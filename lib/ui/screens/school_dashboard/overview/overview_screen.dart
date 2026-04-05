import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../core/extensions.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/academics_dao.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../../models/grade_analytics.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_permissions.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/countdown_chip.dart';
import '../../../widgets/student_avatar.dart';
import '../../../widgets/today_status_card.dart';
import '../../../widgets/quick_stat_row.dart';
import '../../../theme/app_theme.dart';
import '../../../../core/formatters.dart';
import '../school_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Overview Screen — role-dispatched school dashboard landing page
// ─────────────────────────────────────────────────────────────────────────────

/// The Overview screen is the first page a user sees when entering a school
/// dashboard. It adapts its content based on the user's active role.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: schoolContext.currentEntry,
      builder: (context, entry, _) {
        return switch (entry) {
          OwnerEntry() => _OwnerOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          TeacherEntry() => _TeacherOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
          StaffEntry() => _StaffOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          StudentEntry() => _StudentOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
          GuardianEntry() => _GuardianOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
        };
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAGGERED ENTRANCE ANIMATION WRAPPER
// ═════════════════════════════════════════════════════════════════════════════

/// Drop-in replacement for [ListView] that adds a staggered fade + slide
/// entrance animation. Each non-[SizedBox] child animates in sequence with
/// a slight delay, creating a cascading reveal effect. Spacer [SizedBox]
/// widgets are rendered without animation so layout gaps remain stable.
class _StaggeredList extends StatefulWidget {
  const _StaggeredList({required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  State<_StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<_StaggeredList>
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

    return ListView(padding: widget.padding, children: wrapped);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _OwnerOverview extends StatelessWidget {
  const _OwnerOverview({
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

    return _StaggeredList(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── School identity ──────────────────────────────────────────────
        _SchoolIdentityCard(school: school),

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
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _OwnerQuickStats(schoolId: schoolId, term: term),
          const SizedBox(height: 20),
        ],

        // ── Term revenue ─────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Term Revenue', cs: cs),
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
          _SectionTitle(label: 'Current Term', cs: cs),
          const SizedBox(height: 8),
          _TermInfoCard(term: term, cs: cs),
          const SizedBox(height: 10),
          _AcademicMiniTimeline(schoolId: schoolId, term: term, cs: cs),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(
          label: 'Recent Announcements',
          cs: cs,
          onViewAll: () =>
              DashboardNavigation.goToTab(context, 'Announcements'),
        ),
        const SizedBox(height: 8),
        _RecentAnnouncements(schoolId: schoolId, isOwner: true),

        const SizedBox(height: 80),
      ],
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
    final todayDay = _currentDayOfWeek().index;

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
                label: '${dt.day} ${_months[dt.month - 1]}',
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
            label: '${endDt.day} ${_months[endDt.month - 1]}',
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

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherOverview extends StatelessWidget {
  const _TeacherOverview({
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final TeacherEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final userId = entry.teacher.user;

    return _StaggeredList(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── Next class countdown ─────────────────────────────────────────
        if (term != null && userId.isNotEmpty) ...[
          _TeacherNextClass(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            teacherUserId: userId,
          ),
          const SizedBox(height: 16),
        ],

        // ── Attendance marking status ────────────────────────────────────
        if (term != null && userId.isNotEmpty) ...[
          StreamBuilder<List<ClassAttendanceStatus>>(
            stream: AttendanceDao(db).watchTeacherClassAttendanceStatus(
              schoolId: schoolId,
              teacherId: userId,
              year: term.year,
              term: term.term,
              date: DateTime.now()
                  .toUtc()
                  .difference(DateTime.utc(1970, 1, 1))
                  .inDays,
            ),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty)
                return const SizedBox.shrink();
              final classes = snap.data!;
              final allMarked = classes.every((c) => c.isMarked);
              final unmarkedCount = classes.where((c) => !c.isMarked).length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TodayStatusCard(
                  type: allMarked
                      ? TodayStatusType.positive
                      : TodayStatusType.warning,
                  icon: allMarked
                      ? Icons.check_circle_rounded
                      : Icons.edit_note_rounded,
                  title: allMarked
                      ? 'All classes marked'
                      : '$unmarkedCount class${unmarkedCount > 1 ? "es" : ""} not marked',
                  subtitle: classes
                      .map((c) {
                        final label = gradeLabel(c.grade);
                        return c.isMarked ? '$label ✓' : '$label ✗';
                      })
                      .join('  '),
                ),
              );
            },
          ),
        ],

        // ── Today's schedule ─────────────────────────────────────────────
        if (term != null && userId.isNotEmpty) ...[
          _SectionTitle(
            label: "Today's Schedule",
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Timetable'),
          ),
          const SizedBox(height: 8),
          _TeacherTodaySchedule(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            teacherUserId: userId,
          ),
          const SizedBox(height: 20),
        ],

        // ── My Classes ───────────────────────────────────────────────────
        if (term != null && userId.isNotEmpty) ...[
          _SectionTitle(
            label: 'My Classes',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'My Classes'),
          ),
          const SizedBox(height: 8),
          _TeacherClassChips(schoolId: schoolId, userId: userId, term: term),
          const SizedBox(height: 20),
        ],

        // ── Quick stats ──────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _TeacherQuickStats(
            schoolId: schoolId,
            term: term,
            entry: entry,
            userId: userId,
          ),
          const SizedBox(height: 20),
        ],

        // ── Upcoming Exams ───────────────────────────────────────────────
        if (term != null && userId.isNotEmpty) ...[
          _SectionTitle(
            label: 'Upcoming Exams',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Exams'),
          ),
          const SizedBox(height: 8),
          _TeacherUpcomingExams(schoolId: schoolId, userId: userId, term: term),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(
          label: 'Recent Announcements',
          cs: cs,
          onViewAll: () =>
              DashboardNavigation.goToTab(context, 'Announcements'),
        ),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.teachers,
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _TeacherNextClass extends StatefulWidget {
  const _TeacherNextClass({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.teacherUserId,
  });

  final String schoolId;
  final int year;
  final int term;
  final String teacherUserId;

  @override
  State<_TeacherNextClass> createState() => _TeacherNextClassState();
}

class _TeacherNextClassState extends State<_TeacherNextClass> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
  }

  @override
  void didUpdateWidget(covariant _TeacherNextClass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimetableData>>(
      stream: TimetableDao(db).watchTeacherTimetable(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        teacherUserId: widget.teacherUserId,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final allSlots = snap.data!;
        final todayDay = _currentDayOfWeek();
        final now = DateTime.now();
        final nowSec = now.hour * 3600 + now.minute * 60 + now.second;

        final todaySlots =
            allSlots.where((s) => s.day == todayDay && s.end > nowSec).toList()
              ..sort((a, b) => a.start.compareTo(b.start));

        if (todaySlots.isEmpty) return const SizedBox.shrink();

        final nextSlot = todaySlots.firstWhere(
          (s) => s.start > nowSec,
          orElse: () => todaySlots.first,
        );

        final isInProgress = nextSlot.start <= nowSec && nextSlot.end > nowSec;

        return FutureBuilder<List<Subject>>(
          future: _subjectsFuture,
          builder: (context, subSnap) {
            final subjectMap = <int, String>{};
            for (final s in subSnap.data ?? []) {
              subjectMap[s.id] = s.name;
            }
            final subjectName = subjectMap[nextSlot.subject] ?? 'Class';

            if (isInProgress) {
              return TodayStatusCard(
                type: TodayStatusType.positive,
                icon: Icons.play_circle_rounded,
                title: '$subjectName in progress',
                subtitle:
                    '${_fmtTime(nextSlot.start)} – ${_fmtTime(nextSlot.end)}',
                trailing: CountdownChip(
                  label: 'Ends',
                  targetTime: _todayAtSeconds(nextSlot.end),
                  icon: Icons.timer_outlined,
                  compact: true,
                ),
              );
            }

            return TodayStatusCard(
              type: TodayStatusType.neutral,
              icon: Icons.schedule_rounded,
              title: 'Next: $subjectName',
              subtitle:
                  '${_fmtTime(nextSlot.start)} – ${_fmtTime(nextSlot.end)}',
              trailing: CountdownChip(
                label: 'Starts',
                targetTime: _todayAtSeconds(nextSlot.start),
                icon: Icons.timer_outlined,
                compact: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _TeacherTodaySchedule extends StatefulWidget {
  const _TeacherTodaySchedule({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.teacherUserId,
  });

  final String schoolId;
  final int year;
  final int term;
  final String teacherUserId;

  @override
  State<_TeacherTodaySchedule> createState() => _TeacherTodayScheduleState();
}

class _TeacherTodayScheduleState extends State<_TeacherTodaySchedule> {
  late Future<List<Subject>> _subjectsFuture;
  late Future<List<SchoolStream>> _streamsFuture;
  Timer? _refreshTimer;
  bool _showAll = false;

  int get _nowSeconds {
    final now = DateTime.now();
    return now.hour * 3600 + now.minute * 60 + now.second;
  }

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _TeacherTodaySchedule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
        _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
        _showAll = false;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Filters out past lessons and sorts by proximity to now.
  List<TimetableData> _filterAndSort(List<TimetableData> slots) {
    final nowSec = _nowSeconds;
    // Remove lessons that have already ended.
    final active = slots.where((s) => s.end > nowSec).toList();
    // Sort by proximity to now (closest start first), break ties by grade.
    active.sort((a, b) {
      final diffA = (a.start - nowSec).abs();
      final diffB = (b.start - nowSec).abs();
      final cmp = diffA.compareTo(diffB);
      return cmp != 0 ? cmp : a.grade.compareTo(b.grade);
    });
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final timetableDao = TimetableDao(db);

    return StreamBuilder<List<TimetableData>>(
      stream: timetableDao.watchTeacherTimetable(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        teacherUserId: widget.teacherUserId,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final allSlots = snap.data ?? [];
        final todayDay = _currentDayOfWeek();
        final todaySlots = allSlots.where((s) => s.day == todayDay).toList();
        final activeSlots = _filterAndSort(todaySlots);

        // All lessons have passed for the day (but some were scheduled).
        if (activeSlots.isEmpty && todaySlots.isNotEmpty) {
          return const _EmptyCard(
            icon: Icons.celebration_outlined,
            message: 'All done for today! 🎉',
          );
        }

        if (activeSlots.isEmpty) {
          return const _EmptyCard(
            icon: Icons.event_available_outlined,
            message: 'No classes scheduled today',
          );
        }

        return FutureBuilder<List<Subject>>(
          future: _subjectsFuture,
          builder: (context, subSnap) {
            return FutureBuilder<List<SchoolStream>>(
              future: _streamsFuture,
              builder: (context, strSnap) {
                final subjectMap = <int, String>{};
                for (final s in subSnap.data ?? []) {
                  subjectMap[s.id] = s.name;
                }
                final streamMap = <(int, int), String>{};
                for (final s in strSnap.data ?? []) {
                  streamMap[(s.grade, s.stream)] = s.name;
                }

                return _TodayScheduleGrid(
                  slots: activeSlots,
                  subjectMap: subjectMap,
                  streamMap: streamMap,
                  showAll: _showAll,
                  onToggleShowAll: () => setState(() => _showAll = !_showAll),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Responsive grid for today's lessons ──────────────────────────────────────

class _TodayScheduleGrid extends StatelessWidget {
  const _TodayScheduleGrid({
    required this.slots,
    required this.subjectMap,
    required this.streamMap,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final List<TimetableData> slots;
  final Map<int, String> subjectMap;
  final Map<(int, int), String> streamMap;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 360 ? 2 : (width < 600 ? 3 : 4);
        final defaultVisible = columns * 2; // 2 rows
        final total = slots.length;
        final visibleCount = showAll ? total : total.clamp(0, defaultVisible);
        final hasMore = total > defaultVisible;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(visibleCount, (i) {
                final slot = slots[i];
                // Calculate card width to fill columns with spacing.
                final totalSpacing = 8.0 * (columns - 1);
                final cardWidth = (width - totalSpacing) / columns;

                return SizedBox(
                  width: cardWidth,
                  height: 72,
                  child: _TodayLessonCard(
                    slot: slot,
                    subjectName: subjectMap[slot.subject],
                    streamName: streamMap[(slot.grade, slot.stream)],
                  ),
                );
              }),
            ),
            if (hasMore && !showAll) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onToggleShowAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Show all ($total)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (hasMore && showAll) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onToggleShowAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Show less',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Single lesson card in the grid ───────────────────────────────────────────

class _TodayLessonCard extends StatelessWidget {
  const _TodayLessonCard({
    required this.slot,
    this.subjectName,
    this.streamName,
  });

  final TimetableData slot;
  final String? subjectName;
  final String? streamName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _subjectColor(slot.subject);
    final timeLabel = _fmtTime(slot.start);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Left color stripe.
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.kCardRadius),
                bottomLeft: Radius.circular(AppTheme.kCardRadius),
              ),
            ),
          ),
          // Card content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: subject name + time badge.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subjectName ?? 'Subject ${slot.subject}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.kChipRadius,
                          ),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Bottom: grade + stream.
                  Text(
                    gradeStreamLabel(slot.grade, streamName: streamName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherQuickStats extends StatefulWidget {
  const _TeacherQuickStats({
    required this.schoolId,
    required this.term,
    required this.entry,
    required this.userId,
  });

  final String schoolId;
  final Term term;
  final TeacherEntry entry;
  final String userId;

  @override
  State<_TeacherQuickStats> createState() => _TeacherQuickStatsState();
}

class _TeacherQuickStatsState extends State<_TeacherQuickStats> {
  int _subjectCount = 0;
  int _classCount = 0;
  int _lessonsPerWeek = 0;
  int _papersCount = 0;
  Set<int> _teacherSubjectIds = {};
  List<ExamWithPapers> _allExams = [];

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    for (final s in _subs) s.cancel();
    _subs.clear();

    final membersDao = MembersDao(db);
    final timetableDao = TimetableDao(db);
    final examsDao = ExamsGradesDao(db);

    // 1. My Subjects — live count of subject assignments this term
    _subs.add(
      membersDao
          .watchTeacherSubjectsForTerm(
            widget.schoolId,
            widget.userId,
            year: widget.term.year,
            term: widget.term.term,
          )
          .listen((list) {
            if (!mounted) return;
            final ids = list.map((s) => s.subject).toSet();
            setState(() {
              _teacherSubjectIds = ids;
              _subjectCount = ids.length;
            });
            _recomputePapers();
          }),
    );

    // 2. My Classes — class_teacher assignments for this term
    _subs.add(
      membersDao
          .watchClassTeacherAssignments(widget.schoolId, widget.userId)
          .listen((list) {
            if (!mounted) return;
            final count = list
                .where(
                  (c) =>
                      c.year == widget.term.year && c.term == widget.term.term,
                )
                .length;
            setState(() => _classCount = count);
          }),
    );

    // 3. Lessons/Week — timetable entry count = weekly lesson slots
    _subs.add(
      timetableDao
          .watchTeacherTimetable(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
            teacherUserId: widget.userId,
          )
          .listen((list) {
            if (!mounted) return;
            setState(() => _lessonsPerWeek = list.length);
          }),
    );

    // 4. My Exams — papers count from exams where teacher is involved
    _subs.add(
      examsDao
          .watchExamsForTerm(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          )
          .listen((allExams) {
            if (!mounted) return;
            _allExams = allExams;
            _recomputePapers();
          }),
    );
  }

  void _recomputePapers() {
    int papers = 0;
    for (final e in _allExams) {
      if (e.teacher.id == widget.userId ||
          e.papers.any((p) => p.invigilator == widget.userId) ||
          e.papers.any((p) => _teacherSubjectIds.contains(p.subject))) {
        papers += e.papers.length;
      }
    }
    if (mounted) setState(() => _papersCount = papers);
  }

  @override
  void didUpdateWidget(covariant _TeacherQuickStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.userId != widget.userId ||
        oldWidget.term.year != widget.term.year ||
        oldWidget.term.term != widget.term.term) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuickStatRow(
      stats: [
        QuickStat(
          icon: Icons.menu_book_outlined,
          label: 'My Subjects',
          value: '$_subjectCount',
        ),
        QuickStat(
          icon: Icons.class_outlined,
          label: 'My Classes',
          value: '$_classCount',
        ),
        QuickStat(
          icon: Icons.calendar_view_week_rounded,
          label: 'Lessons/Week',
          value: '$_lessonsPerWeek',
        ),
        QuickStat(
          icon: Icons.assignment_outlined,
          label: 'My Exams',
          value: '$_papersCount',
        ),
      ],
    );
  }
}

// ── Teacher Class Chips ──────────────────────────────────────────────────────

class _TeacherClassChips extends StatefulWidget {
  const _TeacherClassChips({
    required this.schoolId,
    required this.userId,
    required this.term,
  });

  final String schoolId;
  final String userId;
  final Term term;

  @override
  State<_TeacherClassChips> createState() => _TeacherClassChipsState();
}

class _TeacherClassChipsState extends State<_TeacherClassChips> {
  late Future<List<SchoolStream>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }

  @override
  void didUpdateWidget(covariant _TeacherClassChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final membersDao = MembersDao(db);

    return StreamBuilder<List<ClassTeacher>>(
      stream: membersDao.watchClassTeacherAssignments(
        widget.schoolId,
        widget.userId,
      ),
      builder: (context, ctSnap) {
        if (ctSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        // Filter to current term + active (end == null) only
        final activeCt = (ctSnap.data ?? [])
            .where(
              (c) =>
                  c.year == widget.term.year &&
                  c.term == widget.term.term &&
                  c.end == null,
            )
            .toList();

        if (activeCt.isEmpty) {
          return _EmptyCard(
            icon: Icons.school_outlined,
            message: 'No class teacher assignments this term',
          );
        }

        // Sort by grade, then stream
        activeCt.sort((a, b) {
          final g = a.grade.compareTo(b.grade);
          return g != 0 ? g : a.stream.compareTo(b.stream);
        });

        return FutureBuilder<List<SchoolStream>>(
          future: _streamsFuture,
          builder: (context, streamsSnap) {
            final streamNames = <(int, int), String>{};
            for (final s in streamsSnap.data ?? []) {
              streamNames[(s.grade, s.stream)] = s.name;
            }

            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: activeCt.map((ct) {
                final streamName = streamNames[(ct.grade, ct.stream)];
                final label = gradeStreamLabel(
                  ct.grade,
                  streamName: streamName,
                );

                return _buildClassChip(
                  label: label,
                  subtitle: 'Class Teacher',
                  isPrimary: true,
                  cs: cs,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildClassChip({
    required String label,
    required String subtitle,
    required bool isPrimary,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPrimary
              ? cs.primary.withValues(alpha: 0.2)
              : cs.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isPrimary ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: isPrimary
                  ? cs.primary.withValues(alpha: 0.6)
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Teacher Upcoming Exams ───────────────────────────────────────────────────

class _TeacherUpcomingExams extends StatefulWidget {
  const _TeacherUpcomingExams({
    required this.schoolId,
    required this.userId,
    required this.term,
  });

  final String schoolId;
  final String userId;
  final Term term;

  @override
  State<_TeacherUpcomingExams> createState() => _TeacherUpcomingExamsState();
}

class _TeacherUpcomingExamsState extends State<_TeacherUpcomingExams> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
  }

  @override
  void didUpdateWidget(covariant _TeacherUpcomingExams oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examsDao = ExamsGradesDao(db);
    final membersDao = MembersDao(db);
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Outer stream: teacher's subject assignments for this term — drives
    // the wider "teaches subject" filter (aligned with _TeacherQuickStats).
    return StreamBuilder<List<SubjectTeacher>>(
      stream: membersDao.watchTeacherSubjectsForTerm(
        widget.schoolId,
        widget.userId,
        year: widget.term.year,
        term: widget.term.term,
      ),
      builder: (context, subjectsSnap) {
        final teacherSubjects = subjectsSnap.data ?? [];
        final teacherSubjectIds = teacherSubjects.map((s) => s.subject).toSet();

        return StreamBuilder<List<ExamWithPapers>>(
          stream: examsDao.watchExamsForTerm(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                subjectsSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingShimmer();
            }

            final allExams = snap.data ?? [];

            // Collect future papers where this teacher is relevant:
            //  • teacher is the invigilator, OR
            //  • teacher teaches the paper's subject, OR
            //  • teacher created the exam
            final upcoming = <({Exam exam, Paper paper})>[];
            for (final e in allExams) {
              for (final p in e.papers) {
                if (p.start > nowSeconds &&
                    (p.invigilator == widget.userId ||
                        teacherSubjectIds.contains(p.subject) ||
                        e.teacher.id == widget.userId)) {
                  upcoming.add((exam: e.exam, paper: p));
                }
              }
            }

            // Sort by paper start ascending (soonest first)
            upcoming.sort((a, b) => a.paper.start.compareTo(b.paper.start));

            if (upcoming.isEmpty) {
              return _EmptyCard(
                icon: Icons.assignment_outlined,
                message: 'No upcoming exams',
              );
            }

            final display = upcoming.take(3).toList();

            return FutureBuilder<List<Subject>>(
              future: _subjectsFuture,
              builder: (context, subSnap) {
                final subjectMap = <int, String>{};
                for (final s in subSnap.data ?? []) {
                  subjectMap[s.id] = s.name;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < display.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: cs.outline.withValues(alpha: 0.06),
                          ),
                        _buildExamRow(
                          examName: display[i].exam.name,
                          subjectName:
                              subjectMap[display[i].paper.subject] ??
                              'Subject ${display[i].paper.subject}',
                          paperStart: display[i].paper.start,
                          status: display[i].paper.status,
                          cs: cs,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExamRow({
    required String examName,
    required String subjectName,
    required BigInt paperStart,
    required PaperStatus status,
    required ColorScheme cs,
  }) {
    final (statusLabel, statusColor) = switch (status) {
      PaperStatus.pending => ('Pending', const Color(0xFFFFA726)),
      PaperStatus.progress => ('In Progress', const Color(0xFF42A5F5)),
      PaperStatus.done => ('Done', const Color(0xFF4CAF50)),
      PaperStatus.marked => ('Marked', const Color(0xFF7C4DFF)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
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
                  '$subjectName · ${_fmtDateFromSeconds(paperStart)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAFF OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

bool _hasAnyStatPermission(SchoolPermissions perms) {
  return perms.can(Resource.students, Action.read) ||
      perms.can(Resource.teachers, Action.read) ||
      perms.can(Resource.staff, Action.read) ||
      perms.can(Resource.fees, Action.read) ||
      perms.can(Resource.payments, Action.read) ||
      perms.can(Resource.exams, Action.read) ||
      perms.can(Resource.classes, Action.read);
}

class _StaffOverview extends StatelessWidget {
  const _StaffOverview({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final perms = schoolContext.permissions;
    final school = schoolContext.membership.school;
    final schoolId = school.id;
    final term = termContext.currentTerm;
    final userName = cache.currentUser?.user.name ?? 'Staff';

    // Check if staff has ANY meaningful permission at all
    final hasAnyPermission =
        _hasAnyStatPermission(perms) ||
        perms.can(Resource.announcements, Action.read) ||
        perms.can(Resource.roles, Action.read) ||
        perms.can(Resource.attendance, Action.read) ||
        perms.can(Resource.attendance, Action.mark);

    if (!hasAnyPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 26,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No roles assigned',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your school administrator hasn\'t assigned any roles to your account yet. '
                'Once roles are assigned, your dashboard will show the relevant features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _StaggeredList(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Welcome ──────────────────────────────────────────────────────
        _WelcomeCard(name: userName, subtitle: school.name, cs: cs),

        const SizedBox(height: 20),

        // ── Quick actions (permission-gated) ─────────────────────────────
        if (perms.can(Resource.payments, Action.create) ||
            perms.can(Resource.fees, Action.read)) ...[
          _SectionTitle(label: 'Quick Actions', cs: cs),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (perms.can(Resource.payments, Action.create))
                _QuickActionChip(
                  icon: Icons.payments_rounded,
                  label: 'Record Payment',
                  color: Colors.green,
                  onTap: () => DashboardNavigation.goToTab(context, 'Finance'),
                ),
              if (perms.can(Resource.fees, Action.read))
                _QuickActionChip(
                  icon: Icons.search_rounded,
                  label: 'Check Balance',
                  color: Colors.orange,
                  onTap: () => DashboardNavigation.goToTab(context, 'Finance'),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // ── Today's collection (permission-gated) ────────────────────────
        if (term != null && perms.can(Resource.fees, Action.read)) ...[
          StreamBuilder<TermFinanceSummary>(
            stream: FinanceDao(db).watchTermFinanceSummary(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
            ),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final s = snap.data!;
              final collected = fmtCurrency(s.totalPaid);
              return TodayStatusCard(
                type: s.collectionRate >= 0.70
                    ? TodayStatusType.positive
                    : s.collectionRate >= 0.40
                    ? TodayStatusType.warning
                    : TodayStatusType.negative,
                icon: Icons.account_balance_rounded,
                title: '$collected collected',
                subtitle:
                    '${s.paidCount} paid · ${s.pendingCount} pending · ${s.overdueCount} overdue',
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        // ── Quick stats (permission-gated) ───────────────────────────────
        if (term != null &&
            _hasAnyStatPermission(schoolContext.permissions)) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _StaffQuickStats(
            schoolId: schoolId,
            term: term,
            permissions: schoolContext.permissions,
          ),
          const SizedBox(height: 20),
        ],

        // ── Limited access hint ──────────────────────────────────────────
        if (term == null ||
            !_hasAnyStatPermission(schoolContext.permissions)) ...[
          const SizedBox(height: 12),
          Text(
            'Your dashboard shows features based on your assigned role.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Recent announcements (permission-gated) ──────────────────────
        if (schoolContext.permissions.can(
          Resource.announcements,
          Action.read,
        )) ...[
          _SectionTitle(
            label: 'Recent Announcements',
            cs: cs,
            onViewAll: () =>
                DashboardNavigation.goToTab(context, 'Announcements'),
          ),
          const SizedBox(height: 8),
          _RecentAnnouncements(
            schoolId: schoolId,
            audienceBit: AudienceBits.staff,
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

class _StaffQuickStats extends StatefulWidget {
  const _StaffQuickStats({
    required this.schoolId,
    required this.term,
    required this.permissions,
  });

  final String schoolId;
  final Term term;
  final SchoolPermissions permissions;

  @override
  State<_StaffQuickStats> createState() => _StaffQuickStatsState();
}

class _StaffQuickStatsState extends State<_StaffQuickStats> {
  StreamSubscription<TermFinanceSummary>? _financeSub;
  TermFinanceSummary? _financeSummary;

  bool get _canFinance =>
      widget.permissions.can(Resource.fees, Action.read) ||
      widget.permissions.can(Resource.payments, Action.read);

  @override
  void initState() {
    super.initState();
    _subscribeFinance();
  }

  void _subscribeFinance() {
    _financeSub?.cancel();
    _financeSummary = null;
    if (!_canFinance) return;
    _financeSub = FinanceDao(db)
        .watchTermFinanceSummary(
          schoolId: widget.schoolId,
          year: widget.term.year,
          term: widget.term.term,
        )
        .listen((summary) {
          if (mounted) setState(() => _financeSummary = summary);
        });
  }

  @override
  void didUpdateWidget(covariant _StaffQuickStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.term.year != widget.term.year ||
        oldWidget.term.term != widget.term.term ||
        oldWidget.permissions != widget.permissions) {
      _subscribeFinance();
    }
  }

  @override
  void dispose() {
    _financeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersDao = MembersDao(db);
    final canFinance = _canFinance;

    final cards = <Widget>[];

    // ── Students count ─────────────────────────────────────────────────
    if (widget.permissions.can(Resource.students, Action.read)) {
      cards.add(
        StreamBuilder<List<StudentsData>>(
          stream: membersDao.watchStudents(widget.schoolId),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return _StatCard(
              icon: Icons.groups_outlined,
              label: 'Students',
              value: '$count',
              tint: const Color(0xFF3F51B5),
            );
          },
        ),
      );
    }

    // ── Teachers count ─────────────────────────────────────────────────
    if (widget.permissions.can(Resource.teachers, Action.read)) {
      cards.add(
        StreamBuilder<List<TeachersData>>(
          stream: membersDao.watchTeachers(widget.schoolId),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return _StatCard(
              icon: Icons.school_outlined,
              label: 'Teachers',
              value: '$count',
              tint: const Color(0xFF009688),
            );
          },
        ),
      );
    }

    // ── Staff count ────────────────────────────────────────────────────
    if (widget.permissions.can(Resource.staff, Action.read)) {
      cards.add(
        StreamBuilder<List<StaffData>>(
          stream: membersDao.watchStaff(widget.schoolId),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return _StatCard(
              icon: Icons.badge_outlined,
              label: 'Staff',
              value: '$count',
              tint: const Color(0xFFFF9800),
            );
          },
        ),
      );
    }

    // ── Finance (single subscription) ──────────────────────────────────
    if (canFinance) {
      final summary = _financeSummary;
      cards.add(
        _StatCard(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices',
          value: summary != null ? '${summary.invoiceCount}' : '—',
          tint: const Color(0xFFFF9800),
        ),
      );
      cards.add(
        _StatCard(
          icon: Icons.account_balance_outlined,
          label: 'Collection',
          value: summary != null
              ? '${summary.collectionRate.toStringAsFixed(0)}%'
              : '—',
          tint: const Color(0xFF4CAF50),
        ),
      );
      cards.add(
        _StatCard(
          icon: Icons.pending_actions_outlined,
          label: 'Pending',
          value: summary != null ? '${summary.pendingCount}' : '—',
          tint: const Color(0xFFF44336),
        ),
      );
    }

    // ── Active exams ───────────────────────────────────────────────────
    if (widget.permissions.can(Resource.exams, Action.read)) {
      cards.add(
        StreamBuilder<List<ExamWithPapers>>(
          stream: ExamsGradesDao(db).watchExamsForTerm(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          ),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return _StatCard(
              icon: Icons.assignment_outlined,
              label: 'Exams',
              value: '$count',
              tint: const Color(0xFF7C4DFF),
            );
          },
        ),
      );
    }

    // ── Classes count ──────────────────────────────────────────────────
    if (widget.permissions.can(Resource.classes, Action.read)) {
      cards.add(
        StreamBuilder<List<({int grade, int stream})>>(
          stream: EnrollmentsDao(db).watchPopulatedClasses(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
          ),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return _StatCard(
              icon: Icons.class_outlined,
              label: 'Classes',
              value: '$count',
              tint: const Color(0xFF7C4DFF),
            );
          },
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    // ── Arrange in 2-column grid ───────────────────────────────────────
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i + 1 < cards.length) {
        rows.add(
          Row(
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 10),
              Expanded(child: cards[i + 1]),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      }
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STUDENT OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _StudentOverview extends StatelessWidget {
  const _StudentOverview({
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final studentAdm = entry.student.adm;
    final studentName = entry.student.name;

    return _StaggeredList(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Welcome ──────────────────────────────────────────────────────
        _WelcomeCard(name: studentName, subtitle: 'Student', cs: cs),

        const SizedBox(height: 16),

        // ── Today's attendance status ────────────────────────────────────
        if (term != null) ...[
          _StudentTodayAttendance(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
            studentName: studentName,
          ),
          const SizedBox(height: 12),
        ],

        // ── Next class countdown ─────────────────────────────────────────
        if (term != null) ...[
          _StudentNextClass(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 16),
        ],

        // ── Enrollment info ──────────────────────────────────────────────
        if (term != null) ...[
          _StudentEnrollmentInfo(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 16),
        ],

        // ── Today's schedule ─────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: "Today's Schedule",
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Timetable'),
          ),
          const SizedBox(height: 8),
          _StudentTodaySchedule(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 20),
        ],

        // ── Recent grades ────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: 'Recent Grades',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Grades'),
          ),
          const SizedBox(height: 8),
          _StudentRecentGrades(schoolId: schoolId, studentAdm: studentAdm),
          const SizedBox(height: 20),
        ],

        // ── Upcoming exams ───────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: 'Upcoming Exams',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Exams'),
          ),
          const SizedBox(height: 8),
          _StudentUpcomingExams(
            schoolId: schoolId,
            term: term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 20),
        ],

        // ── Attendance summary ───────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: 'Attendance',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Attendance'),
          ),
          const SizedBox(height: 8),
          _StudentAttendanceSummary(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(
          label: 'Recent Announcements',
          cs: cs,
          onViewAll: () =>
              DashboardNavigation.goToTab(context, 'Announcements'),
        ),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.students,
          studentAdm: studentAdm,
          termYear: term?.year,
          termNum: term?.term,
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _StudentNextClass extends StatelessWidget {
  const _StudentNextClass({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        if (!enrollSnap.hasData || enrollSnap.data == null) {
          return const SizedBox.shrink();
        }
        final enrollment = enrollSnap.data!;

        return StreamBuilder<List<TimetableEntry>>(
          stream: TimetableDao(db).watchClassTimetable(
            schoolId: schoolId,
            year: year,
            term: term,
            grade: enrollment.grade,
            stream: enrollment.stream,
          ),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();

            final todayDay = _currentDayOfWeek();
            final now = DateTime.now();
            final nowSec = now.hour * 3600 + now.minute * 60 + now.second;

            final todaySlots =
                snap.data!
                    .where((e) => e.slot.day == todayDay && e.slot.end > nowSec)
                    .toList()
                  ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

            if (todaySlots.isEmpty) return const SizedBox.shrink();

            final next = todaySlots.firstWhere(
              (e) => e.slot.start > nowSec,
              orElse: () => todaySlots.first,
            );

            final isInProgress =
                next.slot.start <= nowSec && next.slot.end > nowSec;

            if (isInProgress) {
              return TodayStatusCard(
                type: TodayStatusType.positive,
                icon: Icons.play_circle_rounded,
                title: '${next.subjectName} in progress',
                subtitle:
                    '${_fmtTime(next.slot.start)} – ${_fmtTime(next.slot.end)}',
                trailing: CountdownChip(
                  label: 'Ends',
                  targetTime: _todayAtSeconds(next.slot.end),
                  icon: Icons.timer_outlined,
                  compact: true,
                ),
              );
            }

            return TodayStatusCard(
              type: TodayStatusType.neutral,
              icon: Icons.schedule_rounded,
              title: 'Next: ${next.subjectName}',
              subtitle:
                  '${_fmtTime(next.slot.start)} – ${_fmtTime(next.slot.end)}',
              trailing: CountdownChip(
                label: 'Starts',
                targetTime: _todayAtSeconds(next.slot.start),
                icon: Icons.timer_outlined,
                compact: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentTodayAttendance extends StatelessWidget {
  const _StudentTodayAttendance({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
    required this.studentName,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        if (!enrollSnap.hasData || enrollSnap.data == null) {
          return const SizedBox.shrink();
        }
        final enrollment = enrollSnap.data!;
        final todayDays = DateTime.now()
            .toUtc()
            .difference(DateTime.utc(1970, 1, 1))
            .inDays;

        return StreamBuilder<List<StudentAttendanceRow>>(
          stream: AttendanceDao(db).watchClassAttendance(
            schoolId: schoolId,
            year: year,
            term: term,
            grade: enrollment.grade,
            stream: enrollment.stream,
            date: todayDays,
          ),
          builder: (context, attSnap) {
            if (!attSnap.hasData) {
              return TodayStatusCard(
                type: TodayStatusType.neutral,
                icon: Icons.schedule_rounded,
                title: 'Checking attendance...',
              );
            }

            final myRecord = attSnap.data!
                .where((r) => r.student.adm == studentAdm)
                .firstOrNull;

            if (myRecord == null || !myRecord.isMarked) {
              return TodayStatusCard(
                type: TodayStatusType.neutral,
                icon: Icons.hourglass_empty_rounded,
                title: 'Attendance not yet taken',
                subtitle: 'Your class hasn\'t been marked today',
              );
            }

            final status = myRecord.effectiveStatus;
            final isPresent = status == AttendanceStatus.present;
            final isAbsent = status == AttendanceStatus.absent;

            return TodayStatusCard(
              type: isPresent
                  ? TodayStatusType.positive
                  : isAbsent
                  ? TodayStatusType.negative
                  : TodayStatusType.warning,
              icon: isPresent
                  ? Icons.check_circle_rounded
                  : isAbsent
                  ? Icons.cancel_rounded
                  : Icons.info_rounded,
              title: isPresent
                  ? 'You are marked present today'
                  : isAbsent
                  ? 'You are marked absent today'
                  : 'You are on leave today',
            );
          },
        );
      },
    );
  }
}

class _StudentUpcomingExams extends StatefulWidget {
  const _StudentUpcomingExams({
    required this.schoolId,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final Term term;
  final int studentAdm;

  @override
  State<_StudentUpcomingExams> createState() => _StudentUpcomingExamsState();
}

class _StudentUpcomingExamsState extends State<_StudentUpcomingExams> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
  }

  @override
  void didUpdateWidget(covariant _StudentUpcomingExams oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: widget.schoolId,
        year: widget.term.year,
        term: widget.term.term,
        studentAdm: widget.studentAdm,
      ),
      builder: (context, enrollSnap) {
        if (!enrollSnap.hasData || enrollSnap.data == null) {
          return _EmptyCard(
            icon: Icons.assignment_outlined,
            message: 'No upcoming exams',
          );
        }
        final enrollment = enrollSnap.data!;

        return StreamBuilder<List<ExamWithPapers>>(
          stream: ExamsGradesDao(db).watchExamsForClass(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
            grade: enrollment.grade,
            stream: enrollment.stream,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingShimmer();
            }

            final allExams = snap.data ?? [];
            final upcoming = <({Exam exam, Paper paper})>[];
            for (final e in allExams) {
              for (final p in e.papers) {
                if (p.start > nowSeconds &&
                    p.grade == enrollment.grade &&
                    (p.stream == null || p.stream == enrollment.stream)) {
                  upcoming.add((exam: e.exam, paper: p));
                }
              }
            }

            upcoming.sort((a, b) => a.paper.start.compareTo(b.paper.start));

            if (upcoming.isEmpty) {
              return _EmptyCard(
                icon: Icons.assignment_outlined,
                message: 'No upcoming exams',
              );
            }

            final display = upcoming.take(3).toList();

            return FutureBuilder<List<Subject>>(
              future: _subjectsFuture,
              builder: (context, subSnap) {
                final subjectMap = <int, String>{};
                for (final s in subSnap.data ?? []) {
                  subjectMap[s.id] = s.name;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < display.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: cs.outline.withValues(alpha: 0.06),
                          ),
                        _buildExamRow(
                          examName: display[i].exam.name,
                          subjectName:
                              subjectMap[display[i].paper.subject] ??
                              'Subject ${display[i].paper.subject}',
                          paperStart: display[i].paper.start,
                          cs: cs,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExamRow({
    required String examName,
    required String subjectName,
    required BigInt paperStart,
    required ColorScheme cs,
  }) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paperStart.toInt() * 1000,
      isUtc: true,
    ).toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
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
                  '$subjectName · ${_fmtDateFromSeconds(paperStart)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          CountdownChip(
            label: subjectName,
            targetTime: startDt,
            icon: Icons.access_time_rounded,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _StudentEnrollmentInfo extends StatefulWidget {
  const _StudentEnrollmentInfo({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;

  @override
  State<_StudentEnrollmentInfo> createState() => _StudentEnrollmentInfoState();
}

class _StudentEnrollmentInfoState extends State<_StudentEnrollmentInfo> {
  late Future<List<SchoolStream>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }

  @override
  void didUpdateWidget(covariant _StudentEnrollmentInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enrollmentsDao = EnrollmentsDao(db);

    return StreamBuilder<Enrollment?>(
      stream: enrollmentsDao.watchStudentEnrollment(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        studentAdm: widget.studentAdm,
      ),
      builder: (context, snap) {
        final enrollment = snap.data;
        if (enrollment == null) {
          return _EmptyCard(
            icon: Icons.info_outline_rounded,
            message: 'Not enrolled in any class this term',
          );
        }

        return FutureBuilder<List<SchoolStream>>(
          future: _streamsFuture,
          builder: (context, strSnap) {
            final streamMap = <(int, int), String>{};
            for (final s in strSnap.data ?? []) {
              streamMap[(s.grade, s.stream)] = s.name;
            }
            final streamName = streamMap[(enrollment.grade, enrollment.stream)];
            final label = gradeStreamLabel(
              enrollment.grade,
              streamName: streamName,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 18,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ADM: ${widget.studentAdm}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentTodaySchedule extends StatelessWidget {
  const _StudentTodaySchedule({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final enrollmentsDao = EnrollmentsDao(db);

    return StreamBuilder<Enrollment?>(
      stream: enrollmentsDao.watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        final enrollment = enrollSnap.data;
        if (enrollment == null) {
          return _EmptyCard(
            icon: Icons.event_available_outlined,
            message: 'No class enrollment found',
          );
        }

        final timetableDao = TimetableDao(db);
        return StreamBuilder<List<TimetableEntry>>(
          stream: timetableDao.watchClassTimetable(
            schoolId: schoolId,
            year: year,
            term: term,
            grade: enrollment.grade,
            stream: enrollment.stream,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingShimmer();
            }

            final allSlots = snap.data ?? [];
            final todayDay = _currentDayOfWeek();
            final todaySlots =
                allSlots.where((e) => e.slot.day == todayDay).toList()
                  ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

            if (todaySlots.isEmpty) {
              return _EmptyCard(
                icon: Icons.event_available_outlined,
                message: 'No classes scheduled today',
              );
            }

            return Column(
              children: todaySlots.map((e) {
                return _StudentTimetableSlotCard(entry: e);
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _StudentTimetableSlotCard extends StatelessWidget {
  const _StudentTimetableSlotCard({required this.entry});

  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final slot = entry.slot;
    final teacher = entry.teacher;
    final color = _subjectColor(slot.subject);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.subjectName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teacher.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_fmtTime(slot.start)} – ${_fmtTime(slot.end)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRecentGrades extends StatefulWidget {
  const _StudentRecentGrades({
    required this.schoolId,
    required this.studentAdm,
  });

  final String schoolId;
  final int studentAdm;

  @override
  State<_StudentRecentGrades> createState() => _StudentRecentGradesState();
}

class _StudentRecentGradesState extends State<_StudentRecentGrades> {
  final Map<String, Future<Exam?>> _examCache = {};

  Future<Exam?> _getExam(String examId) {
    return _examCache.putIfAbsent(
      examId,
      () => ExamsGradesDao(db).getExam(examId),
    );
  }

  @override
  void didUpdateWidget(covariant _StudentRecentGrades oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.studentAdm != widget.studentAdm) {
      _examCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examsDao = ExamsGradesDao(db);

    return StreamBuilder<List<Grade>>(
      stream: examsDao.watchStudentGrades(widget.schoolId, widget.studentAdm),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final allGrades = snap.data ?? [];
        if (allGrades.isEmpty) {
          return _EmptyCard(
            icon: Icons.assignment_outlined,
            message: 'No exam results yet',
          );
        }

        // Get subject-level totals (paper == null) grouped by exam, take last 3 exams
        final byExam = <String, List<Grade>>{};
        for (final g in allGrades) {
          if (g.paper != null) continue; // only subject-level totals
          (byExam[g.exam] ??= []).add(g);
        }

        // If no subject-level totals, fall back to all grades
        if (byExam.isEmpty) {
          for (final g in allGrades) {
            (byExam[g.exam] ??= []).add(g);
          }
        }

        final examIds = byExam.keys.toList();
        // Sort by the latest grade created date in each group (desc)
        examIds.sort((a, b) {
          final aMax = byExam[a]!
              .map((g) => g.created)
              .reduce((v, e) => v > e ? v : e);
          final bMax = byExam[b]!
              .map((g) => g.created)
              .reduce((v, e) => v > e ? v : e);
          return bMax.compareTo(aMax);
        });

        final recentExamIds = examIds.take(3).toList();

        return Column(
          children: recentExamIds.map((examId) {
            final grades = byExam[examId]!;
            final totalScore = grades.fold<double>(
              0,
              (sum, g) => sum + g.score,
            );
            final totalMax = grades.fold<double>(0, (sum, g) => sum + g.total);
            final pct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

            return FutureBuilder<Exam?>(
              future: _getExam(examId),
              builder: (context, examSnap) {
                final examName = examSnap.data?.name ?? 'Exam';
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
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  examName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${grades.length} subject${grades.length == 1 ? '' : 's'} · ${totalScore.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _PercentBadge(percent: pct, cs: cs),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _StudentAttendanceSummary extends StatelessWidget {
  const _StudentAttendanceSummary({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final attendanceDao = AttendanceDao(db);

    return StreamBuilder<({int totalDays, int present, int absent, int leave})>(
      stream: attendanceDao.watchStudentAttendanceSummary(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final data = snap.data;
        if (data == null || data.totalDays == 0) {
          return _EmptyCard(
            icon: Icons.calendar_today_outlined,
            message: 'No attendance records this term',
          );
        }

        final presentPct = data.totalDays > 0
            ? (data.present / data.totalDays * 100)
            : 0.0;

        return _AttendanceBar(
          present: data.present,
          absent: data.absent,
          leave: data.leave,
          totalDays: data.totalDays,
          presentPercent: presentPct,
          cs: cs,
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GUARDIAN OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _GuardianOverview extends StatelessWidget {
  const _GuardianOverview({
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final GuardianEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final ward = entry.ward;
    final userName = cache.currentUser?.user.name ?? 'Guardian';

    return _StaggeredList(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── 1. Welcome ───────────────────────────────────────────────────
        _WelcomeCard(name: userName, subtitle: 'Guardian', cs: cs),

        const SizedBox(height: 16),

        // ── 1b. Ward attendance status ───────────────────────────────────
        if (term != null)
          StreamBuilder<Enrollment?>(
            stream: EnrollmentsDao(db).watchStudentEnrollment(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: ward.adm,
            ),
            builder: (context, enrollSnap) {
              if (!enrollSnap.hasData || enrollSnap.data == null) {
                return const SizedBox.shrink();
              }
              final enrollment = enrollSnap.data!;
              final todayDays = DateTime.now()
                  .toUtc()
                  .difference(DateTime.utc(1970, 1, 1))
                  .inDays;

              return StreamBuilder<List<StudentAttendanceRow>>(
                stream: AttendanceDao(db).watchClassAttendance(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                  grade: enrollment.grade,
                  stream: enrollment.stream,
                  date: todayDays,
                ),
                builder: (context, attSnap) {
                  if (!attSnap.hasData) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TodayStatusCard(
                        type: TodayStatusType.neutral,
                        icon: Icons.schedule_rounded,
                        title: 'Checking attendance...',
                      ),
                    );
                  }

                  final wardRecord = attSnap.data!
                      .where((r) => r.student.adm == ward.adm)
                      .firstOrNull;

                  if (wardRecord == null || !wardRecord.isMarked) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TodayStatusCard(
                        type: TodayStatusType.neutral,
                        icon: Icons.hourglass_empty_rounded,
                        title: 'Attendance not yet taken',
                        subtitle:
                            '${ward.name}\'s class hasn\'t been marked today',
                      ),
                    );
                  }

                  final status = wardRecord.effectiveStatus;
                  final isPresent = status == AttendanceStatus.present;
                  final isAbsent = status == AttendanceStatus.absent;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TodayStatusCard(
                      type: isPresent
                          ? TodayStatusType.positive
                          : isAbsent
                          ? TodayStatusType.negative
                          : TodayStatusType.warning,
                      icon: isPresent
                          ? Icons.check_circle_rounded
                          : isAbsent
                          ? Icons.cancel_rounded
                          : Icons.info_rounded,
                      title: isPresent
                          ? '${ward.name} is present today'
                          : isAbsent
                          ? '${ward.name} is absent today'
                          : '${ward.name} is on leave today',
                    ),
                  );
                },
              );
            },
          ),

        // ── 2. Ward info (enhanced) ──────────────────────────────────────
        _WardInfoCard(ward: ward, schoolId: schoolId, term: term),

        const SizedBox(height: 16),

        // ── Unenrolled ward banner ───────────────────────────────────────
        if (term != null)
          StreamBuilder<Enrollment?>(
            stream: EnrollmentsDao(db).watchStudentEnrollment(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: ward.adm,
            ),
            builder: (context, snap) {
              // Don't show banner while loading or if enrollment exists.
              if (snap.connectionState == ConnectionState.waiting ||
                  snap.data != null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ward.name} is not enrolled this term',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Please contact the school for enrollment details.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // ── 3. Quick stats (2×2 grid) ────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _GuardianQuickStats(
            schoolId: schoolId,
            term: term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 4. Today's schedule ──────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: "Today's Schedule",
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Timetable'),
          ),
          const SizedBox(height: 8),
          _StudentTodaySchedule(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 5. Attendance summary ────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: 'Attendance',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Attendance'),
          ),
          const SizedBox(height: 8),
          _StudentAttendanceSummary(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 6. Recent grades ─────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: 'Recent Grades',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Progress'),
          ),
          const SizedBox(height: 8),
          _StudentRecentGrades(schoolId: schoolId, studentAdm: ward.adm),
          const SizedBox(height: 20),
        ],

        // ── 7. Finance summary ───────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(
            label: 'Finance',
            cs: cs,
            onViewAll: () => DashboardNavigation.goToTab(context, 'Finance'),
          ),
          const SizedBox(height: 8),
          _GuardianFinanceSummary(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 8. Recent announcements ──────────────────────────────────────
        _SectionTitle(
          label: 'Recent Announcements',
          cs: cs,
          onViewAll: () =>
              DashboardNavigation.goToTab(context, 'Announcements'),
        ),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.guardians,
          studentAdm: ward.adm,
          termYear: term?.year,
          termNum: term?.term,
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _GuardianQuickStats extends StatelessWidget {
  const _GuardianQuickStats({
    required this.schoolId,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final Term term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final attendanceDao = AttendanceDao(db);
    final examsDao = ExamsGradesDao(db);
    final enrollmentsDao = EnrollmentsDao(db);
    final academicsDao = AcademicsDao(db);

    return LayoutBuilder(
      builder: (context, constraints) {
        final statWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // ── Attendance % ─────────────────────────────────────────────
            SizedBox(
              width: statWidth,
              child:
                  StreamBuilder<
                    ({int totalDays, int present, int absent, int leave})
                  >(
                    stream: attendanceDao.watchStudentAttendanceSummary(
                      schoolId: schoolId,
                      year: term.year,
                      term: term.term,
                      studentAdm: studentAdm,
                    ),
                    builder: (context, snap) {
                      final data = snap.data;
                      final pct = (data != null && data.totalDays > 0)
                          ? (data.present / data.totalDays * 100)
                          : null;
                      return _StatCard(
                        icon: Icons.calendar_today_outlined,
                        label: 'Attendance',
                        value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
                        tint: pct != null
                            ? _pctColor(pct)
                            : const Color(0xFF607D8B),
                      );
                    },
                  ),
            ),

            // ── Latest exam average ──────────────────────────────────────
            SizedBox(
              width: statWidth,
              child: StreamBuilder<List<Grade>>(
                stream: examsDao.watchStudentGrades(schoolId, studentAdm),
                builder: (context, snap) {
                  final allGrades = snap.data ?? [];
                  final byExam = <String, List<Grade>>{};
                  for (final g in allGrades) {
                    if (g.paper != null) continue;
                    (byExam[g.exam] ??= []).add(g);
                  }
                  double? pct;
                  if (byExam.isNotEmpty) {
                    final latestExamId = byExam.keys.reduce((a, b) {
                      final aMax = byExam[a]!
                          .map((g) => g.created)
                          .reduce((v, e) => v > e ? v : e);
                      final bMax = byExam[b]!
                          .map((g) => g.created)
                          .reduce((v, e) => v > e ? v : e);
                      return aMax > bMax ? a : b;
                    });
                    final grades = byExam[latestExamId]!;
                    final totalScore = grades.fold<double>(
                      0,
                      (s, g) => s + g.score,
                    );
                    final totalMax = grades.fold<double>(
                      0,
                      (s, g) => s + g.total,
                    );
                    if (totalMax > 0) pct = totalScore / totalMax * 100;
                  }
                  return _StatCard(
                    icon: Icons.assignment_outlined,
                    label: 'Latest Exam',
                    value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
                    tint: pct != null
                        ? _pctColor(pct)
                        : const Color(0xFF607D8B),
                  );
                },
              ),
            ),

            // ── Subjects count ───────────────────────────────────────────
            SizedBox(
              width: statWidth,
              child: StreamBuilder<Enrollment?>(
                stream: enrollmentsDao.watchStudentEnrollment(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                  studentAdm: studentAdm,
                ),
                builder: (context, enrollSnap) {
                  final enrollment = enrollSnap.data;
                  if (enrollment == null) {
                    return _StatCard(
                      icon: Icons.menu_book_outlined,
                      label: 'Subjects',
                      value: '—',
                      tint: const Color(0xFF7C4DFF),
                    );
                  }
                  return StreamBuilder<List<SubjectTeacherEntry>>(
                    stream: academicsDao.watchSubjectsForGrade(
                      schoolId: schoolId,
                      year: term.year,
                      term: term.term,
                      grade: enrollment.grade,
                      stream: enrollment.stream,
                    ),
                    builder: (context, subSnap) {
                      final count = subSnap.data?.length ?? 0;
                      return _StatCard(
                        icon: Icons.menu_book_outlined,
                        label: 'Subjects',
                        value: '$count',
                        tint: const Color(0xFF7C4DFF),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Mastery % ───────────────────────────────────────────────
            SizedBox(
              width: statWidth,
              child: StreamBuilder<List<MasteryData>>(
                stream: examsDao.watchMasteryForStudent(
                  schoolId: schoolId,
                  studentAdm: studentAdm,
                ),
                builder: (context, snap) {
                  final masteryRows = snap.data ?? [];
                  double? avgPct;
                  if (masteryRows.isNotEmpty) {
                    final totalScore = masteryRows.fold<double>(
                      0,
                      (s, m) => s + m.score,
                    );
                    avgPct = totalScore / masteryRows.length;
                  }
                  return _StatCard(
                    icon: Icons.psychology_outlined,
                    label: 'Mastery',
                    value: avgPct != null
                        ? '${avgPct.toStringAsFixed(0)}%'
                        : '—',
                    tint: avgPct != null
                        ? _pctColor(avgPct)
                        : const Color(0xFF607D8B),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WardInfoCard extends StatefulWidget {
  const _WardInfoCard({
    required this.ward,
    required this.schoolId,
    required this.term,
  });

  final StudentsData ward;
  final String schoolId;
  final Term? term;

  @override
  State<_WardInfoCard> createState() => _WardInfoCardState();
}

class _WardInfoCardState extends State<_WardInfoCard> {
  late Future<List<SchoolStream>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }

  @override
  void didUpdateWidget(covariant _WardInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          StudentAvatar(
            schoolId: widget.schoolId,
            adm: widget.ward.adm,
            name: widget.ward.name,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ward.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ADM: ${widget.ward.adm}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (widget.term != null)
            StreamBuilder<Enrollment?>(
              stream: EnrollmentsDao(db).watchStudentEnrollment(
                schoolId: widget.schoolId,
                year: widget.term!.year,
                term: widget.term!.term,
                studentAdm: widget.ward.adm,
              ),
              builder: (context, snap) {
                final enrollment = snap.data;
                if (enrollment == null) return const SizedBox.shrink();
                return FutureBuilder<List<SchoolStream>>(
                  future: _streamsFuture,
                  builder: (context, strSnap) {
                    final streamMap = <(int, int), String>{};
                    for (final s in strSnap.data ?? []) {
                      streamMap[(s.grade, s.stream)] = s.name;
                    }
                    final streamName =
                        streamMap[(enrollment.grade, enrollment.stream)];
                    final label = gradeStreamLabel(
                      enrollment.grade,
                      streamName: streamName,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _GuardianFinanceSummary extends StatelessWidget {
  const _GuardianFinanceSummary({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final financeDao = FinanceDao(db);

    return StreamBuilder<StudentFinanceSummary>(
      stream: financeDao.watchStudentFinanceSummary(
        schoolId: schoolId,
        studentAdm: studentAdm,
        year: year,
        term: term,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final data = snap.data;
        if (data == null || data.invoices.isEmpty) {
          return _EmptyCard(
            icon: Icons.receipt_long_outlined,
            message: 'No invoices this term',
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _FinanceRow(
                label: 'Total Invoiced',
                value: _fmtCurrency(data.totalInvoiced),
                cs: cs,
              ),
              const SizedBox(height: 8),
              _FinanceRow(
                label: 'Total Paid',
                value: _fmtCurrency(data.totalPaid),
                cs: cs,
                valueColor: const Color(0xFF4CAF50),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              _FinanceRow(
                label: 'Balance',
                value: _fmtCurrency(data.totalBalance),
                cs: cs,
                valueColor: data.totalBalance > 0
                    ? const Color(0xFFF44336)
                    : const Color(0xFF4CAF50),
                bold: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.label,
    required this.value,
    required this.cs,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: bold ? 0.8 : 0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── School Identity Card ─────────────────────────────────────────────────────

class _SchoolIdentityCard extends StatelessWidget {
  const _SchoolIdentityCard({required this.school});

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

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
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
              _initials(name),
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

class _TermInfoCard extends StatelessWidget {
  const _TermInfoCard({required this.term, required this.cs});

  final Term term;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final start = _fmtDateFromSeconds(term.start);
    final end = _fmtDateFromSeconds(term.end);

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.cs, this.onViewAll});

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

class _StatCard extends StatelessWidget {
  const _StatCard({
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

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
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
              _AttendanceDot(
                color: const Color(0xFF4CAF50),
                label: 'Present',
                count: present,
                cs: cs,
              ),
              const SizedBox(width: 16),
              _AttendanceDot(
                color: const Color(0xFFF44336),
                label: 'Absent',
                count: absent,
                cs: cs,
              ),
              const SizedBox(width: 16),
              _AttendanceDot(
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
                  color: _pctColor(presentPercent),
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

class _AttendanceDot extends StatelessWidget {
  const _AttendanceDot({
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

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.percent, required this.cs});

  final double percent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = _pctColor(percent);

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

class _RecentAnnouncements extends StatelessWidget {
  const _RecentAnnouncements({
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
          return const _LoadingShimmer();
        }

        final all = snap.data ?? [];
        if (all.isEmpty) {
          return _EmptyCard(
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

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

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

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

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Converts seconds since midnight into a [DateTime] for today.
DateTime _todayAtSeconds(int secondsSinceMidnight) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(seconds: secondsSinceMidnight));
}

/// Returns the current day of the week as a [DayOfWeek] enum value.
DayOfWeek _currentDayOfWeek() {
  // DateTime.weekday: 1 = Monday … 7 = Sunday
  // DayOfWeek enum:  0 = Sunday, 1 = Monday … 6 = Saturday
  final wd = DateTime.now().weekday;
  return DayOfWeek.values[wd == 7 ? 0 : wd];
}

/// Formats seconds since midnight to "HH:MM" 24-hour.
String _fmtTime(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Formats a BigInt seconds-since-epoch to a readable date string.
String _fmtDateFromSeconds(BigInt secondsSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch.toInt() * 1000,
    isUtc: true,
  );
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
}

const _months = [
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
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Deterministic subject color from a 15-color palette.
Color _subjectColor(int subjectIndex) {
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
Color _pctColor(double pct) {
  if (pct >= 70) return const Color(0xFF4CAF50);
  if (pct >= 40) return const Color(0xFFFFC107);
  return const Color(0xFFF44336);
}

/// Formats a double amount as currency string.
String _fmtCurrency(double amount) {
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

// ── Quick Action Chip (Staff Overview) ───────────────────────────────────────

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
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
