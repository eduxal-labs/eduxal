# ui/widgets/ — Shared Widgets Context

> Reusable UI components used across multiple screens throughout the app.
> Screen-specific widgets that are only used by one screen live in that screen's directory, not here.

## Overview

This directory contains **34 files** and **1 subdirectory** (`member_creation/`). These are the shared building blocks that enforce visual consistency across the app — tab bars, term selectors, avatars, save buttons, action buttons, status indicators, sync indicators, progress bars, trajectory indicators, stat badges, member creation flows, today-status cards, quick-stat rows, countdown chips, pressable row mixins, section headers, stream builders, permission-denied helpers, tiptap/math renderers, stimulus blocks, and the codified design system widgets (sheets, dialogs, form fields, section cards, detail headers, empty states, confirmation dialogs, filter toolbars, search fields).

## Files

| File | Key Exports | Status | Description |
|---|---|---|---|
| `edu_data_table.dart` | `EduDataTable<T>`, `EduDataTableAction<T>` | ✅ Complete | Reusable data-table-style list widget. Renders items as rows separated by 0.5 px dividers with hover highlights. On desktop (≥600px), per-row action buttons appear inline as 28×28 icon buttons that fade in on row hover. On mobile (<600px), a single `Icons.more_vert` (18px) button opens a modal bottom sheet with action rows. Supports an optional header row, empty state (icon + title + subtitle), row tap navigation, and `AnimatedContainer`-based hover background (100ms). All styling uses `AppTheme` design tokens (kModalRadius, kCardRadius, tableRowDivider, modalBg). Destructive actions render in `cs.error`. |
| `animated_action_button.dart` | `AnimatedActionButton` | ✅ Complete | Compact icon button with animated feedback for mutation actions. Cycles through three internal states: **idle** → **busy** (14×14 spinner) → **done** (check flash with `Curves.elasticOut` scale) → **idle**. Default size 32×32, `BorderRadius.circular(6)`. Accepts `icon`, `onTap` (`Future<void> Function()`), optional `tooltip`, `color`, `backgroundColor`, `size`, `iconSize`, `showCheckOnSuccess`. Errors revert to idle silently. Set `showCheckOnSuccess: false` for destructive actions where the item disappears immediately. Applied to: trash/purge/status-change buttons in `_SchoolRowState`, edit/delete buttons in `_RoleRowState`, delete AppBar button in `_RoleDetailScreenState`, unassign button in `_AssignedRow`, and remove buttons in `_DeptAllItem` / `_DeptMemberRow`. |
| `active_term_provider.dart` | `ActiveTermProvider` | ✅ Complete | `InheritedNotifier` that provides `ActiveTermContext` to the widget tree. Screens access via `ActiveTermProvider.of(context)`. |
| `thin_progress_bar.dart` | `ThinProgressBar` | ✅ Complete | A thin, color-coded horizontal progress bar for percentage visualization (exam scores, mastery levels, attendance rates). Height defaults to 6px. Auto-colors via `percentageColor()` from `academic_utils.dart` or accepts an override. Animates width changes with a 300ms ease-out `TweenAnimationBuilder`. Accepts `percent`, `height`, `color`, `backgroundColor`, `borderRadius`, `width`. |
| `trajectory_indicator.dart` | `TrajectoryIndicator` | ✅ Complete | Compact trajectory indicator showing direction + label in the trajectory's color. Supports `compact` mode (icon only, 16px default) and full mode (icon + 4px gap + label text, 12px default). Maps `Trajectory` enum values: improving → green trending_up, declining → red trending_down, stable → amber trending_flat, insufficientData → grey help_outline. |
| `stat_badge.dart` | `StatBadge` | ✅ Complete | Compact stat badge showing a label + value in a tinted container. Used for summary stat rows (comparisons, student overview, etc.). Accepts `label`, `value`, optional `tintColor` (8% alpha background) and `icon` (inline with label). Min width 80, `BorderRadius.circular(8)`, label 11px w400 muted, value 16px w500. |
| `animated_save_button.dart` | `AnimatedSaveButton` | ✅ Complete | A button that animates between idle → saving → saved states. Used for row-level or form-level saves in data entry screens (grades, attendance, etc.). |
| `create_term_modal.dart` | `CreateTermModal` | ✅ Complete | Modal dialog/sheet for creating a new academic term. Fields: year, term number, start date, end date. Writes to `terms` table via `TermsDao`. |
| `edu_tab_bar.dart` | `EduTabBar`, `EduTab` | ✅ Complete | The **single source of truth** for all tab aesthetics in the app. Elevated, shadow-based indicator (not a thin underline). Slightly tinted background container with subtle elevation. Supports both icon-only and text-label modes. `BorderRadius.circular(8)` or `10`, slim text (`w400` unselected / `w500` selected). Every tabbed surface in the app uses this — no raw `TabBar` anywhere. |
| `no_terms_blank_state.dart` | `NoTermsBlankState` | ✅ Complete | Displayed when a school has no terms configured (`ActiveTermContext.hasTerms == false`). Role-aware messaging: admin users (owner or `canCreateTerm`) see "No terms yet" + "Create a term to get started with academics." with a prominent CTA button; non-admin users (student, guardian, teacher/staff without permission) see "No active term" + "Your school hasn't set up a term yet. Please check back later." with informational pills instead of a CTA. Headline uses `FontWeight.w500` (per UI guidelines §21). |
| `status_indicator.dart` | `StatusIndicator` | ✅ Complete | A compact status badge/chip widget. Takes a label string and a color, renders as a small elevated chip with the status text. Used for member status badges, invoice status, school status, etc. |
| `term_selector_chip.dart` | `TermSelectorChip` | ✅ Complete | Compact chip widget shown in the school dashboard AppBar. Displays `ActiveTermContext.currentTermLabel` (e.g. "2025 · Term 2"). On tap, opens a picker showing all available terms. Calls `ActiveTermContext.setTerm(term)` on selection. |
| `sync_indicator.dart` | `SyncIndicator` | ✅ Complete | Tiny (7 px) sync status dot. Binds to `sync.status` (`ValueNotifier<SyncStatus>` from `SyncEngine`). Colors: disconnected → muted red, idle → subtle green, pushing/pulling → pulsing blue. Uses `SingleTickerProviderStateMixin` for pulse animation (900 ms, ease-in-out, opacity 0.35→1.0). Tooltip shows "Offline" / "Connected" / "Syncing…". 20×20 touch target, `BorderRadius.circular(1.5)` (slightly blunted square, not circular). Placed in home screen top bar and all three school dashboard layouts (full sidebar footer, icon rail footer, mobile top bar). |
| `user_avatar.dart` | `UserAvatar` | ✅ Complete | Circular avatar widget that loads a user's profile image from `FileCache.profilePath(userId)`. Falls back to initials (first letter of name) on a colored background if no cached image exists. Accepts a `radius` parameter for sizing. |
| `inline_calendar.dart` | `InlineCalendar` | ✅ Complete | Compact, embeddable inline date picker. Renders as a trigger row (icon + date text + chevron) that expands/collapses a calendar grid via `SizeTransition`. Month/year header with `<` `>` nav arrows, Su–Sa day-of-week labels, tight 32×32 day cells with accent fill on selected, border on today, faded outside/disabled days. Auto-collapses after selection. Accepts `value`, `firstDate`, `lastDate`, `onChanged`, optional `hint` and `icon`. Uses `AppTheme.brandIndigo` / `brandIndigoDark` for accent. Replaces `showDatePicker` dialog usage in member creation forms. |

