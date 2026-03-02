# EduXal — Task Board (Revision 5 — Home Screen, Dashboard, Plans & Roles Polish)

> **Scope:** Home screen aesthetic overhaul, system dashboard navigation and
> chart redesign, plans tab extraction, role creation UI parity with edit
> flow, grade level picker improvement, and app bar removal on dashboard.
>
> **Previous revisions:** All tasks from Revisions 1–4 (Task Groups A–J,
> Tasks 1–15) are complete. This revision builds on that foundation.
>
> **Reference files (read before starting any task):**
> - `AGENT.md` — architecture and conventions
> - `lib/ui/screens/account/account_screen.dart` — **primary design reference** for aesthetic language (section containers, dividers, row patterns, spacing, border treatment, typography weights)
> - `lib/ui/theme/app_theme.dart` — design token source
> - `lib/ui/screens/home/home_screen.dart` — home screen (target of Tasks 1–3)
> - `lib/ui/screens/system/system_dashboard_screen.dart` — dashboard scaffold
> - `lib/ui/screens/system/home/system_stats_section.dart` — charts
> - `lib/ui/screens/system/notifications/notifications_panel.dart`
> - `lib/ui/screens/system/settings/system_settings_screen.dart` — plans UI
> - `lib/ui/screens/system/roles/create_role_sheet.dart`
> - `lib/ui/screens/system/roles/role_detail_screen.dart` — edit flow reference
> - `lib/ui/screens/system/roles/roles_section.dart`
> - `lib/database/daos/system_stats_dao.dart`
> - `lib/models/system_stats.dart`
> - `lib/models/system_permissions.dart`
> - `lib/database/tables/enums.dart`
>
> **Legend:**
> - `[ ]` Not started
> - `[~]` In progress
> - `[x]` Done
>
> **Agent mandate:**
> - You are considered to be a designer/developer with 4 decades of
>   experience in building beautiful, functional user interfaces. That is
>   why we are trusting you with these tasks. Bring your full aesthetic
>   sensibility, your deep understanding of layout, rhythm, whitespace,
>   and visual hierarchy to every pixel you touch. Do not settle for
>   "compiles and works" — settle for "looks and feels world-class."
> - Work on **one task at a time**, in order. Do not skip ahead.
> - After completing each task, **mark it as `[x]` done** in this file.
> - Run `flutter analyze` after each task and confirm zero issues.
> - These are **refinement and feature** tasks. Read existing code first,
>   understand its structure, and make targeted edits. Do not rewrite
>   entire files from scratch unless the task explicitly says so.
> - Preserve all existing functionality unless a task explicitly changes it.
> - When a task references a design pattern from the account screen or
>   another existing screen, open that file and copy the exact values
>   (colours, radii, font sizes, weights, spacing, border treatments).
> - Each task is self-contained. Do not look ahead to future tasks or
>   attempt to do work described in other tasks.

---

## Task 1 — Redesign Home Screen Top Bar to Match Account Screen Aesthetic [x]

**Context:** The home screen (`lib/ui/screens/home/home_screen.dart`) top
bar currently contains the "eduxal" wordmark on the left and a system
badge button (SYSTEM/SUPER chip) next to it. These elements feel alien
and disconnected from the rest of the app's design language. The account
screen (`lib/ui/screens/account/account_screen.dart`) has a cohesive,
clean, minimal feel that should be the reference for the home screen.

**Goal:** Restyle the `_buildTopBar` method so the top bar feels like it
belongs to the same app as the account screen — same visual weight, same
spacing rhythm, same border/color treatments.

**File:** `lib/ui/screens/home/home_screen.dart`

**Requirements:**

1. Open `lib/ui/screens/account/account_screen.dart` and study the
   spacing, font weights, colour opacity values, and container styling
   used throughout. These exact values are your design tokens.
2. Restyle the "eduxal" wordmark: reduce it to `fontSize: 18` with
   `fontWeight: FontWeight.w300` and `letterSpacing: -0.5`. The text
   should feel like a whisper, not a shout — light and architectural.
