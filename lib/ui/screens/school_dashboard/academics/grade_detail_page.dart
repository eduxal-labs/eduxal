import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart' show ExamType;
import '../../../../models/curriculum_levels.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/no_terms_blank_state.dart';
import '../../../widgets/edu_tab_bar.dart';
import 'tabs/comparisons_tab.dart';
import 'tabs/exams_tab.dart';
import 'tabs/students_tab.dart';
import 'tabs/subjects_tab.dart';
import 'tabs/teachers_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/lessons_tab.dart';
import 'tabs/timetable_tab.dart';

/// Detail page for a single grade — shows stream tabs across the top and
/// content tabs below when a specific stream is selected.
///
/// **Layer 1 — Stream Tabs (top):**
///   "Comparisons" | one tab per stream from [GradeConfig.streams].
///
/// **Layer 2 — Content Tabs (below, only when a stream is selected):**
///   Students | Exams | Subjects | Attendance | Timetable | Lessons | Teachers
///
/// A contextual FAB appears when a specific stream is selected, offering
/// actions scoped to that stream (Add Student, Assign Class Teacher, Assign
/// Subject Teacher).
class GradeDetailPage extends StatefulWidget {
  const GradeDetailPage({
    super.key,
    required this.schoolContext,
    required this.curriculumType,
    required this.grade,
    required this.gradeLabel,
    this.initialStreamIndex,
    this.initialContentTabIndex,
  });

  final SchoolContext schoolContext;
  final CurriculumType curriculumType;
  final GradeConfig grade;
  final String gradeLabel;

  /// Optional initial stream tab index. 0 = Comparisons, 1+ = specific stream.
  /// When null, defaults to 0 (Comparisons).
  final int? initialStreamIndex;

  /// Optional initial content tab index (Students=0, Exams=1, Subjects=2,
  /// Attendance=3, Timetable=4, Lessons=5, Teachers=6).
  /// When null, defaults to 0 (Students).
  final int? initialContentTabIndex;

  @override
  State<GradeDetailPage> createState() => _GradeDetailPageState();
}

