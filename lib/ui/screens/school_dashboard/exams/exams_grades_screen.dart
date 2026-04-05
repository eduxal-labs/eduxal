import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/exam_group.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/active_term_provider.dart';
import 'exam_list_view.dart';
import 'exam_group_detail_view.dart';
import 'exams_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level entry point for the Exams & Grades section.
///
/// Mounted from the dashboard shell under the "Exams & Grades" nav label
/// (teacher view) and the "Academics" → Exams tab (owner/staff view).
class ExamsGradesScreen extends StatelessWidget {
  const ExamsGradesScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    // Defense-in-depth: students and guardians should never reach this
    // admin-oriented exams screen. Nav routing should prevent it, but guard
    // here as well.
    final entry = schoolContext.currentEntry.value;
    if (entry is StudentEntry || entry is GuardianEntry) {
      return const RestrictedAccessState();
    }

    // Defense-in-depth: staff without exams.read permission cannot access
    // exam management. Nav routing should already hide the tab, but guard
    // here as well.
    if (entry is StaffEntry &&
        !schoolContext.permissions.can(Resource.exams, Action.read)) {
      return const RestrictedAccessState();
    }

    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const NoTermState();
    }
    return _ExamsShell(schoolContext: schoolContext, termContext: termCtx);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell — owns navigation state (exam list → exam detail → paper detail)
// ─────────────────────────────────────────────────────────────────────────────

enum _ExamsView { list, examDetail, paperDetail }

class _ExamsShell extends StatefulWidget {
  const _ExamsShell({required this.schoolContext, required this.termContext});
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_ExamsShell> createState() => _ExamsShellState();
}

