# TASKS.md

---

## Feature Group AUTH — Client-Side Authorization Enforcement

> **Context:** `client.md` specifies a complete client-side pre-authorization system that checks
> permissions **before** writing to the local DB and sync queue. Currently, mutations succeed
> locally and are only rejected by the server during sync (code 1 = permission_denied), giving
> users a confusing deferred failure experience. This task group implements the authorization
> check engine, wires it into every DAO mutation, and updates the UI to proactively hide
> controls the user cannot use.
>
> **Reading required before any task:** `AGENT.md`, `BUG.md`, `client.md` (full file).

---

### Task AUTH-A01: [x] Create `AuthorizationService` Core + DAO Helper Methods

**Files to create/modify:**
- `lib/services/authorization_service.dart` ← **create new**
- `lib/database/daos/exams_grades_dao.dart` ← add `getSchoolForExam()`
- `lib/database/daos/finance_dao.dart` ← add `getSchoolForFee()`, `getSchoolForInvoice()`, `getSchoolForPayment()`
- `lib/database/daos/announcements_dao.dart` ← add `getSchoolForAnnouncement()`
- `lib/database/daos/schools_dao.dart` ← add `isOwner()`
- `lib/database/daos/roles_dao.dart` ← add `getSystemRolesForUser()`

**Context files to read (if needed):** `lib/database/CONTEXT.md`, `lib/services/CONTEXT.md`

**Depends on:** nothing (foundational)

**Parallel group:** none (must complete before B and C groups)

---

#### Specification

##### 1 — New file: `lib/services/authorization_service.dart`

This file contains the pre-flight authorization engine described in `client.md §The Authorization Algorithm` and `§Dart / Flutter Implementation`. All types use the existing `Resource` and `Action` enums from `lib/models/permissions.dart` (NOT the int constants from `client.md` — we use the typed Dart enums already in the codebase).

**Imports required:**
```dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../client.dart';
import '../database/database.dart';
import '../database/tables/enums.dart';
import '../models/permissions.dart';
import '../models/school_permissions.dart';
import '../models/system_permissions.dart';
import '../core/permission_parser.dart';
```

**`PermissionException`** — thrown by DAOs when the pre-flight check fails:
```dart
class PermissionException implements Exception {
  const PermissionException(this.reason);
  final String reason;

  @override
  String toString() => 'PermissionException: $reason';
}
```

**`PermissionResult`** — returned by `check()`:
```dart
class PermissionResult {
  const PermissionResult.allow() : allowed = true, reason = null;
  const PermissionResult.deny(this.reason) : allowed = false;

  final bool allowed;
  final String? reason; // human-readable denial reason; null when allowed
}
```

**`Organisation` enum + `OrgContext` sealed class hierarchy:**
```dart
enum Organisation { system, account, school }

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
  @override Organisation get type => Organisation.system;
}

final class _AccountOrg extends OrgContext {
  const _AccountOrg();
  @override Organisation get type => Organisation.account;
}

final class _SchoolOrg extends OrgContext {
  const _SchoolOrg(this._schoolId);
  final String _schoolId;
  @override Organisation get type => Organisation.school;
  @override String get schoolId => _schoolId;
}
```

**`AuthorizationService` class:**

