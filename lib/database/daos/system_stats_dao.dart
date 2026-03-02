import 'dart:async';

import 'package:async/async.dart';
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/payments.dart';
import '../tables/plans.dart';
import '../tables/schools.dart';
import '../tables/students.dart';
import '../tables/subscriptions.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../../models/system_stats.dart';

part 'system_stats_dao.g.dart';

/// DAO that provides reactive statistical streams for the system dashboard.
///
/// All streams are driven by [StreamGroup] merges over the relevant
/// table-update notifications, so they re-emit whenever underlying data changes.
///
/// The streams always include all counts (including deleted) — the UI layer
/// decides what to show based on the current user's [UserLevel].
@DriftAccessor(
  tables: [Users, Schools, Students, Plans, Subscriptions, Teachers, Payments],
)
class SystemStatsDao extends DatabaseAccessor<AppDatabase>
    with _$SystemStatsDaoMixin {
  SystemStatsDao(super.db);

  // ---------------------------------------------------------------------------
  // Public reactive streams
  // ---------------------------------------------------------------------------

  /// Emits [UserStats] (counts per [UserStatus]) whenever the `users` table
  /// changes. Emits the current state immediately on first subscription.
  Stream<UserStats> watchUserStats() async* {
    yield await _fetchUserStats();

    final changes = db.tableUpdates(TableUpdateQuery.onTable(db.users));
    await for (final _ in changes) {
      yield await _fetchUserStats();
    }
  }

  /// Emits [SchoolStats] (counts per [SchoolStatus]) whenever the `schools`
  /// table changes. Emits the current state immediately on first subscription.
  Stream<SchoolStats> watchSchoolStats() async* {
    yield await _fetchSchoolStats();

    final changes = db.tableUpdates(TableUpdateQuery.onTable(db.schools));
    await for (final _ in changes) {
      yield await _fetchSchoolStats();
    }
  }

  /// Emits [StudentPlanStats] (total students + per-plan subscription counts)
  /// whenever the `students`, `subscriptions`, or `plans` table changes.
  /// Emits the current state immediately on first subscription.
  Stream<StudentPlanStats> watchStudentPlanStats() async* {
    yield await _fetchStudentPlanStats();

    final merged = StreamGroup.merge([
      db.tableUpdates(TableUpdateQuery.onTable(db.students)),
      db.tableUpdates(TableUpdateQuery.onTable(db.subscriptions)),
      db.tableUpdates(TableUpdateQuery.onTable(db.plans)),
    ]);

    await for (final _ in merged) {
      yield await _fetchStudentPlanStats();
    }
  }

  /// Emits [TeacherStats] (counts per [TeacherStatus]) whenever the
  /// `teachers` table changes. Emits the current state immediately.
  Stream<TeacherStats> watchTeacherStats() async* {
    yield await _fetchTeacherStats();

    final changes = db.tableUpdates(TableUpdateQuery.onTable(db.teachers));
    await for (final _ in changes) {
      yield await _fetchTeacherStats();
    }
  }

  /// Emits [SubscriptionStats] (counts per [SubscriptionStatus]) whenever
  /// the `subscriptions` table changes. Emits the current state immediately.
  Stream<SubscriptionStats> watchSubscriptionStats() async* {
    yield await _fetchSubscriptionStats();

    final changes = db.tableUpdates(TableUpdateQuery.onTable(db.subscriptions));
    await for (final _ in changes) {
      yield await _fetchSubscriptionStats();
    }
  }

  /// Emits [RevenueStats] (payment sums grouped by method) whenever the
  /// `payments` table changes. Emits the current state immediately.
  Stream<RevenueStats> watchRevenueStats() async* {
    yield await _fetchRevenueStats();

    final changes = db.tableUpdates(TableUpdateQuery.onTable(db.payments));
    await for (final _ in changes) {
      yield await _fetchRevenueStats();
    }
  }

  // ---------------------------------------------------------------------------
  // Private fetch helpers
  // ---------------------------------------------------------------------------

  /// Fetches user counts grouped by status via raw SQL so the result type is
  /// a plain [int] that we can switch on without TypeConverter interference.
  Future<UserStats> _fetchUserStats() async {
    // selectOnly with a TypeConverter column returns the converted Dart type,
    // but the analyzer cannot verify this at compile time. We use customSelect
    // with raw SQL to get unambiguous int values.
    final rows = await customSelect(
      'SELECT status, COUNT(*) AS cnt FROM users GROUP BY status',
      readsFrom: {users},
    ).get();

    int invited = 0, active = 0, suspended = 0, deleted = 0;

    for (final row in rows) {
      final statusInt = row.read<int>('status');
      final count = row.read<int>('cnt');
      switch (statusInt) {
        case 0:
          invited = count; // UserStatus.invited
        case 1:
          active = count; // UserStatus.active
        case 2:
          suspended = count; // UserStatus.suspended
        case 3:
          deleted = count; // UserStatus.deleted
      }
    }

    return UserStats(
      total: invited + active + suspended + deleted,
      invited: invited,
      active: active,
      suspended: suspended,
      deleted: deleted,
    );
  }

  /// Fetches school counts grouped by status via raw SQL.
  Future<SchoolStats> _fetchSchoolStats() async {
    final rows = await customSelect(
      'SELECT status, COUNT(*) AS cnt FROM schools GROUP BY status',
      readsFrom: {schools},
    ).get();

    int trial = 0, active = 0, cancelled = 0, suspended = 0, deleted = 0;

    for (final row in rows) {
      final statusInt = row.read<int>('status');
      final count = row.read<int>('cnt');
      switch (statusInt) {
        case 0:
          trial = count; // SchoolStatus.trial
        case 1:
          active = count; // SchoolStatus.active
        case 2:
          cancelled = count; // SchoolStatus.cancelled
        case 3:
          suspended = count; // SchoolStatus.suspended
        case 4:
          deleted = count; // SchoolStatus.deleted
      }
    }

    return SchoolStats(
      total: trial + active + cancelled + suspended + deleted,
      trial: trial,
      active: active,
      cancelled: cancelled,
      suspended: suspended,
      deleted: deleted,
    );
  }

  Future<StudentPlanStats> _fetchStudentPlanStats() async {
    // ── Total student count ──────────────────────────────────────────────────
    final totalCountExpr = students.adm.count();
    final totalQuery = selectOnly(students)..addColumns([totalCountExpr]);
    final totalRow = await totalQuery.getSingleOrNull();
    final totalStudents = totalRow?.read(totalCountExpr) ?? 0;

    // ── Per-plan active subscription counts ─────────────────────────────────
    // Raw SQL: group active subscriptions by plan, joining with plans for name.
    // SubscriptionStatus.active = 1
    final subRows = await customSelect(
      '''
      SELECT s.plan, p.name AS plan_name, COUNT(*) AS cnt
      FROM subscriptions s
      JOIN plans p ON p.id = s.plan
      WHERE s.status = 1
      GROUP BY s.plan
      ORDER BY cnt DESC
      ''',
      readsFrom: {subscriptions, plans},
    ).get();

    final perPlan = <PlanSubscriptionCount>[];
    int subscribedTotal = 0;

    for (final row in subRows) {
      final planId = row.read<String>('plan');
      final planName = row.read<String>('plan_name');
      final count = row.read<int>('cnt');
      subscribedTotal += count;
      perPlan.add(
        PlanSubscriptionCount(planId: planId, planName: planName, count: count),
      );
    }

    final unsubscribed = (totalStudents - subscribedTotal).clamp(
      0,
      totalStudents,
    );

    return StudentPlanStats(
      totalStudents: totalStudents,
      perPlan: perPlan,
      unsubscribed: unsubscribed,
    );
  }

  /// Fetches teacher counts grouped by status via raw SQL.
  Future<TeacherStats> _fetchTeacherStats() async {
    final rows = await customSelect(
      'SELECT status, COUNT(*) AS cnt FROM teachers GROUP BY status',
      readsFrom: {teachers},
    ).get();

    int active = 0, resigned = 0, transferred = 0, fired = 0, retired = 0;

    for (final row in rows) {
      final statusInt = row.read<int>('status');
      final count = row.read<int>('cnt');
      switch (statusInt) {
        case 0:
          active = count; // TeacherStatus.active
        case 1:
          resigned = count; // TeacherStatus.resigned
        case 2:
          transferred = count; // TeacherStatus.transferred
        case 3:
          fired = count; // TeacherStatus.fired
        case 4:
          retired = count; // TeacherStatus.retired
      }
    }

    return TeacherStats(
      total: active + resigned + transferred + fired + retired,
      active: active,
      resigned: resigned,
      transferred: transferred,
      fired: fired,
      retired: retired,
    );
  }

  /// Fetches subscription counts grouped by status via raw SQL.
  Future<SubscriptionStats> _fetchSubscriptionStats() async {
    final rows = await customSelect(
      'SELECT status, COUNT(*) AS cnt FROM subscriptions GROUP BY status',
      readsFrom: {subscriptions},
    ).get();

    int pending = 0, active = 0, cancelled = 0, deleted = 0;

    for (final row in rows) {
      final statusInt = row.read<int>('status');
      final count = row.read<int>('cnt');
      switch (statusInt) {
        case 0:
          pending = count; // SubscriptionStatus.pending
        case 1:
          active = count; // SubscriptionStatus.active
        case 2:
          cancelled = count; // SubscriptionStatus.cancelled
        case 3:
          deleted = count; // SubscriptionStatus.deleted
      }
    }

    return SubscriptionStats(
      total: pending + active + cancelled + deleted,
      pending: pending,
      active: active,
      cancelled: cancelled,
      deleted: deleted,
    );
  }

  /// Fetches revenue aggregates grouped by payment method via raw SQL.
  Future<RevenueStats> _fetchRevenueStats() async {
    final rows = await customSelect(
      'SELECT method, COUNT(*) AS cnt, COALESCE(SUM(amount), 0.0) AS total'
      ' FROM payments GROUP BY method',
      readsFrom: {payments},
    ).get();

    double cash = 0, cheque = 0, mpesa = 0, bank = 0;
    int totalCount = 0;

    for (final row in rows) {
      final methodInt = row.read<int>('method');
      final count = row.read<int>('cnt');
      final amount = row.read<double>('total');
      totalCount += count;
      switch (methodInt) {
        case 0:
          cash = amount; // PaymentMethod.cash
        case 1:
          cheque = amount; // PaymentMethod.cheque
        case 2:
          mpesa = amount; // PaymentMethod.mpesa
        case 3:
          bank = amount; // PaymentMethod.bank
      }
    }

    return RevenueStats(
      totalAmount: cash + cheque + mpesa + bank,
      totalCount: totalCount,
      cash: cash,
      cheque: cheque,
      mpesa: mpesa,
      bank: bank,
    );
  }
}
