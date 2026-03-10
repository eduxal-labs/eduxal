# ui/screens/ — Screen Inventory Context

> Every screen/page in the app lives here, organized by feature area.
> Each subdirectory represents a distinct area of the app with one or more screen files.

## Overview

This directory contains **7 subdirectories**, each representing a major area of the application. Screens are the top-level route destinations — they compose widgets, bind to streams/futures from services and DAOs, and manage navigation.

## Directory Map

| Directory | Purpose | Screen count |
|---|---|---|
| `account/` | User account/profile management | 1 |
| `auth/` | Authentication flow — login, OTP, setup | 3 |
| `home/` | Home screen — membership picker (school cards) | 1 |
| `notifications/` | Standalone full-page notifications screen | 1 |
| `school_dashboard/` | School-scoped dashboard — the main app surface | 10+ (has own CONTEXT.md) |
| `splash/` | Splash/loading screen — session check + routing | 1 |
| `system/` | System admin dashboard for super_/system users | 8+ (has own CONTEXT.md) |

## Screens — Detailed

### `splash/splash_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `SplashScreen` (StatefulWidget)
- **Purpose:** App entry point screen. Checks `client.active()` to determine if a session exists, then routes accordingly. When `kDemoMode` is `true` and no schools exist locally, auto-seeds the database with realistic demo data via `Seeder.seed()` before navigating to `HomeScreen`.
- **Navigation:**
  - Active session found → (auto-seed if `kDemoMode` + empty schools) → `HomeScreen`
  - No session / expired → `LoginScreen`
- **Dependencies:** `client.dart` (`client.active()`), `models/authenticated.dart`, `core/constants.dart` (`kDemoMode`), `core/seeder.dart` (`Seeder`), `database/database.dart` (`db`)

---

### `auth/login_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `LoginScreen` (StatefulWidget)
- **Purpose:** Phone number input screen. Calls `client.authentication.login(phone)` to send OTP.
- **Navigation:** On success → `OtpScreen`
- **Dependencies:** `client.dart` (`client.authentication`), `core/extensions.dart` (`toKenyanPhone()`), `core/grpc_errors.dart` (`toFriendlyMessage()`), `models/result.dart`

### `auth/otp_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `OtpScreen` (StatefulWidget)
- **Purpose:** OTP verification screen. Calls `client.authentication.verify(phone, code)`.
- **Navigation:**
  - `VerifyResultAuthenticated` → saves account via `client.saveAccount()` → `HomeScreen`
  - `VerifyResultRegistered` → `SetupScreen` (passes registration token)
- **Dependencies:** `client.dart`, `models/verify_result.dart`, `models/result.dart`, `core/constants.dart` (`kVerificationExpiry`, `kResendCooldown`)

### `auth/setup_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `SetupScreen` (StatefulWidget)
- **Purpose:** New user registration — name input + optional profile image. Calls `client.authentication.setup(token, name)`.
- **Navigation:** On success → saves account via `client.saveAccount()` → `HomeScreen`
- **Dependencies:** `client.dart`, `models/setup_result.dart`, `models/result.dart`, `cache/file_cache.dart`

---

### `home/home_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `HomeScreen` (StatefulWidget)
- **Purpose:** Membership picker — displays one card per school the user belongs to. Each card shows role badges and school info.
- **Data source:** `membershipsDao.watchMemberships(userId)` → `Stream<List<SchoolMembership>>`
- **Navigation:**
  - Single entry → navigates directly to `SchoolDashboardScreen` with that entry
  - Multiple entries → shows picker dialog → user selects entry → `SchoolDashboardScreen`
  - System admin users may also see a route to `SystemDashboardScreen`
  - Account icon → `AccountScreen`
- **Dependencies:** `client.dart` (`membershipsDao`, `cache.currentUser`), `models/membership.dart` (`SchoolMembership`, `MembershipEntry`, `MembershipRole`), `models/school_context.dart`, `models/school_permissions.dart`

---

### `account/account_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `AccountScreen` (StatefulWidget)
- **Purpose:** User profile management — view/edit name, email, phone, profile image. Theme preference toggle. Account switching. Logout. Hidden developer trigger for demo data seeder.
- **Data source:** `accountsDao.watchActiveAccount()` → `Stream<Authenticated?>`
- **Key features:**
  - Edit name/email (writes to `users` table + `logs`)
  - Change phone number (calls `authentication.changePhone()` + `confirmChangePhone()`)
  - Theme toggle (writes to `accounts.theme` via `accountsDao.updateTheme()`)
  - Profile image picker (saves via `FileCache.saveBytes()`)
  - Account switcher (calls `client.switchAccount()`)
  - Logout (calls `client.logOut()`)
  - **Hidden seeder trigger:** Long-press on "eduxal v1.0.0" version footer text → confirmation dialog → runs `Seeder.seed()` → shows snackbar with result
