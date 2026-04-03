# TASKS.md — Audit Remediation Task List

> Generated from 6 persona audits (System, Owner, Teacher, Staff, Student, Guardian).
> Deduplicated across audits. Organized into 6 tracks (A–F) by severity.
>
> **Unique findings after deduplication: ~85 raw → 43 tasks**
>
> **Deduplication map:**
> - STU-001 = STF-001 = GRD-003 = OWN-016 → Task A07
> - SYS-010 = OWN-005 → Task D01
> - OWN-009 = GRD-004 → Task D02
> - STU-008 = GRD-005 → Task D03
> - OWN-008 = STF-007 → Task E01
> - OWN-001 = SYS-015 → Task A01
> - OWN-002 + OWN-010 → Task A02
> - OWN-019 = OWN-030 → absorbed into Task C03
> - SYS-024 + SYS-025 → Task F11
> - STU-002 + GRD-008 → Task B07
> - TCH-010 + TCH-016 → Task B08
> - STF-002 + STF-003 → Task B06
> - STF-005 + STF-015 → Task E02
> - OWN-014 + GRD-012 → Task F09

---

## Recommended Execution Order

```
Track A (Critical Security) ──► Track B (Data Scoping) ──► Track E (Defense-in-Depth) ──► Track F (UI Polish)
                              ↗                           ↗
Track C (Navigation/Routing) ─┘   Track D (Reactivity) ──┘
```

**Phase 1 — Security (MUST fix first):**
- A01 → A02 (sequential — A02 depends on A01)
- A03, A04, A05, A06, A07, A08, A09 (parallel with each other, parallel with A01→A02)

**Phase 2 — Data Scoping + Navigation (parallel tracks):**
- B01–B08 (parallel with each other after Phase 1)
- C01–C05 (parallel with B track)

**Phase 3 — Reactivity + Defense-in-Depth:**
- D01–D05 (parallel with each other)
- E01–E06 (parallel with D track)

**Phase 4 — UI Polish (lowest priority):**
- F01–F12 (all parallelizable)

---

## Track A: CRITICAL — Permission & Security

### Task A01: Migrate `roles.permissions` column from TextColumn to BlobColumn ✅
**Files to create/modify:** `lib/database/tables/roles.dart`, `lib/database/database.dart`, `lib/core/permission_parser.dart`, `lib/models/system_permissions.dart`
**Context files to read (if needed):** `lib/database/tables/CONTEXT.md`, `lib/database/CONTEXT.md`, `lib/models/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-A

**Audit refs:** OWN-001, SYS-015

**Specification:**

Per AGENT.md §17a, `roles.permissions` must be a `blob` column storing binary `[resource_id: u8, actions_lo: u8, actions_hi: u8]` triplets. Currently it is `TextColumn` storing JSON text.

1. **`lib/database/tables/roles.dart`** — Change column definition:
   ```dart
   // BEFORE:
   TextColumn get permissions => text()(); // JSON map of permissions
   // AFTER:
   BlobColumn get permissions => blob()();
   ```
   This changes the generated `RolesData.permissions` type from `String` to `Uint8List`.

2. **`lib/database/database.dart`** — Add a schema migration (increment `schemaVersion`):
   - In the `MigrationStrategy.onUpgrade` callback, add a migration step that:
     a. Creates a new temporary column or table
     b. Reads all existing `roles` rows
     c. For each row, parses the text `permissions` via `parsePermissions()` → `Map<Resource, int>` → `Permissions(map).toBlob()` → writes the `Uint8List` blob back
     d. Alternatively, use `customStatement` to `ALTER TABLE roles RENAME COLUMN permissions TO permissions_old` then `ALTER TABLE roles ADD COLUMN permissions BLOB NOT NULL DEFAULT x''` then migrate data, then drop old column. (SQLite supports `ALTER TABLE ... RENAME COLUMN` since 3.25.0 / Drift supports it.)
   - Simplest approach: since SQLite doesn't easily alter column types in-place, use the Drift migration approach:
     ```dart
     // In onUpgrade, from old version to new:
     if (from < NEW_VERSION) {
       // 1. Read all roles
       final rows = await customSelect('SELECT id, permissions FROM roles').get();
       // 2. Add new blob column
       await customStatement('ALTER TABLE roles ADD COLUMN permissions_blob BLOB NOT NULL DEFAULT X\'\'');
       // 3. Migrate each row
       for (final row in rows) {
         final textPerms = row.read<String>('permissions');
         final parsed = parsePermissions(textPerms);
         final blob = Permissions(parsed).toBlob();
         await customStatement(
           'UPDATE roles SET permissions_blob = ? WHERE id = ?',
           [blob, row.read<String>('id')],
         );
       }
       // 4. Drop old column, rename new
       // SQLite ≥ 3.35 supports DROP COLUMN:
       await customStatement('ALTER TABLE roles DROP COLUMN permissions');
       await customStatement('ALTER TABLE roles RENAME COLUMN permissions_blob TO permissions');
     }
     ```
   - **Important:** Check the minimum SQLite version on target platforms. If DROP COLUMN is not available, use the standard table-recreation migration pattern.

3. **`lib/core/permission_parser.dart`** — Add a new top-level function for blob-first parsing:
   ```dart
   /// Parses permissions from a Uint8List blob (the new canonical format).
   /// Falls back to text-based parsing for migration compatibility.
   Map<Resource, int> parsePermissionsBlob(Uint8List? blob) {
     if (blob == null || blob.isEmpty) return {};
     final perms = Permissions.fromBlob(blob);
     return Map<Resource, int>.from(perms.map);
   }
   ```
   Keep `parsePermissions(String?)` for backward compat during migration, but mark it `@Deprecated`.

4. **`lib/models/system_permissions.dart`** — Update `RolePermissions` class:
   ```dart
   // BEFORE:
   final String permissionsData;
   // AFTER:
   final Uint8List permissionsData;
   ```
   Update the `SystemPermissions.forUser` factory to use `parsePermissionsBlob` instead of `parsePermissions`.

5. **All callers** that read `RolesData.permissions` as `String` must be updated to handle `Uint8List`. Key callers:
   - `lib/ui/screens/school_dashboard/school_dashboard_screen.dart` `_initializeSession` (~L155): change `parsePermissions(r.permissions)` to `parsePermissionsBlob(r.permissions)`
   - `lib/database/daos/school_scopes_dao.dart` — see Task A02
   - `lib/ui/screens/system/system_dashboard_screen.dart` `_loadPermissions` — update `RolePermissions` construction
   - Any file that references `r.permissions` from a `RolesData` row

**Update after completion:**
- [x] Update `lib/database/tables/CONTEXT.md` — change roles.permissions from text to blob
- [x] Update `lib/database/CONTEXT.md` — note new schema version
- [x] Update `lib/models/CONTEXT.md` — update RolePermissions type
- [x] Update `lib/core/CONTEXT.md` — note parsePermissionsBlob addition
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A02: Fix permission encoding in SchoolScopesDao (createRole / updateRole) ✅
**Files to create/modify:** `lib/database/daos/school_scopes_dao.dart`
**Context files to read (if needed):** `lib/database/daos/CONTEXT.md`
**Depends on:** Task A01
**Parallel group:** P1-A (sequential after A01)

**Audit refs:** OWN-002, OWN-010

**Specification:**

After A01, `RolesCompanion.permissions` is `Value<Uint8List>` (blob). The DAO methods `createRole` and `updateRole` currently use `utf8.encode(companion.permissions.value)` to build the sync proto payload. This sends JSON-encoded text bytes as the proto `permissions` field — the server expects binary blob format.

1. **`createRole` (~L324-360)** — Fix the payload construction:
   ```dart
   // BEFORE:
   permissions: companion.permissions.present
       ? utf8.encode(companion.permissions.value)
       : null,
   // AFTER (post-A01, .value is already Uint8List):
   permissions: companion.permissions.present
       ? companion.permissions.value
       : null,
   ```

2. **`updateRole` (~L367-402)** — Fix the payload construction:
   ```dart
   // BEFORE:
   payload.permissions.addAll(utf8.encode(changes.permissions.value));
   // AFTER (post-A01, .value is already Uint8List):
   payload.permissions.addAll(changes.permissions.value);
   ```

3. Remove the `import 'dart:convert'` if `utf8` is no longer used anywhere in this file (check other usages first).

4. **Verify** that callers of `createRole` and `updateRole` now pass `Value<Uint8List>` for permissions. Key callers:
   - School roles screen role creation/editing sheets
   - System roles screen role creation/editing sheets
   - These callers should use `Permissions(map).toBlob()` to build the blob.

**Update after completion:**
- [ ] Update `lib/database/daos/CONTEXT.md` — note SchoolScopesDao permission encoding fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A03: Fix System privilege escalation — promote to Super / promote to System guards ✅
**Files to create/modify:** `lib/ui/screens/system/members/members_section.dart`, `lib/ui/screens/system/users/users_section.dart`, `lib/ui/screens/system/users/invite_user_sheet.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit refs:** SYS-002, SYS-004, SYS-005, SYS-006, SYS-023

