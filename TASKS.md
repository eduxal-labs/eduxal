# TASKS.md — Staff Dashboard RBAC-Gating

> **Feature:** Permission-gate the staff dashboard so that staff members only see navigation items, overview stats, and member tabs that their assigned roles allow.
>
> **Key constraint:** The `SchoolPermissions` aggregation model is correct — it unions all roles from all scopes for the user at the school. The issue is that the staff **Overview** renders all stat sections unconditionally (no permission checks), the **Members** nav item misses some resource checks, and the **Members page** has a fallback that shows all tabs when none match.
>
> **Commit rule:** Every executor agent MUST run `git add -A && git commit -m "<type>: <description>"` immediately after completing its task. Do NOT defer commits. Types: `feat`, `fix`, `refactor`, `ui`, `docs`, `chore`.

---

## Track 0: Commit Uncommitted Changes

### Task 00: Commit any uncommitted changes before starting work ✅
**Files to modify:** None (git operation only)
**Depends on:** None
**Parallel group:** P0

**Specification:**
Before starting any work, commit the existing uncommitted changes:
```
git add -A && git commit -m "chore: commit pending changes before staff dashboard RBAC work"
```

**Expected outcome:** Clean working tree. All previous work preserved.

**Commit:** This task IS the commit.

---

## Track A: Staff Navigation Refinement

### Task A1: Fix Members nav item condition for staff to include all member resources ✅
**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 00
**Parallel group:** P1

**Specification:**

In `_itemsForRole()` (around line 272), the `MembershipRole.staff` branch (lines 316–348) has a Members nav item gated by:

```dart
if (perms.canAny(Resource.teachers, [Action.read]) ||
    perms.canAny(Resource.students, [Action.read]))
  const _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
```

This only checks `teachers.read` and `students.read`. A staff member whose role grants `Resource.staff.read`, `Resource.owners.read`, or `Resource.departments.read` (but NOT `teachers.read` or `students.read`) would not see the Members nav item, even though they have valid member-related permissions.

**Change:** Expand the condition to include ALL member-related resources:

```dart
if (perms.canAny(Resource.departments, [Action.read]) ||
    perms.canAny(Resource.owners, [Action.read]) ||
    perms.canAny(Resource.teachers, [Action.read]) ||
    perms.canAny(Resource.staff, [Action.read]) ||
    perms.canAny(Resource.students, [Action.read]))
  const _NavItem(label: 'Members', icon: Icons.people_alt_outlined),
```

This matches the member resources that the Members page uses for tab visibility (see `members_page.dart` lines 91–103).

**No other changes to this file.** The rest of the staff nav items are already correctly permission-gated.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note the Members nav item condition change under the staff role section
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: expand staff Members nav item to check all member resources"`

---

## Track B: Staff Overview Permission-Gating

### Task B1: Permission-gate `_StaffOverview` and make `_StaffQuickStats` dynamic
**Files to modify:** `lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/models/permissions.dart` (for `Resource` and `Action` enums), `lib/models/school_context.dart`
**Depends on:** Task 00
**Parallel group:** P1

**Specification:**

Currently, `_StaffOverview` (lines 1070–1115) and `_StaffQuickStats` (lines 1117–1215) render all stat sections unconditionally — Students count, Invoices count, Collection rate, Pending payments — regardless of the staff member's permissions. A staff member with only `attendance.read` would still see finance stats they shouldn't have access to.

**Goal:** Make the staff overview dynamically show only the stat cards the user's permissions allow, and show an appropriate state when no stats are available.

#### Step 1: Pass `SchoolPermissions` into `_StaffQuickStats`

Change `_StaffQuickStats` constructor from:
```dart
const _StaffQuickStats({required this.schoolId, required this.term});
```
to:
```dart
const _StaffQuickStats({
  required this.schoolId,
  required this.term,
  required this.permissions,
});
```
Add field: `final SchoolPermissions permissions;`

Update the call site in `_StaffOverview.build()` (around line 1102) to pass `permissions: schoolContext.permissions`.

You will also need to add the import for `SchoolPermissions` and `Resource`/`Action` if not already imported. The file already imports `school_context.dart` (line 21) so `SchoolContext` is available. Add:
```dart
import '../../../../models/permissions.dart';
import '../../../../models/school_permissions.dart';
```

#### Step 2: Rebuild `_StaffQuickStats` as a dynamic permission-gated grid

Replace the current hardcoded 2×2 grid with a dynamic list of stat cards built from a permission→card mapping. The widget should:

1. Build a `List<Widget>` of stat cards, where each card is only added if the user has the relevant permission:

   | Permission check | Stat card |
   |---|---|
   | `permissions.can(Resource.students, Action.read)` | Students count — `StreamBuilder<List<StudentsData>>` via `membersDao.watchStudents(schoolId)` — icon: `Icons.groups_outlined`, tint: `Color(0xFF3F51B5)` |
   | `permissions.can(Resource.teachers, Action.read)` | Teachers count — `StreamBuilder<List<TeachersData>>` via `membersDao.watchTeachers(schoolId)` — icon: `Icons.school_outlined`, tint: `Color(0xFF009688)` |
   | `permissions.can(Resource.staff, Action.read)` | Staff count — `StreamBuilder<List<StaffData>>` via `membersDao.watchStaff(schoolId)` — icon: `Icons.badge_outlined`, tint: `Color(0xFFFF9800)` |
   | `permissions.can(Resource.fees, Action.read) \|\| permissions.can(Resource.payments, Action.read)` | Invoices count — `StreamBuilder<TermFinanceSummary>` via `financeDao.watchTermFinanceSummary(...)` — icon: `Icons.receipt_long_outlined`, tint: `Color(0xFFFF9800)` |
   | `permissions.can(Resource.fees, Action.read) \|\| permissions.can(Resource.payments, Action.read)` | Collection rate — same `watchTermFinanceSummary` stream — icon: `Icons.account_balance_outlined`, tint: `Color(0xFF4CAF50)` |
   | `permissions.can(Resource.fees, Action.read) \|\| permissions.can(Resource.payments, Action.read)` | Pending payments — same `watchTermFinanceSummary` stream — icon: `Icons.pending_actions_outlined`, tint: `Color(0xFFF44336)` |
   | `permissions.can(Resource.exams, Action.read)` | Active exams — `StreamBuilder` via `ExamsGradesDao(db).watchExamsForTerm(schoolId: schoolId, year: term.year, term: term.term)` counting the list length — icon: `Icons.assignment_outlined`, tint: `Color(0xFF7C4DFF)` |
   | `permissions.can(Resource.classes, Action.read)` | Classes count — `StreamBuilder<List<({int grade, int stream})>>` via `EnrollmentsDao(db).watchPopulatedClasses(schoolId: schoolId, year: term.year, term: term.term)` — icon: `Icons.class_outlined`, tint: `Color(0xFF7C4DFF)` |

2. For finance cards: to avoid creating the `watchTermFinanceSummary` stream multiple times, extract the finance check into a local bool:
   ```dart
   final canFinance = permissions.can(Resource.fees, Action.read) ||
       permissions.can(Resource.payments, Action.read);
   ```
   Then wrap all three finance cards in a single outer `StreamBuilder<TermFinanceSummary>` that returns a `Column` or `Row` of the three cards. This avoids 3 redundant stream subscriptions (which was already a minor inefficiency in the current code).

3. Arrange the cards in a 2-column grid using `Wrap` or manual `Row` pairs. The simplest approach: collect all visible card widgets into a `List<Widget>`, then arrange them in `Row` pairs:
   ```dart
   final cards = <Widget>[...]; // only permission-gated cards
   if (cards.isEmpty) return const SizedBox.shrink();

   final rows = <Widget>[];
   for (var i = 0; i < cards.length; i += 2) {
     if (i + 1 < cards.length) {
       rows.add(Row(children: [
         Expanded(child: cards[i]),
         const SizedBox(width: 10),
         Expanded(child: cards[i + 1]),
       ]));
     } else {
       rows.add(Row(children: [
         Expanded(child: cards[i]),
         const SizedBox(width: 10),
         const Expanded(child: SizedBox.shrink()),
       ]));
     }
     if (i + 2 < cards.length) rows.add(const SizedBox(height: 10));
   }
   return Column(children: rows);
   ```

   **Important implementation detail:** The finance cards are special because they share a single stream. The recommended approach is: build a list of "card descriptors" (each being a widget), but for the finance group, wrap all 3 finance cards in a single `StreamBuilder` that returns a `Column` containing a `Row` of the first two + another `Row` for the third. However, for simplicity and to keep the 2-column grid uniform, you can also treat each finance card independently — each with its own `StreamBuilder` on the same stream (Drift deduplicates watch queries internally so this is not a real performance concern). Choose whichever is cleaner.

#### Step 3: Update `_StaffOverview.build()` to conditionally show the Quick Stats section

Currently (line 1099):
```dart
if (term != null) ...[
  _SectionTitle(label: 'Quick Stats', cs: cs),
  const SizedBox(height: 8),
  _StaffQuickStats(schoolId: schoolId, term: term),
  const SizedBox(height: 20),
],
```

Change to:
```dart
if (term != null && _hasAnyStatPermission(schoolContext.permissions)) ...[
  _SectionTitle(label: 'Quick Stats', cs: cs),
  const SizedBox(height: 8),
  _StaffQuickStats(
    schoolId: schoolId,
    term: term,
    permissions: schoolContext.permissions,
  ),
  const SizedBox(height: 20),
],
```

Add a helper method (can be a local function or a top-level helper near `_StaffOverview`):
```dart
bool _hasAnyStatPermission(SchoolPermissions perms) {
  return perms.can(Resource.students, Action.read) ||
      perms.can(Resource.teachers, Action.read) ||
      perms.can(Resource.staff, Action.read) ||
      perms.can(Resource.fees, Action.read) ||
      perms.can(Resource.payments, Action.read) ||
      perms.can(Resource.exams, Action.read) ||
      perms.can(Resource.classes, Action.read);
}
```

