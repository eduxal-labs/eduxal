import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/roles.dart';
import '../tables/scopes.dart';
import '../tables/users.dart';
import '../../models/system_permissions.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;

part 'users_dao.g.dart';

/// DAO for the [Users] table.
///
/// Provides reactive streams and one-shot reads/writes for user rows.
/// User rows are written by the sync engine when the server pushes user data.
/// The authentication service writes the current user's row via [upsertUser].
///
/// All mutating methods that affect synced tables also write a corresponding
/// row to the [Logs] table (offline mutation queue) inside the same transaction.
@DriftAccessor(tables: [Users, Logs, Scopes, Roles])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the user row for [id] whenever it changes.
  /// Emits [null] if no row with [id] exists.
  Stream<UsersData?> watchUser(String id) {
    return (select(users)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Emits the full list of all users, ordered by name ascending, whenever
  /// any row in the [Users] table changes.
  ///
  /// Used by the system dashboard Users section to drive a reactive list.
  Stream<List<UsersData>> watchAllUsers() {
    return (select(users)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  /// Emits all users where `level = system`, ordered by name ascending.
  ///
  /// Used by the Members tab on the system dashboard. Does **not** include
  /// Normal or Super users.
  Stream<List<UsersData>> watchSystemMembers() {
    return (select(users)
          ..where((t) => t.level.equalsValue(UserLevel.system))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Emits all users where `level = normal`, ordered by name ascending.
  ///
  /// Used by the "Add Member" modal to show users eligible for promotion
  /// to system level. Includes all statuses (invited, active, etc.).
  Stream<List<UsersData>> watchNormalUsers() {
    return (select(users)
          ..where((t) => t.level.equalsValue(UserLevel.normal))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns the user row for [id], or [null] if not found.
  Future<UsersData?> getUser(String id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Returns the user whose phone number exactly matches [phone], or [null]
  /// if no such user exists locally.
  ///
  /// Used by the "create school" and "invite user" flows to check whether an
  /// owner already has a local account before creating a duplicate.
  Future<UsersData?> getUserByPhone(String phone) {
    return (select(
      users,
    )..where((t) => t.phone.equals(phone))).getSingleOrNull();
  }

  /// Fetches all system-level [RolePermissions] for [userId] by querying the
  /// `scopes` table for rows where `school IS NULL` and joining with `roles`.
  ///
  /// Returns an empty list if the user has no system-level scopes.
  ///
  /// Used by [SystemPermissions.forUser] to build the flat permission set that
  /// drives the system dashboard feature-gate logic.
  Future<List<RolePermissions>> getSystemPermissions(String userId) async {
    // Query scopes where school IS NULL for this user, joined with roles.
    final query = select(scopes).join([
      innerJoin(roles, roles.id.equalsExp(scopes.role)),
    ])..where(scopes.user.equals(userId) & scopes.school.isNull());

    final rows = await query.get();

    return rows.map((row) {
      final role = row.readTable(roles);
      return RolePermissions(
        roleId: role.id,
        roleName: role.name,
        permissionsJson: role.permissions,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new user row, or replaces an existing row with the same [id].
  ///
  /// Called by the sync engine when it receives a user delta from the server,
  /// and by the authentication service immediately after a successful login to
  /// persist the authenticated user's profile locally.
  ///
  /// Does **not** write a log entry — this is a sync-sourced write, not a
  /// local mutation.
  Future<void> upsertUser(UsersCompanion user) {
    return into(users).insertOnConflictUpdate(user);
  }

  /// Creates a new invited user and enqueues a log insert entry, both in a
  /// single transaction.
  ///
  /// The [user] companion must have all required fields populated:
  /// - [UsersCompanion.id] — caller generates via [Uuid().v4()]
  /// - [UsersCompanion.phone]
  /// - [UsersCompanion.name]
  /// - [UsersCompanion.status] — should be [UserStatus.invited]
  /// - [UsersCompanion.level]  — should be [UserLevel.normal]
  /// - [UsersCompanion.created] and [UsersCompanion.updated] — seconds since epoch
  ///
  /// The [accountId] is the currently active account's user id, used to
  /// associate the log entry with the correct account.
  Future<void> inviteUser(
    UsersCompanion user, {
    required String accountId,
  }) async {
    await transaction(() async {
      await into(users).insert(user);

      // Note: inviteUser creates a user row directly. The invitation pattern
      // for member creation is handled in the member DAOs (CreateTeacherPayload
      // etc. carry the user info). This method is for standalone user creation
      // (e.g. system-level user management).
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.UpdateUserPayload(
        id: user.id.value,
        phone: user.phone.present ? user.phone.value : null,
        name: user.name.present ? user.name.value : null,
        email: user.email.present ? user.email.value : null,
        level: user.level.present ? user.level.value.index : null,
        status: user.status.present ? user.status.value.index : null,
      );
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: const Value(SyncAction.updateUser),
          resource: Value(user.name.present ? user.name.value : user.id.value),
          payload: Value(Uint8List.fromList(payload.writeToBuffer())),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the specified fields on a user row and writes a log update entry
  /// with the correct [UsersColumn] bitmask, both in a single transaction.
  ///
  /// Only columns whose [Value] is present in [changes] are updated.
  /// The [UsersCompanion.updated] field must be included in [changes] with the
  /// current timestamp (seconds since epoch).
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateUserDetails(
    String userId,
    UsersCompanion changes, {
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(users)..where((t) => t.id.equals(userId))).write(changes);

      // Build payload with only the fields that changed.
      final payload = sync_pb.UpdateUserPayload(id: userId);
      bool anyField = false;
      if (changes.phone.present) {
        payload.phone = changes.phone.value;
        anyField = true;
      }
      if (changes.email.present) {
        payload.email = changes.email.value ?? '';
        anyField = true;
      }
      if (changes.name.present) {
        payload.name = changes.name.value;
        anyField = true;
      }
      if (changes.level.present) {
        payload.level = changes.level.value.index;
        anyField = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        anyField = true;
      }

      if (!anyField) return; // nothing tracked to log

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: const Value(SyncAction.updateUser),
          resource: Value(changes.name.present ? changes.name.value : userId),
          payload: Value(Uint8List.fromList(payload.writeToBuffer())),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates a user's [UserStatus] and the [UsersData.updated] timestamp, and
  /// writes a log update entry, both in a single transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateUserStatus(
    String userId,
    UserStatus status, {
    required String accountId,
  }) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return updateUserDetails(
      userId,
      UsersCompanion(status: Value(status), updated: Value(nowSeconds)),
      accountId: accountId,
    );
  }

  /// Updates a user's [UserLevel] (and optionally their [UserStatus]) and
  /// writes a log update entry, both in a single transaction.
  ///
  /// If [status] is provided, both level and status are changed atomically.
  /// [accountId] is the currently active account's user id.
  Future<void> setUserLevel(
    String userId,
    UserLevel level, {
    required String accountId,
    UserStatus? status,
  }) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final companion = status != null
        ? UsersCompanion(
            level: Value(level),
            status: Value(status),
            updated: Value(nowSeconds),
          )
        : UsersCompanion(level: Value(level), updated: Value(nowSeconds));
    return updateUserDetails(userId, companion, accountId: accountId);
  }

  /// Updates the [UserStatus] for a list of user IDs in a single transaction.
  ///
  /// Each user also gets its [UsersData.updated] timestamp refreshed.
  /// Each change produces its own log entry within the transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> bulkUpdateStatus(
    List<String> userIds,
    UserStatus status, {
    required String accountId,
  }) async {
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      for (final userId in userIds) {
        await (update(users)..where((t) => t.id.equals(userId))).write(
          UsersCompanion(status: Value(status), updated: Value(nowSeconds)),
        );
        final payload = sync_pb.UpdateUserPayload(
          id: userId,
          status: status.index,
        );
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: const Value(SyncAction.updateUser),
            resource: Value(userId),
            payload: Value(Uint8List.fromList(payload.writeToBuffer())),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Updates the [UserLevel] for a list of user IDs in a single transaction.
  ///
  /// Each user also gets its [UsersData.updated] timestamp refreshed.
  /// Each change produces its own log entry within the transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> bulkUpdateLevel(
    List<String> userIds,
    UserLevel level, {
    required String accountId,
  }) async {
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      for (final userId in userIds) {
        await (update(users)..where((t) => t.id.equals(userId))).write(
          UsersCompanion(level: Value(level), updated: Value(nowSeconds)),
        );
        final payload = sync_pb.UpdateUserPayload(
          id: userId,
          level: level.index,
        );
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: const Value(SyncAction.updateUser),
            resource: Value(userId),
            payload: Value(Uint8List.fromList(payload.writeToBuffer())),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
      }
    });
    sync.schedulePush();
  }

  /// Hard-deletes a list of user rows from the local DB in a single
  /// transaction. Writes a delete log entry for each user **before** deletion.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> bulkPurge(
    List<String> userIds, {
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      for (final userId in userIds) {
        final payload = sync_pb.DeleteUserPayload(id: userId);
        await into(logs).insert(
          LogsCompanion(
            account: Value(accountId),
            action: const Value(SyncAction.deleteUser),
            resource: Value(userId),
            payload: Value(Uint8List.fromList(payload.writeToBuffer())),
            status: const Value(LogStatus.pending),
            created: Value(nowMs),
          ),
        );
        await (delete(users)..where((t) => t.id.equals(userId))).go();
      }
    });
    sync.schedulePush();
  }

  /// Hard-deletes a user row from the local DB. Writes a delete log entry
  /// **before** the deletion so the sync engine can replay it to the server.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> purgeUser(String userId, {required String accountId}) async {
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.DeleteUserPayload(id: userId);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: const Value(SyncAction.deleteUser),
          resource: Value(userId),
          payload: Value(Uint8List.fromList(payload.writeToBuffer())),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );

      await (delete(users)..where((t) => t.id.equals(userId))).go();
    });
    sync.schedulePush();
  }
}