**Specification:**

Multiple privilege escalation vectors exist in the System dashboard. Fix all of them:

1. **`members_section.dart` ~L136-179 (`_promoteMember`)** — SYS-002: A System user can promote another to Super level.
   - Add a guard: only `UserLevel.super_` users may set another user's level to `super_`.
   - Before calling the DAO `setUserLevel`, check:
     ```dart
     final currentUser = cache.currentUser;
     if (targetLevel == UserLevel.super_ && currentUser?.user.level != UserLevel.super_) {
       // Show error snackbar: "Only Super users can promote to Super level"
       return;
     }
     ```
   - Also add a guard: no user may promote themselves.

2. **`users_section.dart` ~L410-430 ("Promote to System")** — SYS-004: Currently gated by `Users.Update` instead of `Users.Assign`.
   - Change the permission check from:
     ```dart
     permissions.can(Resource.users, Action.update)
     ```
     to:
     ```dart
     permissions.can(Resource.users, Action.assign)
     ```
   - Also add a status guard (SYS-023): do not allow promoting deleted or suspended users:
     ```dart
     if (user.status == UserStatus.deleted || user.status == UserStatus.suspended) {
       // Show snackbar: "Cannot promote a ${user.status.name} user"
       return;
     }
     ```

3. **`invite_user_sheet.dart` ~L57-62 (`_canCreateSystemUser`)** — SYS-005: Uses `isElevated` (level ≥ system) without checking `Users.Create`.
   - Change to require both elevation AND the create permission:
     ```dart
     bool get _canCreateSystemUser =>
         widget.permissions.isElevated &&
         widget.permissions.can(Resource.users, Action.create);
     ```

4. **`invite_user_sheet.dart` ~L170-192 (invite flow save)** — SYS-006: Uses `SyncAction.updateUser` with no client guard against setting level to `super_`.
   - Add a hard guard before the DAO call:
     ```dart
     if (_selectedLevel == UserLevel.super_) {
       // Super users can only be created by other super users AND only via
       // a different flow. Block unconditionally in invite sheet.
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Cannot invite Super-level users')),
       );
       return;
     }
     ```
   - If the current user is `UserLevel.system`, also block creating system-level users without `Users.Create`:
     ```dart
     if (_selectedLevel == UserLevel.system && !widget.permissions.can(Resource.users, Action.create)) {
       // ...
       return;
     }
     ```

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note privilege escalation guards added
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A04: Fix System FAB visibility — wrong permission check ✅
**Files to create/modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit ref:** SYS-001

**Specification:**

The `_showFab` getter (~L170-183) checks `Users.Update` for the "Add Member" action. Per AGENT.md §17a, adding a relationship is `Action.assign`, not `Action.update`.

Change:
```dart
// BEFORE (~L177):
return _permissions.can(Resource.users, Action.create) ||
    _permissions.can(Resource.users, Action.update) ||   // ← wrong
    _permissions.can(Resource.schools, Action.create) ||
    _permissions.can(Resource.roles, Action.create);
// AFTER:
return _permissions.can(Resource.users, Action.create) ||
    _permissions.can(Resource.users, Action.assign) ||   // ← correct
    _permissions.can(Resource.schools, Action.create) ||
    _permissions.can(Resource.roles, Action.create);
```

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note FAB permission fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A05: Fix StudentEntry falling through to `_OwnerFinanceShell` ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit refs:** STU-001, STF-001, GRD-003, OWN-016

**Specification:**

In `FinanceScreen.build()` (~L40-99), the switch on `entry` has a wildcard `_ =>` fallback that routes to `_OwnerFinanceShell`. This means `StudentEntry` (which is not matched by any explicit case) falls through to the admin finance shell, exposing all school financial data to students.

Fix the switch statement:

```dart
return switch (entry) {
  OwnerEntry() => _OwnerFinanceShell(
    schoolContext: schoolContext,
    termContext: termCtx,
  ),
  StaffEntry() =>
    (schoolContext.permissions.canAny(Resource.fees, [Action.read]) ||
            schoolContext.permissions.canAny(Resource.payments, [Action.read]))
        ? _OwnerFinanceShell(
            schoolContext: schoolContext,
            termContext: termCtx,
          )
        : const EduEmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No finance access',
            subtitle: 'You don\'t have permission to view financial data.',
          ),
  TeacherEntry() =>
    (schoolContext.permissions.canAny(Resource.fees, [Action.read]) ||
            schoolContext.permissions.canAny(Resource.payments, [Action.read]))
        ? _OwnerFinanceShell(
            schoolContext: schoolContext,
            termContext: termCtx,
          )
        : const EduEmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No finance access',
            subtitle: 'You don\'t have permission to view financial data.',
          ),
  GuardianEntry(:final ward) => _GuardianFinanceView(
    key: ValueKey('guardian_finance_${ward.adm}'),
    schoolContext: schoolContext,
    termContext: termCtx,
    studentAdm: ward.adm,
    studentName: ward.name,
  ),
  // ── NEW: Student gets a read-only finance view of their own invoices/payments
  StudentEntry() => _StudentFinanceView(
    schoolContext: schoolContext,
    termContext: termCtx,
  ),
};
```

Also create a minimal `_StudentFinanceView` widget (similar to `_GuardianFinanceView`) that:
- Reads the current student's `adm` from the entry: `(schoolContext.currentEntry.value as StudentEntry).student.adm`
- Shows the student's invoices and payment history (read-only)
- Does NOT show fees management, payment recording, or any admin controls
- If creating a full student finance view is too large for this task, a simpler approach is acceptable: render `_GuardianFinanceView` reusing the student's own ADM and name:
  ```dart
  StudentEntry(:final student) => _GuardianFinanceView(
    key: ValueKey('student_finance_${student.adm}'),
    schoolContext: schoolContext,
    termContext: termCtx,
    studentAdm: student.adm,
    studentName: student.name,
  ),
  ```

