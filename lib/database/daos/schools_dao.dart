import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/owners.dart';
import '../tables/schools.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

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

  /// Emits a single school row (or `null`) whenever the row with the given
  /// [id] changes. Unlike [watchSchools], this sets up a targeted query that
  /// only tracks one row instead of the entire table.
  ///
  /// Used by the school detail screen to keep the header, edit button, and
  /// body in sync with a single subscription.
  Stream<SchoolsData?> watchSchoolById(String id) {
    return (select(schools)..where((t) => t.id.equals(id))).watchSingleOrNull();
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
  /// Writes a single log entry with [SyncAction.createSchool] containing a
  /// [CreateSchoolPayload] that includes both the school data and the owner
  /// identity (invitation pattern). The server handles user lookup/creation
  /// from the owner fields embedded in the payload.
  ///
  /// [accountId] is the currently active account's user id, used to associate
  /// log entries with the correct account.
  /// [ownerUser] is the [UsersData] for the owner being linked.
  Future<void> createSchool({
    required SchoolsCompanion school,
    required UsersData ownerUser,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createSchool,
      schoolId: null,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      // Insert the school row.
      await into(schools).insert(school);

      // Insert the owner row.
      final schoolId = school.id.value;
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await into(owners).insert(
        OwnersCompanion(
          school: Value(schoolId),
          user: Value(ownerUser.id),
          created: Value(nowSec),
        ),
      );

      // Build the CreateSchoolPayload with embedded owner info.
      final payload = sync_pb.CreateSchoolPayload(
        id: schoolId,
        name: school.name.value,
        ownerId: ownerUser.id,
        ownerPhone: ownerUser.phone,
        ownerName: ownerUser.name,
      );
      if (school.motto.present && school.motto.value != null) {
        payload.motto = school.motto.value!;
      }
      if (school.phone.present && school.phone.value != null) {
        payload.phone = school.phone.value!;
      }
      if (school.email.present && school.email.value != null) {
        payload.email = school.email.value!;
      }
      if (school.county.present) {
        payload.county = school.county.value;
      }
      if (school.domain.present && school.domain.value != null) {
        payload.domain = school.domain.value!;
      }
      if (school.established.present && school.established.value != null) {
        payload.established = school.established.value!;
      }
      if (ownerUser.email != null) {
        payload.ownerEmail = ownerUser.email!;
      }

      // Log: single createSchool action.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createSchool),
          resource: Value(school.name.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the specified fields on a school row and writes a log entry
  /// with [SyncAction.updateSchool] containing an [UpdateSchoolPayload],
  /// both in a single transaction.
  ///
  /// Only columns whose [Value] is present in [changes] are included in the
  /// payload. The server uses protobuf `has*()` semantics to determine which
  /// fields were changed.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateSchoolDetails(
    String schoolId,
    SchoolsCompanion changes, {
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateSchool,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      await (update(
        schools,
      )..where((t) => t.id.equals(schoolId))).write(changes);

      // Build the UpdateSchoolPayload with only changed fields.
      final payload = sync_pb.UpdateSchoolPayload(id: schoolId);
      bool hasChanges = false;

      if (changes.name.present) {
        payload.name = changes.name.value;
        hasChanges = true;
      }
      if (changes.motto.present) {
        if (changes.motto.value != null) payload.motto = changes.motto.value!;
        hasChanges = true;
      }
      if (changes.phone.present) {
        if (changes.phone.value != null) payload.phone = changes.phone.value!;
        hasChanges = true;
      }
      if (changes.email.present) {
        if (changes.email.value != null) payload.email = changes.email.value!;
        hasChanges = true;
      }
      if (changes.county.present) {
        payload.county = changes.county.value;
        hasChanges = true;
      }
      if (changes.domain.present) {
        if (changes.domain.value != null) {
          payload.domain = changes.domain.value!;
        }
        hasChanges = true;
      }
      if (changes.established.present) {
        if (changes.established.value != null) {
          payload.established = changes.established.value!;
        }
        hasChanges = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        hasChanges = true;
      }

      if (!hasChanges) return; // nothing tracked to log

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Try to get school name for resource display; fall back to schoolId.
      String resourceName = schoolId;
      if (changes.name.present) {
        resourceName = changes.name.value;
      } else {
        final existing = await getSchool(schoolId);
        if (existing != null) resourceName = existing.name;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateSchool),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
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
  Future<void> purgeSchool(String schoolId, {required String accountId}) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteSchool,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Get the school name for human-readable resource display.
      final existing = await getSchool(schoolId);
      final resourceName = existing?.name ?? schoolId;

      final payload = sync_pb.DeleteSchoolPayload(id: schoolId);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteSchool),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );

      await (delete(schools)..where((t) => t.id.equals(schoolId))).go();
    });
    sync.schedulePush();
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

  /// Links an existing user as an owner of a school and writes a log entry
  /// with [SyncAction.createOwner], both in a single transaction.
  ///
  /// The caller must verify that the user is not already an owner of this
  /// school before calling (see [isOwner]).
  ///
  /// [ownerUser] is the full [UsersData] row for the user being linked.
  /// [accountId] is the currently active account's user id, used to associate
  /// the log entry with the correct account.
  Future<void> linkOwner({
    required String schoolId,
    required UsersData ownerUser,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createOwner,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      await into(owners).insert(
        OwnersCompanion(
          school: Value(schoolId),
          user: Value(ownerUser.id),
          created: Value(nowSeconds),
        ),
      );

      final payload = sync_pb.CreateOwnerPayload(
        school: schoolId,
        userId: ownerUser.id,
        phone: ownerUser.phone,
        name: ownerUser.name,
      );
      if (ownerUser.email != null) {
        payload.email = ownerUser.email!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createOwner),
          resource: Value(ownerUser.phone),
          payload: Value(payload.writeToBuffer()),
          created: Value(now),
        ),
      );
    });
    sync.schedulePush();
  }
}
