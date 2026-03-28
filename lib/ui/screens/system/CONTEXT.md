# ui/screens/system/ — System Admin Dashboard Context

> The system dashboard is the administrative interface for `UserLevel.system` and `UserLevel.super_` users.
> It provides platform-wide management of users, schools, plans, roles, and system settings.

## Overview

This directory contains **1 shell screen file** and **8 subdirectories**, each representing a section of the system administration dashboard. This dashboard is only accessible to users with elevated system-level privileges (`UserLevel.system` or `UserLevel.super_`).

## Entry Point

### `system_dashboard_screen.dart`
- **Status:** ✅ Complete
- **Widget:** `SystemDashboardScreen` (StatefulWidget)
- **Purpose:** Responsive shell for system-wide administration. Uses a single `Scaffold` with a `LayoutBuilder` that tracks an `_isMobile` state flag. Crossing the `kMobileBreakpoint` (600px) schedules a state update via `addPostFrameCallback` but does **not** tear down the widget tree — `_buildMobileBody()` and `_buildDesktopBody()` return body content (not separate `Scaffold`s), composed into one persistent `Scaffold` in `_buildLayout()`. This ensures that any `Navigator.push`-based detail pages (role detail, school detail, notifications, etc.) survive a window resize across the breakpoint.
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
| `users_section.dart` | `UsersSection` | ✅ Complete | List of all users rendered as flat data-table rows via `_UserRow` (`StatefulWidget` + `SingleTickerProviderStateMixin`). Each row is status-tinted by `UserStatus` (active → green, invited → blue, suspended → amber, deleted → red) with a 3px left accent bar that animates to 4px on hover. Leading: `UserAvatar` wrapped in an animated status ring border with `StatusIndicator` overlay on bottom-right. Text: name (13px w500) + phone subtitle (12px w400 muted) + "YOU" chip badge for current user. "Joined" relative date on right. Press animation: `ScaleTransition` 0.98. Animated chevron slides right and increases opacity on hover. Desktop (≥600px): inline 28×28 icon action buttons shown on hover via `_InlineActions`. Mobile (<600px): three-dot `_MobileActions` popup menu. `ListView.separated` with `AppTheme.tableRowDivider`. Row padding `horizontal: 12, vertical: 4`. Actions: Promote/Demote level, Suspend, Restore, Delete (contextual by status/level), Purge (super only). `_UserCard` and `_UserIdentityCell` removed. |
| `user_detail_sheet.dart` | `UserDetailSheet` | ✅ Complete | Slide-over/dialog showing user details — name, phone, email, level, status, created/updated timestamps. Edit actions for level and status changes. |
| `invite_user_sheet.dart` | `InviteUserSheet` | ✅ Complete | Form to invite a new user by phone number. Phone-first pattern — checks if user exists, creates with `status = invited` if not. |

**Key private widgets:** `_UserRow` (flat data-table row with status-tinted accent bar, press scale animation, animated chevron), `_RowAction` (lightweight action descriptor), `_InlineActions` / `_InlineActionButton` (desktop hover icon buttons), `_MobileActions` (three-dot popup menu), `_Toolbar`, `_ToolbarIcon`, `_FilterPanel`, `_FilterRow`, `_FilterChip`, `_ListShimmer`

**Data source:** `UsersDao.watchAllUsers()`
**Dependencies:** `database/daos/users_dao.dart`, `database/tables/enums.dart` (`UserLevel`, `UserStatus`), `ui/widgets/status_indicator.dart` (`StatusIndicator`), `ui/widgets/user_avatar.dart`, `core/extensions.dart` (`toKenyanPhone()`)

---

