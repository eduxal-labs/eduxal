import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../models/grade_analytics.dart';
import '../../../../../models/school_context.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';
import '../subject_detail_page.dart';

/// Subjects tab — shows all subject-teacher assignments for a specific stream
/// within a grade. Each card displays the subject name, assigned teacher,
/// mastery comparison bars (stream vs grade average), and a delta indicator.
class SubjectsTab extends StatefulWidget {
  const SubjectsTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  @override
  State<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<SubjectsTab>
    with AutomaticKeepAliveClientMixin {
  late final AcademicsDao _dao;
  late Stream<List<SubjectTeacherEntry>> _stream;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = AcademicsDao(db);
    _stream = _buildStream();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant SubjectsTab oldWidget) {
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
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  Stream<List<SubjectTeacherEntry>> _buildStream() {
    return _dao.watchSubjectsForGrade(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  List<SubjectTeacherEntry> _filterEntries(List<SubjectTeacherEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    final query = _searchQuery.toLowerCase();
    return entries.where((entry) {
      final nameMatch = entry.subjectName.toLowerCase().contains(query);
      final teacherMatch = entry.teacher.name.toLowerCase().contains(query);
      return nameMatch || teacherMatch;
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<SubjectTeacherEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return _buildEmpty(cs);
        }

        final filtered = _filterEntries(entries);
        return _buildList(cs, entries.length, filtered);
      },
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

  Widget _buildEmpty(ColorScheme cs) {
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
                Icons.menu_book_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No subjects assigned',
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
              'No subjects have been assigned to ${widget.streamName}',
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

  // ── Subject list ───────────────────────────────────────────────────────────

  Widget _buildList(
    ColorScheme cs,
    int totalCount,
    List<SubjectTeacherEntry> entries,
  ) {
    final isDark = cs.brightness == Brightness.dark;
    final showingFiltered =
        _searchQuery.isNotEmpty && entries.length != totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search toolbar ─────────────────────────────────────────────
        _SearchToolbar(controller: _searchController, cs: cs),

        // ── Count header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            showingFiltered
                ? '${entries.length} of $totalCount subject${totalCount == 1 ? '' : 's'}'
                : '$totalCount subject${totalCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),

        // ── List (card-based, no dividers) ─────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? _buildNoResults(cs)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return _buildSubjectRow(cs, entries[index], isDark);
                  },
                ),
        ),
      ],
    );
  }

  // ── No search results ──────────────────────────────────────────────────────

  Widget _buildNoResults(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 28,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No subjects match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Subject row ────────────────────────────────────────────────────────────

  Widget _buildSubjectRow(
    ColorScheme cs,
    SubjectTeacherEntry entry,
    bool isDark,
  ) {
    return _SubjectRow(
      entry: entry,
      curriculumType: widget.curriculumType,
      cs: cs,
      isDark: isDark,
      schoolContext: widget.schoolContext,
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
    );
  }
}

// ─── Search toolbar ──────────────────────────────────────────────────────────

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({required this.controller, required this.cs});

  final TextEditingController controller;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Search by subject or teacher…',
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => controller.clear(),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                );
              },
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.4 : 0.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide(color: cs.primary, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Interactive subject card row ─────────────────────────────────────────────

/// Deterministic subject color from a 10-color palette.
Color _subjectColor(int subject) {
  const palette = [
    Color(0xFF42A5F5), // blue
    Color(0xFF66BB6A), // green
    Color(0xFFAB47BC), // purple
    Color(0xFFEF5350), // red
    Color(0xFFFFA726), // orange
    Color(0xFF26A69A), // teal
    Color(0xFF5C6BC0), // indigo
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF78909C), // blue grey
  ];
  return palette[subject % palette.length];
}

class _SubjectRow extends StatefulWidget {
  const _SubjectRow({
    required this.entry,
    required this.curriculumType,
    required this.cs,
    required this.isDark,
    required this.schoolContext,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
  });

  final SubjectTeacherEntry entry;
  final CurriculumType curriculumType;
  final ColorScheme cs;
  final bool isDark;
  final SchoolContext schoolContext;
  final String schoolId;
  final int year;
  final int term;
  final int grade;

  @override
  State<_SubjectRow> createState() => _SubjectRowState();
}

