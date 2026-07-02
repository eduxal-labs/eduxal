import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/plans.dart';
import '../tables/subscriptions.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

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
    final authResult = await authorization.check(
      action: SyncAction.createPlan,
      schoolId: null,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      await into(plans).insert(plan);

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.CreatePlanPayload(
        id: plan.id.value,
        name: plan.name.value,
        amount: plan.amount.value,
        levels: plan.levels.value,
      );
      if (plan.description.present && plan.description.value != null) {
        payload.description = plan.description.value!;
      }
      if (plan.features.present && plan.features.value != null) {
        payload.features = plan.features.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createPlan),
          resource: Value(plan.name.value),
          payload: Value(payload.writeToBuffer()),
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
    final authResult = await authorization.check(
      action: SyncAction.updatePlan,
      schoolId: null,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      await (update(plans)..where((t) => t.id.equals(planId))).write(changes);

      final payload = sync_pb.UpdatePlanPayload(id: planId);
      bool hasChanges = false;

      if (changes.name.present) {
        payload.name = changes.name.value;
        hasChanges = true;
      }
      if (changes.description.present) {
        if (changes.description.value != null) {
          payload.description = changes.description.value!;
        }
        hasChanges = true;
      }
      if (changes.amount.present) {
        payload.amount = changes.amount.value;
        hasChanges = true;
      }
      if (changes.levels.present) {
        payload.levels = changes.levels.value;
        hasChanges = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        hasChanges = true;
      }
      if (changes.features.present) {
        if (changes.features.value != null) {
          payload.features = changes.features.value!;
        }
        hasChanges = true;
      }

      if (!hasChanges) return; // nothing tracked to log

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Try to get plan name for resource display; fall back to planId.
      String resourceName = planId;
      if (changes.name.present) {
        resourceName = changes.name.value;
      } else {
        final existing = await (select(
          plans,
        )..where((t) => t.id.equals(planId))).getSingleOrNull();
        if (existing != null) resourceName = existing.name;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updatePlan),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
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
    final authResult = await authorization.check(
      action: SyncAction.deletePlan,
      schoolId: null,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Get the plan name for human-readable resource display.
      final existing = await (select(
        plans,
      )..where((t) => t.id.equals(planId))).getSingleOrNull();
      final resourceName = existing?.name ?? planId;

      final payload = sync_pb.DeletePlanPayload(id: planId);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deletePlan),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
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
    final authResult = await authorization.check(
      action: SyncAction.createSubscription,
      schoolId: sub.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      await into(subscriptions).insert(sub);

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.CreateSubscriptionPayload(
        school: sub.school.value,
        plan: sub.plan.value,
        year: sub.year.value,
        term: sub.term.value,
        student: sub.student.value,
      );
      if (sub.invoice.present && sub.invoice.value != null) {
        payload.invoice = sub.invoice.value!;
      }
      if (sub.discount.present) {
        payload.discount = sub.discount.value;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createSubscription),
          resource: Value('${sub.school.value}|${sub.plan.value}'),
          payload: Value(payload.writeToBuffer()),
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
    final authResult = await authorization.check(
      action: SyncAction.updateSubscription,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
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

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.UpdateSubscriptionPayload(
        school: schoolId,
        plan: planId,
        year: year,
        term: term,
        student: studentAdm,
        status: status.index,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateSubscription),
          resource: Value('$schoolId|$planId'),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }
}
