# EduXal — Task Board (Revision 8 — Brand Colours, Tab Layout, User Actions, Plans Polish, Donut Charts, Settings Grades & Streams)

> **Scope:** Ten targeted improvement areas. Tasks are ordered to minimise
> conflicts — global token changes first, then layout changes, then feature
> additions, then visual polish.
>
> **Previous revisions:** All tasks from Revisions 1–6 (Tasks 1–8 + county
> enum addition) are complete. This revision builds on that foundation.
>
> **Reference files (read before starting any task):**
> - `AGENT.md` — architecture and conventions. **Read it in full first.**
> - `lib/ui/theme/app_theme.dart` — design tokens (colours, radii, spacing)
> - `lib/ui/screens/account/account_screen.dart` — primary aesthetic reference
> - `lib/ui/screens/system/system_dashboard_screen.dart` — dashboard scaffold
> - `lib/ui/screens/system/home/system_stats_section.dart` — charts
> - `lib/ui/screens/system/schools/school_detail_screen.dart` — school detail
> - `lib/ui/screens/system/users/users_section.dart` — users list
> - `lib/ui/screens/system/members/members_section.dart` — members list
> - `lib/ui/screens/system/plans/plans_section.dart` — plans section
> - `lib/database/tables/enums.dart` — all enums + converters
> - `lib/database/daos/users_dao.dart` — user mutation methods
> - `lib/database/daos/plans_dao.dart` — plan mutation methods
>
> **Design mandate (carry this into every task):**
> You are a UI/UX designer and frontend developer with more than four decades
> of experience crafting breathtaking, world-class interfaces. Every pixel
> you touch must reflect that pedigree. "Compiles without errors" is the
> floor, not the ceiling. Thin typography, generous whitespace, precise
> borders, sharp corners (radius ≤ 6 for interactive elements), no pill
> shapes, no heavy shadows, no bold colours competing with each other. When
> in doubt, look at the account screen — that is the house style.
>
> **Legend:**
> - `[ ]` Not started
> - `[~]` In progress
> - `[x]` Done
>
> **Agent rules — read these before writing a single line of code:**
> 1. Work on **exactly one task** per session, in the order they appear below.
> 2. Read every reference file listed in that task's "Files to read" section
>    before writing any code.
> 3. After finishing the task, **mark it `[x]`** in this file and save it.
> 4. Run `flutter analyze` and fix all issues before declaring the task done.
> 5. Do **not** look ahead or do work described in future tasks.
> 6. Do **not** rewrite files from scratch unless the task explicitly says so.
>    Make targeted, surgical edits.
> 7. Preserve all existing functionality unless the task explicitly changes it.
> 8. When a task says "match the aesthetic of X", open X and copy exact values
>    (colours, radii, font sizes, weights, spacing, border treatments).
> 9. After marking the task done, **stop and wait for the project owner**
>    to review and instruct you to begin the next task.

---

## Task 1 — Brand Colour Overhaul: Indigo Primary, Bright Green Action [x]

**Goal:** Establish the correct brand identity project-wide. Indigo is the
primary brand colour. Bright green is the action/CTA colour (not teal, not
dark green). Remove all uses of the current `brandGreen` teal (`0xFF00A884`)
and replace with a bright, vivid green. Update `cs.primary` in the dark
theme so the `+` button on desktop and all `cs.primary`-coloured interactive
elements are indigo, not the system-generated seed colour.

### Colour specification

In `lib/ui/theme/app_theme.dart`:

```
brandIndigo = Color(0xFF3F51B5)   — unchanged, stays as primary seed
brandGreen  = Color(0xFF4CAF50)   — REPLACE the current 0xFF00A884 teal
                                    with bright Material Green 500
```

The new `brandGreen` (`0xFF4CAF50`) is the action colour. It is used for:
- All FAB backgrounds (mobile + desktop `+` button)
- All "Save", "Create", "Confirm" filled buttons
- Success states and the "done" phase of the animated save icon (Task 5)

`cs.primary` remains `brandIndigo` in light mode. In dark mode it was
`_indigoDark = Color(0xFF8C9EFF)` — keep that; it is already correct.

### What to search and replace

After updating `brandGreen` in `app_theme.dart`, grep the entire codebase
for every hardcoded reference to the old teal value `0xFF00A884` and also
for every use of `AppTheme.brandGreen` to verify they all now resolve to
the new bright green. There should be no stragglers.

Additionally, audit every place `backgroundColor: cs.primary` or
`color: cs.primary` appears on interactive buttons/FABs. On desktop the
`+` button currently uses `cs.primary` as its background — in light mode
`cs.primary` is `brandIndigo`, which is correct (indigo button). On dark
mode it was also rendering as indigo. This is the desired behaviour — do
not change it.

The FABs (mobile `FloatingActionButton.small`) currently use
`backgroundColor: AppTheme.brandGreen`. After this task they will use the
new bright green, which is what the project owner wants.

### FAB shape — reduce border radius

`FloatingActionButton.small` in Flutter defaults to a large pill/circle
radius. The project owner wants a sharper, more architectural shape.

In `_buildFab` (inside `system_dashboard_screen.dart`), every
`FloatingActionButton.small(...)` call must have an explicit `shape`
override:

```dart
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(10),
),
```

Apply this to **every** `FloatingActionButton.small` call in the file —
the single-action FABs, the multi-action FABs, and the Plans/Members
single-purpose FABs.

Also apply the same override globally via the theme. In
`AppTheme._build(...)`, add a `floatingActionButtonTheme` entry:

```dart
floatingActionButtonTheme: FloatingActionButtonThemeData(
  backgroundColor: brandGreen,
  foregroundColor: Colors.white,
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),
),
```

This means individual FAB widgets no longer need to repeat
`backgroundColor`, `foregroundColor`, `elevation`, or `shape` — they
inherit from the theme. Remove the now-redundant per-FAB properties
(but keep `onPressed` and `child` of course).

### Files to read before starting
- `lib/ui/theme/app_theme.dart` — full file
- `lib/ui/screens/system/system_dashboard_screen.dart` — `_buildFab` method
- Any other file that references `AppTheme.brandGreen` (use grep)

### Acceptance criteria
- `AppTheme.brandGreen` is `Color(0xFF4CAF50)`.
- No file in the project references the old teal `0xFF00A884`.
- All FABs render with `BorderRadius.circular(10)` — noticeably less round
  than the previous circle/pill default.
- The desktop `+` button is indigo in light mode and `_indigoDark` in dark
  mode — driven by `cs.primary`, not hardcoded.
- `flutter analyze` reports zero issues.

---

## Task 2 — Desktop Tab Bar: Fit-to-Content Width, Hug the + Button [x]

**Goal:** Fix two related layout problems with the desktop tab bar inside
`_DesktopBody`:

**Problem 1 — Tab container takes `Flexible` (expands to fill Row):**
The tab bar container is wrapped in `Flexible`, which lets it expand to
fill the available width between the left edge and the `+` button. On wide
screens this leaves a large empty gap inside the pill container to the
right of the last tab. The container should be no wider than its content.

**Problem 2 — `Spacer` between tabs and + button pushes them apart:**
There is a `const Spacer()` between the `Flexible` tab container and the
`+` button. This pushes the `+` button to the far right. Remove it. The
`+` button should sit 8 px to the right of the tab container, always.

### Solution

