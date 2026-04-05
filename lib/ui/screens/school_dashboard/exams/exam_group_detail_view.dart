import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../core/formatters.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/exam_group.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../academics/paper_detail_page.dart';
import 'add_grade_to_exam_sheet.dart';
import 'create_paper_sheet.dart';
import 'exams_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExamGroupDetailView
// ─────────────────────────────────────────────────────────────────────────────

class ExamGroupDetailView extends StatefulWidget {
  const ExamGroupDetailView({
    super.key,
    required this.group,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.subjectNames,
    required this.entry,
    required this.schoolContext,
    required this.onBack,
    required this.onPaperTap,
    required this.onDeleted,
    this.initialGradeIndex = 0,
    this.initialStreamIndex = 0,
    this.initialDayIndex = 0,
    this.onDayChanged,
    this.onGroupKeyChanged,
  });
  final ExamGroup group;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final MembershipEntry entry;
  final SchoolContext schoolContext;
  final VoidCallback onBack;
  final void Function(Paper paper, Exam exam, int grade, {int streamIndex})
  onPaperTap;
  final VoidCallback onDeleted;
  final int initialGradeIndex;
  final int initialStreamIndex;
  final int initialDayIndex;
  final ValueChanged<int>? onDayChanged;
  final ValueChanged<String>? onGroupKeyChanged;

  @override
  State<ExamGroupDetailView> createState() => _ExamGroupDetailViewState();
}

