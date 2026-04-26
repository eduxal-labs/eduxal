import 'package:flutter/foundation.dart';

import '../client.dart';
import '../database/database.dart';
import '../database/tables/enums.dart';
import '../models/permissions.dart';

import '../models/system_permissions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception + Result types
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown by DAOs / services when a pre-flight permission check fails.
///
/// Callers may catch this and display [reason] to the user.
class PermissionException implements Exception {
  const PermissionException(this.reason);
  final String reason;

  @override
  String toString() => 'PermissionException: $reason';
}

/// Returned by [AuthorizationService.check] to convey allow / deny outcome.
class PermissionResult {
  const PermissionResult.allow() : allowed = true, reason = null;
  const PermissionResult.deny(this.reason) : allowed = false;

  final bool allowed;

  /// Human-readable denial reason; `null` when [allowed] is `true`.
  final String? reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// Organisation context
// ─────────────────────────────────────────────────────────────────────────────

/// Broad organisational bucket that determines which permission tier to check.
enum Organisation {
  /// The action targets a globally-scoped resource (no school).
  system,

  /// The action targets the currently authenticated user's own account.
  account,

  /// The action targets a resource inside a specific school.
  school,
}

/// Resolved context for a single authorization check.
sealed class OrgContext {
  const OrgContext();

  const factory OrgContext.system() = _SystemOrg;
  const factory OrgContext.account() = _AccountOrg;
  const factory OrgContext.school(String schoolId) = _SchoolOrg;