```dart
class AuthorizationService {
  const AuthorizationService();

  /// Pre-flight authorization check.
  ///
  /// Call this at the very start of every DAO mutation method, before any
  /// local DB write or sync queue entry.
  ///
  /// [action] — the SyncAction about to be performed.
  /// [schoolId] — pass when directly known from the payload (most actions).
  ///              Leave null for update/delete actions where the school must
  ///              be looked up from the local DB via [recordId].
  /// [recordId] — the ID of the record being updated or deleted (used for DB
  ///              lookup when schoolId is not directly available in the payload).
  ///
  /// Returns [PermissionResult.allow()] or [PermissionResult.deny(reason)].
  /// Never throws — callers inspect [PermissionResult.allowed] and throw
  /// [PermissionException] if they want to surface the denial.
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

      // Super users bypass everything.
      if (user.level == UserLevel.super_) return const PermissionResult.allow();

      final org = await _resolveOrganisation(
        action, schoolId, recordId, user.id);
      final (resource, requiredAction) = _actionPermission(action);

      switch (org.type) {
        case Organisation.system:
          if (user.level.index < UserLevel.system.index) {
            return const PermissionResult.deny(
              'This operation requires system-level access.');
          }
          final systemPerms = await _loadSystemPermissions(user.id, user.level);
          return systemPerms.can(resource, requiredAction)
              ? const PermissionResult.allow()
              : PermissionResult.deny(_denialMessage(resource, requiredAction));

        case Organisation.account:
          return const PermissionResult.allow();

        case Organisation.school:
          final sid = org.schoolId!;
          final school = await db.schoolsDao.getSchool(sid);
          if (school == null) {
            return const PermissionResult.deny('School not found.');
          }
          if (school.status != SchoolStatus.active) {
            return const PermissionResult.deny(
              'This school is not currently active.');
          }

          final isOwner = await db.schoolsDao.isOwner(sid, user.id);
          if (isOwner) return const PermissionResult.allow();

          final schoolPerms = await db.schoolScopesDao.getAggregatedPermissions(
            sid, user.id, user.level);
          return schoolPerms.can(resource, requiredAction)
              ? const PermissionResult.allow()
              : PermissionResult.deny(_denialMessage(resource, requiredAction));
      }
    } catch (e, st) {
      debugPrint('[AuthorizationService.check] Unexpected error: $e\n$st');
      // Fail open — never block a mutation due to an authorization engine error.
      // The server is the real security boundary.
      return const PermissionResult.allow();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<OrgContext> _resolveOrganisation(
    SyncAction action,
    String? schoolId,
    String? recordId,
    String userId,
  ) async {
    // System-level actions (no school context).
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

    // Account-level: user updating their own record.
    if (action == SyncAction.updateUser) {
      return recordId == userId
          ? const OrgContext.account()
          : const OrgContext.system();
    }

    // DB-lookup cases: school not present in payload.
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
          lookedUp = await db.announcementsDao.getSchoolForAnnouncement(recordId);
        default:
          break;
      }
      if (lookedUp != null) return OrgContext.school(lookedUp);
    }

    // Role / scope assignment: school optional → system if absent.
    if (action == SyncAction.createRole ||
        action == SyncAction.assignRole ||
        action == SyncAction.unassignRole) {
      return (schoolId != null && schoolId.isNotEmpty)
          ? OrgContext.school(schoolId)
          : const OrgContext.system();
    }

    // All other actions: school must be in payload.
    if (schoolId != null && schoolId.isNotEmpty) {
      return OrgContext.school(schoolId);
    }

    // Fallback: treat as system if school cannot be determined.
    return const OrgContext.system();
  }

  Future<SystemPermissions> _loadSystemPermissions(
    String userId,
    UserLevel level,
  ) async {
    final roles = await db.rolesDao.getSystemRolesForUser(userId);
    return SystemPermissions.forUser(level, roles);
  }

  /// Maps every SyncAction to the (Resource, Action) pair it requires.
  /// Covers all 89 active SyncAction values. Throws ArgumentError for
  /// deprecated actions (updateSettings=66, addExamGrade=89,
  /// removeExamGrade=90) if ever called — those actions are never queued
  /// by current code.
  static (Resource, Action) _actionPermission(SyncAction action) {
    return switch (action) {
      SyncAction.createSchool          => (Resource.schools, Action.create),
      SyncAction.updateSchool          => (Resource.schools, Action.update),
      SyncAction.deleteSchool          => (Resource.schools, Action.delete),
      SyncAction.createTeacher         => (Resource.teachers, Action.create),
      SyncAction.updateTeacher         => (Resource.teachers, Action.update),
      SyncAction.deleteTeacher         => (Resource.teachers, Action.delete),
      SyncAction.createStaff           => (Resource.staff, Action.create),
      SyncAction.updateStaff           => (Resource.staff, Action.update),
      SyncAction.deleteStaff           => (Resource.staff, Action.delete),
      SyncAction.createOwner           => (Resource.owners, Action.create),
      SyncAction.deleteOwner           => (Resource.owners, Action.delete),
      SyncAction.createStudent         => (Resource.students, Action.create),
      SyncAction.updateStudent         => (Resource.students, Action.update),
      SyncAction.deleteStudent         => (Resource.students, Action.delete),
      SyncAction.enrollStudent         => (Resource.students, Action.assign),
      SyncAction.unenrollStudent       => (Resource.students, Action.unassign),
      SyncAction.createGuardian        => (Resource.students, Action.create),
      SyncAction.updateGuardian        => (Resource.students, Action.update),
      SyncAction.deleteGuardian        => (Resource.students, Action.delete),
      SyncAction.createDepartment      => (Resource.departments, Action.create),
      SyncAction.updateDepartment      => (Resource.departments, Action.update),
      SyncAction.deleteDepartment      => (Resource.departments, Action.delete),
      SyncAction.createTerm            => (Resource.schools, Action.create),
      SyncAction.updateTerm            => (Resource.schools, Action.update),
      SyncAction.deleteTerm            => (Resource.schools, Action.delete),
      SyncAction.assignClassTeacher    => (Resource.classes, Action.assign),
      SyncAction.unassignClassTeacher  => (Resource.classes, Action.unassign),
      SyncAction.assignSubject         => (Resource.classes, Action.assign),
      SyncAction.unassignSubject       => (Resource.classes, Action.unassign),
      SyncAction.createTimetableEntry  => (Resource.classes, Action.create),
      SyncAction.updateTimetableEntry  => (Resource.classes, Action.update),
      SyncAction.deleteTimetableEntry  => (Resource.classes, Action.delete),
      SyncAction.markAttendance        => (Resource.attendance, Action.mark),
      SyncAction.deleteAttendance      => (Resource.attendance, Action.delete),
      SyncAction.createLesson          => (Resource.lessons, Action.create),
      SyncAction.deleteLesson          => (Resource.lessons, Action.delete),
      SyncAction.createExam            => (Resource.exams, Action.create),
      SyncAction.updateExam            => (Resource.exams, Action.update),
      SyncAction.deleteExam            => (Resource.exams, Action.delete),
      SyncAction.createPaper           => (Resource.exams, Action.create),
      SyncAction.updatePaper           => (Resource.exams, Action.update),
      SyncAction.deletePaper           => (Resource.exams, Action.delete),
      SyncAction.markGrades            => (Resource.grades, Action.mark),
      SyncAction.updateGrade           => (Resource.grades, Action.update),
      SyncAction.deleteGrade           => (Resource.grades, Action.delete),
      SyncAction.updateMastery         => (Resource.grades, Action.mark),
      SyncAction.createFee             => (Resource.fees, Action.create),
      SyncAction.updateFee             => (Resource.fees, Action.update),
      SyncAction.deleteFee             => (Resource.fees, Action.delete),
      SyncAction.createInvoice         => (Resource.fees, Action.create),
      SyncAction.updateInvoice         => (Resource.fees, Action.update),
      SyncAction.deleteInvoice         => (Resource.fees, Action.delete),
      SyncAction.createPayment         => (Resource.payments, Action.create),
      SyncAction.updatePayment         => (Resource.payments, Action.update),
      SyncAction.deletePayment         => (Resource.payments, Action.delete),
      SyncAction.approvePayment        => (Resource.payments, Action.approve),
      SyncAction.createAnnouncement    => (Resource.announcements, Action.create),
      SyncAction.updateAnnouncement    => (Resource.announcements, Action.update),
      SyncAction.deleteAnnouncement    => (Resource.announcements, Action.delete),
      SyncAction.createRole            => (Resource.roles, Action.create),
      SyncAction.updateRole            => (Resource.roles, Action.update),
      SyncAction.deleteRole            => (Resource.roles, Action.delete),
      SyncAction.assignRole            => (Resource.roles, Action.assign),
      SyncAction.unassignRole          => (Resource.roles, Action.unassign),
      SyncAction.updateUser            => (Resource.users, Action.update),
      SyncAction.deleteUser            => (Resource.users, Action.delete),
      // ignore: deprecated_member_use
      SyncAction.updateSettings        => (Resource.schools, Action.update),
      SyncAction.createPlan            => (Resource.plans, Action.create),
      SyncAction.updatePlan            => (Resource.plans, Action.update),
      SyncAction.deletePlan            => (Resource.plans, Action.delete),
      SyncAction.updateAiUsage         => (Resource.ai, Action.update),
      SyncAction.createSubscription    => (Resource.plans, Action.create),
      SyncAction.updateSubscription    => (Resource.plans, Action.update),
      SyncAction.deleteSubscription    => (Resource.plans, Action.delete),
      SyncAction.createDiscount        => (Resource.plans, Action.create),
      SyncAction.updateDiscount        => (Resource.plans, Action.update),
      SyncAction.deleteDiscount        => (Resource.plans, Action.delete),
      SyncAction.createSubject         => (Resource.subjects, Action.create),
      SyncAction.updateSubject         => (Resource.subjects, Action.update),
      SyncAction.deleteSubject         => (Resource.subjects, Action.delete),
      SyncAction.createTopic           => (Resource.subjects, Action.create),
      SyncAction.updateTopic           => (Resource.subjects, Action.update),
      SyncAction.deleteTopic           => (Resource.subjects, Action.delete),
      SyncAction.createStream          => (Resource.schools, Action.create),
      SyncAction.updateStream          => (Resource.schools, Action.update),
      SyncAction.deleteStream          => (Resource.schools, Action.delete),
      SyncAction.createMpesa           => (Resource.schools, Action.create),
      SyncAction.updateMpesa           => (Resource.schools, Action.update),
      SyncAction.deleteMpesa           => (Resource.schools, Action.delete),
      // Deprecated — never queued by current client code.
      // ignore: deprecated_member_use
      SyncAction.addExamGrade          => (Resource.exams, Action.assign),
      // ignore: deprecated_member_use
      SyncAction.removeExamGrade       => (Resource.exams, Action.unassign),
    };
  }

  static String _denialMessage(Resource resource, Action action) {
    final resourceName = switch (resource) {
      Resource.users         => 'users',
      Resource.schools       => 'school settings',
      Resource.owners        => 'school owners',
      Resource.teachers      => 'teachers',
      Resource.staff         => 'staff',
      Resource.students      => 'students',
      Resource.departments   => 'departments',
      Resource.classes       => 'classes',
      Resource.attendance    => 'attendance',
      Resource.lessons       => 'lessons',
      Resource.exams         => 'exams',
      Resource.grades        => 'grades',
      Resource.fees          => 'fees',
      Resource.payments      => 'payments',
      Resource.announcements => 'announcements',
      Resource.roles         => 'roles',
      Resource.plans         => 'subscription plans',
      Resource.ai            => 'AI usage',
      Resource.subjects      => 'subjects',
    };
    final actionName = switch (action) {
      Action.create   => 'create',
      Action.read     => 'view',
      Action.update   => 'update',
      Action.delete   => 'delete',
      Action.purge    => 'permanently delete',
      Action.assign   => 'assign',
      Action.unassign => 'remove',
      Action.mark     => 'record',
      Action.approve  => 'approve',
    };
    return "You don't have permission to $actionName $resourceName.";
  }
}
```