class _ExamGroupDetailViewState extends State<ExamGroupDetailView>
    with TickerProviderStateMixin {
  late TabController _gradeTabController;
  int _selectedGradeIndex = 0;
  TabController? _streamTabController;
  int _selectedStreamIndex = 0;
  late final ExamsGradesDao _dao;
  late final MembersDao _membersDao;
  Map<String, String> _teacherNames = {};

  /// Reactive list of streams that have papers for the currently selected
  /// grade.  Populated by [_subscribeToStreams] via [watchStreamsWithPapersForGrade].
  List<({int? streamCode, String? streamName})> _streamEntries = [];
  StreamSubscription? _streamSub;

  // ── Teacher subject restriction (only populated for TeacherEntry) ───────
  List<SubjectTeacher> _teacherSubjects = [];
  StreamSubscription? _teacherSubjectsSub;

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _membersDao = MembersDao(db);
    _selectedGradeIndex = widget.initialGradeIndex.clamp(
      0,
      (widget.group.grades.length - 1).clamp(0, 999),
    );
    _selectedStreamIndex = widget.initialStreamIndex;
    _gradeTabController =
        TabController(
          length: widget.group.grades.length,
          initialIndex: _selectedGradeIndex,
          vsync: this,
        )..addListener(() {
          if (_gradeTabController.indexIsChanging) return;
          _onGradeTabChanged(_gradeTabController.index);
        });
    _subscribeToStreams();
    _loadTeacherNames();
    _subscribeToTeacherSubjects();
  }

  @override
  void didUpdateWidget(covariant ExamGroupDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.groupKey != widget.group.groupKey) {
      _gradeTabController.removeListener(() {});
      _gradeTabController.dispose();
      _selectedGradeIndex = 0;
      _selectedStreamIndex = 0;
      _gradeTabController =
          TabController(
            length: widget.group.grades.length,
            initialIndex: 0,
            vsync: this,
          )..addListener(() {
            if (_gradeTabController.indexIsChanging) return;
            _onGradeTabChanged(_gradeTabController.index);
          });
      _subscribeToStreams();
      _loadTeacherNames();
    } else {
      // Same group key but data may have changed (e.g. grades list grew).
      // Re-subscribe if the selected grade's exam IDs changed.
      _subscribeToStreams();
    }
  }

  @override
  void dispose() {
    _gradeTabController.dispose();
    _streamTabController?.dispose();
    _streamSub?.cancel();
    _teacherSubjectsSub?.cancel();
    super.dispose();
  }

  /// Subscribe to the teacher's subject assignments for the current term.
  /// Only active when the current entry is a [TeacherEntry].
  void _subscribeToTeacherSubjects() {
    _teacherSubjectsSub?.cancel();
    final entry = widget.entry;
    if (entry is TeacherEntry) {
      _teacherSubjectsSub = _membersDao
          .watchTeacherSubjectsForTerm(
            widget.schoolId,
            entry.teacher.user,
            year: widget.year,
            term: widget.term,
          )
          .listen((subjects) {
            if (mounted) setState(() => _teacherSubjects = subjects);
          });
    }
  }

  /// Whether the teacher teaches at least one subject for the currently
  /// selected grade/stream.  Always returns `true` for non-teacher entries.
  bool get _teacherHasSubjectsForCurrentSelection {
    if (widget.entry is! TeacherEntry) return true;
    final grades = widget.group.grades;
    if (grades.isEmpty) return false;
    final currentGrade = grades[_selectedGradeIndex].grade;
    final stream = _currentStreamCode;
    return _teacherSubjects.any(
      (st) =>
          st.grade == currentGrade && (stream == null || st.stream == stream),
    );
  }

  void _onGradeTabChanged(int index) {
    setState(() {
      _selectedGradeIndex = index;
      _selectedStreamIndex = 0;
    });
    _subscribeToStreams();
  }

  /// Subscribes to [ExamsGradesDao.watchStreamsWithPapersForGrade] for the
  /// currently selected grade.  Whenever the DB changes (papers added/removed,
  /// streams renamed) the stream tabs rebuild automatically.
  void _subscribeToStreams() {
    _streamSub?.cancel();
    _streamSub = null;
    _streamTabController?.dispose();
    _streamTabController = null;

    final grades = widget.group.grades;
    if (grades.isEmpty) {
      setState(() => _streamEntries = []);
      return;
    }

    final gradeEntry = grades[_selectedGradeIndex];
    final examIds = widget.group.examIds;

    _streamSub = _dao
        .watchStreamsWithPapersForGrade(
          schoolId: widget.schoolId,
          examIds: examIds,
          grade: gradeEntry.grade,
        )
        .listen((entries) {
          if (!mounted) return;
          setState(() {
            _streamEntries = entries;
            _rebuildStreamTabController();
          });
        });
  }

  /// Rebuilds the [TabController] to match the current [_streamEntries] length.
  /// Called whenever the reactive stream emits a new list.
  void _rebuildStreamTabController() {
    _streamTabController?.dispose();
    _streamTabController = null;

    if (_streamEntries.length > 1) {
      final initialIdx = _selectedStreamIndex.clamp(
        0,
        _streamEntries.length - 1,
      );
      _selectedStreamIndex = initialIdx;
      _streamTabController =
          TabController(
            length: _streamEntries.length,
            initialIndex: initialIdx,
            vsync: this,
          )..addListener(() {
            if (_streamTabController!.indexIsChanging) return;
            setState(() => _selectedStreamIndex = _streamTabController!.index);
          });
    } else {
      _selectedStreamIndex = 0;
    }
  }

  Future<void> _loadTeacherNames() async {
    final ids = <String>{};
    for (final g in widget.group.grades) {
      for (final s in g.streams) {
        for (final p in s.papers) {
          ids.add(p.invigilator);
        }
      }
    }
    final names = <String, String>{};
    for (final id in ids) {
      final user = await _membersDao.findUserById(id);
      if (user != null) names[id] = user.name;
    }
    if (mounted) setState(() => _teacherNames = names);
  }

  /// Currently selected stream code (nullable — null means grade-wide).
  /// Returns the sentinel `_kNoSelection` when there are no stream entries at
  /// all (nothing to show).
  static const _kNoSelection = -9999;
  int? get _currentStreamCode {
    if (_streamEntries.isEmpty) return _kNoSelection;
    final si = _selectedStreamIndex.clamp(0, _streamEntries.length - 1);
    return _streamEntries[si].streamCode;
  }

  /// Whether there is at least one stream entry with papers to display.
  bool get _hasStreamSelection =>
      _streamEntries.isNotEmpty && _currentStreamCode != _kNoSelection;

  /// Resolve the exam row for the current grade.  Because exams have no
  /// grade/stream columns, we pick the first exam from the grade entry's
  /// pre-grouped streams (which all share the same exam ID in the common
  /// case).
  Exam? get _currentExam {
    final grades = widget.group.grades;
    if (grades.isEmpty) return null;
    final gradeEntry = grades[_selectedGradeIndex];
    if (gradeEntry.streams.isEmpty) return null;
    return gradeEntry.streams.first.exam;
  }

  MembershipEntry get _entry => widget.entry;

  bool get _canCreateExam =>
      widget.schoolContext.permissions.can(Resource.exams, Action.create) ||
      _entry is OwnerEntry;

  /// Whether the current teacher created this exam group or has subject
  /// assignments overlapping with any of its participating grades.
  /// Always returns `true` for non-teacher entries.
  bool get _isTeacherExamOwnerOrAssigned {
    if (_entry is! TeacherEntry) return true;
    final teacherId = (_entry as TeacherEntry).teacher.user;
    // Teacher created the exam
    if (widget.group.teacher.id == teacherId) return true;
    // Teacher has subject assignments for any of this exam's grades
    final examGrades = widget.group.participatingGrades.toSet();
    return _teacherSubjects.any((st) => examGrades.contains(st.grade));
  }

  bool get _canEditExam {
    if (_entry is OwnerEntry) return true;
    if (!widget.schoolContext.permissions.can(Resource.exams, Action.update)) {
      return false;
    }
    // Teachers can only edit exams they created or are assigned to
    if (_entry is TeacherEntry) return _isTeacherExamOwnerOrAssigned;
    return true; // Staff with permission
  }

  bool get _canDeleteExam {
    if (_entry is OwnerEntry) return true;
    if (!widget.schoolContext.permissions.can(Resource.exams, Action.delete)) {
      return false;
    }
    // Teachers can only delete exams they created or are assigned to
    if (_entry is TeacherEntry) return _isTeacherExamOwnerOrAssigned;
    return true; // Staff with permission
  }

  bool get _canMarkGrades {
    if (_entry is OwnerEntry) return true;
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.grades, Action.mark);
  }

  Future<void> _showAddPaper(BuildContext context) async {
    if (!_hasStreamSelection) return;
    final grades = widget.group.grades;
    if (grades.isEmpty) return;
    final gradeEntry = grades[_selectedGradeIndex];
    final exam = _currentExam;
    if (exam == null) return;

    await showEduSheet<void>(
      context: context,
      builder: (_) => CreatePaperSheet(
        examGroup: widget.group,
        schoolId: widget.schoolId,
        examId: exam.id,
        year: widget.year,
        term: widget.term,
        grade: gradeEntry.grade,
        stream: _currentStreamCode,
        config: widget.config,
        subjectNames: widget.subjectNames,
        dao: _dao,
        subjectsDao: SubjectsDao(db),
        teacherUserId: widget.entry is TeacherEntry
            ? (widget.entry as TeacherEntry).teacher.user
            : null,
      ),
    );
  }

  Future<void> _showAddGradeModal(BuildContext context) async {
    // For teachers, restrict grade picker to their assigned grades
    final teacherGrades = _entry is TeacherEntry
        ? _teacherSubjects.map((st) => st.grade).toSet()
        : null;
    await showEduSheet<void>(
      context: context,
      maxWidth: 520,
      builder: (_) => AddGradeToExamForm(
        group: widget.group,
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        config: widget.config,
        subjectNames: widget.subjectNames,
        dao: _dao,
        subjectsDao: SubjectsDao(db),
        membersDao: _membersDao,
        onClose: () => Navigator.of(context).pop(),
        teacherAssignedGrades: teacherGrades,
      ),
    );
  }

  Future<void> _showAddStreamModal(BuildContext context) async {
    // For teachers, restrict grade picker to their assigned grades
    final teacherGrades = _entry is TeacherEntry
        ? _teacherSubjects.map((st) => st.grade).toSet()
        : null;
    await showEduSheet<void>(
      context: context,
      maxWidth: 520,
      builder: (_) => AddStreamForm(
        group: widget.group,
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        config: widget.config,
        subjectNames: widget.subjectNames,
        dao: _dao,
        subjectsDao: SubjectsDao(db),
        membersDao: _membersDao,
        onClose: () => Navigator.of(context).pop(),
        teacherAssignedGrades: teacherGrades,
      ),
    );
  }

  Future<void> _showEditExamName(BuildContext context) async {
    final group = widget.group;
    final currentName = group.name;
    final ctrl = TextEditingController(text: currentName);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showEduSheet<void>(
      context: context,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.kModalRadius),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Exam Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Mid-Term Exam',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2C3C)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.3 : 0.5,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.25 : 0.4,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            splashFactory: NoSplash.splashFactory,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final name = ctrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.of(context).pop();
                            final accountId = cache.currentUser?.user.id;
                            if (accountId == null) return;
                            await _dao.updateExamName(
                              examIds: group.examIds,
                              name: name,
                              accountId: accountId,
                            );
                            // Group key is now name-based — notify parent so
                            // the stream matcher picks up the renamed group.
                            final newKey =
                                '${widget.schoolId}|${widget.year}|${widget.term}|$name';
                            widget.onGroupKeyChanged?.call(newKey);
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text(
                            'Save',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _confirmDeleteStream(BuildContext context) async {
    if (!_hasStreamSelection) return;
    final currentGrade = widget.group.grades.isNotEmpty
        ? widget.group.grades[_selectedGradeIndex]
        : null;
    if (currentGrade == null) return;
    final sc = _currentStreamCode;
    final streamName = sc != null
        ? examStreamLabel(currentGrade.grade, sc, widget.config)
        : 'this stream';

    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove $streamName?',
      message: 'This will delete all papers for this stream.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    // Delete all papers for this grade+stream by deleting the exam row
    // that owns them.  In the typical case all papers for a grade share
    // one exam row.
    final exam = _currentExam;
    if (exam == null) return;
    await _dao.deleteExam(examId: exam.id, accountId: accountId);
    if (mounted) {
      setState(() => _selectedStreamIndex = 0);
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Exam',
      message:
          'All papers, grades, and mastery data for this exam will be permanently deleted.',
      confirmLabel: 'Delete Exam',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    for (final id in widget.group.examIds) {
      await _dao.deleteExam(examId: id, accountId: accountId);
    }
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final group = widget.group;
    final grades = group.grades;

    // Build grade tab labels
    final gradeTabs = grades
        .map((g) => EduTab(label: examGradeLabel(g.grade, widget.config)))
        .toList();

    // Build stream tab labels from the reactive _streamEntries list.
    // Show tabs when there are 2+ distinct streams for this grade.
    final currentGrade = grades.isNotEmpty ? grades[_selectedGradeIndex] : null;
    final streamTabs = _streamEntries.length > 1
        ? _streamEntries
              .map(
                (s) => EduTab(
                  label: s.streamCode != null
                      ? (s.streamName != null && s.streamName!.isNotEmpty
                            ? s.streamName!
                            : examStreamLabel(
                                currentGrade!.grade,
                                s.streamCode!,
                                widget.config,
                              ))
                      : 'All',
                ),
              )
              .toList()
        : <EduTab>[];

    // Header subtitle
    final tLabel = typeLabel(group.type);
    final subtitle = '${widget.year} · T${widget.term}';

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: widget.onBack,
                    tooltip: 'Back',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.grades.isNotEmpty &&
                                        group.grades.first.streams.isNotEmpty
                                    ? group.grades.first.streams.first.exam.name
                                    : tLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$tLabel · $subtitle',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_canEditExam)
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            onPressed: () => _showEditExamName(context),
                            tooltip: 'Edit exam name',
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  if (_canDeleteExam)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: cs.error.withValues(alpha: 0.6),
                      ),
                      onPressed: () => _confirmDeleteGroup(context),
                      tooltip: 'Delete exam',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            // ── Responsive content: desktop = cross-table, mobile = tabs ──
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  // ── Desktop (≥600px): unified cross-table matrix ─────────
                  if (constraints.maxWidth >= 600) {
                    return _ExamGroupCrossTable(
                      group: widget.group,
                      config: widget.config,
                      subjectNames: widget.subjectNames,
                      teacherNames: _teacherNames,
                      onPaperTap: (paper, exam, grade, {int streamIndex = 0}) {
                        widget.onPaperTap(
                          paper,
                          exam,
                          grade,
                          streamIndex: streamIndex,
                        );
                      },
                    );
                  }
                  // ── Mobile (<600px): grade tabs + stream sub-tabs ────────
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Grade tabs
                      if (gradeTabs.isNotEmpty)
                        EduTabBar(
                          controller: _gradeTabController,
                          tabs: gradeTabs,
                          isScrollable: true,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                        ),
                      // Stream sub-tabs (reactive from DB)
                      if (streamTabs.isNotEmpty && _streamTabController != null)
                        Row(
                          children: [
                            Expanded(
                              child: EduTabBar(
                                controller: _streamTabController!,
                                tabs: streamTabs,
                                isScrollable: true,
                                padding: const EdgeInsets.fromLTRB(16, 2, 4, 4),
                              ),
                            ),
                            if (_canDeleteExam)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: cs.error.withValues(alpha: 0.5),
                                  ),
                                  onPressed: () =>
                                      _confirmDeleteStream(context),
                                  tooltip: 'Remove stream',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                      // Paper status legend
                      if (_hasStreamSelection)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: _PaperStatusLegend(),
                        ),
                      // Paper content
                      Expanded(
                        child: !_hasStreamSelection
                            ? _EmptyPapersTimetableState(cs: cs)
                            : _PaperContentArea(
                                examIds: widget.group.examIds,
                                grade: currentGrade?.grade ?? 0,
                                stream: _currentStreamCode,
                                exam: _currentExam,
                                schoolId: widget.schoolId,
                                config: widget.config,
                                subjectNames: widget.subjectNames,
                                teacherNames: _teacherNames,
                                dao: _dao,
                                canManage: _canCreateExam || _canMarkGrades,
                                onPaperTap:
                                    (
                                      paper,
                                      exam,
                                      grade, {
                                      int streamIndex = 0,
                                    }) {
                                      widget.onPaperTap(
                                        paper,
                                        exam,
                                        grade,
                                        streamIndex: _selectedStreamIndex,
                                      );
                                    },
                                initialDayIndex: widget.initialDayIndex,
                                onDayChanged: widget.onDayChanged,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        // ── Expandable FAB (manage-only) ───────────────────────────────────
        if (_canCreateExam)
          Positioned(
            right: 12,
            bottom: 16,
            child: _ExpandableFab(
              paperEnabled:
                  _hasStreamSelection && _teacherHasSubjectsForCurrentSelection,
              onAddPaper: () => _showAddPaper(context),
              onAddGrade: () => _showAddGradeModal(context),
              onAddStream: () => _showAddStreamModal(context),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable FAB — multi-option floating action button
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableFab extends StatefulWidget {
  const _ExpandableFab({
    required this.paperEnabled,
    required this.onAddPaper,
    required this.onAddGrade,
    required this.onAddStream,
  });

  final bool paperEnabled;
  final VoidCallback onAddPaper;
  final VoidCallback onAddGrade;
  final VoidCallback onAddStream;

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _open = false;

  // Per-option staggered animations (3 options).
  // Index 0 = Paper (bottom), 1 = Grade, 2 = Stream (top).
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fades = List.generate(3, (i) {
      // Reverse stagger so topmost (index 2) animates first on open.
      final delay = (2 - i) * 0.08;
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          delay,
          (delay + 0.6).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );
    });

    _slides = List.generate(3, (i) {
      final delay = (2 - i) * 0.08;
      final curved = CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          delay,
          (delay + 0.6).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );
      return Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(curved);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Heights: pill height ≈ 38, gap = 8. Stack height to fit 3 pills + FAB.
    const pillH = 38.0;
    const gap = 8.0;
    const fabH = 40.0; // FloatingActionButton.small
    const stackH = 3 * pillH + 3 * gap + fabH;

    // Offsets from bottom for each pill (0 = Paper, 1 = Grade, 2 = Stream).
    double pillBottom(int i) => fabH + gap + i * (pillH + gap);

    return SizedBox(
      width: 160,
      height: stackH,
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // Transparent tap-outside-to-close overlay when open.
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),

          // ── Paper pill (index 0, bottom) ───────────────────────────────
          Positioned(
            bottom: pillBottom(0),
            right: 0,
            child: FadeTransition(
              opacity: _fades[0],
              child: SlideTransition(
                position: _slides[0],
                child: _FabOptionPill(
                  icon: Icons.note_add_outlined,
                  label: 'Paper',
                  enabled: widget.paperEnabled,
                  cs: cs,
                  onTap: () {
                    _close();
                    widget.onAddPaper();
                  },
                ),
              ),
            ),
          ),

          // ── Grade pill (index 1, middle) ───────────────────────────────
          Positioned(
            bottom: pillBottom(1),
            right: 0,
            child: FadeTransition(
              opacity: _fades[1],
              child: SlideTransition(
                position: _slides[1],
                child: _FabOptionPill(
                  icon: Icons.school_outlined,
                  label: 'Grade',
                  enabled: true,
                  cs: cs,
                  onTap: () {
                    _close();
                    widget.onAddGrade();
                  },
                ),
              ),
            ),
          ),

          // ── Stream pill (index 2, top) ─────────────────────────────────
          Positioned(
            bottom: pillBottom(2),
            right: 0,
            child: FadeTransition(
              opacity: _fades[2],
              child: SlideTransition(
                position: _slides[2],
                child: _FabOptionPill(
                  icon: Icons.account_tree_outlined,
                  label: 'Stream',
                  enabled: true,
                  cs: cs,
                  onTap: () {
                    _close();
                    widget.onAddStream();
                  },
                ),
              ),
            ),
          ),

          // ── Main FAB ───────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return FloatingActionButton.small(
                  heroTag: 'fab_exam_detail_main',
                  onPressed: _toggle,
                  child: Transform.rotate(
                    angle: _ctrl.value * (45 * math.pi / 180),
                    child: const Icon(Icons.add, size: 20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FabOptionPill extends StatelessWidget {
  const _FabOptionPill({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.cs,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final borderAlpha = brightness == Brightness.dark ? 0.30 : 0.45;
    final disabledAlpha = 0.35;

    final contentColor = enabled
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: disabledAlpha);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: borderAlpha),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: contentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper content area — wires up the stream entry to the timetable views
// (expanded in R04; this stub shows the papers list and delegates taps)
// ─────────────────────────────────────────────────────────────────────────────

class _PaperContentArea extends StatefulWidget {
  const _PaperContentArea({
    required this.examIds,
    required this.grade,
    required this.stream,
    required this.exam,
    required this.schoolId,
    required this.config,
    required this.subjectNames,
    required this.teacherNames,
    required this.dao,
    required this.canManage,
    required this.onPaperTap,
    this.initialDayIndex = 0,
    this.onDayChanged,
  });

  /// All exam row IDs in the current exam group.
  final List<String> examIds;

  /// The grade filter — only papers with this grade are shown.
  final int grade;

  /// The stream filter — `null` means grade-wide papers (stream IS NULL).
  final int? stream;

  /// The exam row for display purposes (paper tap callback, grid headers).
  /// May be null if no exam row is resolved yet.
  final Exam? exam;
  final String schoolId;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final Map<String, String> teacherNames;
  final ExamsGradesDao dao;
  final bool canManage;
  final void Function(Paper paper, Exam exam, int grade, {int streamIndex})
  onPaperTap;
  final int initialDayIndex;
  final ValueChanged<int>? onDayChanged;

  @override
  State<_PaperContentArea> createState() => _PaperContentAreaState();
}

class _PaperContentAreaState extends State<_PaperContentArea> {
  late Stream<List<Paper>> _papersStream;

  /// Cache key so we can detect when we need to rebuild the stream.
  late String _cacheKey;

  String _buildCacheKey() =>
      '${widget.schoolId}|${widget.examIds.join(',')}|${widget.grade}|${widget.stream}';

  @override
  void initState() {
    super.initState();
    _cacheKey = _buildCacheKey();
    debugPrint(
      '[_PaperContentArea] initState: grade=${widget.grade}, '
      'stream=${widget.stream}, examIds=${widget.examIds}',
    );
    _papersStream = widget.dao.watchPapersForExamGradeStream(
      schoolId: widget.schoolId,
      examIds: widget.examIds,
      grade: widget.grade,
      stream: widget.stream,
    );
  }

  @override
  void didUpdateWidget(covariant _PaperContentArea old) {
    super.didUpdateWidget(old);
    final newKey = _buildCacheKey();
    if (newKey != _cacheKey) {
      debugPrint(
        '[_PaperContentArea] stream changed: '
        'old=${old.stream} → new=${widget.stream}, '
        'grade=${widget.grade}',
      );
      _cacheKey = newKey;
      _papersStream = widget.dao.watchPapersForExamGradeStream(
        schoolId: widget.schoolId,
        examIds: widget.examIds,
        grade: widget.grade,
        stream: widget.stream,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exam = widget.exam;
    return StreamBuilder<List<Paper>>(
      stream: _papersStream,
      builder: (context, snap) {
        final papers = snap.data ?? [];
        if (papers.isNotEmpty) {
          debugPrint(
            '[_PaperContentArea] build: filterStream=${widget.stream}, '
            'filterGrade=${widget.grade}, ${papers.length} papers:',
          );
          for (final p in papers) {
            debugPrint(
              '  subj=${p.subject}, paper=${p.paper}, '
              'grade=${p.grade}, stream=${p.stream}, '
              'status=${p.status}, inv=${p.invigilator}',
            );
          }
        }
        if (papers.isEmpty) {
          return _EmptyPapersTimetableState(cs: cs);
        }
        // Resolve the exam for display — prefer widget.exam.
        // In practice widget.exam should always be non-null.
        final displayExam = exam;
        if (displayExam == null) {
          return _EmptyPapersTimetableState(cs: cs);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return _PaperTimetableGrid(
                papers: papers,
                exam: displayExam,
                grade: widget.grade,
                config: widget.config,
                subjectNames: widget.subjectNames,
                teacherNames: widget.teacherNames,
                canManage: widget.canManage,
                onPaperTap: widget.onPaperTap,
              );
            } else {
              return _PaperTimetableMobile(
                papers: papers,
                exam: displayExam,
                grade: widget.grade,
                config: widget.config,
                subjectNames: widget.subjectNames,
                teacherNames: widget.teacherNames,
                canManage: widget.canManage,
                onPaperTap: widget.onPaperTap,
                initialDayIndex: widget.initialDayIndex,
                onDayChanged: widget.onDayChanged,
              );
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop unified cross-table: all grade+stream combos × all dates (≥600px)
// ─────────────────────────────────────────────────────────────────────────────

/// Displays all papers for an [ExamGroup] as a unified matrix where
/// rows = grade+stream combinations and columns = exam dates. Multiple papers
/// scheduled at different times on the same date are stacked vertically within
/// one cell. Used on desktop (≥600px) inside [_ExamGroupDetailView].
class _ExamGroupCrossTable extends StatelessWidget {
  const _ExamGroupCrossTable({
    required this.group,
    required this.config,
    required this.subjectNames,
    required this.teacherNames,
    required this.onPaperTap,
  });

  final ExamGroup group;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final Map<String, String> teacherNames;
  final void Function(Paper, Exam, int grade, {int streamIndex}) onPaperTap;

  /// Build one row descriptor per (grade, stream) combination.
  List<
    ({int grade, int? streamCode, String label, Exam exam, List<Paper> papers})
  >
  _buildRows() {
    final rows =
        <
          ({
            int grade,
            int? streamCode,
            String label,
            Exam exam,
            List<Paper> papers,
          })
        >[];
    for (final gradeEntry in group.grades) {
      final gradeLabel = examGradeLabel(gradeEntry.grade, config);
      for (final streamEntry in gradeEntry.streams) {
        final streamName = streamEntry.streamCode != null
            ? examStreamLabel(gradeEntry.grade, streamEntry.streamCode!, config)
            : null;
        final rowLabel = streamName != null
            ? '$gradeLabel · $streamName'
            : gradeLabel;
        rows.add((
          grade: gradeEntry.grade,
          streamCode: streamEntry.streamCode,
          label: rowLabel,
          exam: streamEntry.exam,
          papers: streamEntry.papers,
        ));
      }
    }
    return rows;
  }

  /// Returns papers belonging to [date] within [papers], sorted by start time.
  List<Paper> _papersOnDate(List<Paper> papers, DateTime date) {
    return papers.where((p) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
      final day = DateTime(dt.year, dt.month, dt.day);
      return day == date;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final rows = _buildRows();
    final allPapers = rows.expand((r) => r.papers).toList();

    if (rows.isEmpty || allPapers.isEmpty) {
      return _EmptyPapersTimetableState(cs: cs);
    }

    // ── Build unique time-slot columns from all papers ──
    final timeCols = <({String start, String end, int startMins})>[];
    {
      final seen = <int>{};
      final sorted = List<Paper>.from(allPapers)
        ..sort((a, b) => a.start.compareTo(b.start));
      for (final p in sorted) {
        if (p.start.toInt() == 0) continue; // skip unset times
        final sdt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
        final mins = sdt.hour * 60 + sdt.minute;
        if (seen.add(mins)) {
          final edt = DateTime.fromMillisecondsSinceEpoch(p.end.toInt() * 1000);
          timeCols.add((
            start: fmtTimeDt(sdt),
            end: fmtTimeDt(edt),
            startMins: mins,
          ));
        }
      }
    }

    final grouped = groupPapersByDate(allPapers);
    final dates = sortedPaperDates(grouped);

    if (timeCols.isEmpty || dates.isEmpty) {
      return _EmptyPapersTimetableState(cs: cs);
    }

    // ── Layout constants (matching timetable) ──
    const double streamLabelW = 100;
    const double timeColW = 110;
    const double colGap = 3;
    final totalW =
        streamLabelW +
        colGap +
        timeCols.length * timeColW +
        (timeCols.length > 1 ? (timeCols.length - 1) * colGap : 0);

    // ── Helper: find paper for a specific stream's papers at date+time ──
    List<Paper> papersAt(List<Paper> papers, DateTime date, int startMins) {
      return papers.where((p) {
        final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
        final day = DateTime(dt.year, dt.month, dt.day);
        return day == date && (dt.hour * 60 + dt.minute) == startMins;
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _PaperStatusLegend(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Time header row ──
                  Row(
                    children: [
                      const SizedBox(width: streamLabelW),
                      const SizedBox(width: colGap),
                      for (int i = 0; i < timeCols.length; i++) ...[
                        if (i > 0) const SizedBox(width: colGap),
                        SizedBox(
                          width: timeColW,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kChipRadius,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${timeCols[i].start} – ${timeCols[i].end}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                                letterSpacing: 0.1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: colGap),

                  // ── Day groups ──
                  for (int di = 0; di < dates.length; di++) ...[
                    if (di > 0) const SizedBox(height: 10),
                    // Day header strip
                    Container(
                      width: totalW,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.25 : 0.20,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        fmtDayHeader(dates[di]),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.75),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    // Grade sub-groups within this day
                    for (final gradeEntry in group.grades) ...[
                      // Grade sub-header
                      const SizedBox(height: colGap),
                      Container(
                        width: totalW,
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: isDark ? 0.12 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.kChipRadius,
                          ),
                        ),
                        child: Text(
                          examGradeLabel(gradeEntry.grade, config),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),

                      // Stream rows
                      for (final streamEntry in gradeEntry.streams) ...[
                        const SizedBox(height: colGap),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Stream label
                              SizedBox(
                                width: streamLabelW,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      streamEntry.streamCode != null
                                          ? examStreamLabel(
                                              gradeEntry.grade,
                                              streamEntry.streamCode!,
                                              config,
                                            )
                                          : examGradeLabel(
                                              gradeEntry.grade,
                                              config,
                                            ),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.55,
                                        ),
                                        letterSpacing: 0.1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: colGap),

                              // Time slot cells
                              for (int ci = 0; ci < timeCols.length; ci++) ...[
                                if (ci > 0) const SizedBox(width: colGap),
                                SizedBox(
                                  width: timeColW,
                                  child: Builder(
                                    builder: (_) {
                                      final matches = papersAt(
                                        streamEntry.papers,
                                        dates[di],
                                        timeCols[ci].startMins,
                                      );
                                      if (matches.isEmpty) {
                                        return _PaperEmptyCell(cs: cs);
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (
                                            int mi = 0;
                                            mi < matches.length;
                                            mi++
                                          ) ...[
                                            if (mi > 0)
                                              const SizedBox(height: 3),
                                            _PaperSlotBox(
                                              paper: matches[mi],
                                              exam: streamEntry.exam,
                                              subjectNames: subjectNames,
                                              statusColor: paperStatusColor(
                                                matches[mi].status,
                                                cs,
                                              ),
                                              invigilatorName:
                                                  teacherNames[matches[mi]
                                                      .invigilator] ??
                                                  '',
                                              cs: cs,
                                              onTap: () => onPaperTap(
                                                matches[mi],
                                                streamEntry.exam,
                                                gradeEntry.grade,
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cross-table header row + row label
// ─────────────────────────────────────────────────────────────────────────────

class _CrossTableHeaderRow extends StatelessWidget {
  const _CrossTableHeaderRow({
    required this.dates,
    required this.rowLabelWidth,
    required this.colWidth,
    required this.cs,
  });

  final List<DateTime> dates;
  final double rowLabelWidth;
  final double colWidth;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Corner spacer — same width as row labels
        SizedBox(width: rowLabelWidth),
        ...dates.map(
          (d) => SizedBox(
            width: colWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                fmtDayHeader(d),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left-edge label cell for a grade+stream row in [_ExamGroupCrossTable].
class _CrossTableRowLabel extends StatelessWidget {
  const _CrossTableRowLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop paper timetable grid (≥600px)
// ─────────────────────────────────────────────────────────────────────────────

class _PaperTimetableGrid extends StatelessWidget {
  const _PaperTimetableGrid({
    required this.papers,
    required this.exam,
    required this.grade,
    required this.config,
    required this.subjectNames,
    required this.teacherNames,
    required this.canManage,
    required this.onPaperTap,
  });

  final List<Paper> papers;
  final Exam exam;
  final int grade;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final Map<String, String> teacherNames;
  final bool canManage;
  final void Function(Paper paper, Exam exam, int grade, {int streamIndex})
  onPaperTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = groupPapersByDate(papers);
    final dates = sortedPaperDates(grouped);
    final timeslots = uniquePaperStartTimes(papers);

    // Compute total grid width: time gutter + date columns
    const double gutterWidth = 72;
    const double dateColWidth = 140;
    final totalWidth = gutterWidth + dates.length * dateColWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header row ──────────────────────────────────────────────
              _PaperGridHeaderRow(dates: dates, cs: cs),
              const SizedBox(height: 4),
              // ── Data rows (one per unique start time) ───────────────────
              ...timeslots.map((slot) {
                return _PaperGridRow(
                  dates: dates,
                  grouped: grouped,
                  startTime: slot.start,
                  endTime: slot.end,
                  exam: exam,
                  grade: grade,
                  config: config,
                  subjectNames: subjectNames,
                  teacherNames: teacherNames,
                  cs: cs,
                  onPaperTap: onPaperTap,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperGridHeaderRow extends StatelessWidget {
  const _PaperGridHeaderRow({required this.dates, required this.cs});

  final List<DateTime> dates;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Time gutter placeholder
        const SizedBox(width: 72),
        ...dates.map(
          (d) => Expanded(
            child: _PaperHeaderCell(date: d, cs: cs),
          ),
        ),
      ],
    );
  }
}

class _PaperHeaderCell extends StatelessWidget {
  const _PaperHeaderCell({required this.date, required this.cs});

  final DateTime date;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        fmtDayColumn(date),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PaperGridRow extends StatelessWidget {
  const _PaperGridRow({
    required this.dates,
    required this.grouped,
    required this.startTime,
    required this.endTime,
    required this.exam,
    required this.grade,
    required this.config,
    required this.subjectNames,
    required this.teacherNames,
    required this.cs,
    required this.onPaperTap,
  });

  final List<DateTime> dates;
  final Map<DateTime, List<Paper>> grouped;
  final String startTime;
  final String endTime;
  final Exam exam;
  final int grade;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final Map<String, String> teacherNames;
  final ColorScheme cs;
  final void Function(Paper paper, Exam exam, int grade, {int streamIndex})
  onPaperTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Time label ─────────────────────────────────────────────────
            SizedBox(
              width: 72,
              child: _PaperTimeLabel(
                startTime: startTime,
                endTime: endTime,
                cs: cs,
              ),
            ),
            // ── Day cells ──────────────────────────────────────────────────
            ...dates.map((d) {
              final matches = papersAt(grouped, d, startTime);
              if (matches.isEmpty) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _PaperEmptyCell(cs: cs),
                  ),
                );
              }
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      for (int i = 0; i < matches.length; i++) ...[
                        if (i > 0) const SizedBox(height: 3),
                        Expanded(
                          child: _PaperSlotBox(
                            paper: matches[i],
                            exam: exam,
                            subjectNames: subjectNames,
                            statusColor: paperStatusColor(
                              matches[i].status,
                              cs,
                            ),
                            invigilatorName:
                                teacherNames[matches[i].invigilator] ?? '',
                            cs: cs,
                            onTap: () => onPaperTap(matches[i], exam, grade),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PaperTimeLabel extends StatelessWidget {
  const _PaperTimeLabel({
    required this.startTime,
    required this.endTime,
    required this.cs,
  });

  final String startTime;
  final String endTime;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            startTime,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            endTime,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperSlotBox extends StatelessWidget {
  const _PaperSlotBox({
    required this.paper,
    required this.exam,
    required this.subjectNames,
    required this.statusColor,
    required this.invigilatorName,
    required this.cs,
    required this.onTap,
  });

  final Paper paper;
  final Exam exam;
  final Map<int, String> subjectNames;
  final Color statusColor;
  final String invigilatorName;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName =
        subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
    final paperLabel = (paper.paper ?? 1) > 1 ? ' · P${paper.paper}' : '';
    final invDisplay = invigilatorName.isNotEmpty ? invigilatorName : '—';

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border(
            left: BorderSide(
              color: statusColor.withValues(alpha: 0.6),
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$subjectName$paperLabel',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              invDisplay,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperEmptyCell extends StatelessWidget {
  const _PaperEmptyCell({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
          width: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile paper timetable (<600px)
// ─────────────────────────────────────────────────────────────────────────────

class _PaperTimetableMobile extends StatefulWidget {
  const _PaperTimetableMobile({
    required this.papers,
    required this.exam,
    required this.grade,
    required this.config,
    required this.subjectNames,
    required this.teacherNames,
    required this.canManage,
    required this.onPaperTap,
    this.initialDayIndex = 0,
    this.onDayChanged,
  });
  final List<Paper> papers;
  final Exam exam;
  final int grade;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final Map<String, String> teacherNames;
  final bool canManage;
  final void Function(Paper paper, Exam exam, int grade, {int streamIndex})
  onPaperTap;
  final int initialDayIndex;
  final ValueChanged<int>? onDayChanged;

  @override
  State<_PaperTimetableMobile> createState() => _PaperTimetableMobileState();
}

class _PaperTimetableMobileState extends State<_PaperTimetableMobile>
    with TickerProviderStateMixin {
  Map<DateTime, List<Paper>> _grouped = {};
  List<DateTime> _dates = [];
  int _selectedDayIndex = 0;
  TabController? _dayTabController;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = widget.initialDayIndex;
    _rebuildGroups();
  }

  @override
  void didUpdateWidget(_PaperTimetableMobile old) {
    super.didUpdateWidget(old);
    if (old.papers != widget.papers) {
      _rebuildGroups();
    }
  }

  @override
  void dispose() {
    _dayTabController?.dispose();
    super.dispose();
  }

  void _rebuildGroups() {
    _grouped = groupPapersByDate(widget.papers);
    _dates = sortedPaperDates(_grouped);
    _selectedDayIndex = _selectedDayIndex.clamp(
      0,
      (_dates.length - 1).clamp(0, 999),
    );
    _rebuildTabController();
  }

  void _rebuildTabController() {
    _dayTabController?.dispose();
    _dayTabController = null;
    if (_dates.isEmpty) return;
    _dayTabController =
        TabController(
          length: _dates.length,
          initialIndex: _selectedDayIndex,
          vsync: this,
        )..addListener(() {
          if (_dayTabController!.indexIsChanging) return;
          setState(() {
            _selectedDayIndex = _dayTabController!.index;
            widget.onDayChanged?.call(_selectedDayIndex);
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_dates.isEmpty) {
      return _EmptyPapersTimetableState(cs: cs);
    }

    final selectedDate = _dates[_selectedDayIndex];
    final dayPapers = _grouped[selectedDate] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Day tab strip (EduTabBar aesthetic) ──────────────────────────
        if (_dayTabController != null)
          _PaperDayTabStrip(controller: _dayTabController!, dates: _dates),
        // ── Day heading ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Text(
            fmtDayHeader(selectedDate),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ),
        // ── Paper list ───────────────────────────────────────────────────
        Expanded(
          child: dayPapers.isEmpty
              ? Center(
                  child: Text(
                    'No papers on this day.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: dayPapers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = dayPapers[i];
                    final statusColor = paperStatusColor(p.status, cs);
                    final invName = widget.teacherNames[p.invigilator] ?? '';
                    return _PaperSlotCard(
                      paper: p,
                      exam: widget.exam,
                      subjectNames: widget.subjectNames,
                      cs: cs,
                      statusColor: statusColor,
                      invigilatorName: invName,
                      onTap: () =>
                          widget.onPaperTap(p, widget.exam, widget.grade),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Day tab strip matching the EduTabBar aesthetic — tinted background strip
/// with an elevated, shadow-based sliding indicator. Each tab shows a two-line
/// layout: abbreviated day name + date number.
class _PaperDayTabStrip extends StatelessWidget {
  const _PaperDayTabStrip({required this.controller, required this.dates});

  final TabController controller;
  final List<DateTime> dates;

  static const _dayAbbr = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const double _stripHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    Widget strip = Container(
      height: _stripHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        splashBorderRadius: BorderRadius.circular(8),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
              blurRadius: 1,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        tabs: dates.map((d) {
          final dayName = _dayAbbr[d.weekday % 7];
          final dayNum = d.day.toString();
          return Tab(
            height: _stripHeight - 8,
            child: SizedBox(
              width: 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.15,
                    ),
                  ),
                  Text(
                    dayNum,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );

    strip = Align(alignment: Alignment.centerLeft, child: strip);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: strip,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper status legend
// ─────────────────────────────────────────────────────────────────────────────

class _PaperStatusLegend extends StatelessWidget {
  const _PaperStatusLegend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statuses = PaperStatus.values;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: statuses.map((s) {
        final color = paperStatusColor(s, cs);
        final label = paperStatusLabel(s);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper slot card — used by mobile timetable view + paper content area
// ─────────────────────────────────────────────────────────────────────────────

class _PaperSlotCard extends StatelessWidget {
  const _PaperSlotCard({
    required this.paper,
    required this.exam,
    required this.subjectNames,
    required this.cs,
    required this.statusColor,
    required this.invigilatorName,
    required this.onTap,
  });
  final Paper paper;
  final Exam exam;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final Color statusColor;
  final String invigilatorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName =
        subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
    final paperLabel = (paper.paper ?? 1) > 1 ? 'Paper ${paper.paper}' : '';
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);
    final timeRange = '${fmtTimeDt(startDt)} – ${fmtTimeDt(endDt)}';
    final invDisplay = invigilatorName.isNotEmpty ? invigilatorName : '—';

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.06),
            border: Border(
              left: BorderSide(color: statusColor, width: 2.5),
              top: BorderSide(
                color: cs.outlineVariant.withValues(
                  alpha: isDark ? 0.15 : 0.30,
                ),
              ),
              right: BorderSide(
                color: cs.outlineVariant.withValues(
                  alpha: isDark ? 0.15 : 0.30,
                ),
              ),
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(
                  alpha: isDark ? 0.15 : 0.30,
                ),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subjectName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (paperLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            paperLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invDisplay,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty papers timetable state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPapersTimetableState extends StatelessWidget {
  const _EmptyPapersTimetableState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.event_note_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No papers scheduled',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Tap + to add papers for this exam.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper detail view — delegates to PaperDetailPage
// ─────────────────────────────────────────────────────────────────────────────

class PaperDetailView extends StatelessWidget {
  const PaperDetailView({
    super.key,
    required this.exam,
    required this.paper,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.config,
    required this.subjectNames,
    required this.schoolContext,
    required this.onBack,
  });
  final ExamWithPapers exam;
  final Paper paper;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final SchoolContext schoolContext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PaperDetailPage(
      paper: paper,
      exam: exam,
      schoolId: schoolId,
      year: year,
      term: term,
      grade: grade,
      schoolContext: schoolContext,
      subjectNames: subjectNames,
      onBack: onBack,
    );
  }
}
