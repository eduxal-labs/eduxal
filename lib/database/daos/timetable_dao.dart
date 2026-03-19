import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/lessons.dart';
import '../tables/logs.dart';
import '../tables/subject_teachers.dart';
import '../tables/subjects.dart';
import '../tables/timetable.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;

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
@DriftAccessor(
  tables: [Timetable, Lessons, Subjects, SubjectTeachers, Users, Logs],
)
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
    int? stream,
  }) {
    final baseFilter =
        timetable.school.equals(schoolId) &
        timetable.year.equals(year) &
        timetable.term.equals(term) &
        timetable.grade.equals(grade);
    final filter = stream != null
        ? baseFilter & timetable.stream.equals(stream)
        : baseFilter;
    final query =
        select(timetable).join([
            innerJoin(users, users.id.equalsExp(timetable.teacher)),
            leftOuterJoin(subjects, subjects.id.equalsExp(timetable.subject)),
          ])
          ..where(filter)
          ..orderBy([
            OrderingTerm.asc(timetable.day),
            OrderingTerm.asc(timetable.start),
          ]);

    return query.watch().map(
      (rows) => rows.map((r) {
        final subjectRow = r.readTableOrNull(subjects);
        return TimetableEntry(
          slot: r.readTable(timetable),
          teacher: r.readTable(users),
          subjectName:
              subjectRow?.name ?? 'Subject ${r.readTable(timetable).subject}',
        );
      }).toList(),
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
        select(timetable).join([
            innerJoin(users, users.id.equalsExp(timetable.teacher)),
            leftOuterJoin(subjects, subjects.id.equalsExp(timetable.subject)),
          ])
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
      (rows) => rows.map((r) {
        final subjectRow = r.readTableOrNull(subjects);
        return TimetableEntry(
          slot: r.readTable(timetable),
          teacher: r.readTable(users),
          subjectName:
              subjectRow?.name ?? 'Subject ${r.readTable(timetable).subject}',
        );
      }).toList(),
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
        select(timetable).join([
            innerJoin(users, users.id.equalsExp(timetable.teacher)),
            leftOuterJoin(subjects, subjects.id.equalsExp(timetable.subject)),
          ])
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
      (rows) => rows.map((r) {
        final subjectRow = r.readTableOrNull(subjects);
        return TimetableEntry(
          slot: r.readTable(timetable),
          teacher: r.readTable(users),
          subjectName:
              subjectRow?.name ?? 'Subject ${r.readTable(timetable).subject}',
        );
      }).toList(),
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

  /// Returns all subject-teacher assignments for a term, enriched with the
  /// subject name. This is the primary input to the timetable solver.
  Future<List<SolverAssignment>> getSubjectTeachersForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) async {
    final query =
        select(subjectTeachers).join([
            leftOuterJoin(
              subjects,
              subjects.id.equalsExp(subjectTeachers.subject),
            ),
          ])
          ..where(
            subjectTeachers.school.equals(schoolId) &
                subjectTeachers.year.equals(year) &
                subjectTeachers.term.equals(term),
          )
          ..orderBy([
            OrderingTerm.asc(subjectTeachers.grade),
            OrderingTerm.asc(subjectTeachers.stream),
            OrderingTerm.asc(subjectTeachers.subject),
          ]);

    final rows = await query.get();
    return rows.map((r) {
      final st = r.readTable(subjectTeachers);
      final sub = r.readTableOrNull(subjects);
      return SolverAssignment(
        school: st.school,
        year: st.year,
        term: st.term,
        grade: st.grade,
        stream: st.stream,
        subjectId: st.subject,
        subjectName: sub?.name ?? 'Subject ${st.subject}',
        teacherUserId: st.teacher,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mutations — timetable
  // ─────────────────────────────────────────────────────────────────────────

  /// Inserts a single timetable slot and writes a log entry.
  Future<void> insertSlot({
    required TimetableCompanion slot,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(timetable).insert(slot);

      final payload = sync_pb.CreateTimetableEntryPayload(
        school: slot.school.value,
        year: slot.year.value,
        term: slot.term.value,
        grade: slot.grade.value,
        stream: slot.stream.value,
        subject: slot.subject.value,
        teacher: slot.teacher.value,
        day: slot.day.value.index,
        start: slot.start.value,
      );
      if (slot.end.present) payload.end = slot.end.value;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createTimetableEntry),
          resource: Value('Timetable ${slot.day.value.name}'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Bulk-inserts multiple timetable slots (e.g. after generation) and writes
  /// one log entry per slot.
  Future<void> insertSlots({
    required List<TimetableCompanion> slots,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      for (final slot in slots) {
        await into(timetable).insert(slot);

        final payload = sync_pb.CreateTimetableEntryPayload(
          school: slot.school.value,
          year: slot.year.value,
          term: slot.term.value,
          grade: slot.grade.value,
          stream: slot.stream.value,
          subject: slot.subject.value,
          teacher: slot.teacher.value,
          day: slot.day.value.index,
          start: slot.start.value,
        );
        if (slot.end.present) payload.end = slot.end.value;

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.createTimetableEntry),
            resource: Value('Timetable ${slot.day.value.name}'),
            payload: Value(payload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );
      }
    });
    sync.schedulePush();
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
  }) async {
    await transaction(() async {
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

      final payload = sync_pb.DeleteTimetableEntryPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        subject: subject,
        day: day.index,
        start: start,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteTimetableEntry),
          resource: Value('Timetable ${day.name}'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Clears all timetable entries for a class in a term and writes delete logs.
  Future<void> clearClassTimetable({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required String accountId,
  }) async {
    await transaction(() async {
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
        final payload = sync_pb.DeleteTimetableEntryPayload(
          school: entry.school,
          year: entry.year,
          term: entry.term,
          grade: entry.grade,
          stream: entry.stream,
          subject: entry.subject,
          day: entry.day.index,
          start: entry.start,
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.deleteTimetableEntry),
            resource: Value('Timetable ${entry.day.name}'),
            payload: Value(payload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );
      }
    });
    sync.schedulePush();
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
        select(lessons).join([
            innerJoin(users, users.id.equalsExp(lessons.teacher)),
            leftOuterJoin(subjects, subjects.id.equalsExp(lessons.subject)),
          ])
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
      (rows) => rows.map((r) {
        final subjectRow = r.readTableOrNull(subjects);
        return LessonEntry(
          lesson: r.readTable(lessons),
          teacher: r.readTable(users),
          subjectName:
              subjectRow?.name ?? 'Subject ${r.readTable(lessons).subject}',
        );
      }).toList(),
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
        select(lessons).join([
            innerJoin(users, users.id.equalsExp(lessons.teacher)),
            leftOuterJoin(subjects, subjects.id.equalsExp(lessons.subject)),
          ])
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
      (rows) => rows.map((r) {
        final subjectRow = r.readTableOrNull(subjects);
        return LessonEntry(
          lesson: r.readTable(lessons),
          teacher: r.readTable(users),
          subjectName:
              subjectRow?.name ?? 'Subject ${r.readTable(lessons).subject}',
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mutations — lessons
  // ─────────────────────────────────────────────────────────────────────────

  /// Records a lesson (teaching event) and writes a log entry.
  Future<void> insertLesson({
    required LessonsCompanion lesson,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(lessons).insert(lesson);

      final payload = sync_pb.CreateLessonPayload(
        school: lesson.school.value,
        year: lesson.year.value,
        term: lesson.term.value,
        grade: lesson.grade.value,
        stream: lesson.stream.value,
        date: lesson.date.value,
        subject: lesson.subject.value,
        teacher: lesson.teacher.value,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createLesson),
          resource: Value('Lesson ${lesson.date.value}'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
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
  }) async {
    await transaction(() async {
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

      final payload = sync_pb.DeleteLessonPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        date: date,
        subject: subject,
        teacher: teacher,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteLesson),
          resource: Value('Lesson $date'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View models
// ─────────────────────────────────────────────────────────────────────────────

/// A timetable slot joined with the teacher's user data for display.
class TimetableEntry {
  const TimetableEntry({
    required this.slot,
    required this.teacher,
    required this.subjectName,
  });

  final TimetableData slot;
  final UsersData teacher;

  /// Human-readable subject name from the `subjects` table.
  /// Falls back to `'Subject <id>'` if the subject row is missing.
  final String subjectName;
}

/// A lesson record joined with the teacher's user data for display.
class LessonEntry {
  const LessonEntry({
    required this.lesson,
    required this.teacher,
    required this.subjectName,
  });

  final Lesson lesson;
  final UsersData teacher;

  /// Human-readable subject name from the `subjects` table.
  /// Falls back to `'Subject <id>'` if the subject row is missing.
  final String subjectName;
}

/// One subject-teacher assignment — input record for the timetable solver.
class SolverAssignment {
  const SolverAssignment({
    required this.school,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.subjectId,
    required this.subjectName,
    required this.teacherUserId,
  });

  final String school;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int subjectId;
  final String subjectName;
  final String teacherUserId;
}