##### 2 — Add to `lib/database/daos/exams_grades_dao.dart`

In the **One-shot reads** section, add:

```dart
/// Returns the school ID for [examId], or null if the exam is not found locally.
/// Used by [AuthorizationService] to resolve the organisation context for
/// [SyncAction.updateExam] and [SyncAction.deleteExam].
Future<String?> getSchoolForExam(String examId) async {
  final row = await (select(exams)
        ..where((t) => t.id.equals(examId)))
      .getSingleOrNull();
  return row?.school;
}
```

##### 3 — Add to `lib/database/daos/finance_dao.dart`

In the **One-shot reads** section (create one if it doesn't exist), add:

```dart
/// Returns the school ID for [feeId], or null if not found locally.
/// Used by [AuthorizationService] for [SyncAction.updateFee] / [SyncAction.deleteFee].
Future<String?> getSchoolForFee(String feeId) async {
  final row = await (select(fees)..where((t) => t.id.equals(feeId))).getSingleOrNull();
  return row?.school;
}

/// Returns the school ID for [invoiceId], or null if not found locally.
/// Used by [AuthorizationService] for [SyncAction.updateInvoice] / [SyncAction.deleteInvoice].
Future<String?> getSchoolForInvoice(String invoiceId) async {
  final row = await (select(invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
  return row?.school;
}

/// Returns the school ID for [paymentId], or null if not found locally.
/// Used by [AuthorizationService] for update/delete/approve payment actions.
Future<String?> getSchoolForPayment(String paymentId) async {
  final row = await (select(payments)..where((t) => t.id.equals(paymentId))).getSingleOrNull();
  return row?.school;
}
```

The `FinanceDao` has access to `fees`, `invoices`, and `payments` tables (already in its `@DriftAccessor` tables list — verify and add to the list if any are missing).

##### 4 — Add to `lib/database/daos/announcements_dao.dart`

In a **One-shot reads** section:

```dart
/// Returns the school ID for [announcementId], or null if not found locally.
/// Used by [AuthorizationService] for [SyncAction.updateAnnouncement] /
/// [SyncAction.deleteAnnouncement].
Future<String?> getSchoolForAnnouncement(String announcementId) async {
  final row = await (select(announcements)
        ..where((t) => t.id.equals(announcementId)))
      .getSingleOrNull();
  return row?.school;
}
```

##### 5 — Add to `lib/database/daos/schools_dao.dart`

The `SchoolsDao` already imports `owners`. Add to the **One-shot reads** section:

```dart
/// Returns `true` if [userId] has an owner row for [schoolId].
/// Used by [AuthorizationService] to grant owner bypass before role checks.
Future<bool> isOwner(String schoolId, String userId) async {
  final row = await (select(owners)
        ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
      .getSingleOrNull();
  return row != null;
}
```

##### 6 — Add to `lib/database/daos/roles_dao.dart`

Add import at top: `import '../../models/system_permissions.dart';`

In the **One-shot reads** section:

```dart
/// Returns all system-scoped roles ([RolePermissions]) assigned to [userId]
/// via scopes where `school IS NULL`.
///
/// Used by [AuthorizationService] to build a [SystemPermissions] instance
/// for system-level action checks.
Future<List<RolePermissions>> getSystemRolesForUser(String userId) async {
  final query = select(scopes).join([
    innerJoin(roles, roles.id.equalsExp(scopes.role)),
  ])
    ..where(scopes.user.equals(userId) & scopes.school.isNull());

  final rows = await query.get();
  return rows.map((row) {
    final role = row.readTable(roles);
    return RolePermissions(
      roleId: role.id,
      roleName: role.name,
      permissionsData: role.permissions ?? Uint8List(0),
    );
  }).toList();
}
```

Note: `RolePermissions` is defined in `lib/models/system_permissions.dart`. Import it. `Uint8List` needs `dart:typed_data` imported (already likely present — check).

---

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md` — add `authorization_service.dart` entry
- [x] Update `lib/database/CONTEXT.md` — note new helper methods on each DAO
- [x] Mark this task `[x]`
- [x] Orchestrator: `git add -A && git commit -m "feat: add AuthorizationService core + DAO authorization helpers"`

---

### Task AUTH-A02: Register `AuthorizationService` Singleton in `client.dart`

**Files to modify:** `lib/client.dart`

**Context files to read (if needed):** none (self-contained change)

**Depends on:** AUTH-A01

**Parallel group:** none (must complete before Group B)

---

#### Specification

`lib/client.dart` exposes module-level accessors (e.g. `sync`, `accountsDao`, `rolesDao`).
Add `AuthorizationService` the same way.

**Step 1** — Add import at top of `lib/client.dart`:
```dart
import 'services/authorization_service.dart';
```

**Step 2** — Add a module-level late final variable near the other module-level accessors:
```dart
/// Global [AuthorizationService] singleton.
///
/// Call [authorization.check(...)] at the start of every DAO mutation method
/// that maps to a [SyncAction]. Throws nothing — callers inspect
/// [PermissionResult.allowed] and throw [PermissionException] on denial.
late final AuthorizationService authorization;
```

**Step 3** — In `initializeClient()` (the function that runs before `runApp()` and initialises
`db`, `client`, and other singletons), add:
```dart
authorization = const AuthorizationService();
```

Place this line after `db` and `client` are initialized, but before any service that might
call it. The `AuthorizationService` constructor is `const` — it has no state, it reads from the
global `db` and `cache` at call time.

---

**Update after completion:**
- [x] Update `lib/CONTEXT.md` — note the `authorization` global singleton
- [x] Mark this task `[x]`
- [x] Orchestrator: `git add -A && git commit -m "feat: register AuthorizationService singleton in client.dart"`

---

### Task AUTH-A03: Update `AGENT.md` — Add SyncAction Values 91–94 + Maintenance Rule

**Files to modify:** `AGENT.md`

**Context files to read (if needed):** none

**Depends on:** AUTH-A02

**Parallel group:** none (documentation, do alongside or after A02)

---

#### Specification

`client.md` contained two pieces of guidance that must survive its deletion and live in
`AGENT.md` as the single source of truth.

**Part 1 — Update `AGENT.md §7a` SyncAction enum block.**

The enum in AGENT.md currently ends at `removeExamGrade(90)`. Append the following four
values to the code block (before the closing `}`):

```dart
  // Scheme pages (marking scheme file sync)
  uploadScheme(91),
  deleteScheme(92),
  // Answer pages (student answer sheet file sync)
  uploadAnswerSheet(93),
  deleteAnswerSheet(94);
```

Also update the header of §7a to read:
`## 7a. The SyncAction Enum (95 Values — 91 Active)` (was 91 values / 89 active).

**Part 2 — Add a new "§16b. Keeping AuthorizationService in Sync" section** to `AGENT.md`
immediately after the existing `§16. Sync Strategy` section. The content:

```markdown
## 16b. Keeping `AuthorizationService` in Sync With the Server

The client-side `AuthorizationService` (`lib/services/authorization_service.dart`) replicates
the server's `action_permission()` and `action_organisation()` logic. When a new `SyncAction`
is added, ALL of the following must be updated in the same commit:

1. **Server** — add to `action_permission()` and `execute_action()` in `src/db/database/tables/actions.rs`
2. **`lib/database/tables/enums.dart`** — add new `SyncAction` enum value with the next integer
3. **`AuthorizationService._actionPermission()`** — add the `(Resource, Action)` mapping entry
4. **`AuthorizationService._resolveOrganisation()`** — add to `systemActions` set if system-level,
   or add a DB-lookup branch if school must be derived from a related record
5. **The relevant DAO mutation method** — add `authorization.check(...)` call at the top

The binary permissions format (`roles.permissions` blob) is defined in
`src/types/role/permissions.rs` on the server. If Resource IDs or the encoding format ever
change, update `lib/models/permissions.dart` simultaneously.
```

