# TASKS.md

## Track F (Fix) — Functional Fixes

### Task F1: Fix My Classes screen not reacting to entry switch
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/my_classes/my_classes_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart` (reference for ValueListenableBuilder pattern)
**Depends on:** None
**Parallel group:** P1

**Specification:**

The `_MyClassesBody` widget reads `currentEntry.value` in a getter (`_userId` at ~L58) but does NOT wrap its `build()` in a `ValueListenableBuilder<MembershipEntry>`. If the user switches teacher entries via the role switcher, the screen continues showing data for the original teacher.

Fix:
1. In `_MyClassesBodyState.build()`, wrap the outermost return in:
```dart
return ValueListenableBuilder<MembershipEntry>(
  valueListenable: widget.schoolContext.currentEntry,
  builder: (context, entry, _) {
    final userId = entry is TeacherEntry ? entry.teacher.user : '';
    // ... rest of build using userId instead of _userId getter
  },
);
```
2. Remove the `_userId` getter since it's replaced by the local variable inside the builder.
3. Ensure all `StreamBuilder`s that depend on `userId` are inside the `ValueListenableBuilder` so they rebind when the entry changes.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F2: Fix N+1 `watchSubjects()` streams in Guardian Progress Exams tab ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

In `_ExamsTab`, every subject/paper row inside every `_ExamCard` creates its own `StreamBuilder<List<Subject>>` calling `CatalogDao(db).watchSubjects()` (~L960-971). With 3 exams × 6 subjects = 18 simultaneous identical streams.

Fix:
1. Hoist a single `StreamBuilder<List<Subject>>` to the `_ExamsTab` level (above the exam list).
2. Build a lookup map `Map<int, String> subjectNames` from the subjects list.
3. Pass `subjectNames` down to each `_ExamCard` widget as a parameter.
4. Inside `_ExamCard`, replace the per-row `StreamBuilder<List<Subject>>` with a simple synchronous lookup: `final name = subjectNames[g.subject] ?? 'Subject ${g.subject}';`
5. Remove `CatalogDao(db)` instantiation from inside `_ExamCard`.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F3: Fix N+1 `watchTopicsBySubjectAndGrade()` streams in Guardian Progress Mastery tab ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

Each `_MasteryTopicRow` creates its own `StreamBuilder` calling `CatalogDao(db).watchTopicsBySubjectAndGrade()` (~L1235-1245). With 5 subjects × 4 topics = 20 simultaneous streams.

Additionally, `grade: 0` is passed as a "wildcard" but the DAO likely does NOT treat 0 as wildcard — it would return only topics for grade 0, meaning **every topic name shows as "Topic {id}"**.

Fix:
1. In `_MasteryTab`, hoist a single stream that loads all topics relevant to the ward. Query all topics for the ward's enrolled grade across all subjects. Use `CatalogDao(db).watchTopics()` or a custom query if needed — OR load topics per subject at the `_MasterySubjectCard` level (one stream per subject, not per topic).
2. Build a lookup map `Map<int, String> topicNames`.
3. Pass `topicNames` down to `_MasteryTopicRow`.
4. Replace the per-row `StreamBuilder` with a synchronous lookup.
5. Fix the `grade: 0` issue by passing the ward's actual enrolled grade. Get it from the enrollment data already available in the parent widget.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F4: Fix quadruple `watchStudentGrades()` subscription on Guardian Progress Overview tab ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

Four widgets on the Overview tab independently subscribe to `ExamsGradesDao(db).watchStudentGrades(schoolId, studentAdm)`:
- `_LatestExamAvgStat` (~L438)
- `_SubjectsCountStat` (~L521)
- `_ClassRankStat` (~L547)
- `_RecentExamResults` (~L679)

That's 4 identical Drift watch queries active simultaneously.

Fix:
1. In `_OverviewTab`, add a single `StreamBuilder<List<Grade>>` wrapping the stat cards and recent exam results:
```dart
StreamBuilder<List<Grade>>(
  stream: ExamsGradesDao(db).watchStudentGrades(schoolId, studentAdm),
  builder: (context, gradeSnap) {
    final grades = gradeSnap.data ?? [];
    // Compute stats from grades
    return Column(children: [
      _StatsGrid(grades: grades, ...),
      _RecentExamResults(grades: grades, ...),
    ]);
  },
)
```
2. Change `_LatestExamAvgStat`, `_SubjectsCountStat`, `_ClassRankStat`, and `_RecentExamResults` from `StreamBuilder`-based widgets to plain widgets that accept pre-computed data (e.g., `List<Grade> grades` or computed values like `double avgPct`, `int subjectCount`, `int rank`).
3. Remove the individual `ExamsGradesDao(db)` instantiations from each of these widgets.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F5: Fix Staff routed to `_AdminFeed` in Announcements without permission check
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

In the announcements screen, `StaffEntry` is unconditionally routed to `_AdminFeed` which shows ALL announcements (unfiltered by audience). Mutation buttons are gated but the data exposure is broader than intended — staff without announcement management permissions see all announcements, not just those targeted at staff.

Fix: Mirror the teacher pattern — route staff to `_AdminFeed` only if they have announcement write permissions:
```dart
StaffEntry() => schoolContext.permissions.canAny(Resource.announcements, [
      Action.create,
      Action.update,
      Action.delete,
    ])
    ? _AdminFeed(schoolContext: schoolContext, termContext: termCtx)
    : _RoleFeed(
        schoolContext: schoolContext,
        termContext: termCtx,
        audienceBit: AudienceBits.staff,
      ),
