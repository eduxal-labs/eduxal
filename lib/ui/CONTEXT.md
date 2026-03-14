# ui/ — UI Layer Context

> Flutter UI layer. No business logic permitted here — only stream/future consumption and presentation.
> Screens bind to `Stream<T>` and `Future<Result<T, E>>` from the services layer and DAOs.

## Overview

The UI layer contains **3 subdirectories** (screens, widgets, theme) and consumes reactive Drift streams + service results for all data display. State management is done via Drift reactive streams exposed as `Stream<T>`, `ValueNotifier<T>`, and `ChangeNotifier` — no external state management package.

## Directory Structure

```
ui/
├── CONTEXT.md              # This file
├── screens/
│   ├── CONTEXT.md          # Screen inventory with routes and dependencies
│   ├── account/            # User account/profile management
│   ├── auth/               # Login, OTP verification, setup
│   ├── home/               # Home screen — membership picker
│   ├── school_dashboard/   # School-scoped dashboard (the main app surface)
│   ├── splash/             # Splash/loading screen
│   └── system/             # System admin dashboard (super_/system users)
├── widgets/
│   ├── CONTEXT.md          # Shared widget inventory
│   ├── member_creation/    # Phone-first member creation panels
│   └── (shared widgets)    # Reusable components used across screens
└── theme/
    └── app_theme.dart      # Light/dark theme definitions
```

## Theme — `theme/app_theme.dart`

- **Status:** ✅ Complete
- **Exports:** `AppTheme` class with static methods:
  - `AppTheme.light()` → `ThemeData` — light theme.
  - `AppTheme.dark()` → `ThemeData` — dark theme.
  - `AppTheme.resolveThemeMode(AppThemeMode mode)` → `ThemeMode` — maps `AppThemeMode` enum to Flutter's `ThemeMode`.
- **Used by:** `main.dart` in the `MaterialApp` widget.

## Key UI Patterns

### Data Binding
- Screens use `StreamBuilder<T>` to bind to DAO watch methods (e.g. `watchMemberships(userId)`).
- Fallible operations use `Future<Result<T, E>>` → consumed via `switch` on `Ok`/`Err`.
- Entry-sensitive data uses `ValueListenableBuilder<MembershipEntry>` on `SchoolContext.currentEntry`.
- Term-sensitive data uses `ValueListenableBuilder<Term?>` on `ActiveTermContext.termNotifier`.

### Navigation
- `SplashScreen` → checks `client.active()` → routes to `HomeScreen` or `LoginScreen`.
- `HomeScreen` → displays `SchoolMembership` cards → tapping enters `SchoolDashboardScreen`.
- `SchoolDashboardScreen` → responsive layout (sidebar on desktop, top tabs on mobile) → hosts all school-scoped pages.
- System dashboard is a separate route for `UserLevel.system` / `UserLevel.super_` users.

### Responsive Layout
- `LayoutBuilder` is used for responsive breakpoints in `SchoolDashboardScreen`:
  - **Desktop:** Fixed left navigation sidebar + content area.
  - **Mobile:** Scrollable top tabs for section navigation.
- Breakpoint logic avoids duplication between mobile/desktop where possible.

### School Dashboard Structure
The school dashboard uses `SchoolContext` (provided via `InheritedWidget` or similar) to scope all data:
- `SchoolContext.membership` — all entries for this school.
- `SchoolContext.permissions` — aggregated `SchoolPermissions` (constant for session).
- `SchoolContext.currentEntry` — `ValueNotifier<MembershipEntry>` for the active role.

Navigation items vary by role (determined by `currentEntry.role`):
- **Owner:** Overview | Academics | Members | Finance | Timetable | Roles
- **Teacher:** Overview | Academics | Exams & Grades | Attendance | Timetable
- **Staff:** Overview | Members | Finance | Attendance | Announcements
- **Student:** Overview | Timetable | Grades | Attendance
- **Guardian:** Overview | Attendance | Grades | Finance (read-only)

`ActiveTermContext` scopes all academic data to the selected year/term.

## Dependencies

- **Depends on:** `models/` (domain models, `SchoolContext`, `ActiveTermContext`, `Result`, `MembershipEntry`, etc.), `services/` (`Authentication`, `MemberCreationService`, `MemberManagementService`), `database/daos/` (global DAO singletons from `client.dart` for reactive streams), `core/` (constants, `grpc_errors.dart` for `toFriendlyMessage()`), `cache/file_cache.dart` (serving cached images), `client.dart` (global `client`, `cache`, DAO singletons).
- **Depended on by:** `main.dart` (imports `SplashScreen`, `AppTheme`).

## UI Design Guidelines

All design tokens are codified in `AppTheme` (`lib/ui/theme/app_theme.dart`) and documented in AGENT.md §21. Use the constants directly — do not hardcode values.