class _ExamsShellState extends State<_ExamsShell> {
  _ExamsView _view = _ExamsView.list;
  ExamGroup? _selectedGroup;
  String? _selectedGroupKey;
  Exam? _selectedExamRow;
  Paper? _selectedPaper;
  SchoolConfig _config = SchoolConfig.defaults();
  Map<int, String> _subjectNames = {};
  late final ExamsGradesDao _dao;
  late final CatalogDao _catalogDao;
  StreamSubscription? _configSub;
  StreamSubscription? _subjectNamesSub;
  int? _selectedStreamIndex;
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _catalogDao = CatalogDao(db);
    _loadConfig();
    _loadSubjectNames();
  }

  Future<void> _loadSubjectNames() async {
    _subjectNamesSub = _catalogDao.watchSubjects().listen((subjects) {
      if (!mounted) return;
      setState(() {
        _subjectNames = {for (final s in subjects) s.id: s.name};
      });
    });
  }

  Future<void> _loadConfig() async {
    final schoolId = widget.schoolContext.membership.school.id;
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      allStreams,
    ) {
      if (!mounted) return;
      setState(() {
        _config = _buildConfigFromStreams(allStreams);
      });
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _subjectNamesSub?.cancel();
    super.dispose();
  }

  /// Builds a [SchoolConfig] from raw [SchoolStream] rows using the same
  /// curriculum-detection logic as the Academics screen.
  SchoolConfig _buildConfigFromStreams(List<SchoolStream> allStreams) {
    if (allStreams.isEmpty) return SchoolConfig.defaults();

    final allGrades = allStreams.map((s) => s.grade).toSet();

    // Group streams by grade.
    final byGrade = <int, List<SchoolStream>>{};
    for (final s in allStreams) {
      byGrade.putIfAbsent(s.grade, () => []).add(s);
    }

    CurriculumType curriculumForGrade(int grade) {
      if (grade >= 41) return CurriculumType.eightFourFour;
      if (grade >= 9) return CurriculumType.cbc;
      if (allGrades.any((g) => g >= 41)) return CurriculumType.eightFourFour;
      return CurriculumType.cbc;
    }

    final cbcGrades = <GradeConfig>[];
    final eftGrades = <GradeConfig>[];

    for (final entry in byGrade.entries) {
      final gradeNum = entry.key;
      final streamRows = entry.value
        ..sort((a, b) => a.stream.compareTo(b.stream));
      final gradeStreams = streamRows
          .map((s) => GradeStream(name: s.name, code: s.stream))
          .toList();
      final gc = GradeConfig(grade: gradeNum, streams: gradeStreams);

      if (curriculumForGrade(gradeNum) == CurriculumType.cbc) {
        cbcGrades.add(gc);
      } else {
        eftGrades.add(gc);
      }
    }

    cbcGrades.sort((a, b) => a.grade.compareTo(b.grade));
    eftGrades.sort((a, b) => a.grade.compareTo(b.grade));

    final curricula = <CurriculumConfig>[];
    if (cbcGrades.isNotEmpty) {
      curricula.add(
        CurriculumConfig(type: CurriculumType.cbc, grades: cbcGrades),
      );
    }
    if (eftGrades.isNotEmpty) {
      curricula.add(
        CurriculumConfig(type: CurriculumType.eightFourFour, grades: eftGrades),
      );
    }

    return SchoolConfig(curricula: curricula);
  }

  void _openExam(ExamGroup group) {
    setState(() {
      _selectedGroup = group;
      _selectedGroupKey = group.groupKey;
      _view = _ExamsView.examDetail;
    });
  }

  int? _selectedExamGrade;

  void _openPaper(Paper paper, Exam exam, int grade, {int streamIndex = 0}) {
    setState(() {
      _selectedPaper = paper;
      _selectedExamRow = exam;
      _selectedExamGrade = grade;
      _selectedStreamIndex = streamIndex;
      _view = _ExamsView.paperDetail;
    });
  }

  void _popToExam() {
    setState(() {
      _selectedPaper = null;
      _selectedExamRow = null;
      // Keep _selectedExamGrade and _selectedStreamIndex so the tabs restore
      _view = _ExamsView.examDetail;
    });
  }

  void _popToList() {
    setState(() {
      _selectedGroup = null;
      _selectedGroupKey = null;
      _selectedExamRow = null;
      _selectedPaper = null;
      _selectedExamGrade = null;
      _selectedStreamIndex = null;
      _selectedDayIndex = null;
      _view = _ExamsView.list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = widget.schoolContext.membership.school.id;
    final term = widget.termContext.currentTerm!;
    final entry = widget.schoolContext.currentEntry.value;

    // Teachers without admin exams.read permission only see exams they
    // participate in (as creator, invigilator, or subject teacher).
    String? teacherFilter;
    if (entry is TeacherEntry &&
        !widget.schoolContext.permissions.can(Resource.exams, Action.read)) {
      teacherFilter = entry.teacher.user;
    }

    return switch (_view) {
      _ExamsView.list => ExamsListView(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        schoolContext: widget.schoolContext,
        config: _config,
        subjectNames: _subjectNames,
        entry: entry,
        onExamTap: _openExam,
      ),
      _ExamsView.examDetail => StreamBuilder<List<ExamGroup>>(
        stream: _dao.watchExamGroups(
          schoolId: schoolId,
          year: term.year,
          term: term.term,
          teacherId: teacherFilter,
        ),
        builder: (context, snap) {
          final groups = snap.data ?? [];
          final match = groups
              .where((g) => g.groupKey == _selectedGroupKey)
              .firstOrNull;
          // Use the latest matching group from the stream, falling back to
          // the previously selected group (avoids null during loading).
          final group = match ?? _selectedGroup;
          if (group == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _popToList());
            return const SizedBox.shrink();
          }
          return ExamGroupDetailView(
            group: group,
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            config: _config,
            subjectNames: _subjectNames,
            entry: entry,
            schoolContext: widget.schoolContext,
            onBack: _popToList,
            onPaperTap: _openPaper,
            onDeleted: _popToList,
            onGroupKeyChanged: (newKey) {
              setState(() => _selectedGroupKey = newKey);
            },
            initialGradeIndex: () {
              if (_selectedExamGrade == null) return 0;
              final idx = group.grades.indexWhere(
                (g) => g.grade == _selectedExamGrade,
              );
              return idx >= 0 ? idx : 0;
            }(),
            initialStreamIndex: _selectedStreamIndex ?? 0,
            initialDayIndex: _selectedDayIndex ?? 0,
            onDayChanged: (index) {
              _selectedDayIndex = index;
            },
          );
        },
      ),
      _ExamsView.paperDetail => PaperDetailView(
        exam: (
          exam: _selectedExamRow!,
          teacher: _selectedGroup!.teacher,
          papers: const [],
        ),
        paper: _selectedPaper!,
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        grade:
            _selectedExamGrade ??
            (_selectedGroup!.grades.isNotEmpty
                ? _selectedGroup!.grades.first.grade
                : 0),
        config: _config,
        subjectNames: _subjectNames,
        schoolContext: widget.schoolContext,
        onBack: _popToExam,
      ),
    };
  }
}