```

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F6: Add `didUpdateWidget` to `_TeacherClassChips` and `_TeacherUpcomingExams`
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

`_TeacherClassChips` loads `_streamsFuture` in `initState` (~L496-500) but has no `didUpdateWidget` override. If `schoolId` changes while the widget's `State` is reused (same position in tree), the future holds stale data. Same for `_TeacherUpcomingExams` with `_subjectsFuture` (~L671-674).

Fix:
1. In `_TeacherClassChipsState`, add:
```dart
@override
void didUpdateWidget(covariant _TeacherClassChips oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.schoolId != widget.schoolId) {
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }
}
```
2. In `_TeacherUpcomingExamsState`, add a similar override. Since subjects are global (not school-specific), this is less critical but still good practice:
```dart
@override
void didUpdateWidget(covariant _TeacherUpcomingExams oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.schoolId != widget.schoolId) {
    setState(() {
      _subjectsFuture = CatalogDao(db).getSubjects();
    });
  }
}
```

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F7: Add Attendance nav item for Staff with attendance permissions
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

The Staff nav items in `_itemsForRole` (~L319-356) do not include an Attendance nav item. Staff members with `Resource.attendance, Action.read` or `Action.mark` permissions have no way to reach the attendance screen.

Fix: Add a conditional Attendance nav item to the Staff section:
```dart
if (perms.canAny(Resource.attendance, [Action.read, Action.mark]))
  const _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),
```

Place it after the Timetable item and before the Roles item in the Staff list.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task F8: Widen teacher timetable management gate to include Update/Delete
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

The teacher timetable routing (~L122) only checks `Classes.Create` to decide whether to show the management view:
```dart
TeacherEntry() => schoolContext.permissions.can(Resource.classes, Action.create)
    ? _OwnerTimetableShell(...)
    : _TeacherTimetableView(...),
```

A teacher with `Classes.Update` or `Classes.Delete` but NOT `Classes.Create` stays on the personal view and can't manage timetables they're supposed to edit/delete.

Fix: Change the condition to check any management action:
```dart
TeacherEntry() => schoolContext.permissions.canAny(Resource.classes, [
      Action.create,
      Action.update,
      Action.delete,
    ])
    ? _OwnerTimetableShell(...)
    : _TeacherTimetableView(...),
