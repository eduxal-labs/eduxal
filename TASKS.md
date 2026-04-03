# TASKS.md — MVP Audit: Comprehensive Fix List

> Generated from 6 parallel persona audits (System User, School Owner, Teacher, Staff, Student, Guardian).
> **116 issues** identified, deduplicated and organized into 9 tracks with dependency annotations.
> Each task is self-sufficient for the executor agent per AGENT.md §0d.

---

## Track A: CRITICAL — Permission & Security Foundations

These are the highest-priority issues. Most other tracks depend on the permission system working correctly.

---

### Task A1: System users are granted superUser() permissions — bypasses all RBAC ✅

**Files to modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read:** `lib/models/system_permissions.dart`, `lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** PA1

**Specification:**
In `_loadPermissions()` (~L143–161), the code currently does:
```dart
if (level == UserLevel.system || level == UserLevel.super_) {
  _permissions = SystemPermissions.superUser();
  return;
}
```
This treats System users (level 1) identically to Super users (level 2), granting unconditional full access. Per AGENT.md §17a: *"The client code must NOT treat System users as Super users. Only `UserLevel.super_` bypasses permission checks."*

**Fix:**
- Change the condition to `if (level == UserLevel.super_)` only.
- For `UserLevel.system`, fall through to the `else` branch that calls `usersDao.getSystemPermissions()` and `SystemPermissions.forUser()`.
- This unblocks the entire `else` branch which is currently dead code.
- **Warning:** This will immediately surface issues A2 and A3 (the permission parsing pipeline for system users is broken). Those must be fixed in the same batch.

**Update after completion:**
- [x] Update `lib/ui/screens/system/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: restrict superUser() shortcut to super_ level only in system dashboard"`

---

### ~~Task A2: SystemPermissions.forUser() parses JSON but roles.permissions is a binary blob~~ ✅

**Files to modify:** `lib/models/system_permissions.dart`
**Context files to read:** `lib/models/permissions.dart` (especially `fromBlob` / `toBlob`), `lib/database/daos/roles_dao.dart`
**Depends on:** Task A1 (A1 makes this code path reachable)
**Parallel group:** PA1

**Specification:**
In `SystemPermissions.forUser()` (~L72–82), the code calls `jsonDecode(role.permissionsJson)` and `Permissions.fromJson()`. But per AGENT.md §17a, `roles.permissions` is a `blob` column with binary encoding (3 bytes per resource: `[resource_id: u8, actions_lo: u8, actions_hi: u8]`).

The `RolePermissions` class (~L59–62) carries a `permissionsJson` field typed as `String`. The `UsersDao.getSystemPermissions()` (~L104) reads `role.permissions` which is a `Uint8List` blob.

**Fix:**
1. Change `RolePermissions.permissionsJson` from `String` to `Uint8List permissionsBlob`.
2. In `SystemPermissions.forUser()`, replace `jsonDecode` + `Permissions.fromJson()` with `Permissions.fromBlob(role.permissionsBlob)`.
3. Update `UsersDao.getSystemPermissions()` to pass the raw blob, not a string.
4. Remove the `try/catch` that silently swallows parse failures — if a blob is malformed, log it visibly.

**Update after completion:**
- [x] Update `lib/models/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: parse system permissions from binary blob instead of JSON"`

---

### Task A3: Permission format mismatch — JSON text vs binary blob throughout codebase ✅

**Files to modify:** `lib/core/permission_parser.dart`, `lib/database/daos/roles_dao.dart`
**Context files to read:** `lib/models/permissions.dart` (`toBlob`, `fromBlob`), `lib/database/tables/roles.dart`
**Depends on:** Task A2
**Parallel group:** PA2

**Specification:**
Two competing serialization formats exist in the codebase:
1. `permission_parser.dart` `serialisePermissions()` (~L114–125) outputs JSON: `[{"resource": "users", "actions": ["read"]}]`
2. `Permissions.toBlob()` outputs binary: 3 bytes per resource

The `roles_dao.dart` `createRole()` builds a `CreateRolePayload` and sets `payload.permissions = utf8.encode(role.permissions.value)` — encoding a JSON string as UTF-8 bytes.

**Fix:**
1. **Standardize on binary blob format** per AGENT.md §17a.
2. In `roles_dao.dart`, replace JSON encoding with `permissions.toBlob()` when writing to both the local DB and the sync payload.
3. In `permission_parser.dart`, either remove `serialisePermissions()` (if unused elsewhere) or deprecate it and redirect callers to `Permissions.toBlob()`.
4. Ensure `school_dashboard_screen.dart` `_initializeSession()` uses `Permissions.fromBlob()` when reading role permissions.
5. Verify `school_role_detail_screen.dart` and `school_roles_screen.dart` also use the blob format when saving.

**Update after completion:**
- [x] Update `lib/core/CONTEXT.md`
- [x] Update `lib/database/daos/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: standardize permission serialization on binary blob format"`

---

### Task A4: System-scoped permissions never merged with school-scoped permissions ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** `lib/database/daos/school_scopes_dao.dart`, `lib/models/school_permissions.dart`, `lib/models/permissions.dart`
**Depends on:** Task A3
**Parallel group:** PA3

**Specification:**
In `_initializeSession()` (~L92–130), when a System user enters a school dashboard, only **school-scoped** scopes are loaded (`scopes.school.equals(schoolId)`). Per AGENT.md §17: *"System users can also be school members — system + school roles merge."*

**Fix:**
1. After loading school-scoped scopes, also query for system-scoped scopes: `scopes` where `scopes.user = userId` AND `scopes.school IS NULL`.
2. Parse permissions from both sets of roles.
3. Union (bitmask OR) all permissions into the final `SchoolPermissions` object.
4. This ensures a System user with `Users.Read` at system level can also see users within school dashboards.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: merge system-scoped permissions with school-scoped in dashboard"`

---

### Task A5: Service layer has zero permission checks — relies entirely on UI ✅

**Files to modify:** `lib/services/member_management.dart`, `lib/services/members.dart`
**Context files to read:** `lib/models/permissions.dart`, `lib/models/school_permissions.dart`
**Depends on:** Task A3
**Parallel group:** PA3

**Specification:**
`MemberManagementService` methods (`updateTeacher`, `removeTeacher`, `updateStaff`, `removeStaff`, `updateStudent`, etc.) execute directly against DAOs without verifying permissions. All security relies on the UI hiding buttons.

**Fix:**
This is a defense-in-depth concern. For MVP, add a `SchoolPermissions` parameter (or a context object) to each service mutation method and verify the caller has the appropriate `Resource.X` + `Action.Y` before proceeding. Return `Err(GrpcError(...))` if denied.

At minimum, add permission guards to:
- `updateTeacher` → requires `Resource.teachers, Action.update`
- `removeTeacher` → requires `Resource.teachers, Action.delete`
- `updateStaff` → requires `Resource.staff, Action.update`
- `removeStaff` → requires `Resource.staff, Action.delete`
- All owner/guardian/student mutation methods similarly

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add permission guards to service layer mutation methods"`

---

## Track B: Student Experience (Completely Broken)

The student persona is essentially non-functional. This is the second-highest priority.

---