Replace the current `Row` structure in the tab bar section:

```
Row(
  children: [
    Flexible( ← tab container ),
    Spacer(),
    + button,
  ],
)
```

With:

```
Row(
  children: [
    // Tab container — shrink-wrapped, scrollable internally
    IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Allow scroll but never exceed available width minus
          // the + button width (32) and its left gap (8) and
          // the row's horizontal padding (48 total both sides).
          maxWidth: MediaQuery.sizeOf(context).width - 48 - 8 - 40,
        ),
        child: Container(
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: ..., // unchanged
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            ...
          ),
        ),
      ),
    ),
    const SizedBox(width: 8),   // breathing gap
    + button (AnimatedBuilder),
    // NO Spacer here
  ],
)
```

**Important detail about `IntrinsicWidth`:** `IntrinsicWidth` on a
scrollable widget does not work well in Flutter — it will try to measure
the intrinsic width of the `TabBar` which for a scrollable tab bar is the
full content width, potentially overflowing. The correct approach is:

Use a `LayoutBuilder` at the Row level and pass the available width as a
`maxWidth` constraint to the tab container via `ConstrainedBox`. The tab
container uses `isScrollable: true` on the `TabBar` and the outer
`ConstrainedBox` simply caps how wide the pill background can grow. The
pill background will be exactly as wide as needed to show all tabs up to
the constraint, and the tabs scroll if needed.

```dart
LayoutBuilder(
  builder: (context, constraints) {
    // Reserve space for: + button (32) + gap (8) + row padding (48).
    final maxTabWidth = constraints.maxWidth - 88.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxTabWidth),
          child: Container(
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: ..., // existing pill decoration, unchanged
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              ... // all existing properties unchanged
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: tabController,
          builder: (context, _) {
            ... // existing + button logic, unchanged
          },
        ),
      ],
    );
  },
)
```

Wrap the outer `Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), ...)` 
container as normal — the `LayoutBuilder` goes inside it, replacing the
existing `Row`.

### On wide screens

When the screen is wide enough that all 6 tab labels fit without
scrolling, the `ConstrainedBox` will have a `maxWidth` larger than the
tab content. The `TabBar` (with `isScrollable: true`) renders at its
natural content width. The pill background `Container` is the parent of
the `TabBar` — but a `Container` with no `width` set will try to fill its
constraint. To prevent the pill expanding beyond the tabs, wrap the inner
`Container` in a `FittedBox` or use `UnconstrainedBox` on the pill
**background only** while keeping the `ConstrainedBox` as the outer bound:

Actually the cleanest solution: Use `IntrinsicWidth` on the pill
`Container` and make the `ConstrainedBox` sit outside it:

```dart
ConstrainedBox(
  constraints: BoxConstraints(maxWidth: maxTabWidth),
  child: IntrinsicWidth(          // <-- pill shrinks to tab content width
    child: Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: ...,            // pill background
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        ...
      ),
    ),
  ),
),
```

`IntrinsicWidth` on a non-scrollable axis (the cross axis of the `TabBar`)
is safe here because the `TabBar` is only scrollable horizontally and
`IntrinsicWidth` queries the intrinsic width of the `TabBar`'s children
which are all `Tab(text: ...)` — finite, measurable widths. Verify this
renders correctly; if `IntrinsicWidth` causes a Flutter assertion about
unbounded width on a scrollable child, fall back to: measure tabs by
computing total tab label widths programmatically in `initState` and set
an explicit width. Document whichever approach works.

### Files to read before starting
- `lib/ui/screens/system/system_dashboard_screen.dart` —
  `_DesktopBody.build` (lines ~565–748), specifically the tab bar `Row`

### Acceptance criteria
- On a narrow desktop window: the pill container is as wide as the tabs
  that fit, then tabs scroll. The `+` button sits 8 px to the right of
  the pill, not at the far right edge.
- On a wide desktop window: the pill container is exactly as wide as all
  6 tab labels — no empty space inside the pill to the right of "Plans".
- `flutter analyze` reports zero issues.

---

## Task 3 — "This Is Me" Indicator on Users and Members Lists [x]

**Goal:** In both `UsersSection` and `MembersSection`, add a subtle visual
indicator on the list row of the currently logged-in user (the active
account). This tells the user at a glance which record is theirs.

### How to identify the current user

The active account id is available via `cache.currentUser?.user.id`.
Compare this to each row's `user.id`. When they match, the row is "me".

### Visual treatment

- Add a small `YOU` label — `fontSize: 9`, `fontWeight: FontWeight.w600`,
  `letterSpacing: 0.8`, colour `cs.primary` — inside a thin outlined chip:
  `border: Border.all(color: cs.primary.withValues(alpha: 0.5), width: 1)`,
  `borderRadius: BorderRadius.circular(4)`,
  `padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2)`,
  background `cs.primary.withValues(alpha: 0.07)`.
- Place this chip to the **left** of the existing action icons area (desktop)
  or to the left of the `more_vert` menu icon (mobile), with 8 px spacing
  between the chip and the first action icon.
- On mobile, the chip appears inline in the row even without hover — it is
  always visible for the "me" row (unlike action icons which are
  hover-only on desktop).
- Do not alter the row height. The chip is small enough to fit inline.
- In `MembersSection`, the same treatment applies.

### Implementation notes

Both `_UserRowState` and `_MemberRowState` need to read
`cache.currentUser?.user.id` and compare to `widget.user.id`. This is a
synchronous in-memory read — no stream required.

Pass the current user id down from the section widget to avoid reading
`cache` directly in row widgets (keep `cache` access at the section level).
Add a `String? currentUserId` field to both `_UserList` / `_MemberList`
and their row widgets.

In `UsersSection.build`, compute `final currentUserId = cache.currentUser?.user.id`
before building `_UserList`. Pass it through. Same for `MembersSection`.

### Files to read before starting
- `lib/ui/screens/system/users/users_section.dart` — `_UserList`,
  `_UserRow`, `_UserRowState`
- `lib/ui/screens/system/members/members_section.dart` — `_MemberList`,
  `_MemberRow`, `_MemberRowState`
- `lib/client.dart` — `cache.currentUser` shape

### Acceptance criteria
- The current user's row in both lists shows a `YOU` chip.
- Other rows show no chip.
- Row height is unchanged.
- `flutter analyze` reports zero issues.

---

## Task 4 — Bulk Actions on Users and Members: Suspend, Promote, Demote, Purge [x]

**Goal:** Replace the non-functional multi-select toolbar in `UsersSection`
(and mirror in `MembersSection`) with a fully functional bulk-action bar
that supports: **Suspend**, **Promote** (level up), **Demote** (level down),
and **Purge**. Delete (soft trash) already exists but is not wired up —
wire it up too. Actions are shown contextually based on the selected set.

Also add individual row-level actions that are currently missing: **Promote**
and **Demote** for level changes (in addition to the existing Elevate/trash
actions). Read the current state carefully before adding to avoid duplication.

### Bulk action bar specification

Replace the current placeholder toolbar (the `Container` with hardcoded
`TODO` comments) with a proper action bar:

```
┌─────────────────────────────────────────────────────────────────┐
│  ✕  3 selected          [Suspend]  [Promote]  [Demote]  [Purge] │
└─────────────────────────────────────────────────────────────────┘
```