```

**Update after completion:**
- [x] Mark this task `[x]`

---

## Track P (Polish) — Visual & Design Consistency

### Task P1: Fix Guardian Progress dark mode colors to use AppTheme helpers ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P2

**Specification:**

The guardian progress screen manually constructs dark mode colors throughout instead of using the `AppTheme` helpers mandated by §21.

Find-and-replace across the entire file:
1. Replace all `cs.surfaceContainerHighest.withValues(alpha: 0.4)` (and similar alpha variations like 0.25, 0.3) used as container backgrounds → `AppTheme.nestedBg(isDark, cs)` where `isDark = cs.brightness == Brightness.dark`.
2. Replace all `cs.outline.withValues(alpha: 0.08)` (and similar low-alpha outline borders) → `AppTheme.borderColor(isDark, cs)`.
3. For each widget that uses these colors, ensure `isDark` is computed once at the top of the `build` method.

Reference: `my_classes_screen.dart` L546-547 shows the correct pattern:
```dart
final bgColor = AppTheme.nestedBg(isDark, cs);
final border = AppTheme.borderColor(isDark, cs);
```

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P2: Standardize border radii in Guardian Progress screen ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Multiple widgets use non-standard border radius values (6, 10) outside the three-tier system (4, 8, 12).

Fix these specific locations:
- `_StatCard` container: `kCardRadius - 2` (=6) → `AppTheme.kCardRadius` (8)
- `_StatCard` icon box: `6` → `AppTheme.kChipRadius` (4) or `AppTheme.kCardRadius` (8)
- `_EmptyCard` container: `kCardRadius - 2` (=6) → `AppTheme.kCardRadius` (8)
- `_RecentExamResults` item containers: `kCardRadius - 2` (=6) → `AppTheme.kCardRadius` (8)
- `_LoadingShimmer` containers: `6` → `AppTheme.kCardRadius` (8)
- `_ProgressTabBar` outer: `10` → `AppTheme.kCardRadius` (8) or `AppTheme.kModalRadius` (12)
- `_NoTermPlaceholder` icon box: `10` → `AppTheme.kCardRadius` (8)
- `_ExamCard` icon box: `kChipRadius + 2` (=6) → `AppTheme.kCardRadius` (8)
- `_MasterySubjectCard` icon box: `kChipRadius + 2` (=6) → `AppTheme.kCardRadius` (8)

Use the nearest standard token for each.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P3: Fix spacing violations in Guardian Progress screen ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Several spacing values violate §21 guidelines (12-16px internal, 6-8px gaps, never 20-32px internal):

1. `SizedBox(height: 20)` gaps between sections (~L225) → change to `SizedBox(height: 12)`
2. `_NoTermPlaceholder` uses `padding: const EdgeInsets.all(40)` (~L2067) → change to `const EdgeInsets.all(16)` or replace with `EduEmptyState`
3. `_EmptyCard` uses `padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16)` (~L1995) → change to `const EdgeInsets.symmetric(vertical: 16, horizontal: 16)`
4. `SizedBox(height: 80)` bottom padding (~L234) → change to `SizedBox(height: 56)`
5. Review all `SizedBox(height: 20)` occurrences and reduce to 12px where they represent inter-section gaps (not scroll padding).

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P4: Replace `_EmptyCard` and `_NoTermPlaceholder` with `EduEmptyState` ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_empty_state.dart`
**Depends on:** None
**Parallel group:** P2

**Specification:**

The guardian progress screen defines its own `_EmptyCard` (~L1981-2029) and `_NoTermPlaceholder` (~L2055-2090) widgets that are visually inconsistent with the project's standard `EduEmptyState` widget. `_EmptyCard` uses different icon size (40×40 rectangular vs 52×52 circular), different background color, different padding (28px vs 16px), and different font weight.

Fix:
1. Replace all `_EmptyCard(icon: ..., message: ...)` usages with `EduEmptyState(icon: ..., title: ...)`.
2. Replace `_NoTermPlaceholder()` with `EduEmptyState(icon: Icons.calendar_today_outlined, title: 'No terms configured', subtitle: 'Progress data will appear once a term is set up.')`.
3. Add `import '../../../widgets/edu_empty_state.dart';` if not already present.
4. Delete the `_EmptyCard` and `_NoTermPlaceholder` classes once all usages are replaced.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P5: Fix My Classes screen header padding and press scale ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/my_classes/my_classes_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Two minor design violations:

