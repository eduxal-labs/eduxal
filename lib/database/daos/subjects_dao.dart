import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/class_teachers.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/subjects.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../../client.dart';

part 'subjects_dao.g.dart';

/// DAO for the [Subjects] and [ClassTeachers] tables.
///
/// Subjects tie a teacher to a specific class (school, year, term, grade,
/// stream, subject) for the active term.  Class teachers are the homeroom
/// teachers assigned to a grade+stream combination for a term.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay it to the server when
/// connectivity is restored.
@DriftAccessor(tables: [Subjects, ClassTeachers, Teachers, Users, Logs])
class SubjectsDao extends DatabaseAccessor<AppDatabase>
    with _$SubjectsDaoMixin {
  SubjectsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — subjects
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits every subject row for the given class (school, year, term, grade,
  /// stream), joined with the teacher's [Users] row so the UI can display
  /// the teacher's name inline.
  ///
  /// Re-emits on any change to [Subjects] or [Users].
  Stream<List<({Subject subject, UsersData teacher})>> watchSubjectsForClass({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(
            subjects,
          ).join([innerJoin(users, users.id.equalsExp(subjects.teacher))])
          ..where(
            subjects.school.equals(schoolId) &
                subjects.year.equals(year) &
                subjects.term.equals(term) &
                subjects.grade.equals(grade) &
                subjects.stream.equals(stream),
          )
          ..orderBy([OrderingTerm.asc(subjects.subject)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) =>
                (subject: r.readTable(subjects), teacher: r.readTable(users)),
          )
          .toList(),
    );
  }

  /// Emits every (subject, teacher user) pair for all classes assigned to
  /// [teacherUserId] in the given term.  Useful for building a teacher's
  /// "My Classes" overview.
  ///
  /// Re-emits on any change to [Subjects] or [Users].
  Stream<List<Subject>> watchSubjectsForTeacher({
    required String schoolId,
    required int year,
    required int term,
    required String teacherUserId,
  }) {
    return (select(subjects)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.teacher.equals(teacherUserId),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.grade),
            (t) => OrderingTerm.asc(t.stream),
            (t) => OrderingTerm.asc(t.subject),
          ]))
        .watch();
  }

  /// Emits all distinct (grade, stream) combinations that have at least one
  /// subject assigned in the given term.  Returned as raw [SubjectsData] rows
  /// (duplicates per class are collapsed server-side; here we group in Dart
  /// after the watch fires).
  ///
  /// The UI uses this to populate the class-picker used before selecting a
  /// specific subject.
  Stream<List<({int grade, int stream})>> watchClassesWithSubjects({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(subjects)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.grade),
            (t) => OrderingTerm.asc(t.stream),
          ]))
        .watch()
        .map((rows) {
          final seen = <String>{};
          final result = <({int grade, int stream})>[];
          for (final r in rows) {
            final key = '${r.grade}|${r.stream}';
            if (seen.add(key)) result.add((grade: r.grade, stream: r.stream));
          }
          return result;
        });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — class teachers
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the active class teacher (where [ClassTeachers.end] IS NULL) for
  /// the given (school, year, term, grade, stream), joined with the teacher's
  /// [Users] row.  Emits `null` when no class teacher is assigned.
  ///
  /// Re-emits on any change to [ClassTeachers] or [Users].
  Stream<({ClassTeacher classTeacher, UsersData user})?>
  watchActiveClassTeacher({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(classTeachers).join([
          innerJoin(users, users.id.equalsExp(classTeachers.teacher)),
        ])..where(
          classTeachers.school.equals(schoolId) &
              classTeachers.year.equals(year) &
              classTeachers.term.equals(term) &
              classTeachers.grade.equals(grade) &
              classTeachers.stream.equals(stream) &
              classTeachers.end.isNull(),
        );

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      return (
        classTeacher: row.readTable(classTeachers),
        user: row.readTable(users),
      );
    });
  }

  /// Emits every class-teacher assignment (including historical, where
  /// [ClassTeachers.end] IS NOT NULL) for the given class, ordered by start
  /// date descending.
  Stream<List<({ClassTeacher classTeacher, UsersData user})>>
  watchClassTeacherHistory({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(
            classTeachers,
          ).join([innerJoin(users, users.id.equalsExp(classTeachers.teacher))])
          ..where(
            classTeachers.school.equals(schoolId) &
                classTeachers.year.equals(year) &
                classTeachers.term.equals(term) &
                classTeachers.grade.equals(grade) &
                classTeachers.stream.equals(stream),
          )
          ..orderBy([OrderingTerm.desc(classTeachers.start)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (
              classTeacher: r.readTable(classTeachers),
              user: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns all subjects for the given (school, year, term) in a single
  /// query.  Used during initial data load.
  Future<List<Subject>> getSubjectsForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(subjects)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .get();
  }

  /// Returns the teacher assigned to the given subject/class combo, or null.
  Future<Subject?> getSubjectAssignment({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int subject,
  }) {
    return (select(subjects)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term) &
              t.grade.equals(grade) &
              t.stream.equals(stream) &
              t.subject.equals(subject),
        ))
        .getSingleOrNull();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes — subjects
  // ─────────────────────────────────────────────────────────────────────────

  /// Assigns [teacherUserId] to teach [subject] for the specified class.
  ///
  /// If no existing assignment exists, inserts a new [Subjects] row.
  /// If one already exists (same PK), updates the teacher column and writes
  /// a log update entry.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignSubjectTeacher({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int subject,
    required String teacherUserId,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final existing = await getSubjectAssignment(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        subject: subject,
      );

      // Row key for logs: "school|year|term|grade|stream|subject"
      final rowKey = '$schoolId|$year|$term|$grade|$stream|$subject';

      if (existing == null) {
        // Insert a fresh assignment row.
        await into(subjects).insert(
          SubjectsCompanion(
            school: Value(schoolId),
            year: Value(year),
            term: Value(term),
            grade: Value(grade),
            stream: Value(stream),
            subject: Value(subject),
            teacher: Value(teacherUserId),
            created: Value(nowSeconds),
          ),
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.subjects),
            op: const Value(LogOperation.insert),
            rowKey: Value(rowKey),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      } else {
        // Update the teacher on the existing row.
        await (update(subjects)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.year.equals(year) &
                  t.term.equals(term) &
                  t.grade.equals(grade) &
                  t.stream.equals(stream) &
                  t.subject.equals(subject),
            ))
            .write(SubjectsCompanion(teacher: Value(teacherUserId)));

        final mask = 1 << SubjectsColumn.teacher.bit;

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.subjects),
            op: const Value(LogOperation.update),
            rowKey: Value(rowKey),
            columns: Value(mask),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Removes a subject assignment entirely and enqueues a delete log entry.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> removeSubjectAssignment({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int subject,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final rowKey = '$schoolId|$year|$term|$grade|$stream|$subject';

      // Delete log supersedes pending inserts/updates.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.subjects),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      await (delete(logs)..where(
            (t) =>
                t.account.equals(accountId) &
                t.tbl.equalsValue(LogTable.subjects) &
                t.rowKey.equals(rowKey) &
                (t.op.equalsValue(LogOperation.insert) |
                    t.op.equalsValue(LogOperation.update)),
          ))
          .go();

      await (delete(subjects)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream) &
                t.subject.equals(subject),
          ))
          .go();
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes — class teachers
  // ─────────────────────────────────────────────────────────────────────────

  /// Assigns [teacherUserId] as the class teacher for the given grade+stream.
  ///
  /// If an active class teacher already exists (end IS NULL), that row's
  /// [ClassTeachers.end] is set to today − 1 (yesterday in days-since-epoch)
  /// before the new row is inserted.  This preserves history.
  ///
  /// Writes log entries for both the superseded row (update) and the new row
  /// (insert) inside the same transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignClassTeacher({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required String teacherUserId,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final today = DateTime.now();
      final todayDays =
          today.millisecondsSinceEpoch ~/ 86400000; // days since epoch
      final nowSeconds = BigInt.from(today.millisecondsSinceEpoch ~/ 1000);

      // 1. Close any currently-active class teacher assignment.
      final activeQuery =
          select(classTeachers).join([
            innerJoin(users, users.id.equalsExp(classTeachers.teacher)),
          ])..where(
            classTeachers.school.equals(schoolId) &
                classTeachers.year.equals(year) &
                classTeachers.term.equals(term) &
                classTeachers.grade.equals(grade) &
                classTeachers.stream.equals(stream) &
                classTeachers.end.isNull(),
          );
      final activeRow = await activeQuery.getSingleOrNull();

      if (activeRow != null) {
        final ct = activeRow.readTable(classTeachers);
        // Close the active assignment: end = yesterday (or start if same day).
        final closeDay = (todayDays - 1).clamp(ct.start, todayDays);

        await (update(classTeachers)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.year.equals(year) &
                  t.term.equals(term) &
                  t.grade.equals(grade) &
                  t.stream.equals(stream) &
                  t.teacher.equals(ct.teacher) &
                  t.end.isNull(),
            ))
            .write(ClassTeachersCompanion(end: Value(closeDay)));

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.classTeachers),
            op: const Value(LogOperation.update),
            rowKey: Value('$schoolId|$year|$term|$grade|$stream|${ct.teacher}'),
            columns: Value(1 << ClassTeachersColumn.end.bit),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }

      // 2. Insert the new class teacher assignment.
      final newRowKey = '$schoolId|$year|$term|$grade|$stream|$teacherUserId';

      await into(classTeachers).insert(
        ClassTeachersCompanion(
          school: Value(schoolId),
          year: Value(year),
          term: Value(term),
          grade: Value(grade),
          stream: Value(stream),
          teacher: Value(teacherUserId),
          start: Value(todayDays),
          created: Value(nowSeconds),
        ),
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.classTeachers),
          op: const Value(LogOperation.insert),
          rowKey: Value(newRowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes the active class teacher assignment (sets end = today) without
  /// assigning a replacement.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> removeClassTeacher({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required String teacherUserId,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final todayDays = DateTime.now().millisecondsSinceEpoch ~/ 86400000;

      await (update(classTeachers)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream) &
                t.teacher.equals(teacherUserId) &
                t.end.isNull(),
          ))
          .write(ClassTeachersCompanion(end: Value(todayDays)));

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.classTeachers),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$year|$term|$grade|$stream|$teacherUserId'),
          columns: Value(1 << ClassTeachersColumn.end.bit),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }
}
