import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/owners.dart';
import '../tables/schools.dart';
import '../tables/users.dart';

part 'schools_dao.g.dart';

/// DAO for the [Schools] and related [Owners] table.
///
/// Provides reactive streams and one-shot reads for school data. Sync-sourced
/// writes use [upsertSchool]. Local mutations (create, update, status change)
/// write corresponding entries to the [Logs] table inside the same transaction.
@DriftAccessor(tables: [Schools, Owners, Users, Logs])
class SchoolsDao extends DatabaseAccessor<AppDatabase> with _$SchoolsDaoMixin {
  SchoolsDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Emits the full list of schools stored locally whenever any school row
  /// changes. The list is unordered — callers should sort as needed for display.
  ///
  /// Used by the home screen membership list and other consumers that need an
  /// unfiltered school stream.
  Stream<List<SchoolsData>> watchSchools() {
    return select(schools).watch();
  }

  /// Emits the full list of all schools ordered by name ascending whenever
  /// any row in the [Schools] table changes.
  ///
  /// Used by the system dashboard Schools section.
  Stream<List<SchoolsData>> watchAllSchools() {
    return (select(
      schools,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  /// Emits the list of owners for a specific school, joined with the [Users]
  /// table to include full user details. Ordered by user name ascending.
  ///
  /// Each emission is a list of `(OwnersData, UsersData)` pairs. The stream
  /// re-emits whenever the [Owners] or [Users] table changes for matching rows.
  ///
  /// Used by the school detail screen's Owners tab.
  Stream<List<({OwnersData owner, UsersData user})>> watchOwnersForSchool(
    String schoolId,
  ) {
    final query =
        select(owners).join([innerJoin(users, users.id.equalsExp(owners.user))])
          ..where(owners.school.equals(schoolId))
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return (owner: row.readTable(owners), user: row.readTable(users));
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // One-shot reads
  // ---------------------------------------------------------------------------

  /// Returns the school with the given [id], or [null] if not found locally.
  Future<SchoolsData?> getSchool(String id) {
    return (select(schools)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Sync-sourced writes
  // ---------------------------------------------------------------------------

  /// Inserts a new school row, or replaces an existing row with the same [id].
  ///
  /// Called by the sync engine when the server pushes a school insert or
  /// update delta. Does **not** write a log entry.
  Future<void> upsertSchool(SchoolsCompanion school) {
    return into(schools).insertOnConflictUpdate(school);
  }

  // ---------------------------------------------------------------------------
  // Local mutation writes
  // ---------------------------------------------------------------------------

  /// Creates a new school and links an existing user as its first owner, both
  /// in a single transaction.
  ///
  /// Also writes two log entries:
  /// - An INSERT log for the `schools` table (row_key = school id).
  /// - An INSERT log for the `owners` table (row_key = "{schoolId}|{ownerUserId}").
  ///
  /// If the owner user does not yet exist locally, call [UsersDao.inviteUser]
  /// first (in the same parent [db.transaction] block in the calling code),
  /// then pass the new user's id as [ownerUserId].
  ///
  /// [accountId] is the currently active account's user id, used to associate
  /// log entries with the correct account.
  Future<void> createSchool({
    required SchoolsCompanion school,
    required String ownerUserId,
    required String accountId,
  }) {
    return transaction(() async {
      // Insert the school row.
      await into(schools).insert(school);

      // Insert the owner row.
      final schoolId = school.id.value;
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(owners).insert(
        OwnersCompanion(
          school: Value(schoolId),
          user: Value(ownerUserId),
          created: Value(now),
        ),
      );

      // Log: school insert.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.schools),
          op: const Value(LogOperation.insert),
          rowKey: Value(schoolId),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );

      // Log: owner insert — composite row_key = "{schoolId}|{ownerUserId}".
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.owners),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$ownerUserId'),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
  }

  /// Updates the specified fields on a school row and writes a log update entry
  /// with the correct [SchoolsColumn] bitmask, both in a single transaction.
  ///
  /// Only columns whose [Value] is present in [changes] are updated.
  /// The [SchoolsCompanion.updated] field must be included in [changes] with
  /// the current timestamp (seconds since epoch).
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateSchoolDetails(
    String schoolId,
    SchoolsCompanion changes, {
    required String accountId,
  }) {
    return transaction(() async {
      await (update(
        schools,
      )..where((t) => t.id.equals(schoolId))).write(changes);

      int mask = 0;
      if (changes.name.present) mask |= (1 << SchoolsColumn.name.bit);
      if (changes.motto.present) mask |= (1 << SchoolsColumn.motto.bit);
      if (changes.phone.present) mask |= (1 << SchoolsColumn.phone.bit);
      if (changes.email.present) mask |= (1 << SchoolsColumn.email.bit);
      if (changes.county.present) mask |= (1 << SchoolsColumn.county.bit);
      if (changes.domain.present) mask |= (1 << SchoolsColumn.domain.bit);
      if (changes.established.present) {
        mask |= (1 << SchoolsColumn.established.bit);
      }
      if (changes.status.present) mask |= (1 << SchoolsColumn.status.bit);
      if (changes.updated.present) mask |= (1 << SchoolsColumn.updated.bit);

      if (mask == 0) return; // nothing tracked to log

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.schools),
          op: const Value(LogOperation.update),
          rowKey: Value(schoolId),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
  }

  /// Updates a school's [SchoolStatus] and the [SchoolsData.updated] timestamp,
  /// and writes a log update entry, both in a single transaction.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateSchoolStatus(
    String schoolId,
    SchoolStatus status, {
    required String accountId,
  }) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return updateSchoolDetails(
      schoolId,
      SchoolsCompanion(status: Value(status), updated: Value(nowSeconds)),
      accountId: accountId,
    );
  }

  /// Hard-deletes a school row from the local DB. Writes a delete log entry
  /// **before** the deletion so the sync engine can replay it to the server.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> purgeSchool(String schoolId, {required String accountId}) {
    return transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.schools),
          op: const Value(LogOperation.delete),
          rowKey: Value(schoolId),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );

      await (delete(schools)..where((t) => t.id.equals(schoolId))).go();
    });
  }

