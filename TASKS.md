# EduXal — Task Board

> **Workflow:** Examiner writes tasks → Orchestrator dispatches → Executor implements.
> Each task is self-sufficient. The executor should not need to explore the codebase.

## Parallelisation Guide

- Tasks within the same **Parallel Group** (e.g. `P1`) can run simultaneously.
- Tasks with **Depends on** must wait for the dependency to complete.
- The orchestrator should maximise parallel execution where possible.
- After every task (or parallel batch), run `git add -A && git commit -m "<type>: <description>"`.

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 0 — Pre-Flight: Commit Current State
## ═══════════════════════════════════════════════════════════════════════════

### Task 000: Commit current uncommitted state [x]
**Files to create/modify:** None (git only)
**Context files to read:** None
**Depends on:** Nothing
**Parallel group:** —

**Specification:**
Already done by the examiner. The current state has been committed with message:
`docs: update AGENT.md to three-agent workflow (examiner, orchestrator, executor)`

**Update after completion:**
- [x] Mark this task `[x]`

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 1 — Design System Extraction & Codification
## ═══════════════════════════════════════════════════════════════════════════

These tasks extract the implicit design patterns from the UI files the user likes
(Account page, User detail sheet, Role detail screen, School detail screen,
Create term modal) and codify them into reusable widgets and tokens.

---

### Task 101: Codify EduXal Design System into shared widget library [x]
**Files to create/modify:** `lib/ui/widgets/edu_sheet.dart`, `lib/ui/widgets/edu_dialog.dart`, `lib/ui/widgets/edu_form_field.dart`, `lib/ui/widgets/edu_section_card.dart`, `lib/ui/widgets/edu_detail_header.dart`, `lib/ui/widgets/edu_empty_state.dart`, `lib/ui/widgets/edu_confirm_dialog.dart`, `lib/ui/widgets/edu_filter_toolbar.dart`, `lib/ui/widgets/edu_search_field.dart`, `lib/ui/theme/app_theme.dart`
**Context files to read:** `lib/ui/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`
**Depends on:** Nothing
**Parallel group:** —

**Specification:**

The user has identified the following UI screens as the "gold standard":
- **Account page** (`account_screen.dart`) — section containers, row builders, dividers, theme toggle
- **User detail sheet** (`user_detail_sheet.dart`) — sheet handle, header with avatar+dot, section cards, action rows, copyable info rows
- **Role detail screen** (`role_detail_screen.dart`) — entrance animation, NestedScrollView, pinned tab bar, change bar, detail chips
- **School detail screen** (`school_detail_screen.dart`) — settings cards, curriculum toggle, edit sheets, county picker
- **Create term modal** (`create_term_modal.dart`) — responsive dialog/sheet entry point, field labels, error banners, confirm button

Extract the following **reusable** widgets:

#### 1. `EduSheet` — Standard bottom sheet wrapper
```dart
class EduSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final VoidCallback? onClose;
  final bool showHandle;  // default true
  final double? maxHeight; // fraction of screen, default 0.9
  
  // Renders: modalBg background, kModalRadius top corners,
  // _SheetHandle (36×4px pill), optional title row with close button,
  // child content.
}

/// Convenience launcher — desktop: dialog, mobile: bottom sheet
Future<T?> showEduSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  String? title,
  double maxWidth = 480, // for desktop dialog
});
```

#### 2. `EduDialog` — Standard dialog wrapper  
```dart
class EduDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final double maxWidth; // default 440
  
  // Renders: modalBg, kModalRadius, modalShadow, 1px borderColor border,
  // constrained width, title row.
}
```

#### 3. `EduFormField` — Standard form text field
```dart
class EduFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;       // 9.5px uppercase w600 letterSpacing:0.9 @0.55
  final String? hint;
  final String? error;      // renders error banner below field
  final TextInputType? keyboardType;
  final String? prefixText;
  final int maxLines;       // default 1
  final bool obscureText;
  final Widget? suffix;
  
  // Renders: _FieldLabel above, TextFormField with filled decoration
  // using surfaceContainerLow (light) / Color(0xFF1E2A3A) (dark),
  // borderRadius: kCardRadius, thin border.
}
```

#### 4. `EduSectionCard` — Bordered section container (from account screen pattern)
```dart
class EduSectionCard extends StatelessWidget {
  final List<Widget> children;
  final String? title;     // optional section header
  final Widget? trailing;  // optional trailing widget in header
  
  // Renders: Container with surfaceContainer fill, kCardRadius,
  // 0.5px border, thin dividers between children.
}
```

#### 5. `EduDetailHeader` — Detail page header with avatar and metadata chips
```dart
class EduDetailHeader extends StatelessWidget {
  final Widget avatar;     // UserAvatar or school logo
  final String title;
  final String? subtitle;
  final List<Widget> chips; // _DetailChip list
  final List<Widget>? actions; // trailing action buttons
}

class EduDetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  // surfaceContainerHighest@0.4, borderRadius:4, 0.5px border
}
```

#### 6. `EduEmptyState` — Centered empty state (already exists but standardize)
```dart
class EduEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;  // optional CTA button
  // Icon: 32px in 52×52 tinted circle, title 13.5px w500, subtitle 12px w400
}
```

#### 7. `EduConfirmDialog` — Standard confirmation dialog
```dart
class EduConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmLabel;  // default "Confirm"
  final String cancelLabel;   // default "Cancel"
  final Color? confirmColor;  // default cs.error for destructive
  final bool isDestructive;   // default false
  
  // Returns Future<bool> — true if confirmed
}

Future<bool> showEduConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool isDestructive = false,
});
```

#### 8. `EduFilterToolbar` — Search + filter toolbar for data tables
```dart
class EduFilterToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final List<EduFilterChipData> filters;
  final bool showSearch;       // animated toggle
  final VoidCallback onToggleSearch;
  final VoidCallback? onToggleFilters;
  final bool showFilters;      // collapsible filter panel
  
  // Renders: Row with search icon toggle, animated search field,
  // filter icon toggle. Below: collapsible filter chip rows.
}

class EduFilterChipData {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;
}
```

#### 9. `EduSearchField` — Animated inline search field
```dart
class EduSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool expanded;  // animated width transition
  
  // 32px height, kCardRadius, surfaceContainerHighest fill,
  // 13px text, search icon prefix, clear button suffix when not empty
}
```