### Task B1: Student "Grades" tab falls through to "Coming soon" placeholder ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** PB1

**Specification:**
Student nav declares a `'Grades'` tab (L348) but `_buildContentPanel()` (L536–641) has no `if (item.label == 'Grades')` handler. It falls through to the default "Coming soon" placeholder. The student's primary feature is completely non-functional.

**Fix:**
Add a handler for `'Grades'` in `_buildContentPanel()` that routes to a student-specific grades view. This view should show only the current student's grades.

The `StudentEntry` contains the student's `StudentsData` with `adm` (admission number). Use this to scope data:
```dart
if (item.label == 'Grades') {
  return StudentGradePage(
    schoolContext: widget.schoolContext,
    studentAdm: (entry as StudentEntry).student.adm,
  );
}
```

Verify `StudentGradePage` exists at `lib/ui/screens/school_dashboard/academics/student_grade_page.dart` and accepts these parameters. If it doesn't accept `studentAdm` directly, adapt it.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: route student Grades tab to student-specific grades view"`

---

### Task B2: No student-self progress screen — GuardianProgressScreen rejects non-guardians ✅

**Files to modify:** `lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read:** `lib/models/membership.dart`
**Depends on:** None
**Parallel group:** PB1

**Specification:**
`GuardianProgressScreen` (~L67–70) explicitly rejects non-guardian entries with *"This screen is only available for guardians."* Despite having the exact four-tab layout (Overview, Exams, Mastery, Attendance) a student would need.

**Fix:**
Either:
1. **Rename to `ProgressScreen`** and handle both `GuardianEntry` and `StudentEntry` — for `GuardianEntry`, scope by `ward.adm`; for `StudentEntry`, scope by `student.adm`. OR
2. **Create a separate `StudentProgressScreen`** that mirrors the guardian progress layout but is scoped to the logged-in student.

Option 1 is recommended for code reuse. The key change:
- In the entry switch, add `StudentEntry` handling that uses `(entry as StudentEntry).student` instead of `(entry as GuardianEntry).ward`.
- All DAO calls that take `studentAdm` work identically for both cases.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/progress/` (add or update CONTEXT)
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "feat: add student-self progress screen alongside guardian progress"`

---

### Task B3: Student sees ALL exams school-wide if ExamsGradesScreen is ever reached ✅

**Files to modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read:** `lib/database/daos/exams_grades_dao.dart`
**Depends on:** None
**Parallel group:** PB1

**Specification:**
`ExamsGradesScreen` has zero role-based branching. It calls `watchExamGroups(schoolId, year, term)` with no student filter. If a student somehow reaches this screen (currently prevented only by nav routing), they'd see ALL exams, teacher names, grading spreadsheets, and paper management UI for the entire school.

**Fix:**
1. Add a guard at the top of `ExamsGradesScreen.build()`: if `currentEntry is StudentEntry`, redirect to the student grades view (or show a "not available" state).
2. Same for `GuardianEntry`.
3. This is defense-in-depth — the nav routing should prevent students from reaching this screen, but the screen itself should also be safe.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` (create if needed)
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: guard ExamsGradesScreen against student and guardian access"`

---

### Task B4: Students have no Finance tab — cannot see their own fee balance ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Depends on:** None
**Parallel group:** PB2

**Specification:**
Student nav items (L348–354) have no Finance tab. Students cannot view their own fee balance, invoices, or payment history. Guardians have this via `_GuardianFinanceView`.

Additionally, `FinanceScreen`'s wildcard `_ =>` case falls through to `_OwnerFinanceShell`, so if a `StudentEntry` ever reaches this screen, it would see school-wide financial data.

**Fix:**
1. Add a `'Finance'` nav item to the student nav items (with `Icons.receipt_long_outlined`).
2. In `FinanceScreen.build()`, add a `StudentEntry` case that renders a student-specific read-only finance view showing only their own invoices and payments (similar to `_GuardianFinanceView` but scoped by `student.adm`).
3. Ensure the wildcard `_ =>` case does NOT fall through to `_OwnerFinanceShell` — change it to show an error/empty state.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add student finance tab with read-only fee balance view"`

---

### Task B5: _kAcademicNavLabels blocks Announcements when no terms exist (affects students) ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PB2

**Specification:**
`_kAcademicNavLabels` (L493–506) includes `'Announcements'`, `'Finance'`, `'Members'`, `'Grades'`, and `'Progress'`. When no terms exist, these are all hidden behind `NoTermsBlankState`. Students (and guardians) should see Announcements regardless of term configuration.

**Fix:**
Remove `'Announcements'` from `_kAcademicNavLabels`. Also remove `'Members'` and `'Finance'` — these are not academic sections and should be accessible even before terms are created. The set should only contain truly academic items:
```dart
static const _kAcademicNavLabels = {
  'Academics',
  'My Classes',
  'Exams & Grades',
  'Exams',
  'Timetable',
  'Attendance',
  'Grades',
  'Progress',
};
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: remove non-academic items from _kAcademicNavLabels"`

---

### Task B6: Student announcements not filtered by grade/class ✅

**Files to modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read:** `lib/database/daos/announcements_dao.dart`
**Depends on:** None
**Parallel group:** PB3

**Specification:**
`_RoleFeed` for students passes `audienceBit` but not `grade`/`stream` to the DAO. A Grade 7 student sees announcements targeted at Grade 12 students.

**Fix:**
1. Extend the `_RoleFeed` to accept optional `grade` and `stream` parameters.
2. For `StudentEntry`, extract grade/stream from the student's current enrollment.
3. Pass these to the DAO's watch method to filter announcements relevant to the student's class.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: filter student announcements by grade and class"`

---

### Task B7: Student overview shows no stream name in enrollment info ✅

**Files to modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read:** `lib/database/daos/catalog_dao.dart`
**Depends on:** None
**Parallel group:** PB3

**Specification:**
`_StudentEnrollmentInfo` (~L1460–1532) displays `gradeLabel(enrollment.grade)` but never resolves or shows the stream name. Students can't see which stream they're in.

Also, `_StudentRecentGrades` (~L1677–1793) groups by `examId` but never queries the exam record for its name — students see score percentages with no exam identification.

**Fix:**
1. In `_StudentEnrollmentInfo`, resolve the stream name via `CatalogDao.getStreamsForSchool()` and display as `"Grade 10 · East"` using `gradeStreamLabel`.
2. In `_StudentRecentGrades`, fetch exam names via `ExamsGradesDao` and display them as card titles.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: show stream name and exam names in student overview"`

---

### Task B8: _ClassTimetableView treats null stream as "not enrolled" ✅

**Files to modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PB3