3. Restyle the system badge (SYSTEM/SUPER chip): use the same container
   styling pattern as the `_sectionContainer` in the account screen —
   thin 1px border using `cs.outline.withValues(alpha: 0.5)` in dark
   mode and `cs.outlineVariant` in light mode, `BorderRadius.circular(4)`,
   background `cs.surfaceContainer` instead of the current
   `surfaceContainerHighest.withValues(alpha: 0.4)`. The shield icon
   and label should be `cs.onSurfaceVariant` at alpha `0.75`. Reduce
   the label font to `fontSize: 9`, `fontWeight: FontWeight.w500`.
4. Adjust the overall top bar padding to `EdgeInsets.fromLTRB(16, 12, 16, 12)`
   to feel tighter and more refined. The current `20, 16, 16, 16` is
   slightly unbalanced.
5. The avatar button on the right stays as-is. Do not touch `UserAvatar`.
6. Ensure the section header "MEMBERSHIPS" label below the top bar uses
   consistent left padding with the new top bar (change from `left: 20`
   to `left: 16`).
7. Verify the result in both light and dark themes. The badge should not
   look like a foreign element — it should feel integrated.

**Do not** touch any file other than `home_screen.dart`.

---

## Task 2 — Redesign Home Screen Membership Cards to Match Account Screen Containers [x]

**Context:** The membership cards (`_MembershipCard`) on the home screen
currently have `borderRadius: BorderRadius.circular(4)`, a single thin
border, and a fixed `padding: EdgeInsets.all(16)`. They look rigid and
somewhat flat compared to the section containers on the account screen
which have a more refined, integrated feel with `AppTheme.kRadius`,
proper dark/light border differentiation, and `cs.surfaceContainer`
backgrounds.

**Goal:** Restyle the membership cards so they match the aesthetic of the
account screen's `_sectionContainer` — same border radius, same border
colour logic, same background, same level of refinement.

**File:** `lib/ui/screens/home/home_screen.dart`

**Requirements:**

1. Open the account screen and read the `_sectionContainer` method
   (around line 1223). Copy its exact border colour logic:
   - Dark mode: `cs.outline.withValues(alpha: 0.5)`
   - Light mode: `cs.outlineVariant`
2. Change the card background to `cs.surfaceContainer` in both themes
   (remove the current `isDark ? cs.surface : null` conditional).
3. Change the border radius from `BorderRadius.circular(4)` to
   `BorderRadius.circular(AppTheme.kRadius)` to match the account
   screen's containers.
4. Increase the card's internal padding to
   `EdgeInsets.fromLTRB(16, 14, 16, 14)` for a slightly more compact
   vertical feel.
5. Adjust the school name text to `fontSize: 15`,
   `fontWeight: FontWeight.w400`, `letterSpacing: -0.1` for a slightly
   more refined feel.
6. Adjust the list padding from `horizontal: 20` to `horizontal: 16`
   to align with the new top bar padding from Task 1.
7. Adjust the grid padding from `horizontal: 24` to `horizontal: 16`
   for consistency.
8. The role chips (`_RoleChip`) should keep their current styling — they
   are fine. Only the card container itself is being restyled.
9. The arrow icon on the right of each card: change from
   `Icons.arrow_forward_rounded` to `Icons.chevron_right_rounded` at
   `size: 18` to match the account screen's row chevron pattern.
10. Verify in both light and dark themes. The cards should feel like they
    are siblings of the account screen sections.

**Do not** touch any file other than `home_screen.dart`.

---

## Task 3 — Polish Home Screen Empty, Loading, and Error States [x]

**Context:** With Tasks 1–2 complete, the top bar and cards feel cohesive.
Now the empty state, loading shimmer, and error state need to be brought
into alignment with the same refined aesthetic.

**File:** `lib/ui/screens/home/home_screen.dart`

**Requirements:**

1. Adjust the empty state icon size from `40` to `36`, and the text
   padding from `horizontal: 40` to `horizontal: 32` — tighter, more
   intentional.
2. Adjust the error state icon size from `40` to `36` similarly.
3. In the loading shimmer (`_LoadingShimmer`), adjust the shimmer bar
   container to use `BorderRadius.circular(AppTheme.kRadius)` and the
   same border colour logic as the new cards (from Task 2).
4. Adjust shimmer padding from any `horizontal: 20` to `horizontal: 16`
   to match the list padding.
5. Verify in both themes that loading, empty, and error states all feel
   like they belong to the same design system as the cards and top bar.

