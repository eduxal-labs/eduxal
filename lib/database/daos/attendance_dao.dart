import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/attendance.dart';
import '../tables/enrollments.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/students.dart';

part 'attendance_dao.g.dart';

/// A single student's attendance record joined with their identity.
class StudentAttendanceRow {
  const StudentAttendanceRow({
    required this.student,
    required this.enrollment,
    this.attendance,
  });

  /// The student's identity row.
  final StudentsData student;

  /// The student's enrollment in this class.
  final Enrollment enrollment;

  /// The attendance record for the queried date, or `null` if not yet marked.
  final AttendanceData? attendance;

  /// Convenience — the current status, defaulting to present when unmarked.
  AttendanceStatus get effectiveStatus =>
      attendance?.status ?? AttendanceStatus.present;

  /// Whether this student has an attendance record for the queried date.
  bool get isMarked => attendance != null;
}

/// Daily attendance summary for a single date.
class DailyAttendanceSummary {
  const DailyAttendanceSummary({
    required this.date,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
  });

  final int date; // days since epoch
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int leaveCount;

  int get markedCount => presentCount + absentCount + leaveCount;
  bool get isFullyMarked => markedCount == totalStudents;
  double get attendanceRate =>
      totalStudents > 0 ? presentCount / totalStudents : 0.0;
}

/// A single student's attendance record for the guardian calendar view.
class StudentAttendanceRecord {
  const StudentAttendanceRecord({required this.date, required this.status});

  final int date; // days since epoch
  final AttendanceStatus status;
}

