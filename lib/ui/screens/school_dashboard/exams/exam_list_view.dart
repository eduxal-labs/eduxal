import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../core/formatters.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/exam_group.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_filter_toolbar.dart';
import 'exam_creation_page.dart';
import 'exams_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExamsListView — main exam list with search/filter toolbar
// ─────────────────────────────────────────────────────────────────────────────

class ExamsListView extends StatefulWidget {
  const ExamsListView({
    super.key,
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
  State<ExamsListView> createState() => _ExamsListViewState();
}

class _ExamsListViewState extends State<ExamsListView> {
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
    // Teachers without admin exams.read permission only see exams they
    // participate in (as creator, invigilator, or subject teacher).
    String? teacherFilter;
    final entry = widget.entry;
    if (entry is TeacherEntry &&
        !widget.schoolContext.permissions.can(Resource.exams, Action.read)) {
      teacherFilter = entry.teacher.user;
    }
    return _dao.watchExamGroups(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      teacherId: teacherFilter,
    );
  }

  /// Extract a display name from an [ExamGroup].
  String _examGroupName(ExamGroup group) => group.name;

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
      floatingActionButton: _canCreateExam
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
          SectionHeader(
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
                label: typeLabel(t),
                isSelected: _activeTypeFilters.contains(t),
                onTap: () => _toggleTypeFilter(t),
                activeColor: typeColor(t, cs),
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
                  return EmptyExamsState(canCreate: _canCreateExam);
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
                return RefreshIndicator(
                  onRefresh: () async {
                    sync.pushNow();
                    await Future.delayed(const Duration(milliseconds: 800));
                  },
                  color: cs.primary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      return _ExamGroupRow(
                        group: items[i],
                        config: widget.config,
                        onTap: () => widget.onExamTap(items[i]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _canCreateExam =>
      widget.schoolContext.permissions.can(Resource.exams, Action.create) ||
      widget.entry is OwnerEntry;

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
// Exam group row — data-table-style row
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
    final tColor = typeColor(widget.group.type, cs);
    final tLabel = typeLabel(widget.group.type);
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
    final examName = widget.group.name;

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? tColor.withValues(alpha: 0.12)
        : tColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? tColor.withValues(alpha: 0.18)
        : tColor.withValues(alpha: 0.12);

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
                      ? tColor.withValues(alpha: isDark ? 0.35 : 0.25)
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
                          color: tColor.withValues(
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
                                            color: tColor.withValues(
                                              alpha: isDark ? 0.18 : 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.kChipRadius,
                                            ),
                                          ),
                                          child: Text(
                                            tLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: tColor,
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
                                          '${fmtDateDt(startDate)} – ${fmtDateDt(endDate)}',
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
                                            (g) => ClassChip(
                                              label: examGradeLabel(
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
                                  MetaBadge(
                                    icon: Icons.school_outlined,
                                    label: '$gradeCount',
                                    cs: cs,
                                  ),
                                  const SizedBox(width: 4),
                                  MetaBadge(
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
                                            ? tColor
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
