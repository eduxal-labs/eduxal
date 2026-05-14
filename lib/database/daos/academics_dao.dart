import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/attendance.dart';
import '../tables/class_teachers.dart';
import '../tables/enrollments.dart';
import '../tables/enums.dart';
import '../tables/events.dart';
import '../tables/exams.dart';
import '../tables/grades.dart';
import '../tables/logs.dart';
import '../tables/mastery.dart';
import '../tables/papers.dart';
import '../tables/papers_v2.dart';
import '../tables/students.dart';
import '../tables/subject_teachers.dart';
import '../tables/users.dart';
import '../../models/grade_analytics.dart';
import 'exams_grades_dao.dart' show ExamWithPapers, PaperWithExamInfo;

part 'academics_dao.g.dart';

/// An event with its papers and the first paper's teacher.
typedef EventWithPapers = ({
  EventData event,
  List<PapersV2Data> papers,
  UsersData? teacher,
});

@DriftAccessor(
  tables: [
    Enrollments,
    Students,
    Users,
    Grades,
    Exams,
    Papers,
    Events,
    PapersV2,
    Mastery,
    Attendance,
    SubjectTeachers,
    ClassTeachers,
    Logs,
  ],
)
class AcademicsDao extends DatabaseAccessor<AppDatabase>
    with _$AcademicsDaoMixin {
  AcademicsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // 1. watchStudentsForGrade
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches enrolled students for a grade (optionally filtered by
  /// stream) and enriches each row with trajectory and exam averages.
  ///
  /// The base enrollment+student query is reactive. Each emission triggers a
  /// one-shot computation of trajectory and averages from the grades/exams
  /// tables, producing a fully enriched [GradeStudentRow] list.
  Stream<List<GradeStudentRow>> watchStudentsForGrade({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream,
  }) {
    final baseQuery =
        select(enrollments).join([
          innerJoin(
            students,
            students.school.equalsExp(enrollments.school) &
                students.adm.equalsExp(enrollments.student),
          ),
        ])..where(
          enrollments.school.equals(schoolId) &
              enrollments.year.equals(year) &
              enrollments.term.equals(term) &
              enrollments.grade.equals(grade),
        );

    if (stream != null) {
      baseQuery.where(enrollments.stream.equals(stream));
    }

    baseQuery.orderBy([OrderingTerm.asc(students.name)]);

    return baseQuery.watch().asyncMap((rows) async {
      final enrollmentStudentPairs = rows.map((row) {
        return (
          enrollment: row.readTable(enrollments),
          student: row.readTable(students),
        );
      }).toList();

      if (enrollmentStudentPairs.isEmpty) return <GradeStudentRow>[];

      // Collect all student adm numbers for batch queries.
      final studentAdms = enrollmentStudentPairs
          .map((p) => p.student.adm)
          .toSet();

      // Find all exams for this grade via papers table.
      final examIdsForGrade =
          await (select(papers)..where(
                (p) => p.school.equals(schoolId) & p.grade.equals(grade),
              ))
              .get()
              .then((rows) => rows.map((r) => r.exam).toSet());

      final examQuery = select(exams)
        ..where(
          (e) =>
              e.school.equals(schoolId) &
              e.year.equals(year) &
              e.term.equals(term) &
              e.id.isIn(examIdsForGrade),
        )
        ..orderBy([(e) => OrderingTerm.desc(e.start)]);
      final examList = await examQuery.get();

      if (examList.isEmpty) {
        // No exams — return all students with no grade data.
        return enrollmentStudentPairs.map((p) {
          return GradeStudentRow(
            student: p.student,
            enrollment: p.enrollment,
            trajectory: Trajectory.insufficientData,
            lastExamPercent: null,
            overallAverage: null,
          );
        }).toList();
      }

      final examIds = examList.map((e) => e.id).toList();

      // Fetch subject-level totals (paper IS NULL) for these exams and students.
      final gradeRows =
          await (select(grades)..where(
                (g) =>
                    g.school.equals(schoolId) &
                    g.exam.isIn(examIds) &
                    g.student.isIn(studentAdms) &
                    g.paper.isNull(),
              ))
              .get();

      // Group grades by student → exam.
      // studentGrades[adm][examId] = list of subject-level grades
      final studentGrades = <int, Map<String, List<Grade>>>{};
      for (final g in gradeRows) {
        studentGrades
            .putIfAbsent(g.student, () => {})
            .putIfAbsent(g.exam, () => [])
            .add(g);
      }

      // Determine exam ordering (most recent first) for trajectory.
      final examOrder = {
        for (var i = 0; i < examList.length; i++) examList[i].id: i,
      };

      return enrollmentStudentPairs.map((p) {
        final adm = p.student.adm;
        final gradesMap = studentGrades[adm] ?? {};

        // Compute overall average across all exams.
        double? overallAverage;
        if (gradesMap.isNotEmpty) {
          final allPercents = <double>[];
          for (final examGrades in gradesMap.values) {
            for (final g in examGrades) {
              if (g.total > 0) {
                allPercents.add(g.score / g.total * 100);
              }
            }
          }
          if (allPercents.isNotEmpty) {
            overallAverage =
                allPercents.reduce((a, b) => a + b) / allPercents.length;
          }
        }

        // Find per-exam averages ordered most recent first.
        final examAverages = <({String examId, int order, double avg})>[];
        for (final entry in gradesMap.entries) {
          final examId = entry.key;
          final gList = entry.value;
          final percents = <double>[];
          for (final g in gList) {
            if (g.total > 0) {
              percents.add(g.score / g.total * 100);
            }
          }
          if (percents.isNotEmpty) {
            examAverages.add((
              examId: examId,
              order: examOrder[examId] ?? 999,
              avg: percents.reduce((a, b) => a + b) / percents.length,
            ));
          }
        }
        examAverages.sort((a, b) => a.order.compareTo(b.order));

        final double? lastExamPercent = examAverages.isNotEmpty
            ? examAverages.first.avg
            : null;

        // Compute trajectory from the two most recent exams.
        final Trajectory trajectory;
        if (examAverages.length < 2) {
          trajectory = Trajectory.insufficientData;
        } else {
          final latest = examAverages[0].avg;
          final previous = examAverages[1].avg;
          if (latest > previous) {
            trajectory = Trajectory.improving;
          } else if (latest < previous) {
            trajectory = Trajectory.declining;
          } else {
            trajectory = Trajectory.stable;
          }
        }

        return GradeStudentRow(
          student: p.student,
          enrollment: p.enrollment,
          trajectory: trajectory,
          lastExamPercent: lastExamPercent,
          overallAverage: overallAverage,
        );
      }).toList();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. watchStudentCount
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches the count of students enrolled in a grade/stream.
  Stream<int> watchStudentCount({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream,
  }) {
    final countExpr = enrollments.student.count();
    final query = selectOnly(enrollments)..addColumns([countExpr]);
    query.where(
      enrollments.school.equals(schoolId) &
          enrollments.year.equals(year) &
          enrollments.term.equals(term) &
          enrollments.grade.equals(grade),
    );
    if (stream != null) {
      query.where(enrollments.stream.equals(stream));
    }
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. watchSubjectsForGrade
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches all subject-teacher assignments for a grade and
  /// enriches each with stream-level and grade-level mastery averages.
  Stream<List<SubjectTeacherEntry>> watchSubjectsForGrade({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream,
  }) {
    final baseQuery =
        select(subjectTeachers).join([
          innerJoin(users, users.id.equalsExp(subjectTeachers.teacher)),
          leftOuterJoin(
            attachedDatabase.subjects,
            attachedDatabase.subjects.id.equalsExp(subjectTeachers.subject),
          ),
        ])..where(
          subjectTeachers.school.equals(schoolId) &
              subjectTeachers.year.equals(year) &
              subjectTeachers.term.equals(term) &
              subjectTeachers.grade.equals(grade),
        );

    if (stream != null) {
      baseQuery.where(subjectTeachers.stream.equals(stream));
    }

    return baseQuery.watch().asyncMap((rows) async {
      final subjectTeacherRows = rows.map((row) {
        final subjectRow = row.readTableOrNull(attachedDatabase.subjects);
        return (
          subject: row.readTable(subjectTeachers),
          teacher: row.readTable(users),
          subjectName:
              subjectRow?.name ??
              'Subject ${row.readTable(subjectTeachers).subject}',
        );
      }).toList();

      if (subjectTeacherRows.isEmpty) return <SubjectTeacherEntry>[];

      // Load all enrollments for this grade to know which students are in
      // which stream.
      final allEnrollments =
          await (select(enrollments)..where(
                (e) =>
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term) &
                    e.grade.equals(grade),
              ))
              .get();

      // Group student adm numbers by stream.
      final studentsByStream = <int, Set<int>>{};
      final allStudentAdms = <int>{};
      for (final e in allEnrollments) {
        studentsByStream.putIfAbsent(e.stream, () => {}).add(e.student);
        allStudentAdms.add(e.student);
      }

      // Load all mastery rows for these students in this school.
      // Mastery PK: (school, student, subject, topic).
      // We average across topics for each (student, subject).
      final masteryRows = allStudentAdms.isEmpty
          ? <MasteryData>[]
          : await (select(mastery)..where(
                  (m) =>
                      m.school.equals(schoolId) &
                      m.student.isIn(allStudentAdms),
                ))
                .get();

      // Build per-(student, subject) average mastery.
      // masteryByStudentSubject[student][subject] = average score across topics
      final masteryByStudentSubject = <int, Map<int, double>>{};
      final _accumulator = <int, Map<int, ({double sum, int count})>>{};
      for (final m in masteryRows) {
        _accumulator
            .putIfAbsent(m.student, () => {})
            .update(
              m.subject,
              (prev) => (sum: prev.sum + m.score, count: prev.count + 1),
              ifAbsent: () => (sum: m.score, count: 1),
            );
      }
      for (final studentEntry in _accumulator.entries) {
        final studentMap = <int, double>{};
        for (final subjectEntry in studentEntry.value.entries) {
          studentMap[subjectEntry.key] =
              subjectEntry.value.sum / subjectEntry.value.count;
        }
        masteryByStudentSubject[studentEntry.key] = studentMap;
      }

      // Helper: compute average mastery for a subject across a set of students.
      double? _avgMastery(int subjectCode, Set<int> adms) {
        final scores = <double>[];
        for (final adm in adms) {
          final m = masteryByStudentSubject[adm]?[subjectCode];
          if (m != null) scores.add(m);
        }
        if (scores.isEmpty) return null;
        return scores.reduce((a, b) => a + b) / scores.length;
      }

      return subjectTeacherRows.map((row) {
        final subjectCode = row.subject.subject;
        final streamCode = row.subject.stream;

        final streamStudents = studentsByStream[streamCode] ?? {};
        final streamMasteryAverage = _avgMastery(subjectCode, streamStudents);
        final gradeMasteryAverage = _avgMastery(subjectCode, allStudentAdms);

        return SubjectTeacherEntry(
          subject: row.subject,
          subjectName: row.subjectName,
          streamCode: streamCode,
          streamName: _streamName(streamCode),
          teacher: row.teacher,
          streamMasteryAverage: streamMasteryAverage,
          gradeMasteryAverage: gradeMasteryAverage,
        );
      }).toList();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. watchClassTeachersForGrade
  // ─────────────────────────────────────────────────────────────────────────

  /// Reactively watches class teacher assignments for a grade/stream,
  /// joined with user details.
  Stream<List<ClassTeacherHistoryEntry>> watchClassTeachersForGrade({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream,
  }) {
    final baseQuery =
        select(classTeachers).join([
          innerJoin(users, users.id.equalsExp(classTeachers.teacher)),
        ])..where(
          classTeachers.school.equals(schoolId) &
              classTeachers.year.equals(year) &
              classTeachers.term.equals(term) &
              classTeachers.grade.equals(grade),
        );

    if (stream != null) {
      baseQuery.where(classTeachers.stream.equals(stream));
    }

    // Active first (end IS NULL), then by start descending.
    baseQuery.orderBy([
      OrderingTerm(
        expression: classTeachers.end.isNull(),
        mode: OrderingMode.desc,
      ),
      OrderingTerm.desc(classTeachers.start),
    ]);

    return baseQuery.watch().map((rows) {
      return rows.map((row) {
        final ct = row.readTable(classTeachers);
        final user = row.readTable(users);
        return ClassTeacherHistoryEntry(
          classTeacher: ct,
          user: user,
          isActive: ct.end == null,
        );
      }).toList();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. computeStreamComparison
  // ─────────────────────────────────────────────────────────────────────────

  /// One-shot computation that builds [StreamStats] for each provided stream,
  /// pulling data from enrollments, grades, exams, attendance, and mastery.
  Future<List<StreamStats>> computeStreamComparison({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required List<({int code, String name})> streams,
  }) async {
    if (streams.isEmpty) return [];

    final streamCodes = streams.map((s) => s.code).toSet();

    // ── 1. Load all enrollments for this grade ──
    final allEnrollments =
        await (select(enrollments)..where(
              (e) =>
                  e.school.equals(schoolId) &
                  e.year.equals(year) &
                  e.term.equals(term) &
                  e.grade.equals(grade) &
                  e.stream.isIn(streamCodes),
            ))
            .get();

    // Group students by stream.
    final studentsByStream = <int, Set<int>>{};
    for (final e in allEnrollments) {
      studentsByStream.putIfAbsent(e.stream, () => {}).add(e.student);
    }

    // ── 2. Load exams for this grade via papers table ──
    final examIdsForGrade =
        await (select(papers)
              ..where((p) => p.school.equals(schoolId) & p.grade.equals(grade)))
            .get()
            .then((rows) => rows.map((r) => r.exam).toSet());

    final examList =
        await (select(exams)
              ..where(
                (e) =>
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term) &
                    e.id.isIn(examIdsForGrade),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.start)]))
            .get();

    final examIds = examList.map((e) => e.id).toList();

    // ── 3. Load subject-level grades (paper IS NULL) ──
    final allStudentAdms = studentsByStream.values.expand((s) => s).toSet();
    final gradeRows = examIds.isEmpty || allStudentAdms.isEmpty
        ? <Grade>[]
        : await (select(grades)..where(
                (g) =>
                    g.school.equals(schoolId) &
                    g.exam.isIn(examIds) &
                    g.student.isIn(allStudentAdms) &
                    g.paper.isNull(),
              ))
              .get();

    // Group grades: gradesByStudent[adm][examId] = list of grades
    final gradesByStudent = <int, Map<String, List<Grade>>>{};
    for (final g in gradeRows) {
      gradesByStudent
          .putIfAbsent(g.student, () => {})
          .putIfAbsent(g.exam, () => [])
          .add(g);
    }

    // ── 4. Load attendance rows ──
    final attendanceRows = allStudentAdms.isEmpty
        ? <AttendanceData>[]
        : await (select(attendance)..where(
                (a) =>
                    a.school.equals(schoolId) &
                    a.year.equals(year) &
                    a.term.equals(term) &
                    a.grade.equals(grade) &
                    a.stream.isIn(streamCodes),
              ))
              .get();

    // Group attendance by stream.
    final attendanceByStream = <int, List<AttendanceData>>{};
    for (final a in attendanceRows) {
      attendanceByStream.putIfAbsent(a.stream, () => []).add(a);
    }

    // ── 5. Load mastery rows ──
    final masteryRows = allStudentAdms.isEmpty
        ? <MasteryData>[]
        : await (select(mastery)..where(
                (m) =>
                    m.school.equals(schoolId) & m.student.isIn(allStudentAdms),
              ))
              .get();

    // Group mastery scores by student.
    final masteryByStudent = <int, List<double>>{};
    for (final m in masteryRows) {
      masteryByStudent.putIfAbsent(m.student, () => []).add(m.score);
    }

    // ── 6. Build StreamStats for each stream ──
    final results = <StreamStats>[];
    for (final s in streams) {
      final streamStudents = studentsByStream[s.code] ?? {};
      final studentCount = streamStudents.length;

      // Average score across all exams for students in this stream.
      final allPercents = <double>[];
      for (final adm in streamStudents) {
        final studentExamGrades = gradesByStudent[adm] ?? {};
        for (final examGrades in studentExamGrades.values) {
          for (final g in examGrades) {
            if (g.total > 0) {
              allPercents.add(g.score / g.total * 100);
            }
          }
        }
      }
      final averageScore = allPercents.isEmpty
          ? 0.0
          : allPercents.reduce((a, b) => a + b) / allPercents.length;

      // Last exam average: find the most recent exam for this stream.
      // An exam applies to a stream if there is a matching paper row.
      double? lastExamAverage;
      Exam? lastExam;
      for (final exam in examList) {
        lastExam = exam;
        break; // examList is ordered most recent first; all exams here are for this grade
      }
      if (lastExam != null) {
        final lastExamPercents = <double>[];
        for (final adm in streamStudents) {
          final examGrades = gradesByStudent[adm]?[lastExam.id];
          if (examGrades != null) {
            for (final g in examGrades) {
              if (g.total > 0) {
                lastExamPercents.add(g.score / g.total * 100);
              }
            }
          }
        }
        if (lastExamPercents.isNotEmpty) {
          lastExamAverage =
              lastExamPercents.reduce((a, b) => a + b) /
              lastExamPercents.length;
        }
      }

      // Trajectory: compare 2 most recent exam averages for this stream.
      final Trajectory trajectory;
      final recentExamAverages = <double>[];
      for (final exam in examList) {
        final percents = <double>[];
        for (final adm in streamStudents) {
          final examGrades = gradesByStudent[adm]?[exam.id];
          if (examGrades != null) {
            for (final g in examGrades) {
              if (g.total > 0) {
                percents.add(g.score / g.total * 100);
              }
            }
          }
        }
        if (percents.isNotEmpty) {
          recentExamAverages.add(
            percents.reduce((a, b) => a + b) / percents.length,
          );
        }
        if (recentExamAverages.length >= 2) break;
      }
      if (recentExamAverages.length < 2) {
        trajectory = Trajectory.insufficientData;
      } else {
        final latest = recentExamAverages[0];
        final previous = recentExamAverages[1];
        if (latest > previous) {
          trajectory = Trajectory.improving;
        } else if (latest < previous) {
          trajectory = Trajectory.declining;
        } else {
          trajectory = Trajectory.stable;
        }
      }

      // Attendance rate: count(present) / count(total) * 100.
      final streamAttendance = attendanceByStream[s.code] ?? [];
      double? attendanceRate;
      if (streamAttendance.isNotEmpty) {
        final presentCount = streamAttendance
            .where((a) => a.status == AttendanceStatus.present)
            .length;
        attendanceRate = presentCount / streamAttendance.length * 100;
      }

      // Mastery average across all students in this stream.
      double? masteryAverage;
      final masteryScores = <double>[];
      for (final adm in streamStudents) {
        final scores = masteryByStudent[adm];
        if (scores != null) {
          masteryScores.addAll(scores);
        }
      }
      if (masteryScores.isNotEmpty) {
        masteryAverage =
            masteryScores.reduce((a, b) => a + b) / masteryScores.length;
      }

      results.add(
        StreamStats(
          streamCode: s.code,
          streamName: s.name,
          studentCount: studentCount,
          averageScore: averageScore,
          lastExamAverage: lastExamAverage,
          trajectory: trajectory,
          attendanceRate: attendanceRate,
          masteryAverage: masteryAverage,
        ),
      );
    }

    // Order by stream code.
    results.sort((a, b) => a.streamCode.compareTo(b.streamCode));
    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a display name for a stream code.
  ///
  /// Convention: 1 → "Stream 1", 2 → "Stream 2", etc.
  /// The UI may override this with names from school settings, but the DAO
  /// needs a fallback for the domain models.
  static String _streamName(int code) => 'Stream $code';

  // ─────────────────────────────────────────────────────────────────────────
  // 7. computeAttendanceRate
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes attendance rate for students in a specific stream.
  /// Returns a percentage (0–100) or null if no attendance data exists.
  Future<double?> computeAttendanceRate({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) async {
    final rows =
        await (select(attendance)..where(
              (a) =>
                  a.school.equals(schoolId) &
                  a.year.equals(year) &
                  a.term.equals(term) &
                  a.grade.equals(grade) &
                  a.stream.equals(stream),
            ))
            .get();

    if (rows.isEmpty) return null;

    final presentCount = rows
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    return presentCount / rows.length * 100;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 8. computeStudentAttendance
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes attendance summary for a single student in a term.
  /// Returns (present, absent, leave) counts.
  Future<({int present, int absent, int leave})> computeStudentAttendance({
    required String schoolId,
    required int year,
    required int term,
    required int studentAdm,
  }) async {
    final rows =
        await (select(attendance)..where(
              (a) =>
                  a.school.equals(schoolId) &
                  a.year.equals(year) &
                  a.term.equals(term) &
                  a.student.equals(studentAdm),
            ))
            .get();

    int present = 0;
    int absent = 0;
    int leave = 0;

    for (final row in rows) {
      switch (row.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.leave:
          leave++;
      }
    }

    return (present: present, absent: absent, leave: leave);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. watchExamsForGradeStream
  // ─────────────────────────────────────────────────────────────────────────

  /// Watches exams for a specific grade and stream, INCLUDING grade-wide
  /// exams (where `exam.stream IS NULL`).
  ///
  /// Returns exams where:
  ///   `exam.grade == grade AND (exam.stream == streamCode OR exam.stream IS NULL)`
  ///
  /// This is important because grade-wide exams apply to all streams.
  /// Ordered by exam start descending (most recent first).
  ///
  /// When [streamCode] is null, returns ALL exams for the grade regardless
  /// of stream — used by the "All" tab.
  Stream<List<ExamWithPapers>> watchExamsForGradeStream({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? streamCode,
  }) {
    // Watch papers rows for this grade (and optionally stream) combination.
    final paperStream =
        (select(papers)..where((p) {
              Expression<bool> f =
                  p.school.equals(schoolId) & p.grade.equals(grade);
              if (streamCode != null) {
                f = f & p.stream.equals(streamCode);
              }
              return f;
            }))
            .watch();

    final examStream = paperStream.asyncMap((paperRows) async {
      final ids = paperRows.map((r) => r.exam).toSet().toList();
      if (ids.isEmpty) return <Exam>[];
      return (select(exams)
            ..where(
              (e) =>
                  e.school.equals(schoolId) &
                  e.year.equals(year) &
                  e.term.equals(term) &
                  e.id.isIn(ids),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.start)]))
          .get();
    });

    return examStream.asyncMap((examList) async {
      final results = <ExamWithPapers>[];
      for (final exam in examList) {
        final paperList =
            await (select(papers)
                  ..where((p) {
                    Expression<bool> f =
                        p.school.equals(schoolId) &
                        p.exam.equals(exam.id) &
                        p.grade.equals(grade);
                    if (streamCode != null) {
                      f = f & p.stream.equals(streamCode);
                    }
                    return f;
                  })
                  ..orderBy([
                    (p) => OrderingTerm.asc(p.subject),
                    (p) => OrderingTerm.asc(p.paper),
                  ]))
                .get();
        final teacherUser =
            await (select(users)
                  ..where((u) => u.id.equals(exam.teacher))
                  ..limit(1))
                .getSingleOrNull();
        if (teacherUser != null) {
          results.add((exam: exam, papers: paperList, teacher: teacherUser));
        }
      }
      return results;
    });
  }

  /// Watches events for a specific grade, with their papers_v2 joined.
  ///
  /// Returns events filtered by [schoolId], [year], [term], [grade].
  /// When [streamCode] is given, includes events whose papers match that stream
  /// (or where the paper has NULL stream — grade-wide).
  ///
  /// Uses the new events + papers_v2 tables (migration 0007).
  Stream<List<EventWithPapers>> watchEventsForGradeStream({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? streamCode,
  }) {
    // Watch events for this school + year + term.
    return (select(events)
          ..where(
            (e) =>
                e.school.equals(schoolId) &
                e.year.equals(year) &
                e.term.equals(term),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.startDate)]))
        .watch()
        .asyncMap((eventList) async {
      if (eventList.isEmpty) return [];

      final results = <EventWithPapers>[];
      for (final event in eventList) {
        // Query papers_v2 linked to this event, filtered by grade/stream.
        final paperQuery = select(papersV2)
          ..where((p) {
            Expression<bool> f =
                p.event.equals(event.id) & p.grade.equals(grade);
            if (streamCode != null) {
              f = f & (p.stream.equals(streamCode) | p.stream.isNull());
            }
            return f;
          })
          ..orderBy([(p) => OrderingTerm.asc(p.subject)]);

        final paperList = await paperQuery.get();
        if (paperList.isEmpty) continue;

        // Use the first paper's teacher for display.
        UsersData? teacher;
        if (paperList.isNotEmpty) {
          teacher = await (select(users)
                ..where((u) => u.id.equals(paperList.first.teacher))
                ..limit(1))
              .getSingleOrNull();
        }

        results.add((event: event, papers: paperList, teacher: teacher));
      }
      return results;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 9. computeStudentTrajectory
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes the trajectory for a single student based on their exam
  /// performance.
  ///
  /// Looks at the student's average score across the two most recent exams
  /// for the given grade. If exam N average > exam N-1 average → improving;
  /// less → declining; equal → stable; < 2 exams → insufficientData.
  Future<
    ({Trajectory trajectory, double? lastExamPercent, double? overallAverage})
  >
  computeStudentTrajectory({
    required String schoolId,
    required int studentAdm,
    required int grade,
  }) async {
    // Get all exams for this grade via papers, ordered most recent first.
    final examIdsForGrade =
        await (select(papers)
              ..where((p) => p.school.equals(schoolId) & p.grade.equals(grade)))
            .get()
            .then((rows) => rows.map((r) => r.exam).toSet());

    final examList =
        await (select(exams)
              ..where(
                (e) => e.school.equals(schoolId) & e.id.isIn(examIdsForGrade),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.start)]))
            .get();

    if (examList.isEmpty) {
      return (
        trajectory: Trajectory.insufficientData,
        lastExamPercent: null,
        overallAverage: null,
      );
    }

    final examIds = examList.map((e) => e.id).toList();

    // Fetch subject-level totals (paper IS NULL) for this student.
    final gradeRows =
        await (select(grades)..where(
              (g) =>
                  g.school.equals(schoolId) &
                  g.exam.isIn(examIds) &
                  g.student.equals(studentAdm) &
                  g.paper.isNull(),
            ))
            .get();

    if (gradeRows.isEmpty) {
      return (
        trajectory: Trajectory.insufficientData,
        lastExamPercent: null,
        overallAverage: null,
      );
    }

    // Group grades by exam.
    final gradesByExam = <String, List<Grade>>{};
    for (final g in gradeRows) {
      gradesByExam.putIfAbsent(g.exam, () => []).add(g);
    }

    // Build exam order map (most recent first).
    final examOrder = {
      for (var i = 0; i < examList.length; i++) examList[i].id: i,
    };

    // Compute per-exam averages.
    final examAverages = <({String examId, int order, double avg})>[];
    for (final entry in gradesByExam.entries) {
      final percents = <double>[];
      for (final g in entry.value) {
        if (g.total > 0) {
          percents.add(g.score / g.total * 100);
        }
      }
      if (percents.isNotEmpty) {
        examAverages.add((
          examId: entry.key,
          order: examOrder[entry.key] ?? 999,
          avg: percents.reduce((a, b) => a + b) / percents.length,
        ));
      }
    }
    examAverages.sort((a, b) => a.order.compareTo(b.order));

    // Overall average across all exams.
    final allPercents = <double>[];
    for (final g in gradeRows) {
      if (g.total > 0) {
        allPercents.add(g.score / g.total * 100);
      }
    }
    final double? overallAverage = allPercents.isNotEmpty
        ? allPercents.reduce((a, b) => a + b) / allPercents.length
        : null;

    final double? lastExamPercent = examAverages.isNotEmpty
        ? examAverages.first.avg
        : null;

    // Trajectory from the two most recent exams.
    final Trajectory trajectory;
    if (examAverages.length < 2) {
      trajectory = Trajectory.insufficientData;
    } else {
      final latest = examAverages[0].avg;
      final previous = examAverages[1].avg;
      if (latest > previous) {
        trajectory = Trajectory.improving;
      } else if (latest < previous) {
        trajectory = Trajectory.declining;
      } else {
        trajectory = Trajectory.stable;
      }
    }

    return (
      trajectory: trajectory,
      lastExamPercent: lastExamPercent,
      overallAverage: overallAverage,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 10. batchComputeTrajectories
  // ─────────────────────────────────────────────────────────────────────────

  /// Batch-computes trajectories for a list of students.
  ///
  /// More efficient than calling [computeStudentTrajectory] one by one
  /// because it fetches all exams and grades in single queries, then groups
  /// and computes in Dart.
  Future<
    Map<
      int,
      ({Trajectory trajectory, double? lastExamPercent, double? overallAverage})
    >
  >
  batchComputeTrajectories({
    required String schoolId,
    required int grade,
    required List<int> studentAdms,
  }) async {
    if (studentAdms.isEmpty) return {};

    // Get all exams for this grade via papers, ordered most recent first.
    final examIdsForGrade =
        await (select(papers)
              ..where((p) => p.school.equals(schoolId) & p.grade.equals(grade)))
            .get()
            .then((rows) => rows.map((r) => r.exam).toSet());

    final examList =
        await (select(exams)
              ..where(
                (e) => e.school.equals(schoolId) & e.id.isIn(examIdsForGrade),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.start)]))
            .get();

    // Default result for every student.
    final defaultResult = (
      trajectory: Trajectory.insufficientData,
      lastExamPercent: null as double?,
      overallAverage: null as double?,
    );

    if (examList.isEmpty) {
      return {for (final adm in studentAdms) adm: defaultResult};
    }

    final examIds = examList.map((e) => e.id).toList();

    // Build exam order map (most recent first).
    final examOrder = {
      for (var i = 0; i < examList.length; i++) examList[i].id: i,
    };

    // Fetch all subject-level totals (paper IS NULL) for these students.
    final gradeRows =
        await (select(grades)..where(
              (g) =>
                  g.school.equals(schoolId) &
                  g.exam.isIn(examIds) &
                  g.student.isIn(studentAdms) &
                  g.paper.isNull(),
            ))
            .get();

    // Group grades by student → exam.
    // studentGrades[adm][examId] = list of subject-level grades
    final studentGrades = <int, Map<String, List<Grade>>>{};
    for (final g in gradeRows) {
      studentGrades
          .putIfAbsent(g.student, () => {})
          .putIfAbsent(g.exam, () => [])
          .add(g);
    }

    // Compute trajectory for each student.
    final results =
        <
          int,
          ({
            Trajectory trajectory,
            double? lastExamPercent,
            double? overallAverage,
          })
        >{};

    for (final adm in studentAdms) {
      final gradesMap = studentGrades[adm];
      if (gradesMap == null || gradesMap.isEmpty) {
        results[adm] = defaultResult;
        continue;
      }

      // Overall average across all exams.
      final allPercents = <double>[];
      for (final examGrades in gradesMap.values) {
        for (final g in examGrades) {
          if (g.total > 0) {
            allPercents.add(g.score / g.total * 100);
          }
        }
      }
      final double? overallAverage = allPercents.isNotEmpty
          ? allPercents.reduce((a, b) => a + b) / allPercents.length
          : null;

      // Per-exam averages ordered most recent first.
      final examAverages = <({String examId, int order, double avg})>[];
      for (final entry in gradesMap.entries) {
        final percents = <double>[];
        for (final g in entry.value) {
          if (g.total > 0) {
            percents.add(g.score / g.total * 100);
          }
        }
        if (percents.isNotEmpty) {
          examAverages.add((
            examId: entry.key,
            order: examOrder[entry.key] ?? 999,
            avg: percents.reduce((a, b) => a + b) / percents.length,
          ));
        }
      }
      examAverages.sort((a, b) => a.order.compareTo(b.order));

      final double? lastExamPercent = examAverages.isNotEmpty
          ? examAverages.first.avg
          : null;

      // Trajectory from the two most recent exams.
      final Trajectory trajectory;
      if (examAverages.length < 2) {
        trajectory = Trajectory.insufficientData;
      } else {
        final latest = examAverages[0].avg;
        final previous = examAverages[1].avg;
        if (latest > previous) {
          trajectory = Trajectory.improving;
        } else if (latest < previous) {
          trajectory = Trajectory.declining;
        } else {
          trajectory = Trajectory.stable;
        }
      }

      results[adm] = (
        trajectory: trajectory,
        lastExamPercent: lastExamPercent,
        overallAverage: overallAverage,
      );
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 11. computeStreamSubjectMastery
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes average mastery score for a specific (subject, stream) combination.
  /// Averages across all topics and all students enrolled in this stream.
  /// Returns null if no mastery data.
  Future<double?> computeStreamSubjectMastery({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required int subject,
  }) async {
    // 1. Get all students enrolled in this stream.
    final enrollmentRows =
        await (select(enrollments)..where(
              (e) =>
                  e.school.equals(schoolId) &
                  e.year.equals(year) &
                  e.term.equals(term) &
                  e.grade.equals(grade) &
                  e.stream.equals(stream),
            ))
            .get();

    final studentAdms = enrollmentRows.map((e) => e.student).toSet();
    if (studentAdms.isEmpty) return null;

    // 2. Get all mastery rows for those students for this subject.
    final masteryRows =
        await (select(mastery)..where(
              (m) =>
                  m.school.equals(schoolId) &
                  m.subject.equals(subject) &
                  m.student.isIn(studentAdms),
            ))
            .get();

    if (masteryRows.isEmpty) return null;

    // 3. Average all scores.
    final total = masteryRows.fold<double>(0.0, (sum, m) => sum + m.score);
    return total / masteryRows.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 12. computeGradeSubjectMastery
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes average mastery score for a subject across ALL streams in a grade.
  /// Returns null if no mastery data.
  Future<double?> computeGradeSubjectMastery({
    required String schoolId,
    required int grade,
    required int subject,
  }) async {
    final masteryRows =
        await (select(mastery)..where(
              (m) => m.school.equals(schoolId) & m.subject.equals(subject),
            ))
            .get();

    if (masteryRows.isEmpty) return null;

    final total = masteryRows.fold<double>(0.0, (sum, m) => sum + m.score);
    return total / masteryRows.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 13. computeStreamMasteryAverage
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes average mastery across all subjects for students in a stream.
  /// Used for the stream comparison card.
  Future<double?> computeStreamMasteryAverage({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
  }) async {
    // 1. Get all students enrolled in this stream.
    final enrollmentRows =
        await (select(enrollments)..where(
              (e) =>
                  e.school.equals(schoolId) &
                  e.year.equals(year) &
                  e.term.equals(term) &
                  e.grade.equals(grade) &
                  e.stream.equals(stream),
            ))
            .get();

    final studentAdms = enrollmentRows.map((e) => e.student).toSet();
    if (studentAdms.isEmpty) return null;

    // 2. Get all mastery rows for those students (all subjects).
    final masteryRows =
        await (select(mastery)..where(
              (m) => m.school.equals(schoolId) & m.student.isIn(studentAdms),
            ))
            .get();

    if (masteryRows.isEmpty) return null;

    // 3. Average all scores across all subjects and topics.
    final total = masteryRows.fold<double>(0.0, (sum, m) => sum + m.score);
    return total / masteryRows.length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 17. computeExamTrend
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes exam performance trends per stream for a grade.
  ///
  /// Returns a map keyed by stream code. Each value is a list of
  /// `(label, percent)` records ordered chronologically (oldest first),
  /// representing average student scores on the last [maxExams] exams.
  ///
  /// Exam labels are abbreviated: "E1" for the 1st exam, "A2" for the 2nd
  /// assignment, "As1" for the 1st assessment.
  Future<Map<int, List<({String label, double percent})>>> computeExamTrend({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required List<({int code, String name})> streams,
    int maxExams = 5,
  }) async {
    if (streams.isEmpty) return {};

    final streamCodes = streams.map((s) => s.code).toSet();

    // 1. Load enrollments to map students → streams.
    final allEnrollments =
        await (select(enrollments)..where(
              (e) =>
                  e.school.equals(schoolId) &
                  e.year.equals(year) &
                  e.term.equals(term) &
                  e.grade.equals(grade) &
                  e.stream.isIn(streamCodes),
            ))
            .get();

    final studentsByStream = <int, Set<int>>{};
    for (final e in allEnrollments) {
      studentsByStream.putIfAbsent(e.stream, () => {}).add(e.student);
    }

    // 2. Load exams for this grade via papers, ordered most recent first.
    final examIdsForGrade =
        await (select(papers)
              ..where((p) => p.school.equals(schoolId) & p.grade.equals(grade)))
            .get()
            .then((rows) => rows.map((r) => r.exam).toSet());

    final examList =
        await (select(exams)
              ..where(
                (e) =>
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term) &
                    e.id.isIn(examIdsForGrade),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.start)]))
            .get();

    if (examList.isEmpty) return {};

    // Take at most maxExams.
    final recentExams = examList.take(maxExams).toList();
    final examIds = recentExams.map((e) => e.id).toSet();

    // 3. Load subject-level grades (paper IS NULL) for these exams.
    final allStudentAdms = studentsByStream.values.expand((s) => s).toSet();
    final gradeRows = allStudentAdms.isEmpty
        ? <Grade>[]
        : await (select(grades)..where(
                (g) =>
                    g.school.equals(schoolId) &
                    g.exam.isIn(examIds) &
                    g.student.isIn(allStudentAdms) &
                    g.paper.isNull(),
              ))
              .get();

    // Group: gradesByExamStudent[examId][studentAdm] = list of grades
    final gradesByExamStudent = <String, Map<int, List<Grade>>>{};
    for (final g in gradeRows) {
      gradesByExamStudent
          .putIfAbsent(g.exam, () => {})
          .putIfAbsent(g.student, () => [])
          .add(g);
    }

    // 4. Build labels per exam type — track counters for abbreviation.
    //    "E1", "E2" for exams; "A1" for assignments; "As1" for assessments.
    final typeCounters = <ExamType, int>{};
    // Process in chronological order (oldest first) for labelling.
    final chronologicalExams = recentExams.reversed.toList();
    final examLabels = <String, String>{};
    for (final exam in chronologicalExams) {
      final count = (typeCounters[exam.type] ?? 0) + 1;
      typeCounters[exam.type] = count;
      final prefix = switch (exam.type) {
        ExamType.exam => 'E',
        ExamType.assignment => 'A',
        ExamType.assessment => 'As',
      };
      examLabels[exam.id] = '$prefix$count';
    }

    // 5. For each stream, compute average score per exam.
    final result = <int, List<({String label, double percent})>>{};

    for (final s in streams) {
      final streamStudents = studentsByStream[s.code] ?? {};
      if (streamStudents.isEmpty) {
        result[s.code] = [];
        continue;
      }

      final trendPoints = <({String label, double percent})>[];

      // Process in chronological order (oldest first).
      for (final exam in chronologicalExams) {
        final examGradesByStudent = gradesByExamStudent[exam.id] ?? {};
        final percents = <double>[];

        for (final adm in streamStudents) {
          final studentGrades = examGradesByStudent[adm];
          if (studentGrades == null) continue;
          double totalScore = 0;
          int totalPossible = 0;
          for (final g in studentGrades) {
            totalScore += g.score;
            totalPossible += g.total;
          }
          if (totalPossible > 0) {
            percents.add(totalScore / totalPossible * 100);
          }
        }

        if (percents.isNotEmpty) {
          final avg = percents.reduce((a, b) => a + b) / percents.length;
          trendPoints.add((label: examLabels[exam.id] ?? '?', percent: avg));
        }
      }

      result[s.code] = trendPoints;
    }

    return result;
  }
}
