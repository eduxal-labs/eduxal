import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/roles.dart';
import '../tables/scopes.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;

part 'roles_dao.g.dart';

/// DAO for the [Roles] table.
///
/// Covers system-level roles (where `school IS NULL`). School-scoped roles are
/// managed via the school dashboard (future task group).
///
/// All mutating methods write a corresponding row to the [Logs] table (offline
/// mutation queue) inside the same transaction.
@DriftAccessor(tables: [Roles, Logs, Scopes, Users])
class RolesDao extends DatabaseAccessor<AppDatabase> with _$RolesDaoMixin {
  RolesDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits all system-level roles (where `school IS NULL`), ordered by name
  /// ascending, whenever the [Roles] table changes.
  ///
  /// Used by the system dashboard Roles section.
  Stream<List<Role>> watchSystemRoles() {
    return (select(roles)
          ..where((t) => t.school.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Emits the list of system-level roles assigned to a specific user via the
  /// [Scopes] table, joined with the [Roles] table to include full role details.
  /// Only system-level scopes (where `scopes.school IS NULL`) are included.
  /// Ordered by role name ascending.
  ///
  /// Each emission is a list of `(Scope, Role)` pairs. The stream re-emits
  /// whenever the [Scopes] or [Roles] table changes for matching rows.
  ///
  /// Used by the Member Roles sheet on the Members tab.
  Stream<List<({Scope scope, Role role})>> watchRolesForUser(String userId) {
    final query =
        select(scopes).join([innerJoin(roles, roles.id.equalsExp(scopes.role))])
          ..where(scopes.user.equals(userId) & scopes.school.isNull())
          ..orderBy([OrderingTerm.asc(roles.name)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return (scope: row.readTable(scopes), role: row.readTable(roles));
      }).toList();
    });
  }

  /// Emits all system-level roles (where `roles.school IS NULL`) that are
  /// **not yet** assigned to [userId] via a system-level scope.
  /// Ordered by role name ascending.
  ///
  /// Used by the "Assign role" picker inside the Member Roles sheet.
  Stream<List<Role>> watchEligibleRolesForUser(String userId) {
    final assignedSubquery = selectOnly(scopes)
      ..addColumns([scopes.role])
      ..where(scopes.user.equals(userId) & scopes.school.isNull());

    return (select(roles)
          ..where(
            (r) => r.school.isNull() & r.id.isNotInQuery(assignedSubquery),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .watch();
  }

  /// Emits the list of users assigned to a specific role via the [Scopes]
  /// table, joined with the [Users] table to include full user details.
  /// Only system-level scopes (where `scopes.school IS NULL`) are included.
  /// Ordered by user name ascending.
  ///
  /// Each emission is a list of `(Scope, UsersData)` pairs. The stream
  /// re-emits whenever the [Scopes] or [Users] table changes for matching rows.
  ///
  /// Used by the role detail screen's Assigned tab.
  Stream<List<({Scope scope, UsersData user})>> watchUsersForRole(
    String roleId,
  ) {
    final query =
        select(scopes).join([innerJoin(users, users.id.equalsExp(scopes.user))])
          ..where(scopes.role.equals(roleId) & scopes.school.isNull())
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return (scope: row.readTable(scopes), user: row.readTable(users));
      }).toList();
    });
  }

  /// Emits system-level users (where `users.level` is [UserLevel.system])
  /// with status [UserStatus.active] or [UserStatus.invited], who are **not**
  /// already assigned to [roleId] via a system-level scope (where
  /// `scopes.school IS NULL`).
  ///
  /// Used by the "Assign user" sheet on the role detail screen to show only
  /// eligible candidates.
  Stream<List<UsersData>> watchEligibleSystemUsers(String roleId) {
    // Sub-select: user IDs already assigned to this role at system level.
    final assignedSubquery = selectOnly(scopes)
      ..addColumns([scopes.user])
      ..where(scopes.role.equals(roleId) & scopes.school.isNull());

    return (select(users)
          ..where(
            (u) =>
                u.level.equalsValue(UserLevel.system) &
                (u.status.equalsValue(UserStatus.active) |
                    u.status.equalsValue(UserStatus.invited)) &
                u.id.isNotInQuery(assignedSubquery),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns all system-level roles (where `school IS NULL`), ordered by name
  /// ascending, in a single query.
  Future<List<Role>> getSystemRoles() {
    return (select(roles)
          ..where((t) => t.school.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Local mutation writes
  // ---------------------------------------------------------------------------

  /// Inserts a new role row and enqueues a log insert entry, both in a single
  /// transaction.
  ///
  /// The [role] companion must have all required fields populated:
  /// - [RolesCompanion.id]          — caller generates via Uuid().v4()
  /// - [RolesCompanion.name]
  /// - [RolesCompanion.permissions] — JSON-encoded permissions map
  /// - [RolesCompanion.created] and [RolesCompanion.updated] — seconds since epoch
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> createRole(
    RolesCompanion role, {
    required String accountId,
  }) async {
    await transaction(() async {
      await into(roles).insert(role);

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.CreateRolePayload(
        id: role.id.value,
        name: role.name.value,
      );
      if (role.school.present && role.school.value != null) {
        payload.school = role.school.value!;
      }
      if (role.description.present && role.description.value != null) {
        payload.description = role.description.value!;
      }
      if (role.permissions.present) {
        payload.permissions = utf8.encode(role.permissions.value);
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createRole),
          resource: Value(role.name.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the specified fields on a role row and writes a log update entry
  /// with the correct [RolesColumn] bitmask, both in a single transaction.
  ///
  /// Only columns whose [Value] is present in [changes] are updated.
  /// The [RolesCompanion.updated] field must be included in [changes] with the
  /// current timestamp (seconds since epoch).
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateRole(
    String roleId,
    RolesCompanion changes, {
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(roles)..where((t) => t.id.equals(roleId))).write(changes);

      final payload = sync_pb.UpdateRolePayload(id: roleId);
      bool hasChanges = false;

      if (changes.name.present) {
        payload.name = changes.name.value;
        hasChanges = true;
      }
      if (changes.description.present && changes.description.value != null) {
        payload.description = changes.description.value!;
        hasChanges = true;
      }
      if (changes.permissions.present) {
        payload.permissions = utf8.encode(changes.permissions.value);
        hasChanges = true;
      }

      if (!hasChanges) return; // nothing tracked to log

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Try to get role name for resource display; fall back to roleId.
      String resourceName = roleId;
      if (changes.name.present) {
        resourceName = changes.name.value;
      } else {
        final existing = await (select(
          roles,
        )..where((t) => t.id.equals(roleId))).getSingleOrNull();
        if (existing != null) resourceName = existing.name;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateRole),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Assigns a user to a role by inserting a system-level scope row
  /// (school = NULL) and enqueues a log insert entry, both in a single
  /// transaction.
  ///
  /// [userId] is the user being assigned. [roleId] is the target role.
  /// [accountId] is the currently active account's user id.
  Future<void> assignUserToRole({
    required String userId,
    required String roleId,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      await into(scopes).insert(
        ScopesCompanion(
          school: const Value(null),
          user: Value(userId),
          role: Value(roleId),
          created: Value(nowSeconds),
        ),
      );

      // System-level scope — school is omitted (null in proto).
      final payload = sync_pb.AssignRolePayload(user: userId, role: roleId);

      // Get user phone/name for human-readable resource display.
      String resourceName = userId;
      final user = await (select(
        users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (user != null) resourceName = user.phone;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.assignRole),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes a user from a role by deleting the system-level scope row
  /// (school IS NULL) and enqueues a log delete entry, both in a single
  /// transaction.
  ///
  /// [userId] is the user being unassigned. [roleId] is the target role.
  /// [accountId] is the currently active account's user id.
  Future<void> unassignUserFromRole({
    required String userId,
    required String roleId,
    required String accountId,
  }) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // System-level scope — school is omitted (null in proto).
      final payload = sync_pb.UnassignRolePayload(user: userId, role: roleId);

      // Get user phone/name for human-readable resource display.
      String resourceName = userId;
      final user = await (select(
        users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (user != null) resourceName = user.phone;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.unassignRole),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );

      // Delete the actual scope row.
      await (delete(scopes)..where(
            (t) =>
                t.school.isNull() &
                t.user.equals(userId) &
                t.role.equals(roleId),
          ))
          .go();
    });
    sync.schedulePush();
  }

  /// Deletes a role row and writes a log delete entry, both in a single
  /// transaction.
  ///
  /// After the delete log entry is inserted, [LogsDao.supersedWithDelete] is
  /// called to remove any pending insert/update entries for the same
  /// `(tbl=roles, rowKey=roleId)` pair — the delete supersedes them all.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> deleteRole(String roleId, {required String accountId}) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Get role name for human-readable resource display.
      final existing = await (select(
        roles,
      )..where((t) => t.id.equals(roleId))).getSingleOrNull();
      final resourceName = existing?.name ?? roleId;

      final payload = sync_pb.DeleteRolePayload(id: roleId);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteRole),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );

      // Delete the actual role row.
      await (delete(roles)..where((t) => t.id.equals(roleId))).go();
    });
    sync.schedulePush();
  }
}
