import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import 'core/app_cache.dart';
import 'core/constants.dart';
import 'database/database.dart';
import 'database/daos/accounts_dao.dart';
import 'database/daos/logs_dao.dart';
import 'database/daos/memberships_dao.dart';
import 'database/daos/schools_dao.dart';
import 'database/daos/plans_dao.dart';
import 'database/daos/roles_dao.dart';
import 'database/daos/settings_dao.dart';
import 'database/daos/system_stats_dao.dart';
import 'database/daos/users_dao.dart';
import 'models/authenticated.dart';
import 'models/result.dart';
import 'services/authentication.dart';
import 'sync/sync_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Globals
// ─────────────────────────────────────────────────────────────────────────────

/// Short-lived access token kept in memory for fast access during a session.
/// Always written through to the DB via [AccountsDao] on change.
late String accessToken;

/// Long-lived refresh token kept in memory for fast access during a session.
/// Always written through to the DB via [AccountsDao] on change.
late String refreshToken;

/// Global in-memory cache for hot data. Cleared entirely on logout.
final cache = AppCache();

/// The singleton [Client] instance, initialised by [initializeClient].
late final Client client;

late final AccountsDao accountsDao;
late final UsersDao usersDao;
late final LogsDao logsDao;
late final SchoolsDao schoolsDao;
late final MembershipsDao membershipsDao;
late final RolesDao rolesDao;
late final PlansDao plansDao;
late final SettingsDao settingsDao;
late final SystemStatsDao systemStatsDao;

/// Global getter so services can trigger a push via `sync.schedulePush()`.
///
/// Safe to call fire-and-forget from any service or DAO after writing to the
/// `logs` table. [SyncEngine.schedulePush] defers the actual push to the next
/// event-loop turn, so the enclosing Drift transaction is guaranteed to have
/// committed by the time [SyncEngine.pushNow] queries the `logs` table.
///
/// If sync is not running (offline or no active account), the call is a no-op
/// and mutations remain queued for the next push cycle (5-second safety timer).
SyncEngine get sync => client.syncEngine;

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap
// ─────────────────────────────────────────────────────────────────────────────