- The ✕ button clears the selection (existing behaviour — keep it).
- The count label stays (existing — keep it).
- Action buttons are `IconButton` widgets with tooltips and colours:
  - **Suspend** (`Icons.block_outlined`, amber `Color(0xFFFFB300)`) —
    sets all selected users' status to `UserStatus.suspended`.
    Only shown if at least one selected user is NOT already suspended.
  - **Trash/Delete** (`Icons.delete_outline_rounded`, `cs.error`) —
    sets all selected users' status to `UserStatus.deleted` (soft delete).
    Show a single confirmation dialog listing the count.
    Only shown if at least one selected user is not already deleted.
  - **Promote** (`Icons.arrow_upward_rounded`, `cs.primary`) —
    increments the level of eligible users:
    `normal → system`, `system → super_`.
    Only shown if ALL selected users have the same current level AND
    a higher level exists (i.e. not all already `super_`).
    Requires `permissions.level == UserLevel.super_` to promote to
    `super_`; otherwise only `normal → system` is available.
  - **Demote** (`Icons.arrow_downward_rounded`, muted `cs.onSurfaceVariant`) —
    decrements the level: `super_ → system`, `system → normal`.
    Only shown if ALL selected users are at the same level AND a lower
    level exists (i.e. not all already `normal`).
    Requires `permissions.level == UserLevel.super_` for any demotion
    involving `super_`.
  - **Purge** (`Icons.delete_forever_rounded`, `cs.error`) —
    permanently deletes. Only visible to `super_` users
    (`permissions.level == UserLevel.super_`). Show a **serious warning
    dialog** before executing (see below).

### Purge warning dialog

The purge confirmation must feel weighty and irreversible:

```dart
AlertDialog(
  title: Row(children: [
    Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
    SizedBox(width: 8),
    Text('Permanently delete ${count} user(s)?'),
  ]),
  content: Column(children: [
    Text(
      'This action CANNOT be undone. The following records will be '
      'permanently removed from the database with no possibility of '
      'recovery:',
    ),
    SizedBox(height: 8),
    // List up to 5 names, then "and N more..."
    ...names,
    SizedBox(height: 12),
    Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.errorContainer, ...),
      child: Text(
        'Type "DELETE" to confirm',
        style: TextStyle(color: cs.onErrorContainer),
      ),
    ),
    // A TextField where user must type "DELETE" exactly.
    TextField(...),
  ]),
  actions: [
    TextButton('Cancel', ...),
    FilledButton('Purge permanently',
      style: FilledButton.styleFrom(backgroundColor: cs.error),
      onPressed: confirmEnabled ? _executePurge : null,
    ),
  ],
)
```

The "Purge permanently" button is only enabled once the user has typed
"DELETE" exactly into the text field.

### Individual row action additions

In `_UserRowState._buildDesktopActions` (and the mobile popup menu), the
existing actions are: Trash, Purge, and whatever else is present. Read the
file first to see exactly what exists. Then add what is missing:

- **Suspend** action: if user is not already suspended and not deleted.
- **Restore** action (`Icons.restore_rounded`, teal): if user is suspended
  or deleted — restores to `UserStatus.active`.
- **Promote** / **Demote** level actions: contextual, same rules as bulk.

For `MembersSection._MemberRowState`, the existing actions are: Remove,
Elevate, Suspend, Trash, Purge. Rationalise these:
- **Elevate** already does level up — rename its tooltip to "Promote" for
  consistency. Keep the logic.
- Add **Demote** action (icon `Icons.arrow_downward_rounded`): only shown
  if user is system or super.
- Add **Restore** action: if user is suspended or deleted.
- Keep Remove, Trash, Purge as-is.

### DAO methods

Check `lib/database/daos/users_dao.dart` for:
- `updateUserStatus(String userId, UserStatus status, {required String accountId})`
- `updateUserLevel(String userId, UserLevel level, {required String accountId})`
- `purgeUser(String userId, {required String accountId})`

These should already exist from prior work. If any are missing, add them
following the existing pattern (write to DB + write log entry in a
transaction).

Add **batch variants** that operate on a list of user IDs efficiently:
```dart
Future<void> bulkUpdateStatus(
  List<String> userIds,
  UserStatus status, {
  required String accountId,
});

Future<void> bulkUpdateLevel(
  List<String> userIds,
  UserLevel level, {
  required String accountId,
});

Future<void> bulkPurge(
  List<String> userIds, {
  required String accountId,
});
```

Each bulk method runs all writes in a single `transaction()` call. Each
individual user write still produces its own log entry within that
transaction.

### After executing a bulk action

Clear the selection: `setState(() => _selectedIds.clear())`.
Show a `SnackBar` summarising what was done.

### Files to read before starting
- `lib/ui/screens/system/users/users_section.dart` — full file, especially
  the selection toolbar and `_UserRowState`
- `lib/ui/screens/system/members/members_section.dart` — full file,
  especially `_MemberRowState._buildDesktopActions` and `_buildMobileMenu`
- `lib/database/daos/users_dao.dart` — full file

### Acceptance criteria
- Multi-select shows a contextual action bar with only the eligible actions.
- Suspend, Trash, Promote, Demote bulk actions work correctly and update
  the DB.
- Purge bulk action shows the typed-confirmation dialog and only executes
  when "DELETE" is typed.
- Individual row actions include Suspend, Restore, Promote, Demote where
  contextually applicable.
- Selection is cleared and a SnackBar is shown after each bulk action.
- `flutter analyze` reports zero issues.

---

## Task 5 — Animated Save Icon Button (Global Edit Pattern) [x]

**Goal:** Introduce a reusable `AnimatedSaveButton` widget that replaces
bottom-of-screen "Save" / "Save Changes" buttons on all edit forms. The
button lives in the **top-right** of the edit header, is always visible,
and communicates the save state through a small animation.

### Widget specification

**File:** `lib/ui/widgets/animated_save_button.dart`

```dart
/// A compact icon button that animates through three states:
///
/// - [dirty]:      unsaved changes exist.
///                 Shows a checkmark icon coloured [cs.error] (red).
/// - [saving]:     save in progress.
///                 Shows an indigo circular progress arc slowly sweeping
///                 around the checkmark. The checkmark is cs.primary (indigo).
/// - [clean]:      saved successfully (auto-reverts after 1.5 s).
///                 The progress arc completes to a full circle in green,
///                 then fades to a green checkmark. After 1.5 s the button
///                 returns to clean/idle state (no icon shown, or a very
///                 faint static check).
///
/// When [isDirty] is false and [isSaving] is false the button shows the
/// faint idle check (alpha 0.25) — it is present but unobtrusive.
class AnimatedSaveButton extends StatefulWidget {
  const AnimatedSaveButton({
    super.key,
    required this.isDirty,
    required this.isSaving,
    required this.onSave,
    this.size = 36.0,
  });

  final bool isDirty;
  final bool isSaving;
  final VoidCallback? onSave;   // null = disabled
  final double size;
}
```

### Animation detail

The visual is a **thin circular progress arc** (stroke width 1.5 px,
`StrokeCap.round`) drawn around a checkmark icon using `CustomPaint`:

**Idle (clean, not dirty):**
- Checkmark icon: `Icons.check_rounded`, size 16, colour
  `cs.onSurfaceVariant.withValues(alpha: 0.25)`.
- No arc.

