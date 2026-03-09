import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../database/tables/enums.dart';

/// Domain model representing the currently authenticated user.
///
/// Wraps a full [UsersData] row (identity, contact, privilege) alongside the
/// session fields from [AccountsData] (tokens, expiry, sync state, theme).
///
/// Constructed via [Authenticated.fromRows] from the two Drift-generated data
/// classes. Written back to the DB via [toAccountCompanion] (accounts table)
/// and [toUserCompanion] (users table) — always written separately so each
/// table can be updated independently.
///
/// This class is **not** the proto-generated `Authenticated` message. The proto
/// class is only used as a deserialization target inside
/// `lib/services/authentication.dart` and is never referenced beyond that file.
///
/// There is no `currentSchoolId`, `currentRole`, or `currentEntry` field.
/// School context is pure navigational state managed by [SchoolContext] and
/// never persisted to the database.
class Authenticated {
  const Authenticated({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenExpiry,
    required this.refreshTokenExpiry,
    this.lastSyncedAt,
    this.lastSeq = 0,
    required this.theme,
    required this.created,
    required this.updated,
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Identity (delegated to the nested UsersData row)
  // ──────────────────────────────────────────────────────────────────────────

  /// Full user row from the `users` table.
  ///
  /// Access identity fields via this nested object:
  /// - `user.id`     — server-issued user identifier
  /// - `user.phone`  — 10-digit local Kenyan format
  /// - `user.name`   — display name
  /// - `user.email`  — optional email address
  /// - `user.level`  — [UserLevel] privilege
  /// - `user.status` — [UserStatus] account state
  final UsersData user;

  // ──────────────────────────────────────────────────────────────────────────
  // Tokens
  // ──────────────────────────────────────────────────────────────────────────

  /// Short-lived JWT used to authenticate API requests.
  final String accessToken;

  /// Long-lived token used to obtain a new [accessToken] without re-login.
  final String refreshToken;

  /// Milliseconds since Unix epoch when [accessToken] expires
  /// (`issued_at + kAccessTokenDuration`).
  final int tokenExpiry;

  /// `true` when [accessToken] has expired and a refresh is required before
  /// making any authenticated API call.
  bool get isTokenExpired =>
      DateTime.now().millisecondsSinceEpoch > tokenExpiry;

  /// Milliseconds since Unix epoch when [refreshToken] expires
  /// (`issued_at + kRefreshTokenDuration`).
  /// When past this point the user must go through full login again.
  final int refreshTokenExpiry;

  /// `true` when [refreshToken] has also expired — full re-login is required.
  bool get isRefreshTokenExpired =>
      DateTime.now().millisecondsSinceEpoch > refreshTokenExpiry;

  // ──────────────────────────────────────────────────────────────────────────
  // Sync metadata
  // ──────────────────────────────────────────────────────────────────────────

  /// Milliseconds since Unix epoch of the last successful sync with the server.
  /// `null` means the device has never completed a sync for this account.
  final int? lastSyncedAt;

  /// Server's monotonically increasing sequence number for sync tracking.
  /// 0 means "never synced". Updated after each successful watch delta is
  /// applied so the next `WatchRequest` can resume from this point.
  final int lastSeq;

  // ──────────────────────────────────────────────────────────────────────────
  // Theme preference
  // ──────────────────────────────────────────────────────────────────────────

  /// The user's preferred theme mode, persisted in `accounts.theme`.
  /// Defaults to [AppThemeMode.system] on first login.
  final AppThemeMode theme;

  // ──────────────────────────────────────────────────────────────────────────
  // Timestamps (from the accounts row)
  // ──────────────────────────────────────────────────────────────────────────

  /// Milliseconds since Unix epoch when this account row was first created
  /// locally (i.e. when the user first logged in on this device).
  final int created;

  /// Milliseconds since Unix epoch of the last local update to this row.
  final int updated;

  // ──────────────────────────────────────────────────────────────────────────
  // Factories / converters
  // ──────────────────────────────────────────────────────────────────────────

  /// Constructs an [Authenticated] from a pair of Drift-generated data classes.
  ///
  /// [account] supplies token, expiry, sync, theme, and timestamp fields.
  /// [user] is stored directly — no field copying.
  ///
  /// BigInt columns from the generated [AccountsData] are narrowed to [int]
  /// via `.toInt()`. This is safe because all millisecond-epoch values fit
  /// within a 64-bit signed integer.
  factory Authenticated.fromRows(AccountsData account, UsersData user) {
    return Authenticated(
      user: user,
      accessToken: account.accessToken,
      refreshToken: account.refreshToken,
      tokenExpiry: account.tokenExpiry.toInt(),
      refreshTokenExpiry: account.refreshTokenExpiry.toInt(),
      lastSyncedAt: account.lastSyncedAt?.toInt(),
      lastSeq: account.lastSeq.toInt(),
      theme: account.theme,
      created: account.created.toInt(),
      updated: account.updated.toInt(),
    );
  }

  /// Converts the session fields of this model to a Drift [AccountsCompanion]
  /// suitable for insert or update operations on the `accounts` table.
  ///
  /// Only account-table columns are written. User identity fields are
  /// intentionally excluded — those go through [toUserCompanion] and
  /// [UsersDao.upsertUser].
  ///
  /// [isActive] controls the `is_active` column. Pass `true` when persisting
  /// the account that should become the active session. Defaults to `false`
  /// so that background upserts (e.g. token refresh) do not accidentally
  /// change which account is active.
  AccountsCompanion toAccountCompanion({bool isActive = false}) {
    return AccountsCompanion(
      id: Value(user.id),
      accessToken: Value(accessToken),
      refreshToken: Value(refreshToken),
      tokenExpiry: Value(BigInt.from(tokenExpiry)),
      refreshTokenExpiry: Value(BigInt.from(refreshTokenExpiry)),
      isActive: Value(isActive),
      lastSyncedAt: Value(
        lastSyncedAt != null ? BigInt.from(lastSyncedAt!) : null,
      ),
      lastSeq: Value(BigInt.from(lastSeq)),
      theme: Value(theme),
      created: Value(BigInt.from(created)),
      updated: Value(BigInt.from(updated)),
    );
  }

  /// Converts the user identity fields of this model to a Drift
  /// [UsersCompanion] suitable for insert or update operations on the
  /// `users` table.
  ///
  /// Used whenever user data needs to be written independently of the session
  /// row — for example when the user updates their name on the setup screen.
  UsersCompanion toUserCompanion() {
    return UsersCompanion(
      id: Value(user.id),
      phone: Value(user.phone),
      email: Value(user.email),
      name: Value(user.name),
      level: Value(user.level),
      status: Value(user.status),
      created: Value(user.created),
      updated: Value(user.updated),
    );
  }

  @override
  String toString() =>
      'Authenticated(id: ${user.id}, phone: ${user.phone}, name: ${user.name}, '
      'level: ${user.level}, status: ${user.status}, theme: $theme, '
      'tokenExpired: $isTokenExpired, refreshExpired: $isRefreshTokenExpired)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Authenticated &&
          runtimeType == other.runtimeType &&
          user.id == other.user.id &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken;

  @override
  int get hashCode => Object.hash(user.id, accessToken, refreshToken);
}