/// Initialises the database singleton and the [Client], then restores the
/// active session (if any) from the local [Accounts] table.
///
/// Also starts a persistent subscription to [AccountsDao.watchActiveAccount]
/// so that [cache.currentUser] is always up-to-date when the `users` or
/// `accounts` table changes (e.g. after a name/email edit on the Account page).
///
/// Must be called in `main.dart` before `runApp()`.
Future<void> initializeClient() async {
  db = AppDatabase();
  client = await Client.create();

  // NOTE: Do NOT call client.active() here — the splash screen calls it
  // during _resolveAuthAndNavigate(). Calling it twice causes _startSync()
  // to fire twice, which stops the first sync session (killing its push
  // timer and streams) and starts a fresh one. Any pushNow() calls that
  // happen between the two starts are lost.

  // Keep cache.currentUser in sync with every DB change (Task 3.5).
  // The stream fires whenever the active account row OR its joined users row
  // changes, so edits made on the Account page are reflected everywhere
  // (home screen top bar, etc.) without manual refresh.
  accountsDao.watchActiveAccount().listen((auth) {
    cache.currentUser = auth;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Client
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level gRPC channel manager and account lifecycle controller.
///
/// Responsibilities:
/// - Owns the [ClientChannel] used by all gRPC service wrappers.
/// - Manages the active account session: read, switch, refresh, and log out.
/// - Owns the [SyncEngine] and starts/stops it in lock-step with the active
///   account lifecycle.
/// - All account persistence goes through [AccountsDao] and [UsersDao];
///   no raw DB access here.
/// - The only network calls made in this class are token refreshes via
///   [_refresh]. Everything else is local DB reads/writes.
class Client {
  Client._(this._channel, this._accountsDao, this._usersDao, this._logsDao) {
    authentication = Authentication(_channel, _usersDao);
    syncEngine = SyncEngine(_channel, _accountsDao, _logsDao);
  }

  final ClientChannel _channel;
  final AccountsDao _accountsDao;
  final UsersDao _usersDao;
  final LogsDao _logsDao;

  /// gRPC wrapper for the Authentication service.
  /// Used by [_refresh] and exposed for use in `lib/services/authentication.dart`.
  late final Authentication authentication;

  /// Bidirectional sync engine — pushes local mutations to the server and
  /// receives inbound deltas. Started/stopped automatically with the active
  /// account lifecycle.
  late final SyncEngine syncEngine;

  // ───────────────────────────────────────────────────────────────────────────
  // Factory
  // ───────────────────────────────────────────────────────────────────────────

  /// Creates a [Client] by opening a gRPC channel and resolving DAOs from the
  /// global [db] singleton (which must already be initialised).
  static Future<Client> create() async {
    debugPrint('[Client] Creating gRPC channel → $kDomain:$kPort (insecure)');
    final channel = ClientChannel(
      kDomain,
      port: kPort,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    accountsDao = AccountsDao(db);
    usersDao = UsersDao(db);
    logsDao = LogsDao(db);
    schoolsDao = SchoolsDao(db);
    membershipsDao = MembershipsDao(db);
    rolesDao = RolesDao(db);
    plansDao = PlansDao(db);
    settingsDao = SettingsDao(db);
    systemStatsDao = SystemStatsDao(db);
    return Client._(channel, accountsDao, usersDao, logsDao);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Session reads
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns the currently active [Authenticated] user, or `null` if no active
  /// session exists or the session is unrecoverable.
  ///
  /// This is a **pure DB read** — no network call is made except when the
  /// access token has expired and a refresh is needed.
  ///
  /// Decision tree:
  /// 1. No active account row → return `null`.
  /// 2. Refresh token expired → delete the account row, clear cache, return `null`
  ///    (caller must redirect to login).
  /// 3. Access token expired → call [_refresh]; return the refreshed result.
  /// 4. Tokens valid → populate in-memory globals + cache, return [Authenticated].
  ///
  /// On success (steps 3 or 4), the [SyncEngine] is started for this account
  /// so that local mutations begin pushing and inbound deltas begin arriving.
  Future<Authenticated?> active() async {
    // getActiveAccount() now returns a fully joined Authenticated? directly.
    final authenticated = await _accountsDao.getActiveAccount();
    if (authenticated == null) return null;

    if (authenticated.isRefreshTokenExpired) {
      await _accountsDao.deleteAccount(authenticated.user.id);
      cache.clear();
      return null;
    }

    if (authenticated.isTokenExpired) {
      // _refresh() calls saveAccount() which already starts sync internally.
      return await _refresh(authenticated.refreshToken);
    }

    accessToken = authenticated.accessToken;
    refreshToken = authenticated.refreshToken;
    cache.currentUser = authenticated;

    _startSync(authenticated);

    return authenticated;
  }

  /// Returns all locally stored accounts as a map keyed by user id.
  Future<Map<String, Authenticated>> accounts() async {
    final all = await _accountsDao.getAllAccounts();
    return {for (final auth in all) auth.user.id: auth};
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Session writes
  // ───────────────────────────────────────────────────────────────────────────

  /// Persists [authenticated] to both the `users` and `accounts` tables
  /// without activating the account. Used when adding a second (or subsequent)
  /// account after login.
  ///
  /// To also make the account active, call [saveAccount] followed by
  /// [AccountsDao.setActiveAccount].
  Future<void> addAccount(Authenticated authenticated) async {
    await db.transaction(() async {
      await _usersDao.upsertUser(authenticated.toUserCompanion());
      await _accountsDao.upsertAccount(authenticated.toAccountCompanion());
    });
  }

  /// Persists [authenticated] to both the `users` and `accounts` tables and
  /// updates the in-memory token globals.
  ///
  /// Token expiry values are (re-)computed from `now` at the moment of this
  /// call, matching the backend's `issued_at + duration` semantics:
  /// - `tokenExpiry`        = now + [kAccessTokenDuration]
  /// - `refreshTokenExpiry` = now + [kRefreshTokenDuration]
  ///
  /// Both writes are wrapped in a single transaction for atomicity.
  ///
  /// If the [SyncEngine] is already running (e.g. after a token refresh while
  /// sync was active), it is restarted with the new access token so that gRPC
  /// calls use the fresh credentials.
  Future<void> saveAccount(Authenticated authenticated) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newTokenExpiry = now + kAccessTokenDuration.inMilliseconds;
    final newRefreshExpiry = now + kRefreshTokenDuration.inMilliseconds;

    accessToken = authenticated.accessToken;
    refreshToken = authenticated.refreshToken;

    // Rebuild with updated expiry + timestamp values before writing to DB.
    final updated = Authenticated(
      user: authenticated.user,
      accessToken: authenticated.accessToken,
      refreshToken: authenticated.refreshToken,
      tokenExpiry: newTokenExpiry,
      refreshTokenExpiry: newRefreshExpiry,
      lastSyncedAt: authenticated.lastSyncedAt,
      lastSeq: authenticated.lastSeq,
      theme: authenticated.theme,
      created: authenticated.created,
      updated: now,
    );

    await db.transaction(() async {
      await _usersDao.upsertUser(updated.toUserCompanion());
      await _accountsDao.upsertAccount(updated.toAccountCompanion());
      await _accountsDao.setActiveAccount(updated.user.id);
    });

    cache.currentUser = updated;

    // Start sync for this account (or restart with fresh token if already
    // running). On first login saveAccount is called before the user reaches
    // the home screen — without this, sync would not begin until the next
    // cold start when active() is called from the splash screen.
    _startSync(updated);
  }

  /// Switches the active session to the account identified by [id].
  ///
  /// Returns the [Authenticated] for [id] on success, or `null` when:
  /// - The account is not found in the local DB.
  /// - The refresh token has expired (account is deleted; caller must
  ///   redirect to login for that account).
  /// - A token refresh failed.
  ///
  /// The [SyncEngine] is stopped for the previous account and restarted for
  /// the new one.
  Future<Authenticated?> switchAccount(String id) async {
    // Stop sync for the current account before switching.
    await syncEngine.stop();

    final all = await _accountsDao.getAllAccounts();
    final matches = all.where((a) => a.user.id == id);
    if (matches.isEmpty) return null;

    final authenticated = matches.first;

    if (authenticated.isRefreshTokenExpired) {
      await _accountsDao.deleteAccount(id);
      return null;
    }

    if (authenticated.isTokenExpired) {
      // _refresh() calls saveAccount() which already starts sync internally.
      return await _refresh(authenticated.refreshToken);
    }

    await _accountsDao.setActiveAccount(id);
    accessToken = authenticated.accessToken;
    refreshToken = authenticated.refreshToken;
    cache.currentUser = authenticated;

    _startSync(authenticated);

    return authenticated;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Logout
  // ───────────────────────────────────────────────────────────────────────────

  /// Logs out the currently active account.
  ///
  /// - Stops the [SyncEngine] for the current account.
  /// - Deletes the active account row from the local DB.
  /// - Clears the in-memory cache.
  /// - If exactly one account remains, it is automatically activated and its
  ///   tokens are refreshed into memory, and sync is restarted.
  /// - If more than one account remains, none is auto-selected; the UI must
  ///   prompt the user to pick.
  /// - If no accounts remain, **all local data is wiped** via
  ///   [AppDatabase.deleteAllData] to prevent stale records (e.g. a `users`
  ///   row whose phone was reassigned server-side) from causing unique
  ///   constraint violations on the next login.
  Future<void> logOut() async {
    // Stop sync before deleting the account.
    await syncEngine.stop();

    final authenticated = await _accountsDao.getActiveAccount();
    if (authenticated == null) return;

    await _accountsDao.deleteAccount(authenticated.user.id);
    cache.clear();
    accessToken = '';
    refreshToken = '';

    final remaining = await _accountsDao.getAllAccounts();

    if (remaining.isEmpty) {
      // No accounts left — wipe everything so stale data never conflicts
      // with a fresh login (e.g. phone UNIQUE constraint on users table).
      await db.deleteAllData();
      return;
    }

    if (remaining.length == 1) {
      final first = remaining.first;
      await _accountsDao.setActiveAccount(first.user.id);
      await saveAccount(first);
      cache.currentUser = first;
      // saveAccount already restarts sync if it was running, but since we
      // just stopped it, we need to start it explicitly for the new account.
      _startSync(first);
    }
    // 2+ remaining: leave all inactive; UI will prompt the user to choose.
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal — token refresh
  // ───────────────────────────────────────────────────────────────────────────

  /// Attempts to obtain a new access token using [token] as the refresh token.
  ///
  /// On success: persists the refreshed [Authenticated] via [saveAccount],
  /// updates [cache.currentUser], and returns the new [Authenticated].
  ///
  /// On failure: returns `null`. The caller is responsible for deciding whether
  /// to force a full re-login (e.g. by returning `null` from [active]).
  Future<Authenticated?> _refresh(String token) async {
    refreshToken = token;
    final result = await authentication.refresh();
    switch (result) {
      case Ok(:final value):
        await saveAccount(value);
        cache.currentUser = value;
        return value;
      case Err():
        return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal — sync lifecycle
  // ───────────────────────────────────────────────────────────────────────────

  /// Starts (or restarts) the [SyncEngine] for the given [authenticated] user.
  ///
  /// This is a fire-and-forget call — if the sync engine fails to start
  /// (e.g. no network), it will retry internally via its reconnection logic.
  void _startSync(Authenticated authenticated) {
    debugPrint(
      '[Client] _startSync() — account=${authenticated.user.id}, '
      'lastSeq=${authenticated.lastSeq}, '
      'target=$kDomain:$kPort',
    );
    syncEngine.start(
      accountId: authenticated.user.id,
      accessToken: authenticated.accessToken,
      lastSeq: authenticated.lastSeq,
    );
  }
}
