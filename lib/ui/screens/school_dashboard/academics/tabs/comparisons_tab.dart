import 'dart:math' as math;

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
/// 1. A wrapping summary row of compact stat cards.
/// 2. Responsive stream cards (compact on mobile, donut charts on desktop).
/// 3. A ranking table with podium (when 2+ streams exist).
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

        // ── 2. Stream comparison cards (responsive) ──────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 600;
            return Wrap(
              spacing: isDesktop ? 10 : 8,
              runSpacing: isDesktop ? 10 : 8,
              children: stats.map((s) {
                if (isDesktop) {
                  return _StreamDonutCard(
                    stats: s,
                    availableWidth: constraints.maxWidth,
                    streamCount: stats.length,
                  );
                }
                return _CompactStreamCard(
                  stats: s,
                  availableWidth: constraints.maxWidth,
                  streamCount: stats.length,
                );
              }).toList(),
            );
          },
        ),

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
// Summary Row — wrapping row of compact stat cards (Task A1)
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
          child: _SummaryCard(
            label: 'Total Students',
            value: '$totalStudents',
            icon: Icons.people_outline_rounded,
            accentColor: const Color(0xFF42A5F5),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
          child: _SummaryCard(
            label: 'Streams',
            value: '$streamCount',
            icon: Icons.view_stream_outlined,
            accentColor: const Color(0xFF26A69A),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
          child: _SummaryCard(
            label: 'Best Performing',
            value: bestPerforming,
            icon: Icons.emoji_events_outlined,
            accentColor: const Color(0xFFFFA726),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 180),
          child: _SummaryCard(
            label: 'Most Improved',
            value: mostImproved,
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF66BB6A),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            width: 28,
            height: 28,
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
            child: Icon(icon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
// Compact Stream Card — mobile layout (Task A2)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactStreamCard extends StatelessWidget {
  const _CompactStreamCard({
    required this.stats,
    required this.availableWidth,
    required this.streamCount,
  });

  final StreamStats stats;
  final double availableWidth;
  final int streamCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final streamColor = _streamColor(stats.streamCode);

    final cols = math.max(streamCount, 3).clamp(3, 4);
    final spacing = 8.0;
    final cardWidth = (availableWidth - (spacing * (cols - 1))) / cols;

    return SizedBox(
      width: cardWidth,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [streamColor, streamColor.withValues(alpha: 0.4)],
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stream name with dot
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: streamColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              stats.streamName,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Students badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
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
                          '${stats.studentCount} student${stats.studentCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            color: streamColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 4 stat rows
                      _compactStatRow(
                        'Avg',
                        _fmtPercent(stats.averageScore),
                        _percentColor(stats.averageScore),
                        cs,
                      ),
                      const SizedBox(height: 3),
                      _compactStatRow(
                        'Last',
                        stats.lastExamAverage != null
                            ? _fmtPercent(stats.lastExamAverage!)
                            : '—',
                        stats.lastExamAverage != null
                            ? _percentColor(stats.lastExamAverage!)
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        cs,
                      ),
                      const SizedBox(height: 3),
                      _compactStatRow(
                        'Att',
                        stats.attendanceRate != null
                            ? _fmtPercent(stats.attendanceRate!)
                            : '—',
                        stats.attendanceRate != null
                            ? _percentColor(stats.attendanceRate!)
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        cs,
                      ),
                      const SizedBox(height: 3),
                      _compactStatRow(
                        'Mastery',
                        stats.masteryAverage != null
                            ? _fmtPercent(stats.masteryAverage!)
                            : '—',
                        stats.masteryAverage != null
                            ? _percentColor(stats.masteryAverage!)
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        cs,
                      ),
                      const SizedBox(height: 6),
                      // Trajectory badge
                      _TrajectoryBadge(trajectory: stats.trajectory),
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

  Widget _compactStatRow(
    String label,
    String value,
    Color valueColor,
    ColorScheme cs,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream Donut Card — desktop layout (Task A2)
// ─────────────────────────────────────────────────────────────────────────────

class _StreamDonutCard extends StatelessWidget {
  const _StreamDonutCard({
    required this.stats,
    required this.availableWidth,
    required this.streamCount,
  });

  final StreamStats stats;
  final double availableWidth;
  final int streamCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final streamColor = _streamColor(stats.streamCode);

    final cols = math.max(streamCount, 3).clamp(3, 5);
    final spacing = 10.0;
    final cardWidth = ((availableWidth - (spacing * (cols - 1))) / cols).clamp(
      160.0,
      260.0,
    );

    const attendanceColor = Color(0xFF42A5F5);
    const lastExamColor = Color(0xFFFFA726);
    final averageColor = _percentColor(stats.averageScore);

    return SizedBox(
      width: cardWidth,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [streamColor, streamColor.withValues(alpha: 0.4)],
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: Column(
                    children: [
                      // Triple-ring donut chart
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(90, 90),
                              painter: _TripleDonutPainter(
                                averagePercent: stats.averageScore,
                                attendancePercent: stats.attendanceRate,
                                lastExamPercent: stats.lastExamAverage,
                                averageColor: averageColor,
                                attendanceColor: attendanceColor,
                                lastExamColor: lastExamColor,
                                trackColor: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            // Center text
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stats.streamName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${stats.studentCount}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Legend row
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          _donutLegendItem(averageColor, 'Average', cs),
                          _donutLegendItem(attendanceColor, 'Attendance', cs),
                          _donutLegendItem(lastExamColor, 'Last Exam', cs),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Trajectory badge
                      _TrajectoryBadge(trajectory: stats.trajectory),
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

  Widget _donutLegendItem(Color color, String label, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Triple Donut Painter (Task A2)
// ─────────────────────────────────────────────────────────────────────────────

class _TripleDonutPainter extends CustomPainter {
  _TripleDonutPainter({
    required this.averagePercent,
    required this.attendancePercent,
    required this.lastExamPercent,
    required this.averageColor,
    required this.attendanceColor,
    required this.lastExamColor,
    required this.trackColor,
  });

  final double averagePercent;
  final double? attendancePercent;
  final double? lastExamPercent;
  final Color averageColor;
  final Color attendanceColor;
  final Color lastExamColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const outerStroke = 8.0;
    const middleStroke = 6.0;
    const innerStroke = 4.0;
    const gap = 3.0;

    final outerRadius = size.width / 2 - outerStroke / 2;
    final middleRadius = outerRadius - outerStroke / 2 - gap - middleStroke / 2;
    final innerRadius = middleRadius - middleStroke / 2 - gap - innerStroke / 2;
    const startAngle = -math.pi / 2;

    void drawRing(double radius, double stroke, double? percent, Color color) {
      // Track
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = trackColor,
      );
      // Filled arc
      if (percent != null && percent > 0) {
        final sweep = (percent.clamp(0, 100) / 100) * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
    }

    drawRing(outerRadius, outerStroke, averagePercent, averageColor);
    drawRing(middleRadius, middleStroke, attendancePercent, attendanceColor);
    drawRing(innerRadius, innerStroke, lastExamPercent, lastExamColor);
  }

  @override
  bool shouldRepaint(covariant _TripleDonutPainter old) =>
      averagePercent != old.averagePercent ||
      attendancePercent != old.attendancePercent ||
      lastExamPercent != old.lastExamPercent;
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
// Podium Section — visual top-3 display (Task A3)
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.topThree, required this.ranks});

  /// Already sorted by rank. Max length 3.
  final List<StreamStats> topThree;

  /// Tie-aware ranks corresponding to [topThree]. Same length.
  final List<int> ranks;

  static const _goldColor = Color(0xFFFFD700);
  static const _silverColor = Color(0xFFC0C0C0);
  static const _bronzeColor = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Reorder for visual podium: [2nd, 1st, 3rd]
    // Use tie-aware ranks and medal colors based on rank value.
    Color _medalColor(int rank) {
      if (rank == 1) return _goldColor;
      if (rank == 2) return _silverColor;
      return _bronzeColor;
    }

    double _podiumHeight(int rank) {
      if (rank == 1) return 56;
      if (rank == 2) return 40;
      return 28;
    }

    final ordered = <(StreamStats, int, Color, double)>[];
    if (topThree.length >= 2) {
      final r = ranks[1];
      ordered.add((topThree[1], r, _medalColor(r), _podiumHeight(r)));
    }
    {
      final r = ranks[0];
      ordered.add((topThree[0], r, _medalColor(r), _podiumHeight(r)));
    }
    if (topThree.length >= 3) {
      final r = ranks[2];
      ordered.add((topThree[2], r, _medalColor(r), _podiumHeight(r)));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: AppTheme.borderColor(
            isDark,
            cs,
          ).withValues(alpha: isDark ? 0.4 : 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _buildPodiumItem(
                ordered[i].$1,
                ordered[i].$2,
                ordered[i].$3,
                ordered[i].$4,
                cs,
                isDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
    StreamStats stats,
    int rank,
    Color medalColor,
    double podiumHeight,
    ColorScheme cs,
    bool isDark,
  ) {
    final displayScore = stats.averageScore;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal icon
        Icon(Icons.emoji_events_rounded, size: 22, color: medalColor),
        const SizedBox(height: 4),
        // Stream color dot + name
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _streamColor(stats.streamCode),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                stats.streamName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Average percentage
        Text(
          _fmtPercent(displayScore),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _percentColor(displayScore),
          ),
        ),
        const SizedBox(height: 6),
        // Podium bar
        Container(
          height: podiumHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            border: Border(
              top: BorderSide(
                color: medalColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ranking Table — compact table ranking streams by lastExamAverage desc
// (Task A3: + podium, divider, mobile responsiveness)
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

    // Sort by averageScore descending.
    final ranked = List<StreamStats>.from(widget.stats)
      ..sort((a, b) {
        return b.averageScore.compareTo(a.averageScore);
      });

    // Compute tie-aware ranks (competition ranking — RANK() style)
    final ranks = <int>[];
    int currentRank = 1;
    for (int i = 0; i < ranked.length; i++) {
      if (i > 0 && ranked[i].averageScore < ranked[i - 1].averageScore) {
        currentRank = i + 1;
      }
      ranks.add(currentRank);
    }

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

        // Podium section (top 3)
        if (ranked.length >= 3)
          _PodiumSection(
            topThree: ranked.take(3).toList(),
            ranks: ranks.take(3).toList(),
          ),

        // Table container — responsive
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    border: Border.all(
                      color: AppTheme.borderColor(
                        isDark,
                        cs,
                      ).withValues(alpha: isDark ? 0.6 : 0.5),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Table header ──────────────────────────────
                        Container(
                          color: isDark
                              ? cs.surfaceContainerHighest.withValues(
                                  alpha: 0.4,
                                )
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
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
                              const SizedBox(
                                width: 80,
                                child: SizedBox.shrink(),
                              ),
                              const Spacer(),
                              if (!compact) ...[
                                SizedBox(
                                  width: 52,
                                  child: Text(
                                    'Students',
                                    style: _headerStyle(cs),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              SizedBox(
                                width: 58,
                                child: Text(
                                  'Last Exam',
                                  style: _headerStyle(cs),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 58,
                                  child: Text(
                                    'Overall',
                                    style: _headerStyle(cs),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
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

                        // ── Divider between header and rows ──────────
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppTheme.borderColor(isDark, cs),
                        ),

                        // ── Table rows ────────────────────────────────
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
                                rank: ranks[i],
                                stats: ranked[i],
                                isAlternate: i.isOdd,
                                compact: compact,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
    required this.compact,
  });

  final int rank;
  final StreamStats stats;
  final bool isAlternate;
  final bool compact;

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
            Row(
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  widget.stats.streamName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: rank == 1 ? FontWeight.w500 : FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (!widget.compact) ...[
              SizedBox(
                width: 52,
                child: Text(
                  '${widget.stats.studentCount}',
                  style: valueStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
            ],
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
            if (!widget.compact) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: Text(
                  _fmtPercent(widget.stats.averageScore),
                  style: valueStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
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
                strokeColor: isDark ? cs.surface : Colors.white,
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
                    getTooltipColor: (touchedSpot) =>
                        isDark ? const Color(0xFF1E2A3A) : cs.surface,
                    tooltipBorderRadius: BorderRadius.circular(
                      AppTheme.kChipRadius,
                    ),
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