**Remove the `_ =>` wildcard entirely** so the compiler enforces exhaustiveness — if a new `MembershipEntry` subclass is added, it will be a compile error instead of a silent fallthrough.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note StudentEntry finance fix
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A06: Fix Guardian finance tab visibility — permission-gated but guardians have no roles ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit refs:** GRD-001, GRD-002

**Specification:**

In `_itemsForRole` (~L452-462), the `MembershipRole.guardian` case gates the Finance tab on `perms.canAny(Resource.fees, [Action.read]) || perms.canAny(Resource.payments, [Action.read])`. But guardians typically have no roles/scopes at all, so their aggregated permissions are empty and Finance never appears.

Guardians should **always** see Finance (their ward's invoices/payments) — it's a core guardian feature.

Fix:
```dart
MembershipRole.guardian => const [
  _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
  _NavItem(label: 'Progress', icon: Icons.bar_chart_outlined),
  _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
  _NavItem(label: 'Finance', icon: Icons.receipt_long_outlined),  // Always visible
  _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),
  _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
],
```

Remove the `if (perms.canAny(...))` guard around Finance for guardians. The `const` keyword can now be applied to the whole list since there are no conditional items.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note guardian Finance always visible
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A07: Add Attendance tab to teacher nav items ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit ref:** TCH-001

**Specification:**

In `_itemsForRole` (~L376-397), the `MembershipRole.teacher` case is missing the Attendance nav item entirely. Teachers need an Attendance tab — it's a core teacher feature (marking attendance for their classes).

Add after the Timetable item (which is one of the "Always visible (core 4)"):
```dart
MembershipRole.teacher => [
  // ── Always visible (core 5) ──────────────────────────────
  const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
  const _NavItem(label: 'My Classes', icon: Icons.class_outlined),
  const _NavItem(label: 'Exams', icon: Icons.assignment_outlined),
  const _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
  const _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),  // ← NEW

  // ── Permission-gated ──
  if (perms.canAny(Resource.classes, [Action.read]))
    const _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
  // ... rest unchanged
],
```

**Note:** Per BUG-017, attendance marking for non-assigned classes is already handled. The Attendance tab itself was just missing from the nav list.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note teacher Attendance tab added
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A08: Permission-gate teacher Exams tab and fix `_canMarkGrades` bypass ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`, `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit refs:** TCH-002, TCH-004

**Specification:**

Two related issues:

1. **Exams tab always visible for teachers** (`school_dashboard_screen.dart` ~L384): The Exams nav item is in the "Always visible (core 4)" section, but it should be permission-gated for teachers. A teacher without `exams.read` should not see the Exams tab.

   Move Exams from always-visible to permission-gated:
   ```dart
   MembershipRole.teacher => [
     // Always visible (core):
     const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
     const _NavItem(label: 'My Classes', icon: Icons.class_outlined),
     const _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
     const _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),

     // Permission-gated:
     if (perms.canAny(Resource.exams, [Action.read]))
       const _NavItem(label: 'Exams', icon: Icons.assignment_outlined),
     // ... rest
   ],
   ```

2. **`_canMarkGrades` returns true for all TeacherEntry** (`exams_grades_screen.dart` ~L1118-1121): Any teacher can mark grades regardless of permissions or subject assignment.

   Find the `_canMarkGrades` helper and change it to check permissions:
   ```dart
   // BEFORE:
   bool get _canMarkGrades => entry is TeacherEntry || entry is OwnerEntry;
   // AFTER:
   bool get _canMarkGrades {
     if (entry is OwnerEntry) return true;
     final perms = schoolContext.permissions;
     return perms.can(Resource.grades, Action.mark);
   }
   ```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note Exams tab gated, _canMarkGrades fixed
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A09: Stop using `entry is OwnerEntry` as blanket RBAC bypass ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`, `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart`, `lib/ui/screens/school_dashboard/finance/finance_screen.dart`, `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1-B

**Audit refs:** OWN-004, TCH-010, TCH-016

**Specification:**

Throughout the school dashboard sub-screens, `entry is OwnerEntry` is used as a blanket RBAC bypass — granting all permissions to owners regardless of their actual role/scope assignments. Per AGENT.md §17, an owner enters with a specific role context, and permissions should be enforced via `SchoolPermissions`, not entry type checks.

In practice, owners DO typically have full access. But the pattern is wrong because:
- It bypasses the roles system entirely
- Staff/Teachers with equivalent permissions don't get the same access
- It's a maintenance hazard

**For each file**, search for patterns like:
```dart
entry is OwnerEntry
entry.role == MembershipRole.owner
```

And replace with the appropriate permission check:

1. **`members_page.dart`**: Replace `entry is OwnerEntry` checks with `permissions.can(Resource.X, Action.Y)` for the specific action being guarded.

2. **`school_roles_screen.dart`**: Replace owner checks with `permissions.can(Resource.roles, Action.read/create/update/delete)`.

3. **`paper_detail_page.dart` ~L178-193**: `_canGradeContent` returns true for `OwnerEntry` and `StaffEntry` unconditionally. Change to:
   ```dart
   bool get _canGradeContent {
     final perms = widget.schoolContext.permissions;
     return perms.can(Resource.grades, Action.read) ||
            perms.can(Resource.grades, Action.mark);
   }
   ```

4. **`grade_detail_page.dart` ~L278-282**: `_can` helper bypasses RBAC for OwnerEntry. Change to use permission checks.

**Important:** Do NOT remove the `OwnerEntry` case from switch statements that dispatch to different UIs based on entry type (layout differences are fine). Only remove it from permission/authorization checks.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note OwnerEntry RBAC bypass removed
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track B: Data Scoping & Access Control

### Task B01: Scope teacher Academics to assigned classes/subjects only
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/academics_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-A

**Audit ref:** TCH-003

**Specification:**

`AcademicsScreen` (~L23-35) shows ALL grades/streams school-wide with no teacher scoping. When the current entry is a `TeacherEntry`, the screen should filter to only show grades/streams where the teacher is assigned (via `class_teachers` or `subject_teachers` tables).

1. In `AcademicsScreen.build()`, check the current entry:
   ```dart
   final entry = schoolContext.currentEntry.value;
   final teacherId = entry is TeacherEntry ? entry.teacher.user : null;
   ```

2. When `teacherId` is non-null, filter the grade/stream list to only those where the teacher has assignments. This requires querying `class_teachers` or `subject_teachers` for the current year/term and extracting the distinct `(grade, stream)` pairs.

3. Pass the `teacherId` filter down to whatever DAO/stream loads the grades/streams list so the query is scoped at the database level rather than filtering in Dart.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note teacher scoping in AcademicsScreen
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B02: Fix attendance permission inversion for teachers ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-A

**Audit refs:** TCH-005, TCH-006

**Specification:**

Two issues in `attendance_screen.dart`:

1. **~L57-62**: Teachers always see the attendance class picker without a permission check. Add a guard:
   ```dart
   TeacherEntry() => permissions.canAny(Resource.attendance, [Action.mark, Action.read])
       ? _ClassPickerShell(...)
       : const EduEmptyState(
           icon: Icons.fact_check_outlined,
           title: 'No attendance access',
           subtitle: 'You don\'t have permission to manage attendance.',
         ),
   ```

2. **~L247-249**: The permission logic is inverted — teachers WITH `attendance.mark` see ALL classes, while those WITHOUT only see assigned classes. It should be the opposite:
   - Teachers WITHOUT `attendance.mark` (read-only) may see all classes for viewing
   - Teachers WITH `attendance.mark` should be scoped to their assigned classes only (they can mark attendance for those)
   - Fix: swap the condition or restructure so that marking is gated to assigned classes and reading is broader.

   Per BUG-017 fix, `attendance.mark` WITH the permission SHOULD allow marking for non-assigned classes. Verify the current BUG-017 fix is preserved. The real fix here is: if teacher only has `attendance.read`, show all classes read-only. If teacher has `attendance.mark`, show assigned classes with mark capability + optionally other classes read-only.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note attendance permission fix
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B03: Scope teacher exam creation/editing to assigned grades/subjects ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-A

**Audit refs:** TCH-007, TCH-008

**Specification:**

1. **~L534-537 (exam creation)**: A teacher with `exams.create` can create exams for ANY grade/subject. Scope the grade/subject picker to only show grades/subjects the teacher is assigned to via `subject_teachers` for the current year/term.

2. **~L1106-1121 (exam edit/delete)**: A teacher with `exams.update`/`exams.delete` can edit/delete ANY exam, including other teachers' exams. Add a guard:
   - If `entry is TeacherEntry`, only allow edit/delete on exams where `exam.teacher == entry.teacher.user`
   - Owners and staff with proper permissions can edit/delete any exam

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — note teacher scoping for exams
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B04: Permission-gate teacher Timetable tab
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-A

**Audit refs:** TCH-009, TCH-011

**Specification:**

1. **~L387**: Timetable is currently in the "Always visible (core 4)" for teachers. This is actually correct — teachers should always see their own timetable. **Do NOT remove it.**

2. **However**, `timetable_screen.dart` ~L174-184 (TCH-011): Teachers with `classes.create`/`update`/`delete` permissions see the full Owner timetable management UI (rules configuration, generation CTA, etc.). The timetable screen should distinguish:
   - **Teacher view**: Read-only weekly schedule showing their personal timetable across assigned classes
   - **Admin view** (owner, or staff/teacher with `classes.update`): Full management UI with rules config and generation

   In `timetable_screen.dart`, ensure the management UI sections are gated:
   ```dart
   final isAdmin = entry is OwnerEntry ||
       schoolContext.permissions.can(Resource.classes, Action.update);
   // Show management controls only when isAdmin is true
   ```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note timetable admin/teacher view split
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B05: Fix teacher announcements — full admin feed shown to teachers with mutation perms
**Files to create/modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-A

**Audit ref:** TCH-012

**Specification:**

In `announcements_screen.dart` ~L67-76, teachers with any announcement mutation permission (create/update/delete) get the full Admin feed with edit/delete on ALL announcements. A teacher should only be able to edit/delete their own announcements.

Fix:
- When `entry is TeacherEntry`, the edit/delete actions on each announcement row should check `announcement.author == currentUserId`
- Only owners (or users with explicit permission) should see edit/delete on all announcements
- The create FAB is fine — it's gated by `announcements.create` permission

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note announcement author-scoping for teachers
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B06: Permission-gate staff finance tabs individually
**Files to create/modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task A05
**Parallel group:** P2-B

**Audit refs:** STF-002, STF-003, STF-011, TCH-015

**Specification:**

`_OwnerFinanceShell` (~L140-246) shows all 4 finance tabs (Overview, Invoices, Payments, Fees) regardless of staff/teacher permissions. It also exposes all financial metrics in the overview without per-resource checks.

Fix:

1. **Tab visibility** — Make `_OwnerFinanceShell` accept the `SchoolContext` (it already does) and filter visible tabs:
   ```dart
   final perms = widget.schoolContext.permissions;
   final entry = widget.schoolContext.currentEntry.value;
   final isOwner = entry is OwnerEntry;

   final tabs = <_FinanceTab>[];
   // Overview visible if any finance permission
   if (isOwner || perms.canAny(Resource.fees, [Action.read]) || perms.canAny(Resource.payments, [Action.read]))
     tabs.add(_FinanceTab.overview);
   if (isOwner || perms.can(Resource.fees, Action.read))
     tabs.add(_FinanceTab.invoices);
   if (isOwner || perms.can(Resource.payments, Action.read))
     tabs.add(_FinanceTab.payments);
   if (isOwner || perms.can(Resource.fees, Action.read))
     tabs.add(_FinanceTab.fees);
   ```

2. **Tab controller** — Use `tabs.length` instead of hardcoded `4` for the TabController length (~L165-168).

3. **Overview metrics** — In `_OverviewTab`, gate individual metric cards by the relevant permission (fees vs payments).

4. **Write actions** — Ensure record-payment, create-fee, edit/delete actions within each tab are gated by `fees.create`/`payments.create`/etc. rather than just being visible to anyone who can see the tab.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note staff finance permission gating
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B07: Filter announcements by grade/stream for students and guardians
**Files to create/modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`, `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-B

**Audit refs:** STU-002, GRD-008

**Specification:**

1. **`announcements_screen.dart`**: When the entry is `StudentEntry` or `GuardianEntry`, announcements should be filtered to only show those targeting the student's grade/stream (or school-wide announcements with no grade/stream filter).

   The `announcements` table has `grade` and `stream` columns. When building the query for student/guardian views:
   ```dart
   // Filter: announcement.grade IS NULL (school-wide) OR announcement.grade == student's grade
   // AND: announcement.stream IS NULL OR announcement.stream == student's stream
   ```

   For `GuardianEntry`, use `ward.grade` and `ward.stream` (if those fields exist on `StudentsData` — they may be derived from `enrollments`).

2. **`overview_screen.dart` ~L3135-3175 (student) and ~L2142-2147 (guardian)**: The overview announcement snippets should apply the same grade/stream filter.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note announcement grade/stream filtering
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task B08: Fix `_canGradeContent` — StaffEntry/OwnerEntry RBAC bypass for grade access ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task A09
**Parallel group:** P2-B

**Audit refs:** TCH-010, TCH-016

**Specification:**

Partially covered by A09 but specifically for grade/paper detail pages:

1. **`paper_detail_page.dart` ~L178-193**: `_canGradeContent` returns `true` for all `StaffEntry` regardless of permissions. Fix:
   ```dart
   bool get _canGradeContent {
     return widget.schoolContext.permissions.can(Resource.grades, Action.read) ||
            widget.schoolContext.permissions.can(Resource.grades, Action.mark);
   }
   ```

2. **`grade_detail_page.dart` ~L278-282**: `_can` helper bypasses RBAC for `OwnerEntry`. Fix the same way — use permissions, not entry type.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note grade access RBAC fix
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

**Resolution:** Already fully fixed by Task A09. Verified: `_canGradeContent` in `paper_detail_page.dart` uses only `perms.can(Resource.grades, Action.read) || perms.can(Resource.grades, Action.mark)`. `_can()` in `grade_detail_page.dart` delegates directly to `widget.schoolContext.permissions.can(resource, action)`. Zero `StaffEntry`/`OwnerEntry` type checks remain in either file.

---

## Track C: Navigation & Routing Fixes

### Task C01: Fix logout not navigating away from System Dashboard ✅
**Files to create/modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-C

**Audit ref:** SYS-007

**Specification:**

In `system_dashboard_screen.dart` ~L968-991 (the logout handler in `_handleAction`): After logout, the user stays on the System Dashboard with null state instead of being navigated to the login/home screen.

Fix: After the logout call completes, navigate to the root route:
```dart
case _UserMenuAction.logout:
  await client.logout();
  if (mounted) {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    // Or use whatever the app's root navigation pattern is — check main.dart
    // for the route setup. The key is to pop ALL routes and return to login.
  }
```

Verify the app's navigation pattern by checking `main.dart` or the router setup. The important thing is that ALL routes are cleared and the user returns to the initial screen (login or home).

**Update after completion:**
- [x] Update `lib/ui/screens/system/CONTEXT.md` — note logout navigation fix
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task C02: Remove term-gating for non-academic sections (Finance, Announcements)
**Files to create/modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`, `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`, `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-C

**Audit refs:** STU-003, STU-006, OWN-011

**Specification:**

1. **`announcements_screen.dart` ~L39-42**: Announcements are blocked when no terms exist. Announcements are not academic content — they should be visible regardless of term state. Remove the `termCtx.currentTerm == null` early return.

2. **`finance_screen.dart`**: Finance shows "No Term" blank state, but finance is also non-academic. The term context is used for scoping invoices/fees to a term, which is valid — but showing a blank state is wrong. If no term exists, either:
   - Show all-time financial data (no term filter)
   - Or show a message like "Select a term to view financial data" but still allow creating fees/invoices

3. **`school_dashboard_screen.dart` ~L591-600 (`_kAcademicNavLabels`)**: Verify that 'Finance' and 'Announcements' are NOT in this set. Currently the `_isAcademicSection` check blocks these sections when no terms exist. If they ARE in the set, remove them.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note term-gating removed for non-academic
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task C03: Fix owner Attendance routing — show admin overview, not teacher-style class picker ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-C

**Audit refs:** OWN-019, OWN-030

**Specification:**

In `attendance_screen.dart`, `OwnerEntry` is routed to `_ClassPickerShell` — the same teacher-style marking UI. Owners should see an admin-oriented attendance overview:
- Summary stats (attendance rate by grade/stream)
- Ability to view any class's attendance (not just assigned classes)
- The class picker is acceptable as a navigation mechanism, but the UX messaging should be admin-oriented (e.g., "Select a class to view attendance") not teacher-oriented (e.g., "Mark attendance for your classes")

For now, the simplest fix: ensure the `_ClassPickerShell` when rendered for an owner:
1. Shows ALL classes (not just assigned ones)
2. Uses admin-appropriate language
3. Shows both read and mark capabilities

A more thorough redesign (admin attendance dashboard) can be a future task.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note owner attendance UX improvement
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task C04: Fix Attendance → GradeDetailPage tab leak ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 2)
**Parallel group:** P2-C