### Key Tokens

| Token / Helper | Value | Use |
|---|---|---|
| `AppTheme.kModalRadius` | `12.0` | Modal/dialog containers, bottom sheets |
| `AppTheme.kCardRadius` | `8.0` | Cards, inputs, buttons |
| `AppTheme.kChipRadius` | `4.0` | Chips, badges, small tags |
| `AppTheme.modalShadow(isDark)` | dual box-shadow | All dialogs and sheets |
| `AppTheme.tableRowDivider(isDark, cs)` | `0.5 px` divider | Between rows in data-table lists |
| `AppTheme.modalBg(isDark, cs)` | `#18222E` / `cs.surface` | Modal container background |
| `AppTheme.nestedBg(isDark, cs)` | `#1A2536` / `cs.surfaceContainerHighest` | Nested sections inside modals |
| `AppTheme.overlayBg(isDark, cs)` | `#1E2A3A` / `cs.surface` | Dropdown/popover background |
| `AppTheme.borderColor(isDark, cs)` | `#2A3848` / `cs.outlineVariant@0.6` | Container/card borders |

### Summary Rules
- Typography: `w300`/`w400` body, `w500` max headings. Never `w600`/`bold`.
- Radii: `kModalRadius(12)` for dialogs, `kCardRadius(8)` for cards/inputs, `kChipRadius(4)` for tags. Never `0` or `≥ 20`.
- Spacing: `12–16 px` internal padding, `6–8 px` between items. Never `20–32 px`.
- Back button: always `Icons.chevron_left_rounded` (size 22–24). Never `Icons.arrow_back`.
- Action buttons: always animated (`AnimatedSaveButton` pattern — scale, check flash, loading spinner).
- Lists: data-table style (rows + thin dividers), not card-based. Reference: `_GradeSpreadsheet` in `paper_detail_page.dart`.
- Gold-standard reference widget: `lib/ui/widgets/create_term_modal.dart` (`_CreateTermDialog`).

## Conventions

- No business logic in UI files — all logic goes through services/DAOs.
- No direct DB or gRPC imports in screen/widget files.
- Screens are stateful when they manage subscriptions, animation controllers, or form state.
- Shared widgets go in `widgets/`. Screen-specific widgets stay in their screen directory.
- `EduTabBar` (in `widgets/edu_tab_bar.dart`) is the **single source of truth** for all tab aesthetics — no raw `TabBar` in any screen.
- All tab surfaces in the app use `EduTabBar`, whether icon-only or text-label mode.

## Last Updated
Task U03 — Back button standardisation complete. Replaced all remaining `Icons.arrow_back` and `Icons.arrow_back_rounded` usages with `Icons.chevron_left_rounded` across `lib/ui/`. Affected files:
- `lib/ui/screens/school_dashboard/school_dashboard_screen.dart` — `_FullSidebar` back button (`Icons.arrow_back` → `Icons.chevron_left_rounded`) and `_IconRail` back button (`Icons.arrow_back` → `Icons.chevron_left_rounded`).
- `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart` — `_SubjectTeacherPickerSheetState` step-back icon (`Icons.arrow_back_rounded` → `Icons.chevron_left_rounded`).

No instances of `Icons.arrow_back_ios` or `Icons.arrow_back_ios_new` were found. All sizes were ≤ 18 (below the 22 threshold) and were kept as-is per spec.

Previous: Task U01 — Codified design tokens into `AppTheme` (`kModalRadius`, `kCardRadius`, `kChipRadius`, `modalShadow`, `tableRowDivider`, `modalBg`, `nestedBg`, `overlayBg`, `borderColor`). Updated AGENT.md §21 with comprehensive design guidelines. Removed tension note between old §21 and TASKS.md mandate — `AppTheme` constants are now the single source of truth.
- Tasks U09 + U10 (TRACK C — Dialog & Modal Cleanup): Complete sweep of all `Radius.circular(20)` bottom sheet and dialog container radii reduced to `Radius.circular(12)` per `AppTheme.kModalRadius`. Files changed: `school_roles_screen.dart` (U09 full rework + border fix), `school_role_detail_screen.dart`, `system/roles/create_role_sheet.dart`, `system/roles/role_detail_screen.dart`, `system/roles/role_detail_sheet.dart`, `system/schools/create_school_sheet.dart`, `system/schools/school_detail_screen.dart` (2 locations), `system/users/invite_user_sheet.dart`, `system/users/user_detail_sheet.dart`, `system/members/members_section.dart` (3 locations), `system/plans/plans_section.dart`, `system/notifications/notifications_panel.dart`, `academics/grade_detail_page.dart`, `academics/paper_detail_page.dart`. Member creation widgets verified clean. All files compile: 0 errors.
