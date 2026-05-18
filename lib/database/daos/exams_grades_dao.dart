import 'dart:async';
import '../../cache/file_cache.dart' as eduxal_file_cache;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter/foundation.dart' show debugPrint;

import '../database.dart';
import '../tables/enums.dart';
import '../../models/exam_group.dart';
import '../tables/events.dart';
import '../tables/exams.dart';
import '../tables/grades.dart';
import '../tables/logs.dart';
import '../tables/mastery.dart';
import '../tables/papers.dart';
import '../tables/students.dart';
import '../tables/papers_v2.dart';
import '../tables/streams.dart';
import '../../client.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../tables/enrollments.dart';
import '../tables/subject_teachers.dart';

import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

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

/// A paper row together with its parent exam and the exam's teacher user.
typedef PaperWithExamInfo = ({
  Paper paper,
  Exam exam,
  UsersData teacher,
  String? serverPaperId,
});

/// Map [PaperV2Status] (0–6) to legacy [PaperStatus] (0–3).
PaperStatus _mapV2StatusToLegacy(PaperV2Status s) => switch (s) {
  PaperV2Status.draft || PaperV2Status.questionsSet => PaperStatus.pending,
  PaperV2Status.finalized ||
  PaperV2Status.revealed ||
  PaperV2Status.active => PaperStatus.progress,
  PaperV2Status.completed => PaperStatus.done,
  PaperV2Status.marked => PaperStatus.marked,
};

/// Map [PaperV2Type] to legacy [ExamType].
ExamType _mapV2TypeToExamType(PaperV2Type t) => switch (t) {
  PaperV2Type.assessment => ExamType.assessment,
  PaperV2Type.assignment => ExamType.assignment,
  _ => ExamType.exam,
};