This ensures the entire "Quick Stats" section title and spacing are hidden when the staff member has no stat-relevant permissions (e.g., only `announcements.read`).

#### Step 4: Add a "limited access" hint when no stats are visible

If the staff member has zero stat-relevant permissions AND no current term, the overview would show only the welcome card + announcements. This is fine — but add a small hint between the welcome card and announcements:

```dart
if (term == null || !_hasAnyStatPermission(schoolContext.permissions)) ...[
  const SizedBox(height: 12),
  Text(
    'Your dashboard shows features based on your assigned role.',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
      fontStyle: FontStyle.italic,
    ),
  ),
  const SizedBox(height: 12),
],
```

This is a subtle, non-alarming message that helps staff members understand why their overview might look sparse.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note that `_StaffOverview` and `_StaffQuickStats` are now permission-gated
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: permission-gate staff overview stats based on assigned roles"`

---

## Track C: Members Page Hardening

### Task C1: Replace empty-tabs fallback with empty state in members_page.dart
**Files to modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 00
**Parallel group:** P1

**Specification:**

In `_MembersPageBodyState.initState()` (line 106), there is a fallback:
```dart
// Fallback: if somehow no tabs are visible, show all.
if (_visibleTabs.isEmpty) _visibleTabs = _MemberTab.values;
```

This is a permission bypass — if a staff member somehow reaches the Members page with no member-read permissions, they'd see ALL six tabs. This shouldn't happen in practice (the nav item is hidden), but it's defense-in-depth.

**Change 1:** Remove the fallback line entirely. Replace with a comment:
```dart
// If no tabs are visible, the page shows an empty state.
// This shouldn't happen because the Members nav item is
// hidden when no member-read permissions exist.
```

**Change 2:** In `build()`, add an early return for the empty case. Find where `_visibleTabs` is used to build the `TabBar` / `TabBarView`. Before that, add:

```dart
if (_visibleTabs.isEmpty) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outlined,
            size: 48,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No member access',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your role does not include permissions to view members.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    ),
  );
}
```

Where `cs` is the current `ColorScheme` — obtain via `Theme.of(context).colorScheme`.

**Change 3:** Guard the `TabController` creation. Since `TabController(length: 0)` would throw, wrap it:

In `initState()`, change from:
```dart
_currentTab = _visibleTabs.first;
_tabController = TabController(length: _visibleTabs.length, vsync: this)
  ..addListener(_onTabChanged);
```
to:
```dart
if (_visibleTabs.isNotEmpty) {
  _currentTab = _visibleTabs.first;
  _tabController = TabController(length: _visibleTabs.length, vsync: this)
    ..addListener(_onTabChanged);
}
```

And make `_tabController` nullable: `TabController? _tabController;`
And make `_currentTab` nullable: `_MemberTab? _currentTab;`

Guard the `dispose()` method:
```dart
@override
void dispose() {
  _tabController
    ?..removeListener(_onTabChanged)
    ..dispose();
  super.dispose();
}
```

Guard `_onTabChanged` and `_canCreateForCurrentTab` to handle the null case.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note the empty-tabs fallback removal
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: replace members page empty-tabs fallback with empty state"`

---

## Track D: CONTEXT.md Updates

### Task D1: Update CONTEXT.md files for all tracks
**Files to modify:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Tasks A1, B1, C1
**Parallel group:** P2 (run last)

**Specification:**

Final pass to ensure the school dashboard CONTEXT.md reflects the changes:

1. Under the staff navigation section, note that the Members nav item now checks ALL 5 member resources (`departments`, `owners`, `teachers`, `staff`, `students`).

2. Under the overview section, note that `_StaffOverview` and `_StaffQuickStats` are now permission-gated. Each stat card only renders when the corresponding resource permission is present. A "limited access" hint shows when no stat-relevant permissions exist.

3. Under the members page section, note that the empty-tabs fallback has been replaced with an empty state widget displaying "No member access". `TabController` and `_currentTab` are now nullable to support the zero-tabs case.

4. Update the `## Last Updated` line to reference this task.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "docs: update CONTEXT.md for staff dashboard RBAC-gating changes"`

---

## Dependency Graph Summary

```
Task 00 (commit pending)
  ├─► Task A1 (fix Members nav)     ─┐
  ├─► Task B1 (permission-gate overview) ─┼─► Task D1 (CONTEXT.md)
  └─► Task C1 (members page fallback) ─┘
```

## Parallel Execution Groups

| Group | Tasks | Notes |
|---|---|---|
| P0 | 00 | Commit — blocks everything |
| P1 | A1, B1, C1 | All touch different files — can run fully in parallel |
| P2 | D1 | CONTEXT update — run last after all code tasks |