1. Header padding at ~L369 is `EdgeInsets.fromLTRB(20, 14, 16, 2)` — left 20px is asymmetric and outside the 12-16px guideline. Change to `EdgeInsets.fromLTRB(16, 14, 16, 2)`.

2. Press scale animation at ~L515-516 uses `end: 0.97` but §21 mandates `0.95 → 1.0`. Change to `end: 0.95`.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P6: Style the Finance teacher fallback as a proper empty state ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/widgets/edu_empty_state.dart`
**Depends on:** None
**Parallel group:** P2

**Specification:**

When a teacher without finance permissions reaches the finance screen, they see a plain `Center(child: Text('No finance access'))` (~L64-71). This is inconsistent with other empty/fallback states in the app.

Fix: Replace with `EduEmptyState`:
```dart
: EduEmptyState(
    icon: Icons.account_balance_outlined,
    title: 'No finance access',
    subtitle: 'You don\'t have permission to view financial data.',
  ),
```

Add the import for `EduEmptyState` if not already present.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P7: Fix `_WardInfoCard` and `_TimetableSlotCard` showing raw IDs instead of names ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Two widgets display raw integer IDs instead of resolved names:

1. `_WardInfoCard` (~L1822) shows `'Grade ${enrollment.grade} · Stream ${enrollment.stream}'` where `enrollment.stream` is a raw integer. Should resolve the stream name from the `streams` catalog table, similar to how `_TeacherClassChips` resolves stream names via `CatalogDao.getStreamsForSchool()`.

2. `_TimetableSlotCard` (~L393) shows `'Subject ${slot.subject}'` where `slot.subject` is a raw integer ID.

Fix for `_WardInfoCard`:
- Add a `FutureBuilder` or pass resolved stream name from the parent.
- The parent `_GuardianOverview` can load stream names in a `FutureBuilder` and pass them down.
- At minimum, if the stream value is `null` or 0, just show `'Grade ${enrollment.grade}'` without the stream suffix.

Fix for `_TimetableSlotCard`:
- This is an existing widget used across roles (not just guardian). If fixing it requires broader refactoring, defer to a future task. If it accepts a subject name parameter, ensure it's passed correctly.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P8: Fix `_TeacherQuickStats` inconsistent "My Exams" definition ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

`_TeacherQuickStats` "My Exams" stat (~L459) counts exams where `e.teacher.id == userId` (the exam creator). But `_TeacherUpcomingExams` (~L706) filters by `p.invigilator == widget.userId` (the paper invigilator). A teacher who invigilates papers on exams they didn't create sees an inconsistency between these two sections.

Fix: Change the "My Exams" stat to count exams where the teacher is either the creator OR an invigilator on any paper:
```dart
final myExams = allExams.where((e) =>
  e.teacher.id == userId ||
  e.papers.any((p) => p.invigilator == userId)
).length;
```

Or, if `ExamGroup` doesn't expose papers at this level, change the label from "My Exams" to "Created Exams" or "Assigned Exams" for clarity.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P9: Add responsive max-width constraint to Guardian Progress screen ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

The guardian progress screen has zero responsive layout handling. On desktop (≥600px), the entire UI stretches to full width as a single narrow column, wasting horizontal space. Compare with `my_classes_screen.dart` which uses `SliverLayoutBuilder` to switch between grid and list.

Fix:
1. Wrap each tab's `ListView` content in a `Center` + `ConstrainedBox(maxWidth: 680)` to prevent extreme stretching on wide screens:
```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 680),
    child: ListView(
      // ... existing content
    ),
  ),
)
```
2. Apply this to all 4 tab bodies: Overview, Exams, Mastery, Attendance.
3. Optionally, for the Overview tab's stats grid, use a `LayoutBuilder` to switch from 2×2 to a single row of 4 on wider screens.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task P10: Fix border radii in overview_screen.dart new widgets ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/overview/overview_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Several new/modified widgets use `BorderRadius.circular(6)` instead of the standard `AppTheme.kCardRadius` (8.0):

- `_WardInfoCard` container: `6` → `AppTheme.kCardRadius` (8)
- Upcoming exams container: `6` → `AppTheme.kCardRadius` (8)

Leave `_buildClassChip` at `4` (correct per `kChipRadius`) and status badges at `4` (correct).

**Update after completion:**
- [x] Mark this task `[x]`

---

## Track A (Accessibility) — Accessibility & Error Handling

### Task A1: Add StreamBuilder error states to My Classes screen ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/my_classes/my_classes_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P3

**Specification:**

The triple-nested `StreamBuilder` (~L176-186) checks for absence of data but never checks `snap.hasError`. If a database query fails, the loading spinner shows forever.

Fix: Add error checks before the data checks:
```dart
builder: (context, stSnap) {
  if (ctSnap.hasError || stSnap.hasError) {
    return Center(
      child: Text(
        'Failed to load class assignments',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
  if (!ctSnap.hasData && !stSnap.hasData) {
    // ... existing loading spinner
  }
  // ... rest of builder
}
```

Apply the same pattern to the outermost `StreamBuilder` (streams query) as well.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task A2: Replace deprecated `splashRadius` in Guardian Progress screen
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/progress/guardian_progress_screen.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P3

**Specification:**

Two `IconButton` instances use the deprecated `splashRadius` property (~L1627, L1647):
```dart
IconButton(
  icon: Icon(Icons.chevron_left_rounded, size: 22, color: cs.onSurfaceVariant),
  onPressed: onPreviousMonth,
  splashRadius: 18,
),
```

Fix: Replace `splashRadius: 18` with `style`:
```dart
IconButton(
  icon: Icon(Icons.chevron_left_rounded, size: 22, color: cs.onSurfaceVariant),
  onPressed: onPreviousMonth,
  style: IconButton.styleFrom(
    minimumSize: const Size(36, 36),
    padding: const EdgeInsets.all(8),
  ),
),
```

Apply to both the left and right chevron buttons in the attendance calendar month navigation.

**Update after completion:**
- [x] Mark this task `[x]`

---

## Execution Order

### Phase 1 (Parallel Group P1) — Critical functional fixes, all independent files:
- Task F1: My Classes entry switch fix (`my_classes_screen.dart`)
- Task F2: Exams tab N+1 fix (`guardian_progress_screen.dart` — Exams tab area)
- Task F5: Staff announcements routing fix (`announcements_screen.dart`)
- Task F6: didUpdateWidget for overview widgets (`overview_screen.dart`)
- Task F7: Staff attendance nav item (`school_dashboard_screen.dart`)
- Task F8: Teacher timetable management gate (`timetable_screen.dart`)

**Note:** F2, F3, F4 all modify `guardian_progress_screen.dart` — they MUST run sequentially. Run F4 first (Overview tab), then F2 (Exams tab), then F3 (Mastery tab) since they touch different sections. Or combine into one task for a single agent.

### Phase 2 (Parallel Group P2) — Polish, depends on P1 completing:
- Task P1: Guardian Progress dark mode colors (`guardian_progress_screen.dart`)
- Task P2: Guardian Progress border radii (`guardian_progress_screen.dart`)
- Task P3: Guardian Progress spacing (`guardian_progress_screen.dart`)
- Task P4: Replace _EmptyCard/_NoTermPlaceholder with EduEmptyState (`guardian_progress_screen.dart`)
- Task P5: My Classes header padding + press scale (`my_classes_screen.dart`)
- Task P6: Finance teacher fallback styling (`finance_screen.dart`)
- Task P7: Ward info card raw IDs (`overview_screen.dart`)
- Task P8: Teacher quick stats "My Exams" definition (`overview_screen.dart`)
- Task P9: Guardian Progress responsive max-width (`guardian_progress_screen.dart`)
- Task P10: Overview border radii (`overview_screen.dart`)

**Note:** P1, P2, P3, P4, P9 all modify `guardian_progress_screen.dart` — assign to ONE agent. P7, P8, P10 all modify `overview_screen.dart` — assign to ONE agent. P5 and P6 touch separate files — can be separate agents or combined.

### Phase 3 (Parallel Group P3) — Accessibility/minor:
- Task A1: StreamBuilder error states (`my_classes_screen.dart`)
- Task A2: Deprecated splashRadius (`guardian_progress_screen.dart`)