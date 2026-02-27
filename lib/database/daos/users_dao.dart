import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/users.dart';

part 'users_dao.g.dart';

/// DAO for the [Users] table.
///
/// Provides reactive streams and one-shot reads/writes for user rows.
/// User rows are written by the sync engine when the server pushes user data.
/// The authentication service writes the current user's row via [upsertUser].
@DriftAccessor(tables: [Users])
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

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns the user row for [id], or [null] if not found.
  Future<UsersData?> getUser(String id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new user row, or replaces an existing row with the same [id].
  ///
  /// Called by the sync engine when it receives a user delta from the server,
  /// and by the authentication service immediately after a successful login to
  /// persist the authenticated user's profile locally.
  Future<void> upsertUser(UsersCompanion user) {
    return into(users).insertOnConflictUpdate(user);
  }
}
