import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/accounts.dart';
import '../tables/enums.dart';

import '../tables/users.dart';
import '../../models/authenticated.dart';
import '../../client.dart';

part 'accounts_dao.g.dart';

/// DAO for the client-only [Accounts] table.
///
/// All account reads and writes go through this class. No gRPC calls are
/// made here — this is a pure local-database accessor.
///
/// Read methods ([watchActiveAccount], [getActiveAccount], [getAllAccounts])
/// join [Accounts] with [Users] and return domain [Authenticated] objects so
/// callers never have to deal with raw [AccountsData] rows.
///
/// Write methods that only touch session fields ([upsertAccount],
/// [updateTokens], [updateLastSynced], [updateTheme]) still accept or build
/// [AccountsCompanion] directly — no join needed.
@DriftAccessor(tables: [Accounts, Users])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the currently active [Authenticated] whenever it changes.
  /// Emits [null] when no account is active (e.g. after logout).
  Stream<Authenticated?> watchActiveAccount() {
    return (select(accounts).join([
      innerJoin(users, users.id.equalsExp(accounts.id)),
    ])..where(accounts.isActive.equals(true))).watchSingleOrNull().map((row) {
      if (row == null) return null;
      final account = row.readTable(accounts);
      final user = row.readTable(users);
      return Authenticated.fromRows(account, user);
    });
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns the currently active [Authenticated], or [null] if none is active.
  Future<Authenticated?> getActiveAccount() async {
    final row = await (select(accounts).join([
      innerJoin(users, users.id.equalsExp(accounts.id)),
    ])..where(accounts.isActive.equals(true))).getSingleOrNull();
    if (row == null) return null;
    final account = row.readTable(accounts);
    final user = row.readTable(users);
    return Authenticated.fromRows(account, user);
  }

  /// Returns every locally stored account as an [Authenticated] list
  /// (active or not).
  Future<List<Authenticated>> getAllAccounts() async {
    final rows = await select(
      accounts,
    ).join([innerJoin(users, users.id.equalsExp(accounts.id))]).get();
    return [
      for (final row in rows)
        Authenticated.fromRows(row.readTable(accounts), row.readTable(users)),
    ];
  }

  // ---------------------------------------------------------------------------
  // Writes — session / token fields
  // ---------------------------------------------------------------------------

  /// Inserts a new account row, or replaces an existing row with the same [id].
  ///
  /// Used both when first logging in and when refreshing tokens (the companion
  /// carries the updated token fields).
  ///
  /// User identity fields must be written separately via [updateUser] or
  /// directly through [UsersDao.upsertUser] — this method only touches the
  /// `accounts` table.
  Future<void> upsertAccount(AccountsCompanion account) {
    return into(accounts).insertOnConflictUpdate(account);
  }

  /// Atomically sets [id] as the active account and deactivates all others.
  ///
  /// The partial unique index `uq_accounts_active` on the underlying SQL table
  /// enforces that at most one row has `is_active = 1` at any time. This
  /// transaction keeps that invariant without relying solely on the index.
  Future<void> setActiveAccount(String id) {
    return transaction(() async {
      // Deactivate everyone first.
      await (update(
        accounts,
      )).write(const AccountsCompanion(isActive: Value(false)));
      // Then activate the target row.
      await (update(accounts)..where((t) => t.id.equals(id))).write(
        const AccountsCompanion(isActive: Value(true)),
      );
    });
  }

  /// Removes the account row for [id].
  ///
  /// After deletion, if [id] was the active account, no account will be active.
  /// Callers are responsible for calling [setActiveAccount] on another account
  /// (or prompting re-login) as appropriate.
  ///
  /// The FK `ON DELETE CASCADE` on `accounts.id → users.id` means deleting the
  /// *user* row would also delete the account row. This method deletes only the
  /// account row, leaving the user row intact for any other local references.
  Future<void> deleteAccount(String id) {
    return (delete(accounts)..where((t) => t.id.equals(id))).go();
  }

  /// Overwrites the token fields for [id] after a successful token refresh.
  ///
  /// [tokenExpiry] and [refreshTokenExpiry] are milliseconds since epoch.
  Future<void> updateTokens(
    String id,
    String accessToken,
    String refreshToken,
    int tokenExpiry,
    int refreshTokenExpiry,
  ) {
    return (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        accessToken: Value(accessToken),
        refreshToken: Value(refreshToken),
        tokenExpiry: Value(BigInt.from(tokenExpiry)),
        refreshTokenExpiry: Value(BigInt.from(refreshTokenExpiry)),
        updated: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
      ),
    );
  }

  /// Updates [lastSyncedAt] for [id] after a successful sync cycle.
  ///
  /// [timestamp] is milliseconds since epoch.
  Future<void> updateLastSynced(String id, int timestamp) {
    return (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        lastSyncedAt: Value(BigInt.from(timestamp)),
        updated: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
      ),
    );
  }

  /// Updates the server sync sequence number for [id].
  ///
  /// Called by the sync engine after each successful `WatchChanges` delta is
  /// applied locally, so the next `WatchRequest` can resume from [seq].
  Future<void> updateLastSeq(String id, int seq) {
    return (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        lastSeq: Value(BigInt.from(seq)),
        updated: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
      ),
    );
  }

  /// Updates the theme preference for [id].
  ///
  /// Called by the theme switcher in the UI whenever the user changes their
  /// preferred [AppThemeMode]. The reactive [watchActiveAccount] stream will
  /// emit the updated [Authenticated] automatically.
  Future<void> updateTheme(String id, AppThemeMode theme) {
    return (update(accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        theme: Value(theme),
        updated: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Writes — user identity fields
  // ---------------------------------------------------------------------------

  /// Updates the [Users] row for this account by delegating to [UsersDao].
  ///
  /// Convenience method so callers do not need to hold a separate [UsersDao]
  /// reference just to update user data (e.g. name change from the setup
  /// screen).
  Future<void> updateUser(UsersCompanion user) {
    return into(db.users).insertOnConflictUpdate(user);
  }

  // ---------------------------------------------------------------------------
  // Writes — account page profile edits (Task 3.3)
  // ---------------------------------------------------------------------------

  /// Updates the display name of the user identified by [userId].
  ///
  /// Performs two writes atomically in a single transaction:
  /// 1. Updates `users.name` and `users.updated` in the local DB.
  /// 2. Appends a row to the `logs` table so the sync engine can replay the
  ///    mutation to the server when online.
  ///
  /// The reactive [watchActiveAccount] stream will emit the updated
  /// [Authenticated] automatically because it joins against the `users` table.
  Future<void> updateName(String userId, String name) async {
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await transaction(() async {
      // 1. Update the users table.
      await (update(db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(name: Value(name), updated: Value(now)),
      );
      // 2. Write a log entry for sync.
      await into(db.logs).insert(
        LogsCompanion(
          account: Value(userId),
          tbl: Value(LogTable.users),
          op: Value(LogOperation.update),
          rowKey: Value(userId),
          columns: Value(
            (1 << UsersColumn.name.bit) | (1 << UsersColumn.updated.bit),
          ),
          status: Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the email address of the user identified by [userId].
  ///
  /// Pass `null` to clear the email (the column is nullable).
  ///
  /// Performs two writes atomically in a single transaction:
  /// 1. Updates `users.email` and `users.updated` in the local DB.
  /// 2. Appends a row to the `logs` table so the sync engine can replay the
  ///    mutation to the server when online.
  ///
  /// The reactive [watchActiveAccount] stream will emit the updated
  /// [Authenticated] automatically because it joins against the `users` table.
  Future<void> updateEmail(String userId, String? email) async {
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await transaction(() async {
      // 1. Update the users table.
      await (update(db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(email: Value(email), updated: Value(now)),
      );
      // 2. Write a log entry for sync.
      await into(db.logs).insert(
        LogsCompanion(
          account: Value(userId),
          tbl: Value(LogTable.users),
          op: Value(LogOperation.update),
          rowKey: Value(userId),
          columns: Value(
            (1 << UsersColumn.email.bit) | (1 << UsersColumn.updated.bit),
          ),
          status: Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Records the intent to sync a profile image change for [userId].
  ///
  /// **Currently blocked (P8):** There is no gRPC endpoint to request a fresh
  /// presigned PUT URL on demand. Profile image changes are local-only for now
  /// (the file is saved to `FileCache.profilePath(userId)` by the UI).
  ///
  /// When P8 is resolved this method should write a log entry so the sync
  /// engine can upload the image. For now it is a no-op placeholder.
  Future<void> logProfileImageChange(String userId) async {
    // TODO(P8): Write a log entry once the upload-URL endpoint exists.
    // The sync engine will handle profile images via a dedicated file-sync
    // mechanism — no DB column exists for the image itself.
  }

  /// Marks the user as deleted and removes the account from this device.
  ///
  /// Performs three writes atomically in a single transaction:
  /// 1. Sets `users.status` to [UserStatus.deleted] and updates `users.updated`.
  /// 2. Appends a row to the `logs` table so the sync engine can replay the
  ///    status change to the server when online.
  /// 3. Deletes the account row from the `accounts` table (local session only —
  ///    the user row is kept so the log entry has a valid `row_key` reference
  ///    until the sync engine processes it).
  ///
  /// After this call, the account is no longer available for login on this
  /// device. The server will process the deletion request when the sync engine
  /// replays the log entry.
  Future<void> deleteUserAccount(String userId) async {
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    await transaction(() async {
      // 1. Mark user as deleted.
      await (update(db.users)..where((t) => t.id.equals(userId))).write(
        UsersCompanion(status: Value(UserStatus.deleted), updated: Value(now)),
      );
      // 2. Write a log entry for sync.
      await into(db.logs).insert(
        LogsCompanion(
          account: Value(userId),
          tbl: Value(LogTable.users),
          op: Value(LogOperation.update),
          rowKey: Value(userId),
          columns: Value(
            (1 << UsersColumn.status.bit) | (1 << UsersColumn.updated.bit),
          ),
          status: Value(LogStatus.pending),
          created: Value(now),
        ),
      );
      // 3. Remove the local session row.
      await (delete(accounts)..where((t) => t.id.equals(userId))).go();
    });
    sync.schedulePush();
  }
}
