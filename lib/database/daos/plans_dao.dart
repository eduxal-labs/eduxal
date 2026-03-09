import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/plans.dart';
import '../tables/subscriptions.dart';
import '../../client.dart';

part 'plans_dao.g.dart';

/// DAO for the [Plans] table.
///
/// All mutating methods write a corresponding row to the [Logs] table (offline
/// mutation queue) inside the same transaction so that local changes are queued
/// for server synchronisation.
@DriftAccessor(tables: [Plans, Subscriptions, Logs])
class PlansDao extends DatabaseAccessor<AppDatabase> with _$PlansDaoMixin {
  PlansDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the full list of all plans ordered by name ascending whenever any
  /// row in the [Plans] table changes.
  ///
  /// Used by the system settings screen to drive the plans list reactively.
  Stream<List<Plan>> watchAllPlans() {
    return (select(plans)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns all plans with [PlanStatus.active], ordered by name ascending.
  ///
  /// Used by the student subscription stats query and any picker UI that only
  /// wants to show purchasable plans.
  Future<List<Plan>> getActivePlans() {
    return (select(plans)
          ..where((t) => t.status.equalsValue(PlanStatus.active))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Local mutation writes
  // ---------------------------------------------------------------------------

  /// Inserts a new plan row and enqueues a log insert entry, both in a single
  /// transaction.
  ///
  /// The [plan] companion must have all required fields populated:
  /// - [PlansCompanion.id]      — caller generates via Uuid().v4()
  /// - [PlansCompanion.name]
  /// - [PlansCompanion.amount]
  /// - [PlansCompanion.levels]  — bitmask of CBC grade levels
  /// - [PlansCompanion.status]
  /// - [PlansCompanion.created] and [PlansCompanion.updated] — seconds since epoch
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> createPlan(
    PlansCompanion plan, {
    required String accountId,
  }) async {
    await transaction(() async {
      await into(plans).insert(plan);

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.plans),
          op: const Value(LogOperation.insert),
          rowKey: plan.id,
          // columns is null for inserts — the full row is sent on sync.
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the specified fields on a plan row and writes a log update entry
  /// with the correct [PlansColumn] bitmask, both in a single transaction.
  ///
  /// Only columns whose [Value] is present in [changes] are updated.
  /// The [PlansCompanion.updated] field must be included in [changes] with the
  /// current timestamp (seconds since epoch).
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updatePlan(
    String planId,
    PlansCompanion changes, {
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(plans)..where((t) => t.id.equals(planId))).write(changes);

      int mask = 0;
      if (changes.name.present) mask |= (1 << PlansColumn.name.bit);
      if (changes.description.present) {
        mask |= (1 << PlansColumn.description.bit);
      }
      if (changes.amount.present) mask |= (1 << PlansColumn.amount.bit);
      if (changes.levels.present) mask |= (1 << PlansColumn.levels.bit);
      if (changes.status.present) mask |= (1 << PlansColumn.status.bit);
      if (changes.features.present) mask |= (1 << PlansColumn.features.bit);
      if (changes.updated.present) mask |= (1 << PlansColumn.updated.bit);

      if (mask == 0) return; // nothing tracked to log

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.plans),
          op: const Value(LogOperation.update),
          rowKey: Value(planId),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates a plan's [PlanStatus] and the [PlansData.updated] timestamp, and
  /// writes a log update entry, both in a single transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updatePlanStatus(
    String planId,
    PlanStatus status, {
    required String accountId,
  }) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return updatePlan(
      planId,
      PlansCompanion(status: Value(status), updated: Value(nowSeconds)),
      accountId: accountId,
    );
  }

  /// Hard-deletes a plan row from the local DB. Writes a delete log entry
  /// **before** the deletion so the sync engine can replay it to the server.
  ///
  /// Should only be called for plans that are already in [PlanStatus.deleted]
  /// status. Only super-level users should be allowed to call this.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> purgePlan(String planId, {required String accountId}) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.plans),
          op: const Value(LogOperation.delete),
          rowKey: Value(planId),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );

      await (delete(plans)..where((t) => t.id.equals(planId))).go();
    });
    sync.schedulePush();
  }

  // ---------------------------------------------------------------------------
  // Subscription queries
  // ---------------------------------------------------------------------------

  /// Watches all subscriptions for a specific student at a school.
  /// Used by the student detail page to show plan subscriptions.
  Stream<List<Subscription>> watchStudentSubscriptions(
    String schoolId,
    int studentAdm,
  ) {
    return (select(subscriptions)
          ..where(
            (t) => t.school.equals(schoolId) & t.student.equals(studentAdm),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .watch();
  }

  /// Watches subscriptions for a student in a specific term.
  Stream<List<Subscription>> watchStudentTermSubscriptions(
    String schoolId,
    int studentAdm,
    int year,
    int term,
  ) {
    return (select(subscriptions)..where(
          (t) =>
              t.school.equals(schoolId) &
              t.student.equals(studentAdm) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .watch();
  }

  /// Creates a subscription for a student and enqueues a log entry.
  Future<void> createSubscription({
    required SubscriptionsCompanion sub,
    required String accountId,
  }) async {
    await transaction(() async {
      await into(subscriptions).insert(sub);

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final schoolId = sub.school.value;
      final planId = sub.plan.value;
      final year = sub.year.value;
      final term = sub.term.value;
      final student = sub.student.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.subscriptions),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$planId|$year|$term|$student'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates a subscription's status and enqueues a log entry.
  Future<void> updateSubscriptionStatus({
    required String schoolId,
    required String planId,
    required int year,
    required int term,
    required int studentAdm,
    required SubscriptionStatus status,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await (update(subscriptions)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.plan.equals(planId) &
                t.year.equals(year) &
                t.term.equals(term) &
                t.student.equals(studentAdm),
          ))
          .write(
            SubscriptionsCompanion(
              status: Value(status),
              updated: Value(nowSec),
            ),
          );

      int mask = 0;
      mask |= (1 << SubscriptionsColumn.status.bit);
      mask |= (1 << SubscriptionsColumn.updated.bit);

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.subscriptions),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$planId|$year|$term|$studentAdm'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }
}
