import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/plans.dart';

part 'plans_dao.g.dart';

/// DAO for the [Plans] table.
///
/// All mutating methods write a corresponding row to the [Logs] table (offline
/// mutation queue) inside the same transaction so that local changes are queued
/// for server synchronisation.
@DriftAccessor(tables: [Plans, Logs])
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
  Future<void> createPlan(PlansCompanion plan, {required String accountId}) {
    return transaction(() async {
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
  }) {
    return transaction(() async {
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
}
