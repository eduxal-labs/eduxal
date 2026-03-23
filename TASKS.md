# TASKS.md

## Track A: Permission-Based Navigation (Dashboard Shell)

### Task A1: Refactor `_itemsForRole` to use permission-based nav items for Teacher
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`, `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Currently `_itemsForRole` returns a hardcoded list of 6 nav items for teachers. Teachers should see the same pages as owners, but gated by their `SchoolPermissions`. The method signature must change to accept the `SchoolPermissions` from the `SchoolContext`.

Change `_itemsForRole(MembershipRole role)` → `_itemsForRole(MembershipRole role, SchoolPermissions perms)`.

For `MembershipRole.teacher`, instead of hardcoded 6 items, build the list dynamically:

```dart
MembershipRole.teacher => [
  // Always visible
  const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
  // My Classes — always visible for teachers (their assigned classes)
  const _NavItem(label: 'My Classes', icon: Icons.class_outlined),
  // Academics — visible if user can read classes or schools
  if (perms.canAny(Resource.classes, [Action.read]) ||
      perms.canAny(Resource.schools, [Action.read, Action.update]))
    const _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
  // Exams & Grades — always visible for teachers (they grade)
  const _NavItem(label: 'Exams & Grades', icon: Icons.assignment_outlined),
  // Members — visible if user can read any member resource
  if (perms.canAny(Resource.teachers, [Action.read]) ||
      perms.canAny(Resource.students, [Action.read]) ||
      perms.canAny(Resource.staff, [Action.read]) ||
      perms.canAny(Resource.owners, [Action.read]))
    const _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
  // Finance — visible if user can read fees or payments
  if (perms.canAny(Resource.fees, [Action.read]) ||
      perms.canAny(Resource.payments, [Action.read]))
    const _NavItem(label: 'Finance', icon: Icons.account_balance_outlined),
  // Announcements — always visible
  const _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
  // Timetable — always visible for teachers
  const _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
  // Attendance — always visible for teachers (they mark)
  const _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),
  // Roles — visible if user can read roles
  if (perms.canAny(Resource.roles, [Action.read]))
    const _NavItem(label: 'Roles', icon: Icons.admin_panel_settings_outlined),
],
```

For `MembershipRole.guardian`, keep the existing 6 items (Overview, Progress, Timetable, Finance, Attendance, Announcements) — guardians don't get permission-based expansion.

For `MembershipRole.staff`, apply similar permission-based gating as teacher but with different defaults:
```dart
MembershipRole.staff => [
  const _NavItem(label: 'Overview', icon: Icons.space_dashboard_outlined),
  if (perms.canAny(Resource.students, [Action.read]))
    const _NavItem(label: 'Students', icon: Icons.groups_outlined),
  if (perms.canAny(Resource.classes, [Action.read]))
    const _NavItem(label: 'Academics', icon: Icons.menu_book_outlined),
  if (perms.canAny(Resource.exams, [Action.read]))
    const _NavItem(label: 'Exams & Grades', icon: Icons.assignment_outlined),
  if (perms.canAny(Resource.teachers, [Action.read]) ||
      perms.canAny(Resource.students, [Action.read]))
    const _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
  if (perms.canAny(Resource.fees, [Action.read]) ||
      perms.canAny(Resource.payments, [Action.read]))
    const _NavItem(label: 'Finance', icon: Icons.account_balance_outlined),
  const _NavItem(label: 'Announcements', icon: Icons.campaign_outlined),
  if (perms.canAny(Resource.classes, [Action.read]))
    const _NavItem(label: 'Timetable', icon: Icons.calendar_view_week_outlined),
  if (perms.canAny(Resource.roles, [Action.read]))
    const _NavItem(label: 'Roles', icon: Icons.admin_panel_settings_outlined),
],
```

For `MembershipRole.owner` and `MembershipRole.student`, keep unchanged.

Update ALL call sites of `_itemsForRole` to pass `widget.schoolContext.permissions`:
- `initState` → line ~217 area
- `_onEntryChanged` → line ~237 area

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note permission-based nav
- [ ] Mark this task `[x]`