**Audit ref:** STF-008

**Specification:**

In `attendance_screen.dart` ~L351-381, navigating from Attendance into `GradeDetailPage` exposes other tabs (Students, Exams, Subjects) that the user may not have permission to see.

When launching `GradeDetailPage` from the attendance context, either:
1. Pass a parameter to restrict visible tabs to only the Attendance tab
2. Or create a dedicated `AttendanceDetailPage` that only shows the attendance content

The simplest approach is to add an optional `restrictToTab` parameter to `GradeDetailPage`:
```dart
class GradeDetailPage extends StatelessWidget {
  final String? restrictToTab; // If set, only show this tab
  // ...
}
```

When launched from Attendance, pass `restrictToTab: 'Attendance'`.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note attendance tab leak fix
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task C05: Fix "View All" dead links on guardian/student overview
**Files to create/modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task A06
**Parallel group:** P2-C

**Audit refs:** GRD-002, GRD-012, OWN-014

**Specification:**

1. **Guardian overview ~L2122-2128**: "View All" for Finance is a dead link because Finance tab was never visible (fixed in A06). After A06, this link should navigate to the Finance tab. Wire it to `DashboardNavigation.of(context)?.goToTab('Finance')`.

2. **Student/Guardian overview**: Missing "View All" links for various sections. Add navigation links that call `DashboardNavigation.of(context)?.goToTab(label)` for each section that has a corresponding nav tab.