### `schools/`
| File | Widget | Status | Description |
|---|---|---|---|
| `schools_section.dart` | `SchoolsSection` | ✅ Complete | List of all schools rendered as flat data-table rows via `_SchoolRow` (`StatefulWidget` + `SingleTickerProviderStateMixin`). Each row is status-tinted by `SchoolStatus` (trial → blue, active → teal, suspended → amber, cancelled → orange, deleted → red) with a 3px left accent bar that animates to 4px on hover. Leading: school logo wrapped in an animated status ring border with `SchoolStatusDot` overlay. Text: name (13px w500) + motto subtitle (12px w400 muted). "Joined" relative date on right. Press animation: `ScaleTransition` 0.98. Animated chevron slides right and increases opacity on hover. Desktop (≥600px): inline 28×28 icon action buttons shown on hover via `_InlineActions`. Mobile (<600px): three-dot `_MobileActions` popup menu. `ListView.separated` with `AppTheme.tableRowDivider`. Row padding `horizontal: 12, vertical: 4`. Actions: Activate, Suspend, Restore, Delete (contextual by status), Purge (super only). `_SchoolCard` removed. |
| `school_detail_screen.dart` | `SchoolDetailScreen` | ✅ Complete | Full detail view for a school — name, motto, phone, email, county, domain, established date, status. Edit actions. |
| `create_school_sheet.dart` | `CreateSchoolSheet` | ✅ Complete | Form to create a new school. Fields: name, motto, phone, email, county. Creates school row + settings row in a transaction. Task A1: fixed `SingleChildScrollView` bottom padding (0→16) for keyboard handling after `showEduSheet` wrapper removal. Nested `_CountyPickerSheet` verified correct (own Container + handle + title + keyboard-aware ListView padding). |

**Key private widgets:** `_SchoolRow` (flat data-table row with status-tinted accent bar, press scale animation, animated chevron), `_RowAction` (lightweight action descriptor), `_InlineActions` / `_InlineActionButton` (desktop hover icon buttons), `_MobileActions` (three-dot popup menu), `_SchoolLogo`, `_Toolbar`, `_ToolbarIcon`, `_FilterPanel`, `_ListShimmer`

**Data source:** `SchoolsDao.watchAllSchools()`, `SchoolsDao.getSchoolById(id)`
**Dependencies:** `database/daos/schools_dao.dart`, `database/daos/settings_dao.dart`, `database/tables/enums.dart` (`SchoolStatus`), `ui/widgets/status_indicator.dart` (`SchoolStatusDot`), `ui/theme/app_theme.dart` (`AppTheme.tableRowDivider`, `kCardRadius`, `kModalRadius`, `overlayBg`, `borderColor`)

---

### `members/`
| File | Widget | Status | Description |
|---|---|---|---|
| `members_section.dart` | `MembersSection` | ✅ Complete | System-wide view of users with `level = system` or `level = super_`. Flat-row data-table pattern using `ListView.separated` with `AppTheme.tableRowDivider`. Each row (`_MemberRow`): status-tinted background (super active → amber/gold, system active → indigo, non-active → status colour), left accent bar (3px → 4px on hover), avatar with status ring border + `StatusIndicator` overlay, name (13px w500) + phone subtitle (12px w400 muted), trailing "System"/"Super" muted level label, `ScaleTransition` press animation (0.98), animated chevron. Desktop (≥600px): inline icon actions (`_InlineActions` / `_InlineActionButton`, 28×28, fade in on hover). Mobile (<600px): `_MobileActions` three-dot → positioned popup menu. Actions: Roles, Promote (super only, for system members), Suspend, Restore, Delete, Demote, Purge (super only). Tap opens `_MemberRolesSheet`. |

**Key private widgets:** `_RowAction` (action model with icon, label, onTap, optional color, isDestructive), `_MemberRow` (flat data-table row with status tinting and press animation), `_InlineActions` + `_InlineActionButton` (desktop hover actions), `_MobileActions` (mobile popup menu), `_MemberRolesSheet`, `_AssignRoleSheet`, `AddMemberSheet`, `_Toolbar`, `_ListShimmer`

**Data source:** `UsersDao.watchSystemMembers()`
**Dependencies:** `database/daos/users_dao.dart`, `database/tables/enums.dart` (`UserLevel`, `UserStatus`), `ui/widgets/status_indicator.dart`, `ui/widgets/user_avatar.dart`, `ui/theme/app_theme.dart` (`AppTheme.tableRowDivider`, `kCardRadius`, `kChipRadius`, `kMobileBreakpoint`, `kModalRadius`, `overlayBg`, `borderColor`, status colours), `models/permissions.dart`, `models/system_permissions.dart`