**Dirty (unsaved):**
- Checkmark icon: `Icons.check_rounded`, size 16, colour `cs.error`.
- A partial static arc (say 15 % of circle) in `cs.error.withValues(alpha: 0.4)`
  to hint at "incomplete". Use `AnimatedContainer` to transition smoothly
  from idle to dirty state.

**Saving (in progress):**
- Checkmark icon: `Icons.check_rounded`, size 16, colour `cs.primary`
  (indigo).
- A spinning progress arc: full `AnimationController` repeating with
  `duration: Duration(milliseconds: 900)`. Arc sweeps from 0° to 270°
  and rotates continuously. Colour: `cs.primary`.
- The button is non-tappable (`onPressed: null`, `InkWell` disabled).

**Success (just saved — triggered externally by calling `.complete()` on
the widget's state, or by the parent toggling `isSaving: false` and
`isDirty: false` simultaneously):**
- Arc animates from its current position to a full 360° circle in
  `Color(0xFF4CAF50)` (brand green), duration 300 ms.
- Then the checkmark icon colour transitions to brand green.
- After 1500 ms the widget auto-transitions back to Idle state with a
  150 ms fade.

### How to trigger states from the parent

The parent simply passes `isDirty` and `isSaving` boolean props. The
widget manages the animation internally by watching prop changes via
`didUpdateWidget`. The state machine:

```
props change           → internal state
isDirty=true           → dirty state
isSaving=true          → saving state (starts spinner)
isSaving=false,        → success state (starts completion arc)
  isDirty=false          then auto-returns to idle after 1500 ms
isSaving=false,        → idle (save was cancelled without changes)
  isDirty=true (still) → back to dirty state
```

### Apply to these edit forms

Replace the existing bottom `Save Changes` / `Save` / submit buttons with
`AnimatedSaveButton` in the following locations (one per location — they
all follow the same pattern):

1. **`_EditSchoolSheetState`** in `school_detail_screen.dart`:
   - Remove the `FilledButton('Save Changes', ...)` at the bottom.
   - Place `AnimatedSaveButton` in the title row (top-right, after the
     sheet title text and before the close × icon if there is one, or
     replacing the × with a combined close+save button row).
   - `isDirty`: starts `false`. Set to `true` as soon as any controller
     or `_editStatus` changes from the initial value (use `addListener`
     on each `TextEditingController` in `initState` and compare to
     initial values in the listener callback).
   - `isSaving`: `_saving`.

2. **`_PlanDetailSheetState`** in `plans_section.dart`:
   - Remove the `TextButton('Save', ...)` from the action bar.
   - Place `AnimatedSaveButton` in the header row at top-right.
   - `isDirty`: true once any edit field differs from the original plan.
   - `isSaving`: `_saving`.

3. **Role detail screen** (`role_detail_screen.dart`):
   - Wherever the role permissions are edited and saved, apply the same
     `AnimatedSaveButton` in the screen's app bar actions or header row.
   - Read the file first to understand the current save mechanism.

### Important constraint

The `AnimatedSaveButton` widget must live in
`lib/ui/widgets/animated_save_button.dart` and be importable from any
screen file. It has no dependencies on any DAO or service — it is a pure
UI widget driven by the `isDirty` and `isSaving` props.

### Files to read before starting
- `lib/ui/screens/system/schools/school_detail_screen.dart` —
  `_EditSchoolSheetState` (lines ~1281–1590)
- `lib/ui/screens/system/plans/plans_section.dart` —
  `_PlanDetailSheetState` (lines ~1021–1400)
- `lib/ui/screens/system/roles/role_detail_screen.dart` — full file
- `lib/ui/widgets/` directory listing — know what already exists

### Acceptance criteria
- `AnimatedSaveButton` widget exists in `lib/ui/widgets/`.
- The three visual states (dirty/red, saving/indigo spinner, clean/green)
  are clearly distinguishable.
- The success arc animation completes and auto-reverts to idle.
- The button is applied to the school edit sheet, plan detail sheet, and
  role detail screen.
- Bottom "Save" buttons are removed from those three locations.
- `flutter analyze` reports zero issues.

---

## Task 6 — School Detail: Status as Action Buttons, County Display Fix [x]

**Goal:** Two changes to the school detail screen.

### Part A — County display fix

The `_DetailChip` in `_HeaderSection` currently displays the county as
`"County 7"` (the raw integer). Replace it with the county name from the
`KenyaCounty` enum created in a previous task.

In `_HeaderSection.build`, wherever `school.county` is rendered, do:

```dart
// Before:
_DetailChip(
  icon: Icons.location_on_outlined,
  label: 'County ${school.county}',
  cs: cs,
),

// After:
_DetailChip(
  icon: Icons.location_on_outlined,
  label: _countyName(school.county),
  cs: cs,
),
```

Add a static helper:

```dart
static String _countyName(int countyNumber) {
  try {
    return KenyaCounty.values
        .firstWhere((c) => c.number == countyNumber)
        .label;
  } catch (_) {
    return 'County $countyNumber';
  }
}
```

Import `lib/database/tables/curriculum_subjects.dart` (where
`KenyaCounty` lives) at the top of `school_detail_screen.dart`.

### Part B — School status: remove dropdown, add action button group

In `_EditSchoolSheetState`, the `_StyledDropdown<SchoolStatus>` for the
status field must be removed. Status transitions are now driven by
contextual action buttons.

**Within the school edit sheet** (`_EditSchoolSheetState`), replace the
status dropdown with a horizontal row of contextual action buttons below
the field cards and above the `AnimatedSaveButton`. Show only the
transitions that make sense for the current status:

| Current status | Available actions |
|---|---|
| `trial`     | → Active ("Activate", green), → Suspended ("Suspend", amber), → Cancelled ("Cancel", grey) |
| `active`    | → Suspended ("Suspend", amber), → Cancelled ("Cancel", grey) |
| `cancelled` | → Active ("Reactivate", green) |
| `suspended` | → Active ("Reactivate", green), → Cancelled ("Cancel", grey) |
| `deleted`   | → Active ("Restore", green) — super only |

Each action is a compact outlined button:
`height: 32`, `fontSize: 12`, `fontWeight: w400`,
`borderRadius: BorderRadius.circular(6)`,
`side: BorderSide(color: actionColour.withValues(alpha: 0.5))`,
`foregroundColor: actionColour`,
`padding: EdgeInsets.symmetric(horizontal: 12)`.

Tapping an action button immediately calls `schoolsDao.updateSchoolStatus`
(does NOT wait for the Save action — status changes are instant and
independent of the other field edits). Show a brief `SnackBar` confirmation.

**Within the school list** (`_SchoolRowState` in `schools_section.dart`),
the existing desktop hover actions and mobile popup menu already have
Trash/Purge. Add status-transition actions there too:
- "Activate" (if trial/suspended/cancelled)
- "Suspend" (if trial/active)
- "Cancel" (if trial/active/suspended)
- Keep Trash (→ deleted) and Purge as-is.

These actions call `schoolsDao.updateSchoolStatus` directly.

### Files to read before starting
- `lib/ui/screens/system/schools/school_detail_screen.dart` —
  `_EditSchoolSheetState` (lines ~1281–1590), `_HeaderSection` (lines ~286–409)
- `lib/ui/screens/system/schools/schools_section.dart` —
  `_SchoolRowState` (lines ~815–1062)