**Do not** touch any file other than `home_screen.dart`.

---

## Task 4 — Remove App Bar from System Dashboard and Embed Back Button Inline [x]

**Context:** The system dashboard (`lib/ui/screens/system/system_dashboard_screen.dart`)
currently has a standard `AppBar` with a title "System Dashboard", a
notification bell, and a settings gear. This wastes vertical space. The
project owner wants the app bar removed entirely to reclaim that space,
with the back button placed somewhere appropriate within the content area.

**Goal:** Remove the `AppBar` from the system dashboard on both mobile and
desktop layouts. Embed the back button as a subtle inline element within
the content. Remove the notification bell and settings gear from the
top — they will be re-added as tabs in later tasks.

**Files:**
- `lib/ui/screens/system/system_dashboard_screen.dart`

**Requirements:**

1. On **mobile**: remove the `appBar` property from the `Scaffold` in
   `_buildMobile`. Add a compact top row inside the body (above the tab
   content) with:
   - A back button (chevron_left_rounded, size 24) on the left
   - The text "System" in `fontSize: 16`, `fontWeight: FontWeight.w300`,
     `letterSpacing: -0.3` — subtle, not a title
   - Spacer, then nothing on the right (notifications and settings move
     to tabs in later tasks)
   - This row should have `padding: EdgeInsets.fromLTRB(8, 8, 16, 0)`.
   - The row should NOT be inside the animated SlideTransition/FadeTransition —
     it should be stable and always visible.
2. On **desktop**: remove the `appBar` property from the `Scaffold` in
   `_buildDesktop`. Add the same compact back-button row at the very top
   of the `_DesktopBody` Column, before the stats section.
3. Remove the `_buildAppBar` method entirely.
4. Remove the `_NotificationBell` widget class — it is no longer used
   here (it will be replaced by a notifications tab).
5. Keep the `endDrawer` for notifications functional for now — it will
   be removed in a later task when notifications become a tab. Just
   remove the bell that opens it; the drawer itself stays wired.
6. Do not remove the `_scaffoldKey` — it may still be needed by the
   endDrawer.
7. Verify both mobile and desktop layouts. The content should feel like
   it gained breathing room from losing the app bar.

**Do not** touch any file other than `system_dashboard_screen.dart`.

---

## Task 5 — Replace Mobile Bottom Navigation Bar with Icon Tabs [x]

**Context:** The system dashboard mobile layout currently uses a
`NavigationBar` (Material 3 bottom nav) with 5 destinations:
Home, Users, Members, Schools, Roles. The project owner wants to get
rid of the bottom nav bar entirely and use a tab bar (similar to the
desktop layout) for mobile as well, using **icon-only tabs** on mobile
to save space. Two new tabs will also be added: Notifications and Plans.

**Goal:** Replace the `NavigationBar` with a horizontal icon-only `TabBar`
positioned below the inline back-button row from Task 4. Wire up all 7
tabs: Home (charts), Users, Members, Schools, Roles, Notifications, Plans.

**Files:**
- `lib/ui/screens/system/system_dashboard_screen.dart`

**Requirements:**

1. Remove the `_buildBottomNav` method and the `bottomNavigationBar`
   property from the mobile Scaffold.
2. Create a `TabController` for mobile with **length 7** (replace the
   existing `_selectedTab` int-based navigation). The tabs in order:
   - 0: Home (icon: `Icons.bar_chart_rounded`)
   - 1: Users (icon: `Icons.people_outline_rounded`)
   - 2: Members (icon: `Icons.shield_outlined`)
   - 3: Schools (icon: `Icons.school_outlined`)
   - 4: Roles (icon: `Icons.verified_user_outlined`)
   - 5: Notifications (icon: `Icons.notifications_none_rounded`)
   - 6: Plans (icon: `Icons.credit_card_outlined`)
3. Add the mobile tab bar as a horizontal row of icon-only tabs below the
   back-button row from Task 4. Use the same pill-indicator styling as
   the desktop tab bar (the `Container` with `surfaceContainerHighest`
   background, `BorderRadius.circular(8)`, internal `TabBar` with
   surface-coloured indicator). But use `Tab(icon: Icon(..., size: 18))`
   instead of `Tab(text: ...)`.