| `edu_sheet.dart` | `EduSheet`, `showEduSheet()` | ✅ Complete | Standard bottom sheet wrapper + adaptive launcher (desktop dialog / mobile sheet). `EduSheet` widget renders modalBg background, drag handle (36×4px pill), optional title row with close button. `showEduSheet` detects screen width: ≥600px → dialog with border/shadow/constrained width (no title row — sheets render their own headers); <600px → modal bottom sheet returning `builder(ctx)` directly (no `EduSheet` wrapper — sheets render their own chrome). The `title` parameter on `showEduSheet` is deprecated and no longer rendered. `_DialogTitleRow` widget is retained but currently unused. |
| `edu_dialog.dart` | `EduDialog` | ✅ Complete | Standard dialog wrapper. Renders: transparent `Dialog` with `ConstrainedBox(maxWidth)`, `Container` with `modalBg`, `kModalRadius` (12), 1px `borderColor` border, `modalShadow`. Optional title row with close button and thin divider separator. |
| `edu_form_field.dart` | `EduFormField` | ✅ Complete | Standard form text field. Uppercase label (9.5px, w600, letterSpacing 0.9, onSurfaceVariant @0.55) above a filled `TextFormField` (dark: 0xFF1E2A3A, light: surfaceContainerLowest, kCardRadius). Optional error banner below (red-tinted container with icon + message). Supports hint, prefixText, suffix, maxLines, obscureText, onChanged, enabled. |
| `edu_section_card.dart` | `EduSectionCard` | ✅ Complete | Bordered section container. surfaceContainer fill, kCardRadius, 0.5px border. Optional uppercase header with trailing widget. Thin dividers interleaved between children. |
| `edu_detail_header.dart` | `EduDetailHeader`, `EduDetailChip` | ✅ Complete | Detail page header with avatar, title, subtitle, metadata chips, trailing actions. `EduDetailChip`: small chip with icon + label, surfaceContainerHighest @0.4, kChipRadius, 0.5px border. |
| `edu_empty_state.dart` | `EduEmptyState` | ✅ Complete | Centered empty state. 32px icon in 52×52 tinted circle (primary @0.08), title 13.5px w500, subtitle 12px w400, optional CTA action widget. |
| `marking_status_indicator.dart` | `MarkingStatusIndicator` | ✅ Complete | Compact widget that polls the server for AI marking job status and renders phase-appropriate feedback. Max height 36px, horizontal layout. Uses `questionBankService.watchMarkingStatus(...)` polling stream (3s interval). **Phases:** Queued → pulsing amber dot (8px, `ScaleTransition` 0.8–1.2, 800ms ease-in-out) + "Queued for marking..." label. Downloading/Computing → indeterminate `LinearProgressIndicator` (2px, indigo `#6366F1`) + `displayLabel` text. Marking → determinate `LinearProgressIndicator` with percentage text (indigo). Complete → green check icon (16px, `#43A047`) + "Marking complete" label; auto-hides after 3s via `Future.delayed`. Failed → error icon + error message (ellipsis) + "Retry" tap text (calls `onRetry`, resubscribes). Constructor params: `school`, `exam`, `subject`, `paper?`, `grade`, `stream?`, `onComplete` callback, `onRetry` callback. Uses `SingleTickerProviderStateMixin` for pulse animation. On gRPC error in stream listener, yields synthetic failed status. Dependencies: `client.dart` (`questionBankService`, `accessToken`), `models/marking_status.dart` (`MarkingStatus`, `MarkingPhase`). |
| `edu_confirm_dialog.dart` | `EduConfirmDialog`, `showEduConfirmDialog()` | ✅ Complete | Standard confirmation dialog with title, optional message, confirm/cancel buttons. `isDestructive` flag colors confirm in `cs.error`. `showEduConfirmDialog` convenience returns `Future<bool>`. |
| `edu_filter_toolbar.dart` | `EduFilterToolbar`, `EduFilterChipData` | ✅ Complete | Search + filter toolbar for data tables. Row with search icon toggle, animated `EduSearchField`, filter icon toggle. Below: collapsible `AnimatedCrossFade` filter chip rows. |
| `edu_search_field.dart` | `EduSearchField` | ✅ Complete | Animated inline search field. 32px height, kCardRadius, surfaceContainerHighest fill, 13px text, search icon prefix, clear button suffix via `ValueListenableBuilder`. Animated width transition. |
| `looping_tab_strip.dart` | `LoopingTabStrip`, `LoopingTabItem` | ✅ Complete | Infinite-looping, snapping, labelled tab strip for mobile navigation. Renders icon (18px) + label (10.5px w400) stacked vertically. Edge-to-edge with no horizontal margins. Uses a `ScrollController` + `ListView.builder` with `_kMultiplier = 500` virtual copies on each side for seamless looping. Tab width = `screenWidth / min(tabCount, 4)`. Snaps to nearest tab on `ScrollEndNotification` with 200ms ease-out animation. Selected tab shows `cs.surface` background + subtle dual box-shadow inside `AnimatedContainer` (150ms). Programmatic selection via `didUpdateWidget` uses `_nearestVirtualIndex` to animate to the closest virtual copy instead of jumping across the full multiplier distance. Replaces `_PillTabStrip` in the mobile layout of `school_dashboard_screen.dart`. Does NOT use `TabBar` or `TabController` internally — parent wires `selectedIndex` and `onTabSelected` callback. |
| `today_status_card.dart` | `TodayStatusType`, `TodayStatusCard` | ✅ Complete | Prominent today-status indicator card. `TodayStatusType` enum: `positive` (green), `negative` (red), `neutral` (grey), `warning` (amber). Layout: `Row(icon 28px, Expanded(Column(title w500 14px, subtitle w300 12px)), trailing)`. Colored container with `kCardRadius` (8). Light/dark color mapping via static `_bgColor`/`_fgColor` helpers. `InkWell` wrapping when `onTap` provided. Height 64–72px, padding 12px horizontal / 10px vertical. Used by Guardian (attendance), Teacher (marking status), Owner (school-wide attendance), Student (schedule status). |
| `quick_stat_row.dart` | `QuickStat`, `QuickStatRow` | ✅ Complete | Compact stat mini-card row. `QuickStat` data class: label, value, optional icon/trend/suffix/onTap. `QuickStatRow` uses `LayoutBuilder`: ≥600px → `Wrap`, <600px → horizontal `ListView`. Each `_StatCard`: 80–100px wide, 64px tall, `kChipRadius` corners, `surfaceContainerHighest` bg. Value w500 16px, label w300 11px. Optional `_TrendArrow` (10px green trending_up / red trending_down). Press-scale 0.97 animation when tappable. Replaces duplicated `_StatCard` widgets across overview screens. |
| `countdown_chip.dart` | `CountdownChip` | ✅ Complete | Self-updating countdown chip with `Timer`. Ticks every 60s (or 1s when <60s remaining). Formats: "2h 15m", "45 min", "12s", "Now!". `kChipRadius`, `cs.primaryContainer` bg / `cs.onPrimaryContainer` text. Urgency: switches to `cs.errorContainer` when ≤5 min remain. `FadeTransition` entrance 200ms. Fires `onReached` callback at zero, shows `reachedLabel` (or "Now!"). `compact` mode: icon + time only. Re-schedules timer on `didUpdateWidget`. Used by Teacher (next class), Student (next class), Owner (term countdown). |
| `pressable_row.dart` | `PressableRowMixin` | ✅ Complete | Mixin adding press-scale animation (0.95→1.0, 100ms) to any `StatefulWidget`. Requires `TickerProviderStateMixin`. Provides `buildPressable({child, onTap, onLongPress})` which wraps child in `ScaleTransition` + `GestureDetector`. Manages its own `AnimationController`. Replaces identical animation boilerplate duplicated in 12+ widget states (`_GradeCardState`, `_UserDataRowState`, `_SchoolRowState`, etc.). Migration of existing widgets is done separately in Task G3. |
| `section_header.dart` | `SectionHeader` | ✅ Complete | Reusable section title with optional trailing action. `Row`: optional leading `icon` (18px, `onSurfaceVariant`) + 6px gap + title (`13px, w500, onSurfaceVariant`) + `Spacer` + optional `trailing` widget. Configurable `padding` (default: `EdgeInsets.symmetric(horizontal: 16, vertical: 8)`). Replaces duplicated `_SectionTitle` in `overview_screen.dart`, `finance_screen.dart`, `members_page.dart`, etc. |
| `edu_stream_builder.dart` | `EduStreamBuilder<T>` | ✅ Complete | Convenience wrapper around `StreamBuilder<T>` with consistent error-handling and loading states. Constructor params: `stream` (`Stream<T>`), `builder` (`Widget Function(BuildContext, T)`), optional `loading` (custom loading widget), optional `errorBuilder` (`Widget Function(Object, StackTrace?)`). Default loading: centered `CircularProgressIndicator(strokeWidth: 1.5)`. Default error: `_DefaultErrorWidget` — compact error card with tinted icon circle (error @0.10, 36×36), "Something went wrong" title (13px w500), error message (11.5px w400, max 3 lines). Card uses `kCardRadius`, `nestedBg` in dark mode / `errorContainer @0.08` in light mode, 0.5px error-tinted border. Max width 360px. New `StreamBuilder`s across the app should prefer this widget over raw `StreamBuilder`. |
| `permission_denied_handler.dart` | `showPermissionDenied()`, `guardedAction()` | ✅ Complete | Standardized `PermissionException` UI handling pattern. `showPermissionDenied(context, reason)` shows a floating red snackbar (`AppTheme.kPermissionDeniedColor`, 4s) with a lock icon and the denial reason text. `guardedAction(context, action)` wraps any `Future<void>` mutation and automatically calls `showPermissionDenied` on `PermissionException`. Use `guardedAction()` for simple DAO mutations; catch `PermissionException` manually when the method returns `Result<T, E>`. |
| `tiptap_renderer.dart` | `TiptapRenderer`, `renderBody()` | ✅ Complete | Read-only renderer for TipTap/ProseMirror JSON documents. `TiptapRenderer` is a `StatelessWidget` that accepts a `document` (`Map<String, dynamic>`) and optional `baseStyle` (`TextStyle?`). Renders: `doc`, `paragraph`, `orderedList`, `bulletList`, `mathBlock` (via `flutter_math_fork` `Math.tex`, display style), `table`. Inline nodes: `text` (with `bold`/`italic`/`code` marks), `hardBreak`, `mathInline` (via `Math.tex`, inline `WidgetSpan`). `renderBody(body, bodyFormat, {style})` is a top-level convenience helper — returns a `TiptapRenderer` when `bodyFormat == 'tiptap'`, otherwise a plain `Text` widget. Dependency: `flutter_math_fork ^0.7.4`. |
| `stimulus_block.dart` | `StimulusBlock` | ✅ Complete | Renders a question stimulus (passage, table, graph, diagram) in a visually distinct container. Accepts a `stimulus` map with keys: `type` (`'passage'`\|`'table'`\|`'graph'`\|`'diagram'`), `body` (String), `body_format` (`'plain'`\|`'tiptap'`), `caption` (String?). Routes to three private sub-widgets: `_PassageBlock` (left-border accent container with `surfaceContainerHighest @0.35` bg, 3px primary left border, `BorderRadius.only(topRight/bottomRight: 4)`, optional uppercased caption label), `_TableBlock` (plain column with optional caption above), `_ImageBlock` (graph/diagram — body as descriptive text with optional caption below). All body content rendered via `renderBody()` from `tiptap_renderer.dart`. |
| `answer_space.dart` | `AnswerSpaceWidget` | ✅ Complete | Renders the blank answer space for one question or part on a read-only paper preview. Accepts `answerSpaceType` (`'lines'`\|`'plain_box'`\|`'diagram_box'`\|`'construction_box'`\|`'grid_box'`), `answerLines` (default 4), `answerBoxHeightMm` (default 80). `'lines'` renders N ruled dividers (0.5px, `Color(0xFFBBBBBB)`, 16px spacing). Box types render a bordered `Container` at `answerBoxHeightMm × 3.78 px/mm` height with an optional italic watermark label. `'grid_box'` uses `CustomPaint` (`_GridPainter`) to draw 28px graph-paper cells inside the same bordered container. Not used for live exam taking — preview/print layout only. |