- `lib/database/tables/curriculum_subjects.dart` — `KenyaCounty` enum
- `lib/database/daos/schools_dao.dart` — `updateSchoolStatus` method

### Acceptance criteria
- County displays as name ("Garissa") not number ("County 7").
- No status dropdown exists in the school edit sheet.
- Status action buttons appear with correct contextual options.
- Tapping a status action updates the DB immediately (independent of save).
- List row actions include status transitions.
- `flutter analyze` reports zero issues.

---

## Task 7 — Plans Tab: Status Actions, Purge, Default Pending, UI Polish [x]

**Goal:** Four improvements to the Plans section.

### Part A — Default status on create

In `_CreatePlanSheetState._submit()`, change:
```dart
status: const Value(PlanStatus.active),
```
to:
```dart
status: const Value(PlanStatus.pending),
```

### Part B — Status action buttons on plan cards and detail

**On `_PlanCard`:** Add an actions row at the bottom of each card (visible
to users with `permissions.can('plans.update')`). The actions are small
contextual icon buttons with tooltips:

| Plan status | Available actions |
|---|---|
| `pending`   | "Activate" (green `Icons.play_arrow_rounded`), "Delete" (red trash) |
| `active`    | "Suspend" (amber `Icons.pause_rounded`), "Delete" (red trash) |
| `suspended` | "Activate" (green), "Delete" (red trash) |
| `deleted`   | "Restore" (teal `Icons.restore_rounded`), "Purge" (red `Icons.delete_forever_rounded`, super only) |

Each icon button: `size: 18`, visual density compact, colour as above.
Action calls `plansDao.updatePlanStatus(plan.id, newStatus, accountId: accountId)`.
Purge calls `plansDao.purgePlan(plan.id, accountId: accountId)` — add
this method to `PlansDao` if it does not exist (hard delete from DB +
log entry with `LogOperation.delete`).

**Deleted plans** are only visible in the list when
`permissions.canSeeDeleted` is true. The `PlansSection` stream currently
returns all plans — filter out deleted ones unless the user is super:

```dart
// In PlansSection.build, filter the stream result:
final plans = snapshot.data!
    .where((p) => permissions.canSeeDeleted || p.status != PlanStatus.deleted)
    .toList();
```

**Purge warning:** Show the same serious dialog pattern as in Task 4 (typed
"DELETE" confirmation). For a single plan purge, the dialog lists the plan
name specifically.

**In `_PlanDetailSheetState`:** Replace the existing `_confirmDelete`
bottom-sheet-based delete with two separate actions:
- "Delete" (soft delete → `PlanStatus.deleted`): show a simple
  `AlertDialog` confirming. Keep existing logic but use `AlertDialog`.
- "Purge" (hard delete, super only): show the serious typed-confirmation
  dialog. Only shown if `permissions.level == UserLevel.super_` and plan
  is already in `deleted` status (you can only purge what is already
  deleted). Add a `purgePlan` DAO method if missing.

### Part C — Create and Edit UI polish

The create plan sheet and edit form currently use oversized text, old
`Switch` widgets, and generally feel bold and dated. Refine:

**Typography throughout:**
- Section headers (`_buildSectionHeader`): keep current style (`fontSize: 10`,
  `w500`, uppercase, `letterSpacing: 1.1`) — this is already correct.
- Field labels (`_FormLabel`): `fontSize: 12`, `fontWeight: w400`,
  `color: cs.onSurfaceVariant.withValues(alpha: 0.75)`.
- Field input text: `fontSize: 13`, `fontWeight: w400`.
- Plan name in sheet header: `fontSize: 15`, `fontWeight: w400`,
  `letterSpacing: -0.1`.
- Amount field: add a `KES` prefix label inside the field decoration
  (use `prefixText: 'KES  '` with `prefixStyle: TextStyle(fontSize: 13,
  fontWeight: w400, color: cs.onSurfaceVariant)`).

**Feature toggles:** Replace the `Switch` widgets with a more refined
toggle. Use a custom `_FeatureToggle` widget — a tappable row where the
right side shows a small coloured dot (10 × 10, green when enabled, muted
grey when disabled) instead of a full `Switch`. This is cleaner and
lighter. Keep the exact same tap behaviour (`setState(() => _features[key] = !current)`).

**Sheet bottom radius:** The create sheet's
`BorderRadius.vertical(top: Radius.circular(20))` is a pill-shaped
half-circle. Change to `Radius.circular(14)` to align with the sharper
aesthetic established in the brand overhaul.

**Status field in edit form (`_PlanEditForm`):** Replace the
`_StyledDropdown<PlanStatus>` with the same action button group pattern
as school status (Task 6 Part B). Show only contextually valid
transitions.

### Part D — `AnimatedSaveButton` on plan edit

This was already covered in Task 5. Verify it is applied to
`_PlanDetailSheetState` as specified there. If Task 5 is complete, this
is a no-op. If not, apply it here.

### Files to read before starting
- `lib/ui/screens/system/plans/plans_section.dart` — full file
- `lib/database/daos/plans_dao.dart` — check for `purgePlan` method
- `lib/models/system_permissions.dart` — `canSeeDeleted`, `level`

### Acceptance criteria
- New plans default to `PlanStatus.pending`.
- Deleted plans are hidden from non-super users.
- Each plan card shows contextual status action buttons.
- Purge requires typed confirmation.
- Create/edit UI is visibly lighter: thinner text, dot toggles, refined spacing.
- `flutter analyze` reports zero issues.

---

## Task 8 — Donut Chart: Thicker Rings, Visible Track, Refined Painter [x]

**Goal:** The nested concentric donut chart rings are currently too thin and
the uncoloured track arc is nearly invisible against the background. Fix
both issues to produce a chart that is clearly legible, well-defined, and
close in feel to the reference image provided by the project owner (thick,
clearly separated rings where the empty portion is a visible muted arc, not
invisible).

### What the reference image shows

- **Three concentric rings**, each with significant stroke width (the rings
  look solid and substantial, not hair-thin).
- **The uncoloured (empty) portion of each ring is clearly visible** as a
  warm/neutral arc — it has its own colour (a desaturated warm grey/beige,
  noticeably different from the page background). It is NOT the same colour
  as the background, so the ring circle is always complete and readable.
- **The coloured (filled) portion** uses the segment colour at full opacity
  — rich and saturated, no transparency.
- **Each ring is clearly separated** from adjacent rings by visible space.
- The overall donut is compact but not tiny — it reads as a real chart, not
  a decoration.
- **Critically:** the spiral offset rule (each arc starts where the
  previous ended) must be preserved — do NOT copy the reference image's
  layout where all arcs start on the same side.

### Specific changes to `_DonutPainter` in `system_stats_section.dart`

**1. Increase stroke width:**
```dart
// Before:
static const double _strokeWidth = 5.0;
static const double _ringGap = 4.0;

// After:
static const double _strokeWidth = 9.0;   // thicker — clearly visible
static const double _ringGap = 5.0;       // slightly wider gap between rings
```

**2. Fix the track colour:**

The track (`cs.outlineVariant.withValues(alpha: 0.18)`) is nearly
invisible on both light and dark backgrounds. Replace it with a
proper visible-but-muted colour:

```dart
// Light mode track: a warm neutral — like the reference image's beige-grey.
// Dark mode track: a lighter slate.

final trackColor = cs.brightness == Brightness.light
    ? const Color(0xFFE0DDD8)   // warm off-white grey — clearly visible on white
    : cs.surfaceContainerHighest.withValues(alpha: 0.85); // clearly visible on dark
```

Pass `cs` to the painter (it already is passed — just update the track
colour calculation).

**3. Preserve `StrokeCap.round` on filled arcs.** The reference image shows
rounded ends on the arcs — keep this. But the **track arc** should use
`StrokeCap.butt` (flat ends) so it forms a complete unbroken circle.
Currently both use the same paint which has `StrokeCap.round` — separate
the track paint from the arc paint:

```dart
final trackPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = _strokeWidth
  ..strokeCap = StrokeCap.butt    // ← flat, forms a complete circle
  ..color = trackColor;

// Per-segment:
final arcPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = _strokeWidth
  ..strokeCap = StrokeCap.round   // ← rounded ends for the coloured arc
  ..color = segments[i].color;    // full opacity — no alpha reduction
```

**4. Chart size increase:**

The current chart sizes are too small for the thicker rings. Update the
`chartSize` calculation in `_StatCardState.build`:

```dart
// Before (approximate):
final chartSize = isMobile ? 56.0 : 64.0;

// After:
final chartSize = isMobile ? 72.0 : 80.0;
```

Find the exact location where `chartSize` is computed and update it.
Also update the `_CardGridSkeleton` skeleton card dimensions to match so
the loading state does not reflow when data arrives.

**5. Segment colours at full opacity:**

In `_DonutPainter.paint`, the segment colours are currently used as-is,
which is correct — they already have no alpha. Do not add `withValues(alpha: ...)` 
to segment colours. Confirm this is the case and remove any opacity
reduction on segment colours that may have crept in.

**6. Card aspect ratio:**

With larger charts, the desktop card aspect ratio needs a small adjustment.
In `_CardGridContent.build`, change:

```dart
// Before:
childAspectRatio: isDesktop ? 1.85 : ...

// After:
childAspectRatio: isDesktop ? 1.6 : 1.45,
```

For mobile the aspect ratio also needs updating since mobile cards now
render the donut. Find the `crossAxisCount` + `childAspectRatio` block
and adjust.

**7. Desktop collapsed row number chips:**

In the collapsed desktop stats row (the number chips shown before the
user expands the grid), the chips currently have no visual container.
Add a subtle container per chip so they feel intentional:

Each chip: `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)`,
`color: cs.surfaceContainer`,
`borderRadius: BorderRadius.circular(AppTheme.kRadius)`,
`border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))`.
The number and label sit inside this container. This makes the collapsed
row feel like real UI rather than floating text.

### Files to read before starting
- `lib/ui/screens/system/home/system_stats_section.dart` — **full file**,
  especially `_DonutPainter`, `_NestedDonutChart`, `_StatCardState`,
  `_CardGridContent`, `_CardGridSkeleton`, and the desktop collapsed row.

### Acceptance criteria
- Ring stroke width is visibly thicker — rings read as solid shapes, not
  lines.
- The empty (track) portion of each ring is clearly visible on both light
  and dark backgrounds — it has its own warm neutral / slate colour and is
  NOT the same as the page background.
- The filled arc ends are rounded (`StrokeCap.round`).
- The track arcs form complete circles (`StrokeCap.butt`).
- The spiral offset rule is preserved: each arc starts where the previous
  ended.
- The collapse/expand desktop animation still works.
- `flutter analyze` reports zero issues.

---

## Task 9 — School Settings: Grades & Streams (CBC + 8-4-4) [x]

> **Context:** The current settings tab lets a school pick a single curriculum
> (CBC **or** 8-4-4), then tick grade-level groups and individual subjects.
> That was a misjudgement. The correct model is:
> - A school may support **both** curricula simultaneously.
> - For each curriculum the school can enable specific **individual grades**.
> - For each enabled grade the school can define its **streams** — a list of
>   name → code mappings (e.g. "Green" → 1, "Blue" → 2, or "A" → 1, "B" → 2).
> - **Subjects are not configured here.** They remain compile-time enums and
>   will be assigned by teachers when setting up subjects per term.

### Part A — Redefine `SchoolConfig` in `lib/models/school_config.dart`

Replace the current flat `{curriculum, enabledLevels, enabledSubjects}` shape
with a new multi-curriculum structure. The existing `SchoolConfig` class, its
`fromJson`/`toJson`, and the `CurriculumLevel` / `levelsFor` / `subjectLabel`
helpers must all be updated or replaced.

**New domain types (add to or replace the bottom of `school_config.dart`):**

```dart
/// A stream within a grade — name is the display label, code is the integer
/// stored in enrollments.stream / attendance.stream / etc.
class GradeStream {
  const GradeStream({required this.name, required this.code});
  final String name;   // e.g. "Green", "Blue", "A", "North"
  final int code;      // e.g. 1, 2, 3 — the smallint stored in the DB

  factory GradeStream.fromJson(Map<String, dynamic> j) =>
      GradeStream(name: j['name'] as String, code: (j['code'] as num).toInt());
  Map<String, dynamic> toJson() => {'name': name, 'code': code};

  GradeStream copyWith({String? name, int? code}) =>
      GradeStream(name: name ?? this.name, code: code ?? this.code);
}

/// One grade within a curriculum that the school has enabled, together with
/// its stream definitions.
class GradeConfig {
  const GradeConfig({required this.grade, required this.streams});
  final int grade;                  // DB grade integer — see grade numbering below
  final List<GradeStream> streams;  // ordered by code ascending

  factory GradeConfig.fromJson(Map<String, dynamic> j) => GradeConfig(
    grade: (j['grade'] as num).toInt(),
    streams: (j['streams'] as List<dynamic>? ?? [])
        .map((e) => GradeStream.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'grade': grade,
    'streams': streams.map((s) => s.toJson()).toList(),
  };
}

/// One curriculum entry inside [SchoolConfig].
class CurriculumConfig {
  const CurriculumConfig({required this.type, required this.grades});
  final CurriculumType type;        // CurriculumType.cbc or .eightFourFour
  final List<GradeConfig> grades;   // sorted by grade ascending

  factory CurriculumConfig.fromJson(Map<String, dynamic> j) {
    final rawType = (j['type'] as num).toInt();
    final type = CurriculumType.values.firstWhere(
      (e) => e.index_ == rawType,
      orElse: () => CurriculumType.cbc,
    );
    return CurriculumConfig(
      type: type,
      grades: (j['grades'] as List<dynamic>? ?? [])
          .map((e) => GradeConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'type': type.index_,
    'grades': grades.map((g) => g.toJson()).toList(),
  };
}

/// Top-level settings config stored in settings.data JSON.
///
/// A school may enable both curricula simultaneously.
/// JSON shape:
/// {
///   "version": 2,
///   "curricula": [
///     {
///       "type": 0,               // 0 = CBC, 1 = 8-4-4
///       "grades": [
///         {
///           "grade": 3,          // Grade 1 in CBC (see grade numbering)
///           "streams": [
///             {"name": "Green", "code": 1},
///             {"name": "Blue",  "code": 2}
///           ]
///         }
///       ]
///     }
///   ]
/// }
class SchoolConfig {
  const SchoolConfig({required this.curricula});
  final List<CurriculumConfig> curricula;

  bool get isEmpty => curricula.isEmpty;
  bool get hasCbc =>
      curricula.any((c) => c.type == CurriculumType.cbc);
  bool get has844 =>
      curricula.any((c) => c.type == CurriculumType.eightFourFour);

  CurriculumConfig? configFor(CurriculumType type) =>
      curricula.where((c) => c.type == type).firstOrNull;

  factory SchoolConfig.defaults() => const SchoolConfig(curricula: []);

  factory SchoolConfig.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version < 2) {
      // Discard legacy v1 config — it used a different shape.
      return SchoolConfig.defaults();
    }
    return SchoolConfig(
      curricula: (json['curricula'] as List<dynamic>? ?? [])
          .map((e) => CurriculumConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'curricula': curricula.map((c) => c.toJson()).toList(),
  };

  SchoolConfig copyWith({List<CurriculumConfig>? curricula}) =>
      SchoolConfig(curricula: curricula ?? this.curricula);
}
```