4. Below the tab bar, the body should be a `TabBarView` with 7 children.
   For tabs 0–4, use the existing section widgets. For tab 5
   (Notifications), use the existing `NotificationsPanel` content but
   rendered inline (not as a drawer) — extract the notification list
   body into a reusable widget or simply use a `StreamBuilder` on
   `logsDao.watchFailedLogs(accountId)` with the same tile rendering.
   For tab 6 (Plans), render the `_PlansSection` widget from
   `system_settings_screen.dart` — you may need to extract it or import
   it. If extraction is complex, create a placeholder `Center(child: Text('Plans'))`
   and note it for the next task.
5. Remove the `endDrawer` from the mobile Scaffold — notifications are
   now a tab, not a drawer.
6. Update the FAB logic: the FAB should still appear on tabs that support
   creation actions (Users, Members, Schools, Roles, Plans). On the
   Plans tab, the FAB opens the create plan sheet.
7. The `_selectedTab` state variable and `setState` calls should be
   replaced by the `TabController` listener pattern.
8. Verify on mobile that all 7 tabs work, icons are visible, and the
   active tab indicator is clear.

**Do not** touch files other than `system_dashboard_screen.dart` (and
minimal imports if needed for the notifications/plans tab content).

---

## Task 6 — Add Notifications and Plans Tabs to Desktop Layout [x]

**Context:** The desktop layout's `_DesktopBody` currently has a 4-tab
`TabBar` (Users, Members, Schools, Roles) with the stats chart fixed
above. The project owner wants Notifications and Plans added as tabs
on desktop as well, bringing the desktop to 6 tabs (stats remain as
the fixed top panel — not a tab).

**Goal:** Add Notifications and Plans as the 5th and 6th tabs in the
desktop tab bar.

**Files:**
- `lib/ui/screens/system/system_dashboard_screen.dart`

**Requirements:**

1. Change the desktop `TabController` length from 4 to 6.
2. Add two new `Tab` entries to the desktop tab bar:
   - `Tab(text: 'Notifications')`
   - `Tab(text: 'Plans')`
3. Add corresponding children to the desktop `TabBarView`:
   - Notifications: same content as the mobile notifications tab (a full
     list of failed sync logs). NOT a drawer — inline content.
   - Plans: the `_PlansSection` content (or extracted equivalent).
4. Update the desktop "+" button logic (`AnimatedBuilder` on
   `tabController`): on the Plans tab, the "+" button should open the
   create plan sheet. On the Notifications tab, no "+" button.
5. Remove the `endDrawer` from the desktop Scaffold — notifications are
   now inline.
6. Remove the settings gear icon from wherever it still appears in the
   desktop layout. Settings is accessible from the Plans tab or will be
   addressed separately.
7. The stats panel at the top remains unchanged — it is not a tab.
8. Verify on desktop that all 6 tabs work and the "+" button appears
   only on tabs that support creation.

**Do not** touch files other than `system_dashboard_screen.dart` and
minimal imports.

---

## Task 7 — Redesign Charts Section as Stat Cards with Expandable Bar Charts [x]

**Context:** The current stats section (`lib/ui/screens/system/home/system_stats_section.dart`)
shows a single grouped bar chart with Users, Schools, and Students data.
The project owner wants a card-based layout inspired by a health metrics
dashboard — each data category gets its own card showing a prominent
number value with small inline bar charts. On mobile (limited height),
the charts are hidden by default and only the numbers are shown; the
user can tap to expand and see the charts.

**Design reference:** Think of the health dashboard image: each card has
a title + icon at top-left, "Today >" at top-right, a large number
value, a subtitle, and small inline bars on the right side. We adapt
this pattern for our data.

**Goal:** Replace the single grouped bar chart with 6 individual stat
cards in a responsive grid: Users, Schools, Students, Teachers,
Subscriptions, Revenue. Each card shows the total count prominently
and has small inline vertical bars representing status breakdowns.
On mobile, charts are collapsed by default (numbers only); tapping a
card expands it to reveal the bars.

**Files:**
- `lib/ui/screens/system/home/system_stats_section.dart`
- `lib/models/system_stats.dart` (add new stat models if needed)
- `lib/database/daos/system_stats_dao.dart` (add new watch methods if needed)

**Requirements:**