---

### Task A2: Gate `NoTermsBlankState` "Create Term" button by permission
**Files to create/modify:** `eduxal/lib/ui/widgets/no_terms_blank_state.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Currently `NoTermsBlankState` shows the "Create Term" CTA only when `role == MembershipRole.owner`. This must change to use permissions.

1. Add a new parameter `canCreateTerm` (bool) to `NoTermsBlankState`:
```dart
class NoTermsBlankState extends StatelessWidget {
  const NoTermsBlankState({
    super.key,
    required this.schoolId,
    required this.role,
    this.canCreateTerm = false,
    this.onTermCreated,
  });
  final String schoolId;
  final MembershipRole role;
  final bool canCreateTerm;
  final VoidCallback? onTermCreated;
```

2. Replace `final isOwner = role == MembershipRole.owner;` with `final isOwner = canCreateTerm;` in the `build` method. This preserves all existing logic — the headline says "Set up your first term" if `canCreateTerm`, else "No terms yet".

3. Update the call site in `school_dashboard_screen.dart` `_buildContentArea` method (around line 460):
```dart
return NoTermsBlankState(
  schoolId: widget.schoolContext.membership.school.id,
  role: entry.role,
  canCreateTerm: entry.role == MembershipRole.owner ||
      widget.schoolContext.permissions.can(Resource.schools, Action.update),
);
```

This way only owners and users with `Schools.Update` permission see the "Create Term" button. Teachers, guardians, students just see the informational message.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/widgets/CONTEXT.md` — note new `canCreateTerm` param
- [ ] Mark this task `[x]`

---

## Track B: Teacher "My Classes" Screen (New)

### Task B1: Create the Teacher "My Classes" screen
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/my_classes/my_classes_screen.dart` (NEW)
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`, `eduxal/lib/database/daos/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Create a new directory `eduxal/lib/ui/screens/school_dashboard/my_classes/` with `my_classes_screen.dart`.

This screen shows the teacher's assigned classes — a filtered view of grade/stream combinations where the teacher is either a class teacher or subject teacher. It's the teacher's equivalent of the Owner's "Academics" page but filtered to their assignments.

The screen layout:
- A list/grid of class cards (grade + stream), each showing:
  - Grade label (e.g. "Grade 7", "Form 3")
  - Stream name (e.g. "East", "West") or "—" if no stream
  - Role indicator: "Class Teacher" chip if class teacher, "Subject Teacher" chip with subject count
  - Student count
- Tapping a card navigates to the existing `GradeDetailPage` with the grade/stream context

**Implementation:**

```dart
import 'package:flutter/material.dart';
import '../../../../database/database.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../../models/school_config.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_empty_state.dart';
import '../../school_dashboard/academics/grade_detail_page.dart';
import '../../../theme/app_theme.dart';
import '../../../../core/app_cache.dart' as cache;

class MyClassesScreen extends StatelessWidget {
  const MyClassesScreen({super.key, required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const Center(child: Text('No active term'));
    }
    return _MyClassesBody(schoolContext: schoolContext, termContext: termCtx);
  }
}
```

The `_MyClassesBody` is a `StatefulWidget` that:

1. Queries the database for the teacher's class assignments:
   - From `class_teachers` table: where `teacher = userId` and `school = schoolId` and `year = term.year` and `term = term.term` → these are classes where the user is class teacher
   - From `subject_teachers` table: where `teacher = userId` and `school = schoolId` and `year = term.year` and `term = term.term` → group by `(grade, stream)` to get distinct class-subject combos with count
   
2. Use `db.subjectsDao.watchSubjects(schoolId, term.year, term.term)` to get all subject_teachers rows for this teacher. Then derive unique (grade, stream) combos.

3. Also use `db.subjectsDao` method or a custom query joining `class_teachers` for the user.

Actually, let's simplify. Use two streams:
- `(db.select(db.classTeachers)..where((t) => t.school.equals(schoolId) & t.teacher.equals(userId) & t.year.equals(term.year) & t.term.equals(term.term))).watch()` for class teacher assignments
- `(db.select(db.subjectTeachers)..where((t) => t.school.equals(schoolId) & t.teacher.equals(userId) & t.year.equals(term.year) & t.term.equals(term.term))).watch()` for subject teacher assignments

Combine into a `_TeacherClass` model:
```dart
class _TeacherClass {
  final int grade;
  final String? stream;
  final bool isClassTeacher;
  final int subjectCount; // number of subjects they teach in this class
  final String gradeLabel; // e.g. "Grade 7" from SchoolConfig
  
