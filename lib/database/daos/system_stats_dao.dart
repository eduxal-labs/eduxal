import 'dart:async';

import 'package:async/async.dart';
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/enrollments.dart';
import '../tables/invoices.dart';
import '../tables/payments.dart';
import '../tables/plans.dart';
import '../tables/schools.dart';
import '../tables/students.dart';
import '../tables/subscriptions.dart';
import '../tables/teachers.dart';
import '../tables/terms.dart';
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
  tables: [
    Users,
    Schools,
    Students,
    Enrollments,
    Terms,
    Plans,
    Subscriptions,
    Teachers,
    Invoices,
    Payments,
  ],
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

  /// Emits [StudentStats] (counts per [StudentStatus] scoped to the current
  /// term via enrollments) whenever the `students`, `enrollments`, or `terms`
  /// table changes. Emits the current state immediately on first subscription.
  Stream<StudentStats> watchStudentStats() async* {
    yield await _fetchStudentStats();

    final merged = StreamGroup.merge([
      db.tableUpdates(TableUpdateQuery.onTable(db.students)),
      db.tableUpdates(TableUpdateQuery.onTable(db.enrollments)),
      db.tableUpdates(TableUpdateQuery.onTable(db.terms)),
    ]);
    await for (final _ in merged) {
      yield await _fetchStudentStats();
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
      db.tableUpdates(TableUpdateQuery.onTable(db.terms)),
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

  /// Emits [SubscriptionStats] (counts per [SubscriptionStatus] scoped to the
  /// current term) whenever `subscriptions` or `terms` changes.
  Stream<SubscriptionStats> watchSubscriptionStats() async* {
    yield await _fetchSubscriptionStats();

    final merged = StreamGroup.merge([
      db.tableUpdates(TableUpdateQuery.onTable(db.subscriptions)),
      db.tableUpdates(TableUpdateQuery.onTable(db.terms)),
    ]);
    await for (final _ in merged) {
      yield await _fetchSubscriptionStats();
    }
  }

  /// Emits [RevenueStats] (subscription revenue grouped by plan, scoped to the
  /// current term) whenever `subscriptions`, `plans`, or `terms` changes.
  Stream<RevenueStats> watchRevenueStats() async* {
    yield await _fetchRevenueStats();

    final merged = StreamGroup.merge([
      db.tableUpdates(TableUpdateQuery.onTable(db.subscriptions)),
      db.tableUpdates(TableUpdateQuery.onTable(db.plans)),
      db.tableUpdates(TableUpdateQuery.onTable(db.terms)),
    ]);
    await for (final _ in merged) {
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
      readsFrom: {db.users},
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
      readsFrom: {db.schools},
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

  /// Fetches student counts grouped by status via raw SQL.
  /// Resolves the "current" term across all schools in the local DB.
  ///
  /// Priority:
  ///   1. A term currently in progress: `start <= nowSecs AND end >= nowSecs`.
  ///      When multiple schools have overlapping active terms, pick the one
  ///      whose `start` is most recent (most recently begun).
  ///   2. Fallback: the term with the largest `end` value in the past
  ///      (most recently completed term).
  ///   3. If no terms exist at all → returns null (caller shows lifetime data).
  Future<CurrentTerm?> _fetchCurrentTerm() async {
    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Try active term first.
    final activeRows = await customSelect(
      '''
      SELECT year, term, start, end
      FROM terms
      WHERE start <= ? AND end >= ?
      ORDER BY start DESC
      LIMIT 1
      ''',
      variables: [Variable.withInt(nowSecs), Variable.withInt(nowSecs)],
      readsFrom: {db.terms},
    ).get();

    if (activeRows.isNotEmpty) {
      final r = activeRows.first;
      return CurrentTerm(
        year: r.read<int>('year'),
        term: r.read<int>('term'),
        startEpochSecs: r.read<int>('start'),
        endEpochSecs: r.read<int>('end'),
      );
    }

    // Fallback: most recently ended term.
    final pastRows = await customSelect(
      '''
      SELECT year, term, start, end
      FROM terms
      WHERE end < ?
      ORDER BY end DESC
      LIMIT 1
      ''',
      variables: [Variable.withInt(nowSecs)],
      readsFrom: {db.terms},
    ).get();

    if (pastRows.isNotEmpty) {
      final r = pastRows.first;
      return CurrentTerm(
        year: r.read<int>('year'),
        term: r.read<int>('term'),
        startEpochSecs: r.read<int>('start'),
        endEpochSecs: r.read<int>('end'),
      );
    }

    return null;
  }

  /// Fetches student counts grouped by status, scoped to the current term.
  ///
  /// Counts distinct students enrolled in the current term (via the
  /// `enrollments` table) and looks up each student's current status from
  /// the `students` table.  If no terms exist, falls back to a full count
  /// of all students by status.
  Future<StudentStats> _fetchStudentStats() async {
    final ct = await _fetchCurrentTerm();

    List<QueryRow> rows;

    if (ct != null) {
      // Count students enrolled this term, grouped by their current status.
      rows = await customSelect(
        '''
        SELECT s.status, COUNT(DISTINCT e.student) AS cnt
        FROM enrollments e
        JOIN students s ON s.school = e.school AND s.adm = e.student
        WHERE e.year = ? AND e.term = ?
        GROUP BY s.status
        ''',
        variables: [Variable.withInt(ct.year), Variable.withInt(ct.term)],
        readsFrom: {db.enrollments, db.students},
      ).get();
    } else {
      // No terms yet — fall back to lifetime student counts.
      rows = await customSelect(
        'SELECT status, COUNT(*) AS cnt FROM students GROUP BY status',
        readsFrom: {db.students},
      ).get();
    }

    int active = 0,
        expelled = 0,
        graduated = 0,
        transferred = 0,
        withdrawn = 0,
        deleted = 0;

    for (final row in rows) {
      final statusInt = row.read<int>('status');
      final count = row.read<int>('cnt');
      switch (statusInt) {
        case 0:
          active = count;
        case 1:
          expelled = count;
        case 2:
          graduated = count;
        case 3:
          transferred = count;
        case 4:
          withdrawn = count;
        case 5:
          deleted = count;
      }
    }

    return StudentStats(
      total: active + expelled + graduated + transferred + withdrawn + deleted,
      active: active,
      expelled: expelled,
      graduated: graduated,
      transferred: transferred,
      withdrawn: withdrawn,
      deleted: deleted,
      currentTerm: ct,
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
      readsFrom: {db.subscriptions, db.plans},
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
      readsFrom: {db.teachers},
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

  /// Fetches subscription counts grouped by status, scoped to the current term.
  Future<SubscriptionStats> _fetchSubscriptionStats() async {
    final ct = await _fetchCurrentTerm();

    List<QueryRow> rows;

    if (ct != null) {
      rows = await customSelect(
        '''
        SELECT status, COUNT(*) AS cnt
        FROM subscriptions
        WHERE year = ? AND term = ?
        GROUP BY status
        ''',
        variables: [Variable.withInt(ct.year), Variable.withInt(ct.term)],
        readsFrom: {db.subscriptions},
      ).get();
    } else {
      rows = await customSelect(
        'SELECT status, COUNT(*) AS cnt FROM subscriptions GROUP BY status',
        readsFrom: {db.subscriptions},
      ).get();
    }

    int pending = 0, active = 0, cancelled = 0, deleted = 0;

    for (final row in rows) {
      final statusInt = row.read<int>('status');
      final count = row.read<int>('cnt');
      switch (statusInt) {
        case 0:
          pending = count;
        case 1:
          active = count;
        case 2:
          cancelled = count;
        case 3:
          deleted = count;
      }
    }

    return SubscriptionStats(
      total: pending + active + cancelled + deleted,
      pending: pending,
      active: active,
      cancelled: cancelled,
      deleted: deleted,
      currentTerm: ct,
    );
  }

  /// Fetches subscription revenue aggregates grouped by plan, scoped to the
  /// current term.
  ///
  /// Revenue per subscription = `plans.amount * (1 - subscriptions.discount / 100)`.
  /// Only non-cancelled subscriptions (status IN (0=pending, 1=active)) are counted.
  Future<RevenueStats> _fetchRevenueStats() async {
    final ct = await _fetchCurrentTerm();

    List<QueryRow> rows;

    if (ct != null) {
      rows = await customSelect(
        '''
        SELECT p.id   AS plan_id,
               p.name AS plan_name,
               COUNT(*)                                    AS cnt,
               COALESCE(SUM(p.amount * (1.0 - s.discount / 100.0)), 0.0) AS total
        FROM subscriptions s
        JOIN plans p ON p.id = s.plan
        WHERE s.year = ? AND s.term = ?
          AND s.status IN (0, 1)
        GROUP BY p.id, p.name
        ORDER BY total DESC
        ''',
        variables: [Variable.withInt(ct.year), Variable.withInt(ct.term)],
        readsFrom: {db.subscriptions, db.plans},
      ).get();
    } else {
      rows = await customSelect(
        '''
        SELECT p.id   AS plan_id,
               p.name AS plan_name,
               COUNT(*)                                    AS cnt,
               COALESCE(SUM(p.amount * (1.0 - s.discount / 100.0)), 0.0) AS total
        FROM subscriptions s
        JOIN plans p ON p.id = s.plan
        WHERE s.status IN (0, 1)
        GROUP BY p.id, p.name
        ORDER BY total DESC
        ''',
        readsFrom: {db.subscriptions, db.plans},
      ).get();
    }

    double totalAmount = 0;
    int totalCount = 0;
    final perPlan = <PlanRevenue>[];

    for (final row in rows) {
      final planId = row.read<String>('plan_id');
      final planName = row.read<String>('plan_name');
      final count = row.read<int>('cnt');
      final amount = row.read<double>('total');
      totalAmount += amount;
      totalCount += count;
      perPlan.add(
        PlanRevenue(
          planId: planId,
          planName: planName,
          amount: amount,
          count: count,
        ),
      );
    }

    return RevenueStats(
      totalAmount: totalAmount,
      totalCount: totalCount,
      perPlan: perPlan,
      currentTerm: ct,
    );
  }
}