**Grade numbering convention** — keep this in a const map in `school_config.dart`
so both the UI and the DAO use the same values:

```dart
// CBC grades: PP1=1, PP2=2, Grade 1–9 = 3–11, Grade 10–12 = 12–14
const Map<int, String> kCbcGradeLabels = {
  1:  'PP1',
  2:  'PP2',
  3:  'Grade 1',
  4:  'Grade 2',
  5:  'Grade 3',
  6:  'Grade 4',
  7:  'Grade 5',
  8:  'Grade 6',
  9:  'Grade 7',
  10: 'Grade 8',
  11: 'Grade 9',
  12: 'Grade 10',
  13: 'Grade 11',
  14: 'Grade 12',
};

// 8-4-4 grades: Standard 1–8 = 1–8, Form 1–4 = 41–44
const Map<int, String> kEightFourFourGradeLabels = {
  1: 'Standard 1',
  2: 'Standard 2',
  3: 'Standard 3',
  4: 'Standard 4',
  5: 'Standard 5',
  6: 'Standard 6',
  7: 'Standard 7',
  8: 'Standard 8',
  41: 'Form 1',
  42: 'Form 2',
  43: 'Form 3',
  44: 'Form 4',
};

Map<int, String> gradeLabelsFor(CurriculumType type) =>
    type == CurriculumType.cbc ? kCbcGradeLabels : kEightFourFourGradeLabels;
```

The old `CurriculumLevel`, `kCbcLevels`, `k844Levels`, `levelsFor`,
`subjectLabel` identifiers are **no longer needed by the settings screen** and
must be deleted from `school_config.dart`. If they are referenced elsewhere,
keep them but move them to a new file `lib/models/curriculum_levels.dart` so
`school_config.dart` stays clean.

### Part B — Update `SettingsDao.updateSchoolConfig` in `lib/database/daos/settings_dao.dart`

The method signature and internal logic stays the same — it serialises
`SchoolConfig` to JSON and stores it in `settings.data`. No change is needed
to the DAO except:

- The `SchoolConfig` import now comes from the rewritten model.
- The merge logic in `updateSchoolConfig` must use the new `toJson()` shape
  (already the case — it just calls `config.toJson()`).
- Verify the DAO still compiles after the model change.

### Part C — Rewrite `_SettingsTab` UI in `lib/ui/screens/system/schools/school_detail_screen.dart`

This is the bulk of the work. Replace everything from `class _SettingsTab`
through to just before `class _PlaceholderTab` with the new implementation
described below.

**Remove entirely:**
- `_SettingsViewMode`
- `_SettingsEditMode` / `_SettingsEditModeState`
- `_LevelPickerRow`
- `_CurriculumCard`
- `_SubjectChip`
- `_InfoChip`
- `_SettingsEmptyHint`

**Keep (they are reused by the new UI):**
- `_SettingsSectionCard` — keep as-is; it still wraps each section.

**New UI structure:**

`_SettingsTabState` — top-level state widget:
- Holds `bool _editMode`.
- Reads `settingsDao.watchSettings(school.id)` via `StreamBuilder<Setting?>`.
- Calls `_parseConfig(settingsRow?.data)` — same helper, but now parses the
  new `SchoolConfig` shape (version 2; discards v1 if found).
- Renders either `_SettingsViewMode` (read-only) or `_SettingsEditMode`
  (full edit form), switching with `AnimatedSwitcher` exactly as before.

---

**`_SettingsViewMode`** (read-only display):

Shows one `_SettingsSectionCard` per enabled curriculum, each containing an
expandable grade list. Grades that have streams show the stream chips inline.

Layout for each curriculum card (e.g. "CBC"):

```
┌─────────────────────────────────────────────────────┐
│  CBC   Competency-Based Curriculum        [Edit ✎] │  ← header row (only on first card)
├─────────────────────────────────────────────────────┤
│  ▸  Grade 1            2 streams                    │  ← collapsed row
│  ▾  Grade 2                                         │  ← expanded row
│     ● Green  1                                      │
│     ● Blue   2                                      │
│  ▸  Grade 3            1 stream                     │
└─────────────────────────────────────────────────────┘
```

- Each grade row is a `ListTile`-style row: curriculum label on the left,
  stream count badge on the right (e.g. "2 streams"), tap to expand/collapse.
- Expanded grade shows its stream list: each stream is a small row with a
  filled colour dot (use `AppTheme.brandGreen` tinted) + stream name on the
  left, stream code (integer) on the right in a muted monospace chip.
- If `config.isEmpty` show a single empty-state hint with an "Add curriculum"
  action that enters edit mode (if `canEdit`).
- The edit icon button sits in `_SettingsSectionCard`'s `editButton` slot on
  the **first** section card only.

---

**`_SettingsEditMode` / `_SettingsEditModeState`** (full edit form):

State held in `_SettingsEditModeState`:

```dart
late List<CurriculumConfig> _curricula;   // mutable working copy
bool _saving = false;
String? _error;
```

Initialised from `widget.initialConfig.curricula` (deep-copied so cancel
reverts).

Top section — **Curriculum toggle row**:

```
┌─────────────────┐  ┌─────────────────┐
│  ☑  CBC         │  │  ☐  8-4-4       │
└─────────────────┘  └─────────────────┘
```

