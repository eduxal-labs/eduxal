import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/countdown_chip.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STAGGERED ENTRANCE ANIMATION WRAPPER
// ═════════════════════════════════════════════════════════════════════════════

/// Drop-in replacement for [ListView] that adds a staggered fade + slide
/// entrance animation. Each non-[SizedBox] child animates in sequence with
/// a slight delay, creating a cascading reveal effect. Spacer [SizedBox]
/// widgets are rendered without animation so layout gaps remain stable.
class StaggeredList extends StatefulWidget {
  const StaggeredList({
    super.key,
    required this.children,
    this.padding,
    this.physics,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _totalMs;

  /// Stagger delay between successive content sections.
  static const int _staggerMs = 80;

  /// Duration of each individual section's fade + slide animation.
  static const int _itemDurationMs = 350;

  /// Vertical slide offset (fraction of child height).
  static const Offset _slideBegin = Offset(0, 0.05);

  static const Curve _curve = Curves.easeOut;

  @override
  void initState() {
    super.initState();
    final sectionCount = _countSections(widget.children);
    _totalMs = ((sectionCount - 1) * _staggerMs + _itemDurationMs).clamp(
      600,
      1500,
    );
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..forward();
  }

  static int _countSections(List<Widget> children) {
    int n = 0;
    for (final c in children) {
      if (c is! SizedBox) n++;
    }
    return n.clamp(1, 50);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int idx = 0;
    final wrapped = <Widget>[];

    for (final child in widget.children) {
      if (child is SizedBox) {
        wrapped.add(child);
        continue;
      }

      final startMs = idx * _staggerMs;
      if (startMs >= _totalMs) {
        // Beyond animation window — show immediately.
        wrapped.add(child);
        idx++;
        continue;
      }

      final begin = (startMs / _totalMs).clamp(0.0, 1.0);
      final end = ((startMs + _itemDurationMs) / _totalMs).clamp(0.0, 1.0);

      final curved = CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: _curve),
      );

      wrapped.add(
        FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: _slideBegin,
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );
      idx++;
    }

    return ListView(
      padding: widget.padding,
      physics: widget.physics,
      children: wrapped,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── School Identity Card ─────────────────────────────────────────────────────

class SchoolIdentityCard extends StatelessWidget {
  const SchoolIdentityCard({super.key, required this.school});

  final SchoolsData school;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.school_outlined,
                  size: 22,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (school.motto != null && school.motto!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        school.motto!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (school.established != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  'Est. ${school.established}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Welcome Card ─────────────────────────────────────────────────────────────

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.cs,
  });

  final String name;
  final String subtitle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              initials(name),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $firstName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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

// ── Term Info Card ───────────────────────────────────────────────────────────

class TermInfoCard extends StatelessWidget {
  const TermInfoCard({super.key, required this.term, required this.cs});

  final Term term;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final start = fmtDateFromSeconds(term.start);
    final end = fmtDateFromSeconds(term.end);

    // Compute days remaining
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final remaining = (term.end - nowSeconds).toInt();
    final daysRemaining = remaining > 0 ? (remaining / 86400).ceil() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 16,
                color: cs.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                '${term.year} · Term ${term.term}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (daysRemaining > 0)
                CountdownChip(
                  label: '$daysRemaining days',
                  targetTime: DateTime.fromMillisecondsSinceEpoch(
                    term.end.toInt() * 1000,
                    isUtc: true,
                  ).toLocal(),
                  icon: Icons.timer_outlined,
                  reachedLabel: 'Term ended',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$start  –  $end',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ────────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.label,
    required this.cs,
    this.onViewAll,
  });

  final String label;
  final ColorScheme cs;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: cs.onSurface.withValues(alpha: 0.7),
        letterSpacing: 0.1,
      ),
    );
    if (onViewAll == null) return labelWidget;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        labelWidget,
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            'View All \u2192',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.primary.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stat Card ────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: tint.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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

// ── Attendance Bar ───────────────────────────────────────────────────────────

class AttendanceBar extends StatelessWidget {
  const AttendanceBar({
    super.key,
    required this.present,
    required this.absent,
    required this.leave,
    required this.totalDays,
    required this.presentPercent,
    required this.cs,
  });

  final int present;
  final int absent;
  final int leave;
  final int totalDays;
  final double presentPercent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (present > 0)
                    Expanded(
                      flex: present,
                      child: Container(color: const Color(0xFF4CAF50)),
                    ),
                  if (absent > 0)
                    Expanded(
                      flex: absent,
                      child: Container(color: const Color(0xFFF44336)),
                    ),
                  if (leave > 0)
                    Expanded(
                      flex: leave,
                      child: Container(color: const Color(0xFFFFA726)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AttendanceDot(
                color: const Color(0xFF4CAF50),
                label: 'Present',
                count: present,
                cs: cs,
              ),
              const SizedBox(width: 16),
              AttendanceDot(
                color: const Color(0xFFF44336),
                label: 'Absent',
                count: absent,
                cs: cs,
              ),
              const SizedBox(width: 16),
              AttendanceDot(
                color: const Color(0xFFFFA726),
                label: 'Leave',
                count: leave,
                cs: cs,
              ),
              const Spacer(),
              Text(
                '${presentPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: pctColor(presentPercent),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AttendanceDot extends StatelessWidget {
  const AttendanceDot({
    super.key,
    required this.color,
    required this.label,
    required this.count,
    required this.cs,
  });

  final Color color;
  final String label;
  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
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
          '$count',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ── Percent Badge ────────────────────────────────────────────────────────────

class PercentBadge extends StatelessWidget {
  const PercentBadge({super.key, required this.percent, required this.cs});

  final double percent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = pctColor(percent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${percent.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ── Recent Announcements ─────────────────────────────────────────────────────

class RecentAnnouncements extends StatelessWidget {
  const RecentAnnouncements({
    super.key,
    required this.schoolId,
    this.isOwner = false,
    this.audienceBit,
    this.studentAdm,
    this.termYear,
    this.termNum,
  });

  final String schoolId;
  final bool isOwner;
  final int? audienceBit;

  /// B07: When set, the widget resolves the student's enrollment to filter
  /// announcements by grade/stream so students and guardians only see
  /// announcements targeted at their class (or school-wide).
  final int? studentAdm;
  final int? termYear;
  final int? termNum;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final announcementsDao = AnnouncementsDao(db);

    // For student / guardian entries, resolve enrollment first.
    if (studentAdm != null && termYear != null && termNum != null) {
      return StreamBuilder<Enrollment?>(
        stream: EnrollmentsDao(db).watchStudentEnrollment(
          schoolId: schoolId,
          year: termYear!,
          term: termNum!,
          studentAdm: studentAdm!,
        ),
        builder: (context, enrollSnap) {
          final enrollment = enrollSnap.data;
          return _buildList(
            cs: cs,
            dao: announcementsDao,
            grade: enrollment?.grade,
            enrolledStream: enrollment?.stream,
          );
        },
      );
    }

    return _buildList(cs: cs, dao: announcementsDao);
  }

  Widget _buildList({
    required ColorScheme cs,
    required AnnouncementsDao dao,
    int? grade,
    int? enrolledStream,
  }) {
    final Stream<List<AnnouncementWithAuthor>> dataStream;
    if (isOwner) {
      dataStream = dao.watchAllAnnouncements(schoolId);
    } else {
      dataStream = dao.watchAnnouncementsForAudience(
        schoolId,
        audienceBit: audienceBit ?? AudienceBits.all,
        grade: grade,
        stream: enrolledStream,
      );
    }

    return StreamBuilder<List<AnnouncementWithAuthor>>(
      stream: dataStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingShimmer();
        }

        final all = snap.data ?? [];
        if (all.isEmpty) {
          return const EmptyCard(
            icon: Icons.campaign_outlined,
            message: 'No announcements yet',
          );
        }

        final recent = all.take(3).toList();

        return Column(
          children: recent.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.campaign_outlined,
                          size: 16,
                          color: cs.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
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
                              a.content,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (a.authorName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '— ${a.authorName}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Empty Card ───────────────────────────────────────────────────────────────

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Loading Shimmer ──────────────────────────────────────────────────────────

class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: cs.onSurfaceVariant.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

// ── Quick Action Chip ────────────────────────────────────────────────────────

class QuickActionChip extends StatelessWidget {
  const QuickActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: color.withOpacity(isDark ? 0.12 : 0.08),
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        splashColor: color.withOpacity(0.12),
        highlightColor: color.withOpacity(0.06),
        child: SizedBox(
          width: 80,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: color.withOpacity(isDark ? 0.8 : 0.7),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Converts seconds since midnight into a [DateTime] for today.
DateTime todayAtSeconds(int secondsSinceMidnight) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(seconds: secondsSinceMidnight));
}

/// Returns the current day of the week as a [DayOfWeek] enum value.
DayOfWeek currentDayOfWeek() {
  // DateTime.weekday: 1 = Monday … 7 = Sunday
  // DayOfWeek enum:  0 = Sunday, 1 = Monday … 6 = Saturday
  final wd = DateTime.now().weekday;
  return DayOfWeek.values[wd == 7 ? 0 : wd];
}

/// Formats seconds since midnight to "HH:MM" 24-hour.
String fmtTime(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Formats a BigInt seconds-since-epoch to a readable date string.
String fmtDateFromSeconds(BigInt secondsSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch.toInt() * 1000,
    isUtc: true,
  );
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

const months = [
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

/// Extracts initials (up to 2 characters) from a name.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Deterministic subject color from a 15-color palette.
Color subjectColor(int subjectIndex) {
  const palette = [
    Color(0xFF3F51B5),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFF7C4DFF),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
    Color(0xFF795548),
    Color(0xFF9C27B0),
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFF2196F3),
    Color(0xFFCDDC39),
  ];
  return palette[subjectIndex % palette.length];
}

/// Percentage color: green ≥ 70, amber ≥ 40, red < 40.
Color pctColor(double pct) {
  if (pct >= 70) return const Color(0xFF4CAF50);
  if (pct >= 40) return const Color(0xFFFFC107);
  return const Color(0xFFF44336);
}

/// Formats a double amount as currency string (comma-separated, no symbol).
String fmtCurrencyCompact(double amount) {
  // Simple comma-separated formatting
  final wholePart = amount.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < wholePart.length; i++) {
    if (i > 0 && (wholePart.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(wholePart[i]);
  }
  return buf.toString();
}
