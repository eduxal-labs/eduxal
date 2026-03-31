import 'dart:io';

import '../cache/file_cache.dart';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bson/bson.dart';

import '../client.dart';
import '../database/database.dart';
import '../database/daos/members_dao.dart';
import '../database/tables/enums.dart';
import '../models/result.dart';
import '../proto/services/sync.pb.dart' as sync_pb;

// ─────────────────────────────────────────────────────────────────────────────
// Phone-first resolution result
// ─────────────────────────────────────────────────────────────────────────────

/// The outcome of a phone-number lookup in the [MemberCreationService].
///
/// Used by the creation UI to decide whether to show the "enter name" step.
sealed class PhoneLookupResult {
  const PhoneLookupResult();
}

/// The phone number matched an existing local [UsersData] row.
/// The creation form can skip the name field and link directly.
final class UserFound extends PhoneLookupResult {
  const UserFound(this.user);
  final UsersData user;
}

/// The phone number is unknown locally.
/// The creation form must request a `name` and will create an invited user.
final class UserNotFound extends PhoneLookupResult {
  const UserNotFound(this.phone);
  final String phone;
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain errors
// ─────────────────────────────────────────────────────────────────────────────

/// Errors that the creation service can surface to the UI.
enum MemberCreationError {
  /// The active account could not be found — user is not logged in.
  noActiveAccount,

  /// The member (teacher/staff/guardian) already exists at this school.
  alreadyExists,

  /// The phone number supplied is in an invalid format.
  invalidPhone,

  /// An unexpected local database error occurred.
  databaseError,
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Orchestrates all member-creation flows:
///
///   - Teacher creation (phone-first)
///   - Staff creation (phone-first)
///   - Student creation (name-first, no phone required)
///   - Guardian creation (phone-first, always scoped to a student)
///
/// Every mutation writes to the local Drift database **and** enqueues a row
/// in the `logs` table for eventual sync. The UI is therefore fully
/// offline-capable — no network call is made here.
///
/// ### Usage
/// ```dart
/// final svc = MemberCreationService(MembersDao(db));
///
/// final lookup = await svc.lookupPhone('+254700000000');
/// switch (lookup) {
///   case UserFound(:final user): // pre-fill name, disable field
///   case UserNotFound():         // show name field
/// }
///
/// final result = await svc.createTeacher(
///   schoolId: schoolId,
///   phone: '+254700000000',
///   name: user?.name,           // null when user already exists
///   hiredDate: DateTime.now(),
/// );
/// ```
class MemberCreationService {
  MemberCreationService(this._dao);

  final MembersDao _dao;

  // ─────────────────────────────────────────────────────────────────────────
  // Phone-first lookup
  // ─────────────────────────────────────────────────────────────────────────