---

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Orchestrator: `git add -A && git commit -m "docs: update AGENT.md with SyncAction 91-94 and AuthorizationService maintenance rule"`

---

### Task AUTH-B01: [x] Wire Authorization into `ExamsGradesDao` Mutations

**Files to modify:** `lib/database/daos/exams_grades_dao.dart`

**Context files to read (if needed):** `lib/database/CONTEXT.md`

**Depends on:** AUTH-A02

**Parallel group:** P-B (B01–B06 can run in parallel — different write sets)

---

#### Specification

Add the following import if not already present:
```dart
import '../../services/authorization_service.dart';
```

For **each** of the following mutation methods, add an authorization check as the very first
statement in the method body, before any DB write or `transaction()` call:

**Pattern to apply:**
```dart
// At the very start of the method, before any local write:
final _authResult = await authorization.check(
  action: SyncAction.<actionName>,
  schoolId: <schoolIdFromParams or null>,
  recordId: <recordIdFromParams or null>,
);
if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
```

**Methods to update and their check parameters:**

| Method | SyncAction | schoolId source | recordId source |
|---|---|---|---|
| `createExam(...)` | `SyncAction.createExam` | `companion.school.value` (field 2 in payload — `school` field present in `ExamsCompanion`) | `null` |
| `updateExam(String examId, ...)` | `SyncAction.updateExam` | `null` (service looks up from DB via `getSchoolForExam`) | `examId` |
| `deleteExam(String examId, ...)` | `SyncAction.deleteExam` | `null` | `examId` |
| `createPaper(...)` | `SyncAction.createPaper` | `companion.school.value` | `null` |
| `updatePaper(String paperId, ...)` | `SyncAction.updatePaper` | `companion.school.value` if present, else `null` — if school not in companion, pass `recordId: paperId` and let the service look it up by querying `SELECT school FROM papers WHERE id = ?` (add `getPaperSchool()` helper if needed — same pattern as `getSchoolForExam`) | `paperId` if schoolId null |
| `deletePaper(String paperId, ...)` | `SyncAction.deletePaper` | `null` | `paperId` |
| `markGrades(...)` | `SyncAction.markGrades` | `schoolId` parameter (already present in method signature) | `null` |
| `updateGrade(String gradeId, ...)` | `SyncAction.updateGrade` | `schoolId` parameter if present; otherwise `null` + `recordId: gradeId` (add `getSchoolForGrade()` helper: `SELECT school FROM grades WHERE id = ?`) | `gradeId` |
| `deleteGrade(String gradeId, ...)` | `SyncAction.deleteGrade` | `null` | `gradeId` |
| `updateMastery(...)` | `SyncAction.updateMastery` | `schoolId` parameter | `null` |

**Additional DAO helper to add if needed (same pattern as A01):**
- `getSchoolForPaper(String paperId) → Future<String?>` — `SELECT school FROM papers WHERE id = ?`
- `getSchoolForGrade(String gradeId) → Future<String?>` — `SELECT school FROM grades WHERE id = ?`

Add these to the **One-shot reads** section if the corresponding mutation method does not
already receive `schoolId` as a parameter.

**Important:** Ensure `authorization` is accessible — it is the module-level global from
`lib/client.dart`. It is imported via `import '../../client.dart';` which is already present
in this DAO file.

---

**Scheme and answer sheet log methods** — `ExamsGradesDao` has four "log-only" methods that
write directly to the `logs` table (they do not mutate a data table, but they DO enqueue a
sync action). Add authorization checks to these as well:

| Method | SyncAction | schoolId source | recordId |
|---|---|---|---|
| `logUploadScheme(...)` | `SyncAction.uploadScheme` | `schoolId` parameter | `null` |
| `logDeleteScheme(...)` | `SyncAction.deleteScheme` | `schoolId` parameter | `null` |
| `logUploadAnswerSheet(...)` | `SyncAction.uploadAnswerSheet` | `schoolId` parameter | `null` |
| `logDeleteAnswerSheet(...)` | `SyncAction.deleteAnswerSheet` | `schoolId` parameter | `null` |

All four methods already receive `schoolId` as a named parameter — pass it directly.

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md` — note authorization checks on exam/grade mutations
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "feat: wire authorization checks into ExamsGradesDao mutations"`

---

### Task AUTH-B02: [x] Wire Authorization into `FinanceDao` Mutations

**Files to modify:** `lib/database/daos/finance_dao.dart`

**Context files to read (if needed):** `lib/database/CONTEXT.md`

**Depends on:** AUTH-A02

**Parallel group:** P-B

---

#### Specification

Add import if not present:
```dart
import '../../services/authorization_service.dart';
```

Apply the **same pattern** as B01 to each finance mutation method:

| Method | SyncAction | schoolId source | recordId source |
|---|---|---|---|
| `createFee(...)` | `SyncAction.createFee` | `companion.school.value` | `null` |
| `updateFee(String feeId, ...)` | `SyncAction.updateFee` | `null` | `feeId` |
| `deleteFee(String feeId, ...)` | `SyncAction.deleteFee` | `null` | `feeId` |
| `createInvoice(...)` | `SyncAction.createInvoice` | `companion.school.value` | `null` |
| `updateInvoice(String invoiceId, ...)` | `SyncAction.updateInvoice` | `null` | `invoiceId` |
| `deleteInvoice(String invoiceId, ...)` | `SyncAction.deleteInvoice` | `null` | `invoiceId` |
| `createPayment(...)` | `SyncAction.createPayment` | `companion.school.value` (or extract from payload) | `null` |
| `updatePayment(String paymentId, ...)` | `SyncAction.updatePayment` | `null` | `paymentId` |
| `deletePayment(String paymentId, ...)` | `SyncAction.deletePayment` | `null` | `paymentId` |
| `approvePayment(String paymentId, ...)` | `SyncAction.approvePayment` | `null` | `paymentId` |

For `createPayment`, if school is not a direct parameter, check the `PaymentsCompanion` or
the surrounding method signature. If `school` is available, pass it directly. If not, look it
up: add `getSchoolForInvoice()` (already added in A01) to trace school from the invoice.

---

Also check `plans_dao.dart` for any discount-mutation methods (the `discounts` table may be
managed there). If `createDiscount`, `updateDiscount`, `deleteDiscount` methods exist in
`plans_dao.dart`, add them to the AUTH-B06 scope (see below). If they are in `finance_dao.dart`,
add them here with:

| Method | SyncAction | schoolId source | recordId |
|---|---|---|---|
| `createDiscount(...)` | `SyncAction.createDiscount` | `null` (system-level) | `null` |
| `updateDiscount(...)` | `SyncAction.updateDiscount` | `null` | `null` |
| `deleteDiscount(...)` | `SyncAction.deleteDiscount` | `null` | `null` |

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "feat: wire authorization checks into FinanceDao mutations"`

---

### Task AUTH-B03: Wire Authorization into `AnnouncementsDao` Mutations

**Files to modify:** `lib/database/daos/announcements_dao.dart`

**Context files to read (if needed):** `lib/database/CONTEXT.md`

**Depends on:** AUTH-A02

**Parallel group:** P-B

---

#### Specification

Add import if not present:
```dart
import '../../services/authorization_service.dart';
```

Apply the pattern to:

| Method | SyncAction | schoolId source | recordId source |
|---|---|---|---|
| `createAnnouncement(...)` | `SyncAction.createAnnouncement` | `companion.school.value` | `null` |
| `updateAnnouncement(String id, ...)` | `SyncAction.updateAnnouncement` | `null` | `id` |
| `deleteAnnouncement(String id, ...)` | `SyncAction.deleteAnnouncement` | `null` | `id` |

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "feat: wire authorization checks into AnnouncementsDao mutations"`

