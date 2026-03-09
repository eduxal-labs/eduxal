import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/exams.dart';
import '../tables/grades.dart';
import '../tables/logs.dart';
import '../tables/mastery.dart';
import '../tables/papers.dart';
import '../tables/students.dart';
import '../../client.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../tables/enrollments.dart';
import '../tables/subjects.dart';

part 'exams_grades_dao.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Composite result types
// ─────────────────────────────────────────────────────────────────────────────

/// A paper row together with all grades already entered for it.
typedef PaperWithGrades = ({Paper paper, List<GradeRow> grades});

/// A single grade row joined with the student's name and admission number.
typedef GradeRow = ({Grade grade, StudentsData student});

/// An exam row together with its papers.
typedef ExamWithPapers = ({Exam exam, List<Paper> papers, UsersData teacher});

/// Analytics snapshot for a single paper — used to drive charts.
class PaperAnalytics {
  const PaperAnalytics({
    required this.totalStudents,
    required this.gradedStudents,
    required this.averageScore,
    required this.averagePercent,
    required this.distribution,
  });

  /// Number of students enrolled in the class for this exam.
  final int totalStudents;

  /// Number of students who have a grade entry.
  final int gradedStudents;

  /// Mean raw score (or 0 when no grades exist yet).
  final double averageScore;

  /// Mean percentage score (0‒100), or 0 when no grades exist.
  final double averagePercent;

  /// Bucketed grade distribution.  Keys are boundary labels
  /// (e.g. "0–39", "40–49", "50–59", "60–69", "70–79", "80–100").
  /// Values are the count of students in that bucket.
  final Map<String, int> distribution;
}

// ─────────────────────────────────────────────────────────────────────────────
// DAO
// ─────────────────────────────────────────────────────────────────────────────

