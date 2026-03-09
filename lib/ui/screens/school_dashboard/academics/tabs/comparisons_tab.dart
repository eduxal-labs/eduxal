import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/academics_dao.dart';
import '../../../../../models/grade_analytics.dart';
import '../../../../../models/school_config.dart';

/// Comparisons tab — compares all streams within a grade on key metrics.
///
/// Shows:
/// 1. A horizontal summary row of compact stat cards.
/// 2. One comparison card per stream with stats grid.
/// 3. A ranking table (when 2+ streams exist).
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
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SummaryCard(
            label: 'Total Students',
            value: '$totalStudents',
            icon: Icons.people_outline_rounded,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Streams',
            value: '$streamCount',
            icon: Icons.view_stream_outlined,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Best Performing',
            value: bestPerforming,
            icon: Icons.emoji_events_outlined,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Most Improved',
            value: mostImproved,
            icon: Icons.trending_up_rounded,
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
  });

  final String label;
  final String value;
  final IconData icon;

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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
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
                  fontSize: 13,
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

class _StreamComparisonCard extends StatelessWidget {
  const _StreamComparisonCard({required this.stats});

  final StreamStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────
          Row(
            children: [
              Text(
                stats.streamName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${stats.studentCount} student${stats.studentCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Stats grid (2 columns × 3 rows) ───────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Overall Avg',
                  value: _fmtPercent(stats.averageScore),
                  percent: stats.averageScore / 100.0,
                  barColor: _percentColor(stats.averageScore),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCell(
                  label: 'Last Exam',
                  value: stats.lastExamAverage != null
                      ? _fmtPercent(stats.lastExamAverage!)
                      : '—',
                  percent: stats.lastExamAverage != null
                      ? stats.lastExamAverage! / 100.0
                      : null,
                  barColor: stats.lastExamAverage != null
                      ? _percentColor(stats.lastExamAverage!)
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
                  value: stats.attendanceRate != null
                      ? _fmtPercent(stats.attendanceRate!)
                      : '—',
                  percent: stats.attendanceRate != null
                      ? stats.attendanceRate! / 100.0
                      : null,
                  barColor: stats.attendanceRate != null
                      ? _percentColor(stats.attendanceRate!)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCell(
                  label: 'Mastery',
                  value: stats.masteryAverage != null
                      ? _fmtPercent(stats.masteryAverage!)
                      : '—',
                  percent: stats.masteryAverage != null
                      ? stats.masteryAverage! / 100.0
                      : null,
                  barColor: stats.masteryAverage != null
                      ? _percentColor(stats.masteryAverage!)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _TrajectoryCell(trajectory: stats.trajectory)),
              const Spacer(),
            ],
          ),
        ],
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
              height: 6,
              child: LinearProgressIndicator(
                value: percent!.clamp(0.0, 1.0),
                backgroundColor: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
                    : cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor!),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trajectory Cell — icon + label for stream trajectory
// ─────────────────────────────────────────────────────────────────────────────

class _TrajectoryCell extends StatelessWidget {
  const _TrajectoryCell({required this.trajectory});

  final Trajectory trajectory;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trajectory',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ],
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
        duration: const Duration(milliseconds: 200),
      );
    });
    _fadeAnimations = _controllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOut);
    }).toList();
    _slideAnimations = _controllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();
  }

  Future<void> _startStaggered() async {
    for (int i = 0; i < _controllers.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 50));
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
          child: Text(
            'Stream Ranking',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // Table container
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
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
                      width: 32,
                      child: Text('#', style: _headerStyle(cs)),
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
                      isTopRanked: i == 0,
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

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.stats,
    required this.isAlternate,
    this.isTopRanked = false,
  });

  final int rank;
  final StreamStats stats;
  final bool isAlternate;
  final bool isTopRanked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Gold tint for the #1 ranked stream.
    final Color bgColor;
    if (isTopRanked) {
      bgColor = isDark
          ? const Color(0xFFFFA726).withValues(alpha: 0.08)
          : const Color(0xFFFFA726).withValues(alpha: 0.06);
    } else if (isAlternate) {
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

    final (IconData tIcon, Color tColor) = switch (stats.trajectory) {
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

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              stats.streamName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${stats.studentCount}',
              style: valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              stats.lastExamAverage != null
                  ? _fmtPercent(stats.lastExamAverage!)
                  : '—',
              style: valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              _fmtPercent(stats.averageScore),
              style: valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 24, child: Icon(tIcon, size: 16, color: tColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// 4. Performance Trend
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
        Text(
          'Performance Trend',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            letterSpacing: 0.3,
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
        borderRadius: BorderRadius.circular(6),
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
    // Collect all unique labels in order.
    final allLabels = <String>[];
    for (final pts in trendData.values) {
      for (final p in pts) {
        if (!allLabels.contains(p.label)) {
          allLabels.add(p.label);
        }
      }
    }

    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _TrendChartPainter(
                cs: cs,
                trendData: trendData,
                streams: streams,
                labels: allLabels,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend.
          Wrap(
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
          width: 8,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
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

// ─── Trend Chart Painter ─────────────────────────────────────────────────────

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.cs,
    required this.trendData,
    required this.streams,
    required this.labels,
  });

  final ColorScheme cs;
  final Map<int, List<({String label, double percent})>> trendData;
  final List<GradeStream> streams;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.length < 2) return;

    const double leftPad = 32; // space for Y-axis labels
    const double bottomPad = 22; // space for X-axis labels
    const double topPad = 8;
    const double rightPad = 8;

    final chartLeft = leftPad;
    final chartRight = size.width - rightPad;
    final chartTop = topPad;
    final chartBottom = size.height - bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // ── Grid lines & Y-axis labels ──
    final gridPaint = Paint()
      ..color = cs.outline.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    final yLabelStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
    );

    for (int pct = 0; pct <= 100; pct += 25) {
      final y = chartBottom - (pct / 100) * chartHeight;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      // Y-axis label.
      final tp = TextPainter(
        text: TextSpan(text: '$pct', style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - tp.height / 2));
    }

    // ── X-axis labels ──
    final xLabelStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
    );

    final xStep = labels.length > 1
        ? chartWidth / (labels.length - 1)
        : chartWidth;

    for (int i = 0; i < labels.length; i++) {
      final x = chartLeft + i * xStep;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: xLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 6));
    }

    // ── Draw lines and dots per stream ──
    for (final s in streams) {
      final points = trendData[s.code];
      if (points == null || points.length < 2) continue;

      final color = _streamColor(s.code);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Map each point to a canvas position based on its label index.
      final offsets = <Offset>[];
      for (final p in points) {
        final labelIdx = labels.indexOf(p.label);
        if (labelIdx < 0) continue;
        final x = chartLeft + labelIdx * xStep;
        final y = chartBottom - (p.percent.clamp(0, 100) / 100) * chartHeight;
        offsets.add(Offset(x, y));
      }

      if (offsets.length < 2) continue;

      // Draw connecting lines.
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        path.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(path, linePaint);

      // Draw dots.
      for (final o in offsets) {
        canvas.drawCircle(o, 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.trendData != trendData ||
        oldDelegate.labels != labels ||
        oldDelegate.streams != streams ||
        oldDelegate.cs != cs;
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
