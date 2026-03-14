# EduXal — Task Board

> Tasks are ordered by dependency and priority. Execute top-to-bottom.
> Server tasks are in `../ledger/TASKS.md` — complete those first before starting client tasks.
> Proto changes are done on the server side; the client only regenerates Dart stubs from `../ledger/protos/`.

## Parallelisation Guide

Tasks are grouped into independent tracks that can run concurrently via spawned agents:

| Track | Tasks | Model Recommendation | Description |
|---|---|---|---|
| **A — UI Design System** | U01–U03 | Gemini 3.1 Pro | Core design tokens, shared widget overhaul, back button standardisation |
| **B — List/Data Table Conversion** | U04–U08 | Gemini 3.1 Pro | Convert all card-based lists to data-table style across all screens |
| **C — Dialog & Modal Cleanup** | U09–U11 | Gemini 3.1 Pro | Rework bloated dialogs/modals (roles, members, etc.) |
| **D — Paper Page Overhaul** | P01–P05 | Claude Sonnet 4.6 | Paper page analytics, status fixes, editability, mobile polish |
| **E — Exam Page Fixes** | E01–E05 | Claude Sonnet 4.6 | State loss, resize crash, timetable alignment, form UX |
| **F — Roles & Permissions** | R01–R02 | Claude Sonnet 4.6 | Role creation with permissions, permissions tab display |
| **G — Answer Sheet Upload (Server)** | S01 | Claude Opus 4.6 | Server proto/API design prompt for answer sheet file sync |
| **H — Answer Sheet Upload (Client)** | F01–F03 | Claude Sonnet 4.6 | Client-side file capture, storage, and AI grading stub (depends on S01) |
| **I — Responsive Layout Fix** | X01 | Claude Sonnet 4.6 | Critical: window resize ejects user from current page |

**Dependency graph:**
- Track A (U01–U03) has NO dependencies — start immediately
- Track I (X01) has NO dependencies — start immediately (critical bug)
- Track B (U04–U08) depends on U01 (design tokens)
- Track C (U09–U11) depends on U01 (design tokens)
- Track D (P01–P05) depends on U01 (design tokens)
- Track E (E01–E05) depends on U01 (design tokens) and X01 (resize fix)
- Track F (R01–R02) depends on U01 (design tokens)
- Track G (S01) has NO dependencies — start immediately (server-side)
- Track H (F01–F03) depends on S01 (server API) and P01 (paper page base)

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK I — Critical Bug Fix (no dependencies)
## ═══════════════════════════════════════════════════════════════════════════

### Task X01: Fix window resize ejecting user from current page [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`, `lib/ui/screens/system/system_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/CONTEXT.md`, `lib/ui/screens/CONTEXT.md`
**Depends on:** Nothing

**Specification:**

**Problem:** When the user is on a detail page (e.g. exam detail, paper detail, grade detail) and resizes the window past a responsive breakpoint, the `LayoutBuilder` in `_DashboardShellState.build()` triggers a full rebuild. Because the layout dispatch (`_buildFullSidebarLayout` / `_buildRailLayout` / `_buildTabLayout`) creates entirely new widget trees, any `Navigator.push`-based detail pages get popped and the user is thrown back to the section root. This happens at `AppTheme.kDesktopBreakpoint` (1200px) and `AppTheme.kMobileBreakpoint` (600px).

**Root cause:** The `LayoutBuilder` in `_DashboardShellState.build()` (line ~299) dispatches to three completely separate layout methods. Each creates a `Scaffold` with its own widget tree. When the constraint width crosses a breakpoint, Flutter tears down the old Scaffold and builds a new one, destroying any pushed routes.

**Fix approach:** Use a single `Scaffold` with a `Navigator` or `IndexedStack` that persists across layout changes. The layout (sidebar vs rail vs tabs) should be a cosmetic wrapper around a **shared content area** that does NOT get rebuilt when the layout mode changes.

**Concrete implementation:**

1. In `_DashboardShellState`, add a field `_layoutMode` (enum: `full`, `rail`, `mobile`) that tracks the current layout.

2. Change the `LayoutBuilder` in `build()` to only update `_layoutMode` via `setState` when it changes, NOT to return different widget trees:

```dart
// Before (broken):
return LayoutBuilder(
  builder: (context, constraints) {
    final w = constraints.maxWidth;
    if (w >= AppTheme.kDesktopBreakpoint) {
      return _buildFullSidebarLayout(context, currentEntry);
    }
    if (w >= AppTheme.kMobileBreakpoint) {
      return _buildRailLayout(context, currentEntry);
    }
    return _buildTabLayout(context, currentEntry);
  },
);

// After (fixed):
return LayoutBuilder(
  builder: (context, constraints) {
    final w = constraints.maxWidth;
    final newMode = w >= AppTheme.kDesktopBreakpoint
        ? _LayoutMode.full
        : w >= AppTheme.kMobileBreakpoint
            ? _LayoutMode.rail
            : _LayoutMode.mobile;
    // Schedule mode update if changed, but don't rebuild widget tree
    if (newMode != _layoutMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _layoutMode = newMode);
      });
    }
    return _buildLayout(context, currentEntry, newMode);
  },
);
```

3. Refactor `_buildLayout` to use a single `Scaffold` where the navigation chrome (sidebar/rail/tabs) is swapped but the **content area** is a single persistent widget instance:

```dart
Widget _buildLayout(BuildContext ctx, MembershipEntry entry, _LayoutMode mode) {
  final cs = Theme.of(ctx).colorScheme;
  final content = _buildContentArea(ctx, entry);
  
  return Scaffold(
    backgroundColor: cs.surfaceContainerLowest,
    body: switch (mode) {
      _LayoutMode.full => Row(
        children: [
          _FullSidebar(...),
          Expanded(child: _wrapContent(cs, content, true)),
        ],
      ),
      _LayoutMode.rail => Row(
        children: [
          _IconRail(...),
          Expanded(child: _wrapContent(cs, content, true)),
        ],
      ),
      _LayoutMode.mobile => SafeArea(
        child: Column(
          children: [
            _TabLayoutTopBar(...),
            _PillTabStrip(...),
            Expanded(child: content),
          ],
        ),
      ),
    },
  );
}
```

4. **Key constraint:** The mobile layout currently uses `TabBarView` which requires a `TabController`. The fix should use `_selectedIndex` to show the correct content panel in ALL three layouts (not `TabBarView` for mobile). Replace `TabBarView` with the same `_buildContentArea` call used by sidebar/rail layouts. The `_PillTabStrip` should drive `_selectIndex` via its `TabController` listener, but the content should NOT be inside a `TabBarView`.

5. Add the `_LayoutMode` enum:
```dart
enum _LayoutMode { full, rail, mobile }
```

6. Apply the same fix pattern to `system_dashboard_screen.dart` if it has the same issue.

**Testing:** After the fix, open any detail page (e.g. Exams & Grades → click an exam → click a paper), then resize the window past the 600px and 1200px breakpoints in both directions. The user should stay on the current page.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note the layout mode fix
- [ ] Update `lib/ui/screens/CONTEXT.md` — note the fix for both dashboards
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK A — UI Design System Foundation (no dependencies)
## ═══════════════════════════════════════════════════════════════════════════

### Task U01: Establish UI Design Tokens and Update AGENT.md §21 [x]
**Files to create/modify:** `AGENT.md`, `lib/ui/theme/app_theme.dart`
**Context files to read (if needed):** `lib/ui/CONTEXT.md`
**Depends on:** Nothing

**Specification:**

The user has clarified their UI preference by pointing to the Create Term modal (`lib/ui/widgets/create_term_modal.dart`) as the gold standard. After analyzing that widget, the updated design language is:

**Updated Design Tokens (to be codified in AGENT.md §21 and `app_theme.dart`):**

1. **Border Radius:** `BorderRadius.circular(12)` for modal/dialog containers, `BorderRadius.circular(8)` for cards/inputs/buttons, `BorderRadius.circular(4)` for chips/badges/small elements. NOT sharp (0) and NOT pill (24+). The "in-between" rounded feel.

2. **Elevation & Shadows:** Dual box-shadow pattern (large diffuse + small tight) exactly as in `_CreateTermDialog`:
   ```dart
   // Standard modal shadow:
   BoxShadow(
     color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.14),
     blurRadius: isDark ? 40 : 24,
     offset: const Offset(0, 10),
   ),
   BoxShadow(
     color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
     blurRadius: 6,
     offset: const Offset(0, 2),
   ),
   ```

3. **Compact but not congested:** Padding `12–16px` internal, `6–8px` between items. Not the bloated `20–32px` padding found in many current sheets.

4. **Icon buttons over wordy buttons:** Prefer `IconButton` (36×36 or 28×28) with tooltips over full-text buttons. Save buttons → green check icon. Delete → red trash icon. Edit → pencil icon. Actions have animation feedback (scale, check flash, etc.).

5. **Animations on actions:** Every action button should have visible feedback:
   - Button press: subtle scale animation (0.95→1.0, 100ms)
   - Success: brief checkmark flash (300ms elastic out) or color pulse
   - Loading: 16×16 `CircularProgressIndicator(strokeWidth: 1.5)`
   - The `AnimatedSaveButton` pattern should be the standard for all mutation actions.

6. **Back button:** Use `Icons.chevron_left_rounded` (size 22–24) everywhere, NEVER `Icons.arrow_back`. This is already the convention in academics pages but must be enforced globally.

7. **Dark mode colors:**
   - Modal/sheet background: `isDark ? Color(0xFF18222E) : cs.surface`
   - Nested content bg: `isDark ? Color(0xFF1A2536) : cs.surfaceContainerHighest.withAlpha(0.5)`
   - Overlay bg: `isDark ? Color(0xFF1E2A3A) : cs.surface`
   - Border: `isDark ? Color(0xFF2A3848) : cs.outlineVariant.withAlpha(0.6)`

8. **Data table list style** (new standard for all lists — replaces card-based lists):
   - Items separated by visible thin dividers (`Divider(height: 1, color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.1))`)
   - Rows have subtle hover highlight (`cs.primary.withValues(alpha: 0.04)` via `InkWell` or `AnimatedContainer`)
   - No per-item card/elevation — items flow as rows in a continuous surface
   - Row height: 48–56px for standard items, up to 64px for items with subtitle
   - Action buttons: visible icon buttons on desktop, three-dot `Icons.more_vert` on mobile that opens a popup/bottom sheet with actions
   - The `_GradeSpreadsheet` pattern in `paper_detail_page.dart` is the reference implementation

**Concrete changes to `app_theme.dart`:**

Add static constants to `AppTheme`:
```dart
// Modal
static const kModalRadius = 12.0;
static const kCardRadius = 8.0;
static const kChipRadius = 4.0;

// Standard modal shadow (use in all dialogs/sheets)
static List<BoxShadow> modalShadow(bool isDark) => [
  BoxShadow(
    color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.14),
    blurRadius: isDark ? 40 : 24,
    offset: const Offset(0, 10),
  ),
  BoxShadow(
    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

// Data table row divider
static Divider tableRowDivider(bool isDark, ColorScheme cs) => Divider(
  height: 1,
  thickness: 0.5,
  color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.1),
);

// Standard dark mode colors
static Color modalBg(bool isDark, ColorScheme cs) => isDark ? const Color(0xFF18222E) : cs.surface;
static Color nestedBg(bool isDark, ColorScheme cs) => isDark ? const Color(0xFF1A2536) : cs.surfaceContainerHighest;
static Color overlayBg(bool isDark, ColorScheme cs) => isDark ? const Color(0xFF1E2A3A) : cs.surface;
static Color borderColor(bool isDark, ColorScheme cs) => isDark ? const Color(0xFF2A3848) : cs.outlineVariant.withValues(alpha: 0.6);
```