  /// Returns `true` if a row exists in [Owners] for the given
  /// `(schoolId, userId)` composite key.
  ///
  /// Used by the "Add Owner" modal to guard against duplicate links.
  Future<bool> isOwner(String schoolId, String userId) async {
    final row =
        await (select(owners)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Logs an intent to sync the school logo image to the server.
  /// No DB columns are changed — this is a fire-and-forget log entry
  /// that tells the sync engine the logo bytes need uploading.
  ///
  /// Currently a no-op placeholder (same pattern as
  /// [AccountsDao.logProfileImageChange]) until the upload-URL endpoint
  /// exists on the server.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> logLogoChange(
    String schoolId, {
    required String accountId,
  }) async {
    // TODO(P8): Write a log entry once the server exposes a presigned PUT URL
    // for school logos. The sync engine will handle file uploads via a
    // dedicated file-sync mechanism — no DB column exists for the logo itself.
  }

  /// Links an existing user as an owner of a school and writes a log insert
  /// entry, both in a single transaction.
  ///
  /// The caller must verify that the user is not already an owner of this
  /// school before calling (see [isOwner]).
  ///
  /// [accountId] is the currently active account's user id, used to associate
  /// the log entry with the correct account.
  Future<void> linkOwner({
    required String schoolId,
    required String userId,
    required String accountId,
  }) {
    return transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      await into(owners).insert(
        OwnersCompanion(
          school: Value(schoolId),
          user: Value(userId),
          created: Value(nowSeconds),
        ),
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.owners),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(now),
        ),
      );
    });
  }
}