1. **Add new stat streams** to `SystemStatsDao` if they don't exist:
   - `watchTeacherStats()` → count of teachers (query `teachers` table,
     group by any available status or just total count).
   - `watchSubscriptionStats()` → count of subscriptions grouped by
     status (active, cancelled, etc. from `subscriptions` table).
   - `watchRevenueStats()` → sum of `payments.amount` or similar. If
     the payments table doesn't have enough data for real revenue, use
     subscription count × plan amount as a proxy, or just show the
     total payment count. Use your judgment.
2. **Add corresponding model classes** in `system_stats.dart` for any
   new stat types (e.g. `TeacherStats`, `SubscriptionStats`, `RevenueStats`).
3. **Redesign the stats section UI** with 6 stat cards arranged in a
   responsive grid:
   - 1 column on narrow mobile (< 400px width)
   - 2 columns on standard mobile (400–700px)
   - 3 columns on desktop (> 700px)
4. **Each stat card** should contain:
   - A top row: category icon (small, 14px, muted) + category label
     (fontSize: 11, w400, muted)
   - A large number: `fontSize: 24`, `fontWeight: FontWeight.w300` —
     the total count for that category.
   - A subtitle: e.g. "4 active, 1 suspended" — a brief text summary
     of the breakdown.
   - On the right side (when expanded): small inline vertical bars,
     one per status, coloured by status. Each bar's height is
     proportional to its value relative to the max in that card.
     Bar width: 4px, spacing: 3px, max height: ~40px.
5. **Mobile collapse/expand behaviour:**
   - On mobile (width < `AppTheme.kMobileBreakpoint`), the inline bars
     are hidden by default. Each card shows only the number + subtitle.
   - Tapping a card toggles its expanded state, revealing the bars with
     a smooth `AnimatedCrossFade` or `AnimatedSize`.
   - A small expand indicator (chevron_right that rotates to chevron_down)
     should appear at the top-right of each card on mobile.
6. **On desktop**, all cards are always expanded (bars always visible).
   No expand/collapse interaction needed.
7. **Card styling** must match the account screen container aesthetic:
   - Background: `cs.surfaceContainer`
   - Border: 1px, dark: `cs.outline.withValues(alpha: 0.5)`, light: `cs.outlineVariant`
   - Border radius: `AppTheme.kRadius`
8. **Colour palette** for bars: reuse the existing status colours
   (`_kColorInvited`, `_kColorActive`, `_kColorSuspended`, `_kColorDeleted`,
   `_kColorTrial`, `_kColorCancelled`) and add new colours as needed
   for teacher/subscription/revenue breakdowns.
9. Keep the `_ChartSkeleton` shimmer but adapt it for the card grid
   layout — show 6 placeholder cards with shimmer.
10. Respect `permissions.canSeeDeleted` — hide deleted counts when the
    user is not super.
11. Remove the old `_buildBarChart`, `_buildGroups`, and `_TotalBadge`
    code. Remove the `fl_chart` import if no longer needed.
12. The overall feel should be: airy cards, prominent numbers, subtle
    inline bars, clean and modern.

**Do not** touch any UI files other than `system_stats_section.dart`. DAO
and model files may be modified.

---

## Task 8 — Redesign Create Plan Sheet with Card-Based Layout [x]

**Context:** The create plan sheet (`_CreatePlanSheet` inside
`lib/ui/screens/system/settings/system_settings_screen.dart`) currently
crams all fields (name, description, amount, grade levels, features)
into a single scrollable column. It looks dense and unrefined. The
project owner wants a card-based layout with better visual grouping,
elevation, and spacing.

**Goal:** Redesign the create plan sheet so each logical group of fields
lives inside its own styled card with proper spacing and hierarchy.

**File:** `lib/ui/screens/system/settings/system_settings_screen.dart`

**Requirements:**

1. Group the form into 3 visual cards:
   - **Card 1 — Basic Info:** Name, Description, Amount fields.
   - **Card 2 — Grade Levels:** The level selector (redesigned in Task 9).
   - **Card 3 — Features:** The feature toggles.
2. Each card should use the account screen's `_sectionContainer` pattern:
   - Background: `cs.surfaceContainer`
   - Border: 1px, dark `cs.outline.withValues(alpha: 0.5)`, light `cs.outlineVariant`
   - Border radius: `AppTheme.kRadius`
   - Internal padding: `EdgeInsets.all(16)`