Two tappable cards side-by-side (like the old `_CurriculumCard`). Each card
has a checkbox/tick indicator top-right. Tapping a card that is **not** yet
enabled adds a new empty `CurriculumConfig` for it. Tapping one that **is**
enabled shows a confirmation snackbar/inline warning ("Removing CBC will
delete all its grade and stream configuration — tap again to confirm") and on
second tap removes it. Use a `_pendingRemoval` field to implement the
two-tap confirm.

Below the curriculum toggles — one expandable **grade section per enabled
curriculum**, rendered in order (CBC first, then 8-4-4 if both active):

```
CBC ──────────────────────────────────── [+ Add grade]
  ▾  Grade 1                             [✕]
       Streams:
       ┌──────────────┬──────────┬────────┐
       │  Green       │   1      │  [✕]  │
       │  Blue        │   2      │  [✕]  │
       └──────────────┴──────────┴────────┘
       [+ Add stream]
  ▸  Grade 2                             [✕]
  [+ Add grade]

8-4-4 ─────────────────────────────────  [+ Add grade]
  ▸  Standard 1                          [✕]
```

**Grade rows:**
- Display the grade label (from `gradeLabelsFor(type)[grade]`).
- `[✕]` icon button on the right removes the grade (and all its streams).
- Tapping the row header expands it to show the streams editor.
- An already-expanded row collapses on tap.

**"+ Add grade" button:**
- Opens a bottom sheet or inline dropdown listing all grades for that
  curriculum that are **not yet added**.
- Grade picker shows the full ordered list from `gradeLabelsFor(type)`.
- Already-added grades are shown greyed out and non-tappable.
- Tapping an available grade adds a new `GradeConfig(grade: n, streams: [])`
  to that curriculum's grade list.

**Streams inside an expanded grade:**
- Each stream row: `[name TextField] | [code IntField] | [✕]`
- Name field: plain text, max 20 chars.
- Code field: integer input, range 1–99.
- Validation (shown inline below the streams list, not as a dialog):
  - Stream codes must be **unique within the grade** — if two streams share
    the same code, show: *"Stream codes must be unique within a grade."*
  - Stream names must be **non-empty**.
- `[+ Add stream]` button at the bottom of the expanded streams list.
  Tapping it appends a new `GradeStream(name: '', code: nextCode)` where
  `nextCode` is `(maxExistingCode + 1)` or `1` if none exist yet, and
  immediately shows it as an editable row.

**Save / Cancel buttons** at the bottom (same style as existing edit mode).
On save: validate all curricula → if errors exist set `_error` and stay in
edit mode → if clean, call `settingsDao.updateSchoolConfig(...)` and call
`widget.onSaved()`.

---

**Visual elevation and colour differentiation targets:**

| Layer | Treatment |
|---|---|
| Page background | `cs.surface` (default scaffold colour) |
| `_SettingsSectionCard` | `cs.surfaceContainerLow` fill, 1 px `cs.outlineVariant` border, radius 6 |
| Curriculum toggle cards (inactive) | `cs.surfaceContainerLowest` fill, 1 px `cs.outlineVariant` border |
| Curriculum toggle cards (active) | `brandIndigo` at 6 % alpha fill, 1 px `brandIndigo` at 30 % alpha border |
| Grade rows (collapsed header) | `cs.surfaceContainerLow` |
| Grade rows (expanded area) | `cs.surfaceContainer` — one step darker than the card background |
| Stream rows inside expanded grade | `cs.surfaceContainerHigh` — another step darker, making three visible elevation tiers |
| Stream code chip | Monospace font, `cs.surfaceContainerHighest` fill, 0.5 px border |
| "Add grade" / "Add stream" text buttons | `brandIndigo` colour, no fill, no border, small (12 px font) |

Use `BoxDecoration` + `Container` — **not** `Card` or `Material` widgets —
to achieve precise elevation layering without unwanted shadows.

---

### Part D — Remove the subjects configuration from display

In `_SettingsViewMode` (old) there was an "Enabled Subjects" section card.
**Delete it entirely.** Subjects are no longer a school-level setting.

In `_SettingsEditMode` (old) the `_LevelPickerRow` showed subject chips.
**Delete all of that.** The new edit form has no subject selection whatsoever.

---

### Grade picker bottom sheet

Implement as a private `_GradePickerSheet` widget in the same file:

```dart
class _GradePickerSheet extends StatelessWidget {
  const _GradePickerSheet({
    required this.curriculumType,
    required this.alreadyAdded,   // Set<int> of grade ints already in config
    required this.onPick,         // void Function(int grade)
    required this.cs,
  });
  ...
}
```

- Displayed with `showModalBottomSheet`.
- Shows a scrollable list of all grades for `curriculumType` from
  `gradeLabelsFor(curriculumType)`.
- Grades in `alreadyAdded` are shown with a tick icon and muted text
  (non-tappable).
- Available grades are tappable rows; tapping calls `onPick(grade)` and
  closes the sheet.

---

### Files to read before starting

- `lib/models/school_config.dart` — current model (will be rewritten)
- `lib/database/daos/settings_dao.dart` — DAO to verify after model change
- `lib/ui/screens/system/schools/school_detail_screen.dart` — settings section
  (classes `_SettingsTab` through `_SettingsEmptyHint`, and `_SettingsSectionCard`)
- `lib/database/tables/curriculum_subjects.dart` — `CurriculumType` enum lives here
- `lib/ui/theme/app_theme.dart` — colour tokens

---

### Acceptance criteria

- [x] `SchoolConfig` is version-2 shape: `{version: 2, curricula: [{type, grades: [{grade, streams: [{name, code}]}]}]}`.
- [x] Old version-1 JSON in `settings.data` is silently discarded (returns `SchoolConfig.defaults()`).
- [x] A school can have CBC only, 8-4-4 only, or both enabled simultaneously.
- [x] View mode shows one section per enabled curriculum with expandable grade rows and stream details.
- [x] Edit mode shows curriculum toggle cards; enabling/disabling a curriculum works with two-tap confirm on removal.
- [x] Grades are added via a bottom sheet picker listing all available grades for that curriculum.
- [x] Each grade can have any number of streams; each stream has a name and a code.
- [x] Stream codes are validated as unique within a grade before save; error shown inline.
- [x] Stream names are validated as non-empty before save.
- [x] Subjects do not appear anywhere in the settings UI.
- [x] Three visible elevation tiers: card → grade row → stream row.
- [x] `flutter analyze` reports zero issues.

---

## Execution Order

Tasks must be completed strictly in this order:

| # | Task | Why this order |
|---|---|---|
| 1 | Brand colour overhaul (green + FAB radius) | All later tasks inherit correct colours |
| 2 | Desktop tab bar fit-to-content layout | Pure layout — no colour deps |
| 3 | "This is me" indicator on user/member lists | Simple addition, no deps |
| 4 | Bulk actions: suspend, promote, demote, purge | Requires correct brand colours from Task 1 |
| 5 | Animated save icon button (global) | Required by Tasks 6 and 7 |
| 6 | School detail: county name + status actions | Requires Task 5 for save button |
| 7 | Plans tab: status actions, purge, UI polish | Requires Task 5 for save button |
| 8 | Donut chart: thicker rings, visible track | Last — purely visual, no feature deps |
| 9 | School settings: grades & streams (CBC + 8-4-4) | No deps on other open tasks — can be done after any task |

---

## Completed Task Groups (Previous Revisions)

- **Revision 1 (Task Group A–E):** Database foundations, proto layer,
  client.dart, authentication service, file cache.
- **Revision 2 (Task Group F–J):** Home screen, system dashboard scaffold,
  schools CRUD, users CRUD, members, roles.
- **Revision 3 (Tasks 1–7):** Role detail screen, plans, settings,
  integrations (M-Pesa), notifications, account screen.
- **Revision 4 (various):** Stats DAO, system stats section (bar charts v1),
  school detail screen (owners, subscriptions placeholder, integrations).
- **Revision 5 (Tasks 1–13):** Home screen top bar, membership cards,
  dashboard nav redesign, icon tab bar, plans/notifications tab extraction,
  create role sheet, grade level picker, charts stat cards with bars,
  final polish pass.
- **Revision 6 (Tasks 1–8 + county enum):** Kenyan curriculum subject enums,
  KenyaCounty enum, school settings tab (curriculum/levels/subjects),
  status dot on school header, logo picker on create/edit school, owners
  card layout, members role modal, user detail sheet cleanup (action-based
  level/status), nested donut charts (initial implementation).