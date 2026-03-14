import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/class_teachers.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/subject_teachers.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;

part 'subjects_dao.g.dart';

/// DAO for the [SubjectTeachers] and [ClassTeachers] tables.
///
/// SubjectTeachers tie a teacher to a specific class (school, year, term, grade,
/// stream, subject) for the active term.  Class teachers are the homeroom
/// teachers assigned to a grade+stream combination for a term.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay it to the server when
/// connectivity is restored.
@DriftAccessor(tables: [SubjectTeachers, ClassTeachers, Teachers, Users, Logs])
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
  /// Re-emits on any change to [SubjectTeachers] or [Users].
  Stream<List<({SubjectTeacher subject, UsersData teacher})>>
  watchSubjectsForClass({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(subjectTeachers).join([
            innerJoin(users, users.id.equalsExp(subjectTeachers.teacher)),
          ])
          ..where(
            subjectTeachers.school.equals(schoolId) &
                subjectTeachers.year.equals(year) &
                subjectTeachers.term.equals(term) &
                subjectTeachers.grade.equals(grade) &
                subjectTeachers.stream.equals(stream),
          )
          ..orderBy([OrderingTerm.asc(subjectTeachers.subject)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (
              subject: r.readTable(subjectTeachers),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  /// Emits every (subject, teacher user) pair for all classes assigned to
  /// [teacherUserId] in the given term.  Useful for building a teacher's
  /// "My Classes" overview.
  ///
  /// Re-emits on any change to [SubjectTeachers] or [Users].
  Stream<List<SubjectTeacher>> watchSubjectsForTeacher({
    required String schoolId,
    required int year,
    required int term,
    required String teacherUserId,
  }) {
    return (select(subjectTeachers)
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
  /// subject assigned in the given term.  Returned as raw [SubjectTeachersData]
  /// rows (duplicates per class are collapsed server-side; here we group in
  /// Dart after the watch fires).
  ///
  /// The UI uses this to populate the class-picker used before selecting a
  /// specific subject.
  Stream<List<({int grade, int stream})>> watchClassesWithSubjects({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(subjectTeachers)
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
  Future<List<SubjectTeacher>> getSubjectsForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(subjectTeachers)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .get();
  }

  /// Returns all subject assignments for a specific class
  /// (school, year, term, grade, stream) as a one-shot read.
  /// Each result includes the subject row and the teacher's [Users] row.
  Future<List<({SubjectTeacher subject, UsersData teacher})>>
  getSubjectsForClass({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(subjectTeachers).join([
            innerJoin(users, users.id.equalsExp(subjectTeachers.teacher)),
          ])
          ..where(
            subjectTeachers.school.equals(schoolId) &
                subjectTeachers.year.equals(year) &
                subjectTeachers.term.equals(term) &
                subjectTeachers.grade.equals(grade) &
                subjectTeachers.stream.equals(stream),
          )
          ..orderBy([OrderingTerm.asc(subjectTeachers.subject)]);

    return query.get().then(
      (rows) => rows
          .map(
            (r) => (
              subject: r.readTable(subjectTeachers),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  /// Returns the teacher assigned to the given subject/class combo, or null.
  Future<SubjectTeacher?> getSubjectAssignment({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int subject,
  }) {
    return (select(subjectTeachers)..where(
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
  /// If no existing assignment exists, inserts a new [SubjectTeachers] row.
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

      if (existing == null) {
        // Insert a fresh assignment row.
        await into(subjectTeachers).insert(
          SubjectTeachersCompanion(
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
      } else {
        // Update the teacher on the existing row.
        await (update(subjectTeachers)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.year.equals(year) &
                  t.term.equals(term) &
                  t.grade.equals(grade) &
                  t.stream.equals(stream) &
                  t.subject.equals(subject),
            ))
            .write(SubjectTeachersCompanion(teacher: Value(teacherUserId)));
      }

      // Log: assignSubject action (covers both insert and reassign).
      final payload = sync_pb.AssignSubjectPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        subject: subject,
        teacher: teacherUserId,
      );

      // Get teacher name for resource display.
      final user = await (select(
        users,
      )..where((t) => t.id.equals(teacherUserId))).getSingleOrNull();
      final resourceName = user?.name ?? teacherUserId;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.assignSubject),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
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

      final payload = sync_pb.UnassignSubjectPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        subject: subject,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.unassignSubject),
          resource: Value('Grade $grade Stream $stream'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(subjectTeachers)..where(
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

        // Log: unassign the old class teacher.
        final unassignPayload = sync_pb.UnassignClassTeacherPayload(
          school: schoolId,
          year: year,
          term: term,
          grade: grade,
          stream: stream,
          teacher: ct.teacher,
        );

        final oldUser = await (select(
          users,
        )..where((t) => t.id.equals(ct.teacher))).getSingleOrNull();
        final oldResourceName = oldUser?.name ?? ct.teacher;

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.unassignClassTeacher),
            resource: Value(oldResourceName),
            payload: Value(unassignPayload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );
      }

      // 2. Insert the new class teacher assignment.
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

      // Log: assign the new class teacher.
      final assignPayload = sync_pb.AssignClassTeacherPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        teacher: teacherUserId,
        start: todayDays,
      );

      final newUser = await (select(
        users,
      )..where((t) => t.id.equals(teacherUserId))).getSingleOrNull();
      final newResourceName = newUser?.name ?? teacherUserId;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.assignClassTeacher),
          resource: Value(newResourceName),
          payload: Value(assignPayload.writeToBuffer()),
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

      final payload = sync_pb.UnassignClassTeacherPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        teacher: teacherUserId,
      );

      // Get teacher name for resource display.
      final user = await (select(
        users,
      )..where((t) => t.id.equals(teacherUserId))).getSingleOrNull();
      final resourceName = user?.name ?? teacherUserId;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.unassignClassTeacher),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }
}