3. Add a section label above each card (same `_buildSectionHeader`
   pattern from the account screen: uppercase, fontSize 10, w500,
   letterSpacing 1.1, muted colour).
4. Space the cards with `SizedBox(height: 20)` between them.
5. The form fields inside each card should have `SizedBox(height: 12)`
   between them.
6. The features card should have each feature row inside a subtle
   inner container with a thin bottom divider (like the account screen's
   row dividers) instead of just raw padding.
7. The error banner at the top stays as-is but should also use the card
   styling (rounded, bordered).
8. The header (sheet handle + title + submit button) stays at the top
   as-is.
9. Verify in both themes. The sheet should feel spacious and organised,
   not crammed.

**Do not** touch any file other than `system_settings_screen.dart`.

---

## Task 9 — Redesign Grade Level Picker with Expandable CBC Level Groups [x]

**Context:** The grade level selector in both the create plan sheet and
the plan edit form currently displays all 16 `GradeLevel` values as a
flat `Wrap` of small chips. This is overwhelming — 16 small chips all
at once. The Kenyan CBC (Competency-Based Curriculum) system has clear
level groupings that should be represented as expandable sections. The
user should be able to select an entire level group or expand it to
pick individual grades.

**Goal:** Replace the flat chip wrap with an expandable tree of CBC level
groups. Each group can be selected entirely (one tap) or expanded to
select individual grades within it.

**File:** `lib/ui/screens/system/settings/system_settings_screen.dart`

**Requirements:**

1. Define the CBC level groups as a data structure:
   - **Pre-Primary:** PP1, PP2
   - **Lower Primary:** Grade 1, Grade 2, Grade 3
   - **Upper Primary:** Grade 4, Grade 5, Grade 6
   - **Junior Secondary:** Grade 7, Grade 8, Grade 9
   - **Senior Secondary:** Grade 10, Grade 11, Grade 12
   - **Legacy 8-4-4:** Form 3, Form 4
2. Create a `_GradeLevelPicker` widget that displays these groups as a
   vertical list of expandable rows.
3. Each group row shows:
   - A checkbox (or custom toggle) on the left that selects/deselects
     ALL grades in the group.
   - The group name (e.g. "Pre-Primary") as the label.
   - A chevron on the right that expands/collapses the group.
   - When some (but not all) grades in the group are selected, the
     checkbox shows an indeterminate/partial state (a dash or filled
     with different opacity).
4. When expanded, the individual grades appear indented below the group
   header, each with their own checkbox and label (e.g. "PP1", "PP2").
5. Tapping the group checkbox toggles all grades in that group.
6. The expand/collapse uses `AnimatedSize` or `AnimatedCrossFade` for
   smooth transitions.
7. Styling: each group header row should have a thin bottom border
   (divider). The expanded grades should have a subtle left indent
   (24px) and slightly lighter background. Use the same border/colour
   patterns as the account screen containers.
8. Replace the existing flat `Wrap` of grade chips in BOTH the create
   plan sheet (`_CreatePlanSheetState.build`) AND the edit form
   (`_PlanEditForm.build`) with this new `_GradeLevelPicker` widget.
9. The widget should accept `Set<GradeLevel> selectedLevels` and a
   callback `void Function(GradeLevel level)` for toggling individual
   levels — same interface as the current implementation, just better UI.
10. Verify that selecting "Pre-Primary" selects both PP1 and PP2, and
    deselecting it deselects both. Expanding and selecting only PP1
    should show the group checkbox as partial.

**Do not** touch any file other than `system_settings_screen.dart`.

---

## Task 10 — Redesign Create Role Sheet to Match Edit Role Screen Quality [x]

**Context:** The create role sheet (`lib/ui/screens/system/roles/create_role_sheet.dart`)
is a bottom sheet (mobile) / dialog (desktop) with a flat, crammed
permission builder. In contrast, the role detail/edit screen
(`lib/ui/screens/system/roles/role_detail_screen.dart`) has a much
more refined layout with a header section, tab bar, expandable resource
rows, and clear visual hierarchy. The project owner wants the create
flow to look and feel like the edit flow — same quality, same patterns.

