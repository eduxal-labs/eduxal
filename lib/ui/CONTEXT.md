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

## UI Design Guidelines (from AGENT.md §21)

- **Aesthetic:** Clean, minimal, thin, and modern. No heavy, bold, or outdated elements.
- **Typography:** Thin/light font weights (`w300`/`w400` for body, `w500` max for headings). Avoid `w600` or `bold` unless strictly necessary.
- **Shapes & Borders:** Rigid, sharp, or very slightly blunted corners. `BorderRadius.circular(4)` or `0`. Absolutely no pill shapes (`24` or `50` radius).
- **Borders:** Prefer thin, crisp borders (1px) over heavy shadows or thick fills.
- **Elevation:** Subtle elevation (shadows) and slight color shifts/tints to separate layers. No flat UI, but no heavy shadows either.
- **General:** Maximize whitespace. Keep the UI feeling airy, precise, and architectural.

### UI/UX Design Mandate (from TASKS.md conventions)

- Elements should feel slim and dense, not "spongy", doughy, or bloated.
- Absolutely NO borders on most elements — use subtle elevation and color shifts instead.
- "In-between" corners — neither perfectly sharp nor pill-shaped (typically `BorderRadius.circular(8)` to `12` for cards/containers).
- Generous whitespace. Solid, precise, and architectural feel.

> **Note:** There is a slight tension between AGENT.md §21 (says `BorderRadius.circular(4)` or `0`, thin borders) and the TASKS.md mandate (says `8`-`12`, no borders). The TASKS.md mandate reflects the most recent design decisions and should take precedence for new UI work. When in doubt, follow the TASKS.md mandate: subtle elevation over borders, `8`-`12` radius for containers, no pill shapes.

## Conventions

- No business logic in UI files — all logic goes through services/DAOs.
- No direct DB or gRPC imports in screen/widget files.
- Screens are stateful when they manage subscriptions, animation controllers, or form state.
- Shared widgets go in `widgets/`. Screen-specific widgets stay in their screen directory.
- `EduTabBar` (in `widgets/edu_tab_bar.dart`) is the **single source of truth** for all tab aesthetics — no raw `TabBar` in any screen.
- All tab surfaces in the app use `EduTabBar`, whether icon-only or text-label mode.

## Last Updated
Task P3 — Migrated all permission-related UI call sites from string-based `permissions.can('resource.action')` API to typed `permissions.can(Resource.xxx, Action.yyy)` API. Seven files updated in `screens/system/`: `system_dashboard_screen.dart`, `members/members_section.dart`, `plans/plans_section.dart`, `roles/role_detail_screen.dart`, `roles/role_detail_sheet.dart`, `schools/school_detail_screen.dart`, `users/user_detail_sheet.dart`. Each file now imports `permissions.dart` (with `show Action, Resource`) and hides Flutter's `Action` from `material.dart` to avoid name conflict. String-to-typed mapping: `'scopes.create'` → `Resource.roles, Action.assign`; `'scopes.delete'` → `Resource.roles, Action.unassign`; `'settings.update'` → `Resource.schools, Action.update`; all other strings mapped directly (e.g. `'plans.update'` → `Resource.plans, Action.update`).