---

### Task AUTH-B04: Wire Authorization into `AttendanceDao` and `AcademicsDao` Mutations

**Files to modify:**
- `lib/database/daos/attendance_dao.dart`
- `lib/database/daos/academics_dao.dart`

**Context files to read (if needed):** `lib/database/CONTEXT.md`

**Depends on:** AUTH-A02

**Parallel group:** P-B

---

#### Specification

Add import if not present in each file:
```dart
import '../../services/authorization_service.dart';
```

**`AttendanceDao` methods:**

| Method | SyncAction | schoolId source | recordId |
|---|---|---|---|
| `markAttendance(...)` | `SyncAction.markAttendance` | `schoolId` parameter (already in signature) | `null` |
| `deleteAttendance(...)` | `SyncAction.deleteAttendance` | `schoolId` parameter (already in signature) | `null` |

If `schoolId` is not directly available as a method parameter, read it from the companion
(`companion.school.value`) or add a lookup helper `getSchoolForAttendance(attendanceId)`.

**`AcademicsDao` methods:**

Read the `AcademicsDao` to identify all mutation methods (methods that write to DB and enqueue
a `LogsCompanion` row). Common candidates:

| Method | SyncAction | schoolId source | recordId |
|---|---|---|---|
| `createLesson(...)` | `SyncAction.createLesson` | `companion.school.value` | `null` |
| `deleteLesson(String lessonId, ...)` | `SyncAction.deleteLesson` | `null` (look up: add `getSchoolForLesson(lessonId)` → `SELECT school FROM lessons WHERE id = ?`) | `lessonId` |
| Any other mutation methods found | Use matching SyncAction | Extract school from params | — |

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "feat: wire authorization checks into AttendanceDao and AcademicsDao mutations"`

---

### Task AUTH-B05: Wire Authorization into `TimetableDao` Mutations

**Files to modify:** `lib/database/daos/timetable_dao.dart`

**Context files to read (if needed):** `lib/database/CONTEXT.md`

**Depends on:** AUTH-A02

**Parallel group:** P-B

---

#### Specification

Add import if not present:
```dart
import '../../services/authorization_service.dart';
```

Read `timetable_dao.dart` and identify all mutation methods. Expected methods and their mappings:

| Method | SyncAction | schoolId source | recordId |
|---|---|---|---|
| `assignClassTeacher(...)` | `SyncAction.assignClassTeacher` | `schoolId` param | `null` |
| `unassignClassTeacher(...)` | `SyncAction.unassignClassTeacher` | `schoolId` param | `null` |
| `assignSubject(...)` | `SyncAction.assignSubject` | `schoolId` param | `null` |
| `unassignSubject(...)` | `SyncAction.unassignSubject` | `schoolId` param | `null` |
| `createTimetableEntry(...)` | `SyncAction.createTimetableEntry` | `companion.school.value` | `null` |
| `updateTimetableEntry(String id, ...)` | `SyncAction.updateTimetableEntry` | `schoolId` param or lookup | `id` if no schoolId |
| `deleteTimetableEntry(String id, ...)` | `SyncAction.deleteTimetableEntry` | `schoolId` param or lookup | `id` if no schoolId |

For update/delete if school is not a direct parameter, add a lookup helper:
```dart
Future<String?> getSchoolForTimetableEntry(String entryId) async {
  final row = await (select(timetable)..where((t) => t.id.equals(entryId))).getSingleOrNull();
  return row?.school;
}
```

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "feat: wire authorization checks into TimetableDao mutations"`

---

### Task AUTH-B06: Wire Authorization into Remaining DAO Mutations


**Files to modify:**
- `lib/database/daos/departments_dao.dart`
- `lib/database/daos/terms_dao.dart`
- `lib/database/daos/schools_dao.dart` (createSchool, updateSchool, deleteSchool, stream/mpesa mutations)
- `lib/database/daos/members_dao.dart` (createTeacher, createStaff, createOwner, createStudent, createGuardian)
- `lib/database/daos/enrollments_dao.dart` (enrollStudent, unenrollStudent, bulkEnroll)
- `lib/database/daos/plans_dao.dart` (createPlan, updatePlan, purgePlan, createSubscription, updateSubscriptionStatus, createDiscount, updateDiscount, deleteDiscount)
- `lib/database/daos/school_scopes_dao.dart` (school-scoped createRole, updateRole, deleteRole, assignRole, unassignRole)
- `lib/database/daos/catalog_dao.dart` (createSubject, updateSubject, deleteSubject, createTopic, updateTopic, deleteTopic — system-level)
- `lib/database/daos/ai_usage_dao.dart` (updateAiUsage — if present as a mutation)

**Context files to read (if needed):** `lib/database/CONTEXT.md`

**Depends on:** AUTH-A02

**Parallel group:** P-B

---

#### Specification

Add import if not present in each file:
```dart
import '../../services/authorization_service.dart';
```

**`DepartmentsDao`:**

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createDepartment(...)` | `SyncAction.createDepartment` | `companion.school.value` | `null` |
| `updateDepartment(String id, ...)` | `SyncAction.updateDepartment` | `schoolId` param | `null` |
| `deleteDepartment(String id, ...)` | `SyncAction.deleteDepartment` | `schoolId` param | `null` |

**`TermsDao`:**

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createTerm(...)` | `SyncAction.createTerm` | `companion.school.value` | `null` |
| `updateTerm(String id, ...)` | `SyncAction.updateTerm` | `schoolId` param or companion field | `null` |
| `deleteTerm(String id, ...)` | `SyncAction.deleteTerm` | `schoolId` param | `null` |

**`SchoolsDao`** — school-level mutations:

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createSchool(...)` | `SyncAction.createSchool` | `null` (system-level) | `null` |
| `updateSchool(String id, ...)` | `SyncAction.updateSchool` | `id` (the school IS the record) | `null` |
| `deleteSchool(String id, ...)` | `SyncAction.deleteSchool` | `id` | `null` |
| Stream/mpesa create methods (if present) | `SyncAction.createStream` / `createMpesa` etc. | `companion.school.value` | `null` |

For `createSchool`, pass `schoolId: null` — the `AuthorizationService._resolveOrganisation()`
will classify it as `Organisation.system` and check system-level permissions.
For `updateSchool` / `deleteSchool`, pass `schoolId: id` — `client.md` §Determining School ID
says "The `id` field in the payload IS the school id" for UPDATE_SCHOOL / DELETE_SCHOOL.

**`MembersDao`** — creation methods (invitation pattern only; enrollment is in `EnrollmentsDao`):

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createTeacher(...)` | `SyncAction.createTeacher` | `companion.school.value` | `null` |
| `createStaff(...)` | `SyncAction.createStaff` | `companion.school.value` | `null` |
| `createOwner(...)` | `SyncAction.createOwner` | `companion.school.value` | `null` |
| `createStudent(...)` | `SyncAction.createStudent` | `companion.school.value` | `null` |
| `createGuardian(...)` | `SyncAction.createGuardian` | `companion.school.value` | `null` |

**`EnrollmentsDao`** — enrollment mutations (NOT in `MembersDao`):