/// Convert a standalone [PapersV2Data] row into the legacy [Paper]+[Exam] shape
/// so that existing UI (PaperDetailPage, subject tabs) can consume it.
({Paper paper, Exam exam}) _paperExamFromV2(PapersV2Data pv2) {
  final startSecs = pv2.date * 86400;
  final endSecs = startSecs + (pv2.durationMinutes * 60);
  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  final paper = Paper(
    school: pv2.school,
    exam: pv2.event ?? '',
    subject: pv2.subject,
    topic: null,
    paper: null,
    invigilator: pv2.teacher,
    start: BigInt.from(startSecs),
    end: BigInt.from(endSecs),
    status: _mapV2StatusToLegacy(pv2.status),
    grade: pv2.grade,
    stream: pv2.stream,
    timeAllowedMinutes: pv2.durationMinutes,
    customInstructions: pv2.instructions,
    created: pv2.created,
    updated: pv2.updated,
  );
  final exam = Exam(
    id: pv2.event ?? '',
    school: pv2.school,
    name: pv2.name,
    year: 0,
    term: 0,
    personalized: false,
    type: _mapV2TypeToExamType(pv2.type_),
    start: pv2.date,
    end: pv2.date + 1,
    teacher: pv2.teacher,
    created: pv2.created,
    updated: now,
  );
  return (paper: paper, exam: exam);
}

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
    Events,
    Exams,
    Papers,
    PapersV2,
    PaperSubmissions,
    Grades,
    Mastery,
    Students,
    Teachers,
    Users,
    Enrollments,
    SubjectTeachers,
    Streams,
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

  /// Emits papers for a specific grade + stream combination within one or
  /// more exam IDs.  When [stream] is `null`, returns papers where
  /// `papers.stream IS NULL` (grade-wide papers with no stream assignment).
  Stream<List<Paper>> watchPapersForExamGradeStream({
    required String schoolId,
    required List<String> examIds,
    required int grade,
    required int? stream,
  }) {
    return (select(papers)
          ..where(
            (p) =>
                p.school.equals(schoolId) &
                p.exam.isIn(examIds) &
                p.grade.equals(grade) &
                (stream != null ? p.stream.equals(stream) : p.stream.isNull()),
          )
          ..orderBy([
            (p) => OrderingTerm.asc(p.start),
            (p) => OrderingTerm.asc(p.subject),
            (p) => OrderingTerm.asc(p.paper),
          ]))
        .watch();
  }

  /// Emits papers for a specific subject+class combination, joined with their
  /// parent exam and the exam's teacher.  Optionally filtered by [examType]
  /// (0=exam, 1=assignment, 2=assessment).
  ///
  /// Sorted by paper start date ascending.
  Stream<List<PaperWithExamInfo>> watchPapersForSubjectClass({
    required String schoolId,
    required int grade,
    required int stream,
    required int subject,
    int? examType,
  }) {
    // Watch both legacy `papers` and `papers_v2` so that inserts into either
    // table trigger a re-emission.  This is essential because papers created
    // from SubjectDetailPage are written only to `papers_v2`.
    //
    // Returns a broadcast stream so multiple StreamBuilder widgets (e.g. in
    // different TabBarView tabs) can listen simultaneously.
    late final StreamController<List<PaperWithExamInfo>> controller;
    StreamSubscription? papersSub;
    StreamSubscription? pv2Sub;
    int _listenerCount = 0;

    Future<void> emit() async {
      final paperList =
          await (select(papers)..where(
                (p) =>
                    p.school.equals(schoolId) &
                    p.grade.equals(grade) &
                    p.stream.equals(stream) &
                    p.subject.equals(subject),
              ))
              .get();
      final pv2Rows =
          await (select(papersV2)..where(
                (t) =>
                    t.school.equals(schoolId) &
                    t.subject.equals(subject) &
                    t.grade.equals(grade) &
                    t.stream.equals(stream),
              ))
              .get();

      // ── Legacy exam lookup ──────────────────────────────────────────
      final examIds = paperList.map((p) => p.exam).toSet();
      final examRows = await (select(
        exams,
      )..where((e) => e.id.isIn(examIds))).get();
      final filteredExams = examType != null
          ? examRows.where((e) => e.type.index == examType).toList()
          : examRows;
      final examById = <String, Exam>{};
      for (final e in filteredExams) {
        examById[e.id] = e;
      }

      final teacherIds = filteredExams.map((e) => e.teacher).toSet();
      final userRows = await (select(
        users,
      )..where((u) => u.id.isIn(teacherIds))).get();
      final userById = <String, UsersData>{};
      for (final u in userRows) {
        userById[u.id] = u;
      }

      // Index papers_v2 by name for legacy matching.
      final pv2ByName = <String, PapersV2Data>{};
      for (final pv2 in pv2Rows) {
        pv2ByName[pv2.name] = pv2;
      }

      // ── Build merged result ─────────────────────────────────────────
      final result = <PaperWithExamInfo>[];
      final seenNames = <String>{};
      for (final paper in paperList) {
        final exam = examById[paper.exam];
        if (exam == null) continue;
        final teacher =
            userById[exam.teacher] ??
            UsersData(
              id: exam.teacher,
              phone: '',
              name: 'Unknown',
              email: null,
              level: UserLevel.normal,
              status: UserStatus.active,
              created: BigInt.zero,
              updated: BigInt.zero,
            );
        final pv2 = pv2ByName[exam.name];
        seenNames.add(exam.name);
        result.add((
          paper: paper,
          exam: exam,
          teacher: teacher,
          serverPaperId: pv2?.id,
        ));
      }

      // Add remaining papers_v2 rows that weren't matched to legacy records
      // above (e.g. synced from other devices, or standalone assessments).
      for (final pv2 in pv2Rows) {
        if (seenNames.contains(pv2.name)) continue;
        if (examType != null &&
            _mapV2TypeToExamType(pv2.type_).index != examType)
          continue;
        final (:paper, :exam) = _paperExamFromV2(pv2);
        final teacher = UsersData(
          id: pv2.teacher,
          phone: '',
          name: 'Unknown',
          email: null,
          level: UserLevel.normal,
          status: UserStatus.active,
          created: BigInt.zero,
          updated: BigInt.zero,
        );
        result.add((
          paper: paper,
          exam: exam,
          teacher: teacher,
          serverPaperId: pv2.id,
        ));
      }

      result.sort((a, b) => a.paper.start.compareTo(b.paper.start));
      controller.add(result);
    }

    controller = StreamController<List<PaperWithExamInfo>>.broadcast(
      onListen: () {
        _listenerCount++;
        if (_listenerCount == 1) {
          emit();
          papersSub =
              (select(papers)..where(
                    (p) =>
                        p.school.equals(schoolId) &
                        p.grade.equals(grade) &
                        p.stream.equals(stream) &
                        p.subject.equals(subject),
                  ))
                  .watch()
                  .listen((_) => emit());
          pv2Sub =
              (select(papersV2)..where(
                    (t) =>
                        t.school.equals(schoolId) &
                        t.subject.equals(subject) &
                        t.grade.equals(grade) &
                        t.stream.equals(stream),
                  ))
                  .watch()
                  .listen((_) => emit());
        }
      },
      onCancel: () {
        _listenerCount--;
        if (_listenerCount <= 0) {
          _listenerCount = 0;
          papersSub?.cancel();
          pv2Sub?.cancel();
        }
      },
    );

    return controller.stream;
  }

  /// One-shot version of [watchPapersForSubjectClass].
  Future<List<PaperWithExamInfo>> getPapersForSubjectClass({
    required String schoolId,
    required int grade,
    required int stream,
    required int subject,
    int? examType,
  }) async {
    final paperList =
        await (select(papers)
              ..where(
                (p) =>
                    p.school.equals(schoolId) &
                    p.grade.equals(grade) &
                    p.stream.equals(stream) &
                    p.subject.equals(subject),
              )
              ..orderBy([(p) => OrderingTerm.asc(p.start)]))
            .get();

    if (paperList.isEmpty) return [];

    final examIds = paperList.map((p) => p.exam).toSet();
    final examRows = await (select(
      exams,
    )..where((e) => e.id.isIn(examIds))).get();

    final filteredExams = examType != null
        ? examRows.where((e) => e.type.index == examType).toList()
        : examRows;

    final examById = <String, Exam>{};
    for (final e in filteredExams) {
      examById[e.id] = e;
    }

    final teacherIds = filteredExams.map((e) => e.teacher).toSet();
    final userRows = await (select(
      users,
    )..where((u) => u.id.isIn(teacherIds))).get();
    final userById = <String, UsersData>{};
    for (final u in userRows) {
      userById[u.id] = u;
    }

    // Load papers_v2 rows to resolve server paper UUIDs and include
    // standalone papers (event IS NULL) that have no legacy entry.
    final pv2Rows =
        await (select(papersV2)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.subject.equals(subject) &
                  t.grade.equals(grade) &
                  t.stream.equals(stream),
            ))
            .get();
    final pv2ByName = <String, PapersV2Data>{};
    for (final pv2 in pv2Rows) {
      pv2ByName[pv2.name] = pv2;
    }

    final result = <PaperWithExamInfo>[];
    final seenNames = <String>{};
    for (final paper in paperList) {
      final exam = examById[paper.exam];
      if (exam == null) continue;
      final teacher =
          userById[exam.teacher] ??
          UsersData(
            id: exam.teacher,
            phone: '',
            name: 'Unknown',
            email: null,
            level: UserLevel.normal,
            status: UserStatus.active,
            created: BigInt.zero,
            updated: BigInt.zero,
          );
      final pv2 = pv2ByName[exam.name];
      seenNames.add(exam.name);
      result.add((
        paper: paper,
        exam: exam,
        teacher: teacher,
        serverPaperId: pv2?.id,
      ));
    }

    // Add remaining papers_v2 rows not already covered.
    for (final pv2 in pv2Rows) {
      if (seenNames.contains(pv2.name)) continue;
      if (examType != null && _mapV2TypeToExamType(pv2.type_).index != examType)
        continue;
      final (:paper, :exam) = _paperExamFromV2(pv2);
      final teacher = UsersData(
        id: pv2.teacher,
        phone: '',
        name: 'Unknown',
        email: null,
        level: UserLevel.normal,
        status: UserStatus.active,
        created: BigInt.zero,
        updated: BigInt.zero,
      );
      result.add((
        paper: paper,
        exam: exam,
        teacher: teacher,
        serverPaperId: pv2.id,
      ));
    }
    return result;
  }

  /// Watches all distinct streams that have papers for a given [grade] within
  /// the supplied [examIds].  Joins with the `streams` table to resolve
  /// human-readable names.
  ///
  /// Returns a list of `({int? streamCode, String? streamName})` sorted by
  /// stream code ascending.  A `null` streamCode entry means there are
  /// grade-wide papers with no stream assigned.
  Stream<List<({int? streamCode, String? streamName})>>
  watchStreamsWithPapersForGrade({
    required String schoolId,
    required List<String> examIds,
    required int grade,
  }) {
    // Watch both papers and streams tables.  We manually combine the two
    // watches so the output re-emits when *either* table changes (e.g. a
    // paper is added OR a stream is renamed).
    final papersWatch =
        (select(papers)..where(
              (p) =>
                  p.school.equals(schoolId) &
                  p.exam.isIn(examIds) &
                  p.grade.equals(grade),
            ))
            .watch();

    final streamsWatch = (select(
      streams,
    )..where((s) => s.school.equals(schoolId) & s.grade.equals(grade))).watch();

    // Manual combineLatest — stores latest emission from each source and
    // recomputes the result whenever either fires.
    late final StreamController<List<({int? streamCode, String? streamName})>>
    controller;

    List<Paper>? latestPapers;
    List<SchoolStream>? latestStreams;
    StreamSubscription? papersSub;
    StreamSubscription? streamsSub;

    void emit() {
      final pRows = latestPapers;
      final sRows = latestStreams;
      if (pRows == null || sRows == null) return;

      // Check if any papers exist with stream = null (grade-wide).
      final hasGradeWide = pRows.any((p) => p.stream == null);

      // Build the result from ALL streams defined for this grade in the
      // streams table — not just those that already have papers.  This
      // ensures every stream tab is visible so the user can navigate to
      // it (even if it's empty / papers haven't been added yet).
      final result = <({int? streamCode, String? streamName})>[];

      // If there are grade-wide papers (stream IS NULL), show them first.
      if (hasGradeWide) {
        result.add((streamCode: null, streamName: null));
      }

      // Add every stream from the streams table, sorted by code ascending.
      final sortedStreams = List<SchoolStream>.from(sRows)
        ..sort((a, b) => a.stream.compareTo(b.stream));
      for (final s in sortedStreams) {
        result.add((streamCode: s.stream, streamName: s.name));
      }

      controller.add(result);
    }

    controller =
        StreamController<List<({int? streamCode, String? streamName})>>(
          onListen: () {
            papersSub = papersWatch.listen((rows) {
              latestPapers = rows;
              emit();
            });
            streamsSub = streamsWatch.listen((rows) {
              latestStreams = rows;
              emit();
            });
          },
          onCancel: () {
            papersSub?.cancel();
            streamsSub?.cancel();
          },
        );

    return controller.stream;
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

  /// Returns the school ID for [examId], or null if the exam is not found
  /// locally.
  ///
  /// Used by [AuthorizationService] to resolve the organisation context for
  /// [SyncAction.updateExam] and [SyncAction.deleteExam].
  Future<String?> getSchoolForExam(String examId) async {
    final row = await (select(
      exams,
    )..where((t) => t.id.equals(examId))).getSingleOrNull();
    return row?.school;
  }

  /// Returns a single paper (by composite key), or null.
  Future<Paper?> getPaper({
    required String schoolId,
    required String examId,
    required int subject,
    int? paper,
    required int grade,
    required int? stream,
  }) {
    return (select(papers)..where(
          (p) =>
              p.school.equals(schoolId) &
              p.exam.equals(examId) &
              p.subject.equals(subject) &
              (paper == null ? p.paper.isNull() : p.paper.equals(paper)) &
              p.grade.equals(grade) &
              (stream != null ? p.stream.equals(stream) : p.stream.isNull()),
        ))
        .getSingleOrNull();
  }

  /// Watches a single paper row, emitting null if it is deleted.
  /// All six composite PK columns must be specified for a unique match.
  Stream<Paper?> watchPaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
    required int grade,
    required int? stream,
  }) {
    final query = select(papers)
      ..where(
        (p) =>
            p.school.equals(schoolId) &
            p.exam.equals(examId) &
            p.subject.equals(subject) &
            (paperNum == null ? p.paper.isNull() : p.paper.equals(paperNum)) &
            p.grade.equals(grade) &
            (stream != null ? p.stream.equals(stream) : p.stream.isNull()),
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

  /// Reactive version of [getEnrolledStudents]. Returns a stream that
  /// re-emits whenever the underlying enrollment or student rows change.
  Stream<List<StudentsData>> watchEnrolledStudents({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    int? stream, // null → all streams
  }) {
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

    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(students)).toList(),
    );
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
    final _authResult = await authorization.check(
      action: SyncAction.createExam,
      schoolId: exam.school.value,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
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
    final _authResult = await authorization.check(
      action: SyncAction.createExam,
      schoolId: exam.school.value,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
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

  /// Updates mutable exam fields and writes a [SyncAction.updateExam] log entry.
  Future<void> updateExam({
    required String examId,
    required ExamsCompanion changes,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateExam,
      schoolId: null,
      recordId: examId,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
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

  Future<List<String>> getServerEventIds({
    required String schoolId,
    required String examId,
  }) async {
    final query = select(events)
      ..where((e) => e.school.equals(schoolId) & e.id.equals(examId));
    final eventList = await query.get();
    return eventList
        .map((e) => e.id)
        .toList(); // Actually examId is eventId here
  }

  /// Deletes an exam (cascades to papers and grades via FK) and writes a
  /// [SyncAction.deleteExam] log entry.
  Future<void> deleteExam({
    required String examId,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteExam,
      schoolId: null,
      recordId: examId,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      // Manually cascade-delete child rows. SQLite's ON DELETE CASCADE
      // requires PRAGMA foreign_keys = ON on the active connection, which
      // is not guaranteed inside Drift transactions. Explicit deletes are
      // reliable regardless of PRAGMA state.
      // Order: grades → paper_submissions → papers → exams
      // (mastery is per-student/subject/topic — not linked to exams)
      await (delete(grades)..where((g) => g.exam.equals(examId))).go();
      await (delete(
        paperSubmissions,
      )..where((ps) => ps.exam.equals(examId))).go();
      await (delete(papers)..where((p) => p.exam.equals(examId))).go();
      await (delete(exams)..where((e) => e.id.equals(examId))).go();
      await (delete(papersV2)..where((p) => p.event.equals(examId))).go();
      await (delete(events)..where((e) => e.id.equals(examId))).go();
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
    int? timeAllowedMinutes,
    String? customInstructions,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createPaper,
      schoolId: paper.school.value,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    // Merge optional new fields into the companion before inserting.
    final fullPaper = paper.copyWith(
      timeAllowedMinutes: Value(timeAllowedMinutes),
      customInstructions: Value(customInstructions),
    );
    await transaction(() async {
      await into(papers).insert(fullPaper);
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
      if (timeAllowedMinutes != null) {
        payload.timeAllowedMinutes = timeAllowedMinutes;
      }
      if (customInstructions != null) {
        payload.instructions = customInstructions;
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
    required int grade,
    required int? stream,
    required PapersCompanion changes,
    required String accountId,
    int? timeAllowedMinutes,
    String? customInstructions,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updatePaper,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      // Merge optional new fields into the changes companion.
      var resolvedChanges = changes;
      if (timeAllowedMinutes != null) {
        resolvedChanges = resolvedChanges.copyWith(
          timeAllowedMinutes: Value(timeAllowedMinutes),
        );
      }
      if (customInstructions != null) {
        resolvedChanges = resolvedChanges.copyWith(
          customInstructions: Value(customInstructions),
        );
      }

      debugPrint(
        '[updatePaper] WHERE school=$schoolId, exam=$examId, subject=$subject, '
        'paper=$paperNum, grade=$grade, stream=$stream | '
        'changes: ${resolvedChanges.toColumns(false).keys.join(', ')}',
      );

      final affected =
          await (update(papers)..where(
                (p) =>
                    p.school.equals(schoolId) &
                    p.exam.equals(examId) &
                    p.subject.equals(subject) &
                    (paperNum == null
                        ? p.paper.isNull()
                        : p.paper.equals(paperNum)) &
                    p.grade.equals(grade) &
                    (stream != null
                        ? p.stream.equals(stream)
                        : p.stream.isNull()),
              ))
              .write(resolvedChanges);

      debugPrint('[updatePaper] Rows affected: $affected');

      final payload = sync_pb.UpdatePaperPayload(
        school: schoolId,
        exam: examId,
        subject: subject,
        grade: grade,
      );
      if (paperNum != null) payload.paper = paperNum;
      if (stream != null) payload.stream = stream;
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
      // grade and stream are already set above as identifying fields.
      // If the caller is *changing* the grade or stream value itself,
      // that still counts as a meaningful change for the log entry.
      if (changes.grade.present && changes.grade.value != grade) {
        payload.grade = changes.grade.value;
        hasChanges = true;
      }
      if (changes.stream.present && changes.stream.value != stream) {
        if (changes.stream.value != null) {
          payload.stream = changes.stream.value!;
        }
        hasChanges = true;
      }
      if (timeAllowedMinutes != null) {
        payload.timeAllowedMinutes = timeAllowedMinutes;
        hasChanges = true;
      }
      if (customInstructions != null) {
        payload.instructions = customInstructions;
        hasChanges = true;
      }
    });
    sync.schedulePush();
  }

  Future<String?> getServerPaperId({
    required String schoolId,
    required String examId,
    required int subject,
    required int grade,
    int? stream,
  }) async {
    final query = select(papersV2)
      ..where(
        (p) =>
            p.school.equals(schoolId) &
            p.event.equals(examId) &
            p.subject.equals(subject) &
            p.grade.equals(grade) &
            (stream == null ? p.stream.isNull() : p.stream.equals(stream)),
      );
    final result = await query.getSingleOrNull();
    return result?.id;
  }

  /// Deletes a paper (cascades to grades) and writes a [SyncAction.deletePaper]
  /// log entry.
  ///
  /// When [serverPaperId] is provided, also deletes from [papersV2] so that
  /// papers created via direct RPC (SubjectDetailPage) are cleaned up locally.
  Future<void> deletePaper({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
    required int grade,
    required int? stream,
    required String accountId,
    String? serverPaperId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deletePaper,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.DeletePaperPayload(
        school: schoolId,
        exam: examId,
        subject: subject,
        grade: grade,
      );
      if (paperNum != null) payload.paper = paperNum;
      await (delete(papers)..where(
            (p) =>
                p.school.equals(schoolId) &
                p.exam.equals(examId) &
                p.subject.equals(subject) &
                (paperNum == null
                    ? p.paper.isNull()
                    : p.paper.equals(paperNum)) &
                p.grade.equals(grade) &
                (stream != null ? p.stream.equals(stream) : p.stream.isNull()),
          ))
          .go();
      if (serverPaperId != null) {
        await (delete(papersV2)..where((t) => t.id.equals(serverPaperId))).go();
      }
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
    final _authResult = await authorization.check(
      action: SyncAction.markGrades,
      schoolId: grade.school.value,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
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
    final _authResult = await authorization.check(
      action: SyncAction.deleteGrade,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
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
    final _authResult = await authorization.check(
      action: SyncAction.updateMastery,
      schoolId: entry.school.value,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
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
  ///
  /// When [teacherId] is non-null, the result is filtered to only include
  /// groups where the teacher participates as:
  /// - the exam creator (`exams.teacher`),
  /// - an invigilator on any paper (`papers.invigilator`), or
  /// - a subject teacher for any paper's subject (`subject_teachers`).
  // TODO(perf): When teacherId is non-null, this method loads ALL exams for
  // the term and filters in Dart after joining papers + subject_teachers.
  // Ideally the initial exam query would be narrowed via SQL (e.g. EXISTS
  // subquery on papers.invigilator or subject_teachers.teacher), but Drift's
  // query builder makes that difficult without raw SQL. Acceptable for now
  // given typical term exam counts (< 50), but revisit if performance
  // degrades on large schools.
  Stream<List<ExamGroup>> watchExamGroups({
    required String schoolId,
    required int year,
    required int term,
    String? teacherId,
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
        final key = exam.name;
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
            name: firstExam.name,
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

      // ── Teacher-scoped filter ────────────────────────────────────────
      if (teacherId != null) {
        // Fetch the set of subject IDs this teacher is assigned to for
        // the current (school, year, term). Used to match papers whose
        // subject the teacher teaches even if they are not the creator
        // or invigilator.
        final stRows =
            await (select(subjectTeachers)..where(
                  (st) =>
                      st.school.equals(schoolId) &
                      st.year.equals(year) &
                      st.term.equals(term) &
                      st.teacher.equals(teacherId),
                ))
                .get();
        final teacherSubjectIds = stRows.map((r) => r.subject).toSet();

        result.removeWhere((group) {
          // Keep if teacher created any exam in the group.
          if (group.teacher.id == teacherId) return false;
          // Check papers across all grades/streams.
          for (final ge in group.grades) {
            for (final se in ge.streams) {
              for (final p in se.papers) {
                if (p.invigilator == teacherId) return false;
                if (teacherSubjectIds.contains(p.subject)) return false;
              }
            }
          }
          // No match — remove from results.
          return true;
        });
      }

      // Sort by start descending (most recent first)
      result.sort((a, b) => b.start.compareTo(a.start));
      return result;
    });
  }

  /// Updates the date range for ALL exam rows in a group atomically.
  /// Used when extending an exam's date range — all rows sharing the
  /// same name within (school, year, term) must stay in sync.
  Future<void> updateExamGroupDateRange({
    required String schoolId,
    required int year,
    required int term,
    required String examName,
    required int newStart,
    required int newEnd,
    required String accountId,
  }) async {
    await transaction(() async {
      // Find all exam IDs matching the group by name
      final matching =
          await (select(exams)..where(
                (e) =>
                    e.school.equals(schoolId) &
                    e.year.equals(year) &
                    e.term.equals(term) &
                    e.name.equals(examName),
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
    final localQuery = select(paperSubmissions)
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
    final localRows = await localQuery.get();

    final map = <int, List<String>>{};
    final baseDir = await eduxal_file_cache.FileCache.baseDir();

    final serverRows = await customSelect(
      'SELECT school, exam, student, subject, paper, page, key FROM answer_pages WHERE school = ? AND exam = ? AND subject = ? AND (paper IS NULL OR paper = ?) ORDER BY page ASC',
      variables: [
        Variable.withString(schoolId),
        Variable.withString(examId),
        Variable.withInt(subject),
        Variable.withInt(paperNum ?? 0),
      ],
    ).get();

    for (final row in serverRows) {
      final student = row.read<int>('student');
      final page = row.read<int>('page');
      final school = row.read<String>('school');
      final exam = row.read<String>('exam');
      final subj = row.read<int>('subject');
      final paper = row.read<int?>('paper');
      final paperStr = paper ?? 0;
      final localPath = '$baseDir/submissions/$school/$exam/${subj}_$paperStr/students/$student/$page.jpg';
      map.putIfAbsent(student, () => []).add(localPath);
    }
    
    // Add local-only rows (e.g. ones waiting to be AI marked/uploaded)
    for (final row in localRows) {
      map.putIfAbsent(row.student, () => []).add(row.path);
    }
    
    // Dedup and sort numerically by page index (not lexicographically,
    // so 2.jpg comes before 10.jpg).
    for (final key in map.keys) {
      final paths = map[key]!.toSet().toList();
      paths.sort((a, b) {
        final aPage = _extractPageIndex(a);
        final bPage = _extractPageIndex(b);
        return aPage.compareTo(bPage);
      });
      map[key] = paths;
    }
    return map;
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

  /// Deletes all local [AnswerPages] rows for a specific student + paper.
  ///
  /// Used by the answer sheet save flow to immediately reflect user deletions
  /// before the server sync round-trip completes. Without this,
  /// [getSubmissionsForPaper] (which merges answer_pages + paperSubmissions)
  /// would still return server-stale rows and resurrect deleted images.
  Future<void> deleteAnswerPagesLocally({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paperNum,
  }) async {
    await customStatement(
      'DELETE FROM answer_pages WHERE school = ? AND exam = ? AND student = ?'
      ' AND subject = ? AND (paper IS NULL OR paper = ?)',
      [schoolId, examId, student, subject, paperNum ?? 0],
    );
  }

  /// Writes a local placeholder row into [MarkingQueue] so the
  /// [MarkingStatusIndicator] shows "Queued for marking..." immediately
  /// after [markPaper] succeeds, before the server sync delivers the
  /// authoritative row.  The server row will overwrite this placeholder
  /// (ON CONFLICT by paper PK) when the delta arrives.
  Future<void> insertMarkingQueuePlaceholder({
    required String paperId,
  }) async {
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await customStatement(
      'INSERT OR IGNORE INTO marking_queue (id, paper, phase, progress,'
      ' total_students, marked_students, created, updated)'
      ' VALUES (0, ?, 0, \'Queued for marking...\', 0, 0, ?, ?)',
      [paperId, now.toInt(), now.toInt()],
    );
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

  // ───────────────────────────────────────────────────────────────────────────
  // Sync log helpers — scheme pages & answer pages file sync
  // ───────────────────────────────────────────────────────────────────────────

  /// Logs an [uploadScheme] sync action for the given paper's marking scheme.
  ///
  /// Called after the user adds or replaces scheme files locally.
  /// [count] is the total number of scheme pages after the change.
  Future<void> logUploadScheme({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paper,
    required int count,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.uploadScheme,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    final payload = sync_pb.UploadSchemePayload()
      ..school = schoolId
      ..exam = examId
      ..subject = subject
      ..count = count;
    if (paper != null) payload.paper = paper;

    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await into(logs).insert(
      LogsCompanion(
        account: Value(accountId),
        action: Value(SyncAction.uploadScheme),
        resource: Value('Marking scheme'),
        payload: Value(payload.writeToBuffer()),
        created: Value(now),
      ),
    );
    sync.schedulePush();
  }

  /// Logs a [deleteScheme] sync action.
  ///
  /// Called when the user removes all scheme files for a paper.
  Future<void> logDeleteScheme({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paper,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteScheme,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    final payload = sync_pb.DeleteSchemePayload()
      ..school = schoolId
      ..exam = examId
      ..subject = subject;
    if (paper != null) payload.paper = paper;

    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await into(logs).insert(
      LogsCompanion(
        account: Value(accountId),
        action: Value(SyncAction.deleteScheme),
        resource: Value('Marking scheme'),
        payload: Value(payload.writeToBuffer()),
        created: Value(now),
      ),
    );
    sync.schedulePush();
  }

  /// Removes any pending [uploadAnswerSheet] or [deleteAnswerSheet] log entries
  /// for the given student + subject combination.
  ///
  /// Called before inserting a new upload/delete log so that only the latest
  /// user intent is sent to the server. Without this, rapid add/remove cycles
  /// create multiple queued actions whose watch-stream echoes can resurrect
  /// files the user already deleted.
  Future<void> _coalesceAnswerSheetLogs({
    required String accountId,
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
  }) async {
    // Query all pending answer-sheet logs for this account.
    final pending =
        await (select(logs)..where(
              (t) =>
                  t.account.equals(accountId) &
                  t.status.equalsValue(LogStatus.pending) &
                  (t.action.equalsValue(SyncAction.uploadAnswerSheet) |
                      t.action.equalsValue(SyncAction.deleteAnswerSheet)),
            ))
            .get();

    final idsToDelete = <int>[];
    for (final row in pending) {
      try {
        if (row.action == SyncAction.uploadAnswerSheet) {
          final p = sync_pb.UploadAnswerSheetPayload.fromBuffer(row.payload);
          if (p.school == schoolId &&
              p.exam == examId &&
              p.student == student &&
              p.subject == subject) {
            idsToDelete.add(row.id);
          }
        } else {
          final p = sync_pb.DeleteAnswerSheetPayload.fromBuffer(row.payload);
          if (p.school == schoolId &&
              p.exam == examId &&
              p.student == student &&
              p.subject == subject) {
            idsToDelete.add(row.id);
          }
        }
      } catch (_) {
        // Malformed payload — skip
      }
    }

    if (idsToDelete.isNotEmpty) {
      await (delete(logs)..where((t) => t.id.isIn(idsToDelete))).go();
      debugPrint(
        '[ExamsGradesDao] Coalesced ${idsToDelete.length} stale '
        'answer-sheet log(s) for student $student',
      );
    }
  }

  /// Logs an [uploadAnswerSheet] sync action for a student's answer pages.
  ///
  /// Called after the user adds or replaces answer sheet files locally.
  /// [count] is the total number of answer pages after the change.
  Future<void> logUploadAnswerSheet({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paper,
    required int count,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.uploadAnswerSheet,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    // Coalesce: remove any pending upload/delete answer-sheet logs for the
    // same (school, exam, student, subject) so only the latest intent is sent.
    await _coalesceAnswerSheetLogs(
      accountId: accountId,
      schoolId: schoolId,
      examId: examId,
      student: student,
      subject: subject,
    );

    final payload = sync_pb.UploadAnswerSheetPayload()
      ..school = schoolId
      ..exam = examId
      ..student = student
      ..subject = subject
      ..count = count;
    if (paper != null) payload.paper = paper;

    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await into(logs).insert(
      LogsCompanion(
        account: Value(accountId),
        action: Value(SyncAction.uploadAnswerSheet),
        resource: Value('Answer sheet — student $student'),
        payload: Value(payload.writeToBuffer()),
        created: Value(now),
      ),
    );
    sync.schedulePush();
  }

  /// Logs a [deleteAnswerSheet] sync action.
  ///
  /// Called when the user removes all answer sheet files for a student's paper.
  Future<void> logDeleteAnswerSheet({
    required String schoolId,
    required String examId,
    required int student,
    required int subject,
    required int? paper,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteAnswerSheet,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    // Coalesce: remove any pending upload/delete answer-sheet logs for the
    // same (school, exam, student, subject) so only the latest intent is sent.
    await _coalesceAnswerSheetLogs(
      accountId: accountId,
      schoolId: schoolId,
      examId: examId,
      student: student,
      subject: subject,
    );

    final payload = sync_pb.DeleteAnswerSheetPayload()
      ..school = schoolId
      ..exam = examId
      ..student = student
      ..subject = subject;
    if (paper != null) payload.paper = paper;

    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await into(logs).insert(
      LogsCompanion(
        account: Value(accountId),
        action: Value(SyncAction.deleteAnswerSheet),
        resource: Value('Answer sheet — student $student'),
        payload: Value(payload.writeToBuffer()),
        created: Value(now),
      ),
    );
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PapersV2 — new server-aligned schema (migration 0007)
  // ─────────────────────────────────────────────────────────────────────────

  /// Insert a single row into the new [PapersV2] table.
  Future<void> insertPaperV2(PapersV2Companion companion) async {
    await into(papersV2).insert(companion);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Events — new server-aligned schema (migration 0007)
  // ─────────────────────────────────────────────────────────────────────────

  /// Insert a row into the new [Events] table and the legacy [Exams] table
  /// in one transaction. No sync logs — the event was created on the server
  /// via [PaperService.createEvent] RPC.
  Future<void> insertEventWithLegacyExam({
    required EventsCompanion event,
    required ExamsCompanion exam,
  }) async {
    await transaction(() async {
      await into(events).insert(event);
      await into(exams).insert(exam);
    });
  }

  /// Insert a single paper into the legacy [Papers] table without sync logs.
  Future<void> insertLegacyPaper(PapersCompanion companion) async {
    await into(papers).insert(companion);
  }

  /// Look up a single paper in [PapersV2] by server-issued UUID.
  Future<PapersV2Data?> getPaperV2ById(String serverPaperId) async {
    final rows = await (select(
      papersV2,
    )..where((t) => t.id.equals(serverPaperId))).get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Update the status of a paper in [PapersV2] after generation completes.
  Future<void> updatePaperStatusAfterGeneration({
    required String serverPaperId,
  }) async {
    await (update(papersV2)..where((t) => t.id.equals(serverPaperId))).write(
      PapersV2Companion(status: const Value(PaperV2Status.questionsSet)),
    );
  }

  /// Update paper start/end times in both legacy [Papers] and [PapersV2].
  ///
  /// [start] and [end] are seconds since epoch for the legacy table.
  /// [durationMinutes] and [date] (days since epoch) are for papers_v2.
  ///
  /// The server update is handled by the caller via direct RPC
  /// ([PaperService.updatePaper]), so this method only updates local tables
  /// and does not write a sync log entry.
  Future<void> updatePaperTimes({
    required String schoolId,
    required String examId,
    required int subject,
    required int? paperNum,
    required int grade,
    required int? stream,
    required int start,
    required int end,
    required int date,
    required int durationMinutes,
    required String serverPaperId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // Update legacy papers table.
      await customStatement(
        'UPDATE papers SET start = ?, "end" = ?, updated = ?'
        ' WHERE school = ? AND exam = ? AND subject = ?'
        ' AND (paper IS NULL OR paper = ?)'
        ' AND grade = ?'
        ' AND (stream IS NULL OR stream = ?)',
        [
          start,
          end,
          now,
          schoolId,
          examId,
          subject,
          paperNum ?? 0,
          grade,
          stream ?? 0,
        ],
      );

      // Update papers_v2 using the server-issued UUID.
      if (serverPaperId.isNotEmpty) {
        await (update(
          papersV2,
        )..where((t) => t.id.equals(serverPaperId))).write(
          PapersV2Companion(
            date: Value(date),
            durationMinutes: Value(durationMinutes),
          ),
        );
      }
    });
  }
}

/// Extracts the numeric page index from an answer-sheet file path.
/// Paths end with `/{page}.jpg` (e.g. `.../students/101/0.jpg` → 0).
int _extractPageIndex(String path) {
  final lastSlash = path.lastIndexOf('/');
  final filename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  final lastDot = filename.lastIndexOf('.');
  final base = lastDot >= 0 ? filename.substring(0, lastDot) : filename;
  return int.tryParse(base) ?? 0;
}
