import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/daos/members_dao.dart';

import '../../../../models/active_term_context.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../../models/school_permissions.dart';

import '../../../widgets/today_status_card.dart';
import '../../../../core/formatters.dart';
import '../school_dashboard_screen.dart';
import 'overview_shared.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STAFF OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

bool hasAnyStatPermission(SchoolPermissions perms) {
  return perms.can(Resource.students, Action.read) ||
      perms.can(Resource.teachers, Action.read) ||
      perms.can(Resource.staff, Action.read) ||
      perms.can(Resource.fees, Action.read) ||
      perms.can(Resource.payments, Action.read) ||
      perms.can(Resource.exams, Action.read) ||
      perms.can(Resource.classes, Action.read);
}

class StaffOverview extends StatelessWidget {
  const StaffOverview({
    super.key,
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
        hasAnyStatPermission(perms) ||
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
          // ── Welcome ──────────────────────────────────────────────────────
          WelcomeCard(name: userName, subtitle: school.name, cs: cs),

          const SizedBox(height: 20),

          // ── Quick actions (permission-gated) ─────────────────────────────
          if (perms.can(Resource.payments, Action.create) ||
              perms.can(Resource.fees, Action.read)) ...[
            SectionTitle(label: 'Quick Actions', cs: cs),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (perms.can(Resource.payments, Action.create) &&
                    (perms.can(Resource.fees, Action.read) ||
                        perms.can(Resource.payments, Action.read)))
                  QuickActionChip(
                    icon: Icons.payments_rounded,
                    label: 'Record Payment',
                    color: Colors.green,
                    onTap: () =>
                        DashboardNavigation.goToTab(context, 'Finance'),
                  ),
                if (perms.can(Resource.fees, Action.read))
                  QuickActionChip(
                    icon: Icons.search_rounded,
                    label: 'Check Balance',
                    color: Colors.orange,
                    onTap: () =>
                        DashboardNavigation.goToTab(context, 'Finance'),
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
              hasAnyStatPermission(schoolContext.permissions)) ...[
            SectionTitle(label: 'Quick Stats', cs: cs),
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
              !hasAnyStatPermission(schoolContext.permissions)) ...[
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
            SectionTitle(
              label: 'Recent Announcements',
              cs: cs,
              onViewAll: () =>
                  DashboardNavigation.goToTab(context, 'Announcements'),
            ),
            const SizedBox(height: 8),
            RecentAnnouncements(
              schoolId: schoolId,
              audienceBit: AudienceBits.staff,
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
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
            return StatCard(
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
            return StatCard(
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
            return StatCard(
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
        StatCard(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices',
          value: summary != null ? '${summary.invoiceCount}' : '—',
          tint: const Color(0xFFFF9800),
        ),
      );
      cards.add(
        StatCard(
          icon: Icons.account_balance_outlined,
          label: 'Collection',
          value: summary != null
              ? '${summary.collectionRate.toStringAsFixed(0)}%'
              : '—',
          tint: const Color(0xFF4CAF50),
        ),
      );
      cards.add(
        StatCard(
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
            return StatCard(
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
            return StatCard(
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
