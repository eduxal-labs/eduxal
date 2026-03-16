import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../models/grade_analytics.dart';
import '../../../../../models/school_config.dart';
import '../../../../theme/app_theme.dart';

/// Comparisons tab — compares all streams within a grade on key metrics.
///
/// Shows:
/// 1. A horizontal summary row of compact stat cards.
/// 2. One comparison card per stream with stats grid.
/// 3. A ranking table (when 2+ streams exist).
/// 4. A performance trend chart (fl_chart LineChart).
class ComparisonsTab extends StatefulWidget {
  const ComparisonsTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streams,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final List<GradeStream> streams;

  @override
  State<ComparisonsTab> createState() => _ComparisonsTabState();
}

class _ComparisonsTabState extends State<ComparisonsTab> {
  late final AcademicsDao _dao;
  List<StreamStats>? _stats;
  Map<int, List<({String label, double percent})>>? _trendData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dao = AcademicsDao(db);
    _loadComparison();
  }

  @override
  void didUpdateWidget(covariant ComparisonsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streams.length != widget.streams.length) {
      _loadComparison();
    }
  }

  Future<void> _loadComparison() async {
    setState(() => _loading = true);
    try {
      final streamRecords = widget.streams
          .map((s) => (code: s.code, name: s.name))
          .toList();
      final statsFuture = _dao.computeStreamComparison(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
        streams: streamRecords,
      );
      final trendFuture = _dao.computeExamTrend(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
        streams: streamRecords,
      );
      final results = await Future.wait([statsFuture, trendFuture]);
      if (mounted) {
        setState(() {
          _stats = results[0] as List<StreamStats>;
          _trendData =
              results[1] as Map<int, List<({String label, double percent})>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stats = [];
          _trendData = {};
          _loading = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return _buildLoading(cs);
    }

    final stats = _stats;
    if (stats == null || stats.isEmpty) {
      return _buildEmpty(cs);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── 1. Summary row ───────────────────────────────────────────
        _SummaryRow(stats: stats),
        const SizedBox(height: 20),

        // ── 2. Stream comparison cards ───────────────────────────────
        for (int i = 0; i < stats.length; i++) ...[
          _StreamComparisonCard(stats: stats[i]),
          if (i < stats.length - 1) const SizedBox(height: 10),
        ],

        // ── 3. Ranking table (2+ streams) ────────────────────────────
        if (stats.length >= 2) ...[
          const SizedBox(height: 24),
          _RankingTable(stats: stats),
        ],

        // ── 4. Performance trend chart ───────────────────────────────
        if (_trendData != null) ...[
          const SizedBox(height: 24),
          _TrendSection(
            cs: cs,
            trendData: _trendData!,
            streams: widget.streams,
          ),
        ],
      ],
    );
  }

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
                Icons.bar_chart_rounded,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No streams configured',
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
              'No data available yet for this grade',
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
// Summary Row — horizontal scrollable row of compact stat cards
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final List<StreamStats> stats;

  @override
  Widget build(BuildContext context) {
    final totalStudents = stats.fold<int>(0, (sum, s) => sum + s.studentCount);
    final streamCount = stats.length;

    // Best performing = highest lastExamAverage
    final withExams = stats.where((s) => s.lastExamAverage != null).toList();
    String bestPerforming = '—';
    if (withExams.isNotEmpty) {
      withExams.sort(
        (a, b) => (b.lastExamAverage ?? 0).compareTo(a.lastExamAverage ?? 0),
      );
      bestPerforming = withExams.first.streamName;
    }

    // Most improved = trajectory == improving; if multiple, pick highest lastExamAverage
    final improving = stats
        .where((s) => s.trajectory == Trajectory.improving)
        .toList();
    String mostImproved = '—';
    if (improving.isNotEmpty) {
      improving.sort(
        (a, b) => (b.lastExamAverage ?? 0).compareTo(a.lastExamAverage ?? 0),
      );
      mostImproved = improving.first.streamName;
    }

    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SummaryCard(
            label: 'Total Students',
            value: '$totalStudents',
            icon: Icons.people_outline_rounded,
            accentColor: const Color(0xFF42A5F5),
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Streams',
            value: '$streamCount',
            icon: Icons.view_stream_outlined,
            accentColor: const Color(0xFF26A69A),
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Best Performing',
            value: bestPerforming,
            icon: Icons.emoji_events_outlined,
            accentColor: const Color(0xFFFFA726),
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Most Improved',
            value: mostImproved,
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF66BB6A),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.15 : 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container with accent background
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: isDark ? 0.2 : 0.14),
                  accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream Comparison Card — one per stream with stats grid
// ─────────────────────────────────────────────────────────────────────────────

class _StreamComparisonCard extends StatefulWidget {
  const _StreamComparisonCard({required this.stats});

  final StreamStats stats;

  @override
  State<_StreamComparisonCard> createState() => _StreamComparisonCardState();
}

class _StreamComparisonCardState extends State<_StreamComparisonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl;
  late final Animation<double> _borderAlpha;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _borderAlpha = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    if (hovering == _isHovered) return;
    setState(() => _isHovered = hovering);
    if (hovering) {
      _hoverCtrl.forward();
    } else {
      _hoverCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final streamColor = _streamColor(widget.stats.streamCode);

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _borderAlpha,
        builder: (context, child) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: Color.lerp(
                  cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
                  streamColor.withValues(alpha: isDark ? 0.35 : 0.3),
                  _borderAlpha.value,
                )!,
              ),
            ),
            child: child,
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // ── Left accent bar ────────────────────────────────────
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    streamColor,
                    streamColor.withValues(alpha: 0.4),
                  ],
                ),
              ),
              ),
              // ── Card content ───────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ─────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: streamColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.stats.streamName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: streamColor.withValues(
                                alpha: isDark ? 0.12 : 0.08,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kChipRadius,
                              ),
                            ),
                            child: Text(
                              '${widget.stats.studentCount} student${widget.stats.studentCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: streamColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Stats grid (2 columns × 3 rows) ───────────
                      Row(
                        children: [
                          Expanded(
                            child: _StatCell(
                              label: 'Overall Avg',
                              value: _fmtPercent(widget.stats.averageScore),
                              percent: widget.stats.averageScore / 100.0,
                              barColor: _percentColor(widget.stats.averageScore),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCell(
                              label: 'Last Exam',
                              value: widget.stats.lastExamAverage != null
                                  ? _fmtPercent(widget.stats.lastExamAverage!)
                                  : '—',
                              percent: widget.stats.lastExamAverage != null
                                  ? widget.stats.lastExamAverage! / 100.0
                                  : null,
                              barColor: widget.stats.lastExamAverage != null
                                  ? _percentColor(widget.stats.lastExamAverage!)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCell(
                              label: 'Attendance',
                              value: widget.stats.attendanceRate != null
                                  ? _fmtPercent(widget.stats.attendanceRate!)
                                  : '—',
                              percent: widget.stats.attendanceRate != null
                                  ? widget.stats.attendanceRate! / 100.0
                                  : null,
                              barColor: widget.stats.attendanceRate != null
                                  ? _percentColor(widget.stats.attendanceRate!)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCell(
                              label: 'Mastery',
                              value: widget.stats.masteryAverage != null
                                  ? _fmtPercent(widget.stats.masteryAverage!)
                                  : '—',
                              percent: widget.stats.masteryAverage != null
                                  ? widget.stats.masteryAverage! / 100.0
                                  : null,
                              barColor: widget.stats.masteryAverage != null
                                  ? _percentColor(widget.stats.masteryAverage!)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TrajectoryBadge(trajectory: widget.stats.trajectory),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Cell — label + value + thin horizontal progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.percent,
    this.barColor,
  });

  final String label;
  final String value;

  /// 0.0 – 1.0 fraction for the bar. null → no bar shown.
  final double? percent;

  /// Color for the bar fill. null → no bar shown.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        if (percent != null && barColor != null) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  // Background track
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Filled portion with gradient
                  FractionallySizedBox(
                    widthFactor: percent!.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            barColor!.withValues(alpha: 0.7),
                            barColor!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trajectory Badge — compact pill with icon + label
// ─────────────────────────────────────────────────────────────────────────────

class _TrajectoryBadge extends StatelessWidget {
  const _TrajectoryBadge({required this.trajectory});

  final Trajectory trajectory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final (IconData icon, String label, Color color) = switch (trajectory) {
      Trajectory.improving => (
        Icons.trending_up_rounded,
        'Improving',
        const Color(0xFF4CAF50),
      ),
      Trajectory.declining => (
        Icons.trending_down_rounded,
        'Declining',
        const Color(0xFFEF5350),
      ),
      Trajectory.stable => (
        Icons.trending_flat_rounded,
        'Stable',
        const Color(0xFFFFA726),
      ),
      Trajectory.insufficientData => (
        Icons.help_outline_rounded,
        'Insufficient Data',
        cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.2 : 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ranking Table — compact table ranking streams by lastExamAverage desc
// ─────────────────────────────────────────────────────────────────────────────

class _RankingTable extends StatefulWidget {
  const _RankingTable({required this.stats});

  final List<StreamStats> stats;

  @override
  State<_RankingTable> createState() => _RankingTableState();
}

class _RankingTableState extends State<_RankingTable>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _buildAnimations();
    _startStaggered();
  }

  @override
  void didUpdateWidget(covariant _RankingTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats.length != widget.stats.length) {
      _disposeControllers();
      _buildAnimations();
      _startStaggered();
    }
  }

  void _buildAnimations() {
    final count = widget.stats.length;
    _controllers = List.generate(count, (_) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      );
    });
    _fadeAnimations = _controllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();
    _slideAnimations = _controllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();
  }

  Future<void> _startStaggered() async {
    for (int i = 0; i < _controllers.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 65));
      if (!mounted) return;
      _controllers[i].forward();
    }
  }

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Sort by lastExamAverage descending; null values go last.
    final ranked = List<StreamStats>.from(widget.stats)
      ..sort((a, b) {
        final aVal = a.lastExamAverage ?? -1;
        final bVal = b.lastExamAverage ?? -1;
        return bVal.compareTo(aVal);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Icon(
                Icons.leaderboard_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                'Stream Ranking',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),

        // Table container
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            border: Border.all(
              color: AppTheme.borderColor(isDark, cs).withValues(
                alpha: isDark ? 0.6 : 0.5,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Table header ─────────────────────────────────────────
              Container(
                color: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('Rank', style: _headerStyle(cs)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Stream', style: _headerStyle(cs)),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        'Students',
                        style: _headerStyle(cs),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        'Last Exam',
                        style: _headerStyle(cs),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        'Overall',
                        style: _headerStyle(cs),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '',
                        style: _headerStyle(cs),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Table rows ───────────────────────────────────────────
              for (int i = 0; i < ranked.length; i++)
                SlideTransition(
                  position: i < _slideAnimations.length
                      ? _slideAnimations[i]
                      : const AlwaysStoppedAnimation(Offset.zero),
                  child: FadeTransition(
                    opacity: i < _fadeAnimations.length
                        ? _fadeAnimations[i]
                        : const AlwaysStoppedAnimation(1.0),
                    child: _RankingRow(
                      rank: i + 1,
                      stats: ranked[i],
                      isAlternate: i.isOdd,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _headerStyle(ColorScheme cs) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
    letterSpacing: 0.2,
  );
}

class _RankingRow extends StatefulWidget {
  const _RankingRow({
    required this.rank,
    required this.stats,
    required this.isAlternate,
  });

  final int rank;
  final StreamStats stats;
  final bool isAlternate;

  @override
  State<_RankingRow> createState() => _RankingRowState();
}

class _RankingRowState extends State<_RankingRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final rank = widget.rank;

    // Medal colors for top 3
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    final bool isMedalist = rank <= 3;

    // Background: top row gets a gold-tinted bg, rest alternate
    final Color bgColor;
    if (_isHovered) {
      bgColor = cs.primary.withValues(alpha: 0.04);
    } else if (rank == 1) {
      bgColor = isDark
          ? goldColor.withValues(alpha: 0.06)
          : goldColor.withValues(alpha: 0.04);
    } else if (widget.isAlternate) {
      bgColor = isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.15)
          : cs.surfaceContainerHighest.withValues(alpha: 0.2);
    } else {
      bgColor = Colors.transparent;
    }

    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: cs.onSurface.withValues(alpha: 0.85),
    );

    final (IconData tIcon, Color tColor) = switch (widget.stats.trajectory) {
      Trajectory.improving => (
        Icons.trending_up_rounded,
        const Color(0xFF4CAF50),
      ),
      Trajectory.declining => (
        Icons.trending_down_rounded,
        const Color(0xFFEF5350),
      ),
      Trajectory.stable => (
        Icons.trending_flat_rounded,
        const Color(0xFFFFA726),
      ),
      Trajectory.insufficientData => (
        Icons.help_outline_rounded,
        cs.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    };

    // Rank indicator: medal icon for top 3, plain number for rest
    Widget rankWidget;
    if (isMedalist) {
      final medalColor = switch (rank) {
        1 => goldColor,
        2 => silverColor,
        _ => bronzeColor,
      };
      rankWidget = Icon(
        Icons.emoji_events_rounded,
        size: 18,
        color: medalColor,
      );
    } else {
      rankWidget = Text(
        '$rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 36, child: Center(child: rankWidget)),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  // Stream color dot
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _streamColor(widget.stats.streamCode),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.stats.streamName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: rank == 1
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${widget.stats.studentCount}',
                style: valueStyle,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: Text(
                widget.stats.lastExamAverage != null
                    ? _fmtPercent(widget.stats.lastExamAverage!)
                    : '—',
                style: widget.stats.lastExamAverage != null
                    ? valueStyle.copyWith(
                        color: _percentColor(widget.stats.lastExamAverage!),
                      )
                    : valueStyle,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: Text(
                _fmtPercent(widget.stats.averageScore),
                style: valueStyle,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 24, child: Icon(tIcon, size: 16, color: tColor)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Deterministic color palette for streams — indexed by stream code modulo 6.
const _kStreamColors = <Color>[
  Color(0xFF5C6BC0), // indigo
  Color(0xFF26A69A), // teal
  Color(0xFFEF5350), // red
  Color(0xFFFFA726), // amber
  Color(0xFF66BB6A), // green
  Color(0xFFAB47BC), // purple
];

Color _streamColor(int streamCode) =>
    _kStreamColors[streamCode % _kStreamColors.length];

// ─────────────────────────────────────────────────────────────────────────────
// 4. Performance Trend — fl_chart LineChart
// ─────────────────────────────────────────────────────────────────────────────

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.cs,
    required this.trendData,
    required this.streams,
  });

  final ColorScheme cs;
  final Map<int, List<({String label, double percent})>> trendData;
  final List<GradeStream> streams;

  @override
  Widget build(BuildContext context) {
    // Determine if there's enough data — need at least 2 data points in any
    // stream to draw a meaningful trend.
    final maxPoints = trendData.values.fold<int>(
      0,
      (prev, list) => list.length > prev ? list.length : prev,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                'Performance Trend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (maxPoints < 2) _buildNotEnoughData() else _buildChart(maxPoints),
      ],
    );
  }

  Widget _buildNotEnoughData() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: cs.outline.withValues(
            alpha: cs.brightness == Brightness.dark ? 0.06 : 0.04,
          ),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_flat_rounded,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            'Not enough data for trends',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(int maxPoints) {
    final isDark = cs.brightness == Brightness.dark;

    // Collect all unique labels in order.
    final allLabels = <String>[];
    for (final pts in trendData.values) {
      for (final p in pts) {
        if (!allLabels.contains(p.label)) {
          allLabels.add(p.label);
        }
      }
    }

    // Build line data for each stream.
    final lineBars = <LineChartBarData>[];
    for (final s in streams) {
      final points = trendData[s.code];
      if (points == null || points.length < 2) continue;

      final color = _streamColor(s.code);
      final spots = <FlSpot>[];
      for (final p in points) {
        final idx = allLabels.indexOf(p.label);
        if (idx >= 0) {
          spots.add(FlSpot(idx.toDouble(), p.percent.clamp(0, 100)));
        }
      }

      if (spots.length < 2) continue;

      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1.5,
                strokeColor: isDark
                    ? cs.surface
                    : Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.12 : 0.1),
                color.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > 100) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= allLabels.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            allLabels[idx],
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (allLabels.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: lineBars,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => isDark
                        ? const Color(0xFF1E2A3A)
                        : cs.surface,
                    tooltipRoundedRadius: AppTheme.kChipRadius,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final color = spot.bar.color ?? cs.primary;
                        // Find stream name from color match
                        String streamLabel = '';
                        for (final s in streams) {
                          if (_streamColor(s.code) == color) {
                            streamLabel = s.name;
                            break;
                          }
                        }
                        return LineTooltipItem(
                          '$streamLabel\n',
                          TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          children: [
                            TextSpan(
                              text: _fmtPercent(spot.y),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final s in streams)
                  if ((trendData[s.code]?.length ?? 0) >= 2)
                    _LegendItem(
                      color: _streamColor(s.code),
                      label: s.name,
                      cs: cs,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.cs,
  });

  final Color color;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Format a percentage value to one decimal place.
String _fmtPercent(double value) {
  if (value == value.roundToDouble()) {
    return '${value.round()}%';
  }
  return '${value.toStringAsFixed(1)}%';
}

/// Returns a color based on the percentage value:
/// - green (≥75), amber (≥50), red (<50).
Color _percentColor(double percent) {
  if (percent >= 75) return const Color(0xFF4CAF50);
  if (percent >= 50) return const Color(0xFFFFA726);
  return const Color(0xFFEF5350);
}