  _TeacherClass({
    required this.grade,
    this.stream,
    required this.isClassTeacher,
    required this.subjectCount,
    required this.gradeLabel,
  });
}
```

4. Build the UI as a responsive grid:
   - Desktop (≥ 600px): 2-3 column grid of cards
   - Mobile (< 600px): single column list
   
5. Each card design (following the app's design system):
   - Container with `AppTheme.kCardRadius` border radius
   - Background: `cs.surfaceContainerHighest`
   - Content:
     - Row: Grade label (w500, fontSize 15) + stream chip (if exists)
     - Chips row: "Class Teacher" chip (tinted primary) if applicable, "N subjects" chip
     - Bottom: student count text (w300, fontSize 12.5)
   - `InkWell` with `onTap` → navigate to `GradeDetailPage`

6. Empty state: Use `EduEmptyState` with message "You haven't been assigned to any classes yet" and icon `Icons.class_outlined`.

7. For navigation on tap, use the same pattern as `AcademicsScreen` to navigate to `GradeDetailPage`:
```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => ActiveTermProvider.wrap(
    termContext: termCtx,
    child: GradeDetailPage(
      schoolContext: schoolContext,
      grade: teacherClass.grade,
      initialStream: teacherClass.stream,
    ),
  ),
));
```

Note: Check if `GradeDetailPage` accepts `grade` and `initialStream` params. If it uses `GradeStream` model, adapt accordingly. Read the `GradeDetailPage` constructor to match.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — add my_classes/ entry
- [ ] Mark this task `[x]`

---

### Task B2: Wire "My Classes" into the dashboard content panel
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** None
**Depends on:** Task B1
**Parallel group:** P2

**Specification:**

In `_buildContentPanel` method of `_DashboardShellState`, add a handler for the 'My Classes' label:

```dart
if (item.label == 'My Classes') {
  return MyClassesScreen(schoolContext: widget.schoolContext);
}
```

Add the import at the top:
```dart
import 'my_classes/my_classes_screen.dart';
```

Place this AFTER the 'Overview' check and BEFORE the 'Academics' check (around line 480).

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Track C: Guardian "Progress" Screen (New)

### Task C1: Create the Guardian "Progress" screen
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart` (NEW)
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`, `eduxal/lib/database/daos/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Create a new directory `eduxal/lib/ui/screens/school_dashboard/progress/` with `guardian_progress_screen.dart`.

This screen shows the guardian's ward's academic progress — grades, mastery, exam results. It's essentially a read-only view of the student's academic data, similar to what the Owner sees when drilling into a student from the Academics section, but presented as a standalone page.

The guardian's ward is accessed from `schoolContext.currentEntry.value` cast to `GuardianEntry` → `.ward`.

**Implementation:**

```dart
import 'package:flutter/material.dart';
import '../../../../database/database.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/student_avatar.dart';
import '../../../theme/app_theme.dart';

class GuardianProgressScreen extends StatelessWidget {
  const GuardianProgressScreen({super.key, required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final entry = schoolContext.currentEntry.value;
    if (entry is! GuardianEntry) {
      return const Center(child: Text('Not a guardian entry'));
    }
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const Center(child: Text('No active term'));
    }
    return _ProgressBody(
      schoolContext: schoolContext,
      termContext: termCtx,
      ward: entry.ward,
    );
  }
}
```

