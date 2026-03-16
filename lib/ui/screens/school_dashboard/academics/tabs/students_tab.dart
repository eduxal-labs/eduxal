import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../cache/file_cache.dart';
import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../models/grade_analytics.dart';
import '../../../../../models/school_context.dart';
import '../../../../theme/app_theme.dart';
import '../student_grade_page.dart';

/// Students tab — shows all enrolled students for a specific stream within a
/// grade. Each row displays the student's avatar, name, admission number,
/// trajectory indicator, and overall average percentage badge.
///
/// Tapping a row navigates to `StudentGradePage`.
class StudentsTab extends StatefulWidget {
  const StudentsTab({
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
  final dynamic curriculumType;
  final SchoolContext schoolContext;

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab>
    with AutomaticKeepAliveClientMixin {
  late final AcademicsDao _dao;
  late Stream<List<GradeStudentRow>> _stream;

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
  void didUpdateWidget(covariant StudentsTab oldWidget) {
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

  Stream<List<GradeStudentRow>> _buildStream() {
    return _dao.watchStudentsForGrade(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  List<GradeStudentRow> _filterRows(List<GradeStudentRow> rows) {
    if (_searchQuery.isEmpty) return rows;
    final query = _searchQuery.toLowerCase();
    return rows.where((row) {
      final nameMatch = row.student.name.toLowerCase().contains(query);
      final admMatch = row.student.adm.toString().contains(query);
      return nameMatch || admMatch;
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<GradeStudentRow>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return _buildEmpty(cs);
        }

        final filtered = _filterRows(rows);
        return _buildList(cs, rows.length, filtered);
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
                Icons.people_outline_rounded,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No students enrolled',
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
              'Use the + button to enroll students in ${widget.streamName}',
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

  // ── Student list ───────────────────────────────────────────────────────────

  Widget _buildList(
    ColorScheme cs,
    int totalCount,
    List<GradeStudentRow> rows,
  ) {
    final isDark = cs.brightness == Brightness.dark;
    final showingFiltered =
        _searchQuery.isNotEmpty && rows.length != totalCount;

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
                ? '${rows.length} of $totalCount student${totalCount == 1 ? '' : 's'}'
                : '$totalCount student${totalCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),

        // ── List ───────────────────────────────────────────────────────
        Expanded(
          child: rows.isEmpty
              ? _buildNoResults(cs)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    return _buildStudentItem(cs, rows[index], isDark);
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
              'No students match "$_searchQuery"',
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

  // ── Student row ────────────────────────────────────────────────────────────

  Widget _buildStudentItem(ColorScheme cs, GradeStudentRow row, bool isDark) {
    return _StudentRow(
      row: row,
      schoolId: widget.schoolId,
      cs: cs,
      isDark: isDark,
      onTap: () => _onStudentTap(row),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onStudentTap(GradeStudentRow row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentGradePage(
          schoolId: widget.schoolId,
          year: widget.year,
          term: widget.term,
          grade: widget.grade,
          streamCode: widget.streamCode,
          streamName: widget.streamName,
          studentAdm: row.student.adm,
          curriculumType: widget.curriculumType,
          schoolContext: widget.schoolContext,
        ),
      ),
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
            hintText: 'Search by name or ADM no…',
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

// ─── Interactive student row with press animation ────────────────────────────

class _StudentRow extends StatefulWidget {
  const _StudentRow({
    required this.row,
    required this.schoolId,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final GradeStudentRow row;
  final String schoolId;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends State<_StudentRow>
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

  /// Accent color derived from student trajectory.
  Color _trajectoryColor(Trajectory trajectory, ColorScheme cs) {
    return switch (trajectory) {
      Trajectory.improving => const Color(0xFF4CAF50),
      Trajectory.declining => const Color(0xFFF44336),
      Trajectory.stable => const Color(0xFF42A5F5),
      Trajectory.insufficientData => cs.onSurfaceVariant.withValues(alpha: 0.3),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final row = widget.row;
    final accentColor = _trajectoryColor(row.trajectory, cs);

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.12);

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
                      ? accentColor.withValues(alpha: isDark ? 0.35 : 0.25)
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
                      // ── Accent bar ───────────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 4 : 3,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Content ──────────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              // ── Avatar with ring ─────────────────────────
                              _StudentAvatar(
                                schoolId: widget.schoolId,
                                adm: row.student.adm,
                                cs: cs,
                                accentColor: accentColor,
                                isHighlighted: _isHovered || _isPressed,
                              ),

                              const SizedBox(width: 12),

                              // ── Name + ADM ──────────────────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      row.student.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ADM: ${row.student.adm}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // ── Trajectory icon ─────────────────────────
                              _TrajectoryIcon(
                                trajectory: row.trajectory,
                                cs: cs,
                              ),

                              const SizedBox(width: 8),

                              // ── Average badge ───────────────────────────
                              _AverageBadge(
                                percent: row.overallAverage,
                                cs: cs,
                                isDark: isDark,
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
                                        ? accentColor
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

// ─── Student Avatar (cached file-based) ──────────────────────────────────────

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({
    required this.schoolId,
    required this.adm,
    required this.cs,
    required this.accentColor,
    this.isHighlighted = false,
  });

  final String schoolId;
  final int adm;
  final ColorScheme cs;
  final Color accentColor;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.studentImagePath(schoolId, adm)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withValues(
                alpha: isHighlighted ? 0.7 : 0.25,
              ),
              width: isHighlighted ? 1.5 : 1.0,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: hasImage
              ? CircleAvatar(
                  radius: 17,
                  backgroundImage: FileImage(file),
                  backgroundColor: cs.surfaceContainerHighest,
                )
              : CircleAvatar(
                  radius: 17,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                ),
        );
      },
    );
  }
}

// ─── Trajectory icon ─────────────────────────────────────────────────────────

class _TrajectoryIcon extends StatelessWidget {
  const _TrajectoryIcon({required this.trajectory, required this.cs});

  final Trajectory trajectory;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (trajectory) {
      Trajectory.improving => (
        Icons.trending_up_rounded,
        const Color(0xFF4CAF50),
      ),
      Trajectory.declining => (
        Icons.trending_down_rounded,
        const Color(0xFFF44336),
      ),
      Trajectory.stable => (
        Icons.trending_flat_rounded,
        const Color(0xFFFFA726),
      ),
      Trajectory.insufficientData => (
        Icons.help_outline_rounded,
        cs.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    };

    return Icon(icon, size: 16, color: color);
  }
}

// ─── Average percentage badge ────────────────────────────────────────────────

class _AverageBadge extends StatelessWidget {
  const _AverageBadge({
    required this.percent,
    required this.cs,
    required this.isDark,
  });

  final double? percent;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = percent != null ? '${percent!.round()}%' : '—';
    final color = percent != null ? _percentColor(percent!) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: isDark ? 0.18 : 0.1)
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color ?? cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  static Color _percentColor(double p) {
    if (p >= 70) return const Color(0xFF4CAF50);
    if (p >= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }
}
