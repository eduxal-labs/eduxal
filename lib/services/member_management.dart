import 'package:drift/drift.dart';

import '../client.dart';
import '../core/extensions.dart';
import '../database/database.dart';
import '../database/daos/members_dao.dart';
import '../database/tables/enums.dart';
import '../models/permissions.dart';
import '../models/result.dart';
import '../models/school_permissions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain errors
// ─────────────────────────────────────────────────────────────────────────────

/// Base sealed class for all errors the member management service can surface.
sealed class MemberActionError {
  const MemberActionError();
}

/// The active account could not be found — user is not logged in.
final class NoActiveAccount extends MemberActionError {
  const NoActiveAccount();
}

/// The target member row was not found in the local database.
final class NotFound extends MemberActionError {
  const NotFound();
}

/// An unexpected local database error occurred.
final class DatabaseError extends MemberActionError {
  const DatabaseError();
}

/// The caller attempted to remove themselves (e.g. owner removing self).
final class CannotRemoveSelf extends MemberActionError {
  const CannotRemoveSelf();
}

/// The caller lacks the required permission for this operation.
///
/// [reason] carries the human-readable denial message from
/// [AuthorizationService] so the UI can surface the exact reason.
final class PermissionDenied extends MemberActionError {
  const PermissionDenied(this.reason);
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Handles post-creation lifecycle actions for all member types:
/// editing fields, changing status, and removing members.
///
/// Creation is handled by [MemberCreationService] in `members.dart`.
/// This service handles everything after a member already exists.
class MemberManagementService {
  MemberManagementService(this._dao);
  final MembersDao _dao;

  // ── Teacher actions ──────────────────────────────────────────────────────

  /// Updates mutable fields on a teacher row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.teachers` / `Action.update` before proceeding.
  Future<Result<void, MemberActionError>> updateTeacher({
    required String schoolId,
    required String userId,
    String? role,
    String? department,
    DateTime? hiredDate,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateTeacher,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.teachers, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final companion = TeachersCompanion(
        role: role != null ? Value(role) : const Value.absent(),
        department: department != null
            ? Value(department)
            : const Value.absent(),
        hired: hiredDate != null
            ? Value(_dateToDaysSinceEpoch(hiredDate))
            : const Value.absent(),
        updated: Value(nowSec),
      );

      await _dao.updateTeacher(
        schoolId: schoolId,
        userId: userId,
        changes: companion,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Changes a teacher's status (e.g. active → resigned).
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.teachers` / `Action.update` before proceeding.
  Future<Result<void, MemberActionError>> changeTeacherStatus({
    required String schoolId,
    required String userId,
    required TeacherStatus status,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateTeacher,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.teachers, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.updateTeacher(
        schoolId: schoolId,
        userId: userId,
        changes: TeachersCompanion(
          status: Value(status),
          updated: Value(nowSec),
        ),
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Removes a teacher from a school.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.teachers` / `Action.delete` before proceeding.
  Future<Result<void, MemberActionError>> removeTeacher({
    required String schoolId,
    required String userId,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.deleteTeacher,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.teachers, Action.delete)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      await _dao.removeTeacher(
        schoolId: schoolId,
        userId: userId,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  // ── Staff actions ────────────────────────────────────────────────────────

  /// Updates mutable fields on a staff row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.staff` / `Action.update` before proceeding.
  Future<Result<void, MemberActionError>> updateStaff({
    required String schoolId,
    required String userId,
    String? role,
    String? department,
    String? idNumber,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateStaff,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.staff, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final companion = StaffCompanion(
        role: role != null ? Value(role) : const Value.absent(),
        department: department != null
            ? Value(department)
            : const Value.absent(),
        idnumber: idNumber != null ? Value(idNumber) : const Value.absent(),
        updated: Value(nowSec),
      );

      await _dao.updateStaff(
        schoolId: schoolId,
        userId: userId,
        changes: companion,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Changes a staff member's status (e.g. active → resigned).
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.staff` / `Action.update` before proceeding.
  Future<Result<void, MemberActionError>> changeStaffStatus({
    required String schoolId,
    required String userId,
    required StaffStatus status,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateStaff,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.staff, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.updateStaff(
        schoolId: schoolId,
        userId: userId,
        changes: StaffCompanion(status: Value(status), updated: Value(nowSec)),
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Removes a staff member from a school.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.staff` / `Action.delete` before proceeding.
  Future<Result<void, MemberActionError>> removeStaff({
    required String schoolId,
    required String userId,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.deleteStaff,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.staff, Action.delete)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      await _dao.removeStaff(
        schoolId: schoolId,
        userId: userId,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  // ── Owner actions ────────────────────────────────────────────────────────

  /// Removes an owner from a school.
  ///
  /// Returns [CannotRemoveSelf] if the caller attempts
  /// to remove their own owner row.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.owners` / `Action.delete` before proceeding.
  Future<Result<void, MemberActionError>> removeOwner({
    required String schoolId,
    required String userId,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.deleteOwner,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.owners, Action.delete)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    if (userId == accountId) {
      return const Err(CannotRemoveSelf());
    }

    try {
      await _dao.removeOwner(
        schoolId: schoolId,
        userId: userId,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  // ── Student actions ──────────────────────────────────────────────────────

  /// Updates mutable fields on a student row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  ///
  /// [phone] controls user-linking:
  ///   • `null` → no change to user field
  ///   • empty string → unlink current user (set user to null)
  ///   • non-empty → lookup user by phone; link if found locally, server resolves
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.students` / `Action.update` before proceeding.
  Future<Result<void, MemberActionError>> updateStudent({
    required String schoolId,
    required int adm,
    String? name,
    DateTime? dob,
    Gender? gender,
    String? phone,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateStudent,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.students, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // ── Optional phone → user resolution ──────────────────────────
      // Phone-based linking: the phone is forwarded to the DAO so the
      // sync payload carries the phone for server-side resolution.
      // Locally, link to the user only if they already exist in the DB.
      Value<String?> userValue = const Value.absent();
      String? userPhone;
      if (phone != null) {
        if (phone.trim().isEmpty) {
          // Explicitly unlink user.
          userValue = const Value(null);
          userPhone = '-'; // Server interprets "-" as unlink.
        } else {
          userPhone = phone.toKenyanPhone() ?? phone.trim();
          final existing = await _dao.findUserByPhone(userPhone);
          if (existing != null && existing.status != UserStatus.deleted) {
            // User exists locally — link optimistically.
            userValue = Value(existing.id);
          } else {
            // User not found locally — clear stale link; server will
            // resolve the phone and sync back the authoritative user ID.
            userValue = const Value(null);
          }
        }
      }

      final companion = StudentsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        dob: dob != null
            ? Value(_dateToDaysSinceEpoch(dob))
            : const Value.absent(),
        gender: gender != null ? Value(gender) : const Value.absent(),
        user: userValue,
        updated: Value(nowSec),
      );

      await _dao.updateStudent(
        schoolId: schoolId,
        adm: adm,
        changes: companion,
        accountId: accountId,
        userPhone: userPhone,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Changes a student's status (e.g. active → expelled).
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.students` / `Action.update` before proceeding.
  Future<Result<void, MemberActionError>> changeStudentStatus({
    required String schoolId,
    required int adm,
    required StudentStatus status,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateStudent,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.students, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _dao.updateStudent(
        schoolId: schoolId,
        adm: adm,
        changes: StudentsCompanion(
          status: Value(status),
          updated: Value(nowSec),
        ),
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Removes a student from a school.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.students` / `Action.delete` before proceeding.
  Future<Result<void, MemberActionError>> removeStudent({
    required String schoolId,
    required int adm,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.deleteStudent,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    if (permissions != null &&
        !permissions.can(Resource.students, Action.delete)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      await _dao.removeStudent(
        schoolId: schoolId,
        adm: adm,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  // ── Guardian actions ─────────────────────────────────────────────────────

  /// Updates mutable fields on a guardian row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.students` / `Action.update` before proceeding (guardians are
  /// managed under the students resource per AGENT.md §17a).
  Future<Result<void, MemberActionError>> updateGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    GuardianRelationship? relationship,
    GuardianRole? role,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.updateGuardian,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    // Guardians fall under the Students resource per AGENT.md §17a.
    if (permissions != null &&
        !permissions.can(Resource.students, Action.update)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final companion = GuardiansCompanion(
        relationship: relationship != null
            ? Value(relationship)
            : const Value.absent(),
        role: role != null ? Value(role) : const Value.absent(),
        updated: Value(nowSec),
      );

      await _dao.updateGuardian(
        schoolId: schoolId,
        userId: userId,
        studentAdm: studentAdm,
        changes: companion,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  /// Removes a guardian link from a student.
  ///
  /// When [permissions] is provided, verifies the caller has
  /// `Resource.students` / `Action.delete` before proceeding (guardians are
  /// managed under the students resource per AGENT.md §17a).
  Future<Result<void, MemberActionError>> removeGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    SchoolPermissions? permissions,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(NoActiveAccount());
    }

    final authResult = await authorization.check(
      action: SyncAction.deleteGuardian,
      schoolId: schoolId,
      recordId: null,
    );
    if (!authResult.allowed) {
      return Err(PermissionDenied(authResult.reason!));
    }

    // Permission guard (defense-in-depth)
    // Guardians fall under the Students resource per AGENT.md §17a.
    if (permissions != null &&
        !permissions.can(Resource.students, Action.delete)) {
      return const Err(
        PermissionDenied('You don\'t have permission to perform this action.'),
      );
    }

    try {
      await _dao.removeGuardian(
        schoolId: schoolId,
        userId: userId,
        studentAdm: studentAdm,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(DatabaseError());
    }
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  /// Converts a [DateTime] to days since Unix epoch for date columns.
  static int _dateToDaysSinceEpoch(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch ~/ 86400000;
}