#### 10. Add to `AppTheme`
Add the following new tokens/helpers:
```dart
// Standard entrance animation parameters
static const Duration kEntranceAnimDuration = Duration(milliseconds: 350);
static const Offset kEntranceSlideOffset = Offset(0, 0.03);

// Action icon colors (from role detail screen)
static const Color actionRead = Color(0xFF42A5F5);     // blue
static const Color actionCreate = Color(0xFF66BB6A);    // green  
static const Color actionUpdate = Color(0xFFFFA726);    // orange
static const Color actionDelete = Color(0xFFEF5350);    // red
static const Color actionPurge = Color(0xFFAB47BC);     // purple
static const Color actionAssign = Color(0xFF26C6DA);    // cyan
static const Color actionMark = Color(0xFF5C6BC0);      // indigo
static const Color actionApprove = Color(0xFF66BB6A);   // green

// Status colors
static const Color statusActive = Color(0xFF4CAF50);
static const Color statusInvited = Color(0xFF42A5F5);
static const Color statusSuspended = Color(0xFFFF9800);
static const Color statusDeleted = Color(0xFFEF5350);
static const Color statusTrial = Color(0xFF66BB6A);
static const Color statusCancelled = Color(0xFF9E9E9E);

// Level badge specs
static const IconData levelNormalIcon = Icons.circle;       // 6px dot
static const IconData levelSystemIcon = Icons.shield_outlined; // shield
static const IconData levelSuperIcon = Icons.star_rounded;     // star
```

**Update after completion:**
- [x] Update `lib/ui/widgets/CONTEXT.md` — add entries for all new widget files
- [x] Update `lib/ui/CONTEXT.md` — note new design system tokens in AppTheme
- [x] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: codify design system into reusable widget library"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 2 — Enhanced EduDataTable with Selection, Search, Filters
## ═══════════════════════════════════════════════════════════════════════════

### Task 201: Overhaul `EduDataTable` with multi-select, search, filters, and new row design [x]
**Files to create/modify:** `lib/ui/widgets/edu_data_table.dart`
**Context files to read:** `lib/ui/widgets/CONTEXT.md`
**Depends on:** Task 101 (for `EduFilterToolbar`, `EduSearchField`)
**Parallel group:** —

**Specification:**

