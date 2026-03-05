import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/lessons.dart';
import '../tables/logs.dart';
import '../tables/subjects.dart';
import '../tables/timetable.dart';
import '../tables/users.dart';

part 'timetable_dao.g.dart';

/// DAO for the [Timetable] and [Lessons] tables.
///
/// Timetable entries define the recurring weekly schedule — which subject is
/// taught in which class at which time slot on which day.  Lessons are the
/// actual instances of teaching that occurred on a specific date.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay it to the server when
/// connectivity is restored.
@DriftAccessor(tables: [Timetable, Lessons, Subjects, Users, Logs])
class TimetableDao extends DatabaseAccessor<AppDatabase>
    with _$TimetableDaoMixin {
  TimetableDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — timetable
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits every timetable entry for a given class (school, year, term, grade,
  /// stream), joined with the teacher's [Users] row for display.
  ///
  /// Re-emits on any change to [Timetable] or [Users].
  Stream<List<TimetableEntry>> watchClassTimetable({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(
            timetable,
          ).join([innerJoin(users, users.id.equalsExp(timetable.teacher))])
          ..where(
            timetable.school.equals(schoolId) &
                timetable.year.equals(year) &
                timetable.term.equals(term) &
                timetable.grade.equals(grade) &
                timetable.stream.equals(stream),
          )
          ..orderBy([
            OrderingTerm.asc(timetable.day),
            OrderingTerm.asc(timetable.start),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => TimetableEntry(
              slot: r.readTable(timetable),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  /// Emits every timetable entry for a specific teacher across all their
  /// classes in the given term.
  ///
  /// Useful for building a teacher's personal weekly schedule.
  Stream<List<TimetableData>> watchTeacherTimetable({
    required String schoolId,
    required int year,
    required int term,
    required String teacherUserId,
  }) {
    return (select(timetable)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.teacher.equals(teacherUserId),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.day),
            (t) => OrderingTerm.asc(t.start),
          ]))
        .watch();
  }

  /// Emits every timetable entry for a specific day and class — used by the
  /// mobile day-by-day view.
  Stream<List<TimetableEntry>> watchClassDayTimetable({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required DayOfWeek day,
  }) {
    final query =
        select(
            timetable,
          ).join([innerJoin(users, users.id.equalsExp(timetable.teacher))])
          ..where(
            timetable.school.equals(schoolId) &
                timetable.year.equals(year) &
                timetable.term.equals(term) &
                timetable.grade.equals(grade) &
                timetable.stream.equals(stream) &
                timetable.day.equalsValue(day),
          )
          ..orderBy([OrderingTerm.asc(timetable.start)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => TimetableEntry(
              slot: r.readTable(timetable),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  /// Emits the full timetable for a term across all classes — used by the
  /// owner overview / generation UI.
  Stream<List<TimetableEntry>> watchTermTimetable({
    required String schoolId,
    required int year,
    required int term,
  }) {
    final query =
        select(
            timetable,
          ).join([innerJoin(users, users.id.equalsExp(timetable.teacher))])
          ..where(
            timetable.school.equals(schoolId) &
                timetable.year.equals(year) &
                timetable.term.equals(term),
          )
          ..orderBy([
            OrderingTerm.asc(timetable.grade),
            OrderingTerm.asc(timetable.stream),
            OrderingTerm.asc(timetable.day),
            OrderingTerm.asc(timetable.start),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => TimetableEntry(
              slot: r.readTable(timetable),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads — timetable
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns all timetable rows for a given class in a term.
  Future<List<TimetableData>> getClassTimetable({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    return (select(timetable)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.day),
            (t) => OrderingTerm.asc(t.start),
          ]))
        .get();
  }

  /// Returns whether any timetable entries exist for the given term.
  Future<bool> hasTimetable({
    required String schoolId,
    required int year,
    required int term,
  }) async {
    final count = countAll();
    final query = selectOnly(timetable)..addColumns([count]);
    query.where(
      timetable.school.equals(schoolId) &
          timetable.year.equals(year) &
          timetable.term.equals(term),
    );
    final row = await query.getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mutations — timetable
  // ─────────────────────────────────────────────────────────────────────────

  /// Inserts a single timetable slot and writes a log entry.
  Future<void> insertSlot({
    required TimetableCompanion slot,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(timetable).insert(slot);

      // Build the row key from the PK components.
      final rowKey = [
        slot.school.value,
        slot.year.value,
        slot.term.value,
        slot.grade.value,
        slot.stream.value,
        slot.day.value.index, // DayOfWeek → int
        slot.subject.value,
        slot.start.value,
      ].join('|');

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.timetable),
          op: const Value(LogOperation.insert),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Bulk-inserts multiple timetable slots (e.g. after generation) and writes
  /// one log entry per slot.
  Future<void> insertSlots({
    required List<TimetableCompanion> slots,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      for (final slot in slots) {
        await into(timetable).insert(slot);

        final rowKey = [
          slot.school.value,
          slot.year.value,
          slot.term.value,
          slot.grade.value,
          slot.stream.value,
          slot.day.value.index,
          slot.subject.value,
          slot.start.value,
        ].join('|');

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.timetable),
            op: const Value(LogOperation.insert),
            rowKey: Value(rowKey),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }
    });
  }

  /// Deletes a single timetable slot and writes a log entry.
  Future<void> deleteSlot({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required DayOfWeek day,
    required int subject,
    required int start,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (delete(timetable)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream) &
                t.day.equalsValue(day) &
                t.subject.equals(subject) &
                t.start.equals(start),
          ))
          .go();

      final rowKey = [
        schoolId,
        year,
        term,
        grade,
        stream,
        day.index,
        subject,
        start,
      ].join('|');

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.timetable),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Clears all timetable entries for a class in a term and writes delete logs.
  Future<void> clearClassTimetable({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Fetch all existing entries first to write delete logs.
      final existing = await getClassTimetable(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
      );

      // Delete them all.
      await (delete(timetable)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream),
          ))
          .go();

      // Write a delete log for each.
      for (final entry in existing) {
        final rowKey = [
          entry.school,
          entry.year,
          entry.term,
          entry.grade,
          entry.stream,
          entry.day.index,
          entry.subject,
          entry.start,
        ].join('|');

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.timetable),
            op: const Value(LogOperation.delete),
            rowKey: Value(rowKey),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — lessons
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits all lessons for a given class on a specific date, joined with the
  /// teacher's user row.
  Stream<List<LessonEntry>> watchClassLessons({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int date, // days since epoch
  }) {
    final query =
        select(
            lessons,
          ).join([innerJoin(users, users.id.equalsExp(lessons.teacher))])
          ..where(
            lessons.school.equals(schoolId) &
                lessons.year.equals(year) &
                lessons.term.equals(term) &
                lessons.grade.equals(grade) &
                lessons.stream.equals(stream) &
                lessons.date.equals(date),
          )
          ..orderBy([OrderingTerm.asc(lessons.subject)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => LessonEntry(
              lesson: r.readTable(lessons),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  /// Emits all lessons for a teacher on a specific date.
  Stream<List<Lesson>> watchTeacherLessons({
    required String schoolId,
    required int year,
    required int term,
    required String teacherUserId,
    required int date, // days since epoch
  }) {
    return (select(lessons)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.teacher.equals(teacherUserId) &
                t.date.equals(date),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.subject)]))
        .watch();
  }

  /// Emits all lessons for a given class in a term — used for the lesson
  /// history / log view.
  Stream<List<LessonEntry>> watchClassTermLessons({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(
            lessons,
          ).join([innerJoin(users, users.id.equalsExp(lessons.teacher))])
          ..where(
            lessons.school.equals(schoolId) &
                lessons.year.equals(year) &
                lessons.term.equals(term) &
                lessons.grade.equals(grade) &
                lessons.stream.equals(stream),
          )
          ..orderBy([
            OrderingTerm.desc(lessons.date),
            OrderingTerm.asc(lessons.subject),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => LessonEntry(
              lesson: r.readTable(lessons),
              teacher: r.readTable(users),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mutations — lessons
  // ─────────────────────────────────────────────────────────────────────────

  /// Records a lesson (teaching event) and writes a log entry.
  Future<void> insertLesson({
    required LessonsCompanion lesson,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(lessons).insert(lesson);

      final rowKey = [
        lesson.school.value,
        lesson.year.value,
        lesson.term.value,
        lesson.grade.value,
        lesson.stream.value,
        lesson.date.value,
        lesson.subject.value,
        lesson.teacher.value,
      ].join('|');

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.lessons),
          op: const Value(LogOperation.insert),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Deletes a lesson record and writes a log entry.
  Future<void> deleteLesson({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int date,
    required int subject,
    required String teacher,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (delete(lessons)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream) &
                t.date.equals(date) &
                t.subject.equals(subject) &
                t.teacher.equals(teacher),
          ))
          .go();

      final rowKey = [
        schoolId,
        year,
        term,
        grade,
        stream,
        date,
        subject,
        teacher,
      ].join('|');

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.lessons),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View models
// ─────────────────────────────────────────────────────────────────────────────

/// A timetable slot joined with the teacher's user data for display.
class TimetableEntry {
  const TimetableEntry({required this.slot, required this.teacher});

  final TimetableData slot;
  final UsersData teacher;
}

/// A lesson record joined with the teacher's user data for display.
class LessonEntry {
  const LessonEntry({required this.lesson, required this.teacher});

  final Lesson lesson;
  final UsersData teacher;
}