3. **Owner overview ~L81-130**: Missing "View All" navigation links. Add the same pattern.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note "View All" links wired
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track D: Reactivity & State Management

### Task D01: Make permissions reactive via Drift watch stream
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`, `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-A

**Audit refs:** SYS-010, OWN-005

**Specification:**

Both dashboards load permissions once in `initState` and never update them when sync deltas modify roles/scopes.

1. **`school_dashboard_screen.dart` ~L125-195**: `_initializeSession` loads permissions once. Convert to a reactive stream:
   - Create a Drift-based `watchPermissions(schoolId, userId)` method (either in `SchoolScopesDao` or inline) that watches `scopes` + `roles` tables and re-computes the aggregated `Permissions` on any change.
   - Subscribe to this stream in `initState` and update `_schoolContext.permissions` on each emission.
   - Since `SchoolContext.permissions` is currently `final`, either:
     a. Make it a `ValueNotifier<SchoolPermissions>` and rebuild dependent widgets via `ValueListenableBuilder`
     b. Or tear down and recreate `SchoolContext` on permission changes (simpler but more disruptive)
   - Option (a) is preferred for performance.

2. **`system_dashboard_screen.dart` ~L137-157**: `_loadPermissions` loads once. Same pattern — subscribe to a watch stream on `scopes` + `roles` and update `_permissions` state on changes.

**Note:** This is a significant architectural change. The minimum viable fix is to re-call the load function when the app returns to foreground (via `WidgetsBindingObserver.didChangeAppLifecycleState`). The full reactive stream approach is ideal but more complex.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note reactive permissions
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note reactive permissions
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task D02: Fix non-reactive entry reads in AnnouncementsScreen
**Files to create/modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-A

**Audit refs:** OWN-009, GRD-004

**Specification:**

`AnnouncementsScreen` (~L31-88) reads `currentEntry.value` directly instead of using `ValueListenableBuilder`. This means when the user switches roles via the role switcher, the announcements screen doesn't rebuild.

Fix: Wrap the entry-dependent parts in a `ValueListenableBuilder<MembershipEntry>`:
```dart
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<MembershipEntry>(
    valueListenable: schoolContext.currentEntry,
    builder: (context, entry, _) {
      // ... existing build logic using `entry` instead of `schoolContext.currentEntry.value`
    },
  );
}
```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note announcements reactivity fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task D03: Fix non-reactive entry reads in TimetableScreen
**Files to create/modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-A

**Audit refs:** STU-008, GRD-005

**Specification:**

`TimetableScreen` ~L164 reads `schoolContext.currentEntry.value` directly instead of using `ValueListenableBuilder`. Same fix as D02:

Wrap entry-dependent logic in `ValueListenableBuilder<MembershipEntry>`.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note timetable reactivity fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task D04: Fix `_AttendanceTab` not resetting on ward switch
**Files to create/modify:** `lib/ui/screens/school_dashboard/progress/progress_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/progress/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-A

**Audit ref:** GRD-006

**Specification:**

In `progress_screen.dart` ~L1530-1556, `_AttendanceTab` doesn't reset the calendar month when the guardian switches wards. When `didUpdateWidget` is called (or when the ward changes via `ValueListenableBuilder`), the selected month should reset to the current month.

Fix: Add a `didUpdateWidget` or key the widget on the ward's ADM so it fully rebuilds:
```dart
// Option 1: Key on ward ADM
_AttendanceTab(
  key: ValueKey('attendance_${ward.adm}'),
  // ...
)

