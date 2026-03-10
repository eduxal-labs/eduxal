# ui/screens/system/ — System Admin Dashboard Context

> The system dashboard is the administrative interface for `UserLevel.system` and `UserLevel.super_` users.
> It provides platform-wide management of users, schools, plans, roles, and system settings.

## Overview

This directory contains **1 shell screen file** and **8 subdirectories**, each representing a section of the system administration dashboard. This dashboard is only accessible to users with elevated system-level privileges (`UserLevel.system` or `UserLevel.super_`).

## Entry Point

### `system_dashboard_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `SystemDashboardScreen` (StatefulWidget)
- **Purpose:** Responsive shell for system-wide administration. Similar layout pattern to the school dashboard — sidebar on desktop, tabs/navigation on mobile.
- **Key responsibilities:**
  - Hosts all system-scoped sections (stats, users, schools, plans, roles).
  - Computes `SystemPermissions` for the current user and provides them to child sections.
  - Routes to content sections based on selected nav item.
  - Provides profile avatar with sync-failure badge, sync indicator, and user menu (Account / Notifications / Logout) in the top bar for both mobile and desktop layouts.
- **Navigation items (mobile, 6 tabs):** Home/Stats | Users | Members | Schools | Roles | Plans
- **Navigation items (desktop, 5 tabs):** Users | Members | Schools | Roles | Plans
- **User menu actions:** Account → `AccountScreen`, Notifications → `NotificationsPage`, Logout → `client.logOut()`
- **Private widgets:** `_UserMenuAnchor` (avatar + badge + overlay trigger), `_UserMenuOverlay` (animated barrier + positioned card), `_UserMenuCard` (header + action items), `_SysMenuItem` (single row with ink hover), `_UserMenuAction` enum
- **Dependencies:** `client.dart` (global DAOs, `cache.currentUser`), `models/system_permissions.dart`, `models/authenticated.dart`, `database/daos/roles_dao.dart` (for system-scoped permissions), `ui/widgets/sync_indicator.dart`, `ui/widgets/user_avatar.dart`, `ui/screens/account/account_screen.dart`, `ui/screens/notifications/notifications_page.dart`

## Subdirectories

### `home/`
| File | Widget | Status | Description |
|---|---|---|---|
| `system_stats_section.dart` | `SystemStatsSection` | ✅ Complete | Dashboard landing page with aggregate statistic cards — user counts by status, school counts by status, student counts, teacher counts, subscription stats, revenue stats, student-plan breakdown (donut chart). Uses stat models from `models/system_stats.dart`. |

**Data source:** `SystemStatsDao.watchUserStats()`, `watchSchoolStats()`, `watchStudentStats()`, `watchTeacherStats()`, `watchSubscriptionStats()`, `watchRevenueStats()`, `watchStudentPlanStats()`
**Dependencies:** `database/daos/system_stats_dao.dart`, `models/system_stats.dart` (all stat model classes), `models/system_permissions.dart` (`canSeeDeleted` for showing/hiding deleted counts)

---

### `users/`
| File | Widget | Status | Description |
|---|---|---|---|
| `users_section.dart` | `UsersSection` | ✅ Complete | List of all users in the system. Search/filter by name, phone, status. Each row shows name, phone, level badge, status badge. |
| `user_detail_sheet.dart` | `UserDetailSheet` | ✅ Complete | Slide-over/dialog showing user details — name, phone, email, level, status, created/updated timestamps. Edit actions for level and status changes. |
| `invite_user_sheet.dart` | `InviteUserSheet` | ✅ Complete | Form to invite a new user by phone number. Phone-first pattern — checks if user exists, creates with `status = invited` if not. |

**Data source:** `UsersDao.watchAllUsers()`
**Dependencies:** `database/daos/users_dao.dart`, `database/tables/enums.dart` (`UserLevel`, `UserStatus`), `core/extensions.dart` (`toKenyanPhone()`)

---

### `schools/`
| File | Widget | Status | Description |
|---|---|---|---|
| `schools_section.dart` | `SchoolsSection` | ✅ Complete | List of all schools. Each row shows school name, motto, status badge, county. Search/filter support. |
| `school_detail_screen.dart` | `SchoolDetailScreen` | ✅ Complete | Full detail view for a school — name, motto, phone, email, county, domain, established date, status. Edit actions. |
| `create_school_sheet.dart` | `CreateSchoolSheet` | ✅ Complete | Form to create a new school. Fields: name, motto, phone, email, county. Creates school row + settings row in a transaction. |

**Data source:** `SchoolsDao.watchAllSchools()`, `SchoolsDao.getSchoolById(id)`
**Dependencies:** `database/daos/schools_dao.dart`, `database/daos/settings_dao.dart`, `database/tables/enums.dart` (`SchoolStatus`)

---

### `members/`
| File | Widget | Status | Description |
|---|---|---|---|
| `members_section.dart` | `MembersSection` | ✅ Complete | System-wide view of members across all schools. Shows aggregated counts or a searchable list of owners/teachers/staff/students/guardians across the platform. |

**Data source:** Various DAOs — `MembersDao` queries without school scope, or aggregate counts.
**Dependencies:** `database/daos/members_dao.dart`

---

