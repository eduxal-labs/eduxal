import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bson/bson.dart';

import '../client.dart';
import '../database/database.dart';
import '../database/daos/members_dao.dart';
import '../database/tables/enums.dart';
import '../models/result.dart';

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
  /// Returns [UserFound] when a matching row exists, or [UserNotFound] when
  /// the phone number is unknown locally.
  ///
  /// The phone number is normalised (trimmed, leading/trailing whitespace
  /// removed) before the query.
  Future<PhoneLookupResult> lookupPhone(String phone) async {
    final normalised = phone.trim();
    final existing = await _dao.findUserByPhone(normalised);
    if (existing != null) return UserFound(existing);
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

    if (existing != null) {
      // User exists — check for duplicate.
      final duplicate = await _dao.ownerExists(schoolId, existing.id);
      if (duplicate) return const Err(MemberCreationError.alreadyExists);

      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.addExistingUserAsOwner(
        owner: OwnersCompanion(
          school: Value(schoolId),
          user: Value(existing.id),
          created: Value(nowSec),
        ),
        accountId: accountId,
      );
      return Ok(existing);
    }

    // User not found — name is required to create the invited user row.
    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
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

    if (existing != null) {
      // User exists — check for duplicate.
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
        accountId: accountId,
      );
      return Ok(existing);
    }

    // User not found — name is required to create the invited user row.
    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
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
      teacher: TeachersCompanion(
        school: Value(schoolId),
        user: Value(userId),
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

    if (existing != null) {
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
        accountId: accountId,
      );
      return Ok(existing);
    }

    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
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
      member: StaffCompanion(
        school: Value(schoolId),
        user: Value(userId),
        idnumber: idNumber != null ? Value(idNumber) : const Value.absent(),
        role: role != null ? Value(role) : const Value.absent(),
        department: department != null
            ? Value(department)
            : const Value.absent(),
        created: Value(nowSec),
        updated: Value(nowSec),
      ),
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
    DateTime? dob,
    Gender? gender,
    DateTime? admitted,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberCreationError.noActiveAccount);
    }

    final adm = await _dao.nextAdmissionNumber(schoolId);
    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final companion = StudentsCompanion(
      school: Value(schoolId),
      adm: Value(adm),
      name: Value(name.trim()),
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

    await _dao.createStudent(student: companion, accountId: accountId);

    final created = await _dao.getStudent(schoolId, adm);
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

    if (existing != null) {
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
        accountId: accountId,
      );
      return Ok(existing);
    }

    if (name == null || name.trim().isEmpty) {
      return const Err(MemberCreationError.invalidPhone);
    }

    final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
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
      guardian: GuardiansCompanion(
        school: Value(schoolId),
        user: Value(userId),
        student: Value(studentAdm),
        relationship: Value(relationship),
        role: Value(role),
        created: Value(nowSec),
        updated: Value(nowSec),
      ),
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
  /// engine knows to upload the image when connectivity is restored.  The log
  /// row uses [LogOperation.update] with a bitmask of 0 (no column changed) —
  /// a sentinel value that the sync engine interprets as "re-upload profile
  /// image for this user".
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

      // Enqueue a log entry so the sync engine can upload this image.
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await db
          .into(db.logs)
          .insert(
            LogsCompanion(
              account: Value(accountId),
              tbl: const Value(LogTable.users),
              op: const Value(LogOperation.update),
              rowKey: Value(userId),
              // columns = 0 is the sentinel for "re-upload profile image".
              columns: const Value(0),
              status: const Value(LogStatus.pending),
              created: Value(nowMs),
            ),
          );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves a student profile image [sourceFile] to:
  /// `{appDir}/schools/{schoolId}/students/{adm}/image`
  ///
  /// Same log-queue strategy as [saveUserProfileImage].
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

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await db
          .into(db.logs)
          .insert(
            LogsCompanion(
              account: Value(accountId),
              tbl: const Value(LogTable.students),
              op: const Value(LogOperation.update),
              rowKey: Value('$schoolId|$adm'),
              columns: const Value(0),
              status: const Value(LogStatus.pending),
              created: Value(nowMs),
            ),
          );

      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Converts a [DateTime] to days since the Unix epoch (integer stored in
  /// date columns of the schema).
  static int _dateToDaysSinceEpoch(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch ~/ 86400000;
}
