import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/formatters.dart';
import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../database/daos/catalog_dao.dart';
import '../../../../../database/daos/exams_grades_dao.dart' show ExamWithPapers;
import '../../../../../database/tables/enums.dart';

import '../../../../../models/school_config.dart';
import '../../../../../models/school_context.dart';
import '../../../../theme/app_theme.dart';
import '../exam_detail_page.dart';

/// Exams tab — shows all exams for a specific stream within a grade, with
/// local in-memory filters for exam type and personalized status.
///
/// Each exam card shows the type badge, date range, teacher name, paper count,
/// and optional personalized / grade-wide labels.
///
/// Tapping a card navigates to `ExamDetailPage`.
///
/// Exam creation is triggered from outside this tab (e.g. a parent-level action button).
class ExamsTab extends StatefulWidget {
  const ExamsTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? streamCode;
  final String streamName;
  final dynamic curriculumType;
  final SchoolContext schoolContext;

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab>
    with AutomaticKeepAliveClientMixin {
  late final AcademicsDao _dao;
  late final CatalogDao _catalogDao;
  late Stream<List<ExamWithPapers>> _stream;
  StreamSubscription? _subjectSub;
  StreamSubscription? _configSub;

  SchoolConfig _config = SchoolConfig.defaults();
  Map<int, String> _subjectNames = {};

  // ── Filter state ───────────────────────────────────────────────────────────

  /// null = All types
  ExamType? _typeFilter;

  /// null = All, true = Personalized only, false = Standard only
  bool? _personalizedFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = AcademicsDao(db);
    _catalogDao = CatalogDao(db);
    _stream = _buildStream();
    _loadConfig();
    _loadSubjectNames();
  }