@DriftAccessor(
  tables: [
    Exams,
    Papers,
    Grades,
    Mastery,
    Students,
    Teachers,
    Users,
    Enrollments,
    Subjects,
    Logs,
  ],
)
class ExamsGradesDao extends DatabaseAccessor<AppDatabase>
    with _$ExamsGradesDaoMixin {
  ExamsGradesDao(super.db);

  // ───────────────────────────────────────────────────────────────────────────
  // Reactive streams — exams
  // ───────────────────────────────────────────────────────────────────────────

  /// Emits all exams for a given [schoolId], [year], [term].
  ///
  /// Joined with the teacher's [Users] row and the paper count so the exams
  /// list card can show the exam type, date range, and how many papers are
  /// set without a second query.
  ///
  /// Ordered by exam start date descending (most recent first).
  Stream<List<ExamWithPapers>> watchExamsForTerm({
    required String schoolId,
    required int year,
    required int term,
  }) {
    // Emit whenever exams or papers change.
    final examStream =
        (select(exams)
              ..where(
                (e) =>
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.start)]))
            .watch();

    return examStream.asyncMap((examList) async {
      final results = <ExamWithPapers>[];
      for (final exam in examList) {
        final paperList =
            await (select(papers)
                  ..where(
                    (p) => p.school.equals(schoolId) & p.exam.equals(exam.id),
                  )
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

  /// Emits exams filtered to a specific [grade] and optional [stream].
  ///
  /// When [teacherId] is non-null, only exams created by that teacher are
  /// returned — this is the teacher-filtered view used by [TeacherEntry].
  Stream<List<ExamWithPapers>> watchExamsForClass({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream,
    String? teacherId,
  }) {
    final examStream =
        (select(exams)
              ..where((e) {
                Expression<bool> filter =
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term) &
                    e.grade.equals(grade);
                if (stream != null) {
                  // Include all-stream exams (e.stream IS NULL) AND stream-specific.
                  filter =
                      filter & (e.stream.isNull() | e.stream.equals(stream));
                }
                if (teacherId != null) {
                  filter = filter & e.teacher.equals(teacherId);
                }
                return filter;
              })
              ..orderBy([(e) => OrderingTerm.desc(e.start)]))
            .watch();

    return examStream.asyncMap((examList) async {
      final results = <ExamWithPapers>[];
      for (final exam in examList) {
        final paperList =
            await (select(papers)
                  ..where(
                    (p) => p.school.equals(schoolId) & p.exam.equals(exam.id),
                  )
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

  // ───────────────────────────────────────────────────────────────────────────
  // Reactive streams — papers
  // ───────────────────────────────────────────────────────────────────────────

  /// Emits all papers for [examId] ordered by subject then paper number.
  Stream<List<Paper>> watchPapersForExam({
    required String schoolId,
    required String examId,
  }) {
    return (select(papers)
          ..where((p) => p.school.equals(schoolId) & p.exam.equals(examId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.subject),
            (p) => OrderingTerm.asc(p.paper),
          ]))
        .watch();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reactive streams — grades
  // ───────────────────────────────────────────────────────────────────────────

  /// Emits all grades for a specific paper (exam + subject + paper number),
  /// joined with the student row.
  ///
  /// Ordered by student admission number ascending — keeps the spreadsheet
  /// row order stable across re-emissions.
  Stream<List<GradeRow>> watchGradesForPaper({
    required String schoolId,
    required String examId,
    required int subject,
    int? paper, // null → subject-level totals
  }) {
    final query =
        select(grades).join([
            innerJoin(
              students,
              students.adm.equalsExp(grades.student) &
                  students.school.equalsExp(grades.school),
            ),
          ])
          ..where(
            grades.school.equals(schoolId) &
                grades.exam.equals(examId) &
                grades.subject.equals(subject) &
                (paper == null
                    ? grades.paper.isNull()
                    : grades.paper.equals(paper)),
          )
          ..orderBy([OrderingTerm.asc(students.adm)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (grade: r.readTable(grades), student: r.readTable(students)),
          )
          .toList(),
    );
  }

  /// Emits grades for an entire exam (all subjects, all papers) joined with
  /// students — the full grading roster for the exam overview.
  Stream<List<GradeRow>> watchGradesForExam({
    required String schoolId,
    required String examId,
  }) {
    final query =
        select(grades).join([
            innerJoin(
              students,
              students.adm.equalsExp(grades.student) &
                  students.school.equalsExp(grades.school),
            ),
          ])
          ..where(grades.school.equals(schoolId) & grades.exam.equals(examId))
          ..orderBy([
            OrderingTerm.asc(students.adm),
            OrderingTerm.asc(grades.subject),
            OrderingTerm.asc(grades.paper),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (grade: r.readTable(grades), student: r.readTable(students)),
          )
          .toList(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reactive streams — mastery
  // ───────────────────────────────────────────────────────────────────────────

  /// Emits all mastery rows for [studentAdm] in [schoolId], across all grades
  /// and subjects.  Used for the student mastery radar/list view.
  Stream<List<MasteryData>> watchMasteryForStudent({
    required String schoolId,
    required int studentAdm,
  }) {
    return (select(mastery)
          ..where(
            (m) => m.school.equals(schoolId) & m.student.equals(studentAdm),
          )
          ..orderBy([
            (m) => OrderingTerm.asc(m.grade),
            (m) => OrderingTerm.asc(m.subject),
            (m) => OrderingTerm.asc(m.topic),
          ]))
        .watch();
  }

  /// Emits mastery rows for a specific subject and grade — used for the
  /// teacher's class mastery view.
  Stream<List<({MasteryData mastery, StudentsData student})>>
  watchMasteryForSubject({
    required String schoolId,
    required int grade,
    required int subject,
  }) {
    final query =
        select(mastery).join([
            innerJoin(
              students,
              students.adm.equalsExp(mastery.student) &
                  students.school.equalsExp(mastery.school),
            ),
          ])
          ..where(
            mastery.school.equals(schoolId) &
                mastery.grade.equals(grade) &
                mastery.subject.equals(subject),
          )
          ..orderBy([
            OrderingTerm.asc(students.adm),
            OrderingTerm.asc(mastery.topic),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) =>
                (mastery: r.readTable(mastery), student: r.readTable(students)),
          )
          .toList(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns a single exam by [examId], or null.
  Future<Exam?> getExam(String examId) {
    return (select(exams)..where((e) => e.id.equals(examId))).getSingleOrNull();
  }

  /// Returns a single paper (by composite key), or null.
  Future<Paper?> getPaper({
    required String schoolId,
    required String examId,
    required int subject,
    int? paper,
  }) {
    return (select(papers)..where(
          (p) =>
              p.school.equals(schoolId) &
              p.exam.equals(examId) &
              p.subject.equals(subject) &
              (paper == null ? p.paper.isNull() : p.paper.equals(paper)),
        ))
        .getSingleOrNull();
  }

  /// Returns all papers for [examId].
  Future<List<Paper>> getPapersForExam({
    required String schoolId,
    required String examId,
  }) {
    return (select(papers)
          ..where((p) => p.school.equals(schoolId) & p.exam.equals(examId))
          ..orderBy([
            (p) => OrderingTerm.asc(p.subject),
            (p) => OrderingTerm.asc(p.paper),
          ]))
        .get();
  }

  /// Returns all grade rows for a paper, joined with the student.
  Future<List<GradeRow>> getGradesForPaper({
    required String schoolId,
    required String examId,
    required int subject,
    int? paper,
  }) async {
    final query =
        select(grades).join([
            innerJoin(
              students,
              students.adm.equalsExp(grades.student) &
                  students.school.equalsExp(grades.school),
            ),
          ])
          ..where(
            grades.school.equals(schoolId) &
                grades.exam.equals(examId) &
                grades.subject.equals(subject) &
                (paper == null
                    ? grades.paper.isNull()
                    : grades.paper.equals(paper)),
          )
          ..orderBy([OrderingTerm.asc(students.adm)]);

    final rows = await query.get();
    return rows
        .map(
          (r) => (grade: r.readTable(grades), student: r.readTable(students)),
        )
        .toList();
  }

  /// Returns a single grade row for a specific student + paper, or null.
  Future<Grade?> getGrade({
    required String schoolId,
    required String examId,
    required int studentAdm,
    required int subject,
    int? paper,
  }) {
    return (select(grades)..where(
          (g) =>
              g.school.equals(schoolId) &
              g.exam.equals(examId) &
              g.student.equals(studentAdm) &
              g.subject.equals(subject) &
              (paper == null ? g.paper.isNull() : g.paper.equals(paper)),
        ))
        .getSingleOrNull();
  }

  /// Returns the enrolled student list for the class this exam targets,
  /// ordered by admission number.  Respects [stream]: when the exam has
  /// `stream = null` (all-stream), it returns all enrolled students for the
  /// grade regardless of stream.
  Future<List<StudentsData>> getEnrolledStudents({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream, // null → all streams
  }) async {
    final query =
        select(students).join([
            innerJoin(
              enrollments,
              enrollments.student.equalsExp(students.adm) &
                  enrollments.school.equalsExp(students.school) &
                  enrollments.year.equals(year) &
                  enrollments.term.equals(term) &
                  enrollments.grade.equals(grade),
            ),
          ])
          ..where(students.school.equals(schoolId))
          ..orderBy([OrderingTerm.asc(students.adm)]);

    if (stream != null) {
      query.where(enrollments.stream.equals(stream));
    }

    final rows = await query.get();
    return rows.map((r) => r.readTable(students)).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Analytics
  // ───────────────────────────────────────────────────────────────────────────

  /// Computes a [PaperAnalytics] snapshot for a given paper from the local DB.
  ///
  /// [totalEnrolled] must be passed in by the caller (from
  /// [getEnrolledStudents]) so this method avoids a second enrollment query.
  Future<PaperAnalytics> computePaperAnalytics({
    required String schoolId,
    required String examId,
    required int subject,
    int? paper,
    required int totalEnrolled,
  }) async {
    final gradeRows = await getGradesForPaper(
      schoolId: schoolId,
      examId: examId,
      subject: subject,
      paper: paper,
    );

    if (gradeRows.isEmpty) {
      return PaperAnalytics(
        totalStudents: totalEnrolled,
        gradedStudents: 0,
        averageScore: 0,
        averagePercent: 0,
        distribution: _emptyDistribution(),
      );
    }

    double totalScore = 0;
    double totalPercent = 0;
    final dist = _emptyDistribution();

    for (final row in gradeRows) {
      final pct = row.grade.total > 0
          ? (row.grade.score / row.grade.total) * 100
          : 0;
      totalScore += row.grade.score;
      totalPercent += pct;
      _bucketScore(dist, pct.toDouble());
    }

    return PaperAnalytics(
      totalStudents: totalEnrolled,
      gradedStudents: gradeRows.length,
      averageScore: totalScore / gradeRows.length,
      averagePercent: totalPercent / gradeRows.length,
      distribution: dist,
    );
  }

  Map<String, int> _emptyDistribution() => {
    '0–39': 0,
    '40–49': 0,
    '50–59': 0,
    '60–69': 0,
    '70–79': 0,
    '80–100': 0,
  };

  void _bucketScore(Map<String, int> dist, double pct) {
    if (pct < 40) {
      dist['0–39'] = (dist['0–39'] ?? 0) + 1;
    } else if (pct < 50) {
      dist['40–49'] = (dist['40–49'] ?? 0) + 1;
    } else if (pct < 60) {
      dist['50–59'] = (dist['50–59'] ?? 0) + 1;
    } else if (pct < 70) {
      dist['60–69'] = (dist['60–69'] ?? 0) + 1;
    } else if (pct < 80) {
      dist['70–79'] = (dist['70–79'] ?? 0) + 1;
    } else {
      dist['80–100'] = (dist['80–100'] ?? 0) + 1;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Exam mutations
  // ───────────────────────────────────────────────────────────────────────────

  /// Creates a new exam and writes an INSERT log entry in one transaction.
  ///
  /// [exam] must have a stable id (uuid) assigned by the caller.
  Future<void> createExam({
    required ExamsCompanion exam,
    required String accountId,
  }) async {
    await transaction(() async {
      await into(exams).insert(exam);
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.exams),
          op: const Value(LogOperation.insert),
          rowKey: Value(exam.id.value),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable exam fields and writes an UPDATE log entry.
  Future<void> updateExam({
    required String examId,
    required ExamsCompanion changes,
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(exams)..where((e) => e.id.equals(examId))).write(changes);

      int mask = 0;
      if (changes.stream.present) mask |= (1 << ExamsColumn.stream.bit);
      if (changes.personalized.present) {
        mask |= (1 << ExamsColumn.personalized.bit);
      }
      if (changes.type.present) mask |= (1 << ExamsColumn.type.bit);
      if (changes.start.present) mask |= (1 << ExamsColumn.start.bit);
      if (changes.end.present) mask |= (1 << ExamsColumn.end.bit);
      if (changes.teacher.present) mask |= (1 << ExamsColumn.teacher.bit);
      if (changes.updated.present) mask |= (1 << ExamsColumn.updated.bit);
      if (mask == 0) return;

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.exams),
          op: const Value(LogOperation.update),
          rowKey: Value(examId),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes an exam (cascades to papers and grades via FK) and writes a
  /// DELETE log entry.
  Future<void> deleteExam({
    required String examId,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.exams),
          op: const Value(LogOperation.delete),
          rowKey: Value(examId),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
      await (delete(exams)..where((e) => e.id.equals(examId))).go();
    });
    sync.schedulePush();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Paper mutations
  // ───────────────────────────────────────────────────────────────────────────

  /// Creates a new paper and writes an INSERT log entry.
  ///
  /// Row key format: `"{school}|{exam}|{subject}|{paper}"`.
  /// When [paper.paper] is null the literal string "null" is used as the
  /// last segment — the sync engine understands this convention.
  Future<void> createPaper({
    required PapersCompanion paper,
    required String accountId,
  }) async {
    await transaction(() async {
      await into(papers).insert(paper);
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final paperNum = paper.paper.present && paper.paper.value != null
          ? '${paper.paper.value}'
          : 'null';
      final rowKey =
          '${paper.school.value}|${paper.exam.value}|${paper.subject.value}|$paperNum';
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.papers),
          op: const Value(LogOperation.insert),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable paper fields and writes an UPDATE log entry.
  Future<void> updatePaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
    required PapersCompanion changes,
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(papers)..where(
            (p) =>
                p.school.equals(schoolId) &
                p.exam.equals(examId) &
                p.subject.equals(subject) &
                (paperNum == null
                    ? p.paper.isNull()
                    : p.paper.equals(paperNum)),
          ))
          .write(changes);

      int mask = 0;
      if (changes.invigilator.present) {
        mask |= (1 << PapersColumn.invigilator.bit);
      }
      if (changes.start.present) mask |= (1 << PapersColumn.start.bit);
      if (changes.end.present) mask |= (1 << PapersColumn.end.bit);
      if (changes.status.present) mask |= (1 << PapersColumn.status.bit);
      if (changes.updated.present) mask |= (1 << PapersColumn.updated.bit);
      if (mask == 0) return;

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final paperSeg = paperNum != null ? '$paperNum' : 'null';
      final rowKey = '$schoolId|$examId|$subject|$paperSeg';
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.papers),
          op: const Value(LogOperation.update),
          rowKey: Value(rowKey),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes a paper (cascades to grades) and writes a DELETE log entry.
  Future<void> deletePaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final paperSeg = paperNum != null ? '$paperNum' : 'null';
      final rowKey = '$schoolId|$examId|$subject|$paperSeg';
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.papers),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
      await (delete(papers)..where(
            (p) =>
                p.school.equals(schoolId) &
                p.exam.equals(examId) &
                p.subject.equals(subject) &
                (paperNum == null
                    ? p.paper.isNull()
                    : p.paper.equals(paperNum)),
          ))
          .go();
    });
    sync.schedulePush();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Grade mutations
  // ───────────────────────────────────────────────────────────────────────────

  /// Upserts a single grade row and writes an INSERT or UPDATE log entry.
  ///
  /// If the grade already exists an UPDATE log is written; otherwise INSERT.
  /// Both operations are atomic in a single transaction.
  ///
  /// Row key format: `"{school}|{exam}|{student}|{subject}|{paper}"`.
  Future<void> upsertGrade({
    required GradesCompanion grade,
    required String accountId,
  }) async {
    await transaction(() async {
      final schoolId = grade.school.value;
      final examId = grade.exam.value;
      final studentAdm = grade.student.value;
      final subject = grade.subject.value;
      final paperNum = grade.paper.present ? grade.paper.value : null;
      final paperSeg = paperNum != null ? '$paperNum' : 'null';
      final rowKey = '$schoolId|$examId|$studentAdm|$subject|$paperSeg';
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final existing = await getGrade(
        schoolId: schoolId,
        examId: examId,
        studentAdm: studentAdm,
        subject: subject,
        paper: paperNum,
      );

      if (existing != null) {
        // Update score + total only.
        await (update(grades)..where(
              (g) =>
                  g.school.equals(schoolId) &
                  g.exam.equals(examId) &
                  g.student.equals(studentAdm) &
                  g.subject.equals(subject) &
                  (paperNum == null
                      ? g.paper.isNull()
                      : g.paper.equals(paperNum)),
            ))
            .write(grade);

        int mask = 0;
        if (grade.score.present) mask |= (1 << GradesColumn.score.bit);
        if (grade.total.present) mask |= (1 << GradesColumn.total.bit);
        if (grade.updated.present) mask |= (1 << GradesColumn.updated.bit);

        if (mask > 0) {
          await into(logs).insert(
            LogsCompanion(
              account: Value(accountId),
              tbl: const Value(LogTable.grades),
              op: const Value(LogOperation.update),
              rowKey: Value(rowKey),
              columns: Value(mask),
              status: const Value(LogStatus.pending),
              created: Value(now),
            ),
          );
        }
      } else {
        await into(grades).insert(grade);
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.grades),
            op: const Value(LogOperation.insert),
            rowKey: Value(rowKey),
            status: const Value(LogStatus.pending),
            created: Value(now),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Bulk-upserts a list of grades for the same paper in a single transaction.
  ///
  /// Callers build the companions list once (e.g. from a spreadsheet row scan)
  /// and pass it here.  Each grade is processed with the same upsert logic as
  /// [upsertGrade].
  Future<void> bulkUpsertGrades({
    required List<GradesCompanion> gradeList,
    required String accountId,
  }) async {
    await transaction(() async {
      for (final g in gradeList) {
        await upsertGrade(grade: g, accountId: accountId);
      }
    });
    sync.schedulePush();
  }

  /// Deletes a single grade row and writes a DELETE log entry.
  Future<void> deleteGrade({
    required String schoolId,
    required String examId,
    required int studentAdm,
    required int subject,
    required int? paperNum,
    required String accountId,
  }) async {
    await transaction(() async {
      final paperSeg = paperNum != null ? '$paperNum' : 'null';
      final rowKey = '$schoolId|$examId|$studentAdm|$subject|$paperSeg';
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.grades),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
      await (delete(grades)..where(
            (g) =>
                g.school.equals(schoolId) &
                g.exam.equals(examId) &
                g.student.equals(studentAdm) &
                g.subject.equals(subject) &
                (paperNum == null
                    ? g.paper.isNull()
                    : g.paper.equals(paperNum)),
          ))
          .go();
    });
    sync.schedulePush();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Mastery mutations
  // ───────────────────────────────────────────────────────────────────────────

  /// Upserts a mastery row and writes an INSERT or UPDATE log entry.
  ///
  /// Row key format: `"{school}|{student}|{grade}|{subject}|{topic}"`.
  Future<void> upsertMastery({
    required MasteryCompanion entry,
    required String accountId,
  }) async {
    await transaction(() async {
      final schoolId = entry.school.value;
      final studentAdm = entry.student.value;
      final grade = entry.grade.value;
      final subject = entry.subject.value;
      final topic = entry.topic.value;
      final rowKey = '$schoolId|$studentAdm|$grade|$subject|$topic';
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final existing =
          await (select(mastery)..where(
                (m) =>
                    m.school.equals(schoolId) &
                    m.student.equals(studentAdm) &
                    m.grade.equals(grade) &
                    m.subject.equals(subject) &
                    m.topic.equals(topic),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (update(mastery)..where(
              (m) =>
                  m.school.equals(schoolId) &
                  m.student.equals(studentAdm) &
                  m.grade.equals(grade) &
                  m.subject.equals(subject) &
                  m.topic.equals(topic),
            ))
            .write(entry);

        int mask = 0;
        if (entry.score.present) mask |= (1 << MasteryColumn.score.bit);
        if (entry.updated.present) mask |= (1 << MasteryColumn.updated.bit);

        if (mask > 0) {
          await into(logs).insert(
            LogsCompanion(
              account: Value(accountId),
              tbl: const Value(LogTable.mastery),
              op: const Value(LogOperation.update),
              rowKey: Value(rowKey),
              columns: Value(mask),
              status: const Value(LogStatus.pending),
              created: Value(now),
            ),
          );
        }
      } else {
        await into(mastery).insert(entry);
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            tbl: const Value(LogTable.mastery),
            op: const Value(LogOperation.insert),
            rowKey: Value(rowKey),
            status: const Value(LogStatus.pending),
            created: Value(now),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Student-level grade queries
  // ───────────────────────────────────────────────────────────────────────────

  /// Watches all grades for a specific student at a school.
  /// Used by the student detail page to show exam performance history.
  Stream<List<Grade>> watchStudentGrades(String schoolId, int studentAdm) {
    return (select(grades)
          ..where(
            (t) => t.school.equals(schoolId) & t.student.equals(studentAdm),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .watch();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Class-level grade queries & analytics
  // ───────────────────────────────────────────────────────────────────────────

  /// Watches all grades for a specific exam at a school.
  /// Used by the class performance analytics view.
  Stream<List<Grade>> watchClassGrades({
    required String schoolId,
    required String examId,
  }) {
    return (select(
      grades,
    )..where((t) => t.school.equals(schoolId) & t.exam.equals(examId))).watch();
  }

  /// Computes performance analytics for a whole class (all students in an exam).
  /// Groups by subject and returns average scores per subject.
  /// Only considers subject-level totals (paper == null); falls back to all
  /// grades grouped by subject if no subject-level totals exist.
  Future<Map<int, PaperAnalytics>> computeClassAnalytics({
    required String schoolId,
    required String examId,
  }) async {
    final allGrades = await (select(
      grades,
    )..where((t) => t.school.equals(schoolId) & t.exam.equals(examId))).get();

    // Group by subject — prefer subject-level totals (paper == null)
    final bySubject = <int, List<Grade>>{};
    for (final g in allGrades) {
      if (g.paper != null) continue; // only subject-level totals
      bySubject.putIfAbsent(g.subject, () => []).add(g);
    }

    // If no subject-level grades exist, fall back to all grades grouped by subject
    if (bySubject.isEmpty) {
      for (final g in allGrades) {
        bySubject.putIfAbsent(g.subject, () => []).add(g);
      }
    }

    final result = <int, PaperAnalytics>{};
    for (final entry in bySubject.entries) {
      final subjectGrades = entry.value;
      final totalStudents = subjectGrades.length;
      if (totalStudents == 0) continue;

      double totalPct = 0;
      final distribution = _emptyDistribution();
      for (final g in subjectGrades) {
        final pct = g.total > 0 ? (g.score / g.total) * 100 : 0.0;
        totalPct += pct;
        _bucketScore(distribution, pct);
      }

      result[entry.key] = PaperAnalytics(
        totalStudents: totalStudents,
        gradedStudents: totalStudents,
        averageScore: totalPct / totalStudents,
        averagePercent: totalPct / totalStudents,
        distribution: distribution,
      );
    }
    return result;
  }
}