`EnrollmentsDao` is confirmed to own `enrollStudent`, `unenrollStudent`, and `bulkEnroll`.
`schoolId` is the first named parameter in each method.

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `enrollStudent(...)` | `SyncAction.enrollStudent` | `schoolId` param | `null` |
| `unenrollStudent(...)` | `SyncAction.unenrollStudent` | `schoolId` param | `null` |
| `bulkEnroll(...)` | calls `enrollStudent()` in a loop — adding check to `enrollStudent` covers this transitively | — | — |

**`PlansDao`** — plan, subscription, and discount mutations (system-level for plans/discounts;
school-scoped for subscriptions):

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createPlan(...)` | `SyncAction.createPlan` | `null` (system) | `null` |
| `updatePlan(...)` | `SyncAction.updatePlan` | `null` (system) | `null` |
| `updatePlanStatus(...)` | `SyncAction.updatePlan` | `null` (system) | `null` |
| `purgePlan(...)` | `SyncAction.deletePlan` | `null` (system) | `null` |
| `createSubscription(...)` | `SyncAction.createSubscription` | `sub.school.value` | `null` |
| `updateSubscriptionStatus(...)` | `SyncAction.updateSubscription` | `schoolId` param | `null` |
| Any `deleteSubscription` method | `SyncAction.deleteSubscription` | `schoolId` param | `null` |
| Any `createDiscount` method | `SyncAction.createDiscount` | `null` (system) | `null` |
| Any `updateDiscount` method | `SyncAction.updateDiscount` | `null` (system) | `null` |
| Any `deleteDiscount` method | `SyncAction.deleteDiscount` | `null` (system) | `null` |

Read `plans_dao.dart` in full to find all mutation methods — the grep only revealed a subset.

**`SchoolScopesDao`** — school-scoped role mutations:

`SchoolScopesDao` has its own `createRole`, `updateRole`, `deleteRole`, `assignRole`, and
`unassignRole` methods for **school-scoped** roles. These are separate from the system-level
equivalents in `RolesDao`. Apply the same authorization pattern:

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createRole(...)` | `SyncAction.createRole` | `companion.school.value` (non-null — school-scoped) | `null` |
| `updateRole(...)` | `SyncAction.updateRole` | `null` (system-level per org context) | `null` |
| `deleteRole(...)` | `SyncAction.deleteRole` | `null` (system-level per org context) | `null` |
| `assignRole(...)` | `SyncAction.assignRole` | `schoolId` param (non-null — school-scoped) | `null` |
| `unassignRole(...)` | `SyncAction.unassignRole` | `schoolId` param (non-null — school-scoped) | `null` |

Note: `updateRole` and `deleteRole` classify as `Organisation.system` regardless of whether
they touch a school-scoped role — this is correct per `client.md §Organisation Context Per
Action` which lists `UPDATE_ROLE` and `DELETE_ROLE` as system-level actions.

The existing update/delete member methods are already guarded optionally via
`MemberManagementService`. Those service methods pass `SchoolPermissions?` but do not call
`AuthorizationService`. Add `authorization.check()` at the top of those service methods too
(not DAO — check in service):

In `lib/services/member_management.dart`, for every public method (`updateTeacher`,
`changeTeacherStatus`, `removeTeacher`, `updateStaff`, `changeStaffStatus`, `removeStaff`,
`removeOwner`, `updateStudent`, `changeStudentStatus`, `removeStudent`, `updateGuardian`,
`removeGuardian`), add at the very start (after the `accountId` null check):

```dart
final _authResult = await authorization.check(
  action: SyncAction.<matchingAction>,
  schoolId: schoolId,   // already a parameter
  recordId: null,
);
if (!_authResult.allowed) {
  return Err(MemberActionError.permissionDenied);
  // Also set the denial reason in MemberActionError if needed (see C tasks).
}
```

This replaces (or supplements) the existing optional `SchoolPermissions?` check.

**`CatalogDao`** — subjects/topics (system-level, no schoolId):

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `createSubject(...)` | `SyncAction.createSubject` | `null` (system) | `null` |
| `updateSubject(String id, ...)` | `SyncAction.updateSubject` | `null` | `null` |
| `deleteSubject(String id, ...)` | `SyncAction.deleteSubject` | `null` | `null` |
| `createTopic(...)` | `SyncAction.createTopic` | `null` | `null` |
| `updateTopic(String id, ...)` | `SyncAction.updateTopic` | `null` | `null` |
| `deleteTopic(String id, ...)` | `SyncAction.deleteTopic` | `null` | `null` |

**`AiUsageDao`** (if mutation method exists):

| Method | SyncAction | schoolId | recordId |
|---|---|---|---|
| `updateAiUsage(...)` | `SyncAction.updateAiUsage` | `companion.school.value` | `null` |

---

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md`
- [ ] Update `lib/services/CONTEXT.md` — note MemberManagementService changes
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "feat: wire authorization checks into remaining DAO and service mutations"`

---

> **Note to executor:** Before finishing B06, run:
> ```
> grep -r "SyncAction\." lib/database/daos/ | grep -v "\.g\.dart" | grep -v "\.watch\|\.select\|\.where"
> ```
> to verify every `SyncAction` reference inside a `LogsCompanion` insert now has a corresponding
> `authorization.check()` call above it. Any missed method will appear as an unguarded mutation.

---

### Task AUTH-C01: [x] `PermissionException` UI Error Handling — Shared Helper + Snackbar Pattern

**Files to create/modify:**
- `lib/ui/widgets/permission_denied_handler.dart` ← **create new**
- `lib/ui/theme/app_theme.dart` ← add `kPermissionDeniedColor` constant if not present

**Context files to read (if needed):** `lib/ui/CONTEXT.md`

**Depends on:** AUTH-A01 (for `PermissionException` type)

**Parallel group:** P-C (C01–C04 can all run in parallel — different write sets)

---

#### Specification

Create `lib/ui/widgets/permission_denied_handler.dart`:

```dart
import 'package:flutter/material.dart';
import '../../services/authorization_service.dart';
import '../theme/app_theme.dart';

/// Shows a standardized permission-denied snackbar on [context].
///
/// Call this whenever a [PermissionException] is caught in a widget's
/// button handler:
///
/// ```dart
/// try {
///   await db.examsGradesDao.deleteExam(examId, accountId: accountId);
/// } on PermissionException catch (e) {
///   if (context.mounted) showPermissionDenied(context, e.reason);
/// }
/// ```
void showPermissionDenied(BuildContext context, String reason) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFB00020),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
      ),
    );
}

/// Wraps an async action and automatically shows a permission-denied snackbar
/// on [PermissionException].
///
/// Usage:
/// ```dart
/// await guardedAction(context, () => dao.deleteExam(examId, accountId: id));
/// ```
Future<void> guardedAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on PermissionException catch (e) {
    if (context.mounted) showPermissionDenied(context, e.reason);
  }
}
```

This helper is lightweight. Import it wherever a button handler calls a DAO mutation.
Use `guardedAction()` for the simplest case, or catch `PermissionException` manually
for methods that return `Result<T, E>` (where the error is surfaced differently).

---

**Update after completion:**
- [x] Update `lib/ui/CONTEXT.md` — add `permission_denied_handler.dart` entry
- [x] Mark this task `[x]`
- [x] Orchestrator: `git add -A && git commit -m "feat: add permission denied snackbar helper (guardedAction, showPermissionDenied)"`

---

### Task AUTH-C02: UI Permission Gating — Exams & Grades Screens

**Files to modify:**
- `lib/ui/screens/school_dashboard/exams/exam_list_view.dart`
- `lib/ui/screens/school_dashboard/exams/exam_creation_page.dart`
- `lib/ui/screens/school_dashboard/exams/create_paper_sheet.dart`
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
- `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
- `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`

