import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/exam_group.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_filter_toolbar.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import 'exam_creation_page.dart';
import '../academics/paper_detail_page.dart';

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
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
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

    CurriculumType _curriculumForGrade(int grade) {
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

      if (_curriculumForGrade(gradeNum) == CurriculumType.cbc) {
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

    return switch (_view) {
      _ExamsView.list => _ExamsListView(
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
          return _ExamGroupDetailView(
            group: group,
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            config: _config,
            subjectNames: _subjectNames,
            entry: entry,
            onBack: _popToList,
            onPaperTap: _openPaper,
            onDeleted: _popToList,
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
      _ExamsView.paperDetail => _PaperDetailView(
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

// ─────────────────────────────────────────────────────────────────────────────
// Exams list view
// ─────────────────────────────────────────────────────────────────────────────

class _ExamsListView extends StatefulWidget {
  const _ExamsListView({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.schoolContext,
    required this.config,
    required this.subjectNames,
    required this.entry,
    required this.onExamTap,
  });
  final String schoolId;
  final int year;
  final int term;
  final SchoolContext schoolContext;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final MembershipEntry entry;
  final ValueChanged<ExamGroup> onExamTap;

  @override
  State<_ExamsListView> createState() => _ExamsListViewState();
}

class _ExamsListViewState extends State<_ExamsListView> {
  late final ExamsGradesDao _dao;

  // ── Search & filter state ──────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  bool _showFilters = false;
  String _searchQuery = '';
  final Set<ExamType> _activeTypeFilters = {};

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<List<ExamGroup>> _buildStream() {
    return _dao.watchExamGroups(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
  }

  /// Extract a display name from an [ExamGroup].
  /// Uses the name from the first exam row in the group.
  String _examGroupName(ExamGroup group) {
    if (group.grades.isNotEmpty && group.grades.first.streams.isNotEmpty) {
      return group.grades.first.streams.first.exam.name;
    }
    return _typeLabel(group.type);
  }

  /// Filter [items] by the current search query and active type filters.
  List<ExamGroup> _applyFilters(List<ExamGroup> items) {
    var filtered = items;

    // Apply type filter
    if (_activeTypeFilters.isNotEmpty) {
      filtered = filtered
          .where((g) => _activeTypeFilters.contains(g.type))
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final lower = _searchQuery.toLowerCase();
      filtered = filtered.where((g) {
        final name = _examGroupName(g).toLowerCase();
        return name.contains(lower);
      }).toList();
    }

    return filtered;
  }

  void _toggleTypeFilter(ExamType type) {
    setState(() {
      if (_activeTypeFilters.contains(type)) {
        _activeTypeFilters.remove(type);
      } else {
        _activeTypeFilters.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canManage
          ? FloatingActionButton.small(
              heroTag: 'fab_exams_list',
              onPressed: () => _showCreateExam(context),
              tooltip: 'New Exam',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Exams & Assessments',
            subtitle: '${widget.year} · Term ${widget.term}',
          ),
          // ── Search + filter toolbar ──────────────────────────────────
          EduFilterToolbar(
            searchController: _searchCtrl,
            searchHint: 'Search exams…',
            showSearch: _showSearch,
            onToggleSearch: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              });
            },
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            showFilters: _showFilters,
            onToggleFilters: () => setState(() => _showFilters = !_showFilters),
            filters: ExamType.values.map((t) {
              return EduFilterChipData(
                label: _typeLabel(t),
                isSelected: _activeTypeFilters.contains(t),
                onTap: () => _toggleTypeFilter(t),
                activeColor: _typeColor(t, cs),
              );
            }).toList(),
          ),
          Expanded(
            child: StreamBuilder<List<ExamGroup>>(
              stream: _buildStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  );
                }
                final allItems = snap.data ?? [];
                if (allItems.isEmpty) {
                  return _EmptyExamsState(canCreate: _canManage);
                }
                final items = _applyFilters(allItems);
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No matching exams',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    return _ExamGroupRow(
                      group: items[i],
                      config: widget.config,
                      onTap: () => widget.onExamTap(items[i]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _canManage {
    final entry = widget.entry;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
  }

  Future<void> _showCreateExam(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamCreationPage(
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          config: widget.config,
          entry: widget.entry,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exam group row — data-table-style row (replaces _ExamGroupCard)
// ─────────────────────────────────────────────────────────────────────────────

class _ExamGroupRow extends StatefulWidget {
  const _ExamGroupRow({
    required this.group,
    required this.config,
    required this.onTap,
  });
  final ExamGroup group;
  final SchoolConfig config;
  final VoidCallback onTap;

  @override
  State<_ExamGroupRow> createState() => _ExamGroupRowState();
}

class _ExamGroupRowState extends State<_ExamGroupRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final typeColor = _typeColor(widget.group.type, cs);
    final typeLabel = _typeLabel(widget.group.type);
    final startDate = DateTime.fromMillisecondsSinceEpoch(
      widget.group.start * 86400 * 1000,
    );
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      widget.group.end * 86400 * 1000,
    );
    final gradeCount = widget.group.grades.length;
    final paperCount = widget.group.grades.fold<int>(
      0,
      (sum, g) => sum + g.streams.length,
    );
    final examName =
        widget.group.grades.isNotEmpty &&
            widget.group.grades.first.streams.isNotEmpty
        ? widget.group.grades.first.streams.first.exam.name
        : typeLabel;

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? typeColor.withValues(alpha: 0.12)
        : typeColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? typeColor.withValues(alpha: 0.18)
        : typeColor.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _isPressed
                    ? pressBg
                    : _isHovered
                    ? hoverBg
                    : idleBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? typeColor.withValues(alpha: isDark ? 0.35 : 0.25)
                      : cs.outline.withValues(alpha: isDark ? 0.10 : 0.08),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Colored accent bar ──────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 4 : 3,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(
                            alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Content ─────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── Left: name, type badge, date, grades ─
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Exam name
                                    Text(
                                      examName,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    // Type badge + date
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(
                                              alpha: isDark ? 0.18 : 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.kChipRadius,
                                            ),
                                          ),
                                          child: Text(
                                            typeLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: typeColor,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 11,
                                          color: cs.onSurfaceVariant.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${_fmtDate(startDate)} – ${_fmtDate(endDate)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color: cs.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Grade chips
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: widget.group.grades
                                          .map(
                                            (g) => _ClassChip(
                                              label: _gradeLabel(
                                                g.grade,
                                                widget.config,
                                              ),
                                              cs: cs,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // ── Right: badges + chevron ─────────────
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MetaBadge(
                                    icon: Icons.school_outlined,
                                    label: '$gradeCount',
                                    cs: cs,
                                  ),
                                  const SizedBox(width: 4),
                                  _MetaBadge(
                                    icon: Icons.note_alt_outlined,
                                    label: '$paperCount',
                                    cs: cs,
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedSlide(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    offset: Offset(_isHovered ? 0.15 : 0.0, 0),
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      opacity: _isHovered ? 0.8 : 0.35,
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: _isHovered
                                            ? typeColor
                                            : cs.onSurfaceVariant,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exam group detail view — grade tabs, stream sub-tabs, paper content
// ─────────────────────────────────────────────────────────────────────────────

class _ExamGroupDetailView extends StatefulWidget {
  const _ExamGroupDetailView({
    required this.group,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.subjectNames,
    required this.entry,
    required this.onBack,
    required this.onPaperTap,
    required this.onDeleted,
    this.initialGradeIndex = 0,
    this.initialStreamIndex = 0,
    this.initialDayIndex = 0,
    this.onDayChanged,
  });
  final ExamGroup group;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final MembershipEntry entry;
  final VoidCallback onBack;
  final void Function(Paper paper, Exam exam, int grade, {int streamIndex})
  onPaperTap;
  final VoidCallback onDeleted;
  final int initialGradeIndex;
  final int initialStreamIndex;
  final int initialDayIndex;
  final ValueChanged<int>? onDayChanged;

  @override
  State<_ExamGroupDetailView> createState() => _ExamGroupDetailViewState();
}

class _ExamGroupDetailViewState extends State<_ExamGroupDetailView>
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
  }

  @override
  void didUpdateWidget(covariant _ExamGroupDetailView oldWidget) {
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
    super.dispose();
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

  bool get _canManage {
    final entry = widget.entry;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
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
      builder: (_) => _CreatePaperSheet(
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
      ),
    );
  }

  Future<void> _showAddGradeModal(BuildContext context) async {
    await showEduSheet<void>(
      context: context,
      maxWidth: 520,
      builder: (_) => _AddGradeToExamForm(
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
      ),
    );
  }

  Future<void> _showAddStreamModal(BuildContext context) async {
    await showEduSheet<void>(
      context: context,
      maxWidth: 520,
      builder: (_) => _AddStreamForm(
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
      ),
    );
  }

  Future<void> _showEditExamName(BuildContext context) async {
    final group = widget.group;
    final currentName =
        group.grades.isNotEmpty && group.grades.first.streams.isNotEmpty
        ? group.grades.first.streams.first.exam.name
        : '';
    final ctrl = TextEditingController(text: currentName);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF18222E) : cs.surface;

    await showEduSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.4 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save', style: TextStyle(fontSize: 13)),
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
        ? _streamLabel(currentGrade.grade, sc, widget.config)
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
        .map((g) => EduTab(label: _gradeLabel(g.grade, widget.config)))
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
                            : _streamLabel(
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
    final typeLabel = _typeLabel(group.type);
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
                                    : typeLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$typeLabel · $subtitle',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_canManage)
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
                  if (_canManage)
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
                            if (_canManage)
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
                                canManage: _canManage,
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
        if (_canManage)
          Positioned(
            right: 12,
            bottom: 16,
            child: _ExpandableFab(
              paperEnabled: _hasStreamSelection,
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
// Add Stream to Exam — Form
// ─────────────────────────────────────────────────────────────────────────────

/// A single-step form for adding missing streams to an existing grade within
/// an exam group.  The user picks a grade (skipped when only one grade has
/// missing streams), then picks which missing stream(s) to add, configures
/// papers per stream, and saves.
class _AddStreamForm extends StatefulWidget {
  const _AddStreamForm({
    required this.group,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.subjectNames,
    required this.dao,
    required this.subjectsDao,
    required this.membersDao,
    required this.onClose,
  });

  final ExamGroup group;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;
  final MembersDao membersDao;
  final VoidCallback onClose;

  @override
  State<_AddStreamForm> createState() => _AddStreamFormState();
}

class _AddStreamFormState extends State<_AddStreamForm> {
  // ── Grade selection ────────────────────────────────────────────────────────
  // The grade index currently being configured (index into _gradesWithMissing).
  int _selectedGradeIndex = 0;

  // ── Stream dropdown overlay ────────────────────────────────────────────────
  // The stream code currently shown in the paper-config area.
  int? _activeStreamCode; // null = no stream selected yet

  // ── Paper slot state ───────────────────────────────────────────────────────
  // Slots keyed by stream code; streams with no slots are still saveable (no papers).
  final Map<int?, List<_GradePaperSlot>> _paperSlots = {};

  // ── Subject / teacher loading ──────────────────────────────────────────────
  final Map<int?, List<({SubjectTeacher subject, UsersData teacher})>>
  _subjects = {};
  final Map<int?, bool> _loadingSubjects = {};
  List<({TeachersData teacher, UsersData user})> _teachers = [];
  bool _teachersLoaded = false;

  // ── Misc ───────────────────────────────────────────────────────────────────
  bool _saving = false;

  // ── Invigilator conflict tracking ──────────────────────────────────────────
  Map<String, String> _slotConflicts = {};

  // ── Overlay for stream dropdown ────────────────────────────────────────────
  OverlayEntry? _streamOverlay;
  final GlobalKey _streamTriggerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    // Auto-select first grade with missing streams
    final grades = _gradesWithMissing;
    if (grades.isNotEmpty) {
      // Auto-select first available stream for that grade
      final missing = _missingStreamsForGrade(grades[0].grade);
      if (missing.isNotEmpty) {
        _activeStreamCode = missing.first;
        _loadSubjectsForStream(grades[0].grade, missing.first);
      }
    }
  }

  @override
  void dispose() {
    _closeStreamOverlay();
    super.dispose();
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  /// Grades that already participate in the exam group AND still have at
  /// least one stream missing from the group.
  List<GradeConfig> get _gradesWithMissing {
    final result = <GradeConfig>[];
    for (final gradeEntry in widget.group.grades) {
      final gc = _gradeConfigFor(gradeEntry.grade);
      if (gc == null) continue;
      if (_missingStreamsForGrade(gradeEntry.grade).isNotEmpty) {
        result.add(gc);
      }
    }
    return result;
  }

  GradeConfig? _gradeConfigFor(int grade) {
    for (final curriculum in widget.config.curricula) {
      final gc = curriculum.grades.where((g) => g.grade == grade).firstOrNull;
      if (gc != null) return gc;
    }
    return null;
  }

  /// Stream codes present in the config but NOT yet in the exam group for
  /// the given grade.
  List<int?> _missingStreamsForGrade(int grade) {
    final gc = _gradeConfigFor(grade);
    if (gc == null) return [];
    // Find streams already in the group for this grade
    final existing = <int?>{};
    for (final gradeEntry in widget.group.grades) {
      if (gradeEntry.grade != grade) continue;
      for (final se in gradeEntry.streams) {
        existing.add(se.streamCode);
      }
    }
    if (gc.streams.isEmpty) {
      // No-stream grade — already covered if null is in existing
      if (existing.contains(null)) return [];
      return [null];
    }
    return gc.streams
        .map((s) => s.code as int?)
        .where((c) => !existing.contains(c))
        .toList();
  }

  GradeConfig? get _currentGradeConfig {
    final grades = _gradesWithMissing;
    if (grades.isEmpty) return null;
    final idx = _selectedGradeIndex.clamp(0, grades.length - 1);
    return grades[idx];
  }

  int? get _currentGrade => _currentGradeConfig?.grade;

  List<int?> get _currentMissingStreams {
    final grade = _currentGrade;
    if (grade == null) return [];
    return _missingStreamsForGrade(grade);
  }

  String _streamName(int grade, int? streamCode) {
    if (streamCode == null) return 'All Streams';
    return _streamLabel(grade, streamCode, widget.config);
  }

  List<DateTime> get _examDays {
    final start = DateTime.fromMillisecondsSinceEpoch(
      widget.group.start * 86400 * 1000,
      isUtc: true,
    );
    final end = DateTime.fromMillisecondsSinceEpoch(
      widget.group.end * 86400 * 1000,
      isUtc: true,
    );
    final days = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endLocal)) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  List<_GradePaperSlot> _slotsFor(int? streamCode) =>
      _paperSlots.putIfAbsent(streamCode, () => []);

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _loadTeachers() async {
    try {
      final teachersList = await widget.membersDao
          .watchTeachers(widget.schoolId)
          .first;
      if (!mounted) return;
      final results = <({TeachersData teacher, UsersData user})>[];
      for (final t in teachersList) {
        final user = await widget.membersDao.findUserById(t.user);
        if (!mounted) return;
        if (user != null) results.add((teacher: t, user: user));
      }
      if (mounted) {
        setState(() {
          _teachers = results
            ..sort((a, b) => a.user.name.compareTo(b.user.name));
          _teachersLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teachersLoaded = true);
    }
  }

  Future<void> _loadSubjectsForStream(int grade, int? streamCode) async {
    if (_loadingSubjects[streamCode] == true ||
        _subjects.containsKey(streamCode)) {
      return;
    }
    setState(() => _loadingSubjects[streamCode] = true);
    try {
      final result = streamCode != null
          ? (await widget.subjectsDao.getSubjectsForClass(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: grade,
              stream: streamCode,
            )).map((s) => (subject: s.subject, teacher: s.teacher)).toList()
          : <({SubjectTeacher subject, UsersData teacher})>[];
      if (mounted) {
        setState(() {
          _subjects[streamCode] = result;
          _loadingSubjects[streamCode] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubjects[streamCode] = false);
    }
  }

  // ── Invigilator conflict helpers ──────────────────────────────────────────

  /// Checks if a teacher is already assigned to a paper slot at the same
  /// time in a different stream.
  bool _isInvigilatorBusy(
    String teacherId,
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final entry in _paperSlots.entries) {
      if (entry.key == excludeStreamCode) continue;
      for (final slot in entry.value) {
        if (slot.invigilatorId != teacherId) continue;
        if (!(slot.date.year == day.year &&
            slot.date.month == day.month &&
            slot.date.day == day.day)) {
          continue;
        }
        final sStart = slot.startTime.hour * 60 + slot.startTime.minute;
        final sEnd = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin < sEnd && sStart < endMin) return true;
      }
    }
    return false;
  }

  /// Finds a teacher who is not busy at the given time in any stream.
  String? _findAvailableTeacher(
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final t in _teachers) {
      if (!_isInvigilatorBusy(
        t.user.id,
        day,
        startMin,
        endMin,
        excludeStreamCode,
      )) {
        return t.user.id;
      }
    }
    return null;
  }

  /// Scans all paper slots across all streams and returns a map of
  /// slot ID → error message for conflicting invigilators.
  Map<String, String> _findInvigilatorConflicts() {
    final conflicts = <String, String>{};
    final all = <({int? streamCode, _GradePaperSlot slot})>[];
    for (final entry in _paperSlots.entries) {
      for (final slot in entry.value) {
        if (slot.invigilatorId != null &&
            slot.invigilatorId!.isNotEmpty &&
            slot.subjectCode != null) {
          all.add((streamCode: entry.key, slot: slot));
        }
      }
    }
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.streamCode == b.streamCode) continue;
        if (a.slot.invigilatorId != b.slot.invigilatorId) continue;
        if (!(a.slot.date.year == b.slot.date.year &&
            a.slot.date.month == b.slot.date.month &&
            a.slot.date.day == b.slot.date.day)) {
          continue;
        }
        final aStart = a.slot.startTime.hour * 60 + a.slot.startTime.minute;
        final aEnd = a.slot.endTime.hour * 60 + a.slot.endTime.minute;
        final bStart = b.slot.startTime.hour * 60 + b.slot.startTime.minute;
        final bEnd = b.slot.endTime.hour * 60 + b.slot.endTime.minute;
        if (aStart < bEnd && bStart < aEnd) {
          final teacherName =
              _teachers
                  .where((t) => t.user.id == a.slot.invigilatorId)
                  .map((t) => t.user.name)
                  .firstOrNull ??
              'Teacher';
          final msg = '$teacherName is assigned to another paper at this time';
          conflicts[a.slot.id] = msg;
          conflicts[b.slot.id] = msg;
        }
      }
    }
    return conflicts;
  }

  void _recomputeConflicts() {
    _slotConflicts = _findInvigilatorConflicts();
  }

  // ── Auto-fill ─────────────────────────────────────────────────────────────

  void _autoFillStream(int grade, int? streamCode) {
    final subjs = _subjects[streamCode] ?? [];
    if (subjs.isEmpty) return;
    final days = _examDays;
    if (days.isEmpty) return;

    final slots = _slotsFor(streamCode);
    slots.clear();

    int dayIdx = 0;
    int slotInDay = 0;
    const maxPerDay = 3;
    const durationMin = 120;

    for (final s in subjs) {
      if (dayIdx >= days.length) break;
      final day = days[dayIdx];
      final startMin = 8 * 60 + slotInDay * durationMin;
      final endMin = startMin + durationMin;

      // Check if this teacher is busy in another stream at this time
      String? invigilatorId = s.subject.teacher;
      if (_isInvigilatorBusy(
        invigilatorId,
        day,
        startMin,
        endMin,
        streamCode,
      )) {
        invigilatorId = _findAvailableTeacher(
          day,
          startMin,
          endMin,
          streamCode,
        );
      }

      slots.add(
        _GradePaperSlot(
          id: _generateId(),
          date: day,
          startTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
          endTime: TimeOfDay(
            hour: (endMin ~/ 60).clamp(0, 23),
            minute: endMin % 60,
          ),
          subjectCode: s.subject.subject,
          invigilatorId: invigilatorId,
        ),
      );
      slotInDay++;
      if (slotInDay >= maxPerDay) {
        slotInDay = 0;
        dayIdx++;
      }
    }
    _recomputeConflicts();
    setState(() {});
  }

  void _autoFillAllStreams() {
    final grade = _currentGrade;
    if (grade == null) return;
    for (final streamCode in _currentMissingStreams) {
      _autoFillStream(grade, streamCode);
    }
  }

  // ── Stream overlay ────────────────────────────────────────────────────────

  void _closeStreamOverlay() {
    _streamOverlay?.remove();
    _streamOverlay = null;
  }

  void _toggleStreamOverlay(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    Color indigo,
    int grade,
    List<int?> streams,
  ) {
    if (_streamOverlay != null) {
      _closeStreamOverlay();
      return;
    }

    final renderBox =
        _streamTriggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _streamOverlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeStreamOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              width: size.width,
              child: _StreamDropdownOverlay(
                streams: streams,
                current: _activeStreamCode,
                grade: grade,
                config: widget.config,
                cs: cs,
                isDark: isDark,
                indigo: indigo,
                onSelected: (code) {
                  _closeStreamOverlay();
                  if (code == null) {
                    // "Auto-fill all streams" action
                    _autoFillAllStreams();
                  } else {
                    setState(() => _activeStreamCode = code);
                    _loadSubjectsForStream(grade, code);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_streamOverlay!);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final grade = _currentGrade;
    if (grade == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Validate invigilator conflicts
    _recomputeConflicts();
    if (_slotConflicts.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some papers have invigilator time conflicts. Please resolve the highlighted conflicts before saving.',
            ),
          ),
        );
        setState(() {});
      }
      return;
    }

    // Find the existing exam row for this grade (use first stream's exam as
    // the template for school/year/term/type/dates/teacher fields).
    final gradeEntry = widget.group.grades
        .where((g) => g.grade == grade)
        .firstOrNull;
    if (gradeEntry == null) return;
    final templateExam = gradeEntry.streams.first.exam;

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // Add papers to the EXISTING exam — no new exam rows needed.
      // The grade and stream are on the papers table.
      final existingExamId = templateExam.id;

      for (final streamCode in _currentMissingStreams) {
        for (final slot in _slotsFor(streamCode)) {
          if (slot.subjectCode == null) continue;
          final startDt = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.startTime.hour,
            slot.startTime.minute,
          );
          final endDt = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.endTime.hour,
            slot.endTime.minute,
          );
          await widget.dao.createPaper(
            paper: PapersCompanion(
              school: Value(widget.schoolId),
              exam: Value(existingExamId),
              subject: Value(slot.subjectCode!),
              paper: const Value(null),
              invigilator: Value(slot.invigilatorId ?? templateExam.teacher),
              start: Value(BigInt.from(startDt.millisecondsSinceEpoch ~/ 1000)),
              end: Value(BigInt.from(endDt.millisecondsSinceEpoch ~/ 1000)),
              grade: Value(grade),
              stream: Value(streamCode),
              status: const Value(PaperStatus.pending),
              created: Value(now),
              updated: Value(now),
            ),
            accountId: accountId,
          );
        }
      }
      if (mounted) widget.onClose();
    } catch (e, stack) {
      debugPrint('══════ ADD STREAM ERROR ══════');
      debugPrint('Type : ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack:\n$stack');
      debugPrint('══════════════════════════════');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB71C1C),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to add stream (${e.runtimeType}). Please try again.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indigo = const Color(0xFF5C6BC0);

    final grades = _gradesWithMissing;

    // Empty state — all streams already included across all participating grades
    if (grades.isEmpty) {
      return _buildAllStreamsIncluded(cs, isDark);
    }

    final gc = _currentGradeConfig!;
    final grade = gc.grade;
    final missing = _missingStreamsForGrade(grade);
    final activeCode = _activeStreamCode;
    final activeSubjects = activeCode != null
        ? (_subjects[activeCode] ?? [])
        : <({SubjectTeacher subject, UsersData teacher})>[];
    final isLoading =
        activeCode != null && _loadingSubjects[activeCode] == true;
    final activeSlots = activeCode != null
        ? _slotsFor(activeCode)
        : <_GradePaperSlot>[];

    // Set count badge: how many streams have ≥1 slot configured
    final setCount = missing
        .where((sc) => (_paperSlots[sc] ?? []).isNotEmpty)
        .length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildStreamHeader(cs, isDark, indigo, grade),
          // Grade selector (only when multiple grades have missing streams)
          if (grades.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _buildGradeSelector(grades, cs, isDark, indigo),
            ),
          // Stream dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _buildStreamDropdownTrigger(
              context,
              missing,
              grade,
              setCount,
              cs,
              isDark,
              indigo,
            ),
          ),
          // Paper slot list for active stream
          Flexible(
            child: activeCode == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Select a stream above to configure papers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : activeSubjects.isEmpty && activeSlots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No subjects assigned to this class yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    shrinkWrap: true,
                    children: [
                      ...activeSlots.asMap().entries.map(
                        (e) => _GradePaperSlotCard(
                          key: ValueKey(e.value.id),
                          slot: e.value,
                          subjects: activeSubjects,
                          teachers: _teachers,
                          teachersLoaded: _teachersLoaded,
                          config: widget.config,
                          subjectNames: widget.subjectNames,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          examDays: _examDays,
                          errorMessage: _slotConflicts[e.value.id],
                          onChanged: (_) {
                            _recomputeConflicts();
                            setState(() {});
                          },
                          onRemove: () {
                            setState(() {
                              activeSlots.remove(e.value);
                              _recomputeConflicts();
                            });
                          },
                        ),
                      ),
                      _GradeAddPaperButton(
                        cs: cs,
                        isDark: isDark,
                        indigo: indigo,
                        onTap: () {
                          final days = _examDays;
                          if (days.isEmpty) return;
                          final slots = _slotsFor(activeCode);
                          TimeOfDay startTime;
                          if (slots.isNotEmpty) {
                            startTime = slots.last.endTime;
                          } else {
                            startTime = const TimeOfDay(hour: 8, minute: 0);
                          }
                          final endMin =
                              startTime.hour * 60 + startTime.minute + 120;
                          final usedSubjects = slots
                              .map((s) => s.subjectCode)
                              .toSet();
                          int? autoSubject;
                          String? autoInvig;
                          for (final s in activeSubjects) {
                            if (!usedSubjects.contains(s.subject.subject)) {
                              autoSubject = s.subject.subject;
                              autoInvig = s.subject.teacher;
                              break;
                            }
                          }
                          setState(() {
                            slots.add(
                              _GradePaperSlot(
                                id: _generateId(),
                                date: days.first,
                                startTime: startTime,
                                endTime: TimeOfDay(
                                  hour: (endMin ~/ 60).clamp(0, 23),
                                  minute: endMin % 60,
                                ),
                                subjectCode: autoSubject,
                                invigilatorId: autoInvig,
                              ),
                            );
                          });
                        },
                      ),
                      if (activeSlots.isEmpty && activeSubjects.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: TextButton.icon(
                            onPressed: () => _autoFillStream(grade, activeCode),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                            ),
                            label: const Text('Auto-fill from subjects'),
                            style: TextButton.styleFrom(
                              splashFactory: NoSplash.splashFactory,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
          // Footer
          _buildStreamFooter(cs, isDark, indigo),
        ],
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _buildStreamHeader(
    ColorScheme cs,
    bool isDark,
    Color indigo,
    int grade,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
    child: Row(
      children: [
        Text(
          'Add Stream',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _gradeLabel(grade, widget.config),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
          onPressed: widget.onClose,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
        ),
      ],
    ),
  );

  Widget _buildAllStreamsIncluded(ColorScheme cs, bool isDark) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 32,
          color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 14),
        Text(
          'All streams included',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Every stream for all participating grades is already in this exam.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _buildGradeSelector(
    List<GradeConfig> grades,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    return Row(
      children: grades.asMap().entries.map((e) {
        final isSelected = _selectedGradeIndex == e.key;
        final label = _gradeLabel(e.value.grade, widget.config);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () {
              if (_selectedGradeIndex == e.key) return;
              setState(() {
                _selectedGradeIndex = e.key;
                _activeStreamCode = null;
              });
              final missing = _missingStreamsForGrade(e.value.grade);
              if (missing.isNotEmpty) {
                setState(() => _activeStreamCode = missing.first);
                _loadSubjectsForStream(e.value.grade, missing.first);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? indigo.withValues(alpha: isDark ? 0.18 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? indigo.withValues(alpha: 0.55)
                      : cs.outlineVariant.withValues(
                          alpha: isDark ? 0.25 : 0.35,
                        ),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? indigo : cs.onSurface,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStreamDropdownTrigger(
    BuildContext context,
    List<int?> streams,
    int grade,
    int setCount,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final activeCode = _activeStreamCode;
    final hasActive = activeCode != null;
    final label = hasActive ? _streamName(grade, activeCode) : 'Select stream…';

    return GestureDetector(
      key: _streamTriggerKey,
      onTap: () =>
          _toggleStreamOverlay(context, cs, isDark, indigo, grade, streams),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasActive
              ? indigo.withValues(alpha: isDark ? 0.12 : 0.07)
              : (isDark
                    ? const Color(0xFF1E2C3C)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasActive
                ? indigo.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasActive ? FontWeight.w500 : FontWeight.w400,
                color: hasActive ? indigo : cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (setCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$setCount set',
                  style: TextStyle(fontSize: 10.5, color: indigo),
                ),
              ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamFooter(ColorScheme cs, bool isDark, Color indigo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: widget.onClose,
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              _GradeConfirmButton(
                saving: _saving,
                indigo: indigo,
                onTap: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream dropdown overlay (macOS-style inline overlay)
// ─────────────────────────────────────────────────────────────────────────────

class _StreamDropdownOverlay extends StatefulWidget {
  const _StreamDropdownOverlay({
    required this.streams,
    required this.current,
    required this.grade,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
  });

  final List<int?> streams;
  final int? current;
  final int grade;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;

  /// Called with null for "auto-fill all streams", or a stream code to select.
  final ValueChanged<int?> onSelected;

  @override
  State<_StreamDropdownOverlay> createState() => _StreamDropdownOverlayState();
}

class _StreamDropdownOverlayState extends State<_StreamDropdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _streamName(int? code) {
    if (code == null) return 'All Streams';
    return _streamLabel(widget.grade, code, widget.config);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2A3A) : cs.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Regular stream items
                ...widget.streams.map((code) {
                  final isSelected = code == widget.current;
                  final label = _streamName(code);
                  return InkWell(
                    splashFactory: NoSplash.splashFactory,
                    onTap: () => widget.onSelected(code),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: isSelected ? indigo : cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 14, color: indigo),
                        ],
                      ),
                    ),
                  );
                }),
                // Divider before special action
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
                // Auto-fill all streams action
                InkWell(
                  splashFactory: NoSplash.splashFactory,
                  // Pass null to signal "auto-fill all"
                  onTap: () => widget.onSelected(null),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 15, color: indigo),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-fill all streams',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: indigo,
                          ),
                        ),
                      ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Grade to Exam — Form (two-step)
// ─────────────────────────────────────────────────────────────────────────────

/// A two-step form for adding a new grade (+ streams) to an existing exam group.
///
/// Step 1: Grade selection + stream toggle checkboxes.
/// Step 2: Per-stream paper timetable configuration.
class _AddGradeToExamForm extends StatefulWidget {
  const _AddGradeToExamForm({
    required this.group,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.subjectNames,
    required this.dao,
    required this.subjectsDao,
    required this.membersDao,
    required this.onClose,
  });

  final ExamGroup group;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;
  final MembersDao membersDao;
  final VoidCallback onClose;

  @override
  State<_AddGradeToExamForm> createState() => _AddGradeToExamFormState();
}

class _AddGradeToExamFormState extends State<_AddGradeToExamForm>
    with SingleTickerProviderStateMixin {
  // ── Step management ────────────────────────────────────────────────────────
  int _step = 0; // 0 = grade+stream, 1 = paper timetable

  // ── Step 1 state ──────────────────────────────────────────────────────────
  int? _selectedGrade;
  final Set<int?> _selectedStreams = {}; // null = no-stream grade

  // ── Step 2 state ──────────────────────────────────────────────────────────
  // Paper slots keyed by stream code (null for no-stream grades)
  final Map<int?, List<_GradePaperSlot>> _paperSlots = {};
  // Subjects loaded per stream
  final Map<int?, List<({SubjectTeacher subject, UsersData teacher})>>
  _subjects = {};
  final Map<int?, bool> _loadingSubjects = {};
  // Active stream being configured in step 2
  int _activeStreamTabIndex = 0;
  // Teachers for invigilator picker
  List<({TeachersData teacher, UsersData user})> _teachers = [];
  bool _teachersLoaded = false;
  bool _saving = false;

  // ── Invigilator conflict tracking ──────────────────────────────────────────
  Map<String, String> _slotConflicts = {};

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// All grades in the school config that are NOT already in the exam group.
  List<GradeConfig> get _availableGrades {
    final existing = widget.group.participatingGrades.toSet();
    final result = <GradeConfig>[];
    for (final curriculum in widget.config.curricula) {
      for (final gc in curriculum.grades) {
        if (!existing.contains(gc.grade)) result.add(gc);
      }
    }
    return result;
  }

  /// Stream codes for the selected grade, or [null] in a singleton list if
  /// the grade has no streams.
  List<int?> get _streamsForSelected {
    if (_selectedGrade == null) return [];
    for (final curriculum in widget.config.curricula) {
      final gc = curriculum.grades
          .where((g) => g.grade == _selectedGrade)
          .firstOrNull;
      if (gc != null) {
        if (gc.streams.isEmpty) return [null];
        return gc.streams.map((s) => s.code as int?).toList();
      }
    }
    return [];
  }

  String _streamName(int grade, int? streamCode) {
    if (streamCode == null) return 'All Streams';
    return _streamLabel(grade, streamCode, widget.config);
  }

  Future<void> _loadTeachers() async {
    try {
      final teachersList = await widget.membersDao
          .watchTeachers(widget.schoolId)
          .first;
      if (!mounted) return;
      final results = <({TeachersData teacher, UsersData user})>[];
      for (final t in teachersList) {
        final user = await widget.membersDao.findUserById(t.user);
        if (!mounted) return;
        if (user != null) results.add((teacher: t, user: user));
      }
      if (mounted) {
        setState(() {
          _teachers = results
            ..sort((a, b) => a.user.name.compareTo(b.user.name));
          _teachersLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teachersLoaded = true);
    }
  }

  Future<void> _loadSubjectsForStream(int grade, int? streamCode) async {
    if (_loadingSubjects[streamCode] == true ||
        _subjects.containsKey(streamCode)) {
      return;
    }
    setState(() => _loadingSubjects[streamCode] = true);
    try {
      final result = streamCode != null
          ? (await widget.subjectsDao.getSubjectsForClass(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: grade,
              stream: streamCode,
            )).map((s) => (subject: s.subject, teacher: s.teacher)).toList()
          : <({SubjectTeacher subject, UsersData teacher})>[];
      if (mounted) {
        setState(() {
          _subjects[streamCode] = result;
          _loadingSubjects[streamCode] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubjects[streamCode] = false);
    }
  }

  List<_GradePaperSlot> _slotsFor(int? streamCode) {
    return _paperSlots.putIfAbsent(streamCode, () => []);
  }

  List<DateTime> get _examDays {
    final start = DateTime.fromMillisecondsSinceEpoch(
      widget.group.start * 86400 * 1000,
      isUtc: true,
    );
    final end = DateTime.fromMillisecondsSinceEpoch(
      widget.group.end * 86400 * 1000,
      isUtc: true,
    );
    final days = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endLocal)) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  // ── Invigilator conflict helpers ──────────────────────────────────────────

  bool _isInvigilatorBusy(
    String teacherId,
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final entry in _paperSlots.entries) {
      if (entry.key == excludeStreamCode) continue;
      for (final slot in entry.value) {
        if (slot.invigilatorId != teacherId) continue;
        if (!(slot.date.year == day.year &&
            slot.date.month == day.month &&
            slot.date.day == day.day)) {
          continue;
        }
        final sStart = slot.startTime.hour * 60 + slot.startTime.minute;
        final sEnd = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin < sEnd && sStart < endMin) return true;
      }
    }
    return false;
  }

  String? _findAvailableTeacher(
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final t in _teachers) {
      if (!_isInvigilatorBusy(
        t.user.id,
        day,
        startMin,
        endMin,
        excludeStreamCode,
      )) {
        return t.user.id;
      }
    }
    return null;
  }

  Map<String, String> _findInvigilatorConflicts() {
    final conflicts = <String, String>{};
    final all = <({int? streamCode, _GradePaperSlot slot})>[];
    for (final entry in _paperSlots.entries) {
      for (final slot in entry.value) {
        if (slot.invigilatorId != null &&
            slot.invigilatorId!.isNotEmpty &&
            slot.subjectCode != null) {
          all.add((streamCode: entry.key, slot: slot));
        }
      }
    }
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.streamCode == b.streamCode) continue;
        if (a.slot.invigilatorId != b.slot.invigilatorId) continue;
        if (!(a.slot.date.year == b.slot.date.year &&
            a.slot.date.month == b.slot.date.month &&
            a.slot.date.day == b.slot.date.day)) {
          continue;
        }
        final aStart = a.slot.startTime.hour * 60 + a.slot.startTime.minute;
        final aEnd = a.slot.endTime.hour * 60 + a.slot.endTime.minute;
        final bStart = b.slot.startTime.hour * 60 + b.slot.startTime.minute;
        final bEnd = b.slot.endTime.hour * 60 + b.slot.endTime.minute;
        if (aStart < bEnd && bStart < aEnd) {
          final teacherName =
              _teachers
                  .where((t) => t.user.id == a.slot.invigilatorId)
                  .map((t) => t.user.name)
                  .firstOrNull ??
              'Teacher';
          final msg = '$teacherName is assigned to another paper at this time';
          conflicts[a.slot.id] = msg;
          conflicts[b.slot.id] = msg;
        }
      }
    }
    return conflicts;
  }

  void _recomputeConflicts() {
    _slotConflicts = _findInvigilatorConflicts();
  }

  void _autoFillStream(int? streamCode) {
    final grade = _selectedGrade;
    if (grade == null) return;
    final subjs = _subjects[streamCode] ?? [];
    if (subjs.isEmpty) return;
    final days = _examDays;
    if (days.isEmpty) return;

    final slots = _slotsFor(streamCode);
    slots.clear();

    int dayIdx = 0;
    int slotInDay = 0;
    const maxPerDay = 3;
    const durationMin = 120;

    for (final s in subjs) {
      if (dayIdx >= days.length) break;
      final day = days[dayIdx];
      final startMin = 8 * 60 + slotInDay * durationMin;
      final endMin = startMin + durationMin;

      // Check if this teacher is busy in another stream at this time
      String? invigilatorId = s.subject.teacher;
      if (_isInvigilatorBusy(
        invigilatorId,
        day,
        startMin,
        endMin,
        streamCode,
      )) {
        invigilatorId = _findAvailableTeacher(
          day,
          startMin,
          endMin,
          streamCode,
        );
      }

      slots.add(
        _GradePaperSlot(
          id: _generateId(),
          date: day,
          startTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
          endTime: TimeOfDay(
            hour: (endMin ~/ 60).clamp(0, 23),
            minute: endMin % 60,
          ),
          subjectCode: s.subject.subject,
          invigilatorId: invigilatorId,
        ),
      );
      slotInDay++;
      if (slotInDay >= maxPerDay) {
        slotInDay = 0;
        dayIdx++;
      }
    }
    _recomputeConflicts();
    setState(() {});
  }

  // ── Step transitions ───────────────────────────────────────────────────────

  void _goToStep2() {
    if (_selectedGrade == null || _selectedStreams.isEmpty) return;
    // Pre-load subjects for all selected streams
    for (final sc in _selectedStreams) {
      _loadSubjectsForStream(_selectedGrade!, sc);
    }
    setState(() {
      _step = 1;
      _activeStreamTabIndex = 0;
    });
  }

  void _goBackToStep1() {
    setState(() => _step = 0);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final grade = _selectedGrade;
    if (grade == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Validate invigilator conflicts
    _recomputeConflicts();
    if (_slotConflicts.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some papers have invigilator time conflicts. Please resolve the highlighted conflicts before saving.',
            ),
          ),
        );
        setState(() {});
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final teacherId = widget.group.teacher.id;

      // Add papers to the EXISTING exam — no new exam rows needed.
      // The grade and stream are on the papers table, not on exams.
      final existingExamId = widget.group.examIds.first;

      for (final streamCode in _selectedStreams) {
        for (final slot in _slotsFor(streamCode)) {
          if (slot.subjectCode == null) continue;
          final startDt = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.startTime.hour,
            slot.startTime.minute,
          );
          final endDt = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.endTime.hour,
            slot.endTime.minute,
          );
          await widget.dao.createPaper(
            paper: PapersCompanion(
              school: Value(widget.schoolId),
              exam: Value(existingExamId),
              subject: Value(slot.subjectCode!),
              paper: const Value(null),
              invigilator: Value(slot.invigilatorId ?? teacherId),
              start: Value(BigInt.from(startDt.millisecondsSinceEpoch ~/ 1000)),
              end: Value(BigInt.from(endDt.millisecondsSinceEpoch ~/ 1000)),
              grade: Value(grade),
              stream: Value(streamCode),
              status: const Value(PaperStatus.pending),
              created: Value(now),
              updated: Value(now),
            ),
            accountId: accountId,
          );
        }
      }
      if (mounted) widget.onClose();
    } catch (e, stack) {
      debugPrint('══════ ADD GRADE ERROR ══════');
      debugPrint('Type : ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack:\n$stack');
      debugPrint('═════════════════════════════');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB71C1C),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to add grade (${e.runtimeType}). Please try again.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indigo = const Color(0xFF5C6BC0);

    final available = _availableGrades;

    // Empty state — all grades already included
    if (available.isEmpty) {
      return _buildAllGradesIncluded(cs, isDark);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(cs, isDark, indigo),
          // Step indicator
          _GradeStepDots(step: _step, indigo: indigo, cs: cs),
          const SizedBox(height: 8),
          // Step content
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              child: _step == 0
                  ? _buildStep1(cs, isDark, indigo, available)
                  : _buildStep2(cs, isDark, indigo),
            ),
          ),
          // Footer
          _buildFooter(cs, isDark, indigo),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark, Color indigo) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
    child: Row(
      children: [
        Text(
          _step == 0 ? 'Add Grade' : 'Paper Timetable',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
          onPressed: widget.onClose,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
        ),
      ],
    ),
  );

  Widget _buildAllGradesIncluded(ColorScheme cs, bool isDark) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 32,
          color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 14),
        Text(
          'All grades included',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This exam already covers all configured grades.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  // ── Step 1 ────────────────────────────────────────────────────────────────

  Widget _buildStep1(
    ColorScheme cs,
    bool isDark,
    Color indigo,
    List<GradeConfig> available,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select grade',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          // Grade option rows
          ...available.map(
            (gc) => _buildGradeOptionRow(gc, cs, isDark, indigo),
          ),
          if (_selectedGrade != null && _streamsForSelected.length > 1) ...[
            const SizedBox(height: 14),
            Text(
              'Select streams',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            ..._streamsForSelected.map(
              (sc) => _buildStreamToggleRow(sc, cs, isDark, indigo),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGradeOptionRow(
    GradeConfig gc,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final isSelected = _selectedGrade == gc.grade;
    final streamCount = gc.streams.length;
    final label = _gradeLabel(gc.grade, widget.config);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGrade = gc.grade;
          _selectedStreams.clear();
          // Auto-select all streams (or null if no-stream grade)
          if (gc.streams.isEmpty) {
            _selectedStreams.add(null);
          } else {
            _selectedStreams.addAll(gc.streams.map((s) => s.code as int?));
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 5),
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? indigo.withValues(alpha: isDark ? 0.18 : 0.10)
              : (isDark
                    ? const Color(0xFF1A2536)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? indigo.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? indigo : cs.onSurface,
              ),
            ),
            const Spacer(),
            if (streamCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$streamCount ${streamCount == 1 ? "stream" : "streams"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamToggleRow(
    int? streamCode,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final grade = _selectedGrade!;
    final isChecked = _selectedStreams.contains(streamCode);
    final name = _streamName(grade, streamCode);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isChecked) {
            _selectedStreams.remove(streamCode);
          } else {
            _selectedStreams.add(streamCode);
          }
        });
      },
      child: Container(
        height: 32,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            // Custom 16×16 checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isChecked ? indigo : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isChecked
                      ? indigo
                      : cs.outlineVariant.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isChecked ? FontWeight.w500 : FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  Widget _buildStep2(ColorScheme cs, bool isDark, Color indigo) {
    final grade = _selectedGrade!;
    final streams = _selectedStreams.toList();
    final hasMultipleStreams = streams.length > 1;
    final currentStreamCode = streams.isNotEmpty
        ? streams[_activeStreamTabIndex.clamp(0, streams.length - 1)]
        : null;
    final currentSlots = _slotsFor(currentStreamCode);
    final currentSubjects = _subjects[currentStreamCode] ?? [];
    final isLoading = _loadingSubjects[currentStreamCode] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stream selector (when multiple streams)
        if (hasMultipleStreams)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _buildStreamDropdown(streams, grade, cs, isDark, indigo),
          ),
        // Slots list
        Flexible(
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : currentSubjects.isEmpty && currentSlots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No subjects assigned to this class yet.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  children: [
                    ...currentSlots.asMap().entries.map(
                      (e) => _GradePaperSlotCard(
                        key: ValueKey(e.value.id),
                        slot: e.value,
                        subjects: currentSubjects,
                        teachers: _teachers,
                        teachersLoaded: _teachersLoaded,
                        config: widget.config,
                        subjectNames: widget.subjectNames,
                        cs: cs,
                        isDark: isDark,
                        indigo: indigo,
                        examDays: _examDays,
                        errorMessage: _slotConflicts[e.value.id],
                        onChanged: (_) {
                          _recomputeConflicts();
                          setState(() {});
                        },
                        onRemove: () {
                          setState(() {
                            currentSlots.remove(e.value);
                            _recomputeConflicts();
                          });
                        },
                      ),
                    ),
                    // Add paper dashed button
                    _GradeAddPaperButton(
                      cs: cs,
                      isDark: isDark,
                      indigo: indigo,
                      onTap: () {
                        final days = _examDays;
                        if (days.isEmpty) return;
                        final slots = _slotsFor(currentStreamCode);
                        // Chain from last slot's end time
                        TimeOfDay startTime;
                        if (slots.isNotEmpty) {
                          startTime = slots.last.endTime;
                        } else {
                          startTime = const TimeOfDay(hour: 8, minute: 0);
                        }
                        final endMin =
                            startTime.hour * 60 + startTime.minute + 120;
                        // Auto-assign first unassigned subject
                        final usedSubjects = slots
                            .map((s) => s.subjectCode)
                            .toSet();
                        int? autoSubject;
                        String? autoInvig;
                        for (final s in currentSubjects) {
                          if (!usedSubjects.contains(s.subject.subject)) {
                            autoSubject = s.subject.subject;
                            autoInvig = s.subject.teacher;
                            break;
                          }
                        }
                        setState(() {
                          slots.add(
                            _GradePaperSlot(
                              id: _generateId(),
                              date: days.first,
                              startTime: startTime,
                              endTime: TimeOfDay(
                                hour: (endMin ~/ 60).clamp(0, 23),
                                minute: endMin % 60,
                              ),
                              subjectCode: autoSubject,
                              invigilatorId: autoInvig,
                            ),
                          );
                        });
                      },
                    ),
                    if (currentSlots.isEmpty && currentSubjects.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: TextButton.icon(
                          onPressed: () => _autoFillStream(currentStreamCode),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                          ),
                          label: const Text('Auto-fill from subjects'),
                          style: TextButton.styleFrom(
                            splashFactory: NoSplash.splashFactory,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStreamDropdown(
    List<int?> streams,
    int grade,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final currentIdx = _activeStreamTabIndex.clamp(0, streams.length - 1);
    final currentCode = streams[currentIdx];
    final label = _streamName(grade, currentCode);
    // Show set count badge
    final setCounts = streams
        .where((sc) => (_paperSlots[sc] ?? []).isNotEmpty)
        .length;

    return GestureDetector(
      onTap: () async {
        // Show a simple overlay-style picker
        final chosen = await showDialog<int?>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (_) => _GradeStreamPickerDialog(
            streams: streams,
            current: currentCode,
            grade: grade,
            config: widget.config,
            cs: cs,
            isDark: isDark,
          ),
        );
        if (chosen == null) return;
        final idx = streams.indexOf(chosen);
        if (idx >= 0) setState(() => _activeStreamTabIndex = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            if (setCounts > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$setCounts set',
                  style: TextStyle(fontSize: 10.5, color: indigo),
                ),
              ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, bool isDark, Color indigo) {
    final canGoNext = _selectedGrade != null && _selectedStreams.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(
            children: [
              if (_step == 1)
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: _goBackToStep1,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                  ),
                  tooltip: 'Back',
                ),
              const Spacer(),
              TextButton(
                onPressed: widget.onClose,
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              if (_step == 0)
                _GradeNextButton(
                  enabled: canGoNext,
                  indigo: indigo,
                  onTap: _goToStep2,
                )
              else
                _GradeConfirmButton(
                  saving: _saving,
                  indigo: indigo,
                  onTap: _save,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator dots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeStepDots extends StatelessWidget {
  const _GradeStepDots({
    required this.step,
    required this.indigo,
    required this.cs,
  });

  final int step;
  final Color indigo;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_dot(0), const SizedBox(width: 6), _dot(1)],
    );
  }

  Widget _dot(int index) {
    final isActive = index == step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? indigo : Colors.transparent,
        border: Border.all(
          color: isActive ? indigo : cs.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next button (step 1 → step 2)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeNextButton extends StatelessWidget {
  const _GradeNextButton({
    required this.enabled,
    required this.indigo,
    required this.onTap,
  });

  final bool enabled;
  final Color indigo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? indigo : indigo.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Next',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled ? Colors.white : Colors.white60,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: enabled ? Colors.white : Colors.white60,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm button (step 2 save)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeConfirmButton extends StatelessWidget {
  const _GradeConfirmButton({
    required this.saving,
    required this.indigo,
    required this.onTap,
  });

  final bool saving;
  final Color indigo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (saving || onTap == null) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (saving || onTap == null)
              ? AppTheme.brandGreen.withValues(alpha: 0.4)
              : AppTheme.brandGreen,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper slot data class (local to Add Grade / Add Stream modals)
// ─────────────────────────────────────────────────────────────────────────────

class _GradePaperSlot {
  String id;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  int? subjectCode;
  String? invigilatorId;

  _GradePaperSlot({
    required this.id,
    required this.date,
    this.startTime = const TimeOfDay(hour: 8, minute: 0),
    this.endTime = const TimeOfDay(hour: 10, minute: 0),
    this.subjectCode,
    this.invigilatorId,
  });

  Duration get duration {
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    return Duration(minutes: endMin - startMin);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper slot card for the Add Grade / Add Stream modals
// ─────────────────────────────────────────────────────────────────────────────

class _GradePaperSlotCard extends StatefulWidget {
  const _GradePaperSlotCard({
    super.key,
    required this.slot,
    required this.subjects,
    required this.teachers,
    required this.teachersLoaded,
    required this.config,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.examDays,
    required this.onChanged,
    required this.onRemove,
    this.errorMessage,
  });

  final _GradePaperSlot slot;
  final List<({SubjectTeacher subject, UsersData teacher})> subjects;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final List<DateTime> examDays;
  final ValueChanged<_GradePaperSlot> onChanged;
  final VoidCallback onRemove;
  final String? errorMessage;

  @override
  State<_GradePaperSlotCard> createState() => _GradePaperSlotCardState();
}

class _GradePaperSlotCardState extends State<_GradePaperSlotCard> {
  bool _timeOpen = false;
  late int _durationMinutes;
  late final FixedExtentScrollController _startHourCtrl;
  late final FixedExtentScrollController _startMinCtrl;
  late final FixedExtentScrollController _durHourCtrl;
  late final FixedExtentScrollController _durMinCtrl;

  static const _durMinValues = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    final slot = widget.slot;
    final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
    _durationMinutes = (endMin - startMin).clamp(0, 23 * 60 + 45);
    _startHourCtrl = FixedExtentScrollController(
      initialItem: slot.startTime.hour,
    );
    _startMinCtrl = FixedExtentScrollController(
      initialItem: slot.startTime.minute ~/ 5,
    );
    _durHourCtrl = FixedExtentScrollController(
      initialItem: _durationMinutes ~/ 60,
    );
    _durMinCtrl = FixedExtentScrollController(
      initialItem: _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _durHourCtrl.dispose();
    _durMinCtrl.dispose();
    super.dispose();
  }

  void _onStartChanged(TimeOfDay newStart) {
    final startMin = newStart.hour * 60 + newStart.minute;
    final endMin = startMin + _durationMinutes;
    widget.slot.startTime = newStart;
    widget.slot.endTime = TimeOfDay(
      hour: (endMin ~/ 60).clamp(0, 23),
      minute: endMin % 60,
    );
    widget.onChanged(widget.slot);
  }

  void _onDurationChanged(int durationMin) {
    _durationMinutes = durationMin;
    final startMin =
        widget.slot.startTime.hour * 60 + widget.slot.startTime.minute;
    final endMin = startMin + durationMin;
    widget.slot.endTime = TimeOfDay(
      hour: (endMin ~/ 60).clamp(0, 23),
      minute: endMin % 60,
    );
    widget.onChanged(widget.slot);
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;
    final slot = widget.slot;

    final timeSummary =
        '${_fmtTod(slot.startTime)} · ${_fmtDuration(_durationMinutes)}';
    final isInvalid = _durationMinutes <= 0;
    final hasError = widget.errorMessage != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2536)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError
              ? cs.error.withValues(alpha: 0.6)
              : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: time chip + remove button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                // Time trigger chip
                GestureDetector(
                  onTap: () => setState(() => _timeOpen = !_timeOpen),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2C3C)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _timeOpen
                            ? indigo.withValues(alpha: 0.6)
                            : cs.outlineVariant.withValues(
                                alpha: isDark ? 0.3 : 0.45,
                              ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeSummary,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: isInvalid ? cs.error : cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _timeOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 140),
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Date selector
                const SizedBox(width: 8),
                _GradeDateChip(
                  date: slot.date,
                  examDays: widget.examDays,
                  cs: cs,
                  isDark: isDark,
                  indigo: indigo,
                  onChanged: (d) {
                    widget.slot.date = d;
                    widget.onChanged(widget.slot);
                    setState(() {});
                  },
                ),
                const Spacer(),
                // Remove button
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: cs.error.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Inline time configurator (expandable)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _timeOpen
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _GradeInlineTimeConfigurator(
                startTime: slot.startTime,
                durationMinutes: _durationMinutes,
                startHourCtrl: _startHourCtrl,
                startMinCtrl: _startMinCtrl,
                durHourCtrl: _durHourCtrl,
                durMinCtrl: _durMinCtrl,
                isDark: isDark,
                cs: cs,
                indigo: indigo,
                onStartTimeChanged: _onStartChanged,
                onDurationChanged: _onDurationChanged,
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
          // Subject selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: _GradeSubjectSelector(
              value: slot.subjectCode,
              subjects: widget.subjects,
              subjectNames: widget.subjectNames,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onChanged: (code, teacherId) {
                widget.slot.subjectCode = code;
                widget.slot.invigilatorId = teacherId;
                widget.onChanged(widget.slot);
                setState(() {});
              },
            ),
          ),
          // Invigilator selector
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, hasError ? 4 : 10),
            child: _GradeInvigilatorSelector(
              value: slot.invigilatorId,
              teachers: widget.teachers,
              teachersLoaded: widget.teachersLoaded,
              cs: cs,
              isDark: isDark,
              onChanged: (id) {
                widget.slot.invigilatorId = id;
                widget.onChanged(widget.slot);
                setState(() {});
              },
            ),
          ),
          // Invigilator conflict error
          if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.error.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date chip — shows exam date, opens a simple picker overlay
// ─────────────────────────────────────────────────────────────────────────────

class _GradeDateChip extends StatelessWidget {
  const _GradeDateChip({
    required this.date,
    required this.examDays,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final DateTime date;
  final List<DateTime> examDays;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final label =
        '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]}';
    return GestureDetector(
      onTap: () async {
        final chosen = await showDialog<DateTime>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (_) => _GradeDatePickerDialog(
            selectedDate: date,
            examDays: examDays,
            cs: cs,
            isDark: isDark,
            indigo: indigo,
          ),
        );
        if (chosen != null) onChanged(chosen);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker dialog for the Add Grade modal
// ─────────────────────────────────────────────────────────────────────────────

class _GradeDatePickerDialog extends StatelessWidget {
  const _GradeDatePickerDialog({
    required this.selectedDate,
    required this.examDays,
    required this.cs,
    required this.isDark,
    required this.indigo,
  });

  final DateTime selectedDate;
  final List<DateTime> examDays;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18222E) : cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Select date',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: examDays.map((day) {
                  final isSelected = _sameDay(day, selectedDate);
                  final label =
                      '${day.day.toString().padLeft(2, '0')} ${_months[day.month - 1]}';
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo
                            : (isDark
                                  ? const Color(0xFF1A2536)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.5,
                                    )),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? indigo
                              : cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.25 : 0.4,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isSelected ? Colors.white : cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline time configurator for Add Grade modal slots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeInlineTimeConfigurator extends StatefulWidget {
  const _GradeInlineTimeConfigurator({
    required this.startTime,
    required this.durationMinutes,
    required this.startHourCtrl,
    required this.startMinCtrl,
    required this.durHourCtrl,
    required this.durMinCtrl,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.onStartTimeChanged,
    required this.onDurationChanged,
  });

  final TimeOfDay startTime;
  final int durationMinutes;
  final FixedExtentScrollController startHourCtrl;
  final FixedExtentScrollController startMinCtrl;
  final FixedExtentScrollController durHourCtrl;
  final FixedExtentScrollController durMinCtrl;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  State<_GradeInlineTimeConfigurator> createState() =>
      _GradeInlineTimeConfiguratorState();
}

class _GradeInlineTimeConfiguratorState
    extends State<_GradeInlineTimeConfigurator> {
  static const _durMinValues = [0, 15, 30, 45];

  int _startHour = 0;
  int _startMinIndex = 0; // index into 0..11 (0,5,10,...55)
  int _durHour = 0;
  int _durMinIndex = 0; // index into _durMinValues

  @override
  void initState() {
    super.initState();
    _startHour = widget.startTime.hour;
    _startMinIndex = (widget.startTime.minute ~/ 5).clamp(0, 11);
    _durHour = widget.durationMinutes ~/ 60;
    _durMinIndex = _durMinValues
        .indexOf(widget.durationMinutes % 60)
        .clamp(0, 3);
  }

  int get _currentDurationMinutes =>
      _durHour * 60 + _durMinValues[_durMinIndex];

  void _applyPreset(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final mIdx = _durMinValues.indexOf(m).clamp(0, 3);
    setState(() {
      _durHour = h;
      _durMinIndex = mIdx;
    });
    widget.durHourCtrl.jumpToItem(h);
    widget.durMinCtrl.jumpToItem(mIdx);
    widget.onDurationChanged(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2C3C)
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wheel row
          Row(
            children: [
              // Start time column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GradeWheelColumn(
                          controller: widget.startHourCtrl,
                          itemCount: 24,
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          selectedIndex: _startHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startHour = i;
                            widget.onStartTimeChanged(
                              TimeOfDay(
                                hour: _startHour,
                                minute: _startMinIndex * 5,
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        _GradeWheelColumn(
                          controller: widget.startMinCtrl,
                          itemCount: 12,
                          labelBuilder: (i) =>
                              (i * 5).toString().padLeft(2, '0'),
                          selectedIndex: _startMinIndex,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startMinIndex = i;
                            widget.onStartTimeChanged(
                              TimeOfDay(
                                hour: _startHour,
                                minute: _startMinIndex * 5,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 52,
                  child: VerticalDivider(
                    width: 1,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.2 : 0.35,
                    ),
                  ),
                ),
              ),
              // Duration column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GradeWheelColumn(
                          controller: widget.durHourCtrl,
                          itemCount: 12,
                          labelBuilder: (i) => '${i}h',
                          selectedIndex: _durHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _durHour = i;
                            widget.onDurationChanged(_currentDurationMinutes);
                          },
                        ),
                        const SizedBox(width: 4),
                        _GradeWheelColumn(
                          controller: widget.durMinCtrl,
                          itemCount: _durMinValues.length,
                          labelBuilder: (i) => '${_durMinValues[i]}m',
                          selectedIndex: _durMinIndex,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _durMinIndex = i;
                            widget.onDurationChanged(_currentDurationMinutes);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Preset chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children:
                const [
                  ('30m', 30),
                  ('1h', 60),
                  ('1h 30m', 90),
                  ('2h', 120),
                  ('2h 30m', 150),
                  ('3h', 180),
                ].map<Widget>((p) {
                  final isSelected = _currentDurationMinutes == p.$2;
                  return GestureDetector(
                    onTap: () => _applyPreset(p.$2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo.withValues(alpha: 0.18)
                            : (isDark
                                  ? const Color(0xFF18222E)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.4,
                                    )),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? indigo.withValues(alpha: 0.5)
                              : cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.2 : 0.35,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        p.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isSelected ? indigo : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wheel column widget (32px item extent)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeWheelColumn extends StatelessWidget {
  const _GradeWheelColumn({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.selectedIndex,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final int selectedIndex;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 96,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 32,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (_, i) {
            final isSelected = i == selectedIndex;
            return Center(
              child: Text(
                labelBuilder(i),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject selector for Add Grade modal slots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSubjectSelector extends StatelessWidget {
  const _GradeSubjectSelector({
    required this.value,
    required this.subjects,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final int? value;
  final List<({SubjectTeacher subject, UsersData teacher})> subjects;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final void Function(int? code, String? teacherId) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value != null
        ? (subjectNames[value!] ?? 'Subject $value')
        : 'Select subject';
    final hasValue = value != null;

    return GestureDetector(
      onTap: () async {
        if (subjects.isEmpty) return;
        await showEduSheet<void>(
          context: context,
          builder: (_) => _GradeSubjectPickerSheet(
            subjects: subjects,
            value: value,
            subjectNames: subjectNames,
            cs: cs,
            isDark: isDark,
            indigo: indigo,
            onSelected: (code, teacherId) {
              onChanged(code, teacherId);
              Navigator.of(context).pop();
            },
          ),
        );
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: hasValue
                ? indigo.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 14,
              color: hasValue
                  ? indigo
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                  color: hasValue
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSubjectPickerSheet extends StatelessWidget {
  const _GradeSubjectPickerSheet({
    required this.subjects,
    required this.value,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
  });

  final List<({SubjectTeacher subject, UsersData teacher})> subjects;
  final int? value;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final void Function(int code, String? teacherId) onSelected;

  @override
  Widget build(BuildContext context) {
    final sheetBg = isDark ? const Color(0xFF18222E) : cs.surface;
    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'Select subject',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: subjects.length,
            itemBuilder: (_, i) {
              final s = subjects[i];
              final label =
                  subjectNames[s.subject.subject] ??
                  'Subject ${s.subject.subject}';
              final isSelected = s.subject.subject == value;
              return InkWell(
                onTap: () => onSelected(s.subject.subject, s.subject.teacher),
                splashFactory: NoSplash.splashFactory,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected ? indigo : cs.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 16, color: indigo),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invigilator selector for Add Grade modal slots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeInvigilatorSelector extends StatelessWidget {
  const _GradeInvigilatorSelector({
    required this.value,
    required this.teachers,
    required this.teachersLoaded,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final String? value;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolved = value != null
        ? teachers.where((t) => t.user.id == value).firstOrNull
        : null;
    final label =
        resolved?.user.name ?? (teachersLoaded ? 'No invigilator' : 'Loading…');
    final hasValue = resolved != null;

    return GestureDetector(
      onTap: () async {
        if (!teachersLoaded || teachers.isEmpty) return;
        await showEduSheet<void>(
          context: context,
          builder: (_) => _GradeInvigilatorPickerSheet(
            teachers: teachers,
            value: value,
            cs: cs,
            isDark: isDark,
            sheetBg: isDark ? const Color(0xFF18222E) : cs.surface,
            onChanged: (id) {
              onChanged(id);
              Navigator.of(context).pop();
            },
          ),
        );
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invigilator picker sheet (reuses the same picker pattern from exam_creation)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeInvigilatorPickerSheet extends StatefulWidget {
  const _GradeInvigilatorPickerSheet({
    required this.teachers,
    required this.value,
    required this.cs,
    required this.isDark,
    required this.sheetBg,
    required this.onChanged,
  });

  final List<({TeachersData teacher, UsersData user})> teachers;
  final String? value;
  final ColorScheme cs;
  final bool isDark;
  final Color sheetBg;
  final ValueChanged<String?> onChanged;

  @override
  State<_GradeInvigilatorPickerSheet> createState() =>
      _GradeInvigilatorPickerSheetState();
}

class _GradeInvigilatorPickerSheetState
    extends State<_GradeInvigilatorPickerSheet> {
  late final TextEditingController _searchCtrl;
  late List<({TeachersData teacher, UsersData user})> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered = List.of(widget.teachers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.of(widget.teachers)
          : widget.teachers
                .where(
                  (t) =>
                      t.user.name.toLowerCase().contains(lower) ||
                      t.user.phone.toLowerCase().contains(lower),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    return Container(
      decoration: BoxDecoration(
        color: widget.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'Select invigilator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filter,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1A2536)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final t = _filtered[i];
                final isSelected = t.user.id == widget.value;
                return InkWell(
                  onTap: () => widget.onChanged(t.user.id),
                  splashFactory: NoSplash.splashFactory,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.user.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF5C6BC0)
                                      : cs.onSurface,
                                ),
                              ),
                              Text(
                                t.user.phone,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Color(0xFF5C6BC0),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed "Add Paper" button for the modal
// ─────────────────────────────────────────────────────────────────────────────

class _GradeAddPaperButton extends StatelessWidget {
  const _GradeAddPaperButton({
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onTap,
  });

  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
          radius: 4,
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                'Add Paper',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 4.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream picker dialog (used by the stream dropdown in step 2)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeStreamPickerDialog extends StatelessWidget {
  const _GradeStreamPickerDialog({
    required this.streams,
    required this.current,
    required this.grade,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final List<int?> streams;
  final int? current;
  final int grade;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final indigo = const Color(0xFF5C6BC0);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2A3A) : cs.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: streams.map((sc) {
              final isSelected = sc == current;
              final label = sc == null
                  ? 'All Streams'
                  : _streamLabel(grade, sc, config);
              return InkWell(
                onTap: () => Navigator.of(context).pop(sc),
                splashFactory: NoSplash.splashFactory,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected ? indigo : cs.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 14, color: indigo),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable FAB — Add Paper / Add Grade / Add Stream
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
// Paper timetable helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<DateTime, List<Paper>> _groupPapersByDate(List<Paper> papers) {
  final map = <DateTime, List<Paper>>{};
  for (final p in papers) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    final day = DateTime(dt.year, dt.month, dt.day);
    map.putIfAbsent(day, () => []).add(p);
  }
  // Sort papers within each day by start time
  for (final list in map.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return map;
}

List<DateTime> _sortedPaperDates(Map<DateTime, List<Paper>> grouped) {
  final dates = grouped.keys.toList()..sort();
  return dates;
}

List<({String start, String end})> _uniquePaperStartTimes(List<Paper> papers) {
  final seen = <String>{};
  final result = <({String start, String end})>[];
  final sorted = List<Paper>.from(papers)
    ..sort((a, b) => a.start.compareTo(b.start));
  for (final p in sorted) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    final endDt = DateTime.fromMillisecondsSinceEpoch(p.end.toInt() * 1000);
    final startStr = _fmtTime(startDt);
    if (!seen.contains(startStr)) {
      seen.add(startStr);
      result.add((start: startStr, end: _fmtTime(endDt)));
    }
  }
  return result;
}

Paper? _paperAt(
  Map<DateTime, List<Paper>> grouped,
  DateTime date,
  String startTime,
) {
  final day = DateTime(date.year, date.month, date.day);
  final papers = grouped[day] ?? [];
  for (final p in papers) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    if (_fmtTime(dt) == startTime) return p;
  }
  return null;
}

String _fmtDayHeader(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[d.weekday - 1];
  return '$wd, ${d.day} ${_months[d.month - 1]}';
}

String _fmtDayColumn(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[d.weekday - 1];
  return '$wd ${d.day}';
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
      final gradeLabel = _gradeLabel(gradeEntry.grade, config);
      for (final streamEntry in gradeEntry.streams) {
        final streamName = streamEntry.streamCode != null
            ? _streamLabel(gradeEntry.grade, streamEntry.streamCode!, config)
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
    final rows = _buildRows();
    final allPapers = rows.expand((r) => r.papers).toList();

    if (rows.isEmpty || allPapers.isEmpty) {
      return _EmptyPapersTimetableState(cs: cs);
    }

    final grouped = _groupPapersByDate(allPapers);
    final dates = _sortedPaperDates(grouped);

    const double rowLabelWidth = 128;
    const double colWidth = 140;
    final totalWidth = rowLabelWidth + dates.length * colWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status legend
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _PaperStatusLegend(),
        ),
        // Scrollable matrix
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header row (date labels) ──────────────────────────
                    _CrossTableHeaderRow(
                      dates: dates,
                      rowLabelWidth: rowLabelWidth,
                      colWidth: colWidth,
                      cs: cs,
                    ),
                    const SizedBox(height: 6),
                    // ── Data rows (one per grade+stream) ─────────────────
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Row label
                              SizedBox(
                                width: rowLabelWidth,
                                child: _CrossTableRowLabel(
                                  label: row.label,
                                  cs: cs,
                                ),
                              ),
                              // Date cells
                              ...dates.map((date) {
                                final cellPapers = _papersOnDate(
                                  row.papers,
                                  date,
                                );
                                if (cellPapers.isEmpty) {
                                  return SizedBox(
                                    width: colWidth,
                                    child: _PaperEmptyCell(cs: cs),
                                  );
                                }
                                return SizedBox(
                                  width: colWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < cellPapers.length;
                                          i++
                                        ) ...[
                                          _PaperSlotBox(
                                            paper: cellPapers[i],
                                            exam: row.exam,
                                            subjectNames: subjectNames,
                                            statusColor: _paperStatusColor(
                                              cellPapers[i].status,
                                              cs,
                                            ),
                                            invigilatorName:
                                                teacherNames[cellPapers[i]
                                                    .invigilator] ??
                                                '',
                                            cs: cs,
                                            onTap: () => onPaperTap(
                                              cellPapers[i],
                                              row.exam,
                                              row.grade,
                                            ),
                                          ),
                                          if (i < cellPapers.length - 1)
                                            const SizedBox(height: 3),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Header row for [_ExamGroupCrossTable]: empty corner cell + date labels.
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
                _fmtDayHeader(d),
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
    final grouped = _groupPapersByDate(papers);
    final dates = _sortedPaperDates(grouped);
    final timeslots = _uniquePaperStartTimes(papers);

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
        _fmtDayColumn(date),
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
              final paper = _paperAt(grouped, d, startTime);
              if (paper == null) {
                return Expanded(child: _PaperEmptyCell(cs: cs));
              }
              final statusColor = _paperStatusColor(paper.status, cs);
              final invName = teacherNames[paper.invigilator] ?? '';
              return Expanded(
                child: _PaperSlotBox(
                  paper: paper,
                  exam: exam,
                  subjectNames: subjectNames,
                  statusColor: statusColor,
                  invigilatorName: invName,
                  cs: cs,
                  onTap: () => onPaperTap(paper, exam, grade),
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
    final startMs = paper.start.toInt();
    final endMs = paper.end.toInt();
    final timeUnset = startMs == 0;
    final timeRange = timeUnset
        ? null
        : '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(startMs * 1000))}'
              ' – '
              '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(endMs * 1000))}';
    final invDisplay = invigilatorName.isNotEmpty ? invigilatorName : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            border: Border(
              left: BorderSide(
                color: statusColor.withValues(alpha: 0.65),
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$subjectName$paperLabel',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (timeRange != null) ...[
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    height: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(height: 1),
              Text(
                invDisplay,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
            width: 1,
          ),
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
    _grouped = _groupPapersByDate(widget.papers);
    _dates = _sortedPaperDates(_grouped);
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
            _fmtDayHeader(selectedDate),
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
                    final statusColor = _paperStatusColor(p.status, cs);
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
        final color = _paperStatusColor(s, cs);
        final label = _paperStatusLabel(s);
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
    final timeRange = '${_fmtTime(startDt)} – ${_fmtTime(endDt)}';
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

class _PaperDetailView extends StatelessWidget {
  const _PaperDetailView({
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
// ─────────────────────────────────────────────────────────────────────────────
// Create paper sheet
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _CreatePaperSheet — adaptive dialog (desktop) / bottom sheet (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePaperSheet extends StatefulWidget {
  const _CreatePaperSheet({
    required this.examGroup,
    required this.schoolId,
    required this.examId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.config,
    required this.subjectNames,
    required this.dao,
    required this.subjectsDao,
  });

  final ExamGroup examGroup;
  final String schoolId;
  final String examId;
  final int year;
  final int term;
  final int grade;
  final int? stream;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;

  @override
  State<_CreatePaperSheet> createState() => _CreatePaperSheetState();
}

class _CreatePaperSheetState extends State<_CreatePaperSheet> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<SubjectTeacher> _subjects = [];
  bool _loadingSubjects = true;

  // ── Form state ────────────────────────────────────────────────────────────
  int? _selectedSubject;
  bool _multiPaper = false;
  int _paperNumber = 1; // 1–3 wheel
  bool _calendarOpen = false;
  bool _timeOpen = false;
  DateTime _selectedDate = DateTime.now();
  int _startHour = 8;
  int _startMinIndex = 0; // index into 0..11 (0,5,10,...55)
  int _durationMinutes = 120; // default 2 h
  bool _saving = false;

  // ── Wheel controllers ─────────────────────────────────────────────────────
  late final FixedExtentScrollController _paperNumCtrl;
  late final FixedExtentScrollController _startHourCtrl;
  late final FixedExtentScrollController _startMinCtrl;
  late final FixedExtentScrollController _durHourCtrl;
  late final FixedExtentScrollController _durMinCtrl;

  static const _durMinValues = [0, 15, 30, 45];

  // ── Teacher names (userId → display name) for subject overlay subtitles ──
  Map<String, String> _teacherNames = {};

  // ── Subject overlay ───────────────────────────────────────────────────────
  OverlayEntry? _subjectOverlay;
  final _subjectTriggerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Initialise with exam group's first day as default date.
    final groupStartEpochDays = widget.examGroup.start;
    _selectedDate = DateTime.fromMillisecondsSinceEpoch(
      groupStartEpochDays * 86400 * 1000,
    );
    _paperNumCtrl = FixedExtentScrollController(initialItem: 0);
    _startHourCtrl = FixedExtentScrollController(initialItem: _startHour);
    _startMinCtrl = FixedExtentScrollController(initialItem: _startMinIndex);
    final durH = _durationMinutes ~/ 60;
    final durMIdx = _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3);
    _durHourCtrl = FixedExtentScrollController(initialItem: durH);
    _durMinCtrl = FixedExtentScrollController(initialItem: durMIdx);
    _loadSubjects(); // also triggers _loadTeacherNamesForSubjects when done
  }

  @override
  void dispose() {
    _closeSubjectOverlay();
    _paperNumCtrl.dispose();
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _durHourCtrl.dispose();
    _durMinCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _loadTeacherNamesForSubjects() async {
    // Wait until subjects are loaded, then resolve each teacher's display name.
    // We collect unique teacher IDs from the subject_teachers rows and look
    // up each via MembersDao.findUserById.
    final membersDao = MembersDao(db);
    // _subjects may still be loading; call after _loadSubjects populates it.
    // We resolve what we have at call time; a second call is made after
    // _loadSubjects finishes if subjects were empty at that point.
    final ids = _subjects.map((s) => s.teacher).toSet();
    if (ids.isEmpty) return;
    final names = <String, String>{};
    for (final id in ids) {
      final user = await membersDao.findUserById(id);
      if (user != null) names[id] = user.name;
    }
    if (mounted) setState(() => _teacherNames = names);
  }

  Future<void> _loadSubjects() async {
    final allSubs = await widget.subjectsDao.getSubjectsForTerm(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
    final filtered = allSubs
        .where(
          (s) =>
              s.grade == widget.grade &&
              (widget.stream == null || s.stream == widget.stream),
        )
        .toList();
    if (mounted) {
      setState(() {
        _subjects = filtered;
        _loadingSubjects = false;
      });
      // Now that subjects are available, resolve teacher display names.
      _loadTeacherNamesForSubjects();
    }
  }

  int get _durHourValue => _durationMinutes ~/ 60;
  int get _durMinIndex =>
      _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3);

  DateTime get _startDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _startHour,
    _startMinIndex * 5,
  );

  DateTime get _endDateTime =>
      _startDateTime.add(Duration(minutes: _durationMinutes));

  String _fmtTimeTrigger() {
    final sh = _startHour.toString().padLeft(2, '0');
    final sm = (_startMinIndex * 5).toString().padLeft(2, '0');
    final eh = _endDateTime.hour.toString().padLeft(2, '0');
    final em = _endDateTime.minute.toString().padLeft(2, '0');
    final dh = _durHourValue;
    final dm = _durMinValues[_durMinIndex];
    final durLabel = dm == 0 ? '${dh}h' : '${dh}h ${dm}m';
    return '$sh:$sm – $eh:$em · $durLabel';
  }

  bool get _isOutOfRange {
    final groupStart = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.start * 86400 * 1000,
    );
    final groupEnd = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.end * 86400 * 1000,
    );
    final d = _selectedDate;
    final dayOnly = DateTime(d.year, d.month, d.day);
    final rangeStart = DateTime(
      groupStart.year,
      groupStart.month,
      groupStart.day,
    );
    final rangeEnd = DateTime(groupEnd.year, groupEnd.month, groupEnd.day);
    return dayOnly.isBefore(rangeStart) || dayOnly.isAfter(rangeEnd);
  }

  void _applyDurationPreset(int minutes) {
    setState(() => _durationMinutes = minutes);
    _durHourCtrl.jumpToItem(minutes ~/ 60);
    _durMinCtrl.jumpToItem(_durMinValues.indexOf(minutes % 60).clamp(0, 3));
  }

  // ── Subject overlay ───────────────────────────────────────────────────────

  void _closeSubjectOverlay() {
    _subjectOverlay?.remove();
    _subjectOverlay = null;
  }

  void _toggleSubjectOverlay(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    if (_subjectOverlay != null) {
      _closeSubjectOverlay();
      return;
    }

    final renderBox =
        _subjectTriggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Decide whether to open above or below.
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - (offset.dy + size.height);
    final openAbove = spaceBelow < 200;

    _subjectOverlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeSubjectOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: openAbove ? null : offset.dy + size.height + 4,
              bottom: openAbove ? screenHeight - offset.dy + 4 : null,
              width: size.width,
              child: _SubjectMenuOverlay(
                subjects: _subjects,
                selected: _selectedSubject,
                subjectNames: widget.subjectNames,
                cs: cs,
                isDark: isDark,
                indigo: indigo,
                teacherNames: _teacherNames,
                onSelected: (code) {
                  _closeSubjectOverlay();
                  setState(() => _selectedSubject = code);
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_subjectOverlay!);
  }

  // ── Out-of-range extension ────────────────────────────────────────────────

  Future<void> _extendExamRange(BuildContext context) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    final group = widget.examGroup;

    final groupStartDt = DateTime.fromMillisecondsSinceEpoch(
      group.start * 86400 * 1000,
    );
    final groupEndDt = DateTime.fromMillisecondsSinceEpoch(
      group.end * 86400 * 1000,
    );
    final d = _selectedDate;
    final selDay = DateTime(d.year, d.month, d.day);
    final gsDay = DateTime(
      groupStartDt.year,
      groupStartDt.month,
      groupStartDt.day,
    );
    final geDays = DateTime(groupEndDt.year, groupEndDt.month, groupEndDt.day);

    final newStart = selDay.isBefore(gsDay) ? selDay : gsDay;
    final newEnd = selDay.isAfter(geDays) ? selDay : geDays;

    // Convert back to days-since-epoch
    final newStartDays = newStart.millisecondsSinceEpoch ~/ (86400 * 1000);
    final newEndDays = newEnd.millisecondsSinceEpoch ~/ (86400 * 1000);

    try {
      await widget.dao.updateExamGroupDateRange(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        type: group.type,
        oldStart: group.start,
        oldEnd: group.end,
        newStart: newStartDays,
        newEnd: newEndDays,
        accountId: accountId,
      );
    } catch (_) {
      // Silently ignore — the date is still usable.
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selectedSubject == null) return;
    if (_durationMinutes <= 0) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final subjectRow = _subjects
        .where((s) => s.subject == _selectedSubject)
        .firstOrNull;
    final invigilatorId = subjectRow?.teacher ?? accountId;

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.createPaper(
        paper: PapersCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.examId),
          subject: Value(_selectedSubject!),
          paper: Value(_multiPaper ? _paperNumber : null),
          invigilator: Value(invigilatorId),
          start: Value(
            BigInt.from(_startDateTime.millisecondsSinceEpoch ~/ 1000),
          ),
          end: Value(BigInt.from(_endDateTime.millisecondsSinceEpoch ~/ 1000)),
          grade: Value(widget.grade),
          stream: Value(widget.stream),
          status: const Value(PaperStatus.pending),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  // Wrapping (Dialog on desktop / bottom sheet on mobile) is handled by
  // showEduSheet — this widget only returns the form content.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indigo = const Color(0xFF5C7CFA);

    final gradeLabel = _gradeLabel(widget.grade, widget.config);
    final streamLabel = widget.stream != null
        ? _streamLabel(widget.grade, widget.stream!, widget.config)
        : null;
    final subtitle = streamLabel != null
        ? '$gradeLabel · $streamLabel'
        : gradeLabel;

    final sheetBg = isDark ? const Color(0xFF18222E) : cs.surface;

    // isSheet: false — the drag handle is provided by EduSheet / showEduSheet,
    // so we don't render a duplicate one inside the content.
    return _buildContent(
      context,
      cs: cs,
      isDark: isDark,
      indigo: indigo,
      subtitle: subtitle,
      sheetBg: sheetBg,
      isSheet: false,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
    required String subtitle,
    required Color sheetBg,
    required bool isSheet,
  }) {
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.25 : 0.4,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSheet)
                Center(
                  child: Container(
                    width: 32,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.4 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Paper',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    style: IconButton.styleFrom(
                      splashFactory: NoSplash.splashFactory,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Divider(height: 1, thickness: 1, color: borderColor),
        // ── Body ────────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subject selector
                _buildSubjectRow(
                  context,
                  cs: cs,
                  isDark: isDark,
                  indigo: indigo,
                ),
                const SizedBox(height: 14),
                // Multi-paper + paper number wheel
                _buildPaperNumberRow(cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 14),
                // Date picker
                _buildDateRow(context, cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 14),
                // Out-of-range warning
                if (_isOutOfRange)
                  _buildOutOfRangeWarning(
                    context,
                    cs: cs,
                    isDark: isDark,
                    indigo: indigo,
                  ),
                if (_isOutOfRange) const SizedBox(height: 14),
                // Time picker
                _buildTimeRow(cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // ── Footer ──────────────────────────────────────────────────────────
        Divider(height: 1, thickness: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              _GradeConfirmButton(
                saving: _saving,
                indigo: indigo,
                onTap: (_selectedSubject == null || _saving) ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Subject row ───────────────────────────────────────────────────────────

  Widget _buildSubjectRow(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    final hasSubject = _selectedSubject != null;
    final label = hasSubject
        ? (widget.subjectNames[_selectedSubject!] ??
              'Subject $_selectedSubject')
        : (_loadingSubjects ? 'Loading…' : 'Select subject…');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Subject',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _subjectTriggerKey,
          onTap: (_loadingSubjects || _subjects.isEmpty)
              ? null
              : () => _toggleSubjectOverlay(context, cs, isDark, indigo),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: hasSubject
                  ? indigo.withValues(alpha: isDark ? 0.12 : 0.07)
                  : (isDark
                        ? const Color(0xFF1E2C3C)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasSubject
                    ? indigo.withValues(alpha: 0.55)
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 16,
                  color: hasSubject
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasSubject
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: hasSubject ? indigo : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (!_loadingSubjects && _subjects.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No subjects assigned to this class yet.',
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
      ],
    );
  }

  // ── Paper number row ──────────────────────────────────────────────────────

  Widget _buildPaperNumberRow({
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2C3C)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _multiPaper,
              onChanged: (v) {
                setState(() {
                  _multiPaper = v ?? false;
                  if (!_multiPaper) _paperNumber = 1;
                });
              },
              visualDensity: VisualDensity.compact,
              activeColor: indigo,
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.6),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Multiple papers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          // Paper number buttons (only when _multiPaper)
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _multiPaper
                ? _PaperNumberWheel(
                    controller: _paperNumCtrl,
                    selected: _paperNumber,
                    cs: cs,
                    isDark: isDark,
                    indigo: indigo,
                    onChanged: (n) => setState(() => _paperNumber = n),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Date row ──────────────────────────────────────────────────────────────

  Widget _buildDateRow(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    final groupStart = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.start * 86400 * 1000,
    );
    final groupEnd = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.end * 86400 * 1000,
    );

    final d = _selectedDate;
    final dateLabel =
        '${_kDayNamesShort[d.weekday % 7]}, ${d.day} ${_kMonthsShort[d.month - 1]} ${d.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trigger
        GestureDetector(
          onTap: () => setState(() => _calendarOpen = !_calendarOpen),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _calendarOpen
                  ? indigo.withValues(alpha: isDark ? 0.14 : 0.08)
                  : (isDark
                        ? const Color(0xFF1E2C3C)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _calendarOpen
                    ? indigo.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                width: 1,
              ),
              boxShadow: _calendarOpen
                  ? [
                      BoxShadow(
                        color: indigo.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: _calendarOpen
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _calendarOpen ? indigo : cs.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _calendarOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _calendarOpen
                        ? indigo
                        : cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Inline calendar
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _calendarOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _PaperSingleCalendar(
              selected: _selectedDate,
              groupStart: groupStart,
              groupEnd: groupEnd,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onSelected: (d) {
                setState(() {
                  _selectedDate = d;
                  _calendarOpen = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Out-of-range warning ──────────────────────────────────────────────────

  Widget _buildOutOfRangeWarning(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    const amber = Color(0xFFFFA726);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: amber.withValues(alpha: isDark ? 0.35 : 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: amber.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Date is outside the exam period.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? amber.withValues(alpha: 0.8)
                    : const Color(0xFFB35A00),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _extendExamRange(context),
            child: Text(
              'Extend Period',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Time row ──────────────────────────────────────────────────────────────

  Widget _buildTimeRow({
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    final timeLabel = _fmtTimeTrigger();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trigger chip
        GestureDetector(
          onTap: () => setState(() => _timeOpen = !_timeOpen),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _timeOpen
                  ? indigo.withValues(alpha: isDark ? 0.14 : 0.08)
                  : (isDark
                        ? const Color(0xFF1E2C3C)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _timeOpen
                    ? indigo.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                width: 1,
              ),
              boxShadow: _timeOpen
                  ? [
                      BoxShadow(
                        color: indigo.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: _timeOpen
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _timeOpen ? indigo : cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _timeOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _timeOpen
                        ? indigo
                        : cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Inline time configurator
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _timeOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _InlineTimeConfigurator(
              startHour: _startHour,
              startMinIndex: _startMinIndex,
              durationMinutes: _durationMinutes,
              startHourCtrl: _startHourCtrl,
              startMinCtrl: _startMinCtrl,
              durHourCtrl: _durHourCtrl,
              durMinCtrl: _durMinCtrl,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onStartChanged: (h, mIdx) {
                setState(() {
                  _startHour = h;
                  _startMinIndex = mIdx;
                });
              },
              onDurationChanged: (minutes) {
                setState(() => _durationMinutes = minutes);
              },
              onPreset: _applyDurationPreset,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubjectMenuOverlay — macOS-style inline overlay for subject selection
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectMenuOverlay extends StatefulWidget {
  const _SubjectMenuOverlay({
    required this.subjects,
    required this.selected,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
    this.teacherNames = const {},
  });

  final List<SubjectTeacher> subjects;
  final int? selected;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onSelected;

  /// Optional map of userId → display name for showing teacher names in items.
  final Map<String, String> teacherNames;

  @override
  State<_SubjectMenuOverlay> createState() => _SubjectMenuOverlayState();
}

class _SubjectMenuOverlayState extends State<_SubjectMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2A3A) : cs.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.subjects.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final isSelected = s.subject == widget.selected;
                final isLast = idx == widget.subjects.length - 1;
                final label =
                    widget.subjectNames[s.subject] ?? 'Subject ${s.subject}';
                final teacherDisplay = widget.teacherNames[s.teacher] ?? '';
                final hasTeacher = teacherDisplay.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: InkWell(
                    splashFactory: NoSplash.splashFactory,
                    borderRadius: BorderRadius.circular(4),
                    hoverColor: cs.primary.withValues(alpha: 0.06),
                    onTap: () => widget.onSelected(s.subject),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: isLast
                          ? null
                          : BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: isDark ? 0.15 : 0.25,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 14,
                            color: isSelected
                                ? indigo
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: isSelected ? indigo : cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (hasTeacher)
                                  Text(
                                    teacherDisplay, // non-empty guaranteed by hasTeacher guard
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 14, color: indigo),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PaperNumberWheel — compact 1/2/3 wheel for paper number selection
// ─────────────────────────────────────────────────────────────────────────────

class _PaperNumberWheel extends StatelessWidget {
  const _PaperNumberWheel({
    required this.controller,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  // controller kept for API compatibility but no longer used by ListWheelScrollView
  final FixedExtentScrollController controller;
  final int selected;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [1, 2, 3].map((n) {
        final isSelected = n == selected;
        return GestureDetector(
          onTap: () => onChanged(n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? null
                  : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : cs.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PaperSingleCalendar — inline single-date calendar
// ─────────────────────────────────────────────────────────────────────────────

class _PaperSingleCalendar extends StatefulWidget {
  const _PaperSingleCalendar({
    required this.selected,
    required this.groupStart,
    required this.groupEnd,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
  });

  final DateTime selected;
  final DateTime groupStart;
  final DateTime groupEnd;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_PaperSingleCalendar> createState() => _PaperSingleCalendarState();
}

class _PaperSingleCalendarState extends State<_PaperSingleCalendar> {
  late DateTime _month; // first day of visible month

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.selected.year, widget.selected.month);
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inExamRange(DateTime d) {
    final gs = DateTime(
      widget.groupStart.year,
      widget.groupStart.month,
      widget.groupStart.day,
    );
    final ge = DateTime(
      widget.groupEnd.year,
      widget.groupEnd.month,
      widget.groupEnd.day,
    );
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(gs) && !day.isAfter(ge);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    final firstWeekday = _month.weekday % 7; // 0=Sun
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2536)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: _prevMonth,
                style: IconButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: cs.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  '${_kFullMonthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: _nextMonth,
                style: IconButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Weekday headers
          Row(
            children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          // Day grid
          for (int r = 0; r < rows; r++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = r * 7 + col;
                final dayNum = cellIndex - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 32));
                }
                final day = DateTime(_month.year, _month.month, dayNum);
                final isSelected = _sameDay(day, widget.selected);
                final inRange = _inExamRange(day);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onSelected(day),
                    child: Container(
                      height: 32,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo
                            : (inRange
                                  ? indigo.withValues(
                                      alpha: isDark ? 0.14 : 0.08,
                                    )
                                  : Colors.transparent),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : (inRange
                                      ? indigo
                                      : cs.onSurface.withValues(alpha: 0.85)),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InlineTimeConfigurator — two-column wheel time picker with presets
// ─────────────────────────────────────────────────────────────────────────────

class _InlineTimeConfigurator extends StatefulWidget {
  const _InlineTimeConfigurator({
    required this.startHour,
    required this.startMinIndex,
    required this.durationMinutes,
    required this.startHourCtrl,
    required this.startMinCtrl,
    required this.durHourCtrl,
    required this.durMinCtrl,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onStartChanged,
    required this.onDurationChanged,
    required this.onPreset,
  });

  final int startHour;
  final int startMinIndex;
  final int durationMinutes;
  final FixedExtentScrollController startHourCtrl;
  final FixedExtentScrollController startMinCtrl;
  final FixedExtentScrollController durHourCtrl;
  final FixedExtentScrollController durMinCtrl;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final void Function(int hour, int minIndex) onStartChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onPreset;

  @override
  State<_InlineTimeConfigurator> createState() =>
      _InlineTimeConfiguratorState();
}

class _InlineTimeConfiguratorState extends State<_InlineTimeConfigurator> {
  static const _durMinValues = [0, 15, 30, 45];

  late int _startHour;
  late int _startMinIndex;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();
    _startHour = widget.startHour;
    _startMinIndex = widget.startMinIndex;
    _durationMinutes = widget.durationMinutes;
  }

  int get _durHour => _durationMinutes ~/ 60;
  int get _durMinIdx =>
      _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2C3C)
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wheel row
          Row(
            children: [
              // Start time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CompactWheelColumn(
                          controller: widget.startHourCtrl,
                          itemCount: 24,
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          selectedIndex: _startHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startHour = i;
                            widget.onStartChanged(_startHour, _startMinIndex);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        _CompactWheelColumn(
                          controller: widget.startMinCtrl,
                          itemCount: 12,
                          labelBuilder: (i) =>
                              (i * 5).toString().padLeft(2, '0'),
                          selectedIndex: _startMinIndex,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startMinIndex = i;
                            widget.onStartChanged(_startHour, _startMinIndex);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 52,
                  child: VerticalDivider(
                    width: 1,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.2 : 0.35,
                    ),
                  ),
                ),
              ),
              // Duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CompactWheelColumn(
                          controller: widget.durHourCtrl,
                          itemCount: 12,
                          labelBuilder: (i) => '${i}h',
                          selectedIndex: _durHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            final newDur = i * 60 + _durMinValues[_durMinIdx];
                            _durationMinutes = newDur;
                            widget.onDurationChanged(newDur);
                          },
                        ),
                        const SizedBox(width: 4),
                        _CompactWheelColumn(
                          controller: widget.durMinCtrl,
                          itemCount: _durMinValues.length,
                          labelBuilder: (i) => '${_durMinValues[i]}m',
                          selectedIndex: _durMinIdx,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            final newDur = _durHour * 60 + _durMinValues[i];
                            _durationMinutes = newDur;
                            widget.onDurationChanged(newDur);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Preset chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children:
                const [
                  ('30m', 30),
                  ('1h', 60),
                  ('1h 30m', 90),
                  ('2h', 120),
                  ('2h 30m', 150),
                  ('3h', 180),
                ].map<Widget>((p) {
                  final isSelected = _durationMinutes == p.$2;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _durationMinutes = p.$2);
                      widget.onPreset(p.$2);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo.withValues(alpha: 0.18)
                            : (isDark
                                  ? const Color(0xFF18222E)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.4,
                                    )),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? indigo.withValues(alpha: 0.5)
                              : cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.2 : 0.35,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        p.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isSelected ? indigo : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CompactWheelColumn — 32px itemExtent wheel, 1.5 diameterRatio
// ─────────────────────────────────────────────────────────────────────────────

class _CompactWheelColumn extends StatelessWidget {
  const _CompactWheelColumn({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.selectedIndex,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final int selectedIndex;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 80,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF18222E)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.25),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight band
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: indigo.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 32,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (ctx, i) {
                if (i < 0 || i >= itemCount) return null;
                final isSelected = i == selectedIndex;
                return Center(
                  child: Text(
                    labelBuilder(i),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? indigo : cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.leadingAction,
  });
  final String title;
  final String subtitle;
  final _HeaderAction? leadingAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          if (leadingAction != null) ...[
            IconButton(
              onPressed: leadingAction!.onTap,
              icon: Icon(leadingAction!.icon, size: 20),
              tooltip: leadingAction!.label,
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurface,
                minimumSize: const Size(36, 36),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label, required this.cs});
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs});
  final PaperStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaperStatus.pending => ('Pending', cs.onSurfaceVariant),
      PaperStatus.progress => ('In Progress', const Color(0xFFF59E0B)),
      PaperStatus.done => ('Done', cs.primary),
      PaperStatus.marked => ('Marked', AppTheme.brandGreen),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / no-data states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyExamsState extends StatelessWidget {
  const _EmptyExamsState({required this.canCreate});
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                Icons.assignment_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No exams this term',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              canCreate
                  ? 'Use the + button to create your first exam.'
                  : 'Exams created by teachers will appear here.',
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

class _NoStudentsState extends StatelessWidget {
  const _NoStudentsState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      child: Center(
        child: Text(
          'No students enrolled in this class.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _NoTermState extends StatelessWidget {
  const _NoTermState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Select a term to view exams and grades.',
        style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

String _gradeLabel(int grade, SchoolConfig config) {
  for (final c in config.curricula) {
    final labels = gradeLabelsFor(c.type);
    if (labels.containsKey(grade)) return labels[grade]!;
  }
  return 'Grade $grade';
}

String _streamLabel(int grade, int streamCode, SchoolConfig config) {
  for (final c in config.curricula) {
    final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
    if (gc != null) {
      final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
      if (s != null) return s.name;
    }
  }
  return 'Stream $streamCode';
}

String _typeLabel(ExamType type) => switch (type) {
  ExamType.exam => 'Exam',
  ExamType.assignment => 'Assignment',
  ExamType.assessment => 'Assessment',
};

Color _paperStatusColor(PaperStatus status, ColorScheme cs) => switch (status) {
  PaperStatus.pending => cs.onSurfaceVariant.withValues(alpha: 0.3),
  PaperStatus.progress => const Color(0xFF42A5F5),
  PaperStatus.done => const Color(0xFFFFA726),
  PaperStatus.marked => const Color(0xFF66BB6A),
};

String _paperStatusLabel(PaperStatus status) => switch (status) {
  PaperStatus.pending => 'Pending',
  PaperStatus.progress => 'In Progress',
  PaperStatus.done => 'Done',
  PaperStatus.marked => 'Marked',
};

Color _typeColor(ExamType type, ColorScheme cs) => switch (type) {
  ExamType.exam => cs.primary,
  ExamType.assignment => const Color(0xFFF59E0B),
  ExamType.assessment => AppTheme.brandGreen,
};

Color _pctColor(double pct, ColorScheme cs) {
  if (pct >= 70) return AppTheme.brandGreen;
  if (pct >= 50) return const Color(0xFFF59E0B);
  return cs.error;
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtScore(double score) => score == score.truncateToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(1);

const _months = [
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

// Short month names (alias for calendar widgets)
const _kMonthsShort = _months;

// Full month names for calendar header
const _kFullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// Short weekday names starting Sunday (index = weekday % 7)
const _kDayNamesShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

InputDecoration _inputDeco(ColorScheme cs, {String? label}) {
  final isDark = cs.brightness == Brightness.dark;
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
    ),
    filled: true,
    fillColor: isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55),
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}

/// Generates a simple time-based unique id.
String _generateId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rand = (math.Random().nextInt(0x7FFFFFFF));
  return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
}