---

### `plans/`
| File | Widget | Status | Description |
|---|---|---|---|
| `plans_section.dart` | `PlansSection` | ✅ Complete | Subscription plan management rendered via `EduDataTable<Plan>`. Each row: plan icon (32×32 tinted) + name (13px w500) + price `KES x` (12px muted) + grade levels badge + `_PlanStatusBadge`. Desktop actions: Edit (opens `_PlanDetailSheet`), Delete, Purge (super only). Mobile: three-dot. Existing `_PlanDetailSheet` and `openCreatePlan` unchanged. |

**Data source:** `PlansDao.watchAllPlans()`
**Dependencies:** `database/daos/plans_dao.dart`, `database/tables/enums.dart` (`PlanStatus`), `models/plan_features.dart` (`kPlanFeatures`, `gradeLabel()`, `GradeLevel`)

---

### `roles/`
| File | Widget | Status | Description |
|---|---|---|---|
| `roles_section.dart` | `RolesSection` | ✅ Complete | System-level roles management using flat-row data-table pattern (`_RoleRow`). Each row: indigo accent bar (3px→4px on hover), 28×28 tinted shield icon (`_RoleIdentityCell`), role name (13px w500) + description subtitle on desktop (12px w400 muted), trailing permissions count (`_RolePermissionsBadge`), animated chevron on hover. Background: idle `alpha: 0.04`, hover `0.08`, press `0.12`. Press animation: `ScaleTransition` 0.98. Desktop: inline 28×28 icon action buttons appearing on hover (`_InlineActions`). Mobile: three-dot popup menu (`_MobileActions`). `ListView.separated` with `AppTheme.tableRowDivider`. Actions: View (pushes `RoleDetailScreen`), Edit (permission-gated), Delete (permission-gated), Purge (super only). |
| `role_detail_screen.dart` | `RoleDetailScreen` | ✅ Complete | Full role detail page with 2 tabs: Permissions (toggle chips grouped by resource — `resource.action` format) and Assigned Users (users with this system-scoped role via `scopes` table). Assign/unassign actions. |
| `role_detail_sheet.dart` | `RoleDetailSheet` | ✅ Complete | Compact sheet version of role detail for quick viewing. Keyboard fix applied (Task A8): `SingleChildScrollView` bottom padding uses `MediaQuery.viewInsetsOf(context).bottom + 32` to avoid keyboard occlusion in edit mode. |
| `create_role_sheet.dart` | `CreateRoleSheet` | ✅ Complete | Form to create a new system role — name, description, initial permissions. |

**Key private widgets:** `_RowAction` (action descriptor), `_RoleRow` / `_RoleRowState` (flat-row with accent bar, scale animation, hover states), `_InlineActions` / `_InlineActionButton` (desktop 28×28 icon buttons), `_MobileActions` (three-dot popup menu), `_RoleIdentityCell` (28×28 tinted icon only — name moved to row), `_RoleDescriptionCell` (kept for reuse, currently unused in row), `_RolePermissionsBadge` (plain text count), `_Toolbar`, `_ListShimmer`

**Data source:** `RolesDao.watchSystemRoles()`, `RolesDao.watchRoleById(id)`, `RolesDao.watchSystemScopes(userId)`
**Dependencies:** `database/daos/roles_dao.dart`, `models/system_permissions.dart` (`SystemPermissions`, `RolePermissions`), `models/permissions.dart`, `ui/widgets/edu_tab_bar.dart`

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
Task A3 — Fixed `CreateRoleSheet` keyboard handling after `EduSheet` wrapper removal (Task A0). Changed `SingleChildScrollView` bottom padding from static `32` to `MediaQuery.viewInsetsOf(context).bottom + 32` so form content (name/description fields and permission toggles) can be scrolled above the keyboard. Submit button is in `_SheetHeader` at the top, so no bottom action button viewInsets handling needed. Previous: Task A2.