**Context files to read (if needed):** `lib/ui/CONTEXT.md`

**Depends on:** AUTH-C01 (for `guardedAction` / `showPermissionDenied`)

**Parallel group:** P-C

---

#### Specification

**Goal:** Wrap every action button (FABs, delete/edit icon buttons, submit buttons) with a
permission guard so they are hidden or disabled when the user lacks the required permission.
Each screen receives a `SchoolContext` which carries `SchoolContext.permissions`
(a `SchoolPermissions` instance). Use it for synchronous checks.

The `SchoolPermissions` API:
```dart
// Returns true if user can perform Action on Resource.
bool can(Resource resource, Action action)
// Returns true if user can perform ANY of actions on resource.
bool canAny(Resource resource, List<Action> actions)
```

**Pattern to apply to FABs:**
```dart
// Before: always shows FAB
FloatingActionButton(onPressed: _createExam, ...)

// After: hide if user cannot create exams
if (schoolContext.permissions.can(Resource.exams, Action.create))
  FloatingActionButton(onPressed: _createExam, ...)
```

**Pattern to apply to action icon buttons (delete, edit) in list rows:**
```dart
// Delete button — show only if can delete
if (schoolContext.permissions.can(Resource.exams, Action.delete))
  IconButton(
    icon: const Icon(Icons.delete_outline_rounded),
    onPressed: () => guardedAction(context, () => _deleteExam(exam.id)),
  ),
```

**Pattern to apply to wrap async handlers with `guardedAction`:**
```dart
// Any button handler that calls a DAO mutation:
onPressed: () => guardedAction(context, () async {
  await db.examsGradesDao.deleteExam(
    examId, accountId: cache.currentUser!.user.id);
}),
```

**Permission requirements per screen/action:**

| Screen | UI element | Resource | Required Action |
|---|---|---|---|
| `ExamListView` | "Create Exam" FAB | `Resource.exams` | `Action.create` |
| `ExamListView` | Delete exam row button | `Resource.exams` | `Action.delete` |
| `ExamDetailPage` | "Add Paper" button | `Resource.exams` | `Action.create` |
| `ExamDetailPage` | Edit exam button | `Resource.exams` | `Action.update` |
| `ExamDetailPage` | Delete exam button | `Resource.exams` | `Action.delete` |
| `CreatePaperSheet` | Submit (create paper) | `Resource.exams` | `Action.create` |
| `PaperDetailPage` | Delete paper button | `Resource.exams` | `Action.delete` |
| `PaperDetailPage` | "Mark Grades" / submit grades | `Resource.grades` | `Action.mark` |
| `GradeDetailPage` | Edit grade button | `Resource.grades` | `Action.update` |
| `GradeDetailPage` | Delete grade button | `Resource.grades` | `Action.delete` |

The screens already receive `SchoolContext` as a constructor parameter. Access permissions
via `schoolContext.permissions.can(...)`.

**Important:** The check for page-level access (students/guardians blocked from exam
management) is already implemented in `ExamsGradesScreen`. Do NOT duplicate or remove it.
This task adds fine-grained control within the admin view.

---

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "ui: add permission gating to exams and grades screens"`

---

### Task AUTH-C03: UI Permission Gating — Finance Screen

**Files to modify:**
- `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
- `lib/ui/screens/school_dashboard/finance/fee_detail_page.dart`

**Context files to read (if needed):** `lib/ui/CONTEXT.md`

**Depends on:** AUTH-C01

**Parallel group:** P-C

---

#### Specification

Apply the same hide/guard pattern from C02 using `schoolContext.permissions.can(...)`.

**Permission requirements:**

| Screen | UI element | Resource | Required Action |
|---|---|---|---|
| `FinanceScreen` | "Create Fee" FAB / button | `Resource.fees` | `Action.create` |
| `FinanceScreen` | "Create Invoice" button | `Resource.fees` | `Action.create` |
| `FinanceScreen` | Delete fee row | `Resource.fees` | `Action.delete` |
| `FeeDetailPage` | Edit fee button | `Resource.fees` | `Action.update` |
| `FeeDetailPage` | Delete fee button | `Resource.fees` | `Action.delete` |
| `FeeDetailPage` | "Generate Invoice" button | `Resource.fees` | `Action.create` |
| `FeeDetailPage` | Edit invoice button | `Resource.fees` | `Action.update` |
| `FeeDetailPage` | Delete invoice button | `Resource.fees` | `Action.delete` |
| `FeeDetailPage` | "Record Payment" button | `Resource.payments` | `Action.create` |
| `FeeDetailPage` | Edit payment button | `Resource.payments` | `Action.update` |
| `FeeDetailPage` | Delete payment button | `Resource.payments` | `Action.delete` |
| `FeeDetailPage` | "Approve Payment" button | `Resource.payments` | `Action.approve` |

Wrap all async button handlers for mutations with `guardedAction()`.

---

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "ui: add permission gating to finance screens"`

---

### Task AUTH-C04: UI Permission Gating — Announcements, Timetable, Attendance, Members

**Files to modify:**
- `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
- `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
- `lib/ui/screens/school_dashboard/timetable/lesson_management.dart`
- `lib/ui/screens/school_dashboard/academics/tabs/attendance_tab.dart`
- `lib/ui/screens/school_dashboard/members/teachers_tab.dart`
- `lib/ui/screens/school_dashboard/members/staff_tab.dart`
- `lib/ui/screens/school_dashboard/members/students_tab.dart`
- `lib/ui/screens/school_dashboard/members/guardians_tab.dart`
- `lib/ui/screens/school_dashboard/members/owners_tab.dart`
- `lib/ui/screens/school_dashboard/members/departments_tab.dart`

**Context files to read (if needed):** `lib/ui/CONTEXT.md`

**Depends on:** AUTH-C01

**Parallel group:** P-C

---

#### Specification

Apply the hide/guard pattern from C02 + C03. Read each file to identify FABs and action
buttons, then apply `schoolContext.permissions.can(...)` guards.

**Announcements screen** — already has role-based feed switching via `schoolContext.permissions.canAny(Resource.announcements, ...)`. Additionally:

| UI element | Resource | Required Action |
|---|---|---|
| "Compose" / create FAB in `_AdminFeed` | `Resource.announcements` | `Action.create` |
| Edit announcement button | `Resource.announcements` | `Action.update` |
| Delete announcement button | `Resource.announcements` | `Action.delete` |

**Timetable screen:**

| UI element | Resource | Required Action |
|---|---|---|
| "Add entry" FAB or button | `Resource.classes` | `Action.create` |
| Edit timetable entry | `Resource.classes` | `Action.update` |
| Delete timetable entry | `Resource.classes` | `Action.delete` |
| "Assign class teacher" button | `Resource.classes` | `Action.assign` |
| "Assign subject" button | `Resource.classes` | `Action.assign` |

**Attendance tab:**

| UI element | Resource | Required Action |
|---|---|---|
| "Mark attendance" button | `Resource.attendance` | `Action.mark` |
| Delete attendance entry | `Resource.attendance` | `Action.delete` |

**Members tabs** — these screens already use `SchoolPermissions` via `MemberManagementService`.
Audit each tab and ensure that:
1. "Add member" FABs are hidden if `!permissions.can(Resource.<memberType>, Action.create)`
2. Row-level edit/delete buttons are hidden if user lacks update/delete on the relevant resource
3. All async mutation handlers use `guardedAction()` or handle `MemberActionError.permissionDenied`
   with a `showPermissionDenied(context, reason)` call

Member resource mapping:
- `TeachersTab` → `Resource.teachers`
- `StaffTab` → `Resource.staff`
- `StudentsTab` → `Resource.students`
- `GuardiansTab` → `Resource.students` (guardians map to students resource)
- `OwnersTab` → `Resource.owners`
- `DepartmentsTab` → `Resource.departments`

---

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "ui: add permission gating to announcements, timetable, attendance, and members screens"`