**Goal:** Redesign the create role sheet to use the same visual patterns
as the role detail screen's permissions tab — card-based resource
groups, expandable rows, proper spacing and hierarchy.

**File:** `lib/ui/screens/system/roles/create_role_sheet.dart`

**Requirements:**

1. Open `role_detail_screen.dart` and study the `_ResourceRow` and
   `_ExpandedPermissions` widgets. These are the target aesthetic.
2. Replace the current `_PermissionGroupSection` and `_ResourceBlock`
   widgets with a layout that mirrors the edit screen:
   - Each resource group (People, Academic, Finance, etc.) gets a
     section header label (uppercase, muted, letterSpacing 1.1).
   - Each resource within a group gets a row similar to `_ResourceRow`:
     a tappable header that expands/collapses, showing the resource
     name and a count of selected permissions (e.g. "3/4 actions").
   - When expanded, the individual action toggles appear below, styled
     as chips similar to the edit screen's `_ExpandedPermissions`.
3. The name and description fields at the top should be inside a card
   container (same styling as Task 8's cards) to visually separate
   them from the permission builder.
4. Add a "Select all" / "Deselect all" toggle at the top of the
   permissions section (keep existing logic, just restyle the button
   to be more prominent — perhaps a small outlined button instead of
   a text link).
5. Each resource row should have:
   - A "Select all" quick toggle on the right of the row header.
   - An expand chevron that rotates when expanded.
   - A brief summary chip showing "X/Y" selected count.
6. The overall sheet should use the same bottom-sheet structure (handle,
   header, divider, scrollable body) but the body content should feel
   spacious and organised.
7. Add expand/collapse state tracking (`Set<String> _expandedResources`)
   similar to the edit screen's pattern.
8. Verify on both mobile (bottom sheet) and desktop (dialog) that the
   layout looks refined and matches the quality of the edit screen.

**Do not** touch any file other than `create_role_sheet.dart`.

---

## Task 11 — Extract Plans Section into Standalone Tab Content Widget [x]

**Context:** Tasks 5 and 6 added a Plans tab to both mobile and desktop
dashboard layouts. If a placeholder was used, this task replaces it with
the real plans UI. If the `_PlansSection` from `system_settings_screen.dart`
was already reused inline, this task extracts it into a proper standalone
file so it can be imported cleanly by the dashboard without pulling in
the entire settings screen.

**Goal:** Create a standalone plans section widget in its own file that
can be used as tab content in the system dashboard.

**Files:**
- Create: `lib/ui/screens/system/plans/plans_section.dart`
- Modify: `lib/ui/screens/system/system_dashboard_screen.dart` (import the new widget)
- Modify: `lib/ui/screens/system/settings/system_settings_screen.dart` (import and reuse, or keep a copy — your judgment on DRY)

**Requirements:**

1. Create the directory `lib/ui/screens/system/plans/` if it doesn't exist.
2. Create `plans_section.dart` containing a `PlansSection` widget that
   renders the full plans management UI: list of plans, create plan
   sheet, plan detail sheet, all the existing functionality from the
   settings screen's `_PlansSection`.
3. The `PlansSection` widget should accept `SystemPermissions permissions`
   as a required parameter.
4. Move or copy the `_CreatePlanSheet`, `_PlanDetailSheet`,
   `_PlanEditForm`, `_PlanRow`, `_PlanStatusChip`, `_PlanViewBody`,
   and all related helper widgets. Also move the `PlanFeature`,
   `kPlanFeatures`, `GradeLevel`, and `gradeLabel` definitions — or
   extract them into a shared file (e.g. `lib/models/plan_features.dart`)
   and import from both places.
5. Update the dashboard's Plans tab to use `PlansSection(permissions: _permissions)`.
6. If the settings screen still needs to show plans, it can import
   `PlansSection` from the new file. Or if Plans is now fully in its
   own tab, remove it from the settings screen and simplify settings
   to only show non-plan settings.
7. All existing functionality (create, view, edit, delete plans) must
   continue to work exactly as before.
8. Run `flutter analyze` and confirm zero issues.

---

## Task 12 — Extract Notifications into Standalone Tab Content Widget [x]

**Context:** Similar to Task 11, the Notifications tab needs a proper
standalone widget. Currently the notification content lives inside
`notifications_panel.dart` as a `Drawer`-shaped widget. For the tab
layout, we need it rendered as plain inline content (no Drawer wrapper).

**Goal:** Create a standalone notifications section widget that renders
the notification list as inline tab content.

**Files:**
- Create: `lib/ui/screens/system/notifications/notifications_section.dart`
- Modify: `lib/ui/screens/system/system_dashboard_screen.dart` (import and use)

**Requirements:**

1. Create `notifications_section.dart` containing a `NotificationsSection`
   widget that renders the notification list inline (not inside a Drawer).
2. Reuse the existing `_NotificationTile`, `_OperationBadge`, and
   `_EmptyState` widgets from `notifications_panel.dart`. Either import
   them (make them public) or copy them into the new file.
3. The `NotificationsSection` should accept the `accountId` as a
   required parameter and use `StreamBuilder<List<AppNotification>>`
   on `logsDao.watchFailedLogs(accountId)`.
4. Add a header inside the section (similar to the Users/Schools section
   headers) with the title "Notifications" and optionally a count badge.
5. Update the dashboard's Notifications tab on both mobile and desktop
   to use `NotificationsSection(accountId: ...)`.
6. Remove the `endDrawer` and Drawer-based notification panel from the
   dashboard Scaffold if it hasn't been removed already.
7. Keep `notifications_panel.dart` intact — it may be used elsewhere.
8. Verify the notification list displays correctly as inline content.

---

## Task 13 — Final Polish Pass on Dashboard Layout and Spacing [x]

**Context:** After Tasks 4–12, the dashboard has undergone significant
structural changes. This task is a final polish pass to ensure everything
feels cohesive, aligned, and refined.

**Files:**
- `lib/ui/screens/system/system_dashboard_screen.dart`
- Any section files that need minor spacing/border adjustments.

**Requirements:**

1. Verify the back-button row on both mobile and desktop feels
   appropriately weighted — not too prominent, not invisible.
2. Verify the mobile icon tab bar has proper spacing between icons
   and the active indicator is clearly visible in both themes.
3. Verify the desktop text tab bar accommodates 6 tabs without
   horizontal overflow on reasonable screen widths (1024px+).
4. Verify the FAB appears on the correct tabs and the expand/collapse
   animation still works smoothly.
5. Verify the transition animations (fade + slide) still work correctly
   with the new layout structure.
6. Check that there are no orphaned imports, dead code, or unused
   variables left from the refactoring.
7. Run `flutter analyze` and confirm zero issues.
8. Do a visual review of every tab on both mobile and desktop in both
   light and dark themes. Fix any spacing inconsistencies, border
   mismatches, or colour irregularities.

---

## Execution Order

Work through the tasks sequentially: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
11, 12, 13.

**Dependency notes:**
- Tasks 1 → 2 → 3 are a chain (home screen top bar → cards → states).
- Task 4 is independent (dashboard app bar removal) but must precede
  Tasks 5 and 6.
- Tasks 5 → 6 are a chain (mobile tabs → desktop tabs).
- Task 7 is independent (chart redesign) but best done after Tasks 4–6
  since the layout context will have changed.
- Tasks 8 → 9 are a chain (plan sheet cards → grade picker).
- Task 10 is independent (role creation redesign).
- Tasks 11 → 12 depend on Tasks 5–6 (tabs must exist before extracting
  content into standalone widgets).
- Task 13 depends on all previous tasks being complete.

---

## Remaining Items from Previous Revisions

### Blocked Items (Carried Forward)

| # | Item | Blocked by |
|---|---|---|
| P3 | Sync stream proto definitions | Project owner — deferred to Task Group 2 |
| P5 | Failed log retry logic | Server error taxonomy — deferred |
| P7 | Permission key taxonomy alignment | Project owner — needed before dashboard feature gating |
| P10 | School settings JSON schema | Project owner |

### Completed Task Groups (Previous Revisions)

- Task Groups A–J (Revision 3) — UI/UX refinement — all complete.
- Task Groups 1–4A (data layer, system dashboard functionality) — all complete.
- Tasks 1–15 (Revision 4) — charts, members, status indicators, user detail, school owner, M-Pesa, role assignment, dot indicators — all complete.