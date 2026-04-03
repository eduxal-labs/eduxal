import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../models/system_permissions.dart';
import '../../../../models/system_stats.dart';
import '../../../theme/app_theme.dart';

/// The stats/home section of the system dashboard.
///
/// Displays 6 stat cards with stacked segmented bar charts representing
/// status breakdowns. On desktop, cards are always visible in a responsive
/// single-row grid (wraps to multi-row only when truly needed). On mobile,
/// shows a 2-column grid of full-width cards.
class SystemStatsSection extends StatelessWidget {
  const SystemStatsSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTheme.kMobileBreakpoint;

    return _StatsCardGrid(permissions: permissions, isDesktop: isDesktop);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main grid widget — each stat card subscribes to its own stream independently
// so that a single failed query does NOT hide all other working stats.
// ─────────────────────────────────────────────────────────────────────────────

class _StatsCardGrid extends StatelessWidget {
  const _StatsCardGrid({required this.permissions, required this.isDesktop});

  final SystemPermissions permissions;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final canSeeDeleted = permissions.canSeeDeleted;

    // Each card is an independent StreamBuilder — errors are isolated.
    final cardWidgets = <Widget>[
      _IndependentStatCard<UserStats>(
        stream: systemStatsDao.watchUserStats(),
        isDesktop: isDesktop,
        builder: (stats) => _buildUserCard(stats, canSeeDeleted),
      ),
      _IndependentStatCard<SchoolStats>(
        stream: systemStatsDao.watchSchoolStats(),
        isDesktop: isDesktop,
        builder: (stats) => _buildSchoolCard(stats, canSeeDeleted),
      ),
      _IndependentStatCard<StudentStats>(
        stream: systemStatsDao.watchStudentStats(),
        isDesktop: isDesktop,
        builder: (stats) => _buildStudentCard(stats),
      ),
      _IndependentStatCard<TeacherStats>(
        stream: systemStatsDao.watchTeacherStats(),
        isDesktop: isDesktop,
        builder: (stats) => _buildTeacherCard(stats),
      ),
      _IndependentStatCard<SubscriptionStats>(
        stream: systemStatsDao.watchSubscriptionStats(),
        isDesktop: isDesktop,
        builder: (stats) => _buildSubscriptionCard(stats, canSeeDeleted),
      ),
      _IndependentStatCard<RevenueStats>(
        stream: systemStatsDao.watchRevenueStats(),
        isDesktop: isDesktop,
        builder: (stats) => _buildRevenueCard(stats),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 16.0 * 2;
        const gap = 8.0;
        final avail = constraints.maxWidth - hPad;
        final cols = isDesktop
            ? (avail >= 660
                  ? 6
                  : avail >= 420
                  ? 3
                  : 2)
            : (avail >= 320 ? 2 : 1);
        final cardWidth = cols == 1 ? avail : (avail - gap * (cols - 1)) / cols;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cardWidgets)
                SizedBox(width: cardWidth, child: card),
            ],
          ),
        );
      },
    );
  }

  // ── Card builders ──────────────────────────────────────────────────────────

  static _StatCardData _buildUserCard(UserStats stats, bool canSeeDeleted) {
    final segments = <_BarSegment>[
      _BarSegment('Invited', stats.invited, _kColorInvited),
      _BarSegment('Active', stats.active, _kColorActive),
      _BarSegment('Suspended', stats.suspended, _kColorSuspended),
      if (canSeeDeleted) _BarSegment('Deleted', stats.deleted, _kColorDeleted),
    ];

    final parts = <String>[];
    if (stats.active > 0) parts.add('${stats.active} active');
    if (stats.invited > 0) parts.add('${stats.invited} invited');
    if (stats.suspended > 0) parts.add('${stats.suspended} suspended');

    return _StatCardData(
      icon: Icons.people_outline,
      label: 'Users',
      total: _formatCount(stats.total),
      totalRaw: stats.total,
      subtitle: parts.isEmpty ? 'No users' : parts.join(', '),
      segments: segments,
    );
  }

  static _StatCardData _buildSchoolCard(SchoolStats stats, bool canSeeDeleted) {
    final segments = <_BarSegment>[
      _BarSegment('Trial', stats.trial, _kColorTrial),
      _BarSegment('Active', stats.active, _kColorActive),
      _BarSegment('Cancelled', stats.cancelled, _kColorCancelled),
      _BarSegment('Suspended', stats.suspended, _kColorSuspended),
      if (canSeeDeleted) _BarSegment('Deleted', stats.deleted, _kColorDeleted),
    ];

    final parts = <String>[];
    if (stats.active > 0) parts.add('${stats.active} active');
    if (stats.trial > 0) parts.add('${stats.trial} trial');
    if (stats.suspended > 0) parts.add('${stats.suspended} suspended');

    return _StatCardData(
      icon: Icons.school_outlined,
      label: 'Schools',
      total: _formatCount(stats.total),
      totalRaw: stats.total,
      subtitle: parts.isEmpty ? 'No schools' : parts.join(', '),
      segments: segments,
    );
  }

  static _StatCardData _buildStudentCard(StudentStats stats) {
    final segments = <_BarSegment>[
      _BarSegment('Active', stats.active, _kColorActive),
      _BarSegment('Graduated', stats.graduated, _kColorTrial),
      _BarSegment('Transferred', stats.transferred, _kColorInvited),
      _BarSegment('Expelled', stats.expelled, _kColorDeleted),
      _BarSegment('Withdrawn', stats.withdrawn, _kColorSuspended),
      _BarSegment('Deleted', stats.deleted, _kColorCancelled),
    ];

    return _StatCardData(
      icon: Icons.badge_outlined,
      label: 'Students',
      total: _formatCount(stats.total),
      totalRaw: stats.total,
      subtitle: stats.subtitle,
      segments: segments,
      termLabel: stats.currentTerm?.label,
    );
  }

  static _StatCardData _buildTeacherCard(TeacherStats stats) {
    final segments = <_BarSegment>[
      _BarSegment('Active', stats.active, _kColorActive),
      _BarSegment('Resigned', stats.resigned, _kColorCancelled),
      _BarSegment('Transferred', stats.transferred, _kColorInvited),
      _BarSegment('Fired', stats.fired, _kColorDeleted),
      _BarSegment('Retired', stats.retired, _kColorSuspended),
    ];

    return _StatCardData(
      icon: Icons.assignment_ind_outlined,
      label: 'Teachers',
      total: _formatCount(stats.total),
      totalRaw: stats.total,
      subtitle: stats.subtitle,
      segments: segments,
    );
  }

  static _StatCardData _buildSubscriptionCard(
    SubscriptionStats stats,
    bool canSeeDeleted,
  ) {
    final segments = <_BarSegment>[
      _BarSegment('Pending', stats.pending, _kColorInvited),
      _BarSegment('Active', stats.active, _kColorActive),
      _BarSegment('Cancelled', stats.cancelled, _kColorCancelled),
      if (canSeeDeleted) _BarSegment('Deleted', stats.deleted, _kColorDeleted),
    ];

    return _StatCardData(
      icon: Icons.card_membership_outlined,
      label: 'Subscriptions',
      total: _formatCount(stats.total),
      totalRaw: stats.total,
      subtitle: stats.subtitle,
      segments: segments,
      termLabel: stats.currentTerm?.label,
    );
  }

  static _StatCardData _buildRevenueCard(RevenueStats stats) {
    // Cycle through available colors for dynamic plan segments.
    const planColors = [
      _kColorActive,
      _kColorTrial,
      _kColorInvited,
      _kColorSuspended,
      _kColorCancelled,
      _kColorDeleted,
    ];
    final segments = <_BarSegment>[
      for (var i = 0; i < stats.perPlan.length; i++)
        _BarSegment(
          stats.perPlan[i].planName,
          stats.perPlan[i].amount.round(),
          planColors[i % planColors.length],
        ),
    ];

    return _StatCardData(
      icon: Icons.payments_outlined,
      label: 'Revenue',
      total: _formatAmount(stats.totalAmount),
      totalRaw: stats.totalCount,
      subtitle: stats.subtitle,
      segments: segments,
      termLabel: stats.currentTerm?.label,
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  static String _formatAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Independent stat card — each subscribes to its own stream so a single
// failed query only affects that one card, not the entire dashboard.
// ─────────────────────────────────────────────────────────────────────────────

class _IndependentStatCard<T> extends StatelessWidget {
  const _IndependentStatCard({
    super.key,
    required this.stream,
    required this.isDesktop,
    required this.builder,
  });

  final Stream<T> stream;
  final bool isDesktop;
  final _StatCardData Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SingleCardError(
            isDesktop: isDesktop,
            error: snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return _SingleCardSkeleton(isDesktop: isDesktop);
        }

        final data = builder(snapshot.data as T);
        return _StatCard(data: data, isDesktop: isDesktop);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardData {
  const _StatCardData({
    required this.icon,
    required this.label,
    required this.total,
    required this.totalRaw,
    required this.subtitle,
    required this.segments,
    this.termLabel,
  });

  final IconData icon;
  final String label;
  final String total;
  final int totalRaw;
  final String subtitle;
  final List<_BarSegment> segments;

  /// If non-null, shown as a muted badge next to the card label, e.g. "T1 2025".
  /// Only present on term-scoped cards (students, subscriptions, revenue).
  final String? termLabel;
}

class _BarSegment {
  const _BarSegment(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data, required this.isDesktop});

  final _StatCardData data;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Total for proportion = sum of ALL segment values.
    final total = data.segments.fold<int>(0, (s, seg) => s + seg.value);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: icon + label + optional term badge ────────────────
          Row(
            children: [
              Icon(
                data.icon,
                size: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.termLabel != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    data.termLabel!,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                      color: cs.primary.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // ── Body: number+subtitle left, bars right ────────────────────
          // LayoutBuilder so the bar cluster can scale with card width.
          LayoutBuilder(
            builder: (context, bodyConstraints) {
              final n = data.segments.length;
              // Scale bar width and gap to fill card width gracefully.
              // Each bar is at least 7px wide; we allocate up to 40% of
              // the available width to the cluster, distributed evenly.
              final availW = bodyConstraints.maxWidth;
              // Cluster may use at most 45% of the card width.
              final maxClusterW = availW * 0.45;
              const minBarW = 7.0;
              const maxBarW = 12.0;
              const minGap = 3.0;
              const maxGap = 6.0;
              // Start with max and clamp down to fit.
              double barW = maxBarW;
              double barGap = maxGap;
              // Shrink until cluster fits within maxClusterW.
              double clusterW = barW * n + barGap * (n - 1);
              if (clusterW > maxClusterW) {
                // Try shrinking gap first, then bar width.
                barGap = minGap;
                clusterW = barW * n + barGap * (n - 1);
                if (clusterW > maxClusterW) {
                  barW = math.max(
                    minBarW,
                    (maxClusterW - barGap * (n - 1)) / n,
                  );
                }
              }
              final barH = 48.0;
              const labelH = 12.0;
              const gapBetween = 6.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left: number + subtitle — fills remaining width
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.total,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurface,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: gapBetween),
                  // Right: bar cluster — scaled to card width
                  _SegmentedBarChart(
                    segments: data.segments,
                    total: total,
                    isDesktop: isDesktop,
                    barHeight: barH,
                    barWidth: barW,
                    barGap: barGap,
                    labelHeight: labelH,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented bar chart — a row of vertical bars, one per segment.
//
// Layout (top to bottom inside the Expanded area):
//   • Bar column  — fills all remaining height after the label row
//   • Label row   — fixed 14 px, one short label per bar
//
// Shading model — "stacked offset":
//   Imagine the full bar height represents 100 % of the total.
//   Bar i is shaded in the band [fillStart, fillEnd] measured from the
//   bottom of the bar, where fillStart = cumulative fraction before bar i
//   and fillEnd = cumulative fraction including bar i.
//   So bar 0 is shaded near the bottom, bar 1 just above it, etc.
//   Zero-value bars show only the track colour (no shading).
//
// Interaction:
//   Desktop — hover shows a tooltip bubble with label + value.
//   Mobile  — tap shows it for 2 s then auto-dismisses.
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedBarChart extends StatefulWidget {
  const _SegmentedBarChart({
    required this.segments,
    required this.total,
    required this.isDesktop,
    required this.barHeight,
    required this.barWidth,
    required this.barGap,
    required this.labelHeight,
    this.aboveLabelHeight = 22.0, // ignore: unused_element_parameter
  });

  final List<_BarSegment> segments;
  final int total;
  final bool isDesktop;
  final double barHeight;
  final double barWidth;
  final double barGap;
  final double labelHeight;
  final double aboveLabelHeight;

  @override
  State<_SegmentedBarChart> createState() => _SegmentedBarChartState();
}

class _SegmentedBarChartState extends State<_SegmentedBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  // Index of bar currently hovered/tapped (-1 = none, shows total on label).
  int _activeIndex = -1;

  // Timer for mobile tap auto-dismiss.
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _onHoverEnter(int index) {
    if (!widget.isDesktop) return;
    setState(() => _activeIndex = index);
  }

  void _onHoverExit() {
    if (!widget.isDesktop) return;
    setState(() => _activeIndex = -1);
  }

  void _onTap(int index) {
    if (widget.isDesktop) return;
    _dismissTimer?.cancel();
    // Tapping the already-active bar dismisses it immediately.
    if (_activeIndex == index) {
      setState(() => _activeIndex = -1);
      return;
    }
    setState(() => _activeIndex = index);
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _activeIndex = -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Track colour — clearly visible on both light and dark.
    final trackColor = cs.brightness == Brightness.light
        ? const Color(0xFFE8E6E1)
        : cs.surfaceContainerHighest.withValues(alpha: 0.9);

    final segments = widget.segments;
    final total = widget.total;
    final n = segments.length;
    if (n == 0) return const SizedBox.shrink();

    // ── Stacked-offset fill fractions ────────────────────────────────────
    // fillStart[i] = cumulative fraction of total BEFORE bar i (bottom edge
    //   of this bar's shaded band, as a fraction of bar height 0.0–1.0).
    // fillEnd[i]   = cumulative fraction INCLUDING bar i (top edge).
    double cum = 0.0;
    final fillStart = <double>[];
    final fillEnd = <double>[];
    for (final seg in segments) {
      final frac = total > 0 ? seg.value / total : 0.0;
      fillStart.add(cum);
      fillEnd.add(math.min(1.0, cum + frac));
      cum = math.min(1.0, cum + frac);
    }

    final barHeight = widget.barHeight;
    final barWidth = widget.barWidth;
    final barGap = widget.barGap;
    final labelHeight = widget.labelHeight;
    final aboveLabelHeight = widget.aboveLabelHeight;
    final barRadius = barWidth / 2; // full pill ends
    final spacing = barWidth + barGap;
    // Total rendered width of the cluster — intrinsic, not stretched.
    final clusterWidth = barWidth * n + barGap * (n - 1);

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return SizedBox(
          width: clusterWidth,
          height: aboveLabelHeight + barHeight + labelHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Shared active-segment label ────────────────────────────
              // A single line spanning the full cluster width that shows
              // "Status  value" when any bar is hovered/tapped. The text
              // is left-aligned, coloured with the active segment's colour,
              // and ellipsised if the cluster is very narrow.
              SizedBox(
                height: aboveLabelHeight,
                width: clusterWidth,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _buildSharedLabel(cs, segments),
                ),
              ),
              // ── Bar area ───────────────────────────────────────────────
              SizedBox(
                width: clusterWidth,
                height: barHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < n; i++)
                      _buildBar(
                        context: context,
                        cs: cs,
                        index: i,
                        seg: segments[i],
                        trackColor: trackColor,
                        barWidth: barWidth,
                        barRadius: barRadius,
                        barHeight: barHeight,
                        bandStart: fillStart[i],
                        bandEnd: fillEnd[i],
                        progress: _progress.value,
                        xOffset: i * spacing,
                        clusterWidth: clusterWidth,
                      ),
                  ],
                ),
              ),
              // ── Below-bar abbreviation label row ──────────────────────
              SizedBox(
                height: labelHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      SizedBox(
                        width: barWidth,
                        child: _buildLabel(cs, i, segments[i]),
                      ),
                      if (i < n - 1) SizedBox(width: barGap),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Single shared label above the whole cluster.
  /// Shows "Status  value" in the active segment's colour while any bar is
  /// hovered/tapped; invisible (zero-opacity) otherwise so layout is stable.
  Widget _buildSharedLabel(ColorScheme cs, List<_BarSegment> segments) {
    final active = _activeIndex >= 0 && _activeIndex < segments.length
        ? segments[_activeIndex]
        : null;

    final visible = active != null && active.value > 0;

    // Use AnimatedOpacity instead of AnimatedSwitcher to avoid duplicate-key
    // errors that occur when rapid hover/tap cycles cause the switcher's
    // internal transition Stack to hold multiple outgoing children with the
    // same key.
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: visible
          ? Text(
              '${active.label}  ${active.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: active.color,
                height: 1.0,
                letterSpacing: 0.1,
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Short abbreviation label beneath bar i — always shows the first letter
  /// of the segment name so the bars are identifiable at a glance.
  Widget _buildLabel(ColorScheme cs, int i, _BarSegment seg) {
    final isActive = _activeIndex == i;
    final color = isActive
        ? seg.color
        : cs.onSurfaceVariant.withValues(alpha: 0.5);

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.0,
      ),
      child: Text(seg.label[0], textAlign: TextAlign.center, maxLines: 1),
    );
  }

  Widget _buildBar({
    required BuildContext context,
    required ColorScheme cs,
    required int index,
    required _BarSegment seg,
    required Color trackColor,
    required double barWidth,
    required double barRadius,
    required double barHeight,
    // Fraction of bar height where shading STARTS (from bottom), 0.0–1.0.
    required double bandStart,
    // Fraction of bar height where shading ENDS (from bottom), 0.0–1.0.
    required double bandEnd,
    required double progress,
    required double xOffset,
    required double clusterWidth,
  }) {
    final isActive = _activeIndex == index;
    final hasValue = seg.value > 0;

    // Animate: the band grows from bandStart upward toward bandEnd.
    final animatedBandEnd = bandStart + (bandEnd - bandStart) * progress;

    // Pixel positions from the bottom of the bar.
    final bottomPx = barHeight * bandStart;
    final topPx = barHeight * animatedBandEnd;
    final bandHeightPx = (topPx - bottomPx).clamp(0.0, barHeight);

    // Slight brightness boost on hover/tap to give feedback.
    final barColor = isActive && hasValue
        ? Color.lerp(seg.color, Colors.white, 0.15)!
        : seg.color;

    final bar = SizedBox(
      width: barWidth,
      height: barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(barRadius),
        child: Stack(
          children: [
            // Full-height track.
            Positioned.fill(child: Container(color: trackColor)),
            // Shaded band — sits at its proportional position within the bar.
            if (hasValue && bandHeightPx > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomPx,
                height: bandHeightPx,
                child: Container(color: barColor),
              ),
          ],
        ),
      ),
    );

    if (widget.isDesktop) {
      return Positioned(
        left: xOffset,
        top: 0,
        bottom: 0,
        width: barWidth,
        child: MouseRegion(
          onEnter: (_) => _onHoverEnter(index),
          onExit: (_) => _onHoverExit(),
          cursor: SystemMouseCursors.basic,
          child: bar,
        ),
      );
    }

    return Positioned(
      left: xOffset,
      top: 0,
      bottom: 0,
      width: barWidth,
      child: GestureDetector(
        onTap: () => _onTap(index),
        behavior: HitTestBehavior.opaque,
        child: bar,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-card error state — replaces the old all-or-nothing _StatsErrorCard.
// Shows an error icon with tooltip inside a card-shaped container so the
// grid layout is preserved even when individual queries fail.
// ─────────────────────────────────────────────────────────────────────────────

class _SingleCardError extends StatelessWidget {
  const _SingleCardError({required this.isDesktop, required this.error});

  final bool isDesktop;
  final String error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Tooltip(
            message: error,
            child: Icon(
              Icons.error_outline_rounded,
              size: 22,
              color: cs.error.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Failed to load',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-card skeleton — shown while an individual stream is still loading.
// Matches the card shape so the grid stays stable.
// ─────────────────────────────────────────────────────────────────────────────

class _SingleCardSkeleton extends StatefulWidget {
  const _SingleCardSkeleton({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_SingleCardSkeleton> createState() => _SingleCardSkeletonState();
}

class _SingleCardSkeletonState extends State<_SingleCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final shimmerColor = Color.lerp(
          cs.surfaceContainerHighest,
          cs.surfaceContainer,
          _shimmer.value,
        )!;

        return _buildSkeletonCard(cs, isDark, shimmerColor);
      },
    );
  }

  Widget _buildSkeletonCard(ColorScheme cs, bool isDark, Color shimmerColor) {
    // Mirror the fixed bar dimensions from _StatCard.
    const double barH = 56.0;
    const double barW = 9.0;
    const double barGap = 5.0;
    const double labelH = 13.0;
    const int barCount = 4;
    final double clusterW = barW * barCount + barGap * (barCount - 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: isDark ? cs.outline.withValues(alpha: 0.5) : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header placeholder ────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 44,
                height: 9,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Body row: number+subtitle left, bars right ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: number + subtitle placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 18,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 56,
                      height: 7,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Right: bar cluster placeholder
              SizedBox(
                width: clusterW,
                height: barH + 3 + labelH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bars
                    SizedBox(
                      height: barH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(barCount, (i) {
                          return Padding(
                            padding: EdgeInsets.only(
                              right: i < barCount - 1 ? barGap : 0.0,
                            ),
                            child: Container(
                              width: barW,
                              decoration: BoxDecoration(
                                color: shimmerColor,
                                borderRadius: BorderRadius.circular(barW / 2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Label row
                    Row(
                      children: List.generate(barCount, (i) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: i < barCount - 1 ? barGap : 0.0,
                          ),
                          child: Container(
                            width: barW,
                            height: 7,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
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
// Colour palette
// ─────────────────────────────────────────────────────────────────────────────

const _kColorInvited = Color(0xFF7986CB); // indigo-300
const _kColorActive = Color(0xFF26A69A); // teal-400
const _kColorSuspended = Color(0xFFFFB300); // amber
const _kColorDeleted = Color(0xFFEF5350); // red
const _kColorTrial = Color(0xFF42A5F5); // blue-400
const _kColorCancelled = Color(0xFFBDBDBD); // grey
