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
  await client.active();

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
/// - All account persistence goes through [AccountsDao] and [UsersDao];
///   no raw DB access here.
/// - The only network calls made in this class are token refreshes via
///   [_refresh]. Everything else is local DB reads/writes.
class Client {
  Client._(this._channel, this._accountsDao, this._usersDao, this._logsDao) {
    authentication = Authentication(_channel, _usersDao);
  }

  final ClientChannel _channel;
  final AccountsDao _accountsDao;
  final UsersDao _usersDao;
  // ignore: unused_field — will be used by the sync engine in Task Group 2
  final LogsDao _logsDao;

  /// gRPC wrapper for the Authentication service.
  /// Used by [_refresh] and exposed for use in `lib/services/authentication.dart`.
  late final Authentication authentication;

  // ───────────────────────────────────────────────────────────────────────────
  // Factory
  // ───────────────────────────────────────────────────────────────────────────

  /// Creates a [Client] by opening a gRPC channel and resolving DAOs from the
  /// global [db] singleton (which must already be initialised).
  static Future<Client> create() async {
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
      return _refresh(authenticated.refreshToken);
    }

    accessToken = authenticated.accessToken;
    refreshToken = authenticated.refreshToken;
    cache.currentUser = authenticated;
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
  }

  /// Switches the active session to the account identified by [id].
  ///
  /// Returns the [Authenticated] for [id] on success, or `null` when:
  /// - The account is not found in the local DB.
  /// - The refresh token has expired (account is deleted; caller must
  ///   redirect to login for that account).
  /// - A token refresh failed.
  Future<Authenticated?> switchAccount(String id) async {
    final all = await _accountsDao.getAllAccounts();
    final matches = all.where((a) => a.user.id == id);
    if (matches.isEmpty) return null;

    final authenticated = matches.first;

    if (authenticated.isRefreshTokenExpired) {
      await _accountsDao.deleteAccount(id);
      return null;
    }

    if (authenticated.isTokenExpired) {
      return _refresh(authenticated.refreshToken);
    }

    await _accountsDao.setActiveAccount(id);
    accessToken = authenticated.accessToken;
    refreshToken = authenticated.refreshToken;
    cache.currentUser = authenticated;
    return authenticated;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Logout
  // ───────────────────────────────────────────────────────────────────────────

  /// Logs out the currently active account.
  ///
  /// - Deletes the active account row from the local DB.
  /// - Clears the in-memory cache.
  /// - If exactly one account remains, it is automatically activated and its
  ///   tokens are refreshed into memory.
  /// - If more than one account remains, none is auto-selected; the UI must
  ///   prompt the user to pick.
  /// - If no accounts remain, the app returns to the unauthenticated state.
  Future<void> logOut() async {
    final authenticated = await _accountsDao.getActiveAccount();
    if (authenticated == null) return;

    await _accountsDao.deleteAccount(authenticated.user.id);
    cache.clear();

    final remaining = await _accountsDao.getAllAccounts();
    if (remaining.isEmpty) return;

    if (remaining.length == 1) {
      final first = remaining.first;
      await _accountsDao.setActiveAccount(first.user.id);
      await saveAccount(first);
      cache.currentUser = first;
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
}
