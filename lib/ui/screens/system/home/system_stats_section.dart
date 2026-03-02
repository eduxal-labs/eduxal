import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../models/system_permissions.dart';
import '../../../../models/system_stats.dart';
import '../../../theme/app_theme.dart';

/// The stats/home section of the system dashboard.
///
/// Displays 6 stat cards in a responsive grid: Users, Schools, Students,
/// Teachers, Subscriptions, Revenue. Each card shows a prominent total count
/// with small inline vertical bars representing status breakdowns.
///
/// On **mobile**, charts are collapsed by default (numbers + subtitle only).
/// Tapping a card toggles its expanded state to reveal the bars.
///
/// On **desktop**, all cards are always expanded (bars always visible).
///
/// All data comes from [SystemStatsDao] reactive streams.
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
// Main grid widget — subscribes to all 6 streams
// ─────────────────────────────────────────────────────────────────────────────

class _StatsCardGrid extends StatelessWidget {
  const _StatsCardGrid({required this.permissions, required this.isDesktop});

  final SystemPermissions permissions;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserStats>(
      stream: systemStatsDao.watchUserStats(),
      builder: (context, userSnap) {
        return StreamBuilder<SchoolStats>(
          stream: systemStatsDao.watchSchoolStats(),
          builder: (context, schoolSnap) {
            return StreamBuilder<StudentPlanStats>(
              stream: systemStatsDao.watchStudentPlanStats(),
              builder: (context, studentSnap) {
                return StreamBuilder<TeacherStats>(
                  stream: systemStatsDao.watchTeacherStats(),
                  builder: (context, teacherSnap) {
                    return StreamBuilder<SubscriptionStats>(
                      stream: systemStatsDao.watchSubscriptionStats(),
                      builder: (context, subSnap) {
                        return StreamBuilder<RevenueStats>(
                          stream: systemStatsDao.watchRevenueStats(),
                          builder: (context, revSnap) {
                            final allReady =
                                userSnap.hasData &&
                                schoolSnap.hasData &&
                                studentSnap.hasData &&
                                teacherSnap.hasData &&
                                subSnap.hasData &&
                                revSnap.hasData;

                            if (!allReady) {
                              return _CardGridSkeleton(isDesktop: isDesktop);
                            }

                            return _CardGridContent(
                              permissions: permissions,
                              isDesktop: isDesktop,
                              userStats: userSnap.data!,
                              schoolStats: schoolSnap.data!,
                              studentStats: studentSnap.data!,
                              teacherStats: teacherSnap.data!,
                              subscriptionStats: subSnap.data!,
                              revenueStats: revSnap.data!,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid content with the 6 stat cards
// ─────────────────────────────────────────────────────────────────────────────

class _CardGridContent extends StatelessWidget {
  const _CardGridContent({
    required this.permissions,
    required this.isDesktop,
    required this.userStats,
    required this.schoolStats,
    required this.studentStats,
    required this.teacherStats,
    required this.subscriptionStats,
    required this.revenueStats,
  });

  final SystemPermissions permissions;
  final bool isDesktop;
  final UserStats userStats;
  final SchoolStats schoolStats;
  final StudentPlanStats studentStats;
  final TeacherStats teacherStats;
  final SubscriptionStats subscriptionStats;
  final RevenueStats revenueStats;

  @override
  Widget build(BuildContext context) {
    final canSeeDeleted = permissions.canSeeDeleted;

    // ── Build card descriptors ───────────────────────────────────────────────
    final cards = <_StatCardData>[
      _buildUserCard(canSeeDeleted),
      _buildSchoolCard(canSeeDeleted),
      _buildStudentCard(),
      _buildTeacherCard(),
      _buildSubscriptionCard(canSeeDeleted),
      _buildRevenueCard(),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final padding = isDesktop
        ? const EdgeInsets.fromLTRB(24, 20, 24, 20)
        : const EdgeInsets.fromLTRB(16, 16, 16, 24);

    // Determine column count based on width
    final int crossAxisCount;
    if (width < 400) {
      crossAxisCount = 1;
    } else if (width < 700) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    Widget grid = GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Cards adapt height; use a reasonable aspect ratio
        childAspectRatio: isDesktop ? 1.85 : 2.0,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _StatCard(data: cards[index], isDesktop: isDesktop);
      },
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(padding: padding, child: grid),
        ),
      );
    }

    return Padding(padding: padding, child: grid);
  }

  // ── Card builders ──────────────────────────────────────────────────────────

  _StatCardData _buildUserCard(bool canSeeDeleted) {
    final segments = <_BarSegmentData>[
      _BarSegmentData('Invited', userStats.invited, _kColorInvited),
      _BarSegmentData('Active', userStats.active, _kColorActive),
      _BarSegmentData('Suspended', userStats.suspended, _kColorSuspended),
      if (canSeeDeleted)
        _BarSegmentData('Deleted', userStats.deleted, _kColorDeleted),
    ];

    final parts = <String>[];
    if (userStats.active > 0) parts.add('${userStats.active} active');
    if (userStats.invited > 0) parts.add('${userStats.invited} invited');
    if (userStats.suspended > 0) {
      parts.add('${userStats.suspended} suspended');
    }

    return _StatCardData(
      icon: Icons.people_outline,
      label: 'Users',
      total: _formatCount(userStats.total),
      subtitle: parts.isEmpty ? 'No users' : parts.join(', '),
      segments: segments,
    );
  }

  _StatCardData _buildSchoolCard(bool canSeeDeleted) {
    final segments = <_BarSegmentData>[
      _BarSegmentData('Trial', schoolStats.trial, _kColorTrial),
      _BarSegmentData('Active', schoolStats.active, _kColorActive),
      _BarSegmentData('Cancelled', schoolStats.cancelled, _kColorCancelled),
      _BarSegmentData('Suspended', schoolStats.suspended, _kColorSuspended),
      if (canSeeDeleted)
        _BarSegmentData('Deleted', schoolStats.deleted, _kColorDeleted),
    ];

    final parts = <String>[];
    if (schoolStats.active > 0) parts.add('${schoolStats.active} active');
    if (schoolStats.trial > 0) parts.add('${schoolStats.trial} trial');
    if (schoolStats.suspended > 0) {
      parts.add('${schoolStats.suspended} suspended');
    }

    return _StatCardData(
      icon: Icons.school_outlined,
      label: 'Schools',
      total: _formatCount(schoolStats.total),
      subtitle: parts.isEmpty ? 'No schools' : parts.join(', '),
      segments: segments,
    );
  }

  _StatCardData _buildStudentCard() {
    final segments = <_BarSegmentData>[];
    for (var i = 0; i < studentStats.perPlan.length; i++) {
      segments.add(
        _BarSegmentData(
          studentStats.perPlan[i].planName,
          studentStats.perPlan[i].count,
          _kPlanColors[i % _kPlanColors.length],
        ),
      );
    }
    if (studentStats.unsubscribed > 0) {
      segments.add(
        _BarSegmentData(
          'Unsubscribed',
          studentStats.unsubscribed,
          _kColorCancelled,
        ),
      );
    }

    final sub = studentStats.unsubscribed;
    final subscribed = studentStats.totalStudents - sub;
    final parts = <String>[];
    if (subscribed > 0) parts.add('$subscribed subscribed');
    if (sub > 0) parts.add('$sub unsubscribed');

    return _StatCardData(
      icon: Icons.badge_outlined,
      label: 'Students',
      total: _formatCount(studentStats.totalStudents),
      subtitle: parts.isEmpty ? 'No students' : parts.join(', '),
      segments: segments,
    );
  }

  _StatCardData _buildTeacherCard() {
    final segments = <_BarSegmentData>[
      _BarSegmentData('Active', teacherStats.active, _kColorActive),
      _BarSegmentData('Resigned', teacherStats.resigned, _kColorCancelled),
      _BarSegmentData('Transferred', teacherStats.transferred, _kColorInvited),
      _BarSegmentData('Fired', teacherStats.fired, _kColorDeleted),
      _BarSegmentData('Retired', teacherStats.retired, _kColorSuspended),
    ];

    return _StatCardData(
      icon: Icons.assignment_ind_outlined,
      label: 'Teachers',
      total: _formatCount(teacherStats.total),
      subtitle: teacherStats.subtitle,
      segments: segments,
    );
  }

  _StatCardData _buildSubscriptionCard(bool canSeeDeleted) {
    final segments = <_BarSegmentData>[
      _BarSegmentData('Pending', subscriptionStats.pending, _kColorInvited),
      _BarSegmentData('Active', subscriptionStats.active, _kColorActive),
      _BarSegmentData(
        'Cancelled',
        subscriptionStats.cancelled,
        _kColorCancelled,
      ),
      if (canSeeDeleted)
        _BarSegmentData('Deleted', subscriptionStats.deleted, _kColorDeleted),
    ];

    return _StatCardData(
      icon: Icons.card_membership_outlined,
      label: 'Subscriptions',
      total: _formatCount(subscriptionStats.total),
      subtitle: subscriptionStats.subtitle,
      segments: segments,
    );
  }

  _StatCardData _buildRevenueCard() {
    final segments = <_BarSegmentData>[
      _BarSegmentData('Cash', revenueStats.cash.round(), _kColorActive),
      _BarSegmentData('M-Pesa', revenueStats.mpesa.round(), _kColorTrial),
      _BarSegmentData('Bank', revenueStats.bank.round(), _kColorInvited),
      _BarSegmentData('Cheque', revenueStats.cheque.round(), _kColorSuspended),
    ];

    return _StatCardData(
      icon: Icons.payments_outlined,
      label: 'Revenue',
      total: _formatAmount(revenueStats.totalAmount),
      subtitle: revenueStats.subtitle,
      segments: segments,
    );
  }

  static String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  static String _formatAmount(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardData {
  const _StatCardData({
    required this.icon,
    required this.label,
    required this.total,
    required this.subtitle,
    required this.segments,
  });

  final IconData icon;
  final String label;
  final String total;
  final String subtitle;
  final List<_BarSegmentData> segments;
}

class _BarSegmentData {
  const _BarSegmentData(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.data, required this.isDesktop});

  final _StatCardData data;
  final bool isDesktop;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isMobile = !widget.isDesktop;

    // On desktop, always show bars
    final showBars = widget.isDesktop || _expanded;

    // Filter out zero-value segments for the bars
    final nonZeroSegments = widget.data.segments
        .where((s) => s.value > 0)
        .toList();

    return GestureDetector(
      onTap: isMobile ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(
            color: isDark
                ? cs.outline.withValues(alpha: 0.5)
                : cs.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + label + expand chevron on mobile ──────────
            Row(
              children: [
                Icon(
                  widget.data.icon,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.data.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (isMobile)
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Main content: number + subtitle on left, bars on right ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left column: number + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.data.total,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: cs.onSurface,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.data.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right column: inline bars (animated show/hide)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerRight,
                    child: showBars && nonZeroSegments.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: _InlineBars(segments: nonZeroSegments),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline vertical mini bars
// ─────────────────────────────────────────────────────────────────────────────

class _InlineBars extends StatelessWidget {
  const _InlineBars({required this.segments});

  final List<_BarSegmentData> segments;

  static const double _barWidth = 4.0;
  static const double _barSpacing = 3.0;
  static const double _maxBarHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final maxVal = segments.fold<int>(0, (m, s) => math.max(m, s.value));
    if (maxVal == 0) return const SizedBox.shrink();

    return Tooltip(
      richMessage: TextSpan(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const TextSpan(text: '\n'),
            TextSpan(
              text: '${segments[i].label}: ${segments[i].value}',
              style: const TextStyle(fontSize: 11, height: 1.5),
            ),
          ],
        ],
      ),
      child: SizedBox(
        height: _maxBarHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) SizedBox(width: _barSpacing),
              _SingleBar(
                height: (segments[i].value / maxVal) * _maxBarHeight,
                color: segments[i].color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SingleBar extends StatelessWidget {
  const _SingleBar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _InlineBars._barWidth,
      height: math.max(height, 2), // Minimum 2px for visibility
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(1.5),
          topRight: Radius.circular(1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton placeholder while streams load — 6 shimmer cards in grid
// ─────────────────────────────────────────────────────────────────────────────

class _CardGridSkeleton extends StatefulWidget {
  const _CardGridSkeleton({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_CardGridSkeleton> createState() => _CardGridSkeletonState();
}

class _CardGridSkeletonState extends State<_CardGridSkeleton>
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
    final width = MediaQuery.sizeOf(context).width;
    final padding = widget.isDesktop
        ? const EdgeInsets.fromLTRB(24, 20, 24, 20)
        : const EdgeInsets.fromLTRB(16, 16, 16, 24);

    final int crossAxisCount;
    if (width < 400) {
      crossAxisCount = 1;
    } else if (width < 700) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    Widget grid = AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final base = cs.surfaceContainerHighest;
        final shimmerColor = Color.lerp(
          base,
          cs.surfaceContainer,
          _shimmer.value,
        )!;

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: widget.isDesktop ? 1.85 : 2.0,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
                border: Border.all(
                  color: isDark
                      ? cs.outline.withValues(alpha: 0.5)
                      : cs.outlineVariant,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header placeholder
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 50,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Number placeholder
                  Container(
                    width: 48,
                    height: 20,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle placeholder
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            );
          },
        );
      },
    );

    if (widget.isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(padding: padding, child: grid),
        ),
      );
    }

    return Padding(padding: padding, child: grid);
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

// Dynamic plan colours
const _kPlanColors = [
  Color(0xFF7986CB), // indigo-300
  Color(0xFF26A69A), // teal-400
  Color(0xFF42A5F5), // blue-400
  Color(0xFFFF7043), // deep-orange-400
  Color(0xFFAB47BC), // purple-400
  Color(0xFFFFCA28), // amber-400
  Color(0xFF66BB6A), // green-400
];