Redesign `EduDataTable<T>` to match the reference table image (table.webp). The image shows:
- Clean white card container with very subtle border/shadow (~8px radius)
- Column headers: ALL-CAPS, 11-12px, letter-spaced, muted gray-blue (#8B8FA3)
- Rows: 48-52px height, separated by very thin hairline dividers (~0.5px, #E8E9EF)
- No alternating row colors — all same background
- Airy but not wasteful spacing
- Cool desaturated palette

**New features to add:**

#### A. Selection Mode
```dart
// Add to EduDataTable constructor:
final bool selectable;                    // default false — shows checkboxes
final Set<T> selectedItems;              // currently selected items (controlled)
final ValueChanged<Set<T>>? onSelectionChanged;
final bool Function(T)? itemSelectable;  // can this item be selected?

// Selection bar appears above the table when items are selected:
// "[N] selected" label + bulk action buttons provided by caller
final List<EduDataTableAction<T>>? bulkActions;
```

When `selectable: true`:
- Each row gets a leading 18×18 checkbox (rounded 4px, indigo when checked)
- Header row gets a "select all / deselect all" checkbox
- A selection bar animates in above the table showing count + bulk action buttons
- Checkbox column is 40px wide

#### B. Integrated Search & Filters
```dart
// Add to EduDataTable constructor:
final String? searchHint;
final TextEditingController? searchController;
final ValueChanged<String>? onSearchChanged;
final List<EduFilterChipData>? filters;
```

When provided, renders `EduFilterToolbar` above the column headers.

#### C. Row Avatar/Icon with Level Badge
The existing row builder pattern stays but the recommended pattern for identity cells becomes:

```dart
// Helper widget for identity cells with level/status baked in:
class EduIdentityCell extends StatelessWidget {
  final Widget avatar;           // UserAvatar or logo
  final String title;
  final String? subtitle;
  final UserLevel? level;        // renders badge on avatar
  final UserStatus? status;      // colors the badge
  final Color? statusColor;      // override for non-user statuses
}
```

The level badge renders as:
- `UserLevel.normal` → 6px filled circle (dot) on bottom-right of avatar
- `UserLevel.system` → 14px shield icon on bottom-right
- `UserLevel.super_` → 14px star icon on bottom-right

Badge color = status color (active=green, suspended=orange, deleted=red, invited=blue).

#### D. Row tap and hover
- `InkWell` on the entire row — tap navigates to detail page
- Hover: `AnimatedContainer(100ms)` background → `cs.primary.withValues(alpha: 0.04)`
- Remove the "View" icon button — tapping the row IS the view action
- Action buttons appear on hover (desktop) or via three-dot (mobile) — unchanged

#### E. Smart Contextual Action Buttons
Actions are filtered per-item based on the item's state. The caller provides a `actionsBuilder` instead of a static list:
```dart
// Replace:
final List<EduDataTableAction<T>>? actions;
// With:
final List<EduDataTableAction<T>> Function(T item)? actionsBuilder;
```

This allows the caller to return different actions based on the item state (e.g., no "suspend" button on an already-suspended user).

#### F. Updated Styling
- Column headers: 11px, `FontWeight.w600`, `letterSpacing: 0.8`, ALL-CAPS, `onSurfaceVariant.withValues(alpha: 0.55)`
- Row height: `ConstrainedBox(minHeight: 52)`
- Dividers: 0.5px, `outlineVariant.withValues(alpha: 0.15)` (very faint)
- No table title bar (user explicitly said "without the tile header")
- Card container: subtle 0.5px border, `kCardRadius`, no heavy shadow

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md` — update `edu_data_table.dart` entry with new features
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul EduDataTable with selection, search, filters, and contextual actions"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 3 — System Dashboard: Tab Styling + Settings Tab
## ═══════════════════════════════════════════════════════════════════════════

### Task 301: Restyle system dashboard tabs to match school dashboard members page tabs [x]
**Files to create/modify:** `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Nothing
**Parallel group:** P3

**Specification:**

Currently the system dashboard uses a raw `TabBar` or custom tab styling. The school dashboard's Members page (`members_page.dart`) uses `EduTabBar` — the elevated shadow-based indicator with tinted background container. The system dashboard tabs need to use the exact same `EduTabBar` widget.

**Changes:**

1. **Desktop layout:** Replace the current sticky tab bar with `EduTabBar`:
   - Tabs: `Users`, `Members`, `Schools`, `Roles`, `Settings`
   - Use `EduTabBar(controller: _tabController, tabs: [...])` with text tabs
   - Position it the same way the members page positions its tabs

2. **Mobile layout:** Replace the current `TabBar` in the mobile AppBar/body with `EduTabBar`:
   - Same 5 tabs (previously was 6 with Home; Home/Stats should remain as the landing page visible on desktop stats panel, but on mobile it becomes the first tab)
   - Mobile tabs: `Home`, `Users`, `Members`, `Schools`, `Roles`, `Settings`
   - Use `EduTabBar(controller: _mobileTabController, tabs: [...], isScrollable: true)` for mobile since 6 tabs won't fit

3. **Add Settings tab index:**
   - Desktop: index 4 maps to `SystemSettingsScreen` (already exists)
   - Mobile: index 5 maps to `SystemSettingsScreen`
   - Currently `SystemSettingsScreen` is pushed as a separate page — now it should be an inline tab instead

4. **Settings content:** Instead of pushing to `SystemSettingsScreen`, render its content inline in the tab body. The `SystemSettingsScreen` itself contains a `_SegmentedControl` with Plans/Subjects tabs and their section widgets. Inline this content directly:
   ```dart
   // In the tab body for Settings:
   _SettingsTabBody(permissions: permissions)
   ```
   Create `_SettingsTabBody` as a private widget that contains:
   - An inner `EduTabBar` with 2 tabs: `Plans`, `Subjects`
   - `TabBarView` switching between `PlansSection` and `SubjectsSection`
   - This creates nested tabs (outer: system dashboard tabs, inner: settings sub-tabs)

5. **Remove the old Settings push route:** The FAB or button that previously pushed `SystemSettingsScreen` should be removed. Settings is now always visible as a tab.

**Imports needed:**
```dart
import 'settings/subjects_section.dart';
import 'plans/plans_section.dart';
```

The `SystemSettingsScreen` file can be kept for now (not deleted) in case it's referenced elsewhere, but it's no longer the primary entry point.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note tab restructuring, Settings tab addition
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: restyle system dashboard tabs with EduTabBar and add Settings tab"`

---

### Task 302: Add Plans CRUD to Settings > Plans tab (verify/enhance existing PlansSection) [x]
**Files to create/modify:** `lib/ui/screens/system/plans/plans_section.dart`, `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** Task 201 (for enhanced EduDataTable), Task 301 (for Settings tab)
**Parallel group:** —

**Specification:**

The `PlansSection` already exists and has full CRUD (create, read, update, delete, purge) via `PlansDao`. It uses `EduDataTable<Plan>` and is a `StatelessWidget` — already embeddable as a tab body (no Scaffold/AppBar). This task fills the remaining gaps.

**Research findings — current gaps:**
- ❌ No search/filter on the plans list
- ❌ The mobile FAB for creating plans is NOT wired up in `SystemDashboardScreen` (line ~218 has a comment: `// createPlan FAB action deferred until Task 11 extracts CreatePlanSheet.`)
- ✅ The `openCreatePlan()` top-level function exists and works
- ✅ Full CRUD is present in `PlansDao`: `createPlan`, `updatePlan`, `updatePlanStatus`, `purgePlan`

**Changes:**

1. **Wire up the FAB:** In `system_dashboard_screen.dart`, wire the `_FabAction.createPlan` case in `_onFabAction` to call `openCreatePlan(context, _permissions)`. Remove the deferral comment.

2. **Add search:** Add an `EduFilterToolbar` (or simpler search field) above the plans list to filter by plan name. Currently `PlansSection` receives all plans from `plansDao.watchAllPlans()` and filters deleted plans client-side — add a search controller and filter by `plan.name.toLowerCase().contains(query)`.

3. **Add status filter chips:** Filter by plan status: Active, Suspended, Deleted (if super).

4. **Ensure the data table uses the new `actionsBuilder` pattern** (from Task 201) so that actions are contextual per plan status (e.g., can't delete an already-deleted plan, can only purge if super).

5. **Add a FAB to PlansSection itself** (for when it's rendered inside the Settings tab, where the system dashboard's top-level FAB may not be relevant): Green `FloatingActionButton.small` with `Icons.add_rounded`, tooltip "New Plan", calling `openCreatePlan(context, permissions)`. Use a `Scaffold(floatingActionButton: ...)` wrapper or `Stack` overlay.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note Plans enhancements
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: enhance PlansSection for Settings tab with FAB and search"`

---

### Task 303: Enhance Subjects & Topics CRUD in Settings > Subjects tab [x]
**Files to create/modify:** `lib/ui/screens/system/settings/subjects_section.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** Task 201 (for enhanced EduDataTable), Task 301 (for Settings tab)
**Parallel group:** —

**Specification:**

The `SubjectsSection` already exists (~2378 lines) with **full CRUD for both subjects AND topics**, all wired to `CatalogDao`. This task is about ensuring design system consistency, NOT adding missing CRUD.

**Research findings — current state (all working):**
- ✅ `SubjectsSection` is a `StatefulWidget` with no Scaffold/AppBar — embeddable as tab body
- ✅ Create subject: `_showCreateSubject()` → `_CreateSubjectSheet` → `catalogDao.createSubject()`
- ✅ Edit subject: `_showEditSubject()` → `_EditSubjectSheet` → `catalogDao.updateSubject()`
- ✅ Delete subject: `_deleteSubject()` → confirmation → `catalogDao.deleteSubject()`
- ✅ Create topic: `_showCreateTopic()` → `_CreateTopicSheet` → `catalogDao.createTopic()`
- ✅ Edit topic: `_showEditTopic()` → `_EditTopicSheet` → `catalogDao.updateTopic()`
- ✅ Delete topic: `_deleteTopic()` → confirmation → `catalogDao.deleteTopic()`
- ✅ Search: `_searchVisible` toggle + `_SearchField` filters subjects by name
- ✅ Curriculum toggle: CBC / 8-4-4 filter via `_CurriculumToggle`
- ✅ Expandable rows: `_SubjectTile` expands to show `_TopicsPanel` → grade chips → `_TopicList`
- ✅ Permission gating: `_canCreate`, `_canEdit`, `_canDelete` from `SystemPermissions`
- ❌ No FAB — uses an inline `+` icon button in the header instead
- ❌ Create/edit sheets use custom private widgets, not the shared `EduSheet`/`EduFormField`

**Changes (design consistency only):**

1. **Add a FAB:** Green `FloatingActionButton.small` with `Icons.add_rounded`, tooltip "New Subject". On tap → `_showCreateSubject()` (already exists). Use `Stack` to overlay on the existing content.

2. **Migrate create/edit sheets to use shared design widgets:**
   - Replace `_CreateSubjectSheet` / `_EditSubjectSheet` / `_CreateTopicSheet` / `_EditTopicSheet` to use `showEduSheet` for responsive dialog/sheet entry
   - Replace internal text fields with `EduFormField`
   - Replace confirmation dialogs with `showEduConfirmDialog`
   - Keep all the existing validation logic and DAO calls unchanged

3. **Ensure the expandable subject list rows match the new data table aesthetic:**
   - Thin dividers between rows
   - Hover highlight on desktop
   - Consistent typography (13px w500 name, 12px w400 subtitle)

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note Subjects enhancements
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: enhance SubjectsSection for Settings tab with design system consistency"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 4 — Critical Bug Fix: Subject-Teacher Assignment
## ═══════════════════════════════════════════════════════════════════════════

### Task 401: Fix subject-teacher assignment using real `subjects` table instead of enum indices [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`
**Context files to read:** `lib/database/daos/CONTEXT.md`, `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Nothing
**Parallel group:** P4

**Specification:**

**Bug:** On school dashboard → Academics → click grade → stream tab → subjects tab → assign subject teacher → select subject → select teacher → infinite loading.

**Root cause:** The `_SubjectTeacherPickerSheet` in `grade_detail_page.dart` (line ~1716) uses the `_subjectsForGrade()` method (line ~1759) which builds subject candidates from **hardcoded enum indices** (`CbcSubject` / `EightFourFourSubject` in `curriculum_subjects.dart`). These are NOT real database records — they are legacy enum values retained only for label display.

The schema was migrated to use a normalized `subjects` table (auto-increment `int` PK) with FK constraint `FOREIGN KEY (subject) REFERENCES subjects(id)` on `subject_teachers`, but the UI still uses the old hardcoded enum indices. These enum index values (e.g. `CbcSubject.englishLanguage.index_ = 3`) have NO relationship to the auto-increment `subjects.id` values in the real table. The result is either a FK violation or a silent failure/hang.

**Critical type information (from research):**
- `subjects.id` is `IntColumn` with `autoIncrement()` — Dart type **`int`**
- `subject_teachers.subject` is `IntColumn` — Dart type **`int`**
- `SubjectsDao.assignSubjectTeacher` takes `subject` as **`int`**
- `SubjectsDao.getSubjectAssignment` takes `subject` as **`int`**
- `CatalogDao.watchSubjectsByCurriculum(CurriculumType)` returns `Stream<List<Subject>>` — already exists
- The `Subject` Drift data class has `int id` and `String name`

So the column types are correct (`int` → `int`), but the VALUES are wrong (enum indices vs real auto-increment IDs).

**Fix:**

1. **Replace `_subjectsForGrade()` with a query to the real `subjects` table:**

   The `CatalogDao` already has:
   ```dart
   Stream<List<Subject>> watchSubjectsByCurriculum(CurriculumType curriculum)
   ```
   This returns all subjects for a curriculum from the real `subjects` table. No new DAO method needed.

2. **Rewrite `_loadSubjects()`:**
   Instead of building candidates from hardcoded enum indices, query the `subjects` table:
   ```dart
   Future<void> _loadSubjects() async {
     setState(() => _loadingSubjects = true);
     
     // Query real subjects from the catalog table (replaces _subjectsForGrade())
     final catalogDao = CatalogDao(db);
     final subjectsStream = catalogDao.watchSubjectsByCurriculum(widget.curriculumType);
     final subjectsList = await subjectsStream.first;
     if (!mounted) return;
     
     // Get currently assigned subject-teachers for this class
     final assignedStream = _subjectsDao.watchSubjectsForClass(
       schoolId: widget.schoolId,
       year: widget.year,
       term: widget.term,
       grade: widget.grade,
       stream: widget.streamCode,
     );
     final assignedList = await assignedStream.first;
     if (!mounted) return;
     
     // Build assigned map: subject int ID → teacher name
     final assignedMap = <int, String>{};
     for (final entry in assignedList) {
       // entry.subject is SubjectTeacher row — its .subject field is int (FK → subjects.id)
       // entry.teacher is UsersData
       assignedMap[entry.subject.subject] = entry.teacher.name;
     }
     
     // Build candidate list from REAL subjects
     final candidates = <_SubjectCandidate>[];
     for (final subject in subjectsList) {
       candidates.add(_SubjectCandidate(
         subjectId: subject.id,              // int — real auto-increment ID
         subjectName: subject.name,          // String — from subjects table
         assignedTeacherName: assignedMap[subject.id],
       ));
     }
     
     if (!mounted) return;
     setState(() {
       _allSubjects = candidates;
       _filteredSubjects = candidates;
       _loadingSubjects = false;
     });
   }
   ```

3. **Update `_SubjectCandidate` class:**
   ```dart
   class _SubjectCandidate {
     final int subjectId;        // was: int subjectIndex (enum index)
     final String subjectName;   // was: derived from subjectLabel() enum lookup
     final String? assignedTeacherName;
     
     _SubjectCandidate({
       required this.subjectId,
       required this.subjectName,
       this.assignedTeacherName,
     });
   }
   ```
   The type stays `int` but the semantic changes from "hardcoded enum index" to "real subjects.id auto-increment value".

4. **Update `_selectSubject` and `_loadTeachers`:**
   - Change `_selectedSubjectIndex` to `_selectedSubjectId` (rename for clarity — type stays `int?`)
   - In `_loadTeachers`, the call to `_subjectsDao.getSubjectAssignment(subject: ...)` should pass the real `subjectId` (still `int`, no type change needed)

5. **Update `_assign()`:**
   ```dart
   await _subjectsDao.assignSubjectTeacher(
     schoolId: widget.schoolId,
     year: widget.year,
     term: widget.term,
     grade: widget.grade,
     stream: widget.streamCode,
     subject: _selectedSubjectId!,  // int — now a real subjects.id, not enum index
     teacherUserId: candidate.teacher.user,
     accountId: accountId,
   );
   ```
   No DAO method signature changes needed — `assignSubjectTeacher` already takes `int subject`.

6. **Remove the `_subjectsForGrade()` method entirely** — it's no longer needed (it computed valid enum indices from hardcoded `kCbcLevels`/`k844Levels`).

7. **Remove the `subjectLabel()` import** — subject names now come from `Subject.name`, not from the enum label lookup.

8. **Add `CatalogDao` import:**
   ```dart
   import '../../../../../database/daos/catalog_dao.dart';
   ```

9. **Handle empty subjects table gracefully:** If no subjects exist in the catalog yet, show an empty state message: "No subjects available. System administrators can add subjects in Settings → Subjects."

10. **Remove unused imports** after the change: `curriculum_subjects.dart` (for `CbcSubject`), `curriculum_levels.dart` (for `levelsFor`, `subjectLabel`) — only if no other code in the file uses them.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note bug fix in grade_detail_page
- [ ] Update `lib/database/daos/CONTEXT.md` — if DAO methods were changed
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "fix: subject-teacher assignment uses real subjects table instead of enum indices"`

---

### Task 402: Update `subjectLabel()` callers to handle real subject names [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/tabs/subjects_tab.dart`, `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`, `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`, `lib/models/curriculum_levels.dart`, `lib/database/daos/academics_dao.dart`, `lib/models/grade_analytics.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** Task 401
**Parallel group:** —

**Specification:**

After Task 401, subject identifiers in the `subject_teachers` table are now real `int` auto-increment IDs from the `subjects` table, NOT hardcoded enum indices. Several files still call `subjectLabel(curriculumType, intIndex)` which looks up labels from the `CbcSubject`/`EightFourFourSubject` enums. These need to be updated to look up names from the `subjects` table instead.

**Critical type info:** `subject_teachers.subject` is `IntColumn` (Dart `int`), and `subjects.id` is also `IntColumn` with autoIncrement (Dart `int`). The FK is `FOREIGN KEY (subject) REFERENCES subjects(id)`. So the column type is `int` throughout — but the VALUES are now real subject IDs, not enum indices.

**Files that use `subjectLabel()`:**

1. **`subjects_tab.dart`** (line ~226): `final label = subjectLabel(widget.curriculumType, entry.subject.subject);`
   - The `SubjectTeacherEntry.subject` is a `SubjectTeacher` row. Its `.subject` field is `int` (FK → `subjects.id`).
   - Instead of calling `subjectLabel(type, int)` (which looks up hardcoded enum labels), we need the actual subject name from the `subjects` table.
   - **Recommended approach:** Extend the `AcademicsDao.watchSubjectsForGrade()` query to JOIN with the `subjects` table and return the name. Update `SubjectTeacherEntry` in `lib/models/grade_analytics.dart`:
     ```dart
     class SubjectTeacherEntry {
       final SubjectTeacher subject;
       final UsersData teacher;
       final String subjectName;  // ADD THIS — from subjects.name via JOIN
       final double? streamMasteryAverage;
       final double? gradeMasteryAverage;
     }
     ```
   - In `AcademicsDao.watchSubjectsForGrade()`, add `innerJoin(subjects, subjects.id.equalsExp(subjectTeachers.subject))` and select `subjects.name`.
   - Then in `subjects_tab.dart`, replace:
     ```dart
     final label = subjectLabel(widget.curriculumType, entry.subject.subject);
     ```
     with:
     ```dart
     final label = entry.subjectName;
     ```

2. **`exams_grades_screen.dart`** (line ~9961): Uses `CbcSubject.values.firstWhere(...)` to look up labels.
   - This is used to display subject names on paper slots and exam detail views.
   - Replace with a lookup from the `subjects` table. Options:
     a) Pass subject name through the data model (preferred — add `subjectName` to relevant models)
     b) Do a one-shot `CatalogDao(db).getSubject(subjectId)` lookup and cache the results
   - The executor should choose the approach that minimises queries while keeping code clean.

3. **`timetable_screen.dart`** (line ~2451): Same pattern — `CbcSubject.values.firstWhere(...)`.
   - Same fix as above.

4. **`curriculum_levels.dart`** (line ~338): The `subjectLabel()` function itself.
   - **Deprecate** but don't delete yet — some parts of the app may still use it as a fallback.
   - Add a `@Deprecated('Use subjects table name instead')` annotation.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Update `lib/models/CONTEXT.md` — note SubjectTeacherEntry change
- [ ] Update `lib/database/daos/CONTEXT.md` — note AcademicsDao join change
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "refactor: replace enum-based subject labels with real subjects table lookups"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 5 — System Dashboard Data Tables Overhaul
## ═══════════════════════════════════════════════════════════════════════════

### Task 501: Overhaul Users section data table [x]
**Files to create/modify:** `lib/ui/screens/system/users/users_section.dart`, `lib/ui/screens/system/users/user_detail_sheet.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Task 201 (enhanced EduDataTable), Task 101 (design system)
**Parallel group:** P5

**Specification:**

Redesign the Users section to match the new data table style and the user's requirements:

1. **Remove status/level columns** — already done per CONTEXT.md. Status and level are baked into the avatar badge. Verify this is working correctly:
   - Normal → small circle dot on avatar bottom-right
   - System → shield icon on avatar bottom-right  
   - Super → star icon on avatar bottom-right
   - Badge color = status (active=green `#4CAF50`, invited=blue `#42A5F5`, suspended=orange `#FF9800`, deleted=red `#EF5350`)

2. **Profile photo must be visible:** Use `UserAvatar` on every row — loads from `FileCache.profilePath(userId)`.

3. **Smart contextual action buttons using `actionsBuilder`:**
   ```dart
   actionsBuilder: (user) {
     final actions = <EduDataTableAction<UsersData>>[];
     
     // Promote: only if user is Normal → show "Promote to System"
     if (user.level == UserLevel.normal.index) {
       actions.add(EduDataTableAction(
         icon: Icons.shield_outlined,
         label: 'Promote to System',
         onTap: (_) => _promoteUser(user, UserLevel.system),
         color: AppTheme.actionAssign,
       ));
     }
     
     // Elevate: only if user is System → show "Elevate to Super"
     if (user.level == UserLevel.system.index && permissions.canSeeDeleted) {
       actions.add(EduDataTableAction(
         icon: Icons.star_outline_rounded,
         label: 'Elevate to Super',
         onTap: (_) => _promoteUser(user, UserLevel.super_),
         color: AppTheme.actionApprove,
       ));
     }
     
     // Demote: if System → demote to Normal, if Super → demote to System
     if (user.level == UserLevel.system.index) {
       actions.add(EduDataTableAction(
         icon: Icons.arrow_downward_rounded,
         label: 'Demote to Normal',
         onTap: (_) => _demoteUser(user, UserLevel.normal),
         color: AppTheme.actionUpdate,
       ));
     }
     if (user.level == UserLevel.super_.index && permissions.canSeeDeleted) {
       actions.add(EduDataTableAction(
         icon: Icons.arrow_downward_rounded,
         label: 'Demote to System',
         onTap: (_) => _demoteUser(user, UserLevel.system),
         color: AppTheme.actionUpdate,
       ));
     }
     
     // Suspend: only if active or invited
     if (user.status == UserStatus.active.index || user.status == UserStatus.invited.index) {
       actions.add(EduDataTableAction(
         icon: Icons.block_rounded,
         label: 'Suspend',
         onTap: (_) => _suspendUser(user),
         color: AppTheme.statusSuspended,
         isDestructive: true,
       ));
     }
     
     // Restore: only if suspended
     if (user.status == UserStatus.suspended.index) {
       actions.add(EduDataTableAction(
         icon: Icons.restore_rounded,
         label: 'Restore',
         onTap: (_) => _restoreUser(user),
         color: AppTheme.statusActive,
       ));
     }
     
     // Delete: only if NOT already deleted
     if (user.status != UserStatus.deleted.index) {
       actions.add(EduDataTableAction(
         icon: Icons.delete_outline_rounded,
         label: 'Delete',
         onTap: (_) => _trashUser(user),
         color: AppTheme.actionDelete,
         isDestructive: true,
       ));
     }
     
     // Restore from deleted: only if deleted
     if (user.status == UserStatus.deleted.index) {
       actions.add(EduDataTableAction(
         icon: Icons.restore_rounded,
         label: 'Restore',
         onTap: (_) => _restoreUser(user),
         color: AppTheme.statusActive,
       ));
     }
     
     // Purge: super only, always available
     if (permissions.canSeeDeleted) {
       actions.add(EduDataTableAction(
         icon: Icons.delete_forever_rounded,
         label: 'Purge',
         onTap: (_) => _purgeUser(user),
         color: AppTheme.actionPurge,
         isDestructive: true,
       ));
     }
     
     return actions;
   }
   ```

4. **Remove View icon button:** Tapping the row navigates to the user detail view (already should work via `onItemTap`).

5. **Search:** Searchable by name AND phone number. Use `EduFilterToolbar` integrated into the data table.

6. **Filters:** Filter chips for:
   - Status: Active, Invited, Suspended, Deleted (if super)
   - Level: Normal, System, Super

7. **Row hover animation:** Already in EduDataTable — verify it works with `AnimatedContainer(100ms)`.

8. **Row click → user detail:** `onItemTap: (user) => _showUserDetail(user)` — opens `UserDetailSheet`.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note Users section overhaul
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul system dashboard users table with contextual actions and search"`

---

### Task 502: Overhaul Schools section data table [x]
**Files to create/modify:** `lib/ui/screens/system/schools/schools_section.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Task 201, Task 101
**Parallel group:** P5

**Specification:**

Apply the same data table overhaul to schools:

1. **School logo with status dot:** Already present (`SchoolStatusDot`). Verify it works.

2. **Smart contextual actions:**
   - Activate: only if trial/suspended
   - Suspend: only if active/trial
   - Restore: only if suspended/deleted
   - Delete: only if not already deleted
   - Purge: super only

3. **Search:** By school name and motto.

4. **Filters:** Status chips: Trial, Active, Suspended, Cancelled, Deleted (if super).

5. **Row click → school detail page:** `SchoolDetailScreen`.

6. **Remove View icon button** — row tap is the view action.

7. **Profile (logo) photo visible on every row.**

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul system dashboard schools table with contextual actions"`

---

### Task 503: Overhaul Members section data table [x]
**Files to create/modify:** `lib/ui/screens/system/members/members_section.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Task 201, Task 101
**Parallel group:** P5

**Specification:**

1. **Avatar with level badge:** System → shield, Super → star. Color = status.

2. **Smart contextual actions:**
   - View roles
   - Edit status (suspend/restore/delete)
   - Demote (remove system/super level → back to Normal)
   - Purge (super only)

3. **Search:** By name and phone.

4. **Row click → member roles sheet.**

5. **Profile photo on every row.**

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul system dashboard members table"`

---

### Task 504: Overhaul Roles section data table [x]
**Files to create/modify:** `lib/ui/screens/system/roles/roles_section.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Task 201, Task 101
**Parallel group:** P5

**Specification:**

1. **Role icon with name.**

2. **Smart contextual actions:**
   - View (pushes `RoleDetailScreen`)
   - Edit (opens edit sheet)
   - Delete (with confirmation)
   - Purge (super only)

3. **Search:** By role name.

4. **Row click → role detail screen.**

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul system dashboard roles table"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 6 — School Dashboard Data Tables Overhaul
## ═══════════════════════════════════════════════════════════════════════════

### Task 601: Overhaul Members page — all member tabs (Departments, Owners, Teachers, Staff, Students, Guardians) [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 201, Task 101
**Parallel group:** P6

**Specification:**

The members page is ~5400 lines and has 6 tabs. Only the Departments tab currently uses `EduDataTable` — all others use hand-rolled `_FlatMemberList` + `_UserDataRow` / `_FlatRow` patterns. Additionally, there is an N+1 query problem in Owners/Teachers/Staff tabs where each row does a `FutureBuilder<UsersData?>` lookup via `findUserById`.

**For each member tab (Owners, Teachers, Staff, Students, Guardians):**

1. **Use enhanced `EduDataTable` with the new features.**

2. **Profile photos visible:** `UserAvatar` on every member row.

3. **Smart contextual actions per member type:**

   **Owners:**
   - Remove owner (with confirmation)
   - Only show remove if permissions allow
   
   **Teachers:**
   - Edit → opens edit sheet
   - Suspend / Restore (based on current status)
   - Remove → removes membership
   - View → navigate to detail
   
   **Staff:**
   - Edit → opens edit sheet
   - Suspend / Restore
   - Remove → removes membership
   - View → navigate to detail
   
   **Students:**
   - Edit → opens edit sheet
   - View → pushes `StudentDetailPage`
   - Suspend / Restore
   - Unenroll
   - Search by name AND admission number
   - Uses `_StudentAvatar` (loads from file system: `{appDir}/schools/{schoolId}/students/{adm}/image`)
   
   **Guardians:**
   - Edit → opens edit sheet
   - Remove
   - View wards
   - Search by name and phone

4. **Search per tab:**
   - Owners: by name, phone
   - Teachers: by name, phone
   - Staff: by name, phone
   - Students: by name, admission number
   - Guardians: by name, phone

5. **Filters per tab where relevant:**
   - Teachers/Staff/Students: Status (Active, Suspended, etc.)
   - Students: Grade/stream filter if applicable

6. **Row click → detail view** (not a separate View button).

7. **Status baked into avatar badge** using the same dot/shield/star pattern adapted for member status colors.

**For Departments tab:**
- Already uses `EduDataTable<Department>` — update to use `actionsBuilder` for contextual actions
- Department rows with member count
- Click → department detail (existing flow)
- Actions: Edit name, Delete (with confirmation)
- Search by department name

**Fix the N+1 query problem:**
- Owners/Teachers/Staff tabs currently do per-row `FutureBuilder<UsersData?>` on `MembersDao(db).findUserById(member.user)` — this is an N+1 anti-pattern
- Instead, the DAO should return joined data: `watchOwnersWithUsers(schoolId)` → `Stream<List<({Owner owner, UsersData user})>>`
- If these joined DAO methods don't exist yet, create them (or the executor can do the join in the widget layer by pre-fetching all users in a single query before building the list)

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note members page overhaul
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul school dashboard members page with enhanced data tables"`

---

### Task 602: Overhaul Academics page data tables (grades, streams, subjects, teachers, students tabs) [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/academics_screen.dart`, `lib/ui/screens/school_dashboard/academics/tabs/students_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/teachers_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/subjects_tab.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 201, Task 101, Task 401 (for subject fix)
**Parallel group:** P6

**Specification:**

**Research findings — current state:**
- `students_tab.dart`: Hand-rolled `_StudentRow` with `MouseRegion` + hover + dividers (data-table-style manually). Has `_StudentAvatar` ✅. NO search ❌, NO actions ❌ (row tap only → `StudentGradePage`). Shows trajectory + average badge.
- `teachers_tab.dart`: Fully custom card-based layout (NOT data-table). Three sections: Active class teacher card, Past class teachers, Subject teachers. Has `UserAvatar` ✅. NO search ❌, NO actions ❌. Purely informational.
- `subjects_tab.dart`: Custom `_SubjectRow` with hover + dividers. Has `UserAvatar` for teacher ✅. NO search ❌, NO actions ❌.
- `academics_screen.dart`: NOT a data table — it's a navigational grade/stream tree. Leave as-is (it's structural navigation, not entity listing).

