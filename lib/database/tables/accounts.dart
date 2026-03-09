import 'package:drift/drift.dart';

import 'enums.dart';
import 'users.dart';

/// Client-only table — not synced to the server.
///
/// Stores one row per logged-in user account. Replaces `flutter_secure_storage`
/// entirely. Exactly zero or one rows may have [isActive] = true at any time,
/// enforced by the partial unique index created in `database.dart`:
///   `CREATE UNIQUE INDEX uq_accounts_active ON accounts(is_active) WHERE is_active = 1;`
///
/// User identity fields (phone, name, email, level, status) are stored in the
/// [Users] table — this table holds only session/token data and a FK → users.id.
@DataClassName('AccountsData')
class Accounts extends Table {
  @override
  String get tableName => 'accounts';

  /// User id — foreign key referencing [Users.id].
  /// ON DELETE CASCADE: deleting a user row removes the session row too.
  TextColumn get id =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();

  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();

  /// Milliseconds since epoch when the access token expires
  /// (issued_at + kAccessTokenDuration).
  Int64Column get tokenExpiry => int64()();

  /// Whether this is the currently active account session.
  /// Only one row may have isActive = 1 at a time (enforced by partial unique index).
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  /// Milliseconds since epoch of the last successful sync; null = never synced.
  Int64Column get lastSyncedAt => int64().nullable()();

  /// Milliseconds since epoch when the refresh token expires
  /// (issued_at + kRefreshTokenDuration = issued_at + 30 days).
  /// When now > refreshTokenExpiry the user must go through full login again.
  Int64Column get refreshTokenExpiry => int64()();

  /// User's preferred theme mode. Stored as a smallint mapped via
  /// [AppThemeModeConverter]. Defaults to [AppThemeMode.system] (0).
  IntColumn get theme => integer()
      .map(const AppThemeModeConverter())
      .withDefault(const Constant(0))();

  /// Milliseconds since epoch when this account row was first created locally.
  Int64Column get created => int64()();

  /// Milliseconds since epoch of the last local update to this row.
  Int64Column get updated => int64()();

  /// Server's monotonically increasing sequence number for sync tracking.
  /// Default 0 means "never synced". Updated after each successful watch
  /// delta is applied so the next `WatchRequest` can resume from this point.
  Int64Column get lastSeq => int64().withDefault(Constant(BigInt.zero))();

  @override
  Set<Column> get primaryKey => {id};
}