// Option 2: In didUpdateWidget, reset state
@override
void didUpdateWidget(covariant _AttendanceTab oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.studentAdm != widget.studentAdm) {
    setState(() {
      _selectedMonth = DateTime.now();
      // re-fetch attendance data
    });
  }
}
```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/progress/CONTEXT.md` — note ward switch calendar fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task D05: Fix N+1 queries in `_batchLoadUsers` and DAO creation in `build()`
**Files to create/modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`, `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-A

**Audit refs:** OWN-007, OWN-006

**Specification:**

1. **`members_page.dart` ~L967-1030 (`_batchLoadUsers`)**: Performs N+1 queries by loading users one-by-one in a loop. Replace with a single batch query:
   ```dart
   // BEFORE: for each member, query user individually
   // AFTER: collect all user IDs, then:
   final userIds = members.map((m) => m.user).toSet().toList();
   final users = await (db.select(db.users)
     ..where((t) => t.id.isIn(userIds))
   ).get();
   final userMap = {for (final u in users) u.id: u};
   ```

2. **`overview_screen.dart` ~L132-219 (`_OwnerQuickStats`)**: Creates DAO instances in `build()` and fetches all rows for count. Fix:
   - Move DAO instances to `initState` or class-level final fields
   - Use count queries instead of fetching all rows:
     ```dart
     // Instead of: final students = await dao.getAllStudents(schoolId); return students.length;
     // Use: final count = await (selectOnly(db.students)..addColumns([countAll()]))...
     ```
   - Or use the existing DAO count methods if available

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note N+1 and build-DAO fixes
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track E: Defense-in-Depth Guards

### Task E01: Add permission guard to SchoolSettingsScreen
**Files to create/modify:** `lib/ui/screens/school_dashboard/settings/school_settings_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/settings/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-B

**Audit refs:** OWN-008, STF-007, STF-013

**Specification:**

`SchoolSettingsScreen` has no permission check at all. Any user who somehow reaches this screen can view/edit school settings.

Add a defense-in-depth guard at the top of the `build()` method:
```dart
@override
Widget build(BuildContext context) {
  final perms = widget.schoolContext.permissions;
  final entry = widget.schoolContext.currentEntry.value;

  // Defense-in-depth: nav routing should prevent unauthorized access,
  // but guard here as well.
  if (entry is! OwnerEntry && !perms.can(Resource.schools, Action.update)) {
    return const EduEmptyState(
      icon: Icons.lock_outline,
      title: 'Access restricted',
      subtitle: 'You don\'t have permission to view school settings.',
    );
  }
  // ... existing build logic
}
```

Also make the settings data reactive to sync changes (OWN-024): if the screen currently reads school data once, convert to a `StreamBuilder` watching the school row.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/settings/CONTEXT.md` — note permission guard added
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E02: Add permission guards to AcademicsScreen and ExamsGradesScreen for staff
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/academics_screen.dart`, `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-B

**Audit refs:** STF-005, STF-006, STF-015

**Specification:**

1. **`academics_screen.dart` ~L26-32**: No entry-type or permission guard. Add:
   ```dart
   final entry = schoolContext.currentEntry.value;
   if (entry is StudentEntry || entry is GuardianEntry) {
     return const EduEmptyState(
       icon: Icons.lock_outline,
       title: 'Access restricted',
       subtitle: 'This section is for school administrators.',
     );
   }
   ```

2. **`exams_grades_screen.dart` ~L52-68**: Already has a student/guardian guard but lacks staff-specific permission checking. For `StaffEntry`, verify the user has `exams.read` permission before rendering the shell. The existing guard at L57-60 is good — extend it:
   ```dart
   if (entry is StaffEntry && !schoolContext.permissions.can(Resource.exams, Action.read)) {
     return const EduEmptyState(
       icon: Icons.lock_outline,
       title: 'No exam access',
       subtitle: 'You don\'t have permission to view exams.',
     );
   }
   ```

3. Within `_ExamsShell`, gate write actions (create/edit/delete) for staff by checking `exams.create`, `exams.update`, `exams.delete` respectively.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note defense-in-depth guards
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E03: Add confirmation dialogs for destructive system actions
**Files to create/modify:** `lib/ui/screens/system/schools/schools_section.dart`, `lib/ui/screens/system/plans/plans_section.dart`, `lib/ui/screens/system/users/user_detail_sheet.dart`, `lib/ui/screens/system/roles/roles_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-B

**Audit refs:** SYS-008, SYS-009, SYS-012, SYS-018

**Specification:**

1. **`schools_section.dart` ~L93-125 (`_trashSchool`)** — SYS-009: The confirmation dialog is not marked `isDestructive: true`. Add it:
   ```dart
   final confirmed = await showEduConfirmDialog(
     context: context,
     title: 'Delete School',
     message: 'Are you sure you want to delete "${school.name}"?',
     isDestructive: true,  // ← ADD THIS
   );
   ```

2. **`plans_section.dart` ~L217-237 (`_deletePlan`)** — SYS-018: No confirmation dialog and no success snackbar. Add both:
   ```dart
   final confirmed = await showEduConfirmDialog(
     context: context,
     title: 'Delete Plan',
     message: 'Are you sure you want to delete "${plan.name}"?',
     isDestructive: true,
   );
   if (confirmed != true) return;
   await plansDao.deletePlan(plan.id, accountId: accountId);
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Plan deleted')),
     );
   }
   ```

3. **`user_detail_sheet.dart` ~L229-240 (`_updateLevel`, `_updateStatus`)** — SYS-012: No confirmation dialogs for level/status changes. Add confirmation dialogs before both operations:
   ```dart
   final confirmed = await showEduConfirmDialog(
     context: context,
     title: 'Change User Level',
     message: 'Change level to ${newLevel.name}?',
   );
   if (confirmed != true) return;
   ```

4. **`roles_section.dart` ~L243-254 (role delete vs purge)** — SYS-008: Both call `deleteRole` (hard DELETE). Distinguish:
   - "Delete" should be a soft-delete (if the schema supports it) or the standard delete action
   - "Purge" should only be available to Super users and should use a more explicit confirmation
   - If the schema has no soft-delete for roles, document that both are hard deletes but add a confirmation dialog with clear messaging

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note destructive action confirmations
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E04: Gate system Subjects sub-tab and CreateSubjectSheet by permission
**Files to create/modify:** `lib/ui/screens/system/settings/subjects_section.dart`, `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-B

**Audit refs:** SYS-026, SYS-027

**Specification:**

1. **`subjects_section.dart`** — SYS-026: No Read permission check. Add at the top of `build()`:
   ```dart
   if (!permissions.can(Resource.subjects, Action.read)) {
     return const EduEmptyState(
       icon: Icons.lock_outline,
       title: 'Access restricted',
       subtitle: 'You don\'t have permission to view subjects.',
     );
   }
   ```
   The widget needs to receive `permissions` (either `SystemPermissions` or extract from parent).