**Changes:**

1. **Students tab:** Add search by name and admission number. Add `EduFilterToolbar`. Convert `_StudentRow` to use `EduDataTable<GradeStudentRow>` with proper row builder. Student avatar with status indicator. Row tap → `StudentGradePage` (keep existing).
2. **Teachers tab:** This is more of an info panel than a data table — keep the card-based layout BUT ensure cards use the new border/divider aesthetic. Add `UserAvatar` consistently (already present). Consider adding search if the teacher list is long.
3. **Subjects tab:** Add search by subject name. Convert to `EduDataTable` if practical. Ensure teacher avatar is visible (already present).
4. **`academics_screen.dart`:** Leave the grade/stream tree as-is — it's navigational structure, not a data list.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul academics page data tables"`

---

### Task 603: Overhaul Exams & Grades page data tables [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 201, Task 101
**Parallel group:** P6

**Specification:**

**Research findings — current state:**
- Exam list uses hand-rolled `_ExamGroupRow` with `MouseRegion` + hover + `AnimatedContainer` + `AppTheme.tableRowDivider` — already data-table-style but NOT using `EduDataTable`. NO search ❌. NO filter chips ❌. No per-row actions — entire row is tappable to navigate.
- FAB for exam creation is gated by `_canManage` (role-based).