## Subdirectory: `member_creation/`

Phone-first (and name-first for students) member creation panels used by the Members page in the school dashboard.

> **Styling overhaul (Task 06):** All member creation forms have been thoroughly cleaned up to remove glassy/neumorphic patterns and align with the app's clean, minimal aesthetic (AGENT.md §21). Key changes:
>
> - **Text inputs** (`_PhoneField`, `_NameField`, all `_StyledInput` widgets): Now use `Container` with `surfaceContainerLow` fill (light) / `Color(0xFF1E2A3A)` (dark) + thin `Border.all(outlineVariant)` + `InputBorder.none` internally. No `Material` elevation, no `BoxShadow`, no double-border artifacts.
> - **Date pickers** — replaced entirely. The old `_DatePickerTile` + `showDatePicker` dialog approach is gone from both student and teacher panels. Both now use the shared `InlineCalendar` widget (`lib/ui/widgets/inline_calendar.dart`) — a compact, dashboard-style inline calendar that expands/collapses within the form. No popup dialog at all.
> - **Photo picker** (`_PhotoPicker` in student panel): Removed glassy `BoxShadow`. Now uses `Container` with thin border (accent-tinted when image is selected, `outlineVariant` when empty). Slightly smaller (68×68). Camera icon uses `onSurfaceVariant` instead of accent tint.
> - **Gender chips** (`_GenderChip` in student panel): Replaced `BoxShadow` with thin `Border.all`. Selected state uses accent-tinted border instead of accent shadow. Tightened radius from 10 to 8.
> - **Found user card** (`_FoundUserCard` in phone_first_panel): Replaced `BoxShadow` with thin accent-tinted border. Tightened radius from 10 to 8. Avatar radius from 8 to 6.
> - **CTA buttons** (`_CtaButton` in student + phone_first panels): Removed heavy accent `BoxShadow`. Tightened radius from 10 to 8.
> - **All `borderRadius` values** standardised to `8` across inputs, chips, tiles, and buttons (was a mix of 10/8 before).
> - Non-input selection widgets (`_SelectableChip`, `_RoleRow` in guardian panel) were intentionally left unchanged.

| File | Key Exports | Status | Description |
|---|---|---|---|
| `add_guardian_panel.dart` | `AddGuardianPanel` | ✅ Complete | Phone-first guardian creation flow. Linked to a specific student (ward). Fields: phone → user lookup → relationship, role. Uses `MemberCreationService.createGuardian()`. |
| `add_owner_panel.dart` | `AddOwnerPanel` | ✅ Complete | Phone-first owner creation flow. Fields: phone → user lookup → confirm link. Uses `MemberCreationService.createOwner()`. |
| `add_staff_panel.dart` | `AddStaffPanel` | ✅ Complete | Phone-first staff creation flow. Fields: phone → user lookup → ID number, role, department. Uses `MemberCreationService.createStaff()`. |
| `add_student_panel.dart` | `AddStudentPanel` | ✅ Complete | Name-first student creation flow (students don't need a phone number). Fields: name, **admission number (optional)**, DOB, gender, photo, admission date, phone (optional). Uses `MemberCreationService.createStudent()`. **UI polish (Task 09):** Replaced full-width `_CtaButton` with a compact right-aligned `FilledButton.icon` (check icon + label, `BorderRadius.circular(6)`). Added form entrance animation (`TweenAnimationBuilder` fade+slide, 350ms ease-out). Reduced inter-field spacing from 20px to 14–16px for a tighter, more compact layout. Removed the now-unused `_CtaButton` private widget class entirely. **Task 02:** Added optional ADM number field (digits only, `EduFormField`, hint "Leave blank to auto-assign"). Updated subtitle text to mention optional ADM. Passes parsed `int?` to `createStudent(adm:)`. |
| `add_teacher_panel.dart` | `AddTeacherPanel` | ✅ Complete | Phone-first teacher creation flow. Fields: phone → user lookup → hired date, role, department. Uses `MemberCreationService.createTeacher()`. |
| `phone_first_panel.dart` | `PhoneFirstPanel` | ✅ Complete | Shared base component for the phone-first lookup pattern. Renders a phone number input field, calls `MemberCreationService.lookupPhone()`, then expands to show either "User found — link?" confirmation or "User not found — enter name" expansion. Used by `AddOwnerPanel`, `AddTeacherPanel`, `AddStaffPanel`, `AddGuardianPanel`. |

### Phone-First Flow (shared pattern)

1. User enters phone number in `PhoneFirstPanel`.
2. `MemberCreationService.lookupPhone(phone)` is called → returns `UserFound` or `UserNotFound`.
3. **If `UserFound`:** Shows user's name and a "Link to school" confirmation button. On confirm, calls the appropriate `create*()` method with the existing user.
4. **If `UserNotFound`:** Expands the form to request name (+ role-specific fields). On submit, creates a new `users` row with `status = invited` and links the membership.
5. All creation methods write both the entity row and corresponding `logs` entries in a single transaction.

### Student Flow (name-first)

Students use `AddStudentPanel` which does NOT use `PhoneFirstPanel`. Instead:
1. User enters name, optionally an admission number (leave blank to auto-assign), DOB, gender, photo, admission date, and optionally a phone number.
2. On submit, calls `MemberCreationService.createStudent(adm: parsedAdm)` which validates ADM uniqueness (if provided) or auto-assigns via `nextAdmissionNumber()`.
3. Students may optionally be linked to a `users` row later (when the student gets a phone/account).

## Key Widget Details

### `EduTabBar` — Design Specification

This is the most important shared widget for visual consistency. Key properties:
- **Indicator:** Elevated container with subtle shadow, matching the tab's background but slightly shifted — NOT a thin underline indicator.
- **Background:** Slightly tinted container that distinguishes the tab row from surrounding content.
- **Typography:** `w400` for unselected tabs, `w500` for selected. Thin and clean.
- **Border radius:** `8`–`10` on the indicator and container. No pill shapes.
- **Modes:** Accepts both icon-only tabs (for mobile nav) and text-label tabs (for inner page sections).
- **Usage:** Used by `MembersPage` (5 tabs), `SchoolRoleDetailScreen` (2 tabs), `RoleDetailScreen` (2 tabs), and any future tabbed surface.

### `ActiveTermProvider` — Usage Pattern

```dart
// Providing (in SchoolDashboardScreen):
ActiveTermProvider(
  context: activeTermContext,
  child: ...
)

// Consuming (in any child screen):
final termCtx = ActiveTermProvider.of(context);
return ValueListenableBuilder<Term?>(
  valueListenable: termCtx.termNotifier,
  builder: (context, term, _) {
    if (term == null) return const NoTermsBlankState();
    return _MyTermSensitiveWidget(term: term);
  },
);
```

### `UserAvatar` — Usage Pattern

```dart
UserAvatar(
  userId: user.id,
  name: user.name,
  radius: 20,  // defaults to 20
)
```

Internally calls `FileCache.get(FileCache.profilePath(userId))` to check for a cached image file. Shows initials on a deterministic color (derived from userId hash) if no file exists.

## Dependencies

- **Depends on:** `models/active_term_context.dart` (ActiveTermProvider), `models/school_context.dart` (member panels read school context), `services/members.dart` (`MemberCreationService`, `PhoneLookupResult`), `database/daos/terms_dao.dart` (CreateTermModal), `database/database.dart` (for generated types like `Term`), `database/tables/enums.dart` (status enums), `cache/file_cache.dart` (UserAvatar), `core/extensions.dart` (`toKenyanPhone()` in phone panels), `client.dart` (global DAOs, services, `sync` getter), `sync/sync_status.dart` (`SyncStatus` enum)
- **Depended on by:** `ui/screens/school_dashboard/` (all screens use these widgets), `ui/screens/system/` (roles screens use `EduTabBar`)

## Conventions

- Shared widgets are stateless when possible, stateful only when they manage their own animation controllers, form state, or subscriptions.
- Widget files are named descriptively in snake_case: `edu_tab_bar.dart`, `user_avatar.dart`, `animated_save_button.dart`.
- All member creation panels follow the same visual pattern — slide-over panels on desktop, full-screen dialogs on mobile.
- `EduTabBar` is the **only** tab widget used in the app. No screen should create a raw `TabBar`.
- Widgets never import services or DAOs directly for business logic — they receive callbacks or data via constructor parameters. Exception: `CreateTermModal` and member creation panels which instantiate service calls directly (they are self-contained mini-flows, not pure presentational widgets).

## Last Updated
Task A3 — Added `answer_space.dart` (`AnswerSpaceWidget`) — blank answer space renderer for read-only paper previews; supports lines, plain/diagram/construction boxes, and graph-paper grid. File count: 35 files + 1 subdirectory (`member_creation/`).

Previous: Task A2 — Added `stimulus_block.dart` (`StimulusBlock`) — stimulus container widget with passage/table/image sub-types, using `renderBody()` from `tiptap_renderer.dart`. File count: 34 files + 1 subdirectory (`member_creation/`).

Previous: Task A1 — Added `tiptap_renderer.dart` (`TiptapRenderer`, `renderBody`) — read-only TipTap/ProseMirror JSON renderer with inline and block math via `flutter_math_fork`. Also added `flutter_math_fork: ^0.7.4` and `flutter_svg: ^2.0.10+1` to `pubspec.yaml`. File count: 33 files + 1 subdirectory (`member_creation/`).

Previous: Task AUTH-C01 — Added `permission_denied_handler.dart` (`showPermissionDenied`, `guardedAction`) — standardized PermissionException snackbar helper. File count: 32 files + 1 subdirectory (`member_creation/`).
