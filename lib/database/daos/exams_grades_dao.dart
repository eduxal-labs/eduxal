import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import '../database.dart';
import '../tables/enums.dart';
import '../../models/exam_group.dart';
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
import '../tables/subject_teachers.dart';

import '../../proto/services/sync.pb.dart' as sync_pb;

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

/// A single exam to create, with its optional papers.
/// Used by [ExamsGradesDao.createExamBatch] for multi-grade batch creation.
typedef ExamBatchEntry = ({ExamsCompanion exam, List<PapersCompanion> papers});

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
    PaperSubmissions,
    Grades,
    Mastery,
    Students,
    Teachers,
    Users,
    Enrollments,
    SubjectTeachers,
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
    // Watch papers for this grade (and optionally stream) to get
    // the set of applicable exam IDs, then watch those exams.
    final paperQuery = select(papers)
      ..where((p) {
        Expression<bool> f = p.school.equals(schoolId) & p.grade.equals(grade);
        if (stream != null) f = f & p.stream.equals(stream);
        return f;
      });

    final examStream = paperQuery.watch().asyncMap((paperRows) async {
      final ids = paperRows.map((r) => r.exam).toSet().toList();
      if (ids.isEmpty) return <Exam>[];
      return (select(exams)
            ..where((e) {
              Expression<bool> filter =
                  e.school.equals(schoolId) &
                  e.year.equals(year) &
                  e.term.equals(term) &
                  e.id.isIn(ids);
              if (teacherId != null) {
                filter = filter & e.teacher.equals(teacherId);
              }
              return filter;
            })
            ..orderBy([(e) => OrderingTerm.desc(e.start)]))
          .get();
    });

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
            mastery.school.equals(schoolId) & mastery.subject.equals(subject),
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

  /// Watches a single paper row, emitting null if it is deleted.
  Stream<Paper?> watchPaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
  }) {
    final query = select(papers)
      ..where(
        (p) =>
            p.school.equals(schoolId) &
            p.exam.equals(examId) &
            p.subject.equals(subject) &
            (paperNum == null ? p.paper.isNull() : p.paper.equals(paperNum)),
      );
    return query.watchSingleOrNull();
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

  /// Creates a new exam and writes a [SyncAction.createExam] log entry in one
  /// transaction.
  ///
  /// [exam] must have a stable id (uuid) assigned by the caller.
  Future<void> createExam({
    required ExamsCompanion exam,
    required String accountId,
  }) async {
    await transaction(() async {
      await into(exams).insert(exam);
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.CreateExamPayload(
        id: exam.id.value,
        school: exam.school.value,
        year: exam.year.value,
        term: exam.term.value,
        name: exam.name.value,
        type: exam.type.value.index,
        start: exam.start.value,
        end: exam.end.value,
        teacher: exam.teacher.value,
        personalized: exam.personalized.present
            ? exam.personalized.value
            : false,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createExam),
          resource: Value('Exam ${exam.id.value}'),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Creates a single exam row together with its papers in one atomic
  /// transaction. Writes one [SyncAction.createExam] log entry and one
  /// [SyncAction.createPaper] log entry per paper.
  ///
  /// This is the method used by the exam creation page, which always produces
  /// exactly one exam row (one grade + one stream at a time).
  Future<void> createExamWithPapers({
    required ExamsCompanion exam,
    required List<PapersCompanion> paperRows,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // 1. Insert the exam row
      await into(exams).insert(exam);

      // 2. Write createExam log
      final examPayload = sync_pb.CreateExamPayload(
        id: exam.id.value,
        school: exam.school.value,
        year: exam.year.value,
        term: exam.term.value,
        name: exam.name.value,
        type: exam.type.value.index,
        start: exam.start.value,
        end: exam.end.value,
        teacher: exam.teacher.value,
        personalized: exam.personalized.present
            ? exam.personalized.value
            : false,
      );
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createExam),
          resource: Value(exam.name.value),
          payload: Value(examPayload.writeToBuffer()),
          created: Value(now),
        ),
      );

      // 3. Insert each paper + its log
      for (final p in paperRows) {
        await into(papers).insert(p);
        final paperPayload = sync_pb.CreatePaperPayload(
          school: p.school.value,
          exam: p.exam.value,
          subject: p.subject.value,
          invigilator: p.invigilator.value,
          start: fixnum.Int64(p.start.value.toInt()),
          end: fixnum.Int64(p.end.value.toInt()),
        );
        paperPayload.grade = p.grade.value;
        if (p.stream.present && p.stream.value != null) {
          paperPayload.stream = p.stream.value!;
        }
        if (p.paper.present && p.paper.value != null) {
          paperPayload.paper = p.paper.value!;
        }
        final paperLabel = (p.paper.present && p.paper.value != null)
            ? 'Paper ${p.paper.value}'
            : 'Paper';
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.createPaper),
            resource: Value(paperLabel),
            payload: Value(paperPayload.writeToBuffer()),
            created: Value(now),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Creates [entries] exams (and their papers) in one transaction.
  /// Writes one [SyncAction.createExam] log per exam and one
  /// [SyncAction.createPaper] log per paper.
  ///
  /// Used by the "add stream" and "add grade" flows which may fan out into
  /// multiple exam rows in a single submission. For single-exam creation
  /// use [createExamWithPapers] instead.
  Future<void> createExamBatch({
    required List<ExamBatchEntry> entries,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      for (final entry in entries) {
        // 1. Insert the exam row
        await into(exams).insert(entry.exam);

        // 2. Write createExam log
        final e = entry.exam;
        final examPayload = sync_pb.CreateExamPayload(
          id: e.id.value,
          school: e.school.value,
          year: e.year.value,
          term: e.term.value,
          name: e.name.value,
          type: e.type.value.index,
          start: e.start.value,
          end: e.end.value,
          teacher: e.teacher.value,
          personalized: e.personalized.present ? e.personalized.value : false,
        );
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.createExam),
            resource: Value('Exam ${e.id.value}'),
            payload: Value(examPayload.writeToBuffer()),
            created: Value(now),
          ),
        );

        // 3. Insert each paper + its log
        for (final p in entry.papers) {
          await into(papers).insert(p);
          final paperPayload = sync_pb.CreatePaperPayload(
            school: p.school.value,
            exam: p.exam.value,
            subject: p.subject.value,
            invigilator: p.invigilator.value,
            start: fixnum.Int64(p.start.value.toInt()),
            end: fixnum.Int64(p.end.value.toInt()),
          );
          paperPayload.grade = p.grade.value;
          if (p.stream.present && p.stream.value != null) {
            paperPayload.stream = p.stream.value!;
          }
          if (p.paper.present && p.paper.value != null) {
            paperPayload.paper = p.paper.value!;
          }
          final paperLabel = (p.paper.present && p.paper.value != null)
              ? 'Paper ${p.paper.value}'
              : 'Paper';
          await into(logs).insert(
            LogsCompanion(
              account: Value(accountId),
              action: Value(SyncAction.createPaper),
              resource: Value(paperLabel),
              payload: Value(paperPayload.writeToBuffer()),
              created: Value(now),
            ),
          );
        }
      }
    });
    sync.schedulePush();
  }

  /// Updates mutable exam fields and writes a [SyncAction.updateExam] log entry.
  Future<void> updateExam({
    required String examId,
    required ExamsCompanion changes,
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(exams)..where((e) => e.id.equals(examId))).write(changes);

      final payload = sync_pb.UpdateExamPayload(id: examId);
      bool hasChanges = false;

      if (changes.name.present) {
        payload.name = changes.name.value;
        hasChanges = true;
      }
      if (changes.personalized.present) {
        payload.personalized = changes.personalized.value;
        hasChanges = true;
      }
      if (changes.type.present) {
        payload.type = changes.type.value.index;
        hasChanges = true;
      }
      if (changes.start.present) {
        payload.start = changes.start.value;
        hasChanges = true;
      }
      if (changes.end.present) {
        payload.end = changes.end.value;
        hasChanges = true;
      }
      if (changes.teacher.present) {
        payload.teacher = changes.teacher.value;
        hasChanges = true;
      }
      if (!hasChanges) return;

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateExam),
          resource: Value('Exam $examId'),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the [name] field on all exam rows in [examIds] atomically.
  /// Writes one [SyncAction.updateExam] log entry per exam ID.
  Future<void> updateExamName({
    required List<String> examIds,
    required String name,
    required String accountId,
  }) async {
    if (examIds.isEmpty) return;
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      for (final id in examIds) {
        await (update(exams)..where((e) => e.id.equals(id))).write(
          ExamsCompanion(name: Value(name)),
        );
        final payload = sync_pb.UpdateExamPayload(id: id, name: name);
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.updateExam),
            resource: Value('Exam $id'),
            payload: Value(payload.writeToBuffer()),
            created: Value(now),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Deletes an exam (cascades to papers and grades via FK) and writes a
  /// [SyncAction.deleteExam] log entry.
  Future<void> deleteExam({
    required String examId,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.DeleteExamPayload(id: examId);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteExam),
          resource: Value('Exam $examId'),
          payload: Value(payload.writeToBuffer()),
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

  /// Creates a new paper and writes a [SyncAction.createPaper] log entry.
  Future<void> createPaper({
    required PapersCompanion paper,
    required String accountId,
  }) async {
    await transaction(() async {
      await into(papers).insert(paper);
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.CreatePaperPayload(
        school: paper.school.value,
        exam: paper.exam.value,
        subject: paper.subject.value,
        invigilator: paper.invigilator.value,
        start: fixnum.Int64(paper.start.value.toInt()),
        end: fixnum.Int64(paper.end.value.toInt()),
        grade: paper.grade.value,
      );
      if (paper.stream.present && paper.stream.value != null) {
        payload.stream = paper.stream.value!;
      }
      if (paper.paper.present && paper.paper.value != null) {
        payload.paper = paper.paper.value!;
      }

      final paperLabel = paper.paper.present && paper.paper.value != null
          ? 'Paper ${paper.paper.value}'
          : 'Paper';

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createPaper),
          resource: Value(paperLabel),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable paper fields and writes a [SyncAction.updatePaper] log entry.
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

      final payload = sync_pb.UpdatePaperPayload(
        school: schoolId,
        exam: examId,
        subject: subject,
      );
      if (paperNum != null) payload.paper = paperNum;
      bool hasChanges = false;

      if (changes.invigilator.present) {
        payload.invigilator = changes.invigilator.value;
        hasChanges = true;
      }
      if (changes.start.present) {
        payload.start = fixnum.Int64(changes.start.value.toInt());
        hasChanges = true;
      }
      if (changes.end.present) {
        payload.end = fixnum.Int64(changes.end.value.toInt());
        hasChanges = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        hasChanges = true;
      }
      if (changes.grade.present) {
        payload.grade = changes.grade.value;
        hasChanges = true;
      }
      if (changes.stream.present && changes.stream.value != null) {
        payload.stream = changes.stream.value!;
        hasChanges = true;
      }
      if (!hasChanges) return;

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final paperLabel = paperNum != null ? 'Paper $paperNum' : 'Paper';
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updatePaper),
          resource: Value(paperLabel),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Deletes a paper (cascades to grades) and writes a [SyncAction.deletePaper]
  /// log entry.
  Future<void> deletePaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.DeletePaperPayload(
        school: schoolId,
        exam: examId,
        subject: subject,
      );
      if (paperNum != null) payload.paper = paperNum;

      final paperLabel = paperNum != null ? 'Paper $paperNum' : 'Paper';
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deletePaper),
          resource: Value(paperLabel),
          payload: Value(payload.writeToBuffer()),
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

  /// Upserts a single grade row and writes a [SyncAction.updateGrade] or
  /// [SyncAction.markGrades] log entry.
  ///
  /// If the grade already exists an updateGrade log is written; otherwise a
  /// markGrades log with a single record.
  /// Both operations are atomic in a single transaction.
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

        final payload = sync_pb.UpdateGradePayload(
          school: schoolId,
          exam: examId,
          student: studentAdm,
          subject: subject,
        );
        if (paperNum != null) payload.paper = paperNum;
        bool hasChanges = false;
        if (grade.score.present) {
          payload.score = grade.score.value;
          hasChanges = true;
        }
        if (grade.total.present) {
          payload.total = grade.total.value;
          hasChanges = true;
        }

        if (hasChanges) {
          await into(logs).insert(
            LogsCompanion(
              account: Value(accountId),
              action: Value(SyncAction.updateGrade),
              resource: Value('Grade — student $studentAdm'),
              payload: Value(payload.writeToBuffer()),
              created: Value(now),
            ),
          );
        }
      } else {
        await into(grades).insert(grade);

        final record = sync_pb.GradeRecord(
          student: studentAdm,
          score: grade.score.value,
          total: grade.total.value,
        );
        final payload = sync_pb.MarkGradesPayload(
          school: schoolId,
          exam: examId,
          subject: subject,
          records: [record],
        );
        if (paperNum != null) payload.paper = paperNum;

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.markGrades),
            resource: Value('Grade — student $studentAdm'),
            payload: Value(payload.writeToBuffer()),
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

  /// Deletes a single grade row and writes a [SyncAction.deleteGrade] log entry.
  Future<void> deleteGrade({
    required String schoolId,
    required String examId,
    required int studentAdm,
    required int subject,
    required int? paperNum,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteGradePayload(
        school: schoolId,
        exam: examId,
        student: studentAdm,
        subject: subject,
      );
      if (paperNum != null) payload.paper = paperNum;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteGrade),
          resource: Value('Grade — student $studentAdm'),
          payload: Value(payload.writeToBuffer()),
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

  /// Upserts a mastery row and writes a [SyncAction.updateMastery] log entry.
  ///
  /// Both inserts and updates use `updateMastery` — the server handles the
  /// upsert semantics based on the composite PK in the payload.
  Future<void> upsertMastery({
    required MasteryCompanion entry,
    required String accountId,
  }) async {
    await transaction(() async {
      final schoolId = entry.school.value;
      final studentAdm = entry.student.value;
      final subject = entry.subject.value;
      final topic = entry.topic.value;
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final existing =
          await (select(mastery)..where(
                (m) =>
                    m.school.equals(schoolId) &
                    m.student.equals(studentAdm) &
                    m.subject.equals(subject) &
                    m.topic.equals(topic),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (update(mastery)..where(
              (m) =>
                  m.school.equals(schoolId) &
                  m.student.equals(studentAdm) &
                  m.subject.equals(subject) &
                  m.topic.equals(topic),
            ))
            .write(entry);

        if (entry.score.present) {
          final payload = sync_pb.UpdateMasteryPayload(
            school: schoolId,
            student: studentAdm,
            subject: subject,
            topic: topic,
            score: entry.score.value,
          );

          await into(logs).insert(
            LogsCompanion(
              account: Value(accountId),
              action: Value(SyncAction.updateMastery),
              resource: Value('Mastery — student $studentAdm'),
              payload: Value(payload.writeToBuffer()),
              created: Value(now),
            ),
          );
        }
      } else {
        await into(mastery).insert(entry);

        final payload = sync_pb.UpdateMasteryPayload(
          school: schoolId,
          student: studentAdm,
          subject: subject,
          topic: topic,
          score: entry.score.value,
        );

        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.updateMastery),
            resource: Value('Mastery — student $studentAdm'),
            payload: Value(payload.writeToBuffer()),
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

  // ───────────────────────────────────────────────────────────────────────────
  // Exam group methods
  // ───────────────────────────────────────────────────────────────────────────

  /// Emits all exams for a term, grouped by (type, start, end) into
  /// [ExamGroup] objects. Sorted by start date descending (most recent first).
  Stream<List<ExamGroup>> watchExamGroups({
    required String schoolId,
    required int year,
    required int term,
  }) {
    // Watch all exams for the term
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
      // Group exams by (type, start, end) key
      final groups = <String, List<Exam>>{};
      for (final exam in examList) {
        final key = '${exam.type.index}|${exam.start}|${exam.end}';
        (groups[key] ??= []).add(exam);
      }

      final result = <ExamGroup>[];
      for (final group in groups.values) {
        final firstExam = group.first;
        final teacherUser =
            await (select(users)
                  ..where((u) => u.id.equals(firstExam.teacher))
                  ..limit(1))
                .getSingleOrNull();
        if (teacherUser == null) continue;

        // Load ALL papers for all exams in this group
        final examIds = group.map((e) => e.id).toList();
        final allPapers =
            await (select(papers)
                  ..where(
                    (p) => p.school.equals(schoolId) & p.exam.isIn(examIds),
                  )
                  ..orderBy([
                    (p) => OrderingTerm.asc(p.subject),
                    (p) => OrderingTerm.asc(p.paper),
                  ]))
                .get();

        // Group papers by grade, then by stream within each grade
        final gradeMap = <int, Map<int?, List<Paper>>>{};
        for (final paper in allPapers) {
          final streamKey = paper.stream; // nullable int
          gradeMap
              .putIfAbsent(paper.grade, () => {})
              .putIfAbsent(streamKey, () => [])
              .add(paper);
        }

        // Find exam row for each (grade, stream) combination
        // Since papers carry the exam id, we can find which exam each stream belongs to
        final gradeEntries = <ExamGradeEntry>[];
        for (final gradeEntry in gradeMap.entries) {
          final streamEntries = <ExamStreamEntry>[];
          for (final streamEntry in gradeEntry.value.entries) {
            // All papers in this stream group should belong to the same exam
            final examId = streamEntry.value.first.exam;
            final exam = group.firstWhere((e) => e.id == examId);
            streamEntries.add(
              ExamStreamEntry(
                exam: exam,
                streamCode: streamEntry.key,
                papers: streamEntry.value,
              ),
            );
          }
          gradeEntries.add(
            ExamGradeEntry(grade: gradeEntry.key, streams: streamEntries),
          );
        }

        // Sort grades ascending
        gradeEntries.sort((a, b) => a.grade.compareTo(b.grade));

        result.add(
          ExamGroup(
            school: schoolId,
            year: year,
            term: term,
            type: firstExam.type,
            start: firstExam.start,
            end: firstExam.end,
            personalized: firstExam.personalized,
            teacher: teacherUser,
            grades: gradeEntries,
          ),
        );
      }

      // Sort by start descending (most recent first)
      result.sort((a, b) => b.start.compareTo(a.start));
      return result;
    });
  }

  /// Updates the date range for ALL exam rows in a group atomically.
  /// Used when extending an exam's date range — all rows sharing the
  /// same (type, oldStart, oldEnd) must stay in sync.
  Future<void> updateExamGroupDateRange({
    required String schoolId,
    required int year,
    required int term,
    required ExamType type,
    required int oldStart,
    required int oldEnd,
    required int newStart,
    required int newEnd,
    required String accountId,
  }) async {
    await transaction(() async {
      // Find all exam IDs matching the group
      final matching =
          await (select(exams)..where(
                (e) =>
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term) &
                    e.type.equals(type.index) &
                    e.start.equals(oldStart) &
                    e.end.equals(oldEnd),
              ))
              .get();

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      for (final exam in matching) {
        final changes = ExamsCompanion(
          start: Value(newStart),
          end: Value(newEnd),
          updated: Value(now),
        );
        await (update(
          exams,
        )..where((e) => e.id.equals(exam.id))).write(changes);

        // Write an updateExam log per row
        final payload = sync_pb.UpdateExamPayload(
          id: exam.id,
          start: newStart,
          end: newEnd,
        );
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.updateExam),
            resource: Value('Exam ${exam.id}'),
            payload: Value(payload.writeToBuffer()),
            created: Value(now),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Adds a new grade to an existing exam group by creating a new exam row
  /// (one per stream if streams are specified, or one with stream=null)
  /// and optionally its papers. Returns the created exam IDs.
  Future<List<String>> addGradeToExamGroup({
    required ExamGroup group,
    required int grade,
    required List<int?> streams, // null = all streams, or list of stream codes
    required List<PapersCompanion> papers, // papers for each stream
    required String teacherId,
    required String accountId,
  }) async {
    final ids = <String>[];
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      for (final _ in streams) {
        final examId = _generateExamId();
        ids.add(examId);

        final examCompanion = ExamsCompanion(
          id: Value(examId),
          school: Value(group.school),
          year: Value(group.year),
          term: Value(group.term),
          personalized: Value(group.personalized),
          type: Value(group.type),
          start: Value(group.start),
          end: Value(group.end),
          teacher: Value(teacherId),
          created: Value(now),
          updated: Value(now),
        );
        await into(exams).insert(examCompanion);

        final examPayload = sync_pb.CreateExamPayload(
          id: examId,
          school: group.school,
          year: group.year,
          term: group.term,
          type: group.type.index,
          start: group.start,
          end: group.end,
          teacher: teacherId,
          personalized: group.personalized,
        );
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.createExam),
            resource: Value('Exam $examId'),
            payload: Value(examPayload.writeToBuffer()),
            created: Value(now),
          ),
        );

        // Insert papers for this stream's exam
        final streamPapers = papers
            .where((p) => p.exam.value == examId)
            .toList();
        for (final p in streamPapers) {
          await into(this.papers).insert(p);
          final paperPayload = sync_pb.CreatePaperPayload(
            school: p.school.value,
            exam: p.exam.value,
            subject: p.subject.value,
            invigilator: p.invigilator.value,
            start: fixnum.Int64(p.start.value.toInt()),
            end: fixnum.Int64(p.end.value.toInt()),
          );
          paperPayload.grade = p.grade.value;
          if (p.stream.present && p.stream.value != null) {
            paperPayload.stream = p.stream.value!;
          }
          if (p.paper.present && p.paper.value != null) {
            paperPayload.paper = p.paper.value!;
          }
          await into(logs).insert(
            LogsCompanion(
              account: Value(accountId),
              action: Value(SyncAction.createPaper),
              resource: Value('Paper'),
              payload: Value(paperPayload.writeToBuffer()),
              created: Value(now),
            ),
          );
        }
      }
    });
    sync.schedulePush();
    return ids;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Paper Submissions (client-only, never synced)
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns all submission rows for a given paper + student, ordered by
  /// [PaperSubmissions.createdAt] ascending.
  Future<List<PaperSubmissionData>> getSubmissionsForStudent({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paperNum,
  }) {
    final query = select(paperSubmissions)
      ..where(
        (s) =>
            s.school.equals(schoolId) &
            s.exam.equals(examId) &
            s.student.equals(student) &
            s.subject.equals(subject) &
            (paperNum == null
                ? s.paperNum.isNull()
                : s.paperNum.equals(paperNum)),
      )
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    return query.get();
  }

  /// Returns all submission rows for an entire paper (all students),
  /// keyed by student admission number.
  Future<Map<int, List<String>>> getSubmissionsForPaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
  }) async {
    final query = select(paperSubmissions)
      ..where(
        (s) =>
            s.school.equals(schoolId) &
            s.exam.equals(examId) &
            s.subject.equals(subject) &
            (paperNum == null
                ? s.paperNum.isNull()
                : s.paperNum.equals(paperNum)),
      )
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    final rows = await query.get();
    final result = <int, List<String>>{};
    for (final row in rows) {
      result.putIfAbsent(row.student, () => []).add(row.path);
    }
    return result;
  }

  /// Inserts a new submission path row. Silently replaces on conflict.
  Future<void> insertSubmission({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paperNum,
    required String path,
  }) {
    return into(paperSubmissions).insertOnConflictUpdate(
      PaperSubmissionsCompanion.insert(
        school: schoolId,
        exam: examId,
        student: student,
        subject: subject,
        paperNum: Value(paperNum),
        path: path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Deletes a single submission path for a student.
  Future<void> deleteSubmission({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paperNum,
    required String path,
  }) {
    return (delete(paperSubmissions)..where(
          (s) =>
              s.school.equals(schoolId) &
              s.exam.equals(examId) &
              s.student.equals(student) &
              s.subject.equals(subject) &
              (paperNum == null
                  ? s.paperNum.isNull()
                  : s.paperNum.equals(paperNum)) &
              s.path.equals(path),
        ))
        .go();
  }

  /// Deletes all submission paths for a specific student + paper combination.
  Future<void> clearSubmissionsForStudent({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paperNum,
  }) {
    return (delete(paperSubmissions)..where(
          (s) =>
              s.school.equals(schoolId) &
              s.exam.equals(examId) &
              s.student.equals(student) &
              s.subject.equals(subject) &
              (paperNum == null
                  ? s.paperNum.isNull()
                  : s.paperNum.equals(paperNum)),
        ))
        .go();
  }

  String _generateExamId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = math.Random()
        .nextInt(0xFFFF)
        .toRadixString(16)
        .padLeft(4, '0');
    return 'ex_${now.toRadixString(36)}_$rand';
  }
}
