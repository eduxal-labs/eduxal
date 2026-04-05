import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/quick_stat_row.dart';
import '../../../widgets/today_status_card.dart';
import '../../../../core/formatters.dart';
import '../school_dashboard_screen.dart';
import 'overview_shared.dart';

// ═════════════════════════════════════════════════════════════════════════════
// OWNER OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class OwnerOverview extends StatelessWidget {
  const OwnerOverview({
    super.key,
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final school = schoolContext.membership.school;
    final schoolId = school.id;
    final term = termContext.currentTerm;

    return RefreshIndicator(
      onRefresh: () async {
        sync.pushNow();
        await Future.delayed(const Duration(milliseconds: 800));
      },
      color: cs.primary,
      child: StaggeredList(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── School identity ──────────────────────────────────────────────
          SchoolIdentityCard(school: school),

          const SizedBox(height: 16),

          // ── Today's attendance (school-wide) ─────────────────────────────
          if (term != null) ...[
            StreamBuilder<SchoolAttendanceSummary>(
              stream: AttendanceDao(db).watchSchoolAttendanceSummary(
                schoolId: schoolId,
                year: term.year,
                term: term.term,
                date: DateTime.now()
                    .toUtc()
                    .difference(DateTime.utc(1970, 1, 1))
                    .inDays,
              ),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final s = snap.data!;
                if (s.totalEnrolled == 0) return const SizedBox.shrink();
                final pct = (s.attendanceRate * 100).toStringAsFixed(1);
                return TodayStatusCard(
                  type: s.attendanceRate >= 0.90
                      ? TodayStatusType.positive
                      : s.attendanceRate >= 0.75
                      ? TodayStatusType.warning
                      : TodayStatusType.negative,
                  icon: Icons.groups_rounded,
                  title: '${s.presentCount}/${s.totalEnrolled} present ($pct%)',
                  subtitle: s.isFullyMarked
                      ? 'All classes marked'
                      : '${s.unmarkedCount} not yet marked',
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── Quick stats ──────────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(label: 'Quick Stats', cs: cs),
            const SizedBox(height: 8),
            _OwnerQuickStats(schoolId: schoolId, term: term),
            const SizedBox(height: 20),
          ],

          // ── Term revenue ─────────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(label: 'Term Revenue', cs: cs),
            const SizedBox(height: 8),
            _OwnerRevenueSummary(schoolId: schoolId, term: term),
            const SizedBox(height: 20),
          ],

          // ── Lesson delivery ──────────────────────────────────────────────
          if (term != null) ...[
            _OwnerLessonDelivery(schoolId: schoolId, term: term),
            const SizedBox(height: 20),
          ],

          // ── Current term info ────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(label: 'Current Term', cs: cs),
            const SizedBox(height: 8),
            TermInfoCard(term: term, cs: cs),
            const SizedBox(height: 10),
            _AcademicMiniTimeline(schoolId: schoolId, term: term, cs: cs),
            const SizedBox(height: 20),
          ],

          // ── Recent announcements ─────────────────────────────────────────
          SectionTitle(
            label: 'Recent Announcements',
            cs: cs,
            onViewAll: () =>
                DashboardNavigation.goToTab(context, 'Announcements'),
          ),
          const SizedBox(height: 8),
          RecentAnnouncements(schoolId: schoolId, isOwner: true),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _OwnerQuickStats extends StatefulWidget {
  const _OwnerQuickStats({required this.schoolId, required this.term});

  final String schoolId;
  final Term term;

  @override
  State<_OwnerQuickStats> createState() => _OwnerQuickStatsState();
}

class _OwnerQuickStatsState extends State<_OwnerQuickStats> {
  late final MembersDao _membersDao;
  late final EnrollmentsDao _enrollmentsDao;

  int _studentCount = 0;
  int _teacherCount = 0;
  int _staffCount = 0;
  int _classCount = 0;

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _membersDao = MembersDao(db);
    _enrollmentsDao = EnrollmentsDao(db);
    _subscribe();
  }

  void _subscribe() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    _subs.add(
      _membersDao.watchStudents(widget.schoolId).listen((list) {
        if (mounted) setState(() => _studentCount = list.length);
      }),
    );
    _subs.add(
      _membersDao.watchTeachers(widget.schoolId).listen((list) {
        if (mounted) setState(() => _teacherCount = list.length);
      }),
    );
    _subs.add(
      _membersDao.watchStaff(widget.schoolId).listen((list) {
        if (mounted) setState(() => _staffCount = list.length);
      }),
    );
    _subs.add(
      _enrollmentsDao
          .watchPopulatedClasses(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          )
          .listen((list) {
            if (mounted) setState(() => _classCount = list.length);
          }),
    );
  }

  @override
  void didUpdateWidget(covariant _OwnerQuickStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.term.year != widget.term.year ||
        oldWidget.term.term != widget.term.term) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuickStatRow(
      stats: [
        QuickStat(
          icon: Icons.groups_outlined,
          label: 'Students',
          value: '$_studentCount',
        ),
        QuickStat(
          icon: Icons.school_outlined,
          label: 'Teachers',
          value: '$_teacherCount',
        ),
        QuickStat(
          icon: Icons.badge_outlined,
          label: 'Staff',
          value: '$_staffCount',
        ),
        QuickStat(
          icon: Icons.class_outlined,
          label: 'Classes',
          value: '$_classCount',
        ),
      ],
    );
  }
}

// ── Owner Revenue Summary ────────────────────────────────────────────────────

class _OwnerRevenueSummary extends StatefulWidget {
  const _OwnerRevenueSummary({required this.schoolId, required this.term});

  final String schoolId;
  final Term term;

  @override
  State<_OwnerRevenueSummary> createState() => _OwnerRevenueSummaryState();
}

class _OwnerRevenueSummaryState extends State<_OwnerRevenueSummary> {
  StreamSubscription<TermFinanceSummary>? _sub;
  TermFinanceSummary? _summary;

  @override
  void initState() {
    super.initState();
    _subscribeFinance();
  }

  void _subscribeFinance() {
    _sub?.cancel();
    _summary = null;
    _sub = FinanceDao(db)
        .watchTermFinanceSummary(
          schoolId: widget.schoolId,
          year: widget.term.year,
          term: widget.term.term,
        )
        .listen((s) {
          if (mounted) setState(() => _summary = s);
        });
  }

  @override
  void didUpdateWidget(covariant _OwnerRevenueSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.term.year != widget.term.year ||
        oldWidget.term.term != widget.term.term) {
      _subscribeFinance();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _summary;

    if (summary == null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    final rate = summary.collectionRate;
    final ratePct = (rate * 100).clamp(0.0, 100.0);
    final collected = summary.totalPaid;
    final pending = summary.totalPending;
    final overdue = summary.totalOverdue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A3848)
              : cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Collection rate label ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ratePct.toStringAsFixed(1)}% collected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Text(
                fmtCurrency(summary.totalInvoiced),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final greenWidth = totalWidth * rate.clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      Container(
                        width: totalWidth,
                        color: cs.surfaceContainerHighest,
                      ),
                      Container(
                        width: greenWidth,
                        color: const Color(0xFF4CAF50),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Three-column breakdown ──
          Row(
            children: [
              Expanded(
                child: _RevenueStat(
                  label: 'Collected',
                  value: fmtCurrency(collected),
                  color: const Color(0xFF4CAF50),
                  cs: cs,
                ),
              ),
              Expanded(
                child: _RevenueStat(
                  label: 'Pending',
                  value: fmtCurrency(pending),
                  color: Colors.amber[700]!,
                  cs: cs,
                ),
              ),
              Expanded(
                child: _RevenueStat(
                  label: 'Overdue',
                  value: fmtCurrency(overdue),
                  color: const Color(0xFFF44336),
                  cs: cs,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueStat extends StatelessWidget {
  const _RevenueStat({
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });

  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Owner Lesson Delivery ────────────────────────────────────────────────────

class _OwnerLessonDelivery extends StatelessWidget {
  const _OwnerLessonDelivery({required this.schoolId, required this.term});

  final String schoolId;
  final Term term;

  @override
  Widget build(BuildContext context) {
    final todayDate = DateTime.now()
        .toUtc()
        .difference(DateTime.utc(1970, 1, 1))
        .inDays;
    final todayDay = currentDayOfWeek().index;

    return StreamBuilder<LessonDeliveryRate>(
      stream: TimetableDao(db).watchTodayLessonDelivery(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        todayDate: todayDate,
        todayDay: todayDay,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final rate = snap.data!;
        if (rate.expectedLessons == 0) return const SizedBox.shrink();
        final pct = rate.deliveryRate;
        final pctStr = (pct * 100).toStringAsFixed(0);
        return TodayStatusCard(
          type: pct >= 0.90
              ? TodayStatusType.positive
              : pct >= 0.70
              ? TodayStatusType.warning
              : TodayStatusType.negative,
          icon: Icons.school_rounded,
          title:
              '${rate.deliveredLessons}/${rate.expectedLessons} lessons delivered ($pctStr%)',
          subtitle:
              '${rate.uniqueTeachersDelivered}/${rate.uniqueTeachersExpected} teachers active today',
        );
      },
    );
  }
}

// ── Academic Mini Timeline ───────────────────────────────────────────────────

enum _EventType { today, exam, termEnd }

class _TimelineEvent {
  const _TimelineEvent({
    required this.seconds,
    required this.label,
    required this.type,
  });
  final int seconds;
  final String label;
  final _EventType type;
}

class _AcademicMiniTimeline extends StatelessWidget {
  const _AcademicMiniTimeline({
    required this.schoolId,
    required this.term,
    required this.cs,
  });

  final String schoolId;
  final Term term;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExamWithPapers>>(
      stream: ExamsGradesDao(
        db,
      ).watchExamsForTerm(schoolId: schoolId, year: term.year, term: term.term),
      builder: (context, snap) {
        final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final termStartSecs = term.start.toInt();
        final termEndSecs = term.end.toInt();
        final totalSpan = termEndSecs - termStartSecs;
        if (totalSpan <= 0) return const SizedBox.shrink();

        final events = <_TimelineEvent>[];

        // Today marker
        if (nowSecs >= termStartSecs && nowSecs <= termEndSecs) {
          events.add(
            _TimelineEvent(
              seconds: nowSecs,
              label: 'Today',
              type: _EventType.today,
            ),
          );
        }

        // Upcoming exam start dates (max 3)
        if (snap.hasData) {
          final upcoming =
              snap.data!.where((e) => e.exam.start.toInt() >= nowSecs).toList()
                ..sort((a, b) => a.exam.start.compareTo(b.exam.start));
          for (final e in upcoming.take(3)) {
            final secs = e.exam.start.toInt();
            final dt = DateTime.fromMillisecondsSinceEpoch(
              secs * 1000,
              isUtc: true,
            );
            events.add(
              _TimelineEvent(
                seconds: secs,
                label: '${dt.day} ${months[dt.month - 1]}',
                type: _EventType.exam,
              ),
            );
          }
        }

        // Term end
        final endDt = DateTime.fromMillisecondsSinceEpoch(
          termEndSecs * 1000,
          isUtc: true,
        );
        events.add(
          _TimelineEvent(
            seconds: termEndSecs,
            label: '${endDt.day} ${months[endDt.month - 1]}',
            type: _EventType.termEnd,
          ),
        );

        events.sort((a, b) => a.seconds.compareTo(b.seconds));
        if (events.length < 2) return const SizedBox.shrink();

        return _buildTimeline(events, termStartSecs, totalSpan);
      },
    );
  }

  Widget _buildTimeline(
    List<_TimelineEvent> events,
    int termStartSecs,
    int totalSpan,
  ) {
    final items = <Widget>[];

    for (int i = 0; i < events.length; i++) {
      if (i == 0) {
        final gap = events[i].seconds - termStartSecs;
        final flex = (gap * 1000 ~/ totalSpan).clamp(1, 1000);
        items.add(Expanded(flex: flex, child: const SizedBox()));
      }

      items.add(_eventColumn(events[i]));

      if (i < events.length - 1) {
        final gap = events[i + 1].seconds - events[i].seconds;
        final flex = (gap * 1000 ~/ totalSpan).clamp(1, 1000);
        items.add(Expanded(flex: flex, child: const SizedBox()));
      }
    }

    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          Row(children: items),
        ],
      ),
    );
  }

  Widget _eventColumn(_TimelineEvent event) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (event.type == _EventType.today)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary, width: 2),
              color: cs.surface,
            ),
          )
        else
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: event.type == _EventType.exam
                  ? const Color(0xFFFF9800)
                  : cs.error,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          event.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: event.type == _EventType.today
                ? FontWeight.w500
                : FontWeight.w300,
            color: event.type == _EventType.today
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