/// DAO for the [Attendance] table.
///
/// Provides reactive streams for teacher marking UI and guardian history views,
/// plus local mutation methods that write corresponding [Logs] entries inside
/// the same transaction for offline sync.
///
/// The attendance table uses a composite primary key:
/// `(school, year, term, grade, stream, student, date)`.
///
/// The `date` column stores days since Unix epoch (not seconds).
/// The `status` column uses 1-indexed values: Present=1, Absent=2, Leave=3.
@DriftAccessor(tables: [Attendance, Enrollments, Students, Logs])
class AttendanceDao extends DatabaseAccessor<AppDatabase>
    with _$AttendanceDaoMixin {
  AttendanceDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — Teacher marking UI
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the list of enrolled students for a class on a specific date,
  /// joined with any existing attendance records.
  ///
  /// Students without an attendance record for [date] will have
  /// [StudentAttendanceRow.attendance] as `null`.
  ///
  /// Ordered by student admission number ascending.
  ///
  /// Re-emits on any change to [Attendance], [Enrollments], or [Students]
  /// for matching rows.
  Stream<List<StudentAttendanceRow>> watchClassAttendance({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int date,
  }) {
    final query =
        select(enrollments).join([
            innerJoin(
              students,
              students.adm.equalsExp(enrollments.student) &
                  students.school.equalsExp(enrollments.school),
            ),
            leftOuterJoin(
              attendance,
              attendance.school.equalsExp(enrollments.school) &
                  attendance.year.equalsExp(enrollments.year) &
                  attendance.term.equalsExp(enrollments.term) &
                  attendance.grade.equalsExp(enrollments.grade) &
                  attendance.stream.equalsExp(enrollments.stream) &
                  attendance.student.equalsExp(enrollments.student) &
                  attendance.date.equals(date),
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
            (r) => StudentAttendanceRow(
              student: r.readTable(students),
              enrollment: r.readTable(enrollments),
              attendance: r.readTableOrNull(attendance),
            ),
          )
          .toList(),
    );
  }

  /// Emits daily attendance summaries for a class across all dates in the
  /// given term that have at least one attendance record.
  ///
  /// Used by the teacher to see an overview of which days have been marked
  /// and the attendance rate per day.
  ///
  /// Ordered by date descending (most recent first).
  Stream<List<DailyAttendanceSummary>> watchDailyAttendanceSummaries({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) {
    // We need enrollment count and per-date attendance counts.
    // First, watch attendance rows for this class in this term.
    final attendanceQuery = select(attendance)
      ..where(
        (t) =>
            t.school.equals(schoolId) &
            t.year.equals(year) &
            t.term.equals(term) &
            t.grade.equals(grade) &
            t.stream.equals(stream),
      );

    final enrollmentQuery = select(enrollments)
      ..where(
        (t) =>
            t.school.equals(schoolId) &
            t.year.equals(year) &
            t.term.equals(term) &
            t.grade.equals(grade) &
            t.stream.equals(stream),
      );

    // Combine both streams for reactivity.
    return attendanceQuery.watch().asyncMap((attendanceRows) async {
      final enrollmentRows = await enrollmentQuery.get();
      final totalStudents = enrollmentRows.length;

      // Group attendance by date.
      final byDate = <int, List<AttendanceData>>{};
      for (final row in attendanceRows) {
        (byDate[row.date] ??= []).add(row);
      }

      final summaries = <DailyAttendanceSummary>[];
      for (final entry in byDate.entries) {
        int present = 0;
        int absent = 0;
        int leave = 0;
        for (final r in entry.value) {
          switch (r.status) {
            case AttendanceStatus.present:
              present++;
            case AttendanceStatus.absent:
              absent++;
            case AttendanceStatus.leave:
              leave++;
          }
        }
        summaries.add(
          DailyAttendanceSummary(
            date: entry.key,
            totalStudents: totalStudents,
            presentCount: present,
            absentCount: absent,
            leaveCount: leave,
          ),
        );
      }

      // Sort by date descending.
      summaries.sort((a, b) => b.date.compareTo(a.date));
      return summaries;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — Guardian history view
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the full attendance history for a specific student in a term.
  ///
  /// Used by the guardian calendar/list view to display the ward's attendance
  /// records. Ordered by date ascending (oldest first).
  Stream<List<StudentAttendanceRecord>> watchStudentAttendanceHistory({
    required String schoolId,
    required int year,
    required int term,
    required int studentAdm,
  }) {
    // We need the student's enrollment to know their grade/stream.
    // Use a join to get attendance records for wherever they are enrolled.
    final query =
        select(attendance).join([
            innerJoin(
              enrollments,
              enrollments.school.equalsExp(attendance.school) &
                  enrollments.year.equalsExp(attendance.year) &
                  enrollments.term.equalsExp(attendance.term) &
                  enrollments.grade.equalsExp(attendance.grade) &
                  enrollments.stream.equalsExp(attendance.stream) &
                  enrollments.student.equalsExp(attendance.student),
            ),
          ])
          ..where(
            attendance.school.equals(schoolId) &
                attendance.year.equals(year) &
                attendance.term.equals(term) &
                attendance.student.equals(studentAdm),
          )
          ..orderBy([OrderingTerm.asc(attendance.date)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => StudentAttendanceRecord(
              date: r.readTable(attendance).date,
              status: r.readTable(attendance).status,
            ),
          )
          .toList(),
    );
  }

  /// Emits a summary of a student's attendance stats for a term.
  ///
  /// Returns a [DailyAttendanceSummary] where:
  /// - `totalStudents` is the total number of school days with any attendance
  ///   record for the student's class
  /// - `presentCount`, `absentCount`, `leaveCount` are the student's own
  ///   counts
  Stream<({int totalDays, int present, int absent, int leave})>
  watchStudentAttendanceSummary({
    required String schoolId,
    required int year,
    required int term,
    required int studentAdm,
  }) {
    return watchStudentAttendanceHistory(
      schoolId: schoolId,
      year: year,
      term: term,
      studentAdm: studentAdm,
    ).map((records) {
      int present = 0;
      int absent = 0;
      int leave = 0;
      for (final r in records) {
        switch (r.status) {
          case AttendanceStatus.present:
            present++;
          case AttendanceStatus.absent:
            absent++;
          case AttendanceStatus.leave:
            leave++;
        }
      }
      return (
        totalDays: records.length,
        present: present,
        absent: absent,
        leave: leave,
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the attendance record for a specific student on a specific date,
  /// or `null` if not yet marked.
  Future<AttendanceData?> getAttendanceRecord({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int student,
    required int date,
  }) {
    return (select(attendance)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term) &
              t.grade.equals(grade) &
              t.stream.equals(stream) &
              t.student.equals(student) &
              t.date.equals(date),
        ))
        .getSingleOrNull();
  }

  /// Returns all attendance records for a class on a specific date.
  Future<List<AttendanceData>> getClassAttendanceForDate({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int date,
  }) {
    return (select(attendance)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.year.equals(year) &
              t.term.equals(term) &
              t.grade.equals(grade) &
              t.stream.equals(stream) &
              t.date.equals(date),
        ))
        .get();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes
  // ─────────────────────────────────────────────────────────────────────────

  /// Marks or updates a single student's attendance for a given date.
  ///
  /// If no record exists for this `(school, year, term, grade, stream,
  /// student, date)` tuple, an INSERT is performed and an Insert log is
  /// queued.
  ///
  /// If a record already exists, an UPDATE is performed and an Update log
  /// with the [AttendanceColumn.status] + [AttendanceColumn.updated] bits
  /// is queued.
  ///
  /// Both the write and the log entry are wrapped in a single transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> markAttendance({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int studentAdm,
    required int date,
    required AttendanceStatus status,
    required String accountId,
  }) {
    return transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final rowKey = '$schoolId|$year|$term|$grade|$stream|$studentAdm|$date';

      final existing = await getAttendanceRecord(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        student: studentAdm,
        date: date,
      );

      if (existing != null) {
        // Same status — no-op.
        if (existing.status == status) return;

        // Update existing record.
        await (update(attendance)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.year.equals(year) &
                  t.term.equals(term) &
                  t.grade.equals(grade) &
                  t.stream.equals(stream) &
                  t.student.equals(studentAdm) &
                  t.date.equals(date),
            ))
            .write(
              AttendanceCompanion(
                status: Value(status),
                updated: Value(nowSeconds),
              ),
            );

        // Build the column bitmask for the update.
        int mask = 0;
        mask |= (1 << AttendanceColumn.status.bit);
        mask |= (1 << AttendanceColumn.updated.bit);

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.attendance),
            op: const Value(LogOperation.update),
            rowKey: Value(rowKey),
            columns: Value(mask),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      } else {
        // Insert new record.
        await into(attendance).insert(
          AttendanceCompanion(
            school: Value(schoolId),
            year: Value(year),
            term: Value(term),
            grade: Value(grade),
            stream: Value(stream),
            student: Value(studentAdm),
            date: Value(date),
            status: Value(status),
            created: Value(nowSeconds),
            updated: Value(nowSeconds),
          ),
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.attendance),
            op: const Value(LogOperation.insert),
            rowKey: Value(rowKey),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }
    });
  }

  /// Marks attendance for an entire class on a specific date in a single
  /// transaction.
  ///
  /// [statuses] maps `studentAdm → AttendanceStatus`. Students not present
  /// in the map are skipped (their existing records, if any, are unchanged).
  ///
  /// This is the primary method for the "Mark All Present" feature and for
  /// saving the entire class's attendance at once.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> markClassAttendance({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int date,
    required Map<int, AttendanceStatus> statuses,
    required String accountId,
  }) {
    return transaction(() async {
      for (final entry in statuses.entries) {
        await markAttendance(
          schoolId: schoolId,
          year: year,
          term: term,
          grade: grade,
          stream: stream,
          studentAdm: entry.key,
          date: date,
          status: entry.value,
          accountId: accountId,
        );
      }
    });
  }

  /// Deletes a single attendance record and queues a Delete log entry.
  ///
  /// The delete supersedes any pending Insert/Update logs for the same row.
  ///
  /// No-op if no record exists for the given PK.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> deleteAttendanceRecord({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int studentAdm,
    required int date,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final rowKey = '$schoolId|$year|$term|$grade|$stream|$studentAdm|$date';

      final existing = await getAttendanceRecord(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        student: studentAdm,
        date: date,
      );
      if (existing == null) return;

      // Delete log supersedes any pending insert/update for this row.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.attendance),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      await (delete(logs)..where(
            (t) =>
                t.account.equals(accountId) &
                t.tbl.equalsValue(LogTable.attendance) &
                t.rowKey.equals(rowKey) &
                (t.op.equalsValue(LogOperation.insert) |
                    t.op.equalsValue(LogOperation.update)),
          ))
          .go();

      await (delete(attendance)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.grade.equals(grade) &
                t.stream.equals(stream) &
                t.student.equals(studentAdm) &
                t.date.equals(date),
          ))
          .go();
    });
  }
}