  @override
  void didUpdateWidget(covariant ExamsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() => _stream = _buildStream());
    }
  }

  @override
  void dispose() {
    _subjectSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }

  Stream<List<ExamWithPapers>> _buildStream() {
    return _dao.watchExamsForGradeStream(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      streamCode: widget.streamCode,
    );
  }

  void _loadSubjectNames() {
    _subjectSub?.cancel();
    _subjectSub = _catalogDao.watchSubjects().listen((subjects) {
      if (!mounted) return;
      setState(() {
        _subjectNames = {for (final s in subjects) s.id: s.name};
      });
    });
  }

  void _loadConfig() {
    _configSub?.cancel();
    final schoolId = widget.schoolContext.membership.school.id;
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      allStreams,
    ) {
      if (!mounted) return;
      setState(() {
        _config = buildConfigFromStreams(allStreams);
      });
    });
  }

  List<ExamWithPapers> _applyFilters(List<ExamWithPapers> items) {
    return items.where((ep) {
      if (_typeFilter != null && ep.exam.type != _typeFilter) return false;
      if (_personalizedFilter != null &&
          ep.exam.personalized != _personalizedFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<ExamWithPapers>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildLoading(cs);
          }

          final allItems = snapshot.data ?? [];
          final filtered = _applyFilters(allItems);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Filter rows ──────────────────────────────────────────
              _buildFilterSection(cs),

              // ── Divider ──────────────────────────────────────────────
              Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 2),
                color: cs.outline.withValues(alpha: 0.05),
              ),

              // ── List / empty ─────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmpty(cs, allItems.isEmpty)
                    : _buildList(cs, filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Filter section ─────────────────────────────────────────────────────────

  Widget _buildFilterSection(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ExamFilterChip(
                  label: 'All',
                  selected: _typeFilter == null,
                  cs: cs,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Exam',
                  selected: _typeFilter == ExamType.exam,
                  cs: cs,
                  onTap: () => setState(() => _typeFilter = ExamType.exam),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Assignment',
                  selected: _typeFilter == ExamType.assignment,
                  cs: cs,
                  onTap: () =>
                      setState(() => _typeFilter = ExamType.assignment),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Assessment',
                  selected: _typeFilter == ExamType.assessment,
                  cs: cs,
                  onTap: () =>
                      setState(() => _typeFilter = ExamType.assessment),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Personalized filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ExamFilterChip(
                  label: 'All',
                  selected: _personalizedFilter == null,
                  cs: cs,
                  onTap: () => setState(() => _personalizedFilter = null),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Personalized',
                  selected: _personalizedFilter == true,
                  cs: cs,
                  onTap: () => setState(() => _personalizedFilter = true),
                ),
                const SizedBox(width: 6),
                _ExamFilterChip(
                  label: 'Standard',
                  selected: _personalizedFilter == false,
                  cs: cs,
                  onTap: () => setState(() => _personalizedFilter = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty(ColorScheme cs, bool isGloballyEmpty) {
    final String message;
    final IconData icon;

    if (isGloballyEmpty) {
      message = 'No exams for ${widget.streamName}';
      icon = Icons.quiz_outlined;
    } else {
      // Filters are active but yielded zero results.
      final typeLabel = _typeFilter != null
          ? _examTypeLabel(_typeFilter!)
          : null;
      final personLabel = _personalizedFilter == true
          ? 'personalized'
          : _personalizedFilter == false
          ? 'standard'
          : null;

      final parts = <String>[?typeLabel?.toLowerCase(), ?personLabel];
      message = parts.isEmpty
          ? 'No exams found'
          : 'No ${parts.join(' ')} exams found';
      icon = Icons.filter_list_off_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cs.outlineVariant),
            const SizedBox(height: 18),
            Text(
              isGloballyEmpty ? 'No exams this term' : 'No matching exams',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
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

  // ── Exam list ──────────────────────────────────────────────────────────────

  Widget _buildList(ColorScheme cs, List<ExamWithPapers> items) {
    final isDark = cs.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: _buildHeader(cs, items.length),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildExamRow(cs, items[index], isDark);
            },
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, int count) {
    return Text(
      '$count exam${count == 1 ? '' : 's'}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  // ── Exam row ───────────────────────────────────────────────────────────────

  Widget _buildExamRow(ColorScheme cs, ExamWithPapers ep, bool isDark) {
    return _ExamRow(
      ep: ep,
      cs: cs,
      isDark: isDark,
      onTap: () => _onExamTap(ep),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Builds a {streamCode → streamName} map for the current grade from _config.
  Map<int, String> get _streamNames {
    for (final curriculum in _config.curricula) {
      for (final gradeConfig in curriculum.grades) {
        if (gradeConfig.grade == widget.grade) {
          return {for (final s in gradeConfig.streams) s.code: s.name};
        }
      }
    }
    return {};
  }

  void _onExamTap(ExamWithPapers ep) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamDetailPage(
          exam: ep,
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          grade: widget.grade,
          streamCode: widget.streamCode,
          streamName: widget.streamName,
          curriculumType: widget.curriculumType,
          schoolContext: widget.schoolContext,
          subjectNames: _subjectNames,
          streamNames: _streamNames,
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

// ─── Flat exam row with hover ─────────────────────────────────────────────────

class _ExamRow extends StatefulWidget {
  const _ExamRow({
    required this.ep,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final ExamWithPapers ep;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_ExamRow> createState() => _ExamRowState();
}

class _ExamRowState extends State<_ExamRow>
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
    final cs = widget.cs;
    final isDark = widget.isDark;
    final ep = widget.ep;
    final exam = ep.exam;
    final typeColor = _examTypeColor(exam.type, cs);
    final typeLabel = _examTypeLabel(exam.type);

    final startDate = DateTime.fromMillisecondsSinceEpoch(
      exam.start * 86400 * 1000,
    );
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      exam.end * 86400 * 1000,
    );

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
                      // ── Colored accent bar ──────────────────────────────
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

                      // ── Content ─────────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              // ── Type badge ──────────────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(
                                    alpha: isDark ? 0.2 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: typeColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // ── Exam name + date range ──────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ── Exam name (primary) ───────────────
                                    Text(
                                      exam.name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    // ── Date range (secondary) ────────────
                                    Row(
                                      children: [
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
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // ── Scope badges ───────────────────────────
                              if (exam.personalized)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: cs.outline.withValues(
                                          alpha: isDark ? 0.15 : 0.12,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Personalized',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // ── Paper count badge ───────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${ep.papers.length}p',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 4),

                              // ── Chevron ─────────────────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(_isHovered ? 0.15 : 0.0, 0),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
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

class _ExamFilterChip extends StatelessWidget {
  const _ExamFilterChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _examTypeLabel(ExamType type) => switch (type) {
  ExamType.exam => 'Exam',
  ExamType.assignment => 'Assignment',
  ExamType.assessment => 'Assessment',
};

Color _examTypeColor(ExamType type, ColorScheme cs) => switch (type) {
  ExamType.exam => cs.primary,
  ExamType.assignment => const Color(0xFFF59E0B),
  ExamType.assessment => const Color(0xFF4CAF50),
};