2. **`system_dashboard_screen.dart` ~L670-678** — SYS-027: `CreateSubjectSheet` doesn't receive the permissions object. Pass it:
   ```dart
   _showCreateSubject() {
     showEduSheet(
       context: context,
       builder: (_) => CreateSubjectSheet(permissions: _permissions),  // ← pass permissions
     );
   }
   ```
   Then in `CreateSubjectSheet`, use the permissions to gate create/update actions.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note subjects permission gating
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E05: Gate system members status-change actions by permission
**Files to create/modify:** `lib/ui/screens/system/members/members_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 3)
**Parallel group:** P3-B

**Audit ref:** SYS-019

**Specification:**

In `members_section.dart` ~L244-430, status-change actions (activate, suspend, delete) on members are not gated by `Users.Update` permission. Only UI layout determines visibility.

Add permission checks before each status-change action:
```dart
if (!permissions.can(Resource.users, Action.update)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('You don\'t have permission to change user status')),
  );
  return;
}
```

Also hide the action buttons in the UI when the permission is not present:
```dart
if (permissions.can(Resource.users, Action.update)) ...[
  // status change action buttons
],
```

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note member status-change gating
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E06: Fix permission loading — use DAOs instead of raw DB queries
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** Task A01
**Parallel group:** P3-B

**Audit ref:** TCH-013

**Specification:**

In `_initializeSession` (~L125-191), permissions are loaded using raw `db.select(db.scopes)` and `db.select(db.roles)` queries instead of going through DAOs.

Refactor to use `SchoolScopesDao`:
```dart
// BEFORE:
final scopesRows = await (db.select(db.scopes)
  ..where((t) => t.school.equals(schoolId) & t.user.equals(user.id))
).get();
// ...raw role loading...

// AFTER:
final scopesDao = SchoolScopesDao(db);
final permissions = await scopesDao.getAggregatedPermissions(schoolId, user.id);
```

This may require adding a `getAggregatedPermissions` method to `SchoolScopesDao` that encapsulates the scope loading + role parsing + system scope merging logic. The method should:
1. Load school-scoped scopes for `(schoolId, userId)`
2. Load system-scoped scopes for `userId` (where `school IS NULL`) if user is system/super
3. Parse all role permissions and union them
4. Return a `SchoolPermissions` object

This centralizes the permission computation logic and makes it reusable for the reactive watch stream (Task D01).

**Update after completion:**
- [ ] Update `lib/database/daos/CONTEXT.md` — note getAggregatedPermissions method
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note DAO-based permission loading
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track F: UI Polish & UX

### Task F01: Add retry/delete buttons to NotificationsSection for failed sync logs
**Files to create/modify:** `lib/ui/screens/system/notifications/notifications_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** SYS-016

**Specification:**

`NotificationsSection` shows failed sync logs but has no retry or delete buttons. Per AGENT.md §7, failed logs are shown in the notifications UI.

Add per-row action buttons:
1. **Retry** button: Resets `status` back to `LogStatus.pending` and `attempts` to `0`, then calls `sync.schedulePush()`.
2. **Delete** button (with confirmation): Permanently deletes the log row.

Use `IconButton` (28×28) per UI guidelines:
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.refresh, size: 18),
      iconSize: 28,
      tooltip: 'Retry',
      onPressed: () => _retryLog(log),
    ),
    IconButton(
      icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
      iconSize: 28,
      tooltip: 'Delete',
      onPressed: () => _deleteLog(log),
    ),
  ],
)
```

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note notifications retry/delete buttons
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F02: Fix system stats resilience — isolate query failures
**Files to create/modify:** `lib/ui/screens/system/home/system_stats_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** SYS-020

**Specification:**

In `system_stats_section.dart` ~L35-108, a single failed query hides all other working stats. Each stat should be loaded independently so one failure doesn't affect others.

Refactor from a single `FutureBuilder` over all stats to individual `FutureBuilder` widgets per stat card:
```dart
// Each stat card independently loads and handles errors:
_StatCard(
  future: systemStatsDao.getUserCount(),
  label: 'Users',
  icon: Icons.people_outline,
),
_StatCard(
  future: systemStatsDao.getSchoolCount(),
  label: 'Schools',
  icon: Icons.school_outlined,
),
// etc.
```

Each `_StatCard` shows a loading indicator while pending, the value on success, and an error icon with tooltip on failure.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note stats resilience fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F03: Fix `_RoleFeed` using `SchoolConfig.defaults()` instead of actual school config
**Files to create/modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** STU-004

**Specification:**

In `announcements_screen.dart` ~L340, `_RoleFeed` uses `SchoolConfig.defaults()` (empty config) for grade/stream labels instead of the actual school's config.

Fix: Load the actual `SchoolConfig` from the school's settings or derive it from the school's curriculum/streams data. The `SchoolConfig` is typically available from `SettingsDao` or can be constructed from the school's `curriculum` field:
```dart
final schoolConfig = SchoolConfig.fromSchool(schoolContext.membership.school);
```

Pass the real config to `_RoleFeed` instead of `SchoolConfig.defaults()`.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note SchoolConfig fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F04: Fix `currentTerm` null safety when `hasTerms` is true
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** OWN-012

**Specification:**

In `school_dashboard_screen.dart` ~L605-629, `currentTerm` can be null even when `hasTerms` is true (terms exist but none is marked active and the most recent term query returns null).

Fix: In the content area builder, when `hasTerms` is true but `currentTerm` is null:
1. Auto-select the most recent term (by `start` date descending) as a fallback
2. Or show a "Select a term" prompt instead of the blank state

In `ActiveTermContext`, ensure that if `initialTerm` is null but `allTerms` is non-empty, a term is automatically selected:
```dart
ActiveTermContext({
  required this.schoolId,
  required List<Term> allTerms,
  required Term? initialTerm,
}) {
  _allTerms = allTerms;
  _currentTerm = initialTerm ?? (allTerms.isNotEmpty ? allTerms.first : null);
}
```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note term null-safety fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F05: Fix UI guideline violations (font weight, border radius)
**Files to create/modify:** `lib/ui/widgets/no_terms_blank_state.dart`, `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `lib/ui/widgets/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit refs:** OWN-021, OWN-022

**Specification:**

1. **`no_terms_blank_state.dart`** — OWN-021: Headline uses `FontWeight.w600`. Per UI guidelines §21, headings should use `w500` max. Change to `FontWeight.w500`.

2. **`finance_screen.dart`** — OWN-022: Fees tab FAB uses `borderRadius: 12` instead of `AppTheme.kCardRadius` (8). Change to `BorderRadius.circular(AppTheme.kCardRadius)`.

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md` — note typography fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F06: Fix `NoTermsBlankState` messaging for students and guardians
**Files to create/modify:** `lib/ui/widgets/no_terms_blank_state.dart`
**Context files to read (if needed):** `lib/ui/widgets/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit refs:** STU-007

**Specification:**

`NoTermsBlankState` shows admin-oriented messaging ("Create a term to get started") to all users including students. Customize the message based on role:

```dart
class NoTermsBlankState extends StatelessWidget {
  final MembershipRole role;
  // ...

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == MembershipRole.owner ||
        (canCreateTerm ?? false);

    return EduEmptyState(
      icon: Icons.calendar_today_outlined,
      title: isAdmin ? 'No terms yet' : 'No active term',
      subtitle: isAdmin
          ? 'Create a term to get started with academics.'
          : 'Your school hasn\'t set up a term yet. Please check back later.',
      // Only show the "Create Term" CTA for admins
    );
  }
}
```

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md` — note role-aware blank state messaging
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F07: Fix `_GuardianPaymentSheet` missing payment date
**Files to create/modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** GRD-010

**Specification:**

In `_GuardianPaymentSheet` (~L2413-2450), the payment creation doesn't pass the payment date. The `_save` method should include the current date (or a date picker) when creating the payment record:

```dart
// In _save(), when building the payment companion:
PaymentsCompanion(
  // ... existing fields
  date: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000)),
  // ... or use a date picker value if one is added to the form
)
```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note guardian payment date fix
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F08: Fix finance validation — zero/negative amounts
**Files to create/modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** OWN-027

**Specification:**

`_CreateFeeSheet` allows zero or negative amounts for fee creation. Add a validator to the amount field:

```dart
TextFormField(
  controller: _amountCtrl,
  validator: (value) {
    if (value == null || value.isEmpty) return 'Amount is required';
    final amount = double.tryParse(value);
    if (amount == null) return 'Enter a valid number';
    if (amount <= 0) return 'Amount must be greater than zero';
    return null;
  },
  // ...
)
```

Apply the same validation to `_RecordPaymentSheet` and `_GuardianPaymentSheet` amount fields.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note finance validation
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F09: Fix guardian/student overview `_RecentExamResults` — show exam names
**Files to create/modify:** `lib/ui/screens/school_dashboard/progress/progress_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/progress/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** GRD-007