**Concrete changes to `AGENT.md` §21:**

Replace the entire §21 content with the updated design tokens above. Remove the contradiction between §21 and the TASKS.md mandate noted in `lib/ui/CONTEXT.md`. Make the new tokens the single source of truth.

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md` — remove the "tension" note about §21 vs TASKS.md, reference new design tokens
- [ ] Mark this task `[x]`

---

### Task U02: Create shared `EduDataTable` widget for data-table-style lists [x]
**Files to create/modify:** `lib/ui/widgets/edu_data_table.dart`
**Context files to read (if needed):** `lib/ui/widgets/CONTEXT.md`, `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` (reference: `_GradeSpreadsheet`)
**Depends on:** U01

**Specification:**

Create a reusable `EduDataTable` widget that implements the data-table list pattern described in U01. This widget will replace all card-based list views across the app.

**File: `lib/ui/widgets/edu_data_table.dart`**

```dart
/// A data-table-style list widget following the EduXal design system.
///
/// Renders items as rows separated by thin dividers with hover highlights.
/// On desktop, action buttons are visible inline. On mobile, a three-dot
/// menu button opens a bottom sheet with available actions.
class EduDataTable<T> extends StatelessWidget {
  const EduDataTable({
    super.key,
    required this.items,
    required this.rowBuilder,
    this.headerBuilder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'No items',
    this.emptySubtitle,
    this.onItemTap,
    this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// The list of items to display.
  final List<T> items;

  /// Builds the content of each row (excluding action buttons — those are handled by [actions]).
  /// Receives the item and a bool indicating whether the row is hovered (desktop only).
  final Widget Function(BuildContext context, T item, bool isHovered) rowBuilder;

  /// Optional header row above the list (e.g. column labels).
  final Widget Function(BuildContext context)? headerBuilder;

  /// Icon for empty state.
  final IconData emptyIcon;

  /// Title for empty state.
  final String emptyTitle;

  /// Subtitle for empty state.
  final String? emptySubtitle;

  /// Called when a row is tapped (navigation).
  final void Function(T item)? onItemTap;

  /// Action definitions for each row. On desktop (≥600px), shown as inline icon buttons.
  /// On mobile (<600px), shown via a three-dot menu that opens a bottom sheet.
  final List<EduDataTableAction<T>> Function(T item)? actions;

  /// Padding around the entire list.
  final EdgeInsets padding;
}

/// An action that can be performed on a data table row.
class EduDataTableAction<T> {
  const EduDataTableAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final void Function(T item) onTap;
  final Color? color;
  final bool isDestructive;
}
```

**Implementation details:**

1. **Row structure:** Each row is 52px height, `InkWell` with `splashFactory: NoSplash.splashFactory`, hover color `cs.primary.withValues(alpha: 0.04)`.

2. **Row layout:** `Row` with:
   - `Expanded(child: rowBuilder(context, item, isHovered))` on the left
   - Action buttons on the right (desktop: inline icon buttons; mobile: single `Icons.more_vert` 18px)

3. **Dividers:** Between every row, use `AppTheme.tableRowDivider(isDark, cs)` from U01.

4. **Desktop actions (≥600px):** Small icon buttons, 28×28, `BorderRadius.circular(6)`, tooltip with label, `onSurfaceVariant` at 0.5 alpha, hover brings to full alpha. Destructive actions use `cs.error` color.

5. **Mobile actions (<600px):** Single `Icons.more_vert` button (18px) that opens:
   ```dart
   showModalBottomSheet(
     // Bottom sheet with action rows: icon + label, tappable
   )
   ```

6. **Empty state:** Follows the existing academic empty state pattern: 52×52 rounded container + icon + title + subtitle.

7. **Hover animation:** `AnimatedContainer(duration: 100ms)` background color change on hover.

8. **Header:** If `headerBuilder` is provided, render it above the list with a divider below.

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md` — add `edu_data_table.dart` entry
- [ ] Mark this task `[x]`

---

### Task U03: Standardise all back buttons to chevron_left_rounded [x]
**Files to create/modify:** (grep for `Icons.arrow_back` across entire `lib/ui/` directory and replace)
**Context files to read (if needed):** `lib/ui/screens/CONTEXT.md`
**Depends on:** Nothing (can run in parallel with U01)

**Specification:**

Search the entire `lib/ui/` directory for any usage of `Icons.arrow_back`, `Icons.arrow_back_ios`, `Icons.arrow_back_rounded`, or `Icons.arrow_back_ios_new` and replace with `Icons.chevron_left_rounded` (size 22 or 24 depending on context).

**Concrete steps:**

1. Run `grep -rn "arrow_back" lib/ui/` to find all instances.

2. For each instance:
   - Replace the icon with `Icons.chevron_left_rounded`
   - Keep the size as-is if it's already 22–24. If it's larger (e.g. the default 24), keep at 24.
   - Ensure the `onPressed` callback is unchanged.

3. Known locations that already use `chevron_left_rounded` (DO NOT CHANGE these):
   - `paper_detail_page.dart` — AppBar leading
   - `student_grade_page.dart` — AppBar leading
   - `exam_detail_page.dart` — AppBar leading
   - `grade_detail_page.dart` — AppBar leading
   - `exams_grades_screen.dart` — `_ExamGroupDetailView` header and `_SectionHeader`

4. Locations likely still using `arrow_back` (verify via grep):
   - `account_screen.dart` — AppBar
   - `notifications_page.dart` — AppBar
   - `school_role_detail_screen.dart` — AppBar
   - `student_detail_page.dart` — AppBar (if any)
   - Any system dashboard detail screens (`school_detail_screen.dart`, `role_detail_screen.dart`, etc.)
   - `home_screen.dart` — if there's a back action

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md` — note that back button standardisation is complete
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK B — List/Data Table Conversion (depends on U01, U02)
## ═══════════════════════════════════════════════════════════════════════════

### Task U04: Convert system dashboard lists to data-table style [x]
**Files to create/modify:** `lib/ui/screens/system/users/users_section.dart`, `lib/ui/screens/system/schools/schools_section.dart`, `lib/ui/screens/system/plans/plans_section.dart`, `lib/ui/screens/system/roles/roles_section.dart`, `lib/ui/screens/system/members/members_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`, `lib/ui/widgets/edu_data_table.dart` (from U02)
**Depends on:** U01, U02

**Specification:**

Convert all list views in the system dashboard from card-based to data-table style using the `EduDataTable` widget from U02.

**For each section:**

1. **`users_section.dart`** — Users list. Each row: name (w500 13px), phone (muted 12px), level badge (chip), status badge (chip). Desktop actions: Edit level, Edit status, Delete. Mobile: three-dot menu.

2. **`schools_section.dart`** — Schools list. Each row: school name (w500 13px), motto (muted 12px ellipsis), county badge, status badge. Desktop actions: View details, Edit, Delete. Mobile: three-dot menu.

3. **`plans_section.dart`** — Plans list. Each row: plan name (w500 13px), price (muted 12px), status badge, grade count badge. Desktop actions: Edit, Delete. Mobile: three-dot menu.

4. **`roles_section.dart`** — Roles list. Each row: role name (w500 13px), description (muted 12px ellipsis), permission count badge. Desktop actions: View details, Delete. Mobile: three-dot menu.

5. **`members_section.dart`** — Members list. Each row: similar to current but as flat rows.

**Common changes for all:**
- Replace `ListView.builder` + card widgets with `EduDataTable<T>` usage
- Row height 52px standard
- Dividers between rows
- Hover highlight on desktop
- Keep existing search/filter functionality above the table
- Keep existing `FloatingActionButton.small` for creation actions

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note data table migration
- [ ] Mark this task `[x]`

---

### Task U05: Convert school dashboard members list to data-table style [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/widgets/edu_data_table.dart`
**Depends on:** U01, U02

**Specification:**

Convert all member list tabs (Owners, Teachers, Staff, Students, Guardians, Departments) from the current `_BaseTile` card-based pattern to data-table style.

**Current pattern (to be replaced):**
```dart
// _BaseTile uses Material with surfaceContainerHighest alpha 0.4, borderRadius: 6
```

**New pattern for each tab:**

1. **Owners tab:** Row: `UserAvatar` (radius 16) + name (w500 13px) + phone (muted 12px). Desktop actions: View (opens `_OwnerInfoSheet`), Remove (error-colored). Mobile: tap opens detail sheet, long-press or three-dot for remove.

2. **Teachers tab:** Row: `UserAvatar` (radius 16) + name (w500 13px) + role/department subtitle (muted 12px) + status dot. Desktop actions: View, Edit, status actions. Mobile: three-dot menu.

3. **Staff tab:** Same as teachers pattern.

4. **Students tab:** Row: `_StudentAvatar` (radius 16) + name (w500 13px) + "ADM: {adm}" (muted 12px) + status dot. Desktop: View, Edit, Delete. Mobile: three-dot menu.

5. **Guardians tab:** Row: `UserAvatar` (radius 16) + name (w500 13px) + "{N} wards" (muted 12px). Desktop: View. Mobile: tap opens detail.

6. **Departments tab:** Row: department name (w500 13px) + member count badge. Desktop: View, Delete. Mobile: three-dot menu.

**Implementation:**
- Replace `_BaseTile` with `EduDataTable` usage or inline data-table rows
- Remove the `Material` wrapping with `surfaceContainerHighest` alpha
- Use `Divider` between rows
- Keep the existing `EduTabBar` for tab switching
- Keep the existing `FloatingActionButton.small` for creation

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note members list migration
- [ ] Mark this task `[x]`

---

### Task U06: Convert school roles list to data-table style [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/widgets/edu_data_table.dart`
**Depends on:** U01, U02

**Specification:**

Convert `_RoleCard` from a card-based item to a data-table row.

**Current `_RoleCard`** (lines 132–266): Uses `Material` with elevation and card styling.

**New row pattern:**
- Row height: 52px
- Left: role name (w500 13px) + description (muted 12px, ellipsis, max 1 line)
- Right: permission count badge (tinted container, `BorderRadius.circular(4)`, e.g. "8 permissions") + chevron
- Divider between rows
- Hover highlight on desktop
- Tap → `_openDetail` (existing navigation)

**Also:**
- The `_EmptyState` should follow the updated empty state pattern
- Keep `FloatingActionButton.small` for role creation

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note roles list migration
- [ ] Mark this task `[x]`

---

### Task U07: Convert exams list to data-table style [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01, U02

**Specification:**

Convert `_ExamGroupCard` (lines 307–432) from a card-based item to a data-table row.

**Current `_ExamGroupCard`:** Container with thin 1px border, type badge, date range, class chips, meta badges.

**New row pattern:**
- Row height: 56–64px (needs two lines for metadata)
- Left column: type badge (inline chip, 10.5px) + exam date range (13px, w400)
- Middle: `Wrap` of participating grade chips (compact `_ClassChip` at 10px)
- Right: subject count badge + paper count badge + chevron
- Divider between rows
- Hover highlight
- Tap → `_openExam` (existing)

**Also convert the FAB:**
- Replace the current "New Exam" action (if any text button exists) with a `FloatingActionButton.small` with `Icons.add_rounded` tooltip "New Exam" — this is already done per the context, just verify.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note exams list migration
- [ ] Mark this task `[x]`

---

### Task U08: Convert announcements, finance, and academics lists to data-table style [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart`, `lib/ui/screens/school_dashboard/finance/finance_screen.dart`, `lib/ui/screens/school_dashboard/academics/academics_screen.dart`, `lib/ui/screens/school_dashboard/academics/tabs/students_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/subjects_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/lessons_tab.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01, U02

**Specification:**

Convert remaining card-based lists across the school dashboard to data-table style:

1. **`announcements_screen.dart`** — Announcement items: row with title (w500 13px), date (muted 12px), audience badge, truncated body preview (1 line, muted). Desktop actions: Edit, Delete. Mobile: three-dot.

2. **`finance_screen.dart`** — Fee items, invoice items, payment items: each as data-table rows with amount, status, date. Desktop: Edit, Delete, Approve (payments). Mobile: three-dot.

3. **`academics_screen.dart`** — Grade cards can stay as cards (they're structural navigation, not data items). No change needed here.

4. **`students_tab.dart`** — Student rows are already compact but use `Material` wrapping. Convert to flat divider-separated rows. Keep avatar, name, ADM, trajectory, average badge. Add hover highlight.

5. **`exams_tab.dart`** — Exam cards in the grade detail. Convert to flat rows: type badge + date range + paper count + chevron. Dividers between.

6. **`subjects_tab.dart`** — Subject-teacher cards. Convert to flat rows: subject name + teacher avatar+name + mastery bars. Dividers.

7. **`lessons_tab.dart`** — Lesson rows. Convert from cards to flat divider-separated rows. Keep the color accent bar (as a left border 3px on each row instead of a card).

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note data table migration for remaining lists
- [x] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK C — Dialog & Modal Cleanup (depends on U01)
## ═══════════════════════════════════════════════════════════════════════════

### Task U09: Rework role creation modal with permissions and compact UI [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart` (reference for `_ResourceRow` and `_ExpandedPermissions`)
**Depends on:** U01

**Specification:**

**Problem 1:** The role creation modal (`_RoleFormSheet`, lines 272–463) has a bloated feel — `BorderRadius.vertical(top: Radius.circular(20))` is too rounded, padding is too generous (20px sides, 32px bottom), and there appears to be a curved reddish decorative line that shouldn't be there.

**Problem 2:** The modal only allows creating a role with name/description but no permissions. The user wants to set permissions inline during creation.

**Fix — Rework `_RoleFormSheet` into an adaptive modal (dialog on desktop, sheet on mobile):**

1. **Container styling** — Match the `_CreateTermDialog` pattern exactly:
   - Desktop: `Dialog(backgroundColor: transparent)` → `ConstrainedBox(maxWidth: 440)` → `Container` with `Color(0xFF18222E)` dark / `cs.surface` light, `BorderRadius.circular(12)`, dual box-shadow, thin border.
   - Mobile: `showModalBottomSheet` with `BorderRadius.vertical(top: Radius.circular(12))` (not 20).

2. **Remove any decorative elements** (curved lines, etc.). Audit the build method for any `Container` or `Divider` with non-standard colors that could be the "reddish line" — likely a `Divider` or `Container` with an accent color. Remove it.

3. **Add permissions section below name/description fields:**

   Layout:
   ```
   ── Drag handle (sheet only) ──
   ── Header: "New Role" + close button ──
   ── Name field (compact, 14px) ──
   ── Description field (compact, 14px, 2 lines max) ──
   ── Divider ──
   ── Permissions section ──
       List of resources (collapsed by default)
       Each resource: row with resource name + expand chevron
       When expanded: action icons in a Wrap
       Each action: icon button (28×28, toggle on/off)
           Active: primary-tinted bg + primary icon
           Inactive: muted bg + muted icon
       Actions shown per resource per §17a Action Context table
   ── Footer: Cancel text + Save icon button (green check) ──
   ```

4. **Resource list:** Use the `_buildResourceGroups()` function from `school_role_detail_screen.dart` (line 22) to get the grouped resources with their applicable actions.

5. **Permissions storage:** Build a `Map<Resource, int>` bitmask from the toggled actions, serialize to blob via `_serialisePermissions()` (line 127 in `school_role_detail_screen.dart`), and pass to `createRole` as the `permissions` field instead of `'[]'`.

6. **Compact sizing:**
   - Internal padding: `12px` horizontal, `12px` bottom
   - Field spacing: `10px` between fields
   - Resource rows: `36px` height collapsed, expanded shows action icons below
   - Action icon buttons: `28×28`, `BorderRadius.circular(6)`, icon size 14px
   - Use `AppTheme.kCardRadius` (8) for inputs

7. **Action icons mapping** (from `school_role_detail_screen.dart` `_kActionIcons`):
   ```dart
   Action.create → Icons.add_rounded
   Action.read → Icons.visibility_outlined
   Action.update → Icons.edit_outlined
   Action.delete → Icons.delete_outline_rounded
   Action.purge → Icons.delete_forever_outlined
   Action.assign → Icons.link_rounded
   Action.unassign → Icons.link_off_rounded
   Action.mark → Icons.check_box_outlined
   Action.approve → Icons.thumb_up_outlined
   ```

8. **Save button:** Replace `AnimatedSaveButton` with a compact 36×36 green check icon button (`AppTheme.brandGreen`, `BorderRadius.circular(8)`) with the standard animation pattern (scale + check flash on success, spinner while saving).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note role creation modal rework
- [ ] Mark this task `[x]`

---

### Task U10: Rework all remaining bloated dialogs and bottom sheets [x]
**Files to create/modify:** Multiple files across `lib/ui/` (identify via grep for `Radius.circular(20)` or `Radius.circular(24)` or padding > 24 in bottom sheets)
**Context files to read (if needed):** `lib/ui/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`
**Depends on:** U01

**Specification:**

Search the entire `lib/ui/` directory for bottom sheets and dialogs that don't follow the compact pattern established by `_CreateTermDialog`. Fix each one.

**What to look for (grep patterns):**
1. `Radius.circular(20)` or `Radius.circular(24)` on bottom sheets → change to `Radius.circular(12)`
2. `padding: const EdgeInsets.fromLTRB(20, 16, 20, 32)` or similar generous padding → compact to `EdgeInsets.fromLTRB(16, 12, 16, 16)`
3. `SizedBox(height: 20)` or `SizedBox(height: 24)` spacers between form fields → reduce to `SizedBox(height: 10)` or `SizedBox(height: 12)`
4. Full-width text buttons ("Create", "Save", "Submit") → replace with compact icon buttons or small `FilledButton.tonal` right-aligned
5. Missing dual box-shadow → add `AppTheme.modalShadow(isDark)` to desktop dialog containers

**Known locations to check:**
- `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart` — `_RoleFormSheet` (handled separately in U09)
- `lib/ui/screens/school_dashboard/members/members_page.dart` — various detail sheets
- `lib/ui/screens/school_dashboard/finance/finance_screen.dart` — fee/invoice/payment creation sheets
- `lib/ui/screens/school_dashboard/announcements/announcements_screen.dart` — announcement creation
- `lib/ui/screens/system/schools/create_school_sheet.dart` — school creation
- `lib/ui/screens/system/roles/create_role_sheet.dart` — system role creation
- `lib/ui/screens/system/users/invite_user_sheet.dart` — user invitation
- `lib/ui/widgets/member_creation/` — all 5 member creation panels (these were already cleaned up in Task 06 but verify the border radius is 12 not 20)

**For each sheet found:**
1. Top border radius → `Radius.circular(12)`
2. Drag handle: `width: 32, height: 3.5, borderRadius: 2` (match `_CreateTermDialog` handle)
3. Internal padding → `16px` horizontal max
4. Field spacing → `10–12px`
5. Save/submit button → compact right-aligned or icon button

**Update after completion:**
- [ ] Update `lib/ui/CONTEXT.md` — note dialog cleanup sweep
- [ ] Mark this task `[x]`

---

### Task U11: Add animation feedback to all action buttons across the app [x]
**Files to create/modify:** `lib/ui/widgets/animated_action_button.dart` (new), multiple screen files
**Context files to read (if needed):** `lib/ui/widgets/CONTEXT.md`, `lib/ui/widgets/animated_save_button.dart` (reference)
**Depends on:** U01

**Specification:**

**Problem:** In a local-first app, many operations complete instantly with no visual feedback, making it feel like nothing happened.

**Solution:** Create a shared `AnimatedActionButton` widget and apply it across the app.

**File: `lib/ui/widgets/animated_action_button.dart`**

```dart
/// A compact icon button with animation feedback for actions.
///
/// States: idle → busy (spinner) → done (check flash) → idle
/// Size: [size] × [size] (default 32×32)
/// Shape: BorderRadius.circular(6)
class AnimatedActionButton extends StatefulWidget {
  const AnimatedActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = 32,
    this.iconSize = 16,
    this.showCheckOnSuccess = true,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final bool showCheckOnSuccess;
}
```

**Implementation:**
1. `SingleTickerProviderStateMixin` for the check animation
2. On tap: set `_busy = true`, call `onTap()`, on success set `_showCheck = true` for 400ms with elastic out scale animation, then reset
3. Button has a subtle scale animation: `Transform.scale(scale: _busy ? 0.95 : 1.0)` via `AnimatedScale`
4. Loading state: 14×14 `CircularProgressIndicator(strokeWidth: 1.5)` centered
5. Check state: `Icons.check_rounded` with `ScaleTransition(scale: elasticOut)`

**Apply `AnimatedActionButton` to these locations:**
- Delete buttons on data table rows
- Assign/unassign buttons in roles
- Status change buttons in member detail sheets
- Any other mutation icon buttons currently using plain `IconButton` or `GestureDetector` without animation feedback

The executor should search for `IconButton(` and `GestureDetector(onTap:` patterns in the UI layer that trigger mutations (DAO writes, service calls) and wrap them with `AnimatedActionButton` where appropriate. Focus on the most visible ones first:
- Member status changes (`_ActionIconGroup` items in members_page.dart)
- Role assignment/unassignment
- Department delete
- Student enrollment

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md` — add `animated_action_button.dart` entry
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK D — Paper Page Overhaul (depends on U01)
## ═══════════════════════════════════════════════════════════════════════════

### Task P01: Improve paper page analytics section and grade distribution [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01

**Specification:**

**Problem:** The grade distribution bars in `_AnalyticsSection` (lines 701–835) and `_DistributionChart` (lines 985–1085) feel sparse and outdated.

**Fix — Redesign the analytics section with creative freedom:**

The executor agent has **creative license** here. The goal is a more visually engaging analytics section that feels modern and data-dense without being cluttered.

**Suggested direction (executor can deviate):**

1. **Replace the donut chart** with a more compact representation:
   - Instead of an 80×80 `PieChart`, use a compact stats row with:
     - Graded progress: thin horizontal bar (4px) showing `gradedStudents/totalStudents` ratio + "{N}/{M} graded" label
     - Class average: large number (24px, w300) with color-coded tint + small "class average" label below
     - Mean score: similar treatment

2. **Redesign the distribution chart:**
   - Instead of wide bars with gaps, use a more compact grouped visualization:
     - Option A: Stacked horizontal bar (single row, 8px height, segments colored from red to green, with percentage labels above each segment on hover)
     - Option B: Small dot/cell grid — 6 cells in a row, each cell sized by count, colored by range (red→green gradient), with count number inside
     - Option C: Compact vertical bars (no gaps, 24px wide each, rounded top only, with count label above each bar and range label below, all in a tight 200px-wide container)
   - The executor should pick whichever feels most modern and compact

3. **Overall container:** Remove the `Material(elevation: 2)` wrapper. Use `Container` with thin border (`AppTheme.borderColor`) and `BorderRadius.circular(AppTheme.kCardRadius)`. Internal padding: 14px (not 20px).

4. **Responsive layout:** On wide screens (>560px), arrange stats row + distribution side by side. On narrow screens, stack vertically. The total height of the analytics section should be ~120px on desktop (not the current ~200px).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note analytics redesign
- [ ] Mark this task `[x]`

---

### Task P02: Fix paper status advancement color and reactivity [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Nothing (can run in parallel with P01)

**Specification:**

**Problem 1: Status advancement button color is wrong.**
The tick/check icon button for progressing the paper status is always red. Instead, the button color should match the NEXT status (what it will transition TO), while the status LABEL should show the CURRENT status color.

**Current behavior** (in `_PaperActionBarState._buttonConfig`, lines 603–622):
```dart
PaperStatus.pending => (color: Color(0xFF42A5F5), icon: play_arrow, label: 'Start'),
PaperStatus.progress => (color: Color(0xFFFFA726), icon: check_circle, label: 'Done'),
PaperStatus.done => (color: Color(0xFF66BB6A), icon: grading, label: 'Grade'),
```

**This is actually correct per the code** — the button colors already match the next status. The user says the button is "just red in color" which suggests the `_PaperActionBar` is NOT using this `_buttonConfig` function, OR there's a different code path being hit. **Debug step:** Verify that the `_PaperActionBar` widget is the one being rendered (not the old `_StatusAdvanceButton` which uses `AnimatedSaveButton`).

Check if the old `_PaperStatusRow` / `_StatusAdvanceButton` (lines 6505–6596 in `exams_grades_screen.dart`) is being used somewhere instead of `_PaperActionBar`. The old `_StatusAdvanceButton` uses `AnimatedSaveButton` which has its own color scheme — this might be the source of the "red" button.

**Fix:** Ensure `_PaperActionBar` is the only status advance widget used. Verify the color mapping is:
- Button for "Start" (pending → progress): Blue `#42A5F5` ✓
- Button for "Done" (progress → done): Amber `#FFA726` ✓  
- Button for "Grade" (done → marked): Green `#66BB6A` ✓
- Status chip label: shows CURRENT status in its own color (already correct in `_PaperStatusChip`)

**Problem 2: UI doesn't reflect status change until page re-entry.**

**Current code:** `_PaperDetailPageState` already has `_paperStream` (a reactive `Stream<Paper?>` from `ExamsGradesDao.watchPaper`), and the build method wraps everything in `StreamBuilder<Paper?>`. This should work reactively.

**Debug:** The issue might be that `_advance()` in `_PaperActionBarState` writes to the DB but the `_paperStream` is not emitting. Check that `ExamsGradesDao.watchPaper` uses `.watch()` (not `.get()`). If it does use `.watch()`, the stream should emit on DB write.

**Alternative fix:** If `watchPaper` is correct, the issue may be that `_PaperActionBar` receives `paper` as a constructor param and doesn't rebuild when the parent StreamBuilder emits. Verify the `StreamBuilder<Paper?>` result is being passed through to `_PaperActionBar`.

Trace the data flow:
1. `_PaperDetailPageState.build()` → `StreamBuilder<Paper?>` → `currentPaper = paperSnap.data ?? widget.paper`
2. `_PaperActionBar(paper: currentPaper, ...)` — this should receive the updated paper

If this chain is correct, the reactive update should work. If not, identify and fix the break.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note status color and reactivity fix
- [ ] Mark this task `[x]`

---

### Task P03: Add paper editability in pending state (edit invigilator, delete paper) [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** P02

**Specification:**

**Problem:** When a paper is in the `pending` state, it should be editable (change invigilator) and deletable. Currently the info card shows the invigilator but there's no edit action, and there's no delete button.

**Fix 1 — Editable invigilator (pending state only):**

In `_PaperInfoCard` (lines 352–517), when `paper.status == PaperStatus.pending && canEdit`:
- Add a small edit icon (14px, `Icons.edit_outlined`, muted) next to the invigilator name
- On tap, call `onEditInvigilator` callback (which opens `_showInvigilatorPicker`)
- The invigilator picker already exists and works (lines 92–207)
- When status is NOT pending, the invigilator should be display-only (no edit icon)

**Fix 2 — Delete paper (pending state only):**

Add a delete icon button to the `_PaperActionBar` (shown only when `paper.status == PaperStatus.pending`):
- Position: left side of the action bar, before the status chip
- Icon: `Icons.delete_outline_rounded`, size 18, `cs.error.withValues(alpha: 0.6)`
- On tap: show confirmation dialog (`_ConfirmDeleteDialog` pattern):
  ```
  Title: "Delete Paper?"
  Message: "This will permanently remove {subject} Paper {N}."
  Confirm: "Delete" (error color)
  ```
- On confirm: call `_dao.deletePaper(schoolId, examId, subject, paper)` (this method may need to be added to `ExamsGradesDao` if it doesn't exist — check and add if needed)
- After deletion: `Navigator.pop(context)` to go back to the exam detail

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note paper editability and delete
- [ ] Update `lib/database/daos/CONTEXT.md` — if `deletePaper` was added to DAO
- [ ] Mark this task `[x]`

---

### Task P04: Improve paper page mobile layout [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** P01

**Specification:**

**Problem:** On mobile, the paper page UI doesn't feel as good as on desktop.

**Fix — Mobile-specific improvements:**

1. **`_PaperInfoCard` on mobile (<600px):**
   - Stack the fields vertically instead of the current layout
   - Subject name as a large header (15px, w500)
   - Paper number badge inline with subject
   - Info rows: scheduled time, invigilator (avatar + name), exam type — each on its own line with icon prefix
   - Reduce padding from 16px to 12px

2. **`_PaperActionBar` on mobile:**
   - Full width: status chip on the left, advance button on the right (already done, verify)
   - Make the advance button slightly larger on mobile (height: 36px instead of default)

3. **Analytics section on mobile:**
   - Force vertical layout (already done for <560px, but verify spacing is compact)

4. **Grade list on mobile (`_GradeList`):**
   - Each student row: name + ADM on left, grade badge on right, tap to open entry sheet
   - Ensure the submission icon button and quick-grade button are accessible (not clipped)
   - Row height: 48px
   - Add clear dividers between rows

5. **Overall spacing:** Reduce `ListView` padding from `EdgeInsets.fromLTRB(16, 4, 16, 32)` to `EdgeInsets.fromLTRB(12, 4, 12, 24)` on mobile.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note mobile improvements
- [ ] Mark this task `[x]`

---

### Task P05: Add per-student answer sheet action buttons (mobile three-dot menu) [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U02 (for mobile three-dot pattern), P01

**Specification:**

**Problem:** On mobile, the per-student action buttons (submit answer sheets, quick-grade with AI) are not easily accessible. The user wants a three-dot menu on mobile that opens a bottom sheet with all available actions.

**Fix:**

1. **Desktop (≥600px) — `_SpreadsheetRow`:** Keep existing inline icon buttons (submit photos, quick-grade, grade entry). No change needed.

2. **Mobile (<600px) — `_GradeList`:** For each student row, add a three-dot `Icons.more_vert` (18px) button on the far right. On tap, open a compact bottom sheet (`showModalBottomSheet`) with action rows:
   - "Submit Answer Sheets" → `Icons.upload_file_outlined` → opens `_AnswerSubmissionSheet`
   - "Quick Grade with AI" → `Icons.auto_fix_high` → triggers `_quickGrade(adm)` (only when submissions exist)
   - "Enter Grade" → `Icons.edit_outlined` → opens `_MobileGradeEntrySheet`
   - "View Submissions ({N})" → `Icons.photo_library_outlined` → opens submission viewer (only when submissions exist)

3. **Bottom sheet styling:** Match `_CreateTermDialog` pattern — `BorderRadius.vertical(top: Radius.circular(12))`, compact 8px padding, 44px row height, icons 18px, labels 13px w400.

4. **Conditional actions:** Only show "Quick Grade" and "View Submissions" when `_submissions[adm]?.isNotEmpty == true`. Only show "Submit Answer Sheets" when `paper.status == PaperStatus.done`.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note mobile action menu
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK E — Exam Page Fixes (depends on U01, X01)
## ═══════════════════════════════════════════════════════════════════════════

### Task E01: Fix exam detail stream tab state loss on navigation [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** X01 (resize fix must be in place first)

**Specification:**

**Problem:** When the user is on the exam detail view, clicks on a paper slot to view the paper, and then comes back, the stream tab they were on resets to the default (first tab). This is state loss.

**Root cause:** `_ExamGroupDetailViewState` stores `_selectedGradeIndex` and `_selectedStreamIndex` as instance state. When the user navigates to a paper detail and back, the `_ExamGroupDetailView` widget might be getting rebuilt (e.g. by the parent `StreamBuilder` emitting a new list), which triggers `didUpdateWidget` → `_reinitializeTabs()` → resets indexes to 0.

**Fix:**

1. In `_ExamGroupDetailViewState.didUpdateWidget` (line 490), check if the group key has changed before reinitializing tabs:
```dart
@override
void didUpdateWidget(covariant _ExamGroupDetailView oldWidget) {
  super.didUpdateWidget(oldWidget);
  // Only reinitialize if the actual group changed (different key)
  if (oldWidget.group.groupKey != widget.group.groupKey) {
    _initializeGradeTabs();
    _rebuildStreamTabs();
    _loadTeacherNames();
  }
  // If same group but data updated (e.g. new papers), do NOT reset tab state
}
```

2. The `_selectedGradeIndex` and `_selectedStreamIndex` should be preserved when the widget rebuilds with the same group (just updated data). Only reset when switching to a completely different exam group.

3. **Also:** When returning from `PaperDetailPage` via `Navigator.pop`, the parent shell should NOT clear `_selectedPaper` and then rebuild — it should simply pop the paper view and keep the exam detail in its current state.

Check `_ExamsShellState._popToExam()` (line 104):
```dart
void _popToExam() {
  setState(() {
    _selectedPaper = null;
    _selectedExamRow = null;
    // DO NOT clear _selectedGroup or _selectedGroupKey
    _view = _ExamsView.examDetail;
  });
}
```

This should be correct, but verify the `StreamBuilder` wrapping `_ExamsView.examDetail` isn't causing a full rebuild of `_ExamGroupDetailView` when the reactive `watchExamGroups` stream emits.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note tab state fix
- [ ] Mark this task `[x]`

---

### Task E02: Improve mobile day tabs and paper timetable alignment [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01

**Specification:**

**Problem 1:** On mobile, the day tabs (`_PaperDayChip`) in the paper timetable are not as aesthetic as the grade/stream `EduTabBar` tabs.

**Fix:** Replace `_PaperDayChip` (lines 5655–5699) with `EduTabBar`-style tabs or improve their appearance:
- Use the same elevated, shadow-based indicator pattern as `EduTabBar`
- Day chips should be slightly larger (height: 32px, not the current compact size)
- Selected state: filled with primary color, white text, subtle shadow
- Unselected state: transparent, `onSurfaceVariant` text, thin border at 0.2 alpha
- Day name abbreviated (Mon, Tue, etc.) + date number below (12, 13, etc.)
- Smooth `AnimatedContainer` transition (140ms)

**Problem 2:** Paper timetable alignment and UI needs improvement.

**Fix for `_PaperTimetableGrid` (desktop, lines 5177–5236):**
- Ensure columns are properly aligned (all 140px wide, consistent padding)
- Time labels column (72px) should have right-aligned text
- Filled slot cells should have consistent internal padding (8px)
- Empty cells should show a faint dashed border (using `_DashedBorderPainter` pattern if available, or a simple 1px dashed border)

**Problem 3:** Paper timetable slot contents are empty.

**Debug:** The `_PaperSlotBox` widget (lines 5391–5491) renders subject name + paper label + time range + invigilator name. If slots appear empty, the issue is likely:
1. `config` doesn't have the right curriculum to resolve subject names via `_subjectLabel`
2. `teacherNames` map is empty (teacher resolution failed)
3. The paper data itself has null/zero values for `subject`, `paper`, `start`, `end`

**Fix:** Add fallback rendering in `_PaperSlotBox`:
- If subject name is empty/null: show "Subject {code}" as fallback
- If invigilator name not found in `teacherNames`: show "—" instead of empty string
- If time is 0: show "Time not set" in muted text

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note timetable improvements
- [ ] Mark this task `[x]`

---

### Task E03: Add delete-stream and edit-exam-name actions to exam detail [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01

**Specification:**

**Problem:** The exam detail view has a delete button for the entire exam group and a "+" FAB for adding papers/grades/streams, but it's missing:
1. A delete icon for removing a specific stream (and its papers)
2. An edit button for editing the exam name

**Fix 1 — Delete stream action:**

Add a delete icon to each stream tab (similar to how grade tabs have grade-level delete):

In `_ExamGroupDetailViewState.build()`, when rendering the stream sub-tabs area (line ~735), add a small delete icon button (14px, `Icons.close_rounded`, error color at 0.4 alpha) to the right of the stream tabs row. On tap:
1. Show confirmation dialog: "Remove {streamName}?" / "This will delete all papers for this stream."
2. On confirm: delete the specific exam row for `currentStream.exam.id` via `_dao.deleteExam(examId, accountId)`
3. After deletion: reset stream tab to index 0 (or the first remaining stream)
4. The reactive `StreamBuilder` will auto-refresh the view

**Fix 2 — Edit exam name:**

In the `_ExamGroupDetailViewState` header row (line ~719), add an edit icon button (16px, `Icons.edit_outlined`, `onSurfaceVariant` at 0.5 alpha) next to the exam type label. On tap:
1. Show a compact inline edit dialog (or a small bottom sheet) with a single text field pre-populated with the current exam name/type label
2. On save: update all exam rows in the group with the new name via `_dao.updateExamName(examIds, name, accountId)` (this method may need to be added to `ExamsGradesDao`)
3. The reactive `StreamBuilder` will auto-refresh

**Note:** The `ExamGroup` model currently derives its display from `examType` + `year`/`term`. If a `name` field exists on the `Exam` table (it does — added in Task C08), wire the edit to update `exams.name` for all exam rows in the group.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note stream delete and exam edit
- [ ] Update `lib/database/daos/CONTEXT.md` — if new DAO methods added
- [ ] Mark this task `[x]`

---

### Task E04: Improve paper creation form subject selector and paper number picker [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01

**Specification:**

**Problem 1:** When adding a new paper, the subject menu items don't feel "alive" — they should feel like the profile menu items (with boundaries, hover states, and clickable feel).

**Fix for `_SubjectMenuOverlayWidget` (lines 8462–8561):**
- Each menu item should have:
  - `InkWell` with hover color `cs.primary.withValues(alpha: 0.06)`
  - Thin bottom border between items (not `Divider` — use `Container` bottom border)
  - Selected item: primary-tinted background + check icon (already done, verify)
  - Add `borderRadius: BorderRadius.circular(4)` to each item's `InkWell` with internal margin 4px
  - Item height: 40px (not 36px) for better touch target
  - Subject name: 13px w400, with a small `Icons.menu_book_outlined` (14px, muted) prefix icon
  - If the subject has an assigned teacher, show teacher name as subtitle (11px, muted)

**Problem 2:** The multiple papers picker (paper number wheel) has a scrolling issue on desktop — scroll skips 2, can only get 1 or 3 because the scroll jumps.

**Fix for `_PaperNumberWheel` (lines 8567–8637):**
The `ListWheelScrollView` has `itemExtent: 30` and `diameterRatio: 1.2`. On desktop, mouse scroll events may cause the wheel to jump multiple items.

Fix options:
1. Replace `ListWheelScrollView` with a simple `Row` of 3 tappable number buttons (1, 2, 3) — much better UX for only 3 options:
   ```dart
   Row(
     children: [1, 2, 3].map((n) => GestureDetector(
       onTap: () => onChanged(n),
       child: AnimatedContainer(
         duration: const Duration(milliseconds: 140),
         width: 32, height: 32,
         alignment: Alignment.center,
         decoration: BoxDecoration(
           color: n == selected ? indigo : Colors.transparent,
           borderRadius: BorderRadius.circular(6),
           border: n == selected ? null : Border.all(color: cs.outlineVariant.withAlpha(0.3)),
         ),
         child: Text('$n', style: TextStyle(
           fontSize: 13, fontWeight: FontWeight.w500,
           color: n == selected ? Colors.white : cs.onSurface,
         )),
       ),
     )).toList(),
   )
   ```
2. This removes the scroll-skipping issue entirely.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note subject selector and paper number improvements
- [ ] Mark this task `[x]`

---

### Task E05: Convert exam creation FAB to floating action button [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Nothing

**Specification:**

**Problem:** The user wants the "+ New Exam" button to be a floating action button instead of any other pattern.

**Current state:** Check `_ExamsListViewState` (lines 218–301). The current implementation has `_showCreateExam` which pushes `ExamCreationPage`. There may already be a FAB pattern. Verify and ensure:

1. The exams list view (`_ExamsListView`) has a `Scaffold` with `floatingActionButton: FloatingActionButton.small(onPressed: _showCreateExam, child: Icon(Icons.add_rounded), tooltip: 'New Exam')` when `_canManage` is true.

2. Remove any other "New Exam" text buttons, outline buttons, or CTA buttons in the empty state. The FAB should be the ONLY creation entry point.

3. The FAB should use `heroTag: 'fab_exams_list'` to avoid hero conflicts.

**Update after completion:**
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK F — Roles & Permissions (depends on U01)
## ═══════════════════════════════════════════════════════════════════════════

### Task R01: Fix permissions tab display in school role detail [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** U01

**Specification:**

**Problem:** The permissions tab on the role detail page doesn't show any permissions or a way to edit/add them. The user suspects this is because their current role has no permissions set (because there was no way to set them in the creation flow — addressed in U09). But the tab should still show:
1. All available resources with their applicable actions
2. Currently set permissions (highlighted)
3. A way to toggle permissions on/off

**Current code:** `_PermissionsTab` (lines 798–1124) has a full implementation with `_editPermissions`, `_originalPermissions`, `_selectedResources`, `_expandedResources`, `_ResourceRow`, `_ExpandedPermissions`, etc.

**Debug the issue:**

1. `_resetFromRole()` (line 845) initializes `_editPermissions` from `_parsePermissions(widget.role.permissions)`. If `role.permissions` is `'[]'` (empty JSON string — which is what the creation flow saves), `_parsePermissions` may return an empty map.

2. Check `_parsePermissions` (line 97): it parses the `permissions` field. If the permissions field is stored as `'[]'` (JSON string) instead of a binary blob, the parser will fail silently and return empty.

3. **Root cause likely:** The `createRole` in `_RoleFormSheetState._save()` saves `permissions: Value('[]')` — a JSON string. But per AGENT.md §17a, permissions should be a **binary blob**. The parser `_parsePermissions` might expect binary format.

**Fix:**

1. If `_parsePermissions` returns empty for `'[]'`, the permissions tab should still show ALL available resources in a collapsed state, with zero permissions toggled. The user can then expand resources and toggle actions.

2. Ensure `_PermissionsTab.build()` (line 1002) renders even when `_editPermissions` is empty:
   - Show all resources from `_buildResourceGroups()` 
   - Each resource should be expandable
   - Each action should be toggleable
   - An "empty" indicator text when no permissions are set: "No permissions configured. Expand a resource to add permissions."

3. Check that saving permissions serializes correctly to the expected format (binary blob per §17a, or JSON string if that's what the DAO expects).

4. **The `_PermissionsEmptyState` widget** (lines 1633–1684) might be shown when it shouldn't be. Check the condition that triggers it — it should only show if there are truly no resources to display (which should never happen, since the resource list is static).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note permissions tab fix
- [ ] Mark this task `[x]`

---

### Task R02: Add permission editing to school role detail with icon-based actions [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `AGENT.md` (§17a for Resource/Action tables)
**Depends on:** R01

**Specification:**

**Problem:** Even after R01 fixes the display, the user wants the permission editing to feel more intuitive with icon-based action toggles.

**Current implementation:** `_ExpandedPermissions` (lines 1498–1627) shows action chips when a resource is expanded. 

**Improve the UX:**

1. **Resource rows (collapsed):** Show resource name + count of active permissions as a badge + expand chevron. When collapsed, show a compact summary of active actions as small icon dots (filled primary for active, muted outline for inactive).

2. **Resource rows (expanded):** Below the resource name, show a `Wrap` of action icon buttons:
   ```
   [👁] [✏] [🗑] [🔗] [⛓] [✓] [👍]
    R    U    D   Asg  Ung  Mrk  Apr
   ```
   - Each button: `AnimatedContainer` 32×32, `BorderRadius.circular(6)`
   - **Active state:** primary-tinted bg (`cs.primary.withValues(alpha: 0.12)`), primary icon, subtle elevation
   - **Inactive state:** transparent bg, `onSurfaceVariant` icon at 0.3 alpha
   - Below each icon: 9px label ("Read", "Update", etc.) in muted text
   - Tap toggles the permission bit

3. **Only show relevant actions per resource** — use the §17a "Action Context Per Resource" table. For example:
   - Users: Read, Update, Delete (no Create, no Assign)
   - Students: Create, Read, Update, Delete, Assign, Unassign
   - Attendance: Read, Mark (only 2 actions)

4. **Save action:** A compact save icon button (28×28, green check, `BorderRadius.circular(6)`) appears in the `_ChangeBar` when changes exist. Already implemented — verify it works.

5. **Add a "Add Resource" button** at the bottom of the list: thin dashed border row, `Icons.add_rounded` + "Add Resource", opens a picker showing resources not yet in the list. Alternatively, just show ALL resources always (with zero permissions) and let users toggle individual actions.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note permission editing improvements
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK G — Answer Sheet Upload: Server API Design (no dependencies)
## ═══════════════════════════════════════════════════════════════════════════

### Task S01: Generate server API prompt for answer sheet file upload [x]
**Files to create/modify:** `SERVER_PROMPT.md` (new file at project root)
**Context files to read (if needed):** `AGENT.md` (§9 file sync, §7 logs, §14 proto files)
**Depends on:** Nothing

**Specification:**

Create a detailed prompt document (`SERVER_PROMPT.md`) that the project owner will give to the server-side AI agent to implement the answer sheet file upload API. This is a **prompt-only task** — no client code changes.

**File: `SERVER_PROMPT.md`**

```markdown
# Server Task: Answer Sheet File Upload API

## Context

EduXal is a school management app. Teachers can photograph student exam answer sheets 
and upload them for AI-assisted grading. Files are stored in S3-compatible storage.

## Storage Path Convention

Answer sheet files are stored at:
```
/schools/{school_id}/exams/{exam_id}/{subject_code}/{paper_number}/{student_adm}/{file_number}.jpg
```

Where:
- `school_id` — UUID of the school
- `exam_id` — UUID of the exam
- `subject_code` — integer subject code
- `paper_number` — integer paper number (1, 2, 3)
- `student_adm` — integer student admission number
- `file_number` — sequential integer (1, 2, 3...) per upload order

## Required API Changes

### 1. New Proto Messages

Add to `sync.proto`:

```protobuf
// Request to get signed URLs for answer sheet upload
message AnswerSheetUploadRequest {
  string school_id = 1;
  string exam_id = 2;
  int32 subject = 3;
  int32 paper = 4;
  int32 student_adm = 5;
  int32 file_count = 6;  // how many files the client wants to upload
}

// Response with signed PUT URLs
message AnswerSheetUploadResponse {
  repeated FileUrl urls = 1;  // one PUT URL per requested file
}

// Request to get signed read URLs for existing answer sheets
message AnswerSheetReadRequest {
  string school_id = 1;
  string exam_id = 2;
  int32 subject = 3;
  int32 paper = 4;
  int32 student_adm = 5;
}

// Response with read URLs and metadata
message AnswerSheetReadResponse {
  repeated AnswerSheetFile files = 1;
}

message AnswerSheetFile {
  int32 file_number = 1;
  string get_url = 2;
  int64 expiry = 3;     // seconds since epoch
  int64 uploaded_at = 4; // seconds since epoch
}
```

### 2. New RPC Methods

Add to the `Sync` service (or create a new `Files` service):

```protobuf
service Files {
  // Get signed PUT URLs for uploading answer sheet images
  rpc GetAnswerSheetUploadUrls(AnswerSheetUploadRequest) returns (AnswerSheetUploadResponse);
  
  // Get signed GET URLs for reading existing answer sheet images
  rpc GetAnswerSheetReadUrls(AnswerSheetReadRequest) returns (AnswerSheetReadResponse);
  
  // Delete specific answer sheet files
  rpc DeleteAnswerSheetFiles(AnswerSheetDeleteRequest) returns (AnswerSheetDeleteResponse);
}
```

### 3. Server Implementation

1. **GetAnswerSheetUploadUrls:**
   - Verify the user has permission to grade this exam (teacher of the subject, or owner/staff with Grades.Mark permission)
   - Generate `file_count` signed PUT URLs with path `/schools/{school_id}/exams/{exam_id}/{subject}/{paper}/{student_adm}/{N}.jpg` for N = 1..file_count
   - PUT URLs expire in 1 hour
   - Return `AnswerSheetUploadResponse` with the URLs

2. **GetAnswerSheetReadUrls:**
   - List all files at the S3 prefix `/schools/{school_id}/exams/{exam_id}/{subject}/{paper}/{student_adm}/`
   - Generate signed GET URLs for each (expire in 24 hours)
   - Return sorted by file_number ascending

3. **DeleteAnswerSheetFiles:**
   - Delete specified files from S3
   - Permission check: same as upload

### 4. Integration with Existing Sync

Answer sheet files do NOT use the action-based sync (`pushActions`/`watchChanges`). They use direct unary RPCs because:
- Files are large binary blobs, not suitable for the action log
- Upload is idempotent (re-uploading overwrites)
- No need for offline queueing of file uploads (files are stored locally and synced when online)

The client stores file paths locally in the `paper_submissions` table and uploads when connectivity is available.

### 5. AI Grading Integration (Future)

Later, a separate RPC will be added:
```protobuf
rpc GradeAnswerSheets(GradeRequest) returns (stream GradeProgress);
```
This will trigger server-side AI processing of uploaded answer sheets. Not needed now — just ensure the file storage structure supports it.
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## TRACK H — Answer Sheet Upload: Client (depends on S01, P01)
## ═══════════════════════════════════════════════════════════════════════════

### Task F01: Add file upload service for answer sheets [x]
**Files to create/modify:** `lib/services/file_upload.dart` (new), `lib/client.dart`
**Context files to read (if needed):** `AGENT.md` (§8 file caching, §9 file sync), `lib/services/CONTEXT.md`
**Depends on:** S01 (server API must exist)

**Specification:**

Create a service that handles uploading answer sheet images to S3 via signed URLs obtained from the server.

**File: `lib/services/file_upload.dart`**

```dart
/// Service for uploading and managing answer sheet files.
class FileUploadService {
  FileUploadService(this._channel);
  final ClientChannel _channel;
  
  /// Upload answer sheet images for a student's paper.
  ///
  /// 1. Requests signed PUT URLs from the server
  /// 2. Uploads each file via HTTP PUT
  /// 3. Returns the list of uploaded file numbers
  Future<Result<List<int>, String>> uploadAnswerSheets({
    required String schoolId,
    required String examId,
    required int subject,
    required int paper,
    required int studentAdm,
    required List<String> localPaths,  // local file paths from paper_submissions
    required String accessToken,
  }) async {
    // Implementation:
    // 1. Call Files.GetAnswerSheetUploadUrls with file_count = localPaths.length
    // 2. For each URL + localPath pair, HTTP PUT the file bytes
    // 3. Return Ok(fileNumbers) on success, Err(message) on failure
  }
  
  /// Get read URLs for existing answer sheets.
  Future<Result<List<AnswerSheetFile>, String>> getAnswerSheetUrls({
    required String schoolId,
    required String examId,
    required int subject,
    required int paper,
    required int studentAdm,
    required String accessToken,
  }) async {
    // Implementation:
    // 1. Call Files.GetAnswerSheetReadUrls
    // 2. Return the list of files with their read URLs
  }
}
```

**Register in `client.dart`:**
Add `FileUploadService` as a lazily-initialized property on the `Client` class, similar to how `Authentication` is registered.

**Update after completion:**
- [ ] Update `lib/services/CONTEXT.md` — add file_upload.dart entry
- [ ] Update `lib/CONTEXT.md` — note new service
- [ ] Mark this task `[x]`

---

### Task F02: Wire answer sheet upload to paper detail page [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/services/file_upload.dart` (from F01)
**Depends on:** F01

**Specification:**

Wire the `_AnswerSubmissionSheet` to upload files to S3 when online, in addition to saving them locally.

**Changes to `_AnswerSubmissionSheetState`:**

1. After `_addPhotos` saves files locally and persists to `paper_submissions` table, check connectivity and trigger upload:
```dart
// In _addPhotos, after local save:
if (mounted) {
  // Trigger background upload (non-blocking)
  _uploadPendingFiles();
}
```

2. Add `_uploadPendingFiles()` method:
```dart
Future<void> _uploadPendingFiles() async {
  final uploadService = client.fileUpload; // from F01
  final accessToken = cache.currentUser?.accessToken;
  if (accessToken == null) return;
  
  final result = await uploadService.uploadAnswerSheets(
    schoolId: widget.schoolId,
    examId: widget.examId,
    subject: widget.subject,
    paper: widget.paperNum,
    studentAdm: widget.student.adm,
    localPaths: _paths,
    accessToken: accessToken,
  );
  
  // Show subtle success/failure indicator (no blocking UI)
  switch (result) {
    case Ok(): break; // silent success
    case Err(:final error):
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload pending: $error')),
        );
      }
  }
}
```

3. Add a sync status indicator on each thumbnail:
   - Green check overlay when uploaded
   - Cloud-off icon when pending upload
   - Track upload status per file in local state

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note file upload wiring
- [ ] Mark this task `[x]`

---

### Task F03: Wire quick-grade button to fill random grades for submitted students [x]
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** F01 (needs upload service to verify files exist)

**Specification:**

**Current state:** The quick-grade button and AI mark button already exist and generate random grades (Tasks 19, 26 in CONTEXT.md). Verify they work correctly:

1. **Quick-grade button (per student):** When a student has submissions (`_submissions[adm]?.isNotEmpty`), the indigo `Icons.auto_fix_high` button should:
   - Be clickable (currently implemented)
   - Generate a random score 55–100 (currently implemented)
   - Flash the row with indigo color (currently implemented)
   - Update the score text field (desktop, currently implemented)

2. **AI Mark button (bulk):** When the paper is in `done` state and has submissions:
   - Show the gradient indigo→violet button with `Icons.auto_awesome`
   - On click: animate through phases (idle → analyzing → assigning → done)
   - Fill random grades for all students with submissions
   - Flash each row as it's graded

**Verify and fix any issues:**
- Ensure the quick-grade button only appears when `paper.status == PaperStatus.done || paper.status == PaperStatus.marked`
- Ensure the AI mark button is disabled when `!_hasSubmissions`
- Ensure the shimmer animation plays correctly during the analyzing phase
- Ensure the progress bar shows correct progress during the assigning phase
- Ensure the "done" state shows the check icon and count for 2 seconds before resetting

**Add one improvement:** When the AI mark button completes, play a subtle confetti-like animation or a satisfying completion animation (e.g. all row flash controllers fire in a staggered sequence, 30ms apart, creating a wave effect).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note AI grading verification
- [ ] Mark this task `[x]`

---

## ═══════════════════════════════════════════════════════════════════════════
## REMAINING COMPLETED TASKS (historical reference)
## ═══════════════════════════════════════════════════════════════════════════

### ~~Task C00: Commit current uncommitted progress in meaningful chunks~~ [x]

**Specification:**

Before starting the schema restructuring, all uncommitted work must be committed in logical, meaningful chunks. There are 33 changed/new files spanning multiple domains. Commit them in this order:

#### Commit 1: `db: add PaperSubmissions table and remove overly restrictive exam indexes`

Stage and commit:
```
lib/database/tables/papers.dart
lib/database/database.dart
lib/database/database.g.dart
schema.sql
```

This commit covers:
- New `PaperSubmissions` client-only table for storing answer image file paths
- Registration of `PaperSubmissions` in `AppDatabase` tables list and `deleteAllData`
- Schema version bump (3 → 5) with migration steps: dropping `uq_exams_allstream_type` and `uq_exams_stream_type` unique indexes, creating `paper_submissions` table
- Updated `schema.sql` removing those same unique indexes
- Regenerated `database.g.dart`

#### Commit 2: `feat: add exam batch creation, paper watching, and subject class queries`

Stage and commit:
```
lib/database/daos/exams_grades_dao.dart
lib/database/daos/exams_grades_dao.g.dart
lib/database/daos/subjects_dao.dart
lib/models/exam_group.dart
```

This commit covers:
- `ExamBatchEntry` typedef and `createExamBatch` for multi-grade exam creation
- `watchPaper` single-paper reactive stream
- Paper analytics and grade management additions in `ExamsGradesDao`
- `getSubjectsForClass` query in `SubjectsDao`
- New `ExamGroup` domain model for grouping exam rows by shared attributes

#### Commit 3: `feat: add log retry/revert support and sync engine robustness`

Stage and commit:
```
lib/database/daos/logs_dao.dart
lib/sync/delta_writer.dart
lib/sync/sync_engine.dart
```

This commit covers:
- `retryLog` and `deleteAndRevertLog` methods in `LogsDao` for failed action management
- `DeltaWriter`: FK-safe flushing (PRAGMA foreign_keys OFF/ON), improved null parsing, unknown table fallback logging
- `SyncEngine`: exponential backoff with jitter on reconnect, adaptive push interval, flush timer for idle delta batches, guard flag preventing duplicate reconnects

#### Commit 4: `ui: overhaul exams/grades screen, paper detail, and exam creation`

Stage and commit:
```
lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart
lib/ui/screens/school_dashboard/exams/exam_creation_page.dart
lib/ui/screens/school_dashboard/academics/paper_detail_page.dart
lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart
lib/ui/screens/school_dashboard/academics/grade_detail_page.dart
```

This commit covers:
- Major overhaul of exams/grades screen (11k+ line diff)
- New exam creation page with multi-grade support
- Enhanced paper detail page with answer submission and grading
- Updated exams tab and grade detail page

#### Commit 5: `ui: enhance notifications, system dashboard, and member screens`

Stage and commit:
```
lib/ui/screens/notifications/notifications_page.dart
lib/ui/screens/system/notifications/notifications_panel.dart
lib/ui/screens/system/schools/school_detail_screen.dart
lib/ui/screens/system/system_dashboard_screen.dart
lib/ui/screens/system/users/users_section.dart
lib/ui/screens/school_dashboard/members/members_page.dart
lib/ui/screens/school_dashboard/announcements/announcements_screen.dart
lib/ui/screens/school_dashboard/finance/finance_screen.dart
lib/ui/screens/school_dashboard/roles/school_roles_screen.dart
```

This commit covers:
- Overhauled notifications page with retry/revert actions for failed logs
- Enhanced system notifications panel
- System dashboard and school detail additions
- Users section improvements
- Minor fixes/additions to members, announcements, finance, and roles screens

#### Commit 6: `docs: update CONTEXT.md files and AGENT.md`

Stage and commit:
```
AGENT.md
lib/database/CONTEXT.md
lib/database/daos/CONTEXT.md
lib/models/CONTEXT.md
lib/ui/screens/school_dashboard/CONTEXT.md
lib/ui/widgets/CONTEXT.md
```

This commit covers:
- Updated AGENT.md with latest architectural decisions
- Updated all CONTEXT.md files to reflect new files and changed exports

#### Commit 7: `chore: update dependencies`

Stage and commit:
```
pubspec.lock
```

This commit covers:
- Updated dependency lock file

#### After all commits, stage and commit the current TASKS.md separately:

#### Commit 8: `docs: add schema restructuring v2 task list`

Stage and commit:
```
TASKS.md
```

**Execution notes:**
- Use `git add <files> && git commit -m "<message>"` for each chunk.
- Do NOT use `git add .` — stage only the listed files per commit.
- Verify each commit with `git log --oneline -1` after committing.
- If any file has unsaved buffer changes, save before staging.

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Context: What Changed and Why

These tasks implement the "Schema Restructuring v2" changes on the Flutter/Drift client side.
The server `TASKS.md` covers migration SQL, proto file edits, and Rust code updates.
The client tasks below cover Drift table definitions, DAOs, models, services, sync engine, enums, and AGENT.md updates.

### Summary of all changes:

1. **`subjects` table renamed to `subject_teachers`** — was a junction table mapping teachers to subjects in a class.
2. **New global `subjects` table** — auto-incrementing integer PK, stores the subject catalog (e.g. "Mathematics", "English"). Replaces `CbcSubject`/`EightFourFourSubject` enum-to-int mapping. System/Super-only.
3. **New global `topics` table** — auto-inc PK, unique on `(subject, grade, name)`. Grade-specific subdivisions of a subject. System/Super-only.
4. **New `streams` table** — per-school, per-grade stream definitions. Replaces grades/streams from old `settings.data` JSON.
5. **New `mpesa` table** — per-school M-Pesa Daraja API config. PK = school id. Replaces old `settings.mpesa` JSON.
6. **`settings` table removed** — no longer needed.
7. **New `exam_grades` junction table** — replaces `exams.grade` + `exams.stream`. No NULL streams.
8. **`exams` table modified** — `grade`/`stream` columns removed, `name` column added.
9. **`papers` table modified** — optional `topic` column added (FK → `topics.id`).
10. **`mastery` table modified** — `grade` column removed, `subject`/`topic` now FK to new global tables.
11. **All `subject smallint` columns** across ~6 tables changed to `subject integer` referencing `subjects.id`.
12. **New `Resource.subjects` (index 18)** in the permission model.
13. **New `SyncAction` values** for subjects, topics, streams, mpesa, exam_grades.
14. **Migration approach:** No incremental migration — clean database restart. Update initial schema code in place.

---

### ~~Task C01: Regenerate Dart proto stubs from updated server protos~~ [x]

**Files to create/modify:** `lib/proto/` (generated files)
**Context files to read:** `../ledger/protos/services/sync.proto`, `../ledger/protos/types/role.proto`

**Specification:**

After the server proto files are updated (server Tasks S04–S07), regenerate Dart stubs:

```sh
protoc --dart_out=grpc:lib/proto \
  -I../ledger/protos \
  ../ledger/protos/services/sync.proto \
  ../ledger/protos/services/authentication.proto \
  ../ledger/protos/types/role.proto \
  ../ledger/protos/types/user.proto \
  ../ledger/protos/types/member.proto \
  ../ledger/protos/types/verification.proto
```

Verify the generated files compile. Key changes to expect in generated code:
- `SubjectInsert` renamed to `SubjectTeacherInsert` (oneof field 12)
- New `SubjectInsert`, `TopicInsert`, `StreamInsert`, `MpesaInsert`, `ExamGradeInsert` messages
- `ExamInsert` no longer has `grade`/`stream`, has `name` instead
- `PaperInsert` has new `topic` field
- `MasteryInsert` no longer has `grade`
- `SettingsInsert` removed (field 25 reserved)
- New oneof fields 31–35 in `InsertData`
- New payload messages for all new actions
- `Resource` enum has `SUBJECTS = 18`
- `ExamGradeEntry` helper message

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C02: Rename `subjects.dart` → `subject_teachers.dart` and update Drift table~~ [x]

**Files to create/modify:** `lib/database/tables/subject_teachers.dart` (new), delete `lib/database/tables/subjects.dart` (old)
**Context files to read:** `lib/database/tables/subjects.dart`

**Specification:**

1. Delete `lib/database/tables/subjects.dart`.
2. Create `lib/database/tables/subject_teachers.dart`:

```dart
import 'package:drift/drift.dart';
import 'schools.dart';

class SubjectTeachers extends Table {
  @override
  String get tableName => 'subject_teachers';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  IntColumn get subject => integer()(); // FK → subjects.id (was smallint enum)
  TextColumn get teacher => text()();
  Int64Column get created => int64()();

  @override
  Set<Column> get primaryKey => {school, year, term, grade, stream, subject};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
    'FOREIGN KEY (subject)'
        ' REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
```

**Update after completion:**
- [ ] Update `lib/database/CONTEXT.md` if it exists
- [ ] Mark this task `[x]`

---

### ~~Task C03: Create new `subjects.dart` Drift table (global catalog)~~ [x]

**Files to create:** `lib/database/tables/subjects.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'curriculum_subjects.dart';

/// Global subject catalog. Populated by System/Super users only.
/// NOT the same as the old `subjects` table (which is now `subject_teachers`).
class Subjects extends Table {
  @override
  String get tableName => 'subjects';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get curriculum =>
      integer().map(const CurriculumTypeConverter())();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();
}
```

Note: The `CurriculumTypeConverter` already exists in `curriculum_subjects.dart`.

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C04: Create `topics.dart` Drift table~~ [x]

**Files to create:** `lib/database/tables/topics.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'subjects.dart';

/// Global topic catalog. Grade-specific subdivisions of a subject.
/// Populated by System/Super users only.
class Topics extends Table {
  @override
  String get tableName => 'topics';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get subject =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  TextColumn get name => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  List<String> get customConstraints => [
    'UNIQUE (subject, grade, name)',
  ];
}
```

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C05: Create `streams.dart` Drift table~~ [x]

**Files to create:** `lib/database/tables/streams.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'schools.dart';

/// Per-school stream definitions. Links a named stream to a grade.
class Streams extends Table {
  @override
  String get tableName => 'streams';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();
  TextColumn get name => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, grade, stream};
}
```

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C06: Create `mpesa.dart` Drift table~~ [x]

**Files to create:** `lib/database/tables/mpesa.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'schools.dart';

/// M-Pesa environment mode.
enum MpesaEnv {
  sandbox, // 0
  production, // 1
}

class MpesaEnvConverter extends TypeConverter<MpesaEnv, int> {
  const MpesaEnvConverter();
  @override
  MpesaEnv fromSql(int fromDb) => MpesaEnv.values[fromDb];
  @override
  int toSql(MpesaEnv value) => value.index;
}

/// Per-school M-Pesa Daraja API integration configuration.
class Mpesa extends Table {
  @override
  String get tableName => 'mpesa';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get consumerKey => text()();
  TextColumn get consumerSecret => text()();
  TextColumn get passkey => text()();
  TextColumn get shortcode => text()();
  IntColumn get env =>
      integer().map(const MpesaEnvConverter()).withDefault(const Constant(0))();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school};
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C07: Create `exam_grades.dart` Drift table~~ [x]

**Files to create:** `lib/database/tables/exam_grades.dart`

**Specification:**

```dart
import 'package:drift/drift.dart';
import 'exams.dart';

/// Junction table: which grades and streams participate in an exam.
/// No NULL streams — if exam spans all streams, one row per stream.
class ExamGrades extends Table {
  @override
  String get tableName => 'exam_grades';

  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  IntColumn get stream => integer()();

  @override
  Set<Column> get primaryKey => {exam, grade, stream};
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C08: Update `exams.dart` — add `name`, remove `grade` and `stream`~~ [x]

**Files to modify:** `lib/database/tables/exams.dart`
**Context files to read:** `lib/database/tables/exams.dart`

**Specification:**

Replace the current `Exams` table definition:

```dart
import 'package:drift/drift.dart';
import 'enums.dart';
import 'schools.dart';

class Exams extends Table {
  @override
  String get tableName => 'exams';

  TextColumn get id => text()();
  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get year => integer()();
  IntColumn get term => integer()();
  BoolColumn get personalized => boolean().withDefault(const Constant(false))();
  IntColumn get type => integer().map(const ExamTypeConverter())();
  IntColumn get start => integer()(); // days since epoch
  IntColumn get end => integer()(); // days since epoch
  TextColumn get teacher => text()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (start < end)',
    'FOREIGN KEY (school, year, term)'
        ' REFERENCES terms(school, year, term) ON DELETE CASCADE',
    'FOREIGN KEY (school, teacher)'
        ' REFERENCES teachers(school, user) ON DELETE CASCADE',
  ];
}
```

Key changes: `grade` and `stream` columns removed, `name` column added.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C09: Update `papers.dart` — add optional `topic`~~ [x]

**Files to modify:** `lib/database/tables/papers.dart`
**Context files to read:** `lib/database/tables/papers.dart`

**Specification:**

Add a nullable `topic` column to the `Papers` table and add the FK constraint.

After `paper` column:
```dart
  IntColumn get topic => integer().nullable()(); // FK → topics.id
```

Add to `customConstraints` list:
```dart
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
    'FOREIGN KEY (topic) REFERENCES topics(id) ON DELETE SET NULL',
```

Also change `subject` column — it was `integer()` already but had no FK. Now it FKs to `subjects.id`. Remove the old implicit subject usage and ensure the FK is in customConstraints.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C10: Update `mastery.dart` — remove `grade`, FK to subjects and topics~~ [x]

**Files to modify:** `lib/database/tables/mastery.dart`
**Context files to read:** `lib/database/tables/mastery.dart`

**Specification:**

Replace entirely:

```dart
import 'package:drift/drift.dart';
import 'schools.dart';
import 'subjects.dart';
import 'topics.dart';

class Mastery extends Table {
  @override
  String get tableName => 'mastery';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  IntColumn get student => integer()();
  IntColumn get subject =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get topic =>
      integer().references(Topics, #id, onDelete: KeyAction.cascade)();
  RealColumn get score => real()();
  Int64Column get created => int64()();
  Int64Column get updated => int64()();

  @override
  Set<Column> get primaryKey => {school, student, subject, topic};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (school, student)'
        ' REFERENCES students(school, adm) ON DELETE CASCADE',
  ];
}
```

Key: `grade` column removed. PK is now `(school, student, subject, topic)`.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C11: Update `grades.dart` — change subject type, add FK~~ [x]

**Files to modify:** `lib/database/tables/grades.dart`
**Context files to read:** `lib/database/tables/grades.dart`

**Specification:**

The `subject` column type stays `integer()` (it was already integer in Drift even when schema said smallint). Add a FK constraint to the customConstraints:

```dart
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C12: Update `lessons.dart` and `timetable.dart` — update FK references~~ [x]

**Files to modify:** `lib/database/tables/lessons.dart`, `lib/database/tables/timetable.dart`
**Context files to read:** Both files

**Specification:**

In both files, find any FK reference to `subjects(...)` and change to `subject_teachers(...)`.

In `lessons.dart`, the custom constraint:
```dart
'FOREIGN KEY (school, year, term, grade, stream, subject) REFERENCES subject_teachers(school, year, term, grade, stream, subject) ON DELETE RESTRICT'
```

In `timetable.dart`, the custom constraint:
```dart
'FOREIGN KEY (school, year, term, grade, stream, subject, teacher) REFERENCES subject_teachers(school, year, term, grade, stream, subject, teacher) ON DELETE CASCADE ON UPDATE CASCADE'
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C13: Delete `settings.dart` Drift table~~ [x]

**Files to delete:** `lib/database/tables/settings.dart`

**Specification:**

Delete the file entirely. The `settings` table is removed from the schema.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C14: Update `enums.dart` — add new SyncAction values, add MpesaEnv reference~~ [x]

**Files to modify:** `lib/database/tables/enums.dart`
**Context files to read:** `lib/database/tables/enums.dart`

**Specification:**

1. In the `SyncAction` enum, mark value 66 (`updateSettings`) as deprecated and add new values at the end:

```dart
  // Settings — DEPRECATED (table removed)
  @Deprecated('Settings table removed in schema v2')
  updateSettings(66),
```

Add new values after `deleteDiscount(76)`:

```dart
  // Subjects (global catalog)
  createSubject(77),
  updateSubject(78),
  deleteSubject(79),
  // Topics (global catalog)
  createTopic(80),
  updateTopic(81),
  deleteTopic(82),
  // Streams (per-school)
  createStream(83),
  updateStream(84),
  deleteStream(85),
  // M-Pesa (per-school)
  createMpesa(86),
  updateMpesa(87),
  deleteMpesa(88),
  // Exam Grades (junction)
  addExamGrade(89),
  removeExamGrade(90);
```

Total enum values: 91 (0–90).

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C15: Update `database.dart` — register new tables, remove Settings~~ [x]

**Files to modify:** `lib/database/database.dart`
**Context files to read:** `lib/database/database.dart`

**Specification:**

1. Add imports for new table files:
   - `tables/subject_teachers.dart`
   - `tables/topics.dart`
   - `tables/streams.dart`
   - `tables/mpesa.dart`
   - `tables/exam_grades.dart`

2. Remove import for `tables/settings.dart`.

3. In the `@DriftDatabase(tables: [...])` annotation:
   - Remove `Settings`
   - Replace old `Subjects` with `SubjectTeachers`
   - Add: `Subjects` (the new global one), `Topics`, `Streams`, `Mpesa`, `ExamGrades`

4. Update `MigrationStrategy.onCreate`:
   - Remove any raw SQL for `settings` indexes/triggers
   - Remove the `exams_stream_consistency_check` trigger
   - Update `grades_enrollment_check` trigger to JOIN through `exam_grades`
   - Update `grades_enrollment_check_update` trigger similarly
   - Add unique index: `CREATE UNIQUE INDEX uq_subjects_name_curriculum ON subjects(name, curriculum)`
   - Add unique index: `CREATE UNIQUE INDEX uq_topics_subject_grade_name ON topics(subject, grade, name)`
   - Add index: `CREATE INDEX idx_topics_subject ON topics(subject)`
   - Add index: `CREATE INDEX idx_streams_school ON streams(school, grade)`
   - Add index: `CREATE INDEX idx_exam_grades_grade ON exam_grades(grade, stream)`
   - Rename `subjects_class_teacher_idx` → `subject_teachers_class_teacher_idx` referencing `subject_teachers`
   - Rename `idx_subjects_school_teacher` → `idx_subject_teachers_school_teacher` referencing `subject_teachers`
   - Update `papers_within_exam_range` trigger if it references `exams.grade`/`exams.stream`

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C16: Update `delta_writer.dart` — handle new/renamed InsertData variants~~ [x]

**Files to modify:** `lib/sync/delta_writer.dart`
**Context files to read:** `lib/sync/delta_writer.dart`

**Specification:**

After proto stubs are regenerated (Task C01), update the `DeltaWriter` to handle:

1. Renamed: `InsertData.subject` (old) → `InsertData.subjectTeacher` (new, field 12 of oneof). The `SubjectTeacherInsert` maps to the `subject_teachers` table.

2. Removed: `InsertData.settings` (field 25) — remove the case that handled `SettingsInsert`.

3. New cases to add:
   - `InsertData.subjectCatalog` (field 31) → upsert into `subjects` table
   - `InsertData.topic` (field 32) → upsert into `topics` table
   - `InsertData.stream` (field 33) → upsert into `streams` table
   - `InsertData.mpesa` (field 34) → upsert into `mpesa` table
   - `InsertData.examGrade` (field 35) → upsert into `exam_grades` table

4. Update the `ExamInsert` handler — no longer has `grade`/`stream` fields, now has `name`.

5. Update the `PaperInsert` handler — now has optional `topic` field.

6. Update the `MasteryInsert` handler — no longer has `grade` field.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C17: Update `curriculum_subjects.dart` — deprecate enum-to-int approach~~ [x]

**Files to modify:** `lib/database/tables/curriculum_subjects.dart`

**Specification:**

The `CbcSubject` and `EightFourFourSubject` enums are no longer used as database column values — subjects are now rows in the `subjects` table with auto-inc integer IDs. However, these enums and their labels may still be useful as a reference/seed list.

1. Add a comment at the top of the file:
```dart
// NOTE: CbcSubject and EightFourFourSubject enums are no longer used as
// database column values. Subjects are now rows in the global `subjects` table.
// These enums are retained as a reference for seeding the subjects table
// and for label display. The CurriculumType enum and its converter ARE still
// actively used by the new `subjects` table.
```

2. Keep `CurriculumType` and `CurriculumTypeConverter` — these are actively used.
3. Keep `CbcSubject` and `EightFourFourSubject` with their labels — useful for seeding.
4. Keep `KenyaCounty` and its converter — unrelated to this change, still used.
5. Remove `CbcSubjectConverter` and `EightFourFourSubjectConverter` — no longer needed since subjects are no longer stored as enum int values.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C18: Update models — `permissions.dart` add `Resource.subjects`~~ [x]

**Files to modify:** `lib/models/permissions.dart`
**Context files to read:** `lib/models/permissions.dart`

**Specification:**

Add `subjects` to the `Resource` enum at index 18 (after `ai`):

```dart
enum Resource {
  users,        // 0
  schools,      // 1
  owners,       // 2
  teachers,     // 3
  staff,        // 4
  students,     // 5
  departments,  // 6
  classes,      // 7
  attendance,   // 8
  lessons,      // 9
  exams,        // 10
  grades,       // 11
  fees,         // 12
  payments,     // 13
  announcements,// 14
  roles,        // 15
  plans,        // 16
  ai,           // 17
  subjects,     // 18  — global subject/topic catalog
}
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

### ~~Task C19: Update DAOs — rename and add new DAOs as needed~~ [x]

**Files to modify:** Relevant DAO files in `lib/database/daos/`
**Context files to read:** `lib/database/daos/` directory listing

**Specification:**

1. Find any DAO that references the old `Subjects` Drift table (the class, not the table name) and update to `SubjectTeachers`.

2. Find any DAO that references `Settings` and remove those methods.

3. Find any DAO query referencing `exams.grade` or `exams.stream` and update to JOIN through `exam_grades`.

4. Find any DAO query referencing `mastery.grade` and remove that column from the query.

5. Add DAO methods for new tables if needed:
   - `subjects` (global catalog): `watchSubjects()`, `watchSubjectsByCurriculum(CurriculumType)`, insert/update/delete
   - `topics`: `watchTopicsBySubjectAndGrade(int subjectId, int grade)`, insert/update/delete
   - `streams`: `watchStreamsBySchoolAndGrade(String schoolId, int grade)`, insert/update/delete
   - `mpesa`: `watchMpesa(String schoolId)`, insert/update/delete
   - `exam_grades`: CRUD as part of exam operations

These can be added to existing domain-grouped DAOs or new ones as appropriate.

**Update after completion:**
- [ ] Update relevant `CONTEXT.md` files
- [ ] Mark this task `[x]`

---

### ~~Task C20: Update `AGENT.md` — reflect all schema changes~~ [x]

**Files to modify:** `AGENT.md`

**Specification:**

Update the following sections:

1. **§5 Database Design** — mention the new tables (`subjects`, `topics`, `streams`, `mpesa`, `exam_grades`) and the rename (`subjects` → `subject_teachers`). Note `settings` table is removed.

2. **§7a SyncAction Enum** — update to show 91 values (0–90) including the new ones. Mark `updateSettings(66)` as deprecated.

3. **§4 Folder Structure** — no structural change needed, but note new table files.

4. **§13 Division of Labour** — no change needed.

5. **§17a Resource & Action Design** — add `Resource.subjects` (index 18) to the Resource table:
   | 19 | Subjects | `subjects`, `topics` | System/Super-only catalog management |

   Add to Action Context Per Resource table:
   | Subjects | Create, Read, Update, Delete |

6. **§14 gRPC Proto Files** — update `sync.pb.dart` and `sync.pbgrpc.dart` notes to reflect new Insert messages, renamed `SubjectTeacherInsert`, removed `SettingsInsert`, new payload messages.

7. **§12 Pending / Undecided Items** — no new items from this change.

8. **§2 Tech Stack** — no change.

9. **§5.1 Overview** — update table count: the total is now 30 backend tables minus `settings` (29) plus `subjects`, `topics`, `streams`, `mpesa`, `exam_grades` = **34 synced backend tables** plus 2 client-only (`accounts`, `logs`). Update the count accordingly.

10. **§16 Sync Strategy - Current Network Boundary** — no change (sync actions are already covered).

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C21: Run `build_runner` and fix compilation errors~~ [x]

**Specification:**

```sh
dart run build_runner build --delete-conflicting-outputs
```

Fix any compilation errors:
- Missing imports due to renamed/deleted files
- Type mismatches from changed column types
- References to removed `Settings` table/data class
- References to old `SubjectsData` (now `SubjectTeachersData`)
- References to removed `exams.grade`/`exams.stream`/`mastery.grade`

After fixing:
```sh
flutter analyze
```

Ensure zero errors. Warnings about the deprecated `updateSettings` are acceptable.

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C22: Update `client.dart` and services — remove settings references~~ [x]

**Files to modify:** `lib/client.dart`, any service file referencing settings
**Context files to read:** `lib/client.dart`

**Specification:**

1. Search for any reference to `Settings`, `SettingsData`, `UpdateSettingsPayload`, or `settings` table across all service files.
2. Remove those references.
3. If `client.dart` or any service exposes a `updateSettings` method, remove it.

**Update after completion:**
- [x] Mark this task `[x]`

---

### ~~Task C23: Update `schema.sql` — apply all changes to the client reference schema~~ [x]

**Files to modify:** `schema.sql` (project root)

**Specification:**

The `schema.sql` at the project root serves as the client-side reference for the database schema. Apply ALL the same changes that were applied to the server migration SQL:

1. Add `subjects` (global catalog) and `topics` tables
2. Rename old `subjects` → `subject_teachers`, change subject column type
3. Add `streams`, `mpesa` tables
4. Remove `settings` table
5. Modify `exams` — add `name`, remove `grade`/`stream`
6. Add `exam_grades` junction table
7. Modify `papers` — add `topic`, change `subject` type
8. Modify `grades` — change `subject` type, add FK
9. Modify `mastery` — remove `grade`, change `subject`/`topic` types, add FKs
10. Modify `lessons`/`timetable` — change `subject` type, update FK refs
11. Update all affected triggers
12. Update all affected indexes

This file must match the server migration SQL exactly (minus client-only `accounts` and `logs` tables which stay as-is).

**Update after completion:**
- [x] Mark this task `[x]`

---