**Changes:**

1. **Exam list:** Add search by exam name. Add filter chips for exam type (midterm, end-term, etc.). Convert `_ExamGroupRow` to use `EduDataTable<ExamGroup>` or at minimum ensure consistent styling. Row tap → exam detail (keep existing).
2. **Exam detail → papers list:** Use data table pattern with contextual actions (edit paper, delete paper if pending).
3. **Grade spreadsheet:** Already uses a sophisticated custom pattern (`_GradeSpreadsheet`) — verify it aligns with the thin-divider aesthetic but do NOT rewrite it (it's the reference implementation mentioned in AGENT.md §21).
4. **Status baked into exam/paper indicators rather than badge columns.**

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul exams and grades data tables"`

---

### Task 604: Overhaul School Roles page data table [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 201, Task 101
**Parallel group:** P6

**Specification:**

**Research findings — current state:**
- Hand-rolled `_RoleRow` with `MouseRegion` + hover + `AnimatedContainer` + `AppTheme.tableRowDivider`. NOT using `EduDataTable`.
- Desktop: Inline `Edit` icon button (28×28, fades in on hover) + chevron for navigation. Mobile: three-dot → "Edit Role" bottom sheet.
- NO search ❌. Actions are static (same for every role).

**Changes:**

1. **Convert to `EduDataTable`** with proper `actionsBuilder` for contextual actions.
2. **Add search by role name** using `EduFilterToolbar`.
3. **Contextual actions via `actionsBuilder`:** View (navigate), Edit (open sheet), Delete (with confirmation). Purge if super.
4. **Row click → `SchoolRoleDetailScreen`** (keep existing navigation).
5. **Permission count visible** in a subtle muted text (e.g., "5 perms").

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: overhaul school roles data table"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 7 — Dialog, Form & Modal Consistency
## ═══════════════════════════════════════════════════════════════════════════

### Task 701: Migrate all modals/sheets to use `EduSheet`/`EduDialog` wrappers [x]
**Files to create/modify:** (All files that contain `showModalBottomSheet` or `showDialog` — comprehensive list below)
**Context files to read:** `lib/ui/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`
**Depends on:** Task 101 (for EduSheet, EduDialog)
**Parallel group:** —

**Specification:**

Search the codebase for all `showModalBottomSheet` and `showDialog` calls. Replace their container boilerplate with the standardized `showEduSheet` / `EduDialog` wrappers from Task 101.

**Files to update (non-exhaustive — executor should grep for all occurrences):**

System dashboard:
- `system/users/user_detail_sheet.dart`
- `system/users/invite_user_sheet.dart`
- `system/schools/create_school_sheet.dart`
- `system/schools/school_detail_screen.dart`
- `system/roles/create_role_sheet.dart`
- `system/roles/role_detail_sheet.dart`
- `system/plans/plans_section.dart`
- `system/members/members_section.dart`
- `system/settings/subjects_section.dart`

School dashboard:
- `school_dashboard/academics/grade_detail_page.dart`
- `school_dashboard/academics/paper_detail_page.dart`
- `school_dashboard/members/members_page.dart`
- `school_dashboard/members/student_detail_page.dart`
- `school_dashboard/roles/school_roles_screen.dart`
- `school_dashboard/roles/school_role_detail_screen.dart`
- `school_dashboard/exams/exam_creation_page.dart`
- `school_dashboard/exams/exams_grades_screen.dart`

Shared widgets:
- `widgets/create_term_modal.dart` (this IS the gold standard — keep it as-is or extract its patterns into `EduSheet`)
- `widgets/member_creation/*.dart`

**For each file:**
- Replace `showModalBottomSheet(backgroundColor: Colors.transparent, ...)` boilerplate with `showEduSheet()`
- Replace manual `Container(decoration: ...)` with `EduSheet` / `EduDialog`
- Replace manual sheet handles with `EduSheet(showHandle: true)`
- Replace manual form fields with `EduFormField` where they match the pattern
- Ensure confirmation dialogs use `showEduConfirmDialog()`

**Do NOT change the functional logic** — only the visual/structural wrappers.

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md` — note migration to standardized sheet/dialog wrappers
- [ ] Update `lib/ui/widgets/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: migrate all modals and sheets to standardized EduSheet/EduDialog wrappers"`

---

### Task 702: Ensure all forms use `EduFormField` consistently
**Files to create/modify:** Same files as Task 701
**Context files to read:** `lib/ui/widgets/CONTEXT.md`
**Depends on:** Task 101, Task 701
**Parallel group:** —

**Specification:**

After Task 701, go through all form-containing sheets/dialogs and ensure:
1. Text inputs use `EduFormField` (label above, consistent decoration)
2. Error messages render consistently (red-tinted banner below field)
3. Submit buttons use `AnimatedSaveButton` or the green `FilledButton` pattern
4. Field labels use the standardized 9.5px uppercase style

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: standardize all form fields with EduFormField"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 8 — Inner Pages & Detail Screens Consistency
## ═══════════════════════════════════════════════════════════════════════════

### Task 801: Ensure all detail screens have consistent entrance animations and layout [x]
**Files to create/modify:** All detail/inner page screens
**Context files to read:** `lib/ui/CONTEXT.md`
**Depends on:** Task 101
**Parallel group:** —

**Specification:**

Every detail screen (pushed via `Navigator.push`) should have:

1. **Entrance animation:** 350ms fade + slide(0.03) using `AnimationController` — the pattern from `RoleDetailScreen`, `SchoolDetailScreen`, `AccountScreen`.

2. **Back button:** `Icons.chevron_left_rounded` size 22-24 — already standardized.

3. **Header pattern:** `EduDetailHeader` (from Task 101) with avatar/icon, title, subtitle, metadata chips.

4. **Responsive padding:** 20px mobile / 28px desktop, `maxWidth: 760` constraint.

**Screens to verify/fix:**
- `system/schools/school_detail_screen.dart` — already good, use as reference
- `system/roles/role_detail_screen.dart` — already good, use as reference
- `school_dashboard/academics/grade_detail_page.dart`
- `school_dashboard/academics/paper_detail_page.dart`
- `school_dashboard/academics/student_grade_page.dart`
- `school_dashboard/academics/exam_detail_page.dart`
- `school_dashboard/members/student_detail_page.dart`
- `school_dashboard/roles/school_role_detail_screen.dart`

**Update after completion:**
- [ ] Update `lib/ui/screens/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: standardize entrance animations and layouts across all detail screens"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 9 — Profile Photos Everywhere
## ═══════════════════════════════════════════════════════════════════════════

### Task 901: Ensure profile photos are shown in all user/member/student-facing data tables and detail views [x]
**Files to create/modify:** Various — comprehensive check
**Context files to read:** `lib/ui/widgets/CONTEXT.md`
**Depends on:** Task 201
**Parallel group:** —

**Specification:**

The user requested: "not forgetting to include the profile photo anywhere profile can be accessed or visible."

**Checklist — verify `UserAvatar` is used in each of these locations:**

System dashboard:
- [x] Users table rows — `UserAvatar` in `_UserIdentityCell` (`users_section.dart`)
- [x] Members table rows — `UserAvatar` in `_MemberIdentityCell` (`members_section.dart`)
- [x] User detail sheet header — `UserAvatar` in `_AvatarWithDot` (`user_detail_sheet.dart`)
- [x] User menu overlay (top bar) — `UserAvatar` in `_UserMenuAnchorState` + `_UserMenuCard`
- [x] Roles > Assigned Users list (in role detail)

School dashboard:
- [x] Members > Owners tab rows — via `_UserDataRow` which uses `UserAvatar`
- [x] Members > Teachers tab rows — via `_UserDataRow` which uses `UserAvatar`
- [x] Members > Staff tab rows — via `_UserDataRow` which uses `UserAvatar`
- [x] Members > Students tab rows — `_StudentAvatar` via `_FlatRow`
- [x] Members > Guardians tab rows — via `_UserDataRow` which uses `UserAvatar`
- [x] Members > each member's detail sheet header — `UserAvatar` in owner/teacher/staff info sheets
- [x] Members > Guardian wards sheet > ward items — added `_StudentAvatar` to `_WardItem`
- [x] Academics > Teachers tab rows — `UserAvatar` in active/past class teacher cards + subject teacher cards
- [x] Academics > Students tab rows — `_StudentAvatar` in `_StudentRow`
- [x] Academics > Subjects tab rows (teacher avatar) — `UserAvatar` inline in `_SubjectRowState`
- [x] Exam detail > paper student rows — verified
- [x] Grade spreadsheet > student column — verified
- [x] Student detail page header — `_StudentAvatarLarge`
- [x] Student detail page > Guardians tab > `_GuardianRow` — replaced plain `CircleAvatar` with `UserAvatar`

Home screen:
- [x] Home screen cards (user avatar in AppBar)

**For students specifically:** Use the student image path pattern:
```dart
FileCache.studentImagePath(schoolId, admissionNumber)
```

**For users:** Use `UserAvatar(userId: ..., name: ..., radius: ...)`.

Add `UserAvatar` anywhere it's missing from the above list.

**Fixed in this task:**
1. `student_detail_page.dart` — `_GuardianRow`: replaced plain `CircleAvatar` (initials only) with `UserAvatar(userId: guardian.user, radius: 18)` and added `user_avatar.dart` import. Removed unused `_initials` static method.
2. `members_page.dart` — `_WardItem`: added `_StudentAvatar` (or fallback person icon) before the ward name/details in the guardian wards sheet.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: ensure profile photos visible across all data tables and detail views"`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK 10 — Final Polish & Context Updates
## ═══════════════════════════════════════════════════════════════════════════

### Task 1001: Update all CONTEXT.md files to reflect changes
**Files to create/modify:** All `CONTEXT.md` files
**Context files to read:** All
**Depends on:** All previous tasks
**Parallel group:** —

**Specification:**

Go through every `CONTEXT.md` file and ensure it accurately reflects the current state after all changes:

1. `lib/CONTEXT.md`
2. `lib/ui/CONTEXT.md`
3. `lib/ui/screens/CONTEXT.md`
4. `lib/ui/screens/system/CONTEXT.md`
5. `lib/ui/screens/school_dashboard/CONTEXT.md`
6. `lib/ui/widgets/CONTEXT.md`
7. `lib/database/daos/CONTEXT.md`
8. `lib/models/CONTEXT.md`

For each:
- Update file listings (new files created)
- Update widget/class descriptions
- Update status markers
- Update the `## Last Updated` section
- Note any breaking changes or new patterns

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "docs: update all CONTEXT.md files to reflect UI overhaul changes"`

---

### Task 1002: Final compilation check and lint cleanup
**Files to create/modify:** Any files with errors
**Context files to read:** None
**Depends on:** All previous tasks
**Parallel group:** —

**Specification:**

1. Run `flutter analyze` and fix all errors (not info-level lints).
2. Run `dart run build_runner build --delete-conflicting-outputs` if any Drift table changes were made.
3. Ensure zero compilation errors across the project.
4. Fix any unused import warnings that were introduced.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "chore: fix compilation errors and lint cleanup after UI overhaul"`

---

## ═══════════════════════════════════════════════════════════════════════════
## Dependency Graph (Visual Summary)
## ═══════════════════════════════════════════════════════════════════════════

```
Task 000 ✅ (committed)
    │
    ├── Task 101 (Design system widgets)
    │       │
    │       ├── Task 201 (EduDataTable overhaul)
    │       │       │
    │       │       ├── Task 501 ─┐
    │       │       ├── Task 502  │
    │       │       ├── Task 503  ├── Parallel Group P5 (system tables)
    │       │       ├── Task 504 ─┘
    │       │       │
    │       │       ├── Task 601 ─┐
    │       │       ├── Task 602  │
    │       │       ├── Task 603  ├── Parallel Group P6 (school tables)
    │       │       ├── Task 604 ─┘
    │       │       │
    │       │       └── Task 302 (Plans in Settings)
    │       │       └── Task 303 (Subjects in Settings)
    │       │
    │       ├── Task 701 (Modal migration)
    │       │       └── Task 702 (Form field consistency)
    │       │
    │       ├── Task 801 (Detail screen consistency)
    │       │
    │       └── Task 901 (Profile photos everywhere)
    │
    ├── Task 301 (System dashboard tabs) ── Parallel Group P3
    │       ├── Task 302
    │       └── Task 303
    │
    ├── Task 401 (Subject assignment bug fix) ── Parallel Group P4
    │       └── Task 402 (Subject label callers)
    │
    └── Task 1001 (Context updates) ── depends on ALL above
            └── Task 1002 (Compilation check) ── last task
```

## ═══════════════════════════════════════════════════════════════════════════
## Execution Order Recommendation for Orchestrator
## ═══════════════════════════════════════════════════════════════════════════

**Phase 1 — Foundation (sequential):**
1. Task 101 (design system) — must be first, everything depends on it

**Phase 2 — Parallel batch A:**
- Task 201 (EduDataTable overhaul)
- Task 301 (system dashboard tabs)
- Task 401 (subject assignment bug fix)

**Phase 3 — Parallel batch B (after 201 + 301):**
- Task 302 (Plans in Settings)
- Task 303 (Subjects in Settings)
- Task 402 (subject label callers — after 401)

**Phase 4 — Parallel batch C (after 201):**
- Task 501, 502, 503, 504 (system dashboard tables — all parallel)

**Phase 5 — Parallel batch D (after 201):**
- Task 601, 602, 603, 604 (school dashboard tables — all parallel)

**Phase 6 — Sequential polish (after all tables done):**
- Task 701 (modal migration)
- Task 702 (form consistency)
- Task 801 (detail screen consistency)
- Task 901 (profile photos)

**Phase 7 — Final:**
- Task 1001 (context updates)
- Task 1002 (compilation check)