class _SubjectRowState extends State<_SubjectRow>
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
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
    final entry = widget.entry;
    final label = entry.subjectName;
    final color = _subjectColor(entry.subject.subject);

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? color.withValues(alpha: 0.12)
        : color.withValues(alpha: 0.08);
    final pressBg = isDark
        ? color.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.12);

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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubjectDetailPage(
                    schoolContext: widget.schoolContext,
                    subjectEntry: widget.entry,
                    schoolId: widget.schoolId,
                    year: widget.year,
                    term: widget.term,
                    grade: widget.grade,
                    streamCode: widget.entry.streamCode,
                    streamName: widget.entry.streamName,
                    curriculumType: widget.curriculumType,
                  ),
                ),
              );
            },
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
                      ? color.withValues(alpha: isDark ? 0.35 : 0.25)
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
                          color: color.withValues(
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── Subject name + teacher ──────────────────
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UserAvatar(
                                          userId: entry.teacher.id,
                                          radius: 10,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            entry.teacher.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: cs.onSurfaceVariant
                                                  .withValues(alpha: 0.65),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // ── Mastery bars (compact) ──────────────────
                              Expanded(
                                flex: 3,
                                child: _MasterySection(
                                  streamAvg: entry.streamMasteryAverage,
                                  gradeAvg: entry.gradeMasteryAverage,
                                  accentColor: color,
                                  cs: cs,
                                  isDark: isDark,
                                ),
                              ),

                              const SizedBox(width: 4),

                              // ── Chevron ─────────────────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(
                                  _isHovered ? 0.15 : 0.0,
                                  0,
                                ),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isHovered ? 0.8 : 0.35,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _isHovered
                                        ? color
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

// ─── Mastery bars + delta indicator ──────────────────────────────────────────

class _MasterySection extends StatelessWidget {
  const _MasterySection({
    required this.streamAvg,
    required this.gradeAvg,
    required this.accentColor,
    required this.cs,
    required this.isDark,
  });

  final double? streamAvg;
  final double? gradeAvg;
  final Color accentColor;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (streamAvg == null && gradeAvg == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 4),
          Text(
            'No mastery data',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? accentColor.withValues(alpha: 0.06)
            : accentColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.10 : 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Stream average bar ─────────────────────────────────────────
          _MasteryBar(
            label: 'Stream Avg',
            value: streamAvg,
            cs: cs,
            isDark: isDark,
          ),

          const SizedBox(height: 6),

          // ── Grade average bar ──────────────────────────────────────────
          _MasteryBar(
            label: 'Grade Avg',
            value: gradeAvg,
            cs: cs,
            isDark: isDark,
          ),

          // ── Delta indicator ────────────────────────────────────────────
          if (streamAvg != null && gradeAvg != null) ...[
            const SizedBox(height: 6),
            _buildDelta(streamAvg!, gradeAvg!),
          ],
        ],
      ),
    );
  }

  Widget _buildDelta(double stream, double grade) {
    final delta = stream - grade;
    if (delta.abs() < 0.05) {
      return Text(
        'Same as grade average',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      );
    }

    final isPositive = delta > 0;
    final color = isPositive
        ? const Color(0xFF4CAF50)
        : const Color(0xFFF44336);
    final sign = isPositive ? '+' : '';
    final icon = isPositive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '$sign${delta.toStringAsFixed(1)}% vs grade',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Individual mastery bar ──────────────────────────────────────────────────

class _MasteryBar extends StatelessWidget {
  const _MasteryBar({
    required this.label,
    required this.value,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final double? value;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final percent = value ?? 0.0;
    final barColor = value != null ? _percentColor(percent) : null;
    final displayLabel = value != null ? '${value!.toStringAsFixed(1)}%' : '—';

    return Row(
      children: [
        // Label
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),

        // Bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: value != null ? (percent / 100).clamp(0.0, 1.0) : 0.0,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.6 : 0.8,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  barColor ?? cs.surfaceContainerHighest,
                ),
                minHeight: 6,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Percentage label
        SizedBox(
          width: 42,
          child: Text(
            displayLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: barColor ?? cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }

  static Color _percentColor(double p) {
    if (p >= 70) return const Color(0xFF4CAF50);
    if (p >= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }
}