  /// Looks up a user by [phone] in the local database.
  ///
  /// Returns [UserFound] when a matching **non-deleted** row exists, or
  /// [UserNotFound] when the phone number is unknown locally or belongs to
  /// a deleted user. Deleted users are treated as if they don't exist — the
  /// UI will ask for a name and the `createXxx` methods will resurrect the
  /// row (update name + set status to invited).
  ///
  /// The phone number is normalised (trimmed, leading/trailing whitespace
  /// removed) before the query.
  Future<PhoneLookupResult> lookupPhone(String phone) async {
    final normalised = phone.trim();
    final existing = await _dao.findUserByPhone(normalised);
    if (existing != null && existing.status != UserStatus.deleted) {
      return UserFound(existing);
    }
    return UserNotFound(normalised);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Owner creation
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates or links an owner at [schoolId].
  ///
  /// Resolution logic:
  ///   1. Look up [phone] in the local `users` table.
  ///   2. If found → verify not already an owner → link directly.
  ///   3. If not found → create an invited user row → then link.
  ///
  /// Returns the resolved [UsersData] row on success.
  Future<Result<UsersData, MemberCreationError>> createOwner({
    required String schoolId,
    required String phone,
    String? name,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberCreationError.noActiveAccount);
    }

    final normalised = phone.trim();
    final existing = await _dao.findUserByPhone(normalised);

    if (existing != null && existing.status != UserStatus.deleted) {
      // User exists and is not deleted — check for duplicate.
      final duplicate = await _dao.ownerExists(schoolId, existing.id);
      if (duplicate) return const Err(MemberCreationError.alreadyExists);

      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.addExistingUserAsOwner(
        owner: OwnersCompanion(
          school: Value(schoolId),
          user: Value(existing.id),
          created: Value(nowSec),
        ),
        existingUser: existing,
        accountId: accountId,
      );
      return Ok(existing);
    }

    // User not found OR deleted — name is required.
    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    // If the phone belonged to a deleted user, purge the old row first.
    // Cascade deletes will clean up any stale role links.
    if (existing != null && existing.status == UserStatus.deleted) {
      await _purgeDeletedUser(existing.id, accountId: accountId);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    // Create a fresh invited user row + owner link.
    final userId = ObjectId().oid;

    final newUser = UsersCompanion(
      id: Value(userId),
      phone: Value(normalised),
      name: Value(name.trim()),
      status: const Value(UserStatus.invited),
      level: const Value(UserLevel.normal),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    await _dao.inviteAndAddOwner(
      newUser: newUser,
      owner: OwnersCompanion(
        school: Value(schoolId),
        user: Value(userId),
        created: Value(nowSec),
      ),
      accountId: accountId,
    );

    final created = await _dao.findUserByPhone(normalised);
    return Ok(created!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Teacher creation
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates or links a teacher at [schoolId].
  ///
  /// Resolution logic:
  ///   1. Look up [phone] in the local `users` table.
  ///   2. If found → verify not already a teacher → link directly.
  ///   3. If not found → create an invited user row → then link.
  ///
  /// Optional fields ([hiredDate], [role], [department]) are written when
  /// non-null.
  ///
  /// Returns the resolved [UsersData] row on success.
  Future<Result<UsersData, MemberCreationError>> createTeacher({
    required String schoolId,
    required String phone,
    String? name,
    DateTime? hiredDate,
    String? role,
    String? department,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberCreationError.noActiveAccount);
    }

    final normalised = phone.trim();
    final existing = await _dao.findUserByPhone(normalised);

    if (existing != null && existing.status != UserStatus.deleted) {
      // User exists and is not deleted — check for duplicate.
      final duplicate = await _dao.teacherExists(schoolId, existing.id);
      if (duplicate) return const Err(MemberCreationError.alreadyExists);

      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.addExistingUserAsTeacher(
        teacher: TeachersCompanion(
          school: Value(schoolId),
          user: Value(existing.id),
          hired: hiredDate != null
              ? Value(_dateToDaysSinceEpoch(hiredDate))
              : const Value.absent(),
          role: role != null ? Value(role) : const Value.absent(),
          department: department != null
              ? Value(department)
              : const Value.absent(),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        existingUser: existing,
        accountId: accountId,
      );
      return Ok(existing);
    }

    // User not found OR deleted — name is required.
    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    // If the phone belonged to a deleted user, purge the old row first.
    if (existing != null && existing.status == UserStatus.deleted) {
      await _purgeDeletedUser(existing.id, accountId: accountId);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    TeachersCompanion teacherCompanion(String userId) => TeachersCompanion(
      school: Value(schoolId),
      user: Value(userId),
      hired: hiredDate != null
          ? Value(_dateToDaysSinceEpoch(hiredDate))
          : const Value.absent(),
      role: role != null ? Value(role) : const Value.absent(),
      department: department != null ? Value(department) : const Value.absent(),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    // Create a fresh invited user row + teacher link.
    final userId = ObjectId().oid;

    final newUser = UsersCompanion(
      id: Value(userId),
      phone: Value(normalised),
      name: Value(name.trim()),
      status: const Value(UserStatus.invited),
      level: const Value(UserLevel.normal),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    await _dao.inviteAndAddTeacher(
      newUser: newUser,
      teacher: teacherCompanion(userId),
      accountId: accountId,
    );

    final created = await _dao.findUserByPhone(normalised);
    return Ok(created!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Staff creation
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates or links a staff member at [schoolId].
  ///
  /// Follows the same phone-first resolution as [createTeacher].
  Future<Result<UsersData, MemberCreationError>> createStaff({
    required String schoolId,
    required String phone,
    String? name,
    String? idNumber,
    String? role,
    String? department,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberCreationError.noActiveAccount);
    }

    final normalised = phone.trim();
    final existing = await _dao.findUserByPhone(normalised);

    if (existing != null && existing.status != UserStatus.deleted) {
      // User exists and is not deleted — check for duplicate.
      final duplicate = await _dao.staffExists(schoolId, existing.id);
      if (duplicate) return const Err(MemberCreationError.alreadyExists);

      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.addExistingUserAsStaff(
        member: StaffCompanion(
          school: Value(schoolId),
          user: Value(existing.id),
          idnumber: idNumber != null ? Value(idNumber) : const Value.absent(),
          role: role != null ? Value(role) : const Value.absent(),
          department: department != null
              ? Value(department)
              : const Value.absent(),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        existingUser: existing,
        accountId: accountId,
      );
      return Ok(existing);
    }

    // User not found OR deleted — name is required.
    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    // If the phone belonged to a deleted user, purge the old row first.
    if (existing != null && existing.status == UserStatus.deleted) {
      await _purgeDeletedUser(existing.id, accountId: accountId);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    StaffCompanion staffCompanion(String userId) => StaffCompanion(
      school: Value(schoolId),
      user: Value(userId),
      idnumber: idNumber != null ? Value(idNumber) : const Value.absent(),
      role: role != null ? Value(role) : const Value.absent(),
      department: department != null ? Value(department) : const Value.absent(),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    // Create a fresh invited user row + staff link.
    final userId = ObjectId().oid;

    final newUser = UsersCompanion(
      id: Value(userId),
      phone: Value(normalised),
      name: Value(name.trim()),
      status: const Value(UserStatus.invited),
      level: const Value(UserLevel.normal),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    await _dao.inviteAndAddStaff(
      newUser: newUser,
      member: staffCompanion(userId),
      accountId: accountId,
    );

    final created = await _dao.findUserByPhone(normalised);
    return Ok(created!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Student creation
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new student at [schoolId].
  ///
  /// Unlike Teacher/Staff, students are identified by name and are not
  /// required to have a phone number.  The admission number is auto-assigned
  /// as `MAX(adm) + 1` for [schoolId].
  ///
  /// Optional fields: [dob], [gender], [admitted].
  ///
  /// Returns the created [StudentsData] row on success.
  Future<Result<StudentsData, MemberCreationError>> createStudent({
    required String schoolId,
    required String name,
    int? adm,
    DateTime? dob,
    Gender? gender,
    DateTime? admitted,
    String? phone,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberCreationError.noActiveAccount);
    }

    // If caller provided a valid ADM, check for conflicts; otherwise auto-assign.
    final int resolvedAdm;
    if (adm != null && adm > 0) {
      final existing = await _dao.getStudent(schoolId, adm);
      if (existing != null) {
        return const Err(MemberCreationError.alreadyExists);
      }
      resolvedAdm = adm;
    } else {
      resolvedAdm = await _dao.nextAdmissionNumber(schoolId);
    }
    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    // ── Optional phone → user resolution ──────────────────────────────────
    // If a phone is provided, try to find the user locally for an optimistic
    // link.  The phone is always forwarded to the DAO so the sync payload
    // carries the phone (not the user ID) — the server resolves by phone.
    String? userId;
    String? userPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      userPhone = phone.trim();
      final existing = await _dao.findUserByPhone(userPhone);
      if (existing != null && existing.status != UserStatus.deleted) {
        // User exists locally — link optimistically for immediate UI display.
        userId = existing.id;
      }
      // If not found locally, leave userId null.  The server will resolve
      // the phone → user and sync back the authoritative student row.
    }

    final companion = StudentsCompanion(
      school: Value(schoolId),
      adm: Value(resolvedAdm),
      name: Value(name.trim()),
      user: userId != null ? Value(userId) : const Value.absent(),
      dob: dob != null
          ? Value(_dateToDaysSinceEpoch(dob))
          : const Value.absent(),
      gender: gender != null ? Value(gender) : const Value.absent(),
      admitted: admitted != null
          ? Value(_dateToDaysSinceEpoch(admitted))
          : const Value.absent(),
      status: const Value(StudentStatus.active),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    await _dao.createStudent(
      student: companion,
      accountId: accountId,
      userPhone: userPhone,
    );

    final created = await _dao.getStudent(schoolId, resolvedAdm);
    return Ok(created!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Guardian creation
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates or links a guardian for student [studentAdm] at [schoolId].
  ///
  /// Guardian creation is always nested within a student profile.
  /// The guardian–ward relationship is [relationship] (defaults to
  /// [GuardianRelationship.guardian]) and the involvement level is [role]
  /// (defaults to [GuardianRole.secondary]).
  ///
  /// Only one guardian can hold [GuardianRole.primary] per student
  /// (enforced by the unique partial index `uq_guardians_primary`).
  ///
  /// Returns the resolved [UsersData] row on success.
  Future<Result<UsersData, MemberCreationError>> createGuardian({
    required String schoolId,
    required int studentAdm,
    required String phone,
    String? name,
    GuardianRelationship relationship = GuardianRelationship.guardian,
    GuardianRole role = GuardianRole.secondary,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberCreationError.noActiveAccount);
    }

    final normalised = phone.trim();
    final existing = await _dao.findUserByPhone(normalised);

    if (existing != null && existing.status != UserStatus.deleted) {
      // User exists and is not deleted — check for duplicate.
      final duplicate = await _dao.guardianExists(
        schoolId,
        existing.id,
        studentAdm,
      );
      if (duplicate) return const Err(MemberCreationError.alreadyExists);

      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.addExistingUserAsGuardian(
        guardian: GuardiansCompanion(
          school: Value(schoolId),
          user: Value(existing.id),
          student: Value(studentAdm),
          relationship: Value(relationship),
          role: Value(role),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        existingUser: existing,
        accountId: accountId,
      );
      return Ok(existing);
    }

    // User not found OR deleted — name is required.
    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    // If the phone belonged to a deleted user, purge the old row first.
    if (existing != null && existing.status == UserStatus.deleted) {
      await _purgeDeletedUser(existing.id, accountId: accountId);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    GuardiansCompanion guardianCompanion(String userId) => GuardiansCompanion(
      school: Value(schoolId),
      user: Value(userId),
      student: Value(studentAdm),
      relationship: Value(relationship),
      role: Value(role),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    // Create a fresh invited user row + guardian link.
    final userId = ObjectId().oid;

    final newUser = UsersCompanion(
      id: Value(userId),
      phone: Value(normalised),
      name: Value(name.trim()),
      status: const Value(UserStatus.invited),
      level: const Value(UserLevel.normal),
      created: Value(nowSec),
      updated: Value(nowSec),
    );

    await _dao.inviteAndAddGuardian(
      newUser: newUser,
      guardian: guardianCompanion(userId),
      accountId: accountId,
    );

    final created = await _dao.findUserByPhone(normalised);
    return Ok(created!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profile image caching
  // ─────────────────────────────────────────────────────────────────────────

  /// Saves a profile image [sourceFile] for [userId] to the predictable local
  /// path `{appDir}/users/{userId}/profile`.
  ///
  /// Per the AGENT.md file-caching strategy, **no path or blob is stored in
  /// the database**. The image is always served from its constant path.
  ///
  /// After saving the file this method also enqueues a log row so the sync
  /// engine knows to upload the image when connectivity is restored. The log
  /// uses [SyncAction.updateUser] with an [UpdateUserPayload] containing only
  /// the user id — the server detects the file-bearing record and returns a
  /// presigned PUT URL in the ack.
  ///
  /// Returns `true` on success, `false` if the copy failed.
  Future<bool> saveUserProfileImage({
    required String userId,
    required File sourceFile,
    required String accountId,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDir.path}/users/$userId');
      await targetDir.create(recursive: true);

      final targetPath = '${targetDir.path}/profile';
      await sourceFile.copy(targetPath);
      FileCacheNotifier.notify(FileCache.profilePath(userId));

      // Enqueue a log entry so the sync engine can upload this image.
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.UpdateUserPayload(id: userId);

      // Get user phone for resource display.
      final user = await _dao.findUserById(userId);
      final resourceName = user?.phone ?? userId;

      await db
          .into(db.logs)
          .insert(
            LogsCompanion(
              account: Value(accountId),
              action: Value(SyncAction.updateUser),
              resource: Value(resourceName),
              payload: Value(payload.writeToBuffer()),
              created: Value(nowMs),
            ),
          );

      sync.schedulePush();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves a student profile image [sourceFile] to:
  /// `{appDir}/schools/{schoolId}/students/{adm}/image`
  ///
  /// Same log-queue strategy as [saveUserProfileImage], but uses
  /// [SyncAction.updateStudent] with an [UpdateStudentPayload] containing
  /// only the PK fields (school + adm).
  Future<bool> saveStudentImage({
    required String schoolId,
    required int adm,
    required File sourceFile,
    required String accountId,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(
        '${appDir.path}/schools/$schoolId/students/$adm',
      );
      await targetDir.create(recursive: true);

      final targetPath = '${targetDir.path}/image';
      await sourceFile.copy(targetPath);
      FileCacheNotifier.notify(FileCache.studentImagePath(schoolId, adm));

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final payload = sync_pb.UpdateStudentPayload(school: schoolId, adm: adm);

      // Get student name for resource display.
      final student = await _dao.getStudent(schoolId, adm);
      final resourceName = student?.name ?? 'Student #$adm';

      await db
          .into(db.logs)
          .insert(
            LogsCompanion(
              account: Value(accountId),
              action: Value(SyncAction.updateStudent),
              resource: Value(resourceName),
              payload: Value(payload.writeToBuffer()),
              created: Value(nowMs),
            ),
          );

      sync.schedulePush();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Deleted-user cleanup
  // ─────────────────────────────────────────────────────────────────────────

  /// Hard-deletes a deleted user row so the phone number can be reused by a
  /// fresh invited user. A [SyncAction.deleteUser] log entry is enqueued first
  /// so the sync engine can propagate the removal. Cascade deletes in the
  /// schema will clean up any stale role links (owners, teachers, staff,
  /// guardians).
  Future<void> _purgeDeletedUser(
    String userId, {
    required String accountId,
  }) async {
    final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

    // Get user info for resource display before deletion.
    final user = await _dao.findUserById(userId);
    final resourceName = user?.phone ?? userId;

    final payload = sync_pb.DeleteUserPayload(id: userId);

    await db
        .into(db.logs)
        .insert(
          LogsCompanion(
            account: Value(accountId),
            action: Value(SyncAction.deleteUser),
            resource: Value(resourceName),
            payload: Value(payload.writeToBuffer()),
            created: Value(nowMs),
          ),
        );

    await (db.delete(db.users)..where((t) => t.id.equals(userId))).go();
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Converts a [DateTime] to days since the Unix epoch (integer stored in
  /// date columns of the schema).
  static int _dateToDaysSinceEpoch(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch ~/ 86400000;
}