**Specification:**
`_ClassTimetableView` (~L9627–9632) treats a null `enrollment.stream` as "not enrolled" and shows `_NotEnrolledState`. But a student may be validly enrolled in a grade without a stream assignment (e.g., schools that don't use streams).

**Fix:**
Only show `_NotEnrolledState` when there is no enrollment at all (`enrollment == null`), not when `enrollment.stream == null`. When stream is null, load the timetable for the grade without stream filtering.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: allow null stream in timetable enrollment check"`

---

## Track C: Guardian Experience

---

### Task C1: Guardian attendance/finance screens not reactive on ward switch

**Files to modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`, `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read:** `lib/models/school_context.dart`
**Depends on:** None
**Parallel group:** PC1

**Specification:**
Both `AttendanceScreen.build()` and `FinanceScreen.build()` read `schoolContext.currentEntry.value` once, not inside a `ValueListenableBuilder`. When a guardian switches from Ward A to Ward B:
- `_GuardianAttendanceView` has no `didUpdateWidget` override — the `State` object is reused without reset.
- `_GuardianFinanceView` has no `didUpdateWidget` override either.
- `_GuardianAttendanceView` doesn't reset `_calendarMonth` on ward switch.

The timetable screen **correctly** implements `didUpdateWidget` with `oldWidget.studentAdm != widget.studentAdm` → `_loadData()`.

**Fix:**
1. In `AttendanceScreen`, add a `ValueListenableBuilder<MembershipEntry>` wrapping the entry switch, or add a `Key` based on the ward's `adm` to force widget recreation.
2. In `FinanceScreen`, same approach.
3. In `_GuardianAttendanceView`, either implement `didUpdateWidget` to detect `studentAdm` change and reset state, or use a `ValueKey(studentAdm)` on the widget.
4. Reset `_calendarMonth` to current month on ward switch.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: make guardian attendance and finance screens reactive on ward switch"`

---

### Task C2: Guardian nav tabs are hardcoded — not permission-gated

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PC1

**Specification:**
Guardian nav items (L358–366) are `const` — all 6 tabs are always shown regardless of the guardian's actual permissions from `SchoolPermissions`. If a school denies `Resource.fees / Action.read` to a guardian role, they still see the Finance tab (unlike teacher/staff where tabs are permission-gated).

**Fix:**
Make guardian nav items permission-aware, similar to teacher/staff:
```dart
MembershipRole.guardian => [
  const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
  const _NavItem(label: 'Progress', icon: Icons.bar_chart_outlined),
  const _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
  if (perms.canAny(Resource.fees, [Action.read]) ||
      perms.canAny(Resource.payments, [Action.read]))
    const _NavItem(label: 'Finance', icon: Icons.receipt_long_outlined),
  const _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),
  const _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
],
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: permission-gate guardian navigation tabs"`

---

### Task C3: Guardian entry picker does not show ward's cached image ✅

**Files to modify:** `lib/ui/screens/home/home_screen.dart`
**Context files to read:** `lib/ui/widgets/student_avatar.dart`
**Depends on:** None
**Parallel group:** PC2

**Specification:**
The `_showEntryPicker` method shows "Guardian" title and `ward.name` as subtitle for `GuardianEntry`, but does not display the ward's cached profile image (`{appDir}/schools/{schoolId}/students/{adm}/image`). The `StudentAvatar` widget exists and is used elsewhere.

Also, the role-switcher sheet (`_RoleSwitcherSheet` ~L1952–2112) shows a generic `Icons.family_restroom_outlined` icon instead of the ward's image.

**Fix:**
1. In `_showEntryPicker`, use `StudentAvatar` for `GuardianEntry` items.
2. In `_RoleSwitcherSheet._entryMeta`, for `GuardianEntry`, return the ward's avatar widget instead of the generic icon.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "ui: show ward cached image in guardian entry picker"`

---

### Task C4: Guardian progress screen — exam cards have no exam name and are not tappable ✅

**Files to modify:** `lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read:** `lib/database/daos/exams_grades_dao.dart`
**Depends on:** None
**Parallel group:** PC2

**Specification:**
1. `_ExamCard` (~L895–1025) shows "Exam" as a generic label with a quiz icon — never fetches or displays the actual exam name (e.g., "Mid-Term Exam 2025"). The `examId` is available but no lookup is done.
2. `_ExamCard` has no `onTap` handler — guardians cannot drill down into a specific exam to see detailed paper-level grades.
3. The ward identity header shows `gradeLabel(enrollment.grade)` but not the stream name (unlike `_WardInfoCard` in overview which uses `gradeStreamLabel`).

**Fix:**
1. Fetch exam name via `ExamsGradesDao` and display it as the card title.
2. Add an `onTap` handler that navigates to a detail view (possibly `StudentGradePage` scoped to that exam).
3. Resolve and display stream name in the ward identity header using `CatalogDao.getStreamsForSchool`.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: add exam names and tap navigation to guardian progress cards"`

---

### Task C5: Guardian cannot make payments from Finance screen

**Files to modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read:** `lib/database/tables/mpesa.dart`, `lib/models/mpesa_config.dart`
**Depends on:** None
**Parallel group:** PC3

**Specification:**
The guardian finance view (~L1922–2009) shows invoices and payment history as read-only tiles, but there is no "Make Payment" or "Initiate M-Pesa Payment" action. The `mpesa` table and `MpesaConfig` model exist but are not surfaced to guardians.

**Fix:**
Add a "Pay" action button on the guardian finance view. If the school has an M-Pesa configuration (`mpesa` table row for the school), show an "M-Pesa Payment" option. Otherwise, show a "Record Payment" option (for cash/bank payments that the school admin will approve).

This may require a new `_GuardianPaymentSheet` widget.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add payment initiation for guardians on finance screen"`

---

### Task C6: No notification when ward is unenrolled

**Files to modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PC3

**Specification:**
If a ward has been unenrolled from the current term, the guardian overview still renders all sections. Each individually handles `enrollment == null` with graceful fallbacks, but there is no top-level banner telling the guardian *"Your child is not enrolled this term"*.

**Fix:**
Add a prominent banner/alert at the top of `_GuardianOverview` when `enrollment == null`, clearly stating the ward is not enrolled and suggesting they contact the school.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "ui: add unenrolled ward banner to guardian overview"`

---

### Task C7: Entry switching resets guardian to Overview tab

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PC3

**Specification:**
In `_onEntryChanged()` (L248–263), `_selectedIndex = 0` is always set. When a guardian switches from Ward A to Ward B while on the Progress tab, they're forced back to Overview. This is jarring when comparing two wards.

**Fix:**
Only reset `_selectedIndex` to 0 if the role changes (e.g., teacher → guardian). If the role stays the same (guardian → guardian with different ward), keep the current tab:
```dart
void _onEntryChanged() {
  final newEntry = widget.schoolContext.currentEntry.value;
  final newRole = newEntry.role;
  final oldRole = _currentItems == _itemsForRole(newRole, ...) ? newRole : /* old role */;
  final newItems = _itemsForRole(newRole, widget.schoolContext.permissions);
  
  if (newRole != _currentRole) {
    _selectedIndex = 0; // role changed — reset
  } else if (_selectedIndex >= newItems.length) {
    _selectedIndex = 0; // safety bound
  }
  // else: keep current tab index
  ...
}
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: preserve tab index when guardian switches wards"`

---

## Track D: Teacher RBAC & Data Scoping

---

### Task D1: Teacher "Academics" tab shows ALL grades/classes school-wide ✅

**Files to modify:** `lib/ui/screens/school_dashboard/academics/academics_screen.dart`
**Context files to read:** `lib/database/daos/academics_dao.dart`, `lib/database/daos/subjects_dao.dart`
**Depends on:** None
**Parallel group:** PD1

**Specification:**
The teacher nav includes `Academics` as an always-visible "core 4" item, rendering `AcademicsScreen` — the same full grade-tree view that owners/staff get. A teacher can browse every grade, stream, student list, subject assignment, and timetable slot school-wide regardless of their own class assignments or permissions.

**Fix:**
Two options:
1. **Replace `Academics` with `My Classes`** in the teacher's core-4 nav items. The `MyClassesScreen` already exists and is teacher-scoped. Move `Academics` to the permission-gated section (visible only if `perms.canAny(Resource.classes, [Action.read])`).
2. **Or** add a teacher-scoped mode to `AcademicsScreen` that filters to only show grades/classes where the teacher has assignments.

Option 1 is recommended — it aligns with the existing `MyClassesScreen` and is simpler:
```dart
MembershipRole.teacher => [
  const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
  const _NavItem(label: 'My Classes', icon: Icons.class_outlined),
  const _NavItem(label: 'Exams', icon: Icons.assignment_outlined),
  const _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
  // Permission-gated:
  if (perms.canAny(Resource.classes, [Action.read]))
    const _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
  ...
],
```

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: replace teacher Academics with My Classes in core nav"`

---

### Task D2: Teacher "Exams" tab shows ALL exams school-wide — no teacher filter ✅

**Files to modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read:** `lib/database/daos/exams_grades_dao.dart`
**Depends on:** None
**Parallel group:** PD1

**Specification:**
`_ExamsListView._buildStream()` calls `watchExamGroups(schoolId, year, term)` with no teacher filter. Every teacher sees every exam in the school. The DAO's `watchExamsForClass` has an optional `teacherId` parameter but it is never used in the list view.

**Fix:**
1. When `currentEntry is TeacherEntry`, filter the exam list to show only exams where the teacher is creator, invigilator, or teaches one of the exam's subjects.
2. The DAO already has the `teacherId` parameter — pass `(entry as TeacherEntry).teacher.user` to the query.
3. If the teacher has `perms.can(Resource.exams, Action.read)` (admin permission), show all exams (same as owner view).

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: scope teacher exams list to assigned subjects"`

---

### Task D3: _canGradeContent does not check permissions.can(Resource.grades, Action.mark) ✅

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read:** `lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** PD2

**Specification:**
`_canGradeContent` (~L175–188) for `TeacherEntry` only checks if the teacher is assigned to the paper's subject/grade via `_teacherSubjects`. It never consults `SchoolPermissions` for `Resource.grades, Action.mark`. A teacher with an admin role granting `Grades.Mark` globally cannot grade papers for subjects they are not personally assigned to.

Also, `_canProgressStatus` (~L152–157) returns `true` for ALL `StaffEntry` users unconditionally — no `permissions.can(Resource.exams, Action.update)` check.

**Fix:**
1. `_canGradeContent` for `TeacherEntry`: allow if EITHER the teacher teaches the subject OR `permissions.can(Resource.grades, Action.mark)`.
2. `_canProgressStatus` for `StaffEntry`: require `permissions.can(Resource.exams, Action.update)`.
3. `_canProgressStatus` for `TeacherEntry`: check both subject assignment AND `permissions.can(Resource.exams, Action.update)`.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: check grades.mark permission in _canGradeContent"`

---

### Task D4: Attendance class picker shows ALL classes for teachers — not their assigned ones

**Files to modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read:** `lib/database/daos/enrollments_dao.dart`, `lib/database/daos/subjects_dao.dart`
**Depends on:** None
**Parallel group:** PD2

**Specification:**
`_ClassPickerShellState._loadClasses()` (~L194–210) calls `_enrollmentsDao.watchPopulatedClasses(schoolId, year, term)` with no teacher filter. A teacher sees every class in the school in the picker.

Also, `_loadClasses()` calls `.listen()` on a stream but never stores the `StreamSubscription` — the subscription is not cancelled in `dispose()`, creating a memory leak.

**Fix:**
1. For `TeacherEntry`, filter classes to only those the teacher is assigned to (via `subject_teachers` or `class_teachers` table).
2. If `permissions.can(Resource.attendance, Action.mark)`, show all classes (admin-level access) — this aligns with the BUG-017 fix intent.
3. Store the `StreamSubscription` from `.listen()` and cancel it in `dispose()`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: filter attendance class picker to teacher-assigned classes"`

---

### Task D5: Teacher can see student personal details without students.read permission ✅

**Files to modify:** `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PD2

**Specification:**
The grade detail page's Students tab (index 0, ~L485) is always visible in the content tab strip. There is no `permissions.can(Resource.students, Action.read)` gate. Any teacher who reaches a grade detail (via Academics, which is always visible per D1) can see the full enrolled student list with personal data.

**Fix:**
Gate the Students tab behind `permissions.can(Resource.students, Action.read)` or `entry is OwnerEntry`. If the teacher doesn't have permission, hide the Students tab entirely (shift tab indices).

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: gate student details tab behind students.read permission"`

---

### Task D6: Teacher overview shows ALL exams, not teacher-scoped; upcoming exams filter is inconsistent

**Files to modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read:** `lib/database/daos/exams_grades_dao.dart`
**Depends on:** None
**Parallel group:** PD3

**Specification:**
1. `_TeacherQuickStats` (~L665–728) calls `examsDao.watchExamsForTerm(schoolId, year, term)` loading every exam, then client-side filters.
2. `_TeacherUpcomingExams` (~L941–960) only filters by `p.invigilator == widget.userId`, excluding papers for subjects the teacher teaches but isn't invigilator for — inconsistent with the "My Exams" stat card which uses a wider filter.

**Fix:**
1. Use a teacher-scoped DAO query instead of loading all exams and filtering client-side.
2. Align the upcoming exams filter to include papers where the teacher teaches the subject (not just invigilator).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: scope teacher overview exams to assigned subjects"`

---

### Task D7: Announcements — admin feed doesn't scope edit/delete by announcement ownership

**Files to modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PD3

**Specification:**
When a teacher gets `_AdminFeed` (via `announcements.create/update/delete` permission), `canEdit` and `canDelete` are set to `true` for ALL announcements. There's no check whether the teacher authored a specific announcement.

**Fix:**
Pass the current user's ID to the announcement list. For each announcement, only show edit/delete if `announcement.createdBy == currentUserId` OR `permissions.can(Resource.announcements, Action.delete)` (admin override).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: scope announcement edit/delete by ownership"`

---

### Task D8: Members page tabs computed once in initState, not reactive to entry changes ✅

**Files to modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PD3

**Specification:**
`_MembersPageBodyState.initState()` (~L82–113) reads `currentEntry.value` and `permissions` once to build `_visibleTabs`, but never listens to `currentEntry` changes. If a user switches role via `SchoolContext.switchEntry()` (e.g., teacher→guardian), the Members tab list doesn't update.

**Fix:**
Listen to `schoolContext.currentEntry` and rebuild `_visibleTabs` when it changes. Either:
1. Move tab computation to `build()` (deriving from the current entry).
2. Or add a listener in `initState` and call `setState` when entry changes.

Option 1 is cleaner.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: recompute members page tabs reactively on entry change"`

---

## Track E: Staff RBAC & Data Scoping

---

### Task E1: Staff finance — routed to _OwnerFinanceShell unconditionally ✅

**Files to modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read:** `lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** PE1

**Specification:**
`FinanceScreen.build()` (~L53–56) routes `StaffEntry` to `_OwnerFinanceShell` unconditionally. A staff member with zero finance permissions sees the full 4-tab finance UI. Additionally, within `_OwnerFinanceShell`, create/edit/delete actions for fees, invoices, and payments are not per-action permission-gated.

**Fix:**
1. For `StaffEntry`, check permissions before routing:
   - If `perms.can(Resource.fees, Action.read) || perms.can(Resource.payments, Action.read)` → show `_OwnerFinanceShell` but with per-action permission gating inside each tab.
   - Otherwise → show an access-denied state (though the nav item should already be hidden).
2. Inside `_OwnerFinanceShell`, gate each mutation button:
   - Fee creation: `perms.can(Resource.fees, Action.create)`
   - Invoice creation: `perms.can(Resource.fees, Action.create)`
   - Payment recording: `perms.can(Resource.payments, Action.create)`
   - Payment approval: `perms.can(Resource.payments, Action.approve)`
   - Fee/Invoice edit: `perms.can(Resource.fees, Action.update)`
   - Fee/Invoice delete: `perms.can(Resource.fees, Action.delete)`

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: permission-gate staff finance routing and actions"`

---

### Task E2: Staff timetable — routed to _OwnerTimetableShell unconditionally ✅

**Files to modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PE1

**Specification:**
`StaffEntry()` (~L139–143) is routed unconditionally to `_OwnerTimetableShell` — the full admin timetable with generation/deletion controls. The nav item is gated, but the screen has no internal guard.

**Fix:**
For `StaffEntry`, check `permissions.can(Resource.classes, Action.update)`:
- If yes → `_OwnerTimetableShell` (admin view with generation controls)
- If only `Action.read` → read-only school-wide timetable view (no generation/deletion buttons)

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: permission-gate staff timetable admin controls"`

---

### Task E3: Staff attendance — falls through to teacher's marking UI ✅

**Files to modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PE1

**Specification:**
`StaffEntry` falls through to the wildcard `_ => _ClassPickerShell(...)` case (~L52–70), which is the teacher's class-based attendance **marking** UI. A staff member with only `Action.read` on attendance gets the full marking interface.

**Fix:**
Add explicit `StaffEntry` handling:
- If `permissions.can(Resource.attendance, Action.mark)` → show `_ClassPickerShell` (marking UI)
- If only `permissions.can(Resource.attendance, Action.read)` → show a read-only attendance view
- Remove the wildcard `_ =>` fallback or make it show an error state

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add explicit staff attendance routing with permission checks"`

---

### Task E4: Staff "Students" nav item has no handler in _buildContentPanel ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PE2

**Specification:**
Staff nav adds a `'Students'` nav item (~L325) gated by `Resource.students, Action.read`. But `_buildContentPanel` has no handler for `'Students'` — it falls through to the "Coming soon" placeholder.

**Fix:**
Either:
1. Add a `'Students'` handler in `_buildContentPanel` that shows `MembersPage` pre-filtered to the Students tab.
2. Or remove the separate `'Students'` nav item for staff and keep only `'Members'` (which already has a Students sub-tab).

Option 2 is simpler and avoids the confusing redundancy (staff nav having both "Students" and "Members" when the latter includes a Students sub-tab).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: resolve staff Students nav item handler or remove redundant tab"`

---

### Task E5: Staff Announcements always visible — not permission-gated ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PE2

**Specification:**
Staff nav (L339–341) includes `Announcements` as a `const` item — always visible regardless of `Resource.announcements, Action.read` permission.

**Fix:**
Wrap the Announcements nav item in a permission check:
```dart
if (perms.canAny(Resource.announcements, [Action.read]))
  const _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: permission-gate staff announcements nav item"`

---

### Task E6: Staff overview shows announcement content without permission check ✅

**Files to modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PE2

**Specification:**
`_StaffOverview` shows `_RecentAnnouncements` with `audienceBit: AudienceBits.staff` without checking `permissions.can(Resource.announcements, Action.read)`. Announcement content leaks onto the overview.

Also, `_StaffQuickStats` creates three separate `StreamBuilder` widgets subscribing to the same Drift stream three times instead of sharing one subscription.

**Fix:**
1. Gate `_RecentAnnouncements` behind `permissions.can(Resource.announcements, Action.read)`.
2. Combine the three identical `StreamBuilder` widgets into a single stream subscription.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: `git add -A && git commit -m "fix: gate staff overview announcements behind permission check"`

---

## Track F: Owner Missing Features

---

### Task F1: Members/Finance/Announcements gated behind term existence — blocks school setup ✅

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** Task B5 (removes items from _kAcademicNavLabels)
**Parallel group:** PF1

**Specification:**
A brand-new school owner cannot add teachers, staff, or students until they first create a term, because `Members`, `Finance`, and `Announcements` are in `_kAcademicNavLabels` and gated behind `activeTermContext.hasTerms`. This breaks the natural setup workflow.

**Fix:**
Per Task B5, remove `'Members'`, `'Finance'`, and `'Announcements'` from `_kAcademicNavLabels`. These should be accessible even before terms are created. Only truly academic sections (Academics, Exams, Timetable, Attendance, Grades, Progress) should require a term.

**Note:** If B5 is completed first, this task may already be done. Verify and mark complete.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Git commit: Already done by Task B5 (removed non-academic items from `_kAcademicNavLabels`)

---

### Task F2: Owner nav — missing Attendance tab

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`, `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PF1

**Specification:**
Owner nav items (L272–280) omit Attendance entirely. An owner can only reach attendance by drilling through Academics → Grade Detail → Attendance tab (4 clicks deep).

Additionally, `AttendanceScreen.build()` has no `OwnerEntry` handler — even if added to nav, the screen would fall through to the wildcard.

**Fix:**
1. Add `Attendance` nav item for owners:
   ```dart
   _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),
   ```
2. In `AttendanceScreen.build()`, add an `OwnerEntry` case that shows a school-wide attendance dashboard (all classes, all dates).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add attendance tab to owner navigation"`

---

### Task F3: Role edit from list is broken — opens blank creation form ✅

**Files to modify:** `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart`
**Depends on:** None
**Parallel group:** PF2

**Specification:**
The table-row "Edit" action (~L266) calls `_showCreateSheet(context)` while discarding the selected role. `_RoleFormSheet` accepts no `existing` parameter, so "Edit" opens a blank creation form. Role editing from the list is completely broken.

**Fix:**
1. Add an `existing` parameter to `_RoleFormSheet` (or `_showCreateSheet`).
2. Pass the selected role's data when the Edit action is triggered.
3. Pre-populate the form with the role's name, description, and permissions.
4. On save, call the update DAO method instead of create.

Also fix: `_purgeRole` and `_deleteRole` both call the identical `_dao.deleteRole(...)`. Add a distinct purge operation or remove the purge button if purge isn't supported for school roles.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: wire role edit action to pre-populated form"`

---

### Task F4: No school profile/settings screen for owners

**Files to modify:** Create `lib/ui/screens/school_dashboard/settings/school_settings_screen.dart`
**Context files to read:** `lib/database/tables/schools.dart`, `lib/database/daos/schools_dao.dart`
**Depends on:** None
**Parallel group:** PF2

**Specification:**
There is no UI for owners to edit school name, address, motto, curriculum type, or upload a logo. `SyncAction.updateSchool(1)` exists but has no UI path.

**Fix:**
Create a `SchoolSettingsScreen` with:
- School name (text field)
- Address/location (text field)
- Motto (text field)
- Curriculum type selector (CBC / 8-4-4)
- Logo upload (using file picker → write to `{appDir}/schools/{schoolId}/logo`)
- Save button that writes to local DB and creates a sync log entry with `SyncAction.updateSchool`

Add a `'Settings'` nav item to the owner nav in `school_dashboard_screen.dart`.

**Update after completion:**
- [ ] Create `lib/ui/screens/school_dashboard/settings/CONTEXT.md`
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add school profile/settings screen for owners"`

---

### Task F5: No student deletion — missing DAO and service methods ✅

**Files to modify:** `lib/database/daos/members_dao.dart`, `lib/services/member_management.dart`
**Context files to read:** `lib/database/tables/students.dart`, `lib/database/tables/logs.dart`
**Depends on:** None
**Parallel group:** PF3

**Specification:**
No `deleteStudent` / `removeStudent` method exists in `MembersDao` despite `SyncAction.deleteStudent(13)` existing. The UI's `_confirmDelete` in `_StudentRow` has no DAO method to call.

**Fix:**
1. Add `deleteStudent(String schoolId, String adm, {required String accountId})` to `MembersDao`:
   - Soft-delete the student row (set status to deleted or remove from table).
   - Create a log entry with `SyncAction.deleteStudent` and appropriate payload.
2. Add a corresponding method in `MemberManagementService`.
3. Verify the UI's `_confirmDelete` callback in `_StudentRow` correctly calls the new method.

**Update after completion:**
- [x] Update `lib/database/daos/CONTEXT.md`
- [x] Update `lib/services/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add deleteStudent method to DAO and service layer"`

---

### Task F6: No enrollment management UI (enroll/unenroll students)

**Files to modify:** `lib/ui/screens/school_dashboard/members/student_detail_page.dart`
**Context files to read:** `lib/database/daos/enrollments_dao.dart`, `lib/database/tables/enrollments.dart`
**Depends on:** None
**Parallel group:** PF3

**Specification:**
`SyncAction.enrollStudent(14)` and `SyncAction.unenrollStudent(15)` exist. `EnrollmentsDao` is present. But there is no visible enrollment management UI (enroll/unenroll buttons) accessible to the owner from the Members page or Student Detail page for term-based class enrollment.

**Fix:**
1. On `student_detail_page.dart`, add an "Enrollments" section showing the student's enrollment history (grade, stream, term, year).
2. Add an "Enroll" button that opens a sheet to select grade, stream, and term.
3. Add an "Unenroll" button on active enrollments.
4. Both actions should write to local DB and create log entries.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add enrollment management UI to student detail page"`

---

### Task F7: No term editing or deletion UI ✅

**Files to modify:** `lib/ui/widgets/create_term_modal.dart` (or create new edit modal)
**Context files to read:** `lib/database/daos/terms_dao.dart`
**Depends on:** None
**Parallel group:** PF4

**Specification:**
Owners can create the first term via `NoTermsBlankState` and `create_term_modal.dart`, but once created, there is no visible path to edit term dates or delete a misconfigured term.

**Fix:**
1. Add edit functionality to the term selector or term display area — when a term chip/card is long-pressed or has an edit icon, open a modal pre-populated with the term's dates and name.
2. Add a delete action (with confirmation dialog) for terms.
3. Both actions should create appropriate log entries.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add term editing and deletion UI"`

---

### Task F8: No M-Pesa configuration UI

**Files to modify:** Create `lib/ui/screens/school_dashboard/settings/mpesa_config_screen.dart`
**Context files to read:** `lib/database/tables/mpesa.dart`, `lib/models/mpesa_config.dart`, `lib/database/daos/finance_dao.dart`
**Depends on:** Task F4 (part of settings screen)
**Parallel group:** PF4

**Specification:**
The `mpesa` table, `MpesaConfig` model, and `SyncAction.createMpesa/updateMpesa/deleteMpesa` (86–88) all exist. But there is no UI for owners to configure mobile payment integration.

**Fix:**
Create an M-Pesa configuration section within the school settings screen (from F4) with fields for:
- Business short code
- Consumer key / consumer secret (masked)
- Passkey
- Callback URL
- Environment (sandbox / production)

Save creates a log entry with `SyncAction.createMpesa`. Update uses `SyncAction.updateMpesa`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add M-Pesa configuration screen for owners"`

---

### Task F9: No Plans/Subscriptions UI for school owners

**Files to modify:** Create new screen or add to settings
**Context files to read:** `lib/database/daos/plans_dao.dart`, `lib/models/plan_features.dart`
**Depends on:** Task F4
**Parallel group:** PF4

**Specification:**
`plans_dao.dart`, `plan_features.dart`, and `SyncAction.createSubscription/updateSubscription/deleteSubscription` (71–73) exist. But there is no UI for owners to view or manage their school's subscription tier.

**Fix:**
Add a "Subscription" section to the school settings screen showing:
- Current plan name and features
- Expiry date
- Usage stats (if available from `aiusage` table)
- Upgrade CTA (if applicable)

This is read-only for most owners (subscriptions are managed by system/super users), but they should at least be able to see their current plan.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: add read-only subscription/plans view for school owners"`

---

## Track G: System Dashboard

---

### Task G1: System user action buttons bypass permission checks (Users, Members, Schools, Roles, Plans)

**Files to modify:** `lib/ui/screens/system/users/users_section.dart`, `lib/ui/screens/system/members/members_section.dart`, `lib/ui/screens/system/schools/schools_section.dart`, `lib/ui/screens/system/roles/roles_section.dart`, `lib/ui/screens/system/plans/plans_section.dart`
**Context files to read:** `lib/models/system_permissions.dart`, `lib/models/permissions.dart`
**Depends on:** Task A1 (once A1 is fixed, system users won't have superUser() — these checks become meaningful)
**Parallel group:** PG1

**Specification:**
Currently all action buttons are visible because of the A1 bug (`superUser()` for all system users). Once A1 is fixed, the following sections need explicit permission checks:

1. **Users section** (~L390–500): promote, demote, suspend, purge actions never check `permissions.can(Resource.users, Action.update/delete)`.
2. **Members section** (~L290–370): "Remove member", "Purge", "Suspend", "Delete" actions are unguarded.
3. **Schools section**: status-change/trash/purge actions on school rows need `permissions.can(Resource.schools, Action.update/delete)`.
4. **Roles section**: edit/delete actions need `permissions.can(Resource.roles, Action.update/delete)`.
5. **Plans section**: create/delete/purge actions need `permissions.can(Resource.plans, Action.create/delete)`.

**Fix:**
For each section, wrap every action button in a permission check:
```dart
if (widget.permissions.can(Resource.users, Action.update))
  _buildPromoteButton(...)
```

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add permission checks to system dashboard action buttons"`

---

### Task G2: Plans tab unreachable on both mobile and desktop

**Files to modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read:** `lib/ui/screens/system/plans/plans_section.dart`
**Depends on:** None
**Parallel group:** PG1

**Specification:**
The Plans section exists as a widget (`PlansSection`) and a FAB action (`_FabAction.createPlan`), but has no dedicated navigation surface:
- Mobile (6 tabs): Home, Users, Members, Schools, Roles, Settings — no Plans.
- Desktop (5 tabs): Users, Members, Schools, Roles, Settings — no Plans.

**Fix:**
Add a "Plans" tab to both mobile and desktop layouts. Alternatively, merge Plans into the Settings tab as a sub-section (alongside Subjects).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add Plans tab to system dashboard navigation"`

---

### Task G3: Notifications tab missing — failed sync logs invisible to system users

**Files to modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read:** `lib/ui/screens/system/notifications/notifications_panel.dart`, `lib/ui/screens/system/notifications/notifications_section.dart`
**Depends on:** None
**Parallel group:** PG2

**Specification:**
`notifications/notifications_panel.dart` and `notifications/notifications_section.dart` exist but are not wired into any tab in either mobile or desktop layout. Failed sync logs are invisible to System users.

**Fix:**
Add a Notifications panel/section to the system dashboard. On desktop, this could be a sidebar panel. On mobile, add a Notifications tab or a bell icon in the app bar that opens the notifications section.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "feat: wire notifications panel into system dashboard"`

---

### Task G4: Invite user flow — no level picker, wrong SyncAction

**Files to modify:** `lib/ui/screens/system/users/invite_user_sheet.dart`
**Context files to read:** `lib/database/tables/enums.dart` (SyncAction enum)
**Depends on:** None
**Parallel group:** PG2

**Specification:**
1. The invite user flow creates a user with `level: UserLevel.normal` unconditionally. Per AGENT.md §16a, a System user with `Users.Create` permission should be able to create System-level users.
2. `inviteUser()` logs the action as `SyncAction.updateUser` instead of a create/invite action.

**Fix:**
1. Add a `UserLevel` picker to the invite sheet (Normal / System — Super is not allowed per §16a).
2. Change the sync action from `SyncAction.updateUser` to the appropriate create action.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add level picker and correct SyncAction in invite user flow"`

---

### Task G5: System dashboard — home screen access for system users is too subtle

**Files to modify:** `lib/ui/screens/home/home_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PG2

**Specification:**
The "SYSTEM" badge (~L253–310) is a tiny 9px text chip in the top bar. A System user with no school memberships sees an empty "No schools yet" state with no prominent affordance to reach the system dashboard.

**Fix:**
1. For users with `level == UserLevel.system || level == UserLevel.super_`, show a prominent system dashboard card at the top of the home screen (above school membership cards).
2. Style it distinctly (different color/icon) so it's immediately obvious.
3. Optionally, if the user has no school memberships, auto-navigate to the system dashboard.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "ui: add prominent system dashboard card on home screen"`

---

### Task G6: _promoteMember doesn't check target user status before elevation

**Files to modify:** `lib/ui/screens/system/members/members_section.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PG3

**Specification:**
`_promoteMember` (~L136–166) promotes a user to `UserLevel.super_` — a dangerous elevation — but only checks `isSuper` (current user is super). It doesn't verify the target user's status is `active`, allowing promotion of suspended or deleted users.

**Fix:**
Add a guard: `if (targetUser.status != UserStatus.active) { show error "Cannot promote a suspended/deleted user"; return; }`

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: check target user status before promotion"`

---

### Task G7: System stats StreamBuilders don't handle error state

**Files to modify:** `lib/ui/screens/system/home/system_stats_section.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PG3

**Specification:**
`SystemStatsSection` nests 6+ `StreamBuilder` widgets but does not handle `snapshot.hasError` for any of them. If any DAO stream errors, the UI silently shows stale/default data.

**Fix:**
Add error handling to each `StreamBuilder`:
```dart
if (snapshot.hasError) {
  return _ErrorCard(message: 'Failed to load stats');
}
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add error state handling to system stats StreamBuilders"`

---

## Track H: Data Sync & Log Integrity

---

### Task H1: Verify log creation for attendance marking

**Files to modify:** `lib/database/daos/attendance_dao.dart`
**Context files to read:** `lib/database/tables/logs.dart`, `lib/database/tables/enums.dart`
**Depends on:** None
**Parallel group:** PH1

**Specification:**
`markAttendance` and `markClassAttendance` methods in `AttendanceDao` must write to the `logs` table with `SyncAction.markAttendance` and a self-contained protobuf payload. If log entries aren't created, offline attendance mutations will never sync to the server.

**Fix:**
1. Read the `markAttendance` implementation fully.
2. If log entries are not being created, add them with the correct `SyncAction` and payload.
3. Verify the `resource` field is set to something human-readable (e.g., student name or class name).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: verify and add sync log creation for attendance marking"`

---

### Task H2: Verify log creation for grade upserts

**Files to modify:** `lib/database/daos/exams_grades_dao.dart`
**Context files to read:** `lib/database/tables/logs.dart`, `lib/database/tables/enums.dart`
**Depends on:** None
**Parallel group:** PH1

**Specification:**
`upsertGrade` and `bulkUpsertGrades` methods must write to the `logs` table with `SyncAction.markGrades` and appropriate payloads. If not, teacher grade entries will be lost on sync.

**Fix:**
Same as H1 — verify and add log creation if missing.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: verify and add sync log creation for grade upserts"`

---

## Track I: UI Polish & Edge Cases

---

### Task I1: _ClassTimetableView uses SchoolConfig.defaults() instead of actual school config

**Files to modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** `lib/models/school_config.dart`
**Depends on:** None
**Parallel group:** PI1

**Specification:**
Both `_TeacherTimetableView` and `_ClassTimetableView` have a TODO comment and set `_config = SchoolConfig.defaults()`. Slot durations, day start/end times, and subject names may not match the school's actual configuration.

**Fix:**
Load the school's actual config from the database (if stored) or from the school's row data. If no school config table exists yet, this may need to wait — but at minimum, document the TODO and ensure defaults are reasonable.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: load actual school config instead of defaults in timetable"`

---

### Task I2: NoTermsBlankState shows same message for all roles

**Files to modify:** `lib/ui/widgets/no_terms_blank_state.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PI1

**Specification:**
The `role` parameter is accepted but unused. Students see *"Contact the school owner to get started"* which is confusing since they have no relationship with "the owner".

**Fix:**
Customize the message per role:
- Owner: "Create your first term to get started"
- Teacher: "No terms have been created yet. Contact the school administrator."
- Student: "The school hasn't set up terms yet. Check back later."
- Guardian: "The school hasn't set up the academic calendar yet."
- Staff: "No academic terms configured. Contact the school owner."

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "ui: customize NoTermsBlankState message per role"`

---

### Task I3: MembershipEntry subtypes missing operator== and hashCode

**Files to modify:** `lib/models/membership.dart`
**Context files to read:** `lib/models/school_context.dart`
**Depends on:** None
**Parallel group:** PI1

**Specification:**
None of the `MembershipEntry` sealed subtypes (`OwnerEntry`, `TeacherEntry`, `StaffEntry`, `StudentEntry`, `GuardianEntry`) implement `operator ==` or `hashCode`. `SchoolContext.switchEntry()` relies on reference identity. Any code that reconstructs entries (e.g., a future stream re-emit from `watchMemberships`) would silently break the `if (currentEntry.value == entry) return` guard.

**Fix:**
Implement `operator ==` and `hashCode` for each subtype based on their data fields:
- `OwnerEntry`: compare by `owner.id`
- `TeacherEntry`: compare by `teacher.id`
- `StaffEntry`: compare by `staff.id`
- `StudentEntry`: compare by `student.adm`
- `GuardianEntry`: compare by `guardian.id` + `ward.adm`

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: implement operator== and hashCode for MembershipEntry subtypes"`

---

### Task I4: Role-switcher sheet — staff shows empty subtitle, guardian shows no ward image

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read:** `lib/ui/widgets/student_avatar.dart`
**Depends on:** None
**Parallel group:** PI2

**Specification:**
In `_RoleSwitcherSheet._entryMeta`:
1. `StaffEntry() => (Icons.badge_outlined, 'Staff', '')` — empty subtitle. Should show department or role title from `StaffData`.
2. `GuardianEntry` uses generic `Icons.family_restroom_outlined` instead of the ward's cached profile image.

**Fix:**
1. For `StaffEntry`, show the staff member's department or role as subtitle.
2. For `GuardianEntry`, use `StudentAvatar` for the ward's image.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "ui: fix staff subtitle and guardian ward image in role-switcher sheet"`

---

### Task I5: Guardian overview — no "View All" navigation links from summary cards

**Files to modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PI2

**Specification:**
Multiple summary cards on the guardian overview (finance summary, today's schedule, recent grades) have no tap action or "View All" link that would navigate to the corresponding full tab.

**Fix:**
Add `onTap` handlers to summary cards that programmatically switch to the appropriate tab index (e.g., tapping the finance summary switches to the Finance tab).

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "ui: add View All navigation links to guardian overview cards"`

---

### Task I6: Guardian mastery tab watches global subject catalog without school scoping

**Files to modify:** `lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read:** `lib/database/daos/catalog_dao.dart`
**Depends on:** None
**Parallel group:** PI2

**Specification:**
The mastery tab (~L1078–1082) calls `CatalogDao.watchSubjects()` and `db.select(db.topics).watch()` which return the **entire global catalog** — showing subjects from other curricula that aren't relevant to the ward's school.

**Fix:**
Filter subjects and topics by the school's curriculum type (CBC or 8-4-4) and optionally by the ward's enrolled grade level.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: filter guardian mastery subjects by school curriculum"`

---

### Task I7: Orphaned guardian row silently dropped in memberships DAO

**Files to modify:** `lib/database/daos/memberships_dao.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PI3

**Specification:**
When a guardian row references a student that doesn't exist in the `students` table, the row is silently skipped (`if (ward == null) continue`) with no diagnostic logging.

**Fix:**
Add `debugPrint('MembershipsDao: Guardian ${guardian.id} references missing student ${guardian.student} — skipping')` for debuggability.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "fix: add debug logging for orphaned guardian rows in memberships DAO"`

---

### Task I8: Dead tab index constants in system dashboard

**Files to modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read:** None
**Depends on:** None
**Parallel group:** PI3

**Specification:**
Several tab index constants (~L31–47) are annotated with `// ignore: unused_element`, indicating they were defined but never referenced.

**Fix:**
Either use these constants in the tab logic (preferred — makes code more readable) or remove them entirely to reduce dead code.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Git commit: `git add -A && git commit -m "chore: remove or use dead tab index constants in system dashboard"`

---

## Track Summary

| Track | Description | Tasks | Critical/High |
|-------|-------------|-------|---------------|
| **A** | Permission & Security Foundations | A1–A5 | 5 Critical/High |
| **B** | Student Experience (Broken) | B1–B8 | 3 Critical, 2 High |
| **C** | Guardian Experience | C1–C7 | 2 High |
| **D** | Teacher RBAC & Data Scoping | D1–D8 | 4 Critical/High |
| **E** | Staff RBAC & Data Scoping | E1–E6 | 3 Critical |
| **F** | Owner Missing Features | F1–F9 | 3 Critical/High |
| **G** | System Dashboard | G1–G7 | 2 High |
| **H** | Data Sync & Log Integrity | H1–H2 | 2 High |
| **I** | UI Polish & Edge Cases | I1–I8 | 0 (all Medium/Low) |

**Total: 52 tasks** (deduplicated from 116 raw findings)

## Recommended Execution Order

1. **Track A (A1→A2→A3→A4, A5)** — Fix permission foundations first. Everything else depends on RBAC working.
2. **Track B (B1–B8 in parallel)** + **Track E (E1–E6 in parallel)** — Student is completely broken; Staff has critical security gaps.
3. **Track D (D1–D8 in parallel)** — Teacher RBAC data scoping.
4. **Track C (C1–C7 in parallel)** + **Track F (F1–F9 by dependency)** — Guardian reactivity + Owner missing features.
5. **Track G (G1–G7 in parallel)** + **Track H (H1–H2 in parallel)** — System dashboard + sync verification.
6. **Track I (I1–I8 in parallel)** — Polish last.

## Parallel Group Reference

| Group | Tasks | Can run simultaneously |
|-------|-------|----------------------|
| PA1 | A1, A2 | Yes (A2 depends on A1 making code reachable, but different files) |
| PA2 | A3 | Sequential after PA1 |
| PA3 | A4, A5 | Yes (different files) |
| PB1 | B1, B2, B3 | Yes (different files) |
| PB2 | B4, B5 | Yes (different files, but B5 touches same file as B4 — sequence if needed) |
| PB3 | B6, B7, B8 | Yes (different files) |
| PC1 | C1, C2 | Yes (different files) |
| PC2 | C3, C4 | Yes (different files) |
| PC3 | C5, C6, C7 | Yes (different files) |
| PD1 | D1, D2 | Yes (different files) |
| PD2 | D3, D4, D5 | Yes (different files) |
| PD3 | D6, D7, D8 | Yes (different files) |
| PE1 | E1, E2, E3 | Yes (different files) |
| PE2 | E4, E5, E6 | Yes (different files) |
| PF1 | F1, F2 | Yes (F1 depends on B5 for same file) |
| PF2 | F3, F4 | Yes (different files) |
| PF3 | F5, F6 | Yes (different files) |
| PF4 | F7, F8, F9 | Yes (different files) |
| PG1 | G1, G2 | Yes (different files) |
| PG2 | G3, G4, G5 | Yes (different files) |
| PG3 | G6, G7 | Yes (different files) |
| PH1 | H1, H2 | Yes (different files) |
| PI1 | I1, I2, I3 | Yes (different files) |
| PI2 | I4, I5, I6 | Yes (different files) |
| PI3 | I7, I8 | Yes (different files) |