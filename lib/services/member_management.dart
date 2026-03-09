import 'package:drift/drift.dart';

import '../client.dart';
import '../database/database.dart';
import '../database/daos/members_dao.dart';
import '../database/tables/enums.dart';
import '../models/result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain errors
// ─────────────────────────────────────────────────────────────────────────────

/// Errors that the member management service can surface to the UI.
enum MemberActionError {
  /// The active account could not be found — user is not logged in.
  noActiveAccount,

  /// The target member row was not found in the local database.
  notFound,

  /// An unexpected local database error occurred.
  databaseError,

  /// The caller attempted to remove themselves (e.g. owner removing self).
  cannotRemoveSelf,
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
  Future<Result<void, MemberActionError>> updateTeacher({
    required String schoolId,
    required String userId,
    String? role,
    String? department,
    DateTime? hiredDate,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  /// Changes a teacher's status (e.g. active → resigned).
  Future<Result<void, MemberActionError>> changeTeacherStatus({
    required String schoolId,
    required String userId,
    required TeacherStatus status,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  /// Removes a teacher from a school.
  Future<Result<void, MemberActionError>> removeTeacher({
    required String schoolId,
    required String userId,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
    }

    try {
      await _dao.removeTeacher(
        schoolId: schoolId,
        userId: userId,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(MemberActionError.databaseError);
    }
  }

  // ── Staff actions ────────────────────────────────────────────────────────

  /// Updates mutable fields on a staff row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  Future<Result<void, MemberActionError>> updateStaff({
    required String schoolId,
    required String userId,
    String? role,
    String? department,
    String? idNumber,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  /// Changes a staff member's status (e.g. active → resigned).
  Future<Result<void, MemberActionError>> changeStaffStatus({
    required String schoolId,
    required String userId,
    required StaffStatus status,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  /// Removes a staff member from a school.
  Future<Result<void, MemberActionError>> removeStaff({
    required String schoolId,
    required String userId,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
    }

    try {
      await _dao.removeStaff(
        schoolId: schoolId,
        userId: userId,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(MemberActionError.databaseError);
    }
  }

  // ── Owner actions ────────────────────────────────────────────────────────

  /// Removes an owner from a school.
  ///
  /// Returns [MemberActionError.cannotRemoveSelf] if the caller attempts
  /// to remove their own owner row.
  Future<Result<void, MemberActionError>> removeOwner({
    required String schoolId,
    required String userId,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
    }

    if (userId == accountId) {
      return const Err(MemberActionError.cannotRemoveSelf);
    }

    try {
      await _dao.removeOwner(
        schoolId: schoolId,
        userId: userId,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(MemberActionError.databaseError);
    }
  }

  // ── Student actions ──────────────────────────────────────────────────────

  /// Updates mutable fields on a student row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  Future<Result<void, MemberActionError>> updateStudent({
    required String schoolId,
    required int adm,
    String? name,
    DateTime? dob,
    Gender? gender,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final companion = StudentsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        dob: dob != null
            ? Value(_dateToDaysSinceEpoch(dob))
            : const Value.absent(),
        gender: gender != null ? Value(gender) : const Value.absent(),
        updated: Value(nowSec),
      );

      await _dao.updateStudent(
        schoolId: schoolId,
        adm: adm,
        changes: companion,
        accountId: accountId,
      );

      return const Ok(null);
    } on Exception {
      return const Err(MemberActionError.databaseError);
    }
  }

  /// Changes a student's status (e.g. active → expelled).
  Future<Result<void, MemberActionError>> changeStudentStatus({
    required String schoolId,
    required int adm,
    required StudentStatus status,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  // ── Guardian actions ─────────────────────────────────────────────────────

  /// Updates mutable fields on a guardian row.
  ///
  /// Only non-null parameters are written. A log UPDATE entry is enqueued
  /// automatically by the DAO.
  Future<Result<void, MemberActionError>> updateGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    GuardianRelationship? relationship,
    GuardianRole? role,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  /// Removes a guardian link from a student.
  Future<Result<void, MemberActionError>> removeGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
  }) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      return const Err(MemberActionError.noActiveAccount);
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
      return const Err(MemberActionError.databaseError);
    }
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  /// Converts a [DateTime] to days since Unix epoch for date columns.
  static int _dateToDaysSinceEpoch(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch ~/ 86400000;
}