### `plans/`
| File | Widget | Status | Description |
|---|---|---|---|
| `plans_section.dart` | `PlansSection` | ✅ Complete | Subscription plan management. List of plans with name, description, amount, status, grade levels (bitmask decoded via `gradeLabel()`), features. Create/edit/delete plan actions. |

**Data source:** `PlansDao.watchAllPlans()`
**Dependencies:** `database/daos/plans_dao.dart`, `database/tables/enums.dart` (`PlanStatus`), `models/plan_features.dart` (`kPlanFeatures`, `gradeLabel()`, `GradeLevel`)

---

### `roles/`
| File | Widget | Status | Description |
|---|---|---|---|
| `roles_section.dart` | `RolesSection` | ✅ Complete | System-level roles management. List of roles where `school IS NULL`. Each card shows role name, description, permission count. |
| `role_detail_screen.dart` | `RoleDetailScreen` | ✅ Complete | Full role detail page with 2 tabs: Permissions (toggle chips grouped by resource — `resource.action` format) and Assigned Users (users with this system-scoped role via `scopes` table). Assign/unassign actions. |
| `role_detail_sheet.dart` | `RoleDetailSheet` | ✅ Complete | Compact sheet version of role detail for quick viewing. |
| `create_role_sheet.dart` | `CreateRoleSheet` | ✅ Complete | Form to create a new system role — name, description, initial permissions. |

**Data source:** `RolesDao.watchSystemRoles()`, `RolesDao.watchRoleById(id)`, `RolesDao.watchSystemScopes(userId)`
**Dependencies:** `database/daos/roles_dao.dart`, `models/system_permissions.dart` (`SystemPermissions`, `RolePermissions`), `ui/widgets/edu_tab_bar.dart`

---

### `settings/`
| File | Widget | Status | Description |
|---|---|---|---|
| `system_settings_screen.dart` | `SystemSettingsScreen` | ✅ Complete | System-wide settings management. Currently a minimal screen — placeholder for future system configuration options. |

**Dependencies:** Minimal — mostly static UI with potential future DAO connections.

---

### `notifications/`
| File | Widget | Status | Description |
|---|---|---|---|
| `notifications_section.dart` | `NotificationsSection` | ✅ Complete | Displays failed sync log entries as notifications. Lists all `logs` rows with `status = failed` for the current account, mapped to `AppNotification` display models. |
| `notifications_panel.dart` | `NotificationsPanel` | ✅ Complete | Panel/overlay version of the notifications list, used in the dashboard shell for quick access. |

**Data source:** `LogsDao.watchFailedLogs(accountId)` → mapped to `List<AppNotification>`
**Dependencies:** `database/daos/logs_dao.dart`, `models/app_notification.dart` (`AppNotification`), `database/tables/enums.dart` (`SyncAction`)

**Migration note (Task C13):** All three notification widgets were updated to use the action-based `SyncAction` enum instead of the old `LogTable`/`LogOperation` enums. Icon mapping is now by domain group derived from `SyncAction`, and operation badges derive create/update/delete/assign/mark/approve labels from the action name prefix. The old `_OperationBadge` widget was replaced by `_ActionBadge`. The `notification.rowKey` field was replaced by `notification.resource`.

## Permission Gating

System sections check `SystemPermissions` before rendering sensitive actions:

| Action | Required permission |
|---|---|
| View users | `users.read` (auto-granted for system/super_ levels) |
| Edit user level/status | `users.update` |
| Create school | `schools.create` |
| Delete school | `schools.delete` |
| Manage plans | `plans.create`, `plans.update`, `plans.delete` |
| Manage roles | `roles.create`, `roles.update`, `roles.delete` |
| See deleted records | Only `UserLevel.super_` (`SystemPermissions.canSeeDeleted`) |

For `UserLevel.super_` and `UserLevel.system` users, all permissions are granted unconditionally via the level shortcut in `SystemPermissions.can()`.

## Dependencies

- **Depends on:** `models/system_permissions.dart`, `models/system_stats.dart`, `models/app_notification.dart`, `models/plan_features.dart`, `models/authenticated.dart`, `database/daos/` (system_stats_dao, users_dao, schools_dao, roles_dao, plans_dao, logs_dao, members_dao, settings_dao), `database/tables/enums.dart`, `ui/widgets/edu_tab_bar.dart`, `core/extensions.dart`, `client.dart`
- **Depended on by:** `home/home_screen.dart` (navigates to `SystemDashboardScreen` for elevated users)

## Conventions

- All sections receive `SystemPermissions` from the shell — they never compute their own.
- Data is not school-scoped — all queries are system-wide (no `schoolId` filter).
- The notification system reads from the `logs` table directly — it does not depend on the sync engine.
- Permission gating uses `SystemPermissions.can(action)` — never raw `UserLevel` checks in UI code (except `canSeeDeleted` which is level-specific by design).

## Last Updated
Task 03 — Removed Notifications tab from both mobile (7→6 tabs) and desktop (6→5 tabs). Added profile avatar with sync-failure badge count (`logsDao.watchFailedLogCount`), `SyncIndicator` widget, and `_UserMenuAnchor` overlay (Account / Notifications / Logout) to both mobile and desktop top-bar rows. Notifications action navigates to standalone `NotificationsPage`. Removed `notifications_section.dart` import from the shell (section files in `notifications/` subdirectory remain intact for potential reuse).