- **Dependencies:** `client.dart` (multiple DAOs, `client` methods), `models/authenticated.dart`, `cache/file_cache.dart`, `database/tables/enums.dart` (`AppThemeMode`), `core/seeder.dart` (`Seeder`), `database/database.dart` (`db`)

---

### `notifications/notifications_page.dart`
- **Status:** ✅ Complete
- **Widget:** `NotificationsPage` (StatelessWidget)
- **Purpose:** Standalone full-page screen displaying all failed sync log entries for the active account. Navigated to from the user menu overlay on both the School Dashboard and System Dashboard.
- **Data source:** `logsDao.watchFailedLogs(accountId)` → `Stream<List<AppNotification>>`, `logsDao.watchFailedLogCount(accountId)` → `Stream<int>` (for title badge)
- **Key features:**
  - AppBar with back chevron, "Notifications" title, and live count badge
  - Reactive list of failed sync entries with domain icon (derived from `SyncAction`), title, action badge (Create/Update/Delete/Assign/Mark/Approve/etc.), error subtitle, monospaced resource identifier, and relative timestamp
  - Empty state with checkmark icon + "No sync issues." centered
  - Each tile wrapped in `InkWell` for future retry/dismiss interactions
  - Icon mapping (`_iconForAction`), relative time formatter, and action badge (`_ActionBadge`) are self-contained top-level helpers
- **Constructor:** `NotificationsPage({required String accountId})`
- **Dependencies:** `client.dart` (`logsDao`), `models/app_notification.dart`, `database/tables/enums.dart` (`SyncAction`), `ui/theme/app_theme.dart`
- **Migration note (Task C13):** Updated from old `LogTable`/`LogOperation` enums to action-based `SyncAction`. `_iconForTable` → `_iconForAction`, `_OperationBadge` → `_ActionBadge`, `notification.rowKey` → `notification.resource`.

---

### `school_dashboard/` — School Dashboard
- **Has own CONTEXT.md** at `school_dashboard/CONTEXT.md`
- **Entry point:** `school_dashboard_screen.dart` — responsive shell with sidebar (desktop) / top tabs (mobile)
- **Subdirectories:** `academics/`, `announcements/`, `attendance/`, `exams/`, `finance/`, `members/`, `roles/`, `timetable/`
- See `school_dashboard/CONTEXT.md` for full details.

---

### `system/` — System Admin Dashboard
- **Has own CONTEXT.md** at `system/CONTEXT.md`
- **Entry point:** `system_dashboard_screen.dart` — responsive shell for super_/system level users
- **Subdirectories:** `home/`, `members/`, `notifications/`, `plans/`, `roles/`, `schools/`, `settings/`, `users/`
- See `system/CONTEXT.md` for full details.

## Navigation Flow

```
main.dart → SplashScreen
                │
        ┌───────┴────────┐
        │                │
   LoginScreen      HomeScreen ─────────── AccountScreen
        │                │
   OtpScreen    ┌────────┴────────┐
        │       │                 │
   SetupScreen  SchoolDashboard   SystemDashboard
                (role-scoped)     (admin-only)
```

## Dependencies

- **Depends on:** `models/` (all domain models), `services/` (`Authentication`, `MemberCreationService`), `database/daos/` (global DAO singletons), `core/` (constants, extensions, grpc_errors), `cache/file_cache.dart`, `client.dart` (global `client`, `cache`, DAOs), `ui/widgets/` (shared components), `ui/theme/` (`AppTheme`)
- **Depended on by:** `main.dart` (imports `SplashScreen`)

## Conventions

- Screen files are named `{feature}_screen.dart` (e.g. `login_screen.dart`, `home_screen.dart`).
- Each screen is a `StatefulWidget` when it manages subscriptions, animation controllers, or form state.
- Screens never import `package:drift` or `package:grpc` directly — they use DAOs and services.
- Navigation uses `Navigator.push` / `Navigator.pushReplacement` with `MaterialPageRoute`.
- Screen-specific helper widgets (that are only used by one screen) live in the same directory as the screen.

## Last Updated
Phase 1–3 Tasks 01–09 — Added `notifications/notifications_page.dart` (standalone full-page notifications screen for failed sync logs, navigable from both dashboards). System Dashboard (`system/`) updated: removed Notifications tab from navigation, added profile avatar with sync-failure badge count + `SyncIndicator` + user menu overlay (Account / Notifications / Logout) to top bar. School Dashboard (`school_dashboard/`) updated: wired notifications action in user menu, added sync-failure badge on avatar, fixed student image display in members list (`_StudentAvatar` uses `FileCache.studentImagePath`), redesigned student detail header (icon action buttons replacing `PopupMenuButton`), redesigned student edit sheet (inline calendar, compact save button, entrance animation), added student photo editing to edit sheet, polished add student creation panel (compact CTA, entrance animation, tighter spacing). Both dashboards now have profile avatar with badge + sync indicator in their top bars.