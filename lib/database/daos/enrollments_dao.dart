import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enrollments.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/students.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

part 'enrollments_dao.g.dart';

/// DAO for the [Enrollments] table.
///
/// Enrollments tie a student to a specific class (grade + stream) for a given
/// school year and term.  Each student may only be enrolled in one class per
/// term — enforced at the DB level by the unique index
/// `uq_enrollments_student_term`.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay mutations to the server when
/// connectivity is restored.
@DriftAccessor(tables: [Enrollments, Students, Users, Logs])
class EnrollmentsDao extends DatabaseAccessor<AppDatabase>
    with _$EnrollmentsDaoMixin {
  EnrollmentsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the full list of enrollment rows for the given term, ordered by
  /// grade ascending then stream ascending then student adm ascending.
  ///
  /// Re-emits on any change to the [Enrollments] table for this school/term.
  Stream<List<Enrollment>> watchEnrollmentsForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(enrollments)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.grade),
            (t) => OrderingTerm.asc(t.stream),
            (t) => OrderingTerm.asc(t.student),
          ]))
        .watch();
  }

  /// Emits enrollment rows for a specific class (grade + stream) within a
  /// term, joined with the [Students] row so the UI can display the student's
  /// name inline without a second query.
  ///
  /// Ordered by student admission number ascending.
  ///
  /// Re-emits on any change to [Enrollments] or [Students] for matching rows.
  Stream<List<({Enrollment enrollment, StudentsData student})>>
  watchStudentsInClass({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    final query =
        select(enrollments).join([
            innerJoin(
              students,
              students.adm.equalsExp(enrollments.student) &
                  students.school.equalsExp(enrollments.school),
            ),
          ])
          ..where(
            enrollments.school.equals(schoolId) &
                enrollments.year.equals(year) &
                enrollments.term.equals(term) &
                enrollments.grade.equals(grade) &
                enrollments.stream.equals(stream),
          )
          ..orderBy([OrderingTerm.asc(students.adm)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (
              enrollment: r.readTable(enrollments),
              student: r.readTable(students),
            ),
          )
          .toList(),
    );
  }

  /// Emits the enrollment row for a specific student in the given term, or
  /// `null` when the student is not enrolled in any class that term.
  ///
  /// Re-emits whenever the student's enrollment changes.
  Stream<Enrollment?> watchStudentEnrollment({
    required String schoolId,
    required int year,
    required int term,
    required int studentAdm,
  }) {
    return (select(enrollments)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term) &
              t.student.equals(studentAdm),
        ))
        .watchSingleOrNull();
  }

  /// Emits all enrollment rows for a specific student at a school, across
  /// every year and term.  Ordered by year descending then term descending
  /// so the most recent enrollment appears first.
  ///
  /// Used by the student detail page to show the full enrollment history.
  Stream<List<Enrollment>> watchAllEnrollmentsForStudent({
    required String schoolId,
    required int studentAdm,
  }) {
    return (select(enrollments)
          ..where(
            (t) => t.school.equals(schoolId) & t.student.equals(studentAdm),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.year),
            (t) => OrderingTerm.desc(t.term),
          ]))
        .watch();
  }

  /// Emits the set of distinct (grade, stream) pairs that have at least one
  /// enrolled student for the given term.
  ///
  /// The pairs are collected from raw [Enrollments] rows and deduplicated in
  /// Dart after the stream fires.  Ordered by grade then stream.
  ///
  /// Re-emits on any change to the [Enrollments] table for this school/term.
  Stream<List<({int grade, int stream})>> watchPopulatedClasses({
    required String schoolId,
    required int year,
    required int term,
  }) {
    return (select(enrollments)
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

  /// Emits (student, optional existing enrollment) pairs for **all** active
  /// students at [schoolId], allowing the UI to show both enrolled and
  /// un-enrolled students in a single list.
  ///
  /// Un-enrolled students have `null` for the enrollment field.
  ///
  /// Ordered by student admission number ascending.
  Stream<List<({StudentsData student, Enrollment? enrollment})>>
  watchAllStudentsWithEnrollment({
    required String schoolId,
    required int year,
    required int term,
  }) {
    final query =
        select(students).join([
            leftOuterJoin(
              enrollments,
              enrollments.student.equalsExp(students.adm) &
                  enrollments.school.equalsExp(students.school) &
                  enrollments.year.equals(year) &
                  enrollments.term.equals(term),
            ),
          ])
          ..where(
            students.school.equals(schoolId) &
                students.status.equals(StudentStatus.active.index),
          )
          ..orderBy([OrderingTerm.asc(students.adm)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (
              student: r.readTable(students),
              enrollment: r.readTableOrNull(enrollments),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the enrollment row for the given student in the given term, or
  /// `null` when not enrolled.
  Future<Enrollment?> getStudentEnrollment({
    required String schoolId,
    required int year,
    required int term,
    required int studentAdm,
  }) {
    return (select(enrollments)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term) &
              t.student.equals(studentAdm),
        ))
        .getSingleOrNull();
  }

  /// Returns all enrollment rows for the given class (grade + stream).
  Future<List<Enrollment>> getStudentsInClass({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    return (select(enrollments)
          ..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.student)]))
        .get();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes
  // ─────────────────────────────────────────────────────────────────────────

  /// Enrolls [studentAdm] in the given class (grade + stream) for the given
  /// term.
  ///
  /// If the student is already enrolled in a **different** class that term,
  /// the existing enrollment is removed first and a delete log entry is
  /// queued.  The new enrollment is then inserted and an insert log entry is
  /// queued.  Both operations run in a single transaction.
  ///
  /// If the student is already enrolled in the **same** class, this is a
  /// no-op.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> enrollStudent({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int studentAdm,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.enrollStudent,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Check for an existing enrollment in this term.
      final existing = await getStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      );

      if (existing != null) {
        // Same class — nothing to do.
        if (existing.grade == grade && existing.stream == stream) return;

        // Different class — unenroll from old class first.
        final unenrollPayload = sync_pb.UnenrollStudentPayload(
          school: schoolId,
          year: year,
          term: term,
          grade: existing.grade,
          stream: existing.stream,
          student: studentAdm,
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.unenrollStudent),
            resource: Value('ADM $studentAdm'),
            payload: Value(unenrollPayload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );

        await (delete(enrollments)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.year.equals(year) &
                  t.term.equals(term) &
                  t.student.equals(studentAdm),
            ))
            .go();
      }

      // Insert new enrollment.
      await into(enrollments).insert(
        EnrollmentsCompanion(
          school: Value(schoolId),
          year: Value(year),
          term: Value(term),
          grade: Value(grade),
          stream: Value(stream),
          student: Value(studentAdm),
          created: Value(nowSeconds),
        ),
      );

      final enrollPayload = sync_pb.EnrollStudentPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        student: studentAdm,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.enrollStudent),
          resource: Value('ADM $studentAdm'),
          payload: Value(enrollPayload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes the enrollment for [studentAdm] from any class in the given term.
  ///
  /// If the student is not enrolled, this is a no-op (no log entry written).
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> unenrollStudent({
    required String schoolId,
    required int year,
    required int term,
    required int studentAdm,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.unenrollStudent,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final existing = await getStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      );

      if (existing == null) return; // nothing to remove

      final payload = sync_pb.UnenrollStudentPayload(
        school: schoolId,
        year: year,
        term: term,
        grade: existing.grade,
        stream: existing.stream,
        student: studentAdm,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.unenrollStudent),
          resource: Value('ADM $studentAdm'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(enrollments)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.student.equals(studentAdm),
          ))
          .go();
    });
    sync.schedulePush();
  }

  /// Bulk-enrolls a list of students into the same class in a single
  /// transaction.
  ///
  /// For each student, the same re-enrollment logic as [enrollStudent] is
  /// applied: if already in a different class, the old enrollment is removed
  /// first.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> bulkEnroll({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required List<int> studentAdms,
    required String accountId,
  }) async {
    await transaction(() async {
      for (final adm in studentAdms) {
        await enrollStudent(
          schoolId: schoolId,
          year: year,
          term: term,
          grade: grade,
          stream: stream,
          studentAdm: adm,
          accountId: accountId,
        );
      }
    });
    sync.schedulePush();
  }
}