  Organisation get type;
  String? get schoolId => null;
}

final class _SystemOrg extends OrgContext {
  const _SystemOrg();
  @override
  Organisation get type => Organisation.system;
}

final class _AccountOrg extends OrgContext {
  const _AccountOrg();
  @override
  Organisation get type => Organisation.account;
}

final class _SchoolOrg extends OrgContext {
  const _SchoolOrg(this._schoolId);
  final String _schoolId;
  @override
  Organisation get type => Organisation.school;
  @override
  String get schoolId => _schoolId;
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthorizationService
// ─────────────────────────────────────────────────────────────────────────────

/// Pre-flight authorization engine.
///
/// Call [check] before any local mutation to validate that the current user
/// has the required permission. On denial, display [PermissionResult.reason]
/// to the user and abort the mutation.
///
/// The service is intentionally stateless — a single global instance is
/// sufficient. It reads from the local Drift DB (no network calls).
///
/// ### Failure-open contract
/// If the authorization engine itself throws unexpectedly (DB unavailable,
/// bug, etc.) [check] returns [PermissionResult.allow] rather than blocking
/// legitimate mutations. This avoids false positives while the user is still
/// building out their role configuration.
class AuthorizationService {
  const AuthorizationService();

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks whether the currently authenticated user may perform [action].
  ///
  /// Parameters:
  /// - [action] — the [SyncAction] the caller is about to enqueue.
  /// - [schoolId] — optional school context carried in the action payload.
  ///   May be `null` for system-level actions or when the school is embedded
  ///   in a record looked up via [recordId].
  /// - [recordId] — optional PK of an existing record (exam, fee, invoice,
  ///   payment, announcement) used to look up the owning school when the
  ///   payload does not carry one explicitly.
  ///
  /// Returns [PermissionResult.allow] or [PermissionResult.deny].
  Future<PermissionResult> check({
    required SyncAction action,
    String? schoolId,
    String? recordId,
  }) async {
    try {
      final authenticated = cache.currentUser;
      if (authenticated == null) {
        return const PermissionResult.deny('Not authenticated.');
      }
      final user = authenticated.user;

      // Super users bypass every check unconditionally.
      if (user.level == UserLevel.super_) return const PermissionResult.allow();

      final org = await _resolveOrganisation(
        action,
        schoolId,
        recordId,
        user.id,
      );
      final (resource, requiredAction) = _actionPermission(action);

      switch (org.type) {
        // ── System-level actions ────────────────────────────────────────────
        case Organisation.system:
          if (user.level.index < UserLevel.system.index) {
            return const PermissionResult.deny(
              'This operation requires system-level access.',
            );
          }
          final systemPerms = await _loadSystemPermissions(user.id, user.level);
          return systemPerms.can(resource, requiredAction)
              ? const PermissionResult.allow()
              : PermissionResult.deny(_denialMessage(resource, requiredAction));

        // ── Account-level actions ───────────────────────────────────────────
        case Organisation.account:
          // User editing their own account — always allowed once authenticated.
          return const PermissionResult.allow();

        // ── School-level actions ────────────────────────────────────────────
        case Organisation.school:
          final sid = org.schoolId!;

          final school = await db.schoolsDao.getSchool(sid);
          if (school == null) {
            return const PermissionResult.deny('School not found.');
          }
          if (school.status != SchoolStatus.active) {
            return const PermissionResult.deny(
              'This school is not currently active.',
            );
          }

          // School owners have full access — skip role checks.
          final isOwner = await db.schoolsDao.isOwner(sid, user.id);
          if (isOwner) return const PermissionResult.allow();

          final schoolPerms = await db.schoolScopesDao.getAggregatedPermissions(
            sid,
            user.id,
            user.level,
          );
          return schoolPerms.can(resource, requiredAction)
              ? const PermissionResult.allow()
              : PermissionResult.deny(_denialMessage(resource, requiredAction));
      }
    } catch (e, st) {
      debugPrint('[AuthorizationService.check] Unexpected error: $e\n$st');
      // Fail open — never block a mutation due to an authorization engine bug.
      return const PermissionResult.allow();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Determines which [OrgContext] applies to [action].
  ///
  /// Precedence:
  /// 1. Hard-coded system-only action list.
  /// 2. `updateUser` targeting the caller's own ID → account.
  /// 3. DB look-up via [recordId] for actions whose school is not in the
  ///    payload (update/delete on existing records).
  /// 4. `createRole` / `assignRole` / `unassignRole` — school if present.
  /// 5. [schoolId] from the payload.
  /// 6. Fallback: treat as system.
  Future<OrgContext> _resolveOrganisation(
    SyncAction action,
    String? schoolId,
    String? recordId,
    String userId,
  ) async {
    // Actions that are always system-level (no school context).
    const systemActions = {
      SyncAction.createSchool,
      SyncAction.createPlan,
      SyncAction.updatePlan,
      SyncAction.deletePlan,
      SyncAction.createSubject,
      SyncAction.updateSubject,
      SyncAction.deleteSubject,
      SyncAction.createTopic,
      SyncAction.updateTopic,
      SyncAction.deleteTopic,
      SyncAction.updateRole,
      SyncAction.deleteRole,
      SyncAction.deleteUser,
    };
    if (systemActions.contains(action)) return const OrgContext.system();

    // updateUser — account-level when user is editing their own record.
    if (action == SyncAction.updateUser) {
      return recordId == userId
          ? const OrgContext.account()
          : const OrgContext.system();
    }

    // Lookup-based resolution for actions on existing records without explicit
    // school in the payload.
    if (recordId != null) {
      String? lookedUp;
      switch (action) {
        case SyncAction.updateExam:
        case SyncAction.deleteExam:
          lookedUp = await db.examsGradesDao.getSchoolForExam(recordId);
        case SyncAction.updateFee:
        case SyncAction.deleteFee:
          lookedUp = await db.financeDao.getSchoolForFee(recordId);
        case SyncAction.updateInvoice:
        case SyncAction.deleteInvoice:
          lookedUp = await db.financeDao.getSchoolForInvoice(recordId);
        case SyncAction.updatePayment:
        case SyncAction.deletePayment:
        case SyncAction.approvePayment:
          lookedUp = await db.financeDao.getSchoolForPayment(recordId);
        case SyncAction.updateAnnouncement:
        case SyncAction.deleteAnnouncement:
          lookedUp = await db.announcementsDao.getSchoolForAnnouncement(
            recordId,
          );
        default:
          break;
      }
      if (lookedUp != null) return OrgContext.school(lookedUp);
    }

    // Role management — school-scoped if schoolId is present, otherwise system.
    if (action == SyncAction.createRole ||
        action == SyncAction.assignRole ||
        action == SyncAction.unassignRole) {
      return (schoolId != null && schoolId.isNotEmpty)
          ? OrgContext.school(schoolId)
          : const OrgContext.system();
    }

    // All remaining actions: school must be in the payload.
    if (schoolId != null && schoolId.isNotEmpty) {
      return OrgContext.school(schoolId);
    }

    // Fallback: cannot determine school — treat as system to enforce the
    // highest tier of permission checks.
    return const OrgContext.system();
  }

  /// Builds a [SystemPermissions] instance for [userId] at [level] by loading
  /// all system-scoped roles from the local DB.
  Future<SystemPermissions> _loadSystemPermissions(
    String userId,
    UserLevel level,
  ) async {
    final roles = await db.rolesDao.getSystemRolesForUser(userId);
    return SystemPermissions.forUser(level, roles);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Static helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Maps every [SyncAction] to the `(Resource, Action)` pair that must be
  /// granted for the action to proceed.
  ///
  /// The switch is exhaustive — the Dart compiler will flag any missing cases.
  static (Resource, Action) _actionPermission(SyncAction action) {
    return switch (action) {
      // ── Schools ────────────────────────────────────────────────────────────
      SyncAction.createSchool => (Resource.schools, Action.create),
      SyncAction.updateSchool => (Resource.schools, Action.update),
      SyncAction.deleteSchool => (Resource.schools, Action.delete),
      // ── Teachers ───────────────────────────────────────────────────────────
      SyncAction.createTeacher => (Resource.teachers, Action.create),
      SyncAction.updateTeacher => (Resource.teachers, Action.update),
      SyncAction.deleteTeacher => (Resource.teachers, Action.delete),
      // ── Staff ──────────────────────────────────────────────────────────────
      SyncAction.createStaff => (Resource.staff, Action.create),
      SyncAction.updateStaff => (Resource.staff, Action.update),
      SyncAction.deleteStaff => (Resource.staff, Action.delete),
      // ── Owners ─────────────────────────────────────────────────────────────
      SyncAction.createOwner => (Resource.owners, Action.create),
      SyncAction.deleteOwner => (Resource.owners, Action.delete),
      // ── Students ───────────────────────────────────────────────────────────
      SyncAction.createStudent => (Resource.students, Action.create),
      SyncAction.updateStudent => (Resource.students, Action.update),
      SyncAction.deleteStudent => (Resource.students, Action.delete),
      SyncAction.enrollStudent => (Resource.students, Action.assign),
      SyncAction.unenrollStudent => (Resource.students, Action.unassign),
      // ── Guardians (under Students resource per §17a) ───────────────────────
      SyncAction.createGuardian => (Resource.students, Action.create),
      SyncAction.updateGuardian => (Resource.students, Action.update),
      SyncAction.deleteGuardian => (Resource.students, Action.delete),
      // ── Departments ────────────────────────────────────────────────────────
      SyncAction.createDepartment => (Resource.departments, Action.create),
      SyncAction.updateDepartment => (Resource.departments, Action.update),
      SyncAction.deleteDepartment => (Resource.departments, Action.delete),
      // ── Terms (under Schools resource) ────────────────────────────────────
      SyncAction.createTerm => (Resource.schools, Action.create),
      SyncAction.updateTerm => (Resource.schools, Action.update),
      SyncAction.deleteTerm => (Resource.schools, Action.delete),
      // ── Classes ────────────────────────────────────────────────────────────
      SyncAction.assignClassTeacher => (Resource.classes, Action.assign),
      SyncAction.unassignClassTeacher => (Resource.classes, Action.unassign),
      SyncAction.assignSubject => (Resource.classes, Action.assign),
      SyncAction.unassignSubject => (Resource.classes, Action.unassign),
      SyncAction.createTimetableEntry => (Resource.classes, Action.create),
      SyncAction.updateTimetableEntry => (Resource.classes, Action.update),
      SyncAction.deleteTimetableEntry => (Resource.classes, Action.delete),
      // ── Attendance ─────────────────────────────────────────────────────────
      SyncAction.markAttendance => (Resource.attendance, Action.mark),
      SyncAction.deleteAttendance => (Resource.attendance, Action.delete),
      // ── Lessons ────────────────────────────────────────────────────────────
      SyncAction.createLesson => (Resource.lessons, Action.create),
      SyncAction.deleteLesson => (Resource.lessons, Action.delete),
      // ── Exams ──────────────────────────────────────────────────────────────
      SyncAction.createExam => (Resource.exams, Action.create),
      SyncAction.updateExam => (Resource.exams, Action.update),
      SyncAction.deleteExam => (Resource.exams, Action.delete),
      SyncAction.createPaper => (Resource.exams, Action.create),
      SyncAction.updatePaper => (Resource.exams, Action.update),
      SyncAction.deletePaper => (Resource.exams, Action.delete),
      // ── Grades ─────────────────────────────────────────────────────────────
      SyncAction.markGrades => (Resource.grades, Action.mark),
      SyncAction.updateGrade => (Resource.grades, Action.update),
      SyncAction.deleteGrade => (Resource.grades, Action.delete),
      SyncAction.updateMastery => (Resource.grades, Action.mark),
      // ── Fees ───────────────────────────────────────────────────────────────
      SyncAction.createFee => (Resource.fees, Action.create),
      SyncAction.updateFee => (Resource.fees, Action.update),
      SyncAction.deleteFee => (Resource.fees, Action.delete),
      SyncAction.createInvoice => (Resource.fees, Action.create),
      SyncAction.updateInvoice => (Resource.fees, Action.update),
      SyncAction.deleteInvoice => (Resource.fees, Action.delete),
      // ── Payments ───────────────────────────────────────────────────────────
      SyncAction.createPayment => (Resource.payments, Action.create),
      SyncAction.updatePayment => (Resource.payments, Action.update),
      SyncAction.deletePayment => (Resource.payments, Action.delete),
      SyncAction.approvePayment => (Resource.payments, Action.approve),
      // ── Announcements ──────────────────────────────────────────────────────
      SyncAction.createAnnouncement => (Resource.announcements, Action.create),
      SyncAction.updateAnnouncement => (Resource.announcements, Action.update),
      SyncAction.deleteAnnouncement => (Resource.announcements, Action.delete),
      // ── Roles ──────────────────────────────────────────────────────────────
      SyncAction.createRole => (Resource.roles, Action.create),
      SyncAction.updateRole => (Resource.roles, Action.update),
      SyncAction.deleteRole => (Resource.roles, Action.delete),
      SyncAction.assignRole => (Resource.roles, Action.assign),
      SyncAction.unassignRole => (Resource.roles, Action.unassign),
      // ── Users ──────────────────────────────────────────────────────────────
      SyncAction.updateUser => (Resource.users, Action.update),
      SyncAction.deleteUser => (Resource.users, Action.delete),
      // ── Settings — DEPRECATED (table removed in schema v2) ─────────────────
      // ignore: deprecated_member_use
      SyncAction.updateSettings => (Resource.schools, Action.update),
      // ── Plans ──────────────────────────────────────────────────────────────
      SyncAction.createPlan => (Resource.plans, Action.create),
      SyncAction.updatePlan => (Resource.plans, Action.update),
      SyncAction.deletePlan => (Resource.plans, Action.delete),
      // ── AI ─────────────────────────────────────────────────────────────────
      SyncAction.updateAiUsage => (Resource.ai, Action.update),
      // ── Subscriptions ──────────────────────────────────────────────────────
      SyncAction.createSubscription => (Resource.plans, Action.create),
      SyncAction.updateSubscription => (Resource.plans, Action.update),
      SyncAction.deleteSubscription => (Resource.plans, Action.delete),
      // ── Discounts ──────────────────────────────────────────────────────────
      SyncAction.createDiscount => (Resource.plans, Action.create),
      SyncAction.updateDiscount => (Resource.plans, Action.update),
      SyncAction.deleteDiscount => (Resource.plans, Action.delete),
      // ── Subjects (global catalog — System/Super only) ──────────────────────
      SyncAction.createSubject => (Resource.subjects, Action.create),
      SyncAction.updateSubject => (Resource.subjects, Action.update),
      SyncAction.deleteSubject => (Resource.subjects, Action.delete),
      // ── Topics (global catalog — System/Super only) ────────────────────────
      SyncAction.createTopic => (Resource.subjects, Action.create),
      SyncAction.updateTopic => (Resource.subjects, Action.update),
      SyncAction.deleteTopic => (Resource.subjects, Action.delete),
      // ── Streams (per-school — under Schools resource) ──────────────────────
      SyncAction.createStream => (Resource.schools, Action.create),
      SyncAction.updateStream => (Resource.schools, Action.update),
      SyncAction.deleteStream => (Resource.schools, Action.delete),
      // ── M-Pesa (per-school — under Schools resource) ───────────────────────
      SyncAction.createMpesa => (Resource.schools, Action.create),
      SyncAction.updateMpesa => (Resource.schools, Action.update),
      SyncAction.deleteMpesa => (Resource.schools, Action.delete),
      // ── Exam Grades — DEPRECATED (table removed in schema v3) ─────────────
      // ignore: deprecated_member_use
      SyncAction.addExamGrade => (Resource.exams, Action.assign),
      // ignore: deprecated_member_use
      SyncAction.removeExamGrade => (Resource.exams, Action.unassign),
      // ── Scheme / Answer Sheet file sync ────────────────────────────────────
      SyncAction.uploadScheme => (Resource.exams, Action.update),
      SyncAction.deleteScheme => (Resource.exams, Action.delete),
      SyncAction.uploadAnswerSheet => (Resource.exams, Action.update),
      SyncAction.deleteAnswerSheet => (Resource.exams, Action.delete),
    };
  }

  /// Builds a human-readable denial message for [resource] / [action].
  static String _denialMessage(Resource resource, Action action) {
    final resourceName = switch (resource) {
      Resource.users => 'users',
      Resource.schools => 'school settings',
      Resource.owners => 'school owners',
      Resource.teachers => 'teachers',
      Resource.staff => 'staff',
      Resource.students => 'students',
      Resource.departments => 'departments',
      Resource.classes => 'classes',
      Resource.attendance => 'attendance',
      Resource.lessons => 'lessons',
      Resource.exams => 'exams',
      Resource.grades => 'grades',
      Resource.fees => 'fees',
      Resource.payments => 'payments',
      Resource.announcements => 'announcements',
      Resource.roles => 'roles',
      Resource.plans => 'subscription plans',
      Resource.ai => 'AI usage',
      Resource.subjects => 'subjects',
    };
    final actionName = switch (action) {
      Action.create => 'create',
      Action.read => 'view',
      Action.update => 'update',
      Action.delete => 'delete',
      Action.purge => 'permanently delete',
      Action.assign => 'assign',
      Action.unassign => 'remove',
      Action.mark => 'record',
      Action.approve => 'approve',
    };
    return "You don't have permission to $actionName $resourceName.";
  }
}