class _GradeDetailPageState extends State<GradeDetailPage>
    with TickerProviderStateMixin {
  // ── Tab controllers ────────────────────────────────────────────────────────

  late TabController _streamTabController;
  late TabController _contentTabController;

  /// 0 = Comparisons, 1+ = specific stream.
  late int _selectedStreamIndex;

  /// Tracks the currently visible content tab index for FAB context.
  late int _selectedContentIndex;

  // ── FAB animation ──────────────────────────────────────────────────────────

  late final AnimationController _fabScaleController;
  late final Animation<double> _fabScaleAnimation;

  // ── Content tab definitions ────────────────────────────────────────────────

  static const _contentTabs = [
    EduTab(label: 'Students'),
    EduTab(label: 'Exams'),
    EduTab(label: 'Subjects'),
    EduTab(label: 'Attendance'),
    EduTab(label: 'Timetable'),
    EduTab(label: 'Lessons'),
    EduTab(label: 'Teachers'),
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final streamCount = widget.grade.streams.length;

    // Resolve initial stream index — clamp to valid range.
    final maxStreamIdx =
        streamCount; // 0 = Comparisons, streamCount = last stream
    final initStream = (widget.initialStreamIndex ?? 0).clamp(0, maxStreamIdx);
    _selectedStreamIndex = initStream;

    _streamTabController = TabController(
      length: 1 + streamCount, // "Comparisons" + N streams
      initialIndex: initStream,
      vsync: this,
    );
    _streamTabController.addListener(_onStreamTabChanged);

    // Resolve initial content tab index — clamp to valid range.
    final initContent = (widget.initialContentTabIndex ?? 0).clamp(
      0,
      _contentTabs.length - 1,
    );
    _selectedContentIndex = initContent;

    _contentTabController = TabController(
      length: _contentTabs.length,
      initialIndex: initContent,
      vsync: this,
    );
    _contentTabController.addListener(_onContentTabChanged);

    // FAB scale animation — used for show/hide and tab-switch bounce.
    _fabScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: _isComparisons ? 0.0 : 1.0,
    );
    _fabScaleAnimation = CurvedAnimation(
      parent: _fabScaleController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _streamTabController.removeListener(_onStreamTabChanged);
    _streamTabController.dispose();
    _contentTabController.removeListener(_onContentTabChanged);
    _contentTabController.dispose();
    _fabScaleController.dispose();
    super.dispose();
  }

  void _onStreamTabChanged() {
    if (_streamTabController.indexIsChanging) return;
    final newIndex = _streamTabController.index;
    if (newIndex != _selectedStreamIndex) {
      final oldIndex = _selectedStreamIndex;
      setState(() => _selectedStreamIndex = newIndex);
      // Animate FAB in/out when switching to/from Comparisons.
      if (newIndex == 0) {
        // Moving to Comparisons — hide FAB.
        _fabScaleController.reverse();
      } else if (oldIndex == 0) {
        // Was on Comparisons — show FAB (if current content tab has one).
        if (_hasFabForContentTab(_selectedContentIndex)) {
          _fabScaleController.forward();
        }
      } else {
        // Switching between streams — subtle bounce.
        _bounceFab();
      }
    }
  }

  void _onContentTabChanged() {
    if (_contentTabController.indexIsChanging) return;
    final newIndex = _contentTabController.index;
    if (newIndex != _selectedContentIndex) {
      setState(() => _selectedContentIndex = newIndex);
      // Subtle bounce when switching content tabs (if FAB is visible).
      if (!_isComparisons && _hasFabForContentTab(newIndex)) {
        _bounceFab();
      } else if (!_hasFabForContentTab(newIndex)) {
        _fabScaleController.reverse();
      } else {
        _fabScaleController.forward();
      }
    }
  }

  /// Returns true if the given content tab index should show a FAB.
  bool _hasFabForContentTab(int index) {
    // Attendance (3) has no FAB — marking is inline.
    return index != 3;
  }

  /// Brief scale-down-then-up bounce for the FAB.
  Future<void> _bounceFab() async {
    await _fabScaleController.reverse();
    if (mounted) {
      await _fabScaleController.forward();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _isComparisons => _selectedStreamIndex == 0;

  GradeStream? get _selectedStream {
    if (_isComparisons) return null;
    final idx = _selectedStreamIndex - 1;
    final streams = widget.grade.streams;
    return idx < streams.length ? streams[idx] : null;
  }

  String get _selectedStreamName => _selectedStream?.name ?? '';

  // ignore: unused_element
  int? get _selectedStreamCode => _selectedStream?.code;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final termCtx = ActiveTermProvider.read(context);
    final streams = widget.grade.streams;

    // Build stream tab descriptors: "Comparisons" + one per stream.
    final streamTabs = <EduTab>[
      const EduTab(label: 'Comparisons'),
      for (final s in streams) EduTab(label: s.name),
    ];

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ValueListenableBuilder<Term?>(
          valueListenable: termCtx.termNotifier,
          builder: (context, term, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.gradeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (term != null)
                  Text(
                    '${term.year} · Term ${term.term}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            );
          },
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: ValueListenableBuilder<Term?>(
        valueListenable: termCtx.termNotifier,
        builder: (context, term, _) {
          // ── No terms — show blank state ──────────────────────────────
          if (term == null) {
            final role = widget.schoolContext.currentEntry.value.role;
            return NoTermsBlankState(
              schoolId: widget.schoolContext.membership.school.id,
              role: role,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Layer 1: Stream tabs ─────────────────────────────────
              Container(
                color: cs.surface,
                child: EduTabBar(
                  controller: _streamTabController,
                  tabs: streamTabs,
                  isScrollable: true,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                ),
              ),

              // ── Layer 2: Content tabs (hidden on Comparisons) ────────
              if (!_isComparisons)
                Container(
                  color: cs.surface,
                  child: EduTabBar(
                    controller: _contentTabController,
                    tabs: _contentTabs,
                    isScrollable: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  ),
                ),

              // ── Divider ──────────────────────────────────────────────
              Container(
                height: 1,
                color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
              ),

              // ── Content area ─────────────────────────────────────────
              Expanded(
                child: _isComparisons
                    ? _buildComparisonsTab(cs, term)
                    : TabBarView(
                        controller: _contentTabController,
                        children: [
                          _buildStudentsTab(cs, term),
                          _buildExamsTab(cs, term),
                          _buildSubjectsTab(cs, term),
                          _buildAttendanceTab(cs, term),
                          _buildTimetableTab(cs, term),
                          _buildLessonsTab(cs, term),
                          _buildTeachersTab(cs, term),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildContextualFab(cs),
    );
  }

  // ── Comparisons tab ────────────────────────────────────────────────────────

  Widget _buildComparisonsTab(ColorScheme cs, Term term) {
    return ComparisonsTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streams: widget.grade.streams,
    );
  }

  // ── Students tab ───────────────────────────────────────────────────────────

  Widget _buildStudentsTab(ColorScheme cs, Term term) {
    return StudentsTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── Exams tab ──────────────────────────────────────────────────────────────

  Widget _buildExamsTab(ColorScheme cs, Term term) {
    return ExamsTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── Subjects tab ───────────────────────────────────────────────────────────

  Widget _buildSubjectsTab(ColorScheme cs, Term term) {
    return SubjectsTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── Teachers tab ───────────────────────────────────────────────────────────

  Widget _buildTeachersTab(ColorScheme cs, Term term) {
    return TeachersTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── Timetable tab ──────────────────────────────────────────────────────────

  Widget _buildTimetableTab(ColorScheme cs, Term term) {
    return TimetableTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── Attendance tab ─────────────────────────────────────────────────────────

  Widget _buildAttendanceTab(ColorScheme cs, Term term) {
    return AttendanceTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── Lessons tab ────────────────────────────────────────────────────────────

  Widget _buildLessonsTab(ColorScheme cs, Term term) {
    return LessonsTab(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: widget.grade.grade,
      streamCode: _selectedStreamCode ?? widget.grade.streams.first.code,
      streamName: _selectedStreamName.isNotEmpty
          ? _selectedStreamName
          : widget.grade.streams.first.name,
      curriculumType: widget.curriculumType,
      schoolContext: widget.schoolContext,
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  /// Builds the contextual FAB with animated scale based on current tabs.
  Widget? _buildContextualFab(ColorScheme cs) {
    // Always render the ScaleTransition so it can animate in/out smoothly.
    return ScaleTransition(
      scale: _fabScaleAnimation,
      alignment: Alignment.center,
      child: FloatingActionButton.small(
        heroTag: 'fab_grade_detail',
        onPressed: () => _handleFabTap(context),
        tooltip: _fabTooltipForContentTab(_selectedContentIndex),
        elevation: 4,
        highlightElevation: 6,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add_rounded, size: 20),
      ),
    );
  }

  /// Returns the actions available for the current content tab.
  List<_FabAction> _actionsForContentTab(int tabIndex) {
    return switch (tabIndex) {
      0 => [
        // Students tab — single action.
        _FabAction(
          icon: Icons.person_add_outlined,
          label: 'Add Student',
          subtitle: 'Enroll a student into this class',
          onTap: () => _showEnrollSheet(context),
        ),
      ],
      1 => [
        // Exams tab — single action.
        _FabAction(
          icon: Icons.quiz_outlined,
          label: 'Create Exam',
          subtitle: 'Create a new exam for this class',
          onTap: () => _showCreateExam(context),
        ),
      ],
      2 => [
        // Subjects tab — single action.
        _FabAction(
          icon: Icons.assignment_ind_outlined,
          label: 'Assign Subject Teacher',
          subtitle: 'Assign a teacher to a subject in this stream',
          onTap: () => _showAssignSubjectTeacherSheet(context),
        ),
      ],
      // 3 = Attendance — no FAB (handled by _hasFabForContentTab).
      4 => [
        // Timetable tab — stub.
        _FabAction(
          icon: Icons.schedule_outlined,
          label: 'Add Slot',
          subtitle: 'Add a timetable slot',
          onTap: () => _showStubSnackbar(context, 'Add Slot'),
        ),
      ],
      5 => [
        // Lessons tab — stub.
        _FabAction(
          icon: Icons.menu_book_outlined,
          label: 'Record Lesson',
          subtitle: 'Record a lesson for this class',
          onTap: () => _showStubSnackbar(context, 'Record Lesson'),
        ),
      ],
      6 => [
        // Teachers tab — multiple actions.
        _FabAction(
          icon: Icons.school_outlined,
          label: 'Assign Class Teacher',
          subtitle: 'Set the class teacher for this stream',
          onTap: () => _showAssignClassTeacherSheet(context),
        ),
        _FabAction(
          icon: Icons.assignment_ind_outlined,
          label: 'Assign Subject Teacher',
          subtitle: 'Assign a teacher to a subject in this stream',
          onTap: () => _showAssignSubjectTeacherSheet(context),
        ),
      ],
      _ => [],
    };
  }

  String _fabTooltipForContentTab(int tabIndex) {
    final actions = _actionsForContentTab(tabIndex);
    if (actions.length == 1) return actions.first.label;
    return 'Actions';
  }

  /// Handles FAB tap — direct action for single-action tabs, sheet for multi.
  void _handleFabTap(BuildContext context) {
    final actions = _actionsForContentTab(_selectedContentIndex);
    if (actions.isEmpty) return;
    if (actions.length == 1) {
      actions.first.onTap();
      return;
    }
    _showActionSheet(context, actions);
  }

  void _showStubSnackbar(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action — coming soon'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Action sheet ───────────────────────────────────────────────────────────

  void _showActionSheet(BuildContext context, List<_FabAction> actions) {
    final cs = Theme.of(context).colorScheme;
    final streamName = _selectedStreamName;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Text(
                '${widget.gradeLabel} · $streamName',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an action',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),

              // ── Actions ────────────────────────────────────────────────
              for (int i = 0; i < actions.length; i++) ...[
                _ActionTile(
                  icon: actions[i].icon,
                  label: actions[i].label,
                  subtitle: actions[i].subtitle,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    actions[i].onTap();
                  },
                ),
                if (i < actions.length - 1) const SizedBox(height: 4),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateExam(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    final term = termCtx.currentTerm;
    if (term == null) return;

    final schoolId = widget.schoolContext.membership.school.id;
    final stream = _selectedStream;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateExamFromGradeSheet(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        grade: widget.grade.grade,
        gradeLabel: widget.gradeLabel,
        stream: stream,
        allStreams: widget.grade.streams,
        entry: widget.schoolContext.currentEntry.value,
      ),
    );
  }
  // ── Assign subject teacher sheet ───────────────────────────────────────────

  void _showAssignSubjectTeacherSheet(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    final term = termCtx.currentTerm;
    if (term == null) return;

    final schoolId = widget.schoolContext.membership.school.id;
    final stream = _selectedStream;
    if (stream == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubjectTeacherPickerSheet(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        grade: widget.grade.grade,
        gradeLabel: widget.gradeLabel,
        streamCode: stream.code,
        streamName: stream.name,
        curriculumType: widget.curriculumType,
      ),
    );
  }

  // ── Assign class teacher sheet ─────────────────────────────────────────────

  void _showAssignClassTeacherSheet(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    final term = termCtx.currentTerm;
    if (term == null) return;

    final schoolId = widget.schoolContext.membership.school.id;
    final stream = _selectedStream;
    if (stream == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassTeacherPickerSheet(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        grade: widget.grade.grade,
        gradeLabel: widget.gradeLabel,
        streamCode: stream.code,
        streamName: stream.name,
      ),
    );
  }

  // ── Enroll student sheet ───────────────────────────────────────────────────

  void _showEnrollSheet(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    final term = termCtx.currentTerm;
    if (term == null) return;

    final schoolId = widget.schoolContext.membership.school.id;
    final stream = _selectedStream;
    if (stream == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentEnrollSheet(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        grade: widget.grade.grade,
        gradeLabel: widget.gradeLabel,
        streamCode: stream.code,
        streamName: stream.name,
        curriculumType: widget.curriculumType,
        allGrades: _allGradesFromConfig(),
      ),
    );
  }

  /// Builds a lookup of grade int → list of streams from the school config
  /// by scanning all curricula of the same type as this page's curriculum.
  List<GradeConfig> _allGradesFromConfig() {
    // We only have access to the single grade passed to this page, but
    // for labelling "Currently in Grade X Stream Y" on other grades we
    // return just what we know. The sheet will fall back gracefully.
    return [widget.grade];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Enroll Sheet — searchable picker with enrollment status
// ─────────────────────────────────────────────────────────────────────────────

class _StudentEnrollSheet extends StatefulWidget {
  const _StudentEnrollSheet({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.gradeLabel,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.allGrades,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final String gradeLabel;
  final int streamCode;
  final String streamName;
  final CurriculumType curriculumType;
  final List<GradeConfig> allGrades;

  @override
  State<_StudentEnrollSheet> createState() => _StudentEnrollSheetState();
}

class _StudentEnrollSheetState extends State<_StudentEnrollSheet> {
  final _searchCtrl = TextEditingController();
  final _membersDao = MembersDao(db);
  final _enrollmentsDao = EnrollmentsDao(db);

  List<_StudentEnrollCandidate> _results = [];
  bool _loading = true;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final students = await _membersDao.searchStudents(widget.schoolId, query);
    if (!mounted) return;

    // For each student, check current enrollment status in this term.
    final candidates = <_StudentEnrollCandidate>[];
    for (final s in students) {
      final enrollment = await _enrollmentsDao.getStudentEnrollment(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        studentAdm: s.adm,
      );
      if (!mounted) return;

      _EnrollStatus status;
      String? statusLabel;

      if (enrollment == null) {
        status = _EnrollStatus.notEnrolled;
        statusLabel = 'Not enrolled';
      } else if (enrollment.grade == widget.grade &&
          enrollment.stream == widget.streamCode) {
        status = _EnrollStatus.alreadyHere;
        statusLabel = 'Already enrolled';
      } else {
        status = _EnrollStatus.otherClass;
        final otherGradeLabel = _gradeLabelFor(enrollment.grade);
        final otherStreamName = _streamNameFor(
          enrollment.grade,
          enrollment.stream,
        );
        statusLabel =
            'Currently in $otherGradeLabel'
            '${otherStreamName != null ? ' · $otherStreamName' : ''}';
      }

      candidates.add(
        _StudentEnrollCandidate(
          student: s,
          status: status,
          statusLabel: statusLabel,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _results = candidates;
      _loading = false;
    });
  }

  String _gradeLabelFor(int grade) {
    final labels = gradeLabelsFor(widget.curriculumType);
    return labels[grade] ?? 'Grade $grade';
  }

  String? _streamNameFor(int grade, int streamCode) {
    for (final g in widget.allGrades) {
      if (g.grade == grade) {
        for (final s in g.streams) {
          if (s.code == streamCode) return s.name;
        }
        return null;
      }
    }
    return null;
  }

  Future<void> _enroll(_StudentEnrollCandidate candidate) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _enrolling = true);

    await _enrollmentsDao.enrollStudent(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
      studentAdm: candidate.student.adm,
      accountId: accountId,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${candidate.student.name} enrolled in '
          '${widget.gradeLabel} · ${widget.streamName}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Student',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Enroll into ${widget.gradeLabel} · ${widget.streamName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),

          // ── Search field ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2A3A)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by name or admission number…',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
                onChanged: (q) => _search(q),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Results list ─────────────────────────────────────────────
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'No active students found.'
                            : 'No students match "${_searchCtrl.text}"',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, i) =>
                        _buildCandidateRow(_results[i], cs, isDark),
                  ),
          ),

          // ── Enrolling overlay ────────────────────────────────────────
          if (_enrolling)
            Container(
              color: (isDark ? Colors.black : Colors.white).withValues(
                alpha: 0.5,
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCandidateRow(
    _StudentEnrollCandidate candidate,
    ColorScheme cs,
    bool isDark,
  ) {
    final s = candidate.student;
    final isDisabled = candidate.status == _EnrollStatus.alreadyHere;
    final isTransfer = candidate.status == _EnrollStatus.otherClass;

    final Color statusColor;
    switch (candidate.status) {
      case _EnrollStatus.notEnrolled:
        statusColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
      case _EnrollStatus.alreadyHere:
        statusColor = cs.primary.withValues(alpha: 0.7);
      case _EnrollStatus.otherClass:
        statusColor = const Color(0xFFE8A317);
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      enabled: !isDisabled && !_enrolling,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: cs.surfaceContainerHighest,
        child: Text(
          _initials(s.name),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        s.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDisabled
              ? cs.onSurface.withValues(alpha: 0.4)
              : cs.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            '${s.adm}',
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              candidate.statusLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      trailing: isDisabled
          ? Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: cs.primary.withValues(alpha: 0.5),
            )
          : isTransfer
          ? Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: const Color(0xFFE8A317).withValues(alpha: 0.7),
            )
          : null,
      onTap: isDisabled || _enrolling
          ? null
          : () {
              if (isTransfer) {
                _confirmTransfer(candidate);
              } else {
                _enroll(candidate);
              }
            },
    );
  }

  void _confirmTransfer(_StudentEnrollCandidate candidate) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Transfer student?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        content: Text(
          '${candidate.student.name} is ${candidate.statusLabel.toLowerCase()}. '
          'This will move them to ${widget.gradeLabel} · ${widget.streamName}.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _enroll(candidate);
            },
            child: Text(
              'Transfer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}

// ── Enroll status enum ───────────────────────────────────────────────────────

enum _EnrollStatus { notEnrolled, alreadyHere, otherClass }

// ═══════════════════════════════════════════════════════════════════════════════
// ── Assign Class Teacher Sheet ───────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _ClassTeacherPickerSheet extends StatefulWidget {
  const _ClassTeacherPickerSheet({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.gradeLabel,
    required this.streamCode,
    required this.streamName,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final String gradeLabel;
  final int streamCode;
  final String streamName;

  @override
  State<_ClassTeacherPickerSheet> createState() =>
      _ClassTeacherPickerSheetState();
}

class _ClassTeacherPickerSheetState extends State<_ClassTeacherPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _membersDao = MembersDao(db);
  final _subjectsDao = SubjectsDao(db);

  List<_TeacherCandidate> _allTeachers = [];
  List<_TeacherCandidate> _filtered = [];
  bool _loading = true;
  bool _assigning = false;
  String? _activeTeacherUserId;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _loading = true);

    // 1. Load the current active class teacher (if any).
    final activeStream = _subjectsDao.watchActiveClassTeacher(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    final activeRecord = await activeStream.first;
    if (!mounted) return;
    _activeTeacherUserId = activeRecord?.user.id;

    // 2. Load all teachers for this school.
    final teachersStream = _membersDao.watchTeachers(widget.schoolId);
    final teachersList = await teachersStream.first;
    if (!mounted) return;

    // 3. Resolve user data for each teacher.
    final candidates = <_TeacherCandidate>[];
    for (final t in teachersList) {
      final user = await _membersDao.findUserById(t.user);
      if (!mounted) return;
      if (user == null) continue;

      final isActive = t.user == _activeTeacherUserId;
      candidates.add(
        _TeacherCandidate(
          teacher: t,
          user: user,
          isCurrentClassTeacher: isActive,
        ),
      );
    }

    // Sort: active class teacher first, then alphabetically by name.
    candidates.sort((a, b) {
      if (a.isCurrentClassTeacher && !b.isCurrentClassTeacher) return -1;
      if (!a.isCurrentClassTeacher && b.isCurrentClassTeacher) return 1;
      return a.user.name.compareTo(b.user.name);
    });

    if (!mounted) return;
    setState(() {
      _allTeachers = candidates;
      _filtered = candidates;
      _loading = false;
    });
  }

  void _filterTeachers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _allTeachers);
      return;
    }
    setState(() {
      _filtered = _allTeachers
          .where((c) => c.user.name.toLowerCase().contains(q))
          .toList();
    });
  }

  Future<void> _assign(_TeacherCandidate candidate) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _assigning = true);

    await _subjectsDao.assignClassTeacher(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
      teacherUserId: candidate.teacher.user,
      accountId: accountId,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${candidate.user.name} assigned as class teacher '
          'for ${widget.gradeLabel} · ${widget.streamName}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assign Class Teacher',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.gradeLabel} · ${widget.streamName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),

          // ── Search field ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2A3A)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
                onChanged: _filterTeachers,
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Results list ─────────────────────────────────────────────
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'No teachers found at this school.'
                            : 'No teachers match "${_searchCtrl.text}"',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) =>
                        _buildTeacherRow(_filtered[i], cs, isDark),
                  ),
          ),

          // ── Assigning overlay ────────────────────────────────────────
          if (_assigning)
            Container(
              color: (isDark ? Colors.black : Colors.white).withValues(
                alpha: 0.5,
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeacherRow(
    _TeacherCandidate candidate,
    ColorScheme cs,
    bool isDark,
  ) {
    final u = candidate.user;
    final t = candidate.teacher;
    final isActive = candidate.isCurrentClassTeacher;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      enabled: !isActive && !_assigning,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isActive
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerHighest,
        child: Text(
          _initials(u.name),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isActive ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        u.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isActive ? cs.onSurface.withValues(alpha: 0.5) : cs.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          if (t.role != null && t.role!.isNotEmpty) ...[
            Text(
              t.role!,
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            if (t.department != null && t.department!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
          if (t.department != null && t.department!.isNotEmpty)
            Flexible(
              child: Text(
                t.department!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          if ((t.role == null || t.role!.isEmpty) &&
              (t.department == null || t.department!.isEmpty))
            Text(
              'Teacher',
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          if (isActive) ...[
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Current class teacher',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
      trailing: isActive
          ? Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: cs.primary.withValues(alpha: 0.5),
            )
          : null,
      onTap: isActive || _assigning ? null : () => _assign(candidate),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}

class _TeacherCandidate {
  const _TeacherCandidate({
    required this.teacher,
    required this.user,
    required this.isCurrentClassTeacher,
  });

  final TeachersData teacher;
  final UsersData user;
  final bool isCurrentClassTeacher;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Assign Subject Teacher Sheet ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _SubjectTeacherPickerSheet extends StatefulWidget {
  const _SubjectTeacherPickerSheet({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.gradeLabel,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final String gradeLabel;
  final int streamCode;
  final String streamName;
  final CurriculumType curriculumType;

  @override
  State<_SubjectTeacherPickerSheet> createState() =>
      _SubjectTeacherPickerSheetState();
}

class _SubjectTeacherPickerSheetState
    extends State<_SubjectTeacherPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _membersDao = MembersDao(db);
  final _subjectsDao = SubjectsDao(db);

  // ── Step state ─────────────────────────────────────────────────────────────
  // Step 0 = subject picker, Step 1 = teacher picker.
  int _step = 0;

  // ── Step 0 — subject list ──────────────────────────────────────────────────
  List<_SubjectCandidate> _allSubjects = [];
  List<_SubjectCandidate> _filteredSubjects = [];
  bool _loadingSubjects = true;

  // ── Step 1 — teacher list ──────────────────────────────────────────────────
  int? _selectedSubjectIndex;
  String? _selectedSubjectName;
  String? _currentTeacherUserId; // teacher already assigned to this subject
  List<_TeacherCandidate> _allTeachers = [];
  List<_TeacherCandidate> _filteredTeachers = [];
  bool _loadingTeachers = true;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Grade → Level mapping ──────────────────────────────────────────────────

  /// Returns all valid subject indices for the given grade int.
  ///
  /// For CBC:
  ///   PP1(1),PP2(2) → level 0; Grade1–3(3–5) → level 1; Grade4–6(6–8) → level 2;
  ///   Grade7–9(9–11) → level 3; Grade10–12(12–14) → levels 4,5,6 (union).
  ///
  /// For 8-4-4:
  ///   Std1–3(1–3) → level 0; Std4–8(4–8) → level 1;
  ///   Form1–2(41–42) → level 2; Form3–4(43–44) → level 3.
  List<int> _subjectsForGrade() {
    final levels = levelsFor(widget.curriculumType);
    final grade = widget.grade;

    // Build grade → level index ranges for each curriculum.
    List<int> cbcLevelIndicesForGrade(int g) {
      if (g <= 2) return [0];
      if (g <= 5) return [1];
      if (g <= 8) return [2];
      if (g <= 11) return [3];
      if (g <= 14) return [4, 5, 6]; // all senior pathways
      return [];
    }

    List<int> eightFourFourLevelIndicesForGrade(int g) {
      if (g <= 3) return [0];
      if (g <= 8) return [1];
      if (g <= 42) return [2]; // Form 1–2 = 41–42
      if (g <= 44) return [3]; // Form 3–4 = 43–44
      return [];
    }

    final levelIndices = widget.curriculumType == CurriculumType.cbc
        ? cbcLevelIndicesForGrade(grade)
        : eightFourFourLevelIndicesForGrade(grade);

    // Collect all subjects from matching levels (union for multiple pathways).
    final subjects = <int>{};
    for (final li in levelIndices) {
      if (li < levels.length) {
        subjects.addAll(levels[li].subjects);
      }
    }
    final sorted = subjects.toList()..sort();
    return sorted;
  }

  // ── Load subjects ──────────────────────────────────────────────────────────

  Future<void> _loadSubjects() async {
    setState(() => _loadingSubjects = true);

    // Get all valid subject indices for this grade.
    final validSubjects = _subjectsForGrade();

    // Get currently assigned subjects for this class.
    final assignedStream = _subjectsDao.watchSubjectsForClass(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    final assignedList = await assignedStream.first;
    if (!mounted) return;

    // Build a map of subject index → assigned teacher name.
    final assignedMap = <int, String>{};
    for (final entry in assignedList) {
      assignedMap[entry.subject.subject] = entry.teacher.name;
    }

    // Build candidate list.
    final candidates = <_SubjectCandidate>[];
    for (final subjectIndex in validSubjects) {
      final label = subjectLabel(widget.curriculumType, subjectIndex);
      final assignedTeacher = assignedMap[subjectIndex];
      candidates.add(
        _SubjectCandidate(
          subjectIndex: subjectIndex,
          subjectName: label,
          assignedTeacherName: assignedTeacher,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _allSubjects = candidates;
      _filteredSubjects = candidates;
      _loadingSubjects = false;
    });
  }

  void _filterSubjects(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredSubjects = _allSubjects);
      return;
    }
    setState(() {
      _filteredSubjects = _allSubjects
          .where((c) => c.subjectName.toLowerCase().contains(q))
          .toList();
    });
  }

  // ── Select subject → load teachers ─────────────────────────────────────────

  void _selectSubject(_SubjectCandidate candidate) {
    _searchCtrl.clear();
    setState(() {
      _step = 1;
      _selectedSubjectIndex = candidate.subjectIndex;
      _selectedSubjectName = candidate.subjectName;
      _loadingTeachers = true;
    });

    // Find the currently assigned teacher for this subject (if any).
    final assignedEntry = _allSubjects.firstWhere(
      (s) => s.subjectIndex == candidate.subjectIndex,
    );
    // We need to find the teacher user id, not just the name.
    _loadTeachers(assignedEntry);
  }

  Future<void> _loadTeachers(_SubjectCandidate forSubject) async {
    // Get the current assignment to find the teacher user id.
    final assignment = await _subjectsDao.getSubjectAssignment(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
      subject: forSubject.subjectIndex,
    );
    if (!mounted) return;
    _currentTeacherUserId = assignment?.teacher;

    // Load all teachers for this school.
    final teachersStream = _membersDao.watchTeachers(widget.schoolId);
    final teachersList = await teachersStream.first;
    if (!mounted) return;

    // Resolve user data for each teacher.
    final candidates = <_TeacherCandidate>[];
    for (final t in teachersList) {
      final user = await _membersDao.findUserById(t.user);
      if (!mounted) return;
      if (user == null) continue;

      final isActive = t.user == _currentTeacherUserId;
      candidates.add(
        _TeacherCandidate(
          teacher: t,
          user: user,
          isCurrentClassTeacher:
              isActive, // reusing field as "currently assigned"
        ),
      );
    }

    // Sort: currently assigned first, then alphabetically by name.
    candidates.sort((a, b) {
      if (a.isCurrentClassTeacher && !b.isCurrentClassTeacher) return -1;
      if (!a.isCurrentClassTeacher && b.isCurrentClassTeacher) return 1;
      return a.user.name.compareTo(b.user.name);
    });

    if (!mounted) return;
    setState(() {
      _allTeachers = candidates;
      _filteredTeachers = candidates;
      _loadingTeachers = false;
    });
  }

  void _filterTeachers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredTeachers = _allTeachers);
      return;
    }
    setState(() {
      _filteredTeachers = _allTeachers
          .where((c) => c.user.name.toLowerCase().contains(q))
          .toList();
    });
  }

  // ── Assign ─────────────────────────────────────────────────────────────────

  Future<void> _assign(_TeacherCandidate candidate) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null || _selectedSubjectIndex == null) return;

    setState(() => _assigning = true);

    await _subjectsDao.assignSubjectTeacher(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
      subject: _selectedSubjectIndex!,
      teacherUserId: candidate.teacher.user,
      accountId: accountId,
    );

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_selectedSubjectName assigned to ${candidate.user.name}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Back to step 0 ─────────────────────────────────────────────────────────

  void _goBack() {
    _searchCtrl.clear();
    setState(() {
      _step = 0;
      _selectedSubjectIndex = null;
      _selectedSubjectName = null;
      _currentTeacherUserId = null;
      _allTeachers = [];
      _filteredTeachers = [];
      _filteredSubjects = _allSubjects;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                if (_step == 1) ...[
                  GestureDetector(
                    onTap: _goBack,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    _step == 0
                        ? 'Assign Subject Teacher'
                        : _selectedSubjectName ?? 'Choose Teacher',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _step == 0
                    ? '${widget.gradeLabel} · ${widget.streamName} — Choose a subject'
                    : '${widget.gradeLabel} · ${widget.streamName} — Choose a teacher',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),

          // ── Search field ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2A3A)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: _step == 0 ? 'Search subjects…' : 'Search by name…',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
                onChanged: _step == 0 ? _filterSubjects : _filterTeachers,
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Content ──────────────────────────────────────────────────
          Flexible(
            child: _step == 0
                ? _buildSubjectList(cs, isDark)
                : _buildTeacherList(cs, isDark),
          ),

          // ── Assigning overlay ────────────────────────────────────────
          if (_assigning)
            Container(
              color: (isDark ? Colors.black : Colors.white).withValues(
                alpha: 0.5,
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step 0: Subject list ───────────────────────────────────────────────────

  Widget _buildSubjectList(ColorScheme cs, bool isDark) {
    if (_loadingSubjects) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_filteredSubjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _searchCtrl.text.isEmpty
                ? 'No subjects available for this grade.'
                : 'No subjects match "${_searchCtrl.text}"',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: _filteredSubjects.length,
      itemBuilder: (context, i) =>
          _buildSubjectRow(_filteredSubjects[i], cs, isDark),
    );
  }

  Widget _buildSubjectRow(
    _SubjectCandidate candidate,
    ColorScheme cs,
    bool isDark,
  ) {
    final isAssigned = candidate.assignedTeacherName != null;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isAssigned
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.menu_book_outlined,
          size: 16,
          color: isAssigned
              ? cs.primary.withValues(alpha: 0.7)
              : cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      title: Text(
        candidate.subjectName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        isAssigned ? candidate.assignedTeacherName! : 'Not assigned',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          color: isAssigned
              ? cs.primary.withValues(alpha: 0.6)
              : cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
      ),
      onTap: () => _selectSubject(candidate),
    );
  }

  // ── Step 1: Teacher list ───────────────────────────────────────────────────

  Widget _buildTeacherList(ColorScheme cs, bool isDark) {
    if (_loadingTeachers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_filteredTeachers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _searchCtrl.text.isEmpty
                ? 'No teachers found at this school.'
                : 'No teachers match "${_searchCtrl.text}"',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, i) =>
          _buildTeacherRowForSubject(_filteredTeachers[i], cs, isDark),
    );
  }

  Widget _buildTeacherRowForSubject(
    _TeacherCandidate candidate,
    ColorScheme cs,
    bool isDark,
  ) {
    final u = candidate.user;
    final t = candidate.teacher;
    final isActive = candidate.isCurrentClassTeacher; // currently assigned

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      enabled: !isActive && !_assigning,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isActive
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerHighest,
        child: Text(
          _initials(u.name),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isActive ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        u.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isActive ? cs.onSurface.withValues(alpha: 0.5) : cs.onSurface,
        ),
      ),
      subtitle: Row(
        children: [
          if (t.role != null && t.role!.isNotEmpty) ...[
            Text(
              t.role!,
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            if (t.department != null && t.department!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
          if (t.department != null && t.department!.isNotEmpty)
            Flexible(
              child: Text(
                t.department!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          if ((t.role == null || t.role!.isEmpty) &&
              (t.department == null || t.department!.isEmpty))
            Text(
              'Teacher',
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          if (isActive) ...[
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Currently assigned',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
      trailing: isActive
          ? Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: cs.primary.withValues(alpha: 0.5),
            )
          : null,
      onTap: isActive || _assigning ? null : () => _assign(candidate),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}

class _SubjectCandidate {
  const _SubjectCandidate({
    required this.subjectIndex,
    required this.subjectName,
    this.assignedTeacherName,
  });

  final int subjectIndex;
  final String subjectName;
  final String? assignedTeacherName;
}

// ── Candidate model ──────────────────────────────────────────────────────────

class _StudentEnrollCandidate {
  const _StudentEnrollCandidate({
    required this.student,
    required this.status,
    required this.statusLabel,
  });

  final StudentsData student;
  final _EnrollStatus status;
  final String statusLabel;
}

// ─────────────────────────────────────────────────────────────────────────────
// Action tile — compact list tile for the FAB action sheet
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Create Exam from Grade Page — pre-filled bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateExamFromGradeSheet extends StatefulWidget {
  const _CreateExamFromGradeSheet({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.gradeLabel,
    required this.stream,
    required this.allStreams,
    required this.entry,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final String gradeLabel;
  final GradeStream? stream; // null when on Comparisons (shouldn't happen)
  final List<GradeStream> allStreams;
  final MembershipEntry entry;

  @override
  State<_CreateExamFromGradeSheet> createState() =>
      _CreateExamFromGradeSheetState();
}

class _CreateExamFromGradeSheetState extends State<_CreateExamFromGradeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final ExamsGradesDao _dao;
  bool _saving = false;

  ExamType _type = ExamType.exam;
  bool _allStreams = false;
  bool _personalized = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final teacherId = widget.entry is TeacherEntry
        ? (widget.entry as TeacherEntry).teacher.user
        : accountId;

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final examId = _generateExamId();
      final startDays = _startDate.millisecondsSinceEpoch ~/ (86400 * 1000);
      final endDays = _endDate.millisecondsSinceEpoch ~/ (86400 * 1000);

      await _dao.createExam(
        exam: ExamsCompanion(
          id: Value(examId),
          school: Value(widget.schoolId),
          year: Value(widget.year),
          term: Value(widget.term),
          grade: Value(widget.grade),
          stream: Value(_allStreams ? null : widget.stream?.code),
          personalized: Value(_personalized),
          type: Value(_type),
          start: Value(startDays),
          end: Value(endDays),
          teacher: Value(teacherId),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam created'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title.
                Text(
                  'New Exam / Assessment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.gradeLabel}${widget.stream != null ? ' · ${widget.stream!.name}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Type selector ────────────────────────────────────────
                _ExamFieldLabel(label: 'Type', cs: cs),
                const SizedBox(height: 6),
                _ExamSegmentedRow<ExamType>(
                  options: ExamType.values,
                  selected: _type,
                  labelOf: (t) => switch (t) {
                    ExamType.exam => 'Exam',
                    ExamType.assignment => 'Assignment',
                    ExamType.assessment => 'Assessment',
                  },
                  onSelected: (t) => setState(() => _type = t),
                  cs: cs,
                ),
                const SizedBox(height: 16),

                // ── Stream scope ─────────────────────────────────────────
                if (widget.allStreams.length > 1 && widget.stream != null) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _allStreams,
                          onChanged: (v) =>
                              setState(() => _allStreams = v ?? false),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Apply to all streams in ${widget.gradeLabel}',
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Personalized toggle ──────────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _personalized,
                        onChanged: (v) =>
                            setState(() => _personalized = v ?? false),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalized exam',
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                          ),
                          Text(
                            'Different questions per student',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Date range ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ExamDateField(
                        label: 'Start date',
                        date: _startDate,
                        cs: cs,
                        onPicked: (d) => setState(() => _startDate = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ExamDateField(
                        label: 'End date',
                        date: _endDate,
                        cs: cs,
                        onPicked: (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Save button ──────────────────────────────────────────
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text(
                          'Create Exam',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _generateExamId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = math.Random().nextInt(0x7FFFFFFF);
    return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lightweight helper widgets for the exam creation sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ExamFieldLabel extends StatelessWidget {
  const _ExamFieldLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ExamSegmentedRow<T> extends StatelessWidget {
  const _ExamSegmentedRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    required this.cs,
  });
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: opt == options.last ? 0 : 4),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
              ),
              child: Text(
                labelOf(opt),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

const _kExamMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _ExamDateField extends StatelessWidget {
  const _ExamDateField({
    required this.label,
    required this.date,
    required this.cs,
    required this.onPicked,
  });
  final String label;
  final DateTime date;
  final ColorScheme cs;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2050),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day.toString().padLeft(2, '0')} ${_kExamMonths[date.month - 1]} ${date.year}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight data class describing a single FAB action.
class _FabAction {
  const _FabAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