---

### Task AUTH-C05: Update `MemberActionError` to Carry Denial Reason + Propagate to UI

**Files to modify:**
- `lib/services/member_management.dart`
- All UI files that handle `MemberActionError.permissionDenied` (search: `MemberActionError.permissionDenied`)

**Context files to read (if needed):** `lib/services/CONTEXT.md`, `lib/ui/CONTEXT.md`

**Depends on:** AUTH-B06, AUTH-C01

**Parallel group:** none (small sequential cleanup)

---

#### Specification

Currently `MemberActionError.permissionDenied` is a plain enum value — it carries no message.
After AUTH-B06, the service calls `authorization.check()` which provides a human-readable
`reason`. We need to surface that reason to the UI.

**Option A (simpler — recommended):** Convert `MemberActionError` from a plain enum into a
sealed class so `permissionDenied` can carry a `reason` string:

```dart
sealed class MemberActionError {
  const MemberActionError();
}

final class NoActiveAccount extends MemberActionError {
  const NoActiveAccount();
}

final class NotFound extends MemberActionError {
  const NotFound();
}

final class DatabaseError extends MemberActionError {
  const DatabaseError();
}

final class CannotRemoveSelf extends MemberActionError {
  const CannotRemoveSelf();
}

final class PermissionDenied extends MemberActionError {
  const PermissionDenied(this.reason);
  final String reason;
}
```

**Option B (less invasive):** Keep `MemberActionError` as an enum, but add a companion
`String? permissionReason` field to `Result<void, MemberActionError>`. However, this requires
changes to the `Result` type which is used project-wide. **Do not pursue Option B.**

**After converting to sealed class:**
1. Update all service methods to return `Err(const PermissionDenied(authResult.reason!))` when
   the authorization check fails.
2. Search for all `case MemberActionError.permissionDenied:` switch arms in the UI and update
   them to handle the new `PermissionDenied` class, passing `e.reason` to `showPermissionDenied`.
3. Update all other `switch` expressions on `MemberActionError` to use the new sealed class
   pattern.

**Search command to find all UI usages:**
```
grep -r "MemberActionError" lib/ui/
```

Typical UI handling pattern after the change:
```dart
// In widget:
final result = await memberManagementService.removeTeacher(...);
result.match(
  onOk: (_) { /* success */ },
  onErr: (err) {
    switch (err) {
      case PermissionDenied(:final reason):
        showPermissionDenied(context, reason);
      case NotFound():
        showErrorSnackbar(context, 'Member not found.');
      // ... other cases
    }
  },
);
```

---

**Update after completion:**
- [ ] Update `lib/services/CONTEXT.md`
- [ ] Update `lib/ui/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "refactor: convert MemberActionError to sealed class carrying denial reason"`

---

### Task AUTH-C06: UI Permission Gating — System Dashboard (Plans, Subjects, Roles, Schools)

**Files to modify:**
- `lib/ui/screens/system/plans/plans_section.dart`
- `lib/ui/screens/system/schools/schools_section.dart`
- `lib/ui/screens/system/schools/create_school_sheet.dart`
- `lib/ui/screens/system/settings/subjects_section.dart`
- `lib/ui/screens/system/roles/roles_section.dart`
- `lib/ui/screens/system/roles/role_detail_screen.dart`
- `lib/ui/screens/system/users/users_section.dart`

**Context files to read (if needed):** `lib/ui/CONTEXT.md`

**Depends on:** AUTH-A02, AUTH-C01

**Parallel group:** P-C

---

#### Specification

The system dashboard uses `SystemPermissions` (not `SchoolPermissions`) to gate actions.
`SystemPermissions` is available via the system dashboard's state management — check how
it is passed to these screens (likely via the system dashboard state or a provider).

**Permission checks to add:**

| Screen | UI element | Resource | Required Action |
|---|---|---|---|
| `PlansSection` | Create plan FAB | `Resource.plans` | `Action.create` |
| `PlansSection` | Edit plan button | `Resource.plans` | `Action.update` |
| `PlansSection` | Delete plan button | `Resource.plans` | `Action.delete` |
| `SchoolsSection` | Create school button | `Resource.schools` | `Action.create` |
| `SubjectsSection` | Create subject FAB | `Resource.subjects` | `Action.create` |
| `SubjectsSection` | Edit subject button | `Resource.subjects` | `Action.update` |
| `SubjectsSection` | Delete subject button | `Resource.subjects` | `Action.delete` |
| `RolesSection` | Create role FAB | `Resource.roles` | `Action.create` |
| `RoleDetailScreen` | Edit role button | `Resource.roles` | `Action.update` |
| `RoleDetailScreen` | Delete role button | `Resource.roles` | `Action.delete` |
| `RoleDetailScreen` | Assign user button | `Resource.roles` | `Action.assign` |
| `UsersSection` | Delete user button | `Resource.users` | `Action.delete` |

Use `systemPermissions.can(resource, action)` to gate each element. If `SystemPermissions`
is not currently passed to a screen, thread it through from the system dashboard state.

Wrap async mutation handlers with `guardedAction(context, ...)`.

---

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git add -A && git commit -m "ui: add permission gating to system dashboard screens"`

---

## Task Dependency Graph

```
AUTH-A01 (AuthorizationService core + DAO helpers)
    │
    ├── AUTH-A02 (Register singleton)
    │       │
    │       ├── AUTH-B01 (ExamsGradesDao)   ─┐
    │       ├── AUTH-B02 (FinanceDao)        │
    │       ├── AUTH-B03 (AnnouncementsDao)  ├── all P-B parallel
    │       ├── AUTH-B04 (Attendance+Acad)   │
    │       ├── AUTH-B05 (TimetableDao)      │
    │       └── AUTH-B06 (Remaining DAOs:   ─┘
    │               PlansDao, EnrollmentsDao,
    │               SchoolScopesDao, MembersDao,
    │               DepartmentsDao, TermsDao,
    │               SchoolsDao, CatalogDao,
    │               AiUsageDao)
    │
    └── AUTH-A03 (AGENT.md update — SyncAction 91-94 + maintenance rule)
                 [can run in parallel with A02 and all B tasks]

AUTH-C01 (PermissionDenied helper) — depends on A01 only; can start once A01 is done
    │
    ┌─────────────┼─────────────┬────────────┐
AUTH-C02        AUTH-C03      AUTH-C04     AUTH-C06
(Exams/Grades) (Finance)   (Announce,     (System
                             Timetable,    Dashboard)
                             Members)
                                  │
                             AUTH-C05
                          (MemberActionError
                             sealed class —
                          depends on B06 + C01)
```

**Total tasks: 14**
- Group A (foundation): A01, A02, A03
- Group B (DAO wiring, parallel): B01, B02, B03, B04, B05, B06
- Group C (UI gating, parallel after C01): C01, C02, C03, C04, C05, C06

**Parallel execution notes:**
- B01–B06 all have disjoint write sets (different DAO files) — spawn all 6 in parallel after A02.
- C01 can start as soon as A01 is done (only needs the `PermissionException` type).
- C02–C06 can run in parallel with each other after C01 (disjoint screen files).
- C05 touches `member_management.dart` and UI files. Ensure B06 is complete before starting C05.