**Specification:**

In `progress_screen.dart` ~L720-822, `_RecentExamResults` in the Progress overview doesn't display exam names, making it hard for guardians to understand which exam a result belongs to.

Fix: When building each result row, join with the `exams` table to get the exam name and display it:
```dart
// Each result tile should show:
// - Exam name (from exams table)
// - Subject name
// - Score / Total
// - Date
```

If the data model already includes the exam name, just ensure it's displayed in the tile widget. If not, modify the DAO query to join with exams.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/progress/CONTEXT.md` — note exam names in results
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F10: Fix home screen guardian card — show ward info
**Files to create/modify:** `lib/ui/screens/home/home_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit ref:** GRD-011

**Specification:**

In `home_screen.dart` ~L855-944, guardian membership cards show no ward info. Per AGENT.md §17, `GuardianEntry` has a `ward` field (`StudentsData`) with the child's name and ADM.

For each `GuardianEntry` in the membership card:
```dart
// In the guardian badge/subtitle area:
Text(
  'Guardian of ${entry.ward.name}',
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: cs.onSurfaceVariant,
  ),
)
```

If the ward has a cached image at `{appDir}/schools/{schoolId}/students/{adm}/image`, show a small avatar.

**Update after completion:**
- [ ] Update `lib/ui/screens/CONTEXT.md` — note guardian card ward info
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F11: Filter deleted records from default lists for non-Super system users
**Files to create/modify:** `lib/ui/screens/system/schools/schools_section.dart`, `lib/ui/screens/system/users/users_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit refs:** SYS-024, SYS-025

**Specification:**

Per AGENT.md §17a: "Only Super users see deleted records." Currently deleted schools and users appear in the default unfiltered list for System users.

1. **`schools_section.dart` ~L263-356**: When `permissions.canSeeDeleted` is false, filter out `SchoolStatus.deleted` from the query or list. Add a filter either at the DAO level (preferred) or in the UI:
   ```dart
   // If filtering in UI:
   final visibleSchools = permissions.canSeeDeleted
       ? allSchools
       : allSchools.where((s) => s.status != SchoolStatus.deleted).toList();
   ```

2. **`users_section.dart` ~L296-517**: Same pattern for users — filter out `UserStatus.deleted` when `permissions.canSeeDeleted` is false.

Optionally, add a "Show deleted" toggle visible only to Super users.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note deleted record filtering
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task F12: Clean up dead code and minor inconsistencies
**Files to create/modify:** `lib/ui/screens/system/system_dashboard_screen.dart`, `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`, `lib/ui/screens/school_dashboard/my_classes/my_classes_screen.dart`, `lib/ui/screens/school_dashboard/overview/overview_screen.dart`, `lib/database/daos/exams_grades_dao.dart`, `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`, `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None (Phase 4)
**Parallel group:** P4

**Audit refs:** SYS-011, SYS-013, SYS-017, SYS-021, TCH-017, TCH-018, TCH-019, TCH-021, OWN-023, OWN-025

**Specification:**

A collection of minor fixes that can be done in one pass:

1. **SYS-021**: `_FabAction.createPlan` is dead code in the expandable FAB (~L867). Remove it or wire it up.

2. **SYS-017**: Tab index constants `_kDesktopTabUsers`, `_kDesktopTabMembers`, etc. (~L32-42) are partially unused/misleading. Clean up unused constants.

3. **SYS-011**: `_desktopTabController` has no listener (asymmetry with mobile tab controller). Add a listener if desktop tab changes need to trigger state updates, or document why it's not needed.

4. **SYS-013**: `accountsDao.logProfileImageChange` is a no-op placeholder (~L116-120). Either implement it (log a `SyncAction.updateUser` entry) or remove the call and add a TODO.

5. **TCH-017**: "Exams & Grades" dead code check in `_buildContentPanel` (~L676-677). The check `item.label == 'Exams & Grades' || item.label == 'Exams'` has the first branch as dead code since the nav item label is just "Exams". Remove the dead branch.

6. **TCH-018**: `my_classes_screen.dart` ~L151 uses empty string for userId when entry is not `TeacherEntry`. Use `''` with a comment or throw an assertion:
   ```dart
   final teacherId = entry is TeacherEntry ? entry.teacher.user : '';
   assert(entry is TeacherEntry, 'My Classes should only be shown to teachers');
   ```

7. **TCH-019**: `overview_screen.dart` ~L253 uses `cache.currentUser` instead of `entry.teacher.user`. Fix to use the entry-specific user ID.

8. **TCH-021**: `exams_grades_dao.dart` ~L1462-1600 `watchExamGroups` with `teacherId` loads ALL exams then filters in Dart. Move the filter to the SQL query for efficiency:
   ```dart
   ..where((t) => t.teacher.equals(teacherId))
   ```

9. **OWN-023**: Department creation in `members_page.dart` has no duplicate name check. Add validation:
   ```dart
   final existing = await departmentsDao.getDepartment(schoolId, name);
   if (existing != null) {
     // Show error: "A department with this name already exists"
     return;
   }
   ```

10. **OWN-025**: Role form uses `ObjectId` for IDs instead of UUID pattern. If the project uses UUIDs elsewhere, standardize. This is low-priority and may not need changing if ObjectId works with the sync engine.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note dead code cleanup
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note minor fixes
- [ ] Update `lib/database/daos/CONTEXT.md` — note exam query optimization
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Summary

| Track | Tasks | Priority | Parallel Groups |
|---|---|---|---|
| **A: Critical Security** | A01–A09 | 🔴 Critical/High | P1-A (A01→A02 sequential), P1-B (A03–A09 parallel) |
| **B: Data Scoping** | B01–B08 | 🟠 High | P2-A (B01–B05 parallel), P2-B (B06–B08 parallel, after A05) |
| **C: Navigation & Routing** | C01–C05 | 🟠 High/Medium | P2-C (all parallel, C05 after A06) |
| **D: Reactivity & State** | D01–D05 | 🟡 Medium | P3-A (all parallel) |
| **E: Defense-in-Depth** | E01–E06 | 🟡 Medium | P3-B (all parallel, E06 after A01) |
| **F: UI Polish & UX** | F01–F12 | 🟢 Low | P4 (all parallel) |
| **Total** | **43 tasks** | | |

### Dependency Graph

```
A01 ──► A02
A01 ──► E06
A05 ──► B06
A06 ──► C05

All Phase 1 ──► Phase 2 (B + C tracks)
All Phase 2 ──► Phase 3 (D + E tracks)
All Phase 3 ──► Phase 4 (F track)
```

Note: Phase dependencies are soft — tasks within a phase can start as soon as their specific hard dependencies are met. The phase ordering is a recommended flow, not a strict gate.