The `_ProgressBody` is a `StatefulWidget` with a `TabController` for 4 tabs:
1. **Overview** — Summary: latest exam average, attendance %, mastery progress bar, rank in class
2. **Exams** — List of exams with the ward's scores per paper
3. **Mastery** — Subject-by-subject mastery progress (topics completed / total)
4. **Attendance** — Monthly attendance calendar (reuse the existing `_GuardianAttendanceView` pattern from `attendance_screen.dart`)

**Tab 1 — Overview:**
- Ward identity header: `StudentAvatar` + name + admission number + grade/stream badge
- Stats cards in a 2×2 grid:
  - "Latest Exam" — average score from most recent exam
  - "Class Rank" — position out of N students
  - "Attendance" — present % for current term
  - "Mastery" — overall mastery % (topics completed / total)
- Recent exam results: last 3 exams as compact rows (exam name, date, average score, colored indicator)
- All data from existing DAOs: `db.examsGradesDao`, `db.attendanceDao`, `db.academicsDao`

**Tab 2 — Exams:**
- Use a `StreamBuilder` watching `db.examsGradesDao.watchExamGroups(schoolId, term.year, term.term)`
- For each exam group, show a collapsible card with:
  - Exam name + date header
  - For each paper in the ward's grade: subject name, score/outOf, percentage, grade letter
  - Bottom: exam average, class average, rank
- Query pattern: filter exams to only those with the ward's grade, then for each paper query grades where `student = ward.adm`

**Tab 3 — Mastery:**
- Stream from `db.examsGradesDao` mastery-related queries
- List of subjects the ward is enrolled in (via `subject_teachers` for their grade)
- For each subject: subject name, mastery progress bar (topics mastered / total topics), percentage text
- Color-coded: green ≥70%, amber 40-69%, red <40%

**Tab 4 — Attendance:**
- Reuse the attendance calendar pattern from `attendance_screen.dart`'s `_GuardianAttendanceView`
- Show monthly view with day cells colored by status (present=green, absent=red, leave=amber)
- Summary stats at top: total days, present count, absent count, leave count, percentage

**Design follows the app's conventions:**
- Use `EduTabBar` for the 4 tabs
- Body text: w300/w400, Headings: w500 max
- Cards use `AppTheme.kCardRadius` (8.0)
- Spacing: 12-16px internal, 6-8px gaps
- Data rows use thin dividers (`AppTheme.tableRowDivider`)
- Colors: Use `AppTheme.modalBg`, `AppTheme.nestedBg`, `AppTheme.borderColor` for dark mode

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — add progress/ entry
- [ ] Mark this task `[x]`

---

### Task C2: Wire "Progress" into the dashboard content panel
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** None
**Depends on:** Task C1
**Parallel group:** P2

**Specification:**

In `_buildContentPanel` method of `_DashboardShellState`, add a handler for the 'Progress' label:

```dart
if (item.label == 'Progress') {
  return GuardianProgressScreen(schoolContext: widget.schoolContext);
}
```

Add the import at the top:
```dart
import 'progress/guardian_progress_screen.dart';
```

Place this near the other content panel handlers.

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Track D: Permission-Gating Existing Screens

### Task D1: Permission-gate the Announcements screen
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first to understand the current structure. The Announcements screen currently shows a compose FAB for admin roles (Owner/Staff) and a read-only feed for others.

Changes needed:
1. The compose FAB (for creating announcements) should only be visible if `schoolContext.permissions.can(Resource.announcements, Action.create)` OR if the entry is `OwnerEntry`.
2. Edit/Delete actions on individual announcements should only be visible if `schoolContext.permissions.can(Resource.announcements, Action.update)` / `Action.delete` respectively, OR if the entry is `OwnerEntry`.
3. For Teacher entries: if they have `Announcements.Create` permission, they should see the compose FAB. Without permission, they see read-only feed just like guardians/students.

Find the compose FAB and wrap it:
```dart
final canCreate = entry is OwnerEntry ||
    schoolContext.permissions.can(Resource.announcements, Action.create);
// ... then conditionally show FAB based on canCreate
```

Similarly for edit/delete actions on announcement rows.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

### Task D2: Permission-gate the Timetable screen actions
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. Currently the timetable screen shows Generate/Delete FABs to Owner and Staff entries without any permission check.

Changes needed:
1. The Generate Timetable FAB should only be visible if:
   ```dart
   final canManageTimetable = entry is OwnerEntry ||
       schoolContext.permissions.can(Resource.classes, Action.create);
   ```
2. The Delete Timetable button should only be visible if:
   ```dart
   final canDeleteTimetable = entry is OwnerEntry ||
       schoolContext.permissions.can(Resource.classes, Action.delete);
   ```
3. The Generate Lessons FAB should follow the same pattern as Generate Timetable.
4. For `StaffEntry`, route to `_OwnerTimetableShell` only if they have classes read permission, otherwise show `_ClassTimetableView` for a generic read-only view.
5. For `TeacherEntry` with `Classes.Create` permission, they should also see the `_OwnerTimetableShell` instead of just `_TeacherTimetableView`. Update the entry switch:
   ```dart
   TeacherEntry() => schoolContext.permissions.can(Resource.classes, Action.create)
       ? _OwnerTimetableShell(...)  // Teacher with management permissions
       : _TeacherTimetableView(...), // Regular teacher view
   ```

Pass `schoolContext` to `_OwnerTimetableShell` so it can check permissions for the FABs internally.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

### Task D3: Permission-gate the Finance screen actions
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. Currently the finance screen shows all CRUD buttons to Owner/Staff without permission checks.

Changes needed:
1. Route teacher entries to the admin shell if they have finance permissions:
   ```dart
   return switch (entry) {
     OwnerEntry() => _OwnerFinanceShell(...),
     StaffEntry() => _OwnerFinanceShell(...),
     TeacherEntry() => schoolContext.permissions.canAny(Resource.fees, [Action.read]) ||
                       schoolContext.permissions.canAny(Resource.payments, [Action.read])
         ? _OwnerFinanceShell(...)
         : const Center(child: Text('No finance access')),
     GuardianEntry(:final ward) => _GuardianFinanceView(...),
     _ => _OwnerFinanceShell(...),
   };
   ```

2. Inside `_OwnerFinanceShell`, gate actions by permissions:
   - "New Fee" FAB: visible only if `permissions.can(Resource.fees, Action.create)` or `entry is OwnerEntry`
   - Fee edit/delete actions: gate by `Resource.fees, Action.update/delete`
   - "Generate Invoices" action: gate by `Resource.fees, Action.assign` or `Resource.fees, Action.create`
   - "Record Payment" action: gate by `Resource.payments, Action.create`
   - "Approve Payment" action: gate by `Resource.payments, Action.approve`
   - Payment edit/delete: gate by `Resource.payments, Action.update/delete`

3. Pass `schoolContext` to the finance shell so it can access permissions.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

### Task D4: Permission-gate the Exams & Grades screen actions
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. Currently uses `_canManage` which checks entry type only.

Changes needed:
1. Replace the `_canManage` getter with permission-based checks throughout:
   ```dart
   bool get _canCreateExam =>
       widget.schoolContext.permissions.can(Resource.exams, Action.create) ||
       entry is OwnerEntry;
   
   bool get _canEditExam =>
       widget.schoolContext.permissions.can(Resource.exams, Action.update) ||
       entry is OwnerEntry;
   
   bool get _canDeleteExam =>
       widget.schoolContext.permissions.can(Resource.exams, Action.delete) ||
       entry is OwnerEntry;
   
   bool get _canMarkGrades =>
       widget.schoolContext.permissions.can(Resource.grades, Action.mark) ||
       entry is OwnerEntry || entry is TeacherEntry;
   ```

2. Use these granular checks instead of the blanket `_canManage`:
   - "New Exam" FAB → `_canCreateExam`
   - Edit exam name → `_canEditExam`
   - Delete exam → `_canDeleteExam`
   - Add paper / update paper → `_canCreateExam` or `_canEditExam`
   - Grade marking → `_canMarkGrades`

3. Teachers should ALWAYS be able to mark grades for their assigned subjects (this is core teacher functionality). So `_canMarkGrades` includes `entry is TeacherEntry` as a fallback.

4. Pass `schoolContext` through to inner widgets that need permission checks. Currently `_ExamsShell` receives `schoolContext` — make sure it's propagated to `_ExamsListView` and `_ExamGroupDetailView`.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

### Task D5: Permission-gate the Members page actions
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. The Members page has 6 tabs (Departments, Owners, Teachers, Staff, Students, Guardians) with FABs and row actions.

Changes needed:
1. Gate tab visibility by permissions. Teachers/Staff should only see tabs for member types they have read access to:
   ```dart
   final perms = schoolContext.permissions;
   final isOwner = entry is OwnerEntry;
   
   final tabs = <(String label, Widget tab)>[
     if (isOwner || perms.can(Resource.departments, Action.read))
       ('Departments', _DepartmentsTab(...)),
     if (isOwner || perms.can(Resource.owners, Action.read))
       ('Owners', _OwnersTab(...)),
     if (isOwner || perms.can(Resource.teachers, Action.read))
       ('Teachers', _TeachersTab(...)),
     if (isOwner || perms.can(Resource.staff, Action.read))
       ('Staff', _StaffTab(...)),
     if (isOwner || perms.can(Resource.students, Action.read))
       ('Students', _StudentsTab(...)),
     if (isOwner || perms.can(Resource.students, Action.read))
       ('Guardians', _GuardiansTab(...)),
   ];
   ```

2. Gate the "Add Member" FAB per tab by corresponding create permission:
   - Add Owner → `Resource.owners, Action.create`
   - Add Teacher → `Resource.teachers, Action.create`
   - Add Staff → `Resource.staff, Action.create`
   - Add Student → `Resource.students, Action.create`
   - Add Guardian → `Resource.students, Action.assign` (assigning a guardian to a student)

3. Gate row actions (edit, delete, status change) by corresponding update/delete permissions.

4. Pass `schoolContext` to each tab widget so they can check permissions internally.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

### Task D6: Permission-gate the Academics screen actions
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/academics/academics_screen.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. Currently all CRUD buttons are always visible.

Changes needed:
1. Pass `schoolContext` to `_AcademicsGradeTree` if not already passed.
2. Gate the "Add Grade" FAB:
   ```dart
   final canCreate = entry is OwnerEntry ||
       schoolContext.permissions.can(Resource.classes, Action.create);
   ```
3. Gate "Add Stream" button on grade cards by same check.
4. Gate "Edit Streams" button by:
   ```dart
   final canEdit = entry is OwnerEntry ||
       schoolContext.permissions.can(Resource.classes, Action.update);
   ```
5. Gate "Delete Grade" button by:
   ```dart
   final canDelete = entry is OwnerEntry ||
       schoolContext.permissions.can(Resource.classes, Action.delete);
   ```
6. For teachers who reach this page via permission-based nav expansion, they should see grade/stream cards as read-only (tappable for drill-down) unless they have specific create/update/delete permissions.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

### Task D7: Permission-gate the Roles screen
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/roles/school_roles_screen.dart`
**Context files to read (if needed):** `eduxal/lib/models/permissions.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. The roles screen may already have some permission checks (from the grep results showing `perms.can(models.Resource.roles, models.Action.update)`).

Ensure complete coverage:
1. "Create Role" FAB → only if `perms.can(Resource.roles, Action.create)` or `entry is OwnerEntry`
2. Edit role → `Resource.roles, Action.update`
3. Delete role → `Resource.roles, Action.delete`
4. Assign/Unassign user to role → `Resource.roles, Action.assign` / `Action.unassign`
5. If a teacher reaches this page via permission-based nav, they should see the role list in read-only mode unless they have specific permissions.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

## Track E: Guardian Ward-Scoped Views

### Task E1: Ensure Guardian Finance view is ward-scoped
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file to verify the `_GuardianFinanceView` correctly receives `ward` data and scopes all queries to `ward.adm`. Based on the agent report, it already does (`GuardianEntry(:final ward) => _GuardianFinanceView(...)`).

Verify:
1. Invoice queries filter by `student = ward.adm`
2. Payment queries filter by `student = ward.adm`
3. Fee display shows only fees applicable to the ward's grade
4. The balance card shows the ward's specific balance, not school-wide totals

If any of these are missing, add the correct filters. The guardian should see ONLY their ward's financial data.

Also ensure the `ValueListenableBuilder` on `schoolContext.currentEntry` is used so that when a guardian switches wards (via role switcher), the finance view updates reactively.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task E2: Ensure Guardian Timetable is ward-scoped
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

Verify that the Guardian entry in the timetable screen correctly scopes to the ward's class timetable:

```dart
GuardianEntry(:final ward) => _ClassTimetableView(
  schoolId: ...,
  grade: ward.grade,    // ward's enrolled grade
  stream: ward.stream,  // ward's enrolled stream
  ...
),
```

The ward's grade and stream should come from the ward's enrollment data. Verify the `_ClassTimetableView` queries timetable entries for the correct `(school, year, term, grade, stream)` combination.

If the ward switches (via role switcher from guardian of child A → guardian of child B), the timetable should update.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task E3: Ensure Guardian Attendance is ward-scoped
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

Verify the attendance screen correctly uses `GuardianEntry(:final ward)` → `ward.adm` to scope attendance queries. The existing code already does:
```dart
GuardianEntry(:final ward) => _GuardianAttendanceView(
  schoolContext: schoolContext,
  termContext: termCtx,
  studentAdm: ward.adm,
  studentName: ward.name,
),
```

Verify this updates reactively when the guardian switches wards. If the attendance screen is a `StatelessWidget` that reads `schoolContext.currentEntry.value` in `build`, it will rebuild automatically via the `ValueListenableBuilder` in the dashboard shell. If it caches the ward reference, ensure it listens to `schoolContext.currentEntry`.

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Track F: Guardian Overview Enhancement

### Task F1: Enhance Guardian Overview with richer ward data
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

The current `_GuardianOverview` is functional but basic. Enhance it to be more informative and visually consistent with the Owner/Teacher overviews.

Read the current `_GuardianOverview` (lines 1090-1168) and `_WardInfoCard` (lines 1170-1271).

Improvements:
1. **Add a 2×2 quick stats grid** (like `_OwnerQuickStats` / `_TeacherQuickStats`) showing:
   - "Attendance" — current term attendance percentage with color indicator
   - "Latest Exam" — average from most recent exam
   - "Subjects" — number of subjects the ward is enrolled in
   - "Rank" — class rank from latest exam (or "—" if unavailable)
   
   Use the existing `_StatCard` widget pattern (lines 1678-1743) for consistency.

2. **Add "Today's Schedule" section** — reuse the `_StudentTodaySchedule` widget (lines 770-840) which already exists for the student overview. The guardian should see their ward's schedule:
   ```dart
   if (term != null) ...[
     _SectionTitle(label: "Today's Schedule", cs: cs),
     const SizedBox(height: 8),
     _StudentTodaySchedule(
       schoolId: schoolId,
       year: term.year,
       term: term.term,
       studentAdm: ward.adm,
     ),
     const SizedBox(height: 20),
   ],
   ```
   Place this after the ward info card and before the attendance section.

3. **Improve `_WardInfoCard`** — add the ward's grade/stream label as a chip badge, and show the ward's `StudentAvatar` (cached image) if available.

4. Ensure all sections use the ward's `adm` for data queries, not the guardian's user id.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

## Track G: Teacher Overview Enhancement

### Task G1: Enhance Teacher Overview with richer data
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

The current `_TeacherOverview` (lines 214-279) shows welcome, today's schedule, quick stats, and announcements. Enhance it to be more useful.

Read the current implementation and the `_TeacherQuickStats` (lines 401-453) and `_TeacherTodaySchedule` (lines 281-330).

Improvements:
1. **Add "My Classes" summary** — a compact row of class chips showing the teacher's assigned grades/streams. Each chip is tappable to navigate to that class's detail. Place after Today's Schedule:
   ```dart
   _SectionTitle(label: 'My Classes', cs: cs),
   const SizedBox(height: 8),
   _TeacherClassChips(
     schoolId: schoolId,
     userId: userId,
     term: term,
     schoolContext: schoolContext,
   ),
   ```

2. **Implement `_TeacherClassChips`** — a new widget that:
   - Queries `class_teachers` and `subject_teachers` for the teacher's assignments
   - Displays a `Wrap` of compact chips (grade label + stream)
   - Each chip is tappable → navigates to `GradeDetailPage`
   - Uses `AppTheme.kChipRadius` (4.0), fontSize 12, w400
   - Color: primary-tinted for class teacher, surfaceContainerHighest for subject teacher
   - Shows "Class Teacher" or "N subjects" as subtitle on the chip

3. **Add "Upcoming Exams" section** — show the next 2-3 upcoming exams where the teacher is an invigilator or has papers to grade:
   ```dart
   _SectionTitle(label: 'Upcoming Exams', cs: cs),
   const SizedBox(height: 8),
   _TeacherUpcomingExams(schoolId: schoolId, userId: userId, term: term),
   ```
   Query `exams` + `papers` where `invigilator = userId` and `status < completed`, ordered by date. Show exam name, date, paper subject, status badge.

4. Keep the existing sections (Welcome, Today's Schedule, Quick Stats, Announcements) but reorder:
   - Welcome card
   - Today's Schedule
   - My Classes chips
   - Quick Stats (2×2 grid)
   - Upcoming Exams
   - Recent Announcements

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`

---

## Track H: TermSelectorChip Permission Gating

### Task H1: Gate term creation in TermSelectorChip
**Files to create/modify:** `eduxal/lib/ui/widgets/term_selector_chip.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Read the file first. The `TermSelectorChip` is shown in the sidebar/rail/top bar and allows switching terms. It may also have a "Create Term" option in its dropdown/picker.

If there's a "Create Term" or "Add Term" action inside the term selector:
1. Add a `canCreateTerm` parameter (bool, default false)
2. Only show the create action when `canCreateTerm` is true
3. Update the call site in `school_dashboard_screen.dart` to pass:
   ```dart
   canCreateTerm: entry.role == MembershipRole.owner ||
       widget.schoolContext.permissions.can(Resource.schools, Action.update),
   ```

If the term selector is purely for switching (no create action), then this task is a no-op — just verify and mark done.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/widgets/CONTEXT.md` if changed
- [ ] Mark this task `[x]`

---

## Execution Order

### Phase 1 (Parallel Group P1) — All independent, can run simultaneously:
- Task A1: Permission-based nav items
- Task A2: NoTermsBlankState permission gate
- Task B1: My Classes screen (new file)
- Task C1: Guardian Progress screen (new file)
- Task D1: Announcements permission gate
- Task D2: Timetable permission gate
- Task D3: Finance permission gate
- Task D4: Exams permission gate
- Task D5: Members permission gate
- Task D6: Academics permission gate
- Task D7: Roles permission gate
- Task E1: Guardian finance ward-scoping verification
- Task E2: Guardian timetable ward-scoping verification
- Task E3: Guardian attendance ward-scoping verification
- Task F1: Guardian overview enhancement
- Task G1: Teacher overview enhancement
- Task H1: TermSelectorChip permission gate

### Phase 2 (Parallel Group P2) — Depends on P1:
- Task B2: Wire My Classes into dashboard (depends on B1)
- Task C2: Wire Progress into dashboard (depends on C1)

### Notes:
- Tasks in P1 touching different files can safely run in parallel.
- Tasks A1 and B2/C2 both modify `school_dashboard_screen.dart` — A1 must complete first, then B2 and C2 can run together since they modify different methods (A1 touches `_itemsForRole`, B2/C2 touch `_buildContentPanel`).
- D1–D7 each touch separate screen files — fully parallelizable.
- E1–E3 each touch separate screen files — fully parallelizable.
- F1 and G1 both modify `overview_screen.dart` — they should NOT run in parallel. Run F1 first, then G1 (or vice versa).