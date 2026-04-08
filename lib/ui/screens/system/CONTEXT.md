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
| `system_stats_section.dart` | `SystemStatsSection` | ✅ Complete | Dashboard landing page with aggregate statistic cards — user counts by status, school counts by status, student counts, teacher counts, subscription stats, revenue stats. Uses stat models from `models/system_stats.dart`. **Resilient per-card streams (F02):** Each stat card now subscribes to its own `StreamBuilder` independently via `_IndependentStatCard<T>`, so a single failed query only affects that one card — not the entire dashboard. Failed cards show `_SingleCardError` (error icon with tooltip containing the error message). Loading cards show `_SingleCardSkeleton` (per-card shimmer animation). The old deeply-nested 6-StreamBuilder pyramid (`_StatsCardGrid`) and all-or-nothing `_StatsErrorCard`/`_CardGridSkeleton` have been removed. Card builder methods are now `static` on `_StatsCardGrid` and accept their stats type as a parameter. Layout (desktop Wrap / mobile Wrap) is unified in a single `LayoutBuilder` inside `_StatsCardGrid.build()`. |

**Data source:** `SystemStatsDao.watchUserStats()`, `watchSchoolStats()`, `watchStudentStats()`, `watchTeacherStats()`, `watchSubscriptionStats()`, `watchRevenueStats()` — each consumed by an independent `_IndependentStatCard<T>` StreamBuilder
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
| `school_detail_screen.dart` | `SchoolDetailScreen` | ✅ Complete | Full detail view for a school — name, motto, phone, email, county, domain, established date, status. Edit actions. Task A10: audited `_EditSchoolSheet`, `_AddOwnerSheet`, `_MpesaConfigSheet` — all three manage their own Container, handle, title row, and `viewInsets.bottom` padding correctly after `showEduSheet` wrapper removal (A0). No double-layer issues, no changes needed. |
| `create_school_sheet.dart` | `CreateSchoolSheet` | ✅ Complete | Form to create a new school. Fields: name, motto, phone, email, county. Creates school row + settings row in a transaction. Task A1: fixed `SingleChildScrollView` bottom padding (0→16) for keyboard handling after `showEduSheet` wrapper removal. Nested `_CountyPickerSheet` verified correct (own Container + handle + title + keyboard-aware ListView padding). |

**Key private widgets:** `_SchoolRow` (flat data-table row with status-tinted accent bar, press scale animation, animated chevron), `_RowAction` (lightweight action descriptor), `_InlineActions` / `_InlineActionButton` (desktop hover icon buttons), `_MobileActions` (three-dot popup menu), `_SchoolLogo`, `_Toolbar`, `_ToolbarIcon`, `_FilterPanel`, `_ListShimmer`

**Data source:** `SchoolsDao.watchAllSchools()`, `SchoolsDao.getSchoolById(id)`
**Dependencies:** `database/daos/schools_dao.dart`, `database/daos/settings_dao.dart`, `database/tables/enums.dart` (`SchoolStatus`), `ui/widgets/status_indicator.dart` (`SchoolStatusDot`), `ui/theme/app_theme.dart` (`AppTheme.tableRowDivider`, `kCardRadius`, `kModalRadius`, `overlayBg`, `borderColor`)

---

### `members/`
| File | Widget | Status | Description |
|---|---|---|---|
| `members_section.dart` | `MembersSection` | ✅ Complete | System-wide view of users with `level = system` or `level = super_`. Flat-row data-table pattern using `ListView.separated` with `AppTheme.tableRowDivider`. Each row (`_MemberRow`): status-tinted background (super active → amber/gold, system active → indigo, non-active → status colour), left accent bar (3px → 4px on hover), avatar with status ring border + `StatusIndicator` overlay, name (13px w500) + phone subtitle (12px w400 muted), trailing "System"/"Super" muted level label, `ScaleTransition` press animation (0.98), animated chevron. Desktop (≥600px): inline icon actions (`_InlineActions` / `_InlineActionButton`, 28×28, fade in on hover). Mobile (<600px): `_MobileActions` three-dot → positioned popup menu. Actions: Roles, Promote (super only, for system members), Suspend, Restore, Delete, Demote, Purge (super only). Tap opens `_MemberRolesSheet`. `AddMemberSheet` keyboard fix applied (Task A4): `ListView.separated` bottom padding uses `MediaQuery.viewInsetsOf(context).bottom + 24` so the user list scrolls properly when the search field keyboard is open. `_AssignRoleSheet` keyboard fix applied (Task A9): same pattern — `ListView.separated` bottom padding uses `MediaQuery.viewInsetsOf(context).bottom + 24` for keyboard-aware scrolling on the role search list. `_MemberRolesSheet` audited (Task A9): no changes needed — no text input, handle renders correctly post-A0. **Defense-in-depth permission guards (Task E05):** Three action handler methods now have defense-in-depth permission checks in addition to the existing UI-level button visibility gating: `_removeMember()` checks `Users.Update` before demoting; `_purgeMember()` checks `UserLevel.super_` before purging; `_updateStatus()` checks `Users.Update` (or `Users.Delete` for delete status) before any status change. All show a SnackBar and return early if the permission check fails. The UI-level `canUpdate`/`canDelete` variables in `build()` already conditionally hide action buttons — the handler-level checks are a second layer of protection against programmatic bypass. **`AddMemberSheet._promote` permission guard (Task A5):** `_promote()` now checks `widget.permissions.can(Resource.users, Action.update)` at the start and returns early if the caller lacks permission. This is a defense-in-depth guard — the sheet's visibility is already gated at the FAB level, but the method itself now independently verifies authorization before calling `usersDao.setUserLevel`. |

**Key private widgets:** `_RowAction` (action model with icon, label, onTap, optional color, isDestructive), `_MemberRow` (flat data-table row with status tinting and press animation), `_InlineActions` + `_InlineActionButton` (desktop hover actions), `_MobileActions` (mobile popup menu), `_MemberRolesSheet`, `_AssignRoleSheet`, `AddMemberSheet`, `_Toolbar`, `_ListShimmer`

**Data source:** `UsersDao.watchSystemMembers()`
**Dependencies:** `database/daos/users_dao.dart`, `database/tables/enums.dart` (`UserLevel`, `UserStatus`), `ui/widgets/status_indicator.dart`, `ui/widgets/user_avatar.dart`, `ui/theme/app_theme.dart` (`AppTheme.tableRowDivider`, `kCardRadius`, `kChipRadius`, `kMobileBreakpoint`, `kModalRadius`, `overlayBg`, `borderColor`, status colours), `models/permissions.dart`, `models/system_permissions.dart`

---

### `plans/`
| File | Widget | Status | Description |
|---|---|---|---|
| `plans_section.dart` | `PlansSection` | ✅ Complete | Subscription plan management rendered via `EduDataTable<Plan>`. Each row: plan icon (32×32 tinted) + name (13px w500) + price `KES x` (12px muted) + grade levels badge + `_PlanStatusBadge`. Left accent bar (3px, `cs.primary @ 0.7`) appears on hover via `_EduDataTableRow` enhancement in `edu_data_table.dart` — visually consistent with redesigned flat-row sections. Desktop actions: Edit (opens `_PlanDetailSheet`), Delete, Purge (super only). Mobile: three-dot. `_CreatePlanSheet` (Task A5) and `_PlanDetailSheet` (Task A6) both have viewInsets-aware bottom padding on their `SingleChildScrollView` to prevent keyboard occlusion in edit mode. |

**Data source:** `PlansDao.watchAllPlans()`
**Dependencies:** `database/daos/plans_dao.dart`, `database/tables/enums.dart` (`PlanStatus`), `models/plan_features.dart` (`kPlanFeatures`, `gradeLabel()`, `GradeLevel`)

---

### `roles/`
| File | Widget | Status | Description |
|---|---|---|---|
| `roles_section.dart` | `RolesSection` | ✅ Complete | System-level roles management using flat-row data-table pattern (`_RoleRow`). Each row: indigo accent bar (3px→4px on hover), 28×28 tinted shield icon (`_RoleIdentityCell`), role name (13px w500) + description subtitle on desktop (12px w400 muted), trailing permissions count (`_RolePermissionsBadge`), animated chevron on hover. Background: idle `alpha: 0.04`, hover `0.08`, press `0.12`. Press animation: `ScaleTransition` 0.98. Desktop: inline 28×28 icon action buttons appearing on hover (`_InlineActions`). Mobile: three-dot popup menu (`_MobileActions`). `ListView.separated` with `AppTheme.tableRowDivider`. Actions: View (pushes `RoleDetailScreen`), Edit (permission-gated), Delete (permission-gated), Purge (super only). |
| `role_detail_screen.dart` | `RoleDetailScreen` | ✅ Complete | Full role detail page with 2 tabs: Permissions (toggle chips grouped by resource — `resource.action` format using typed `Resource`/`Action` enums) and Assigned Users (users with this system-scoped role via `scopes` table). Assign/unassign actions. |
| `role_detail_sheet.dart` | `RoleDetailSheet` | ✅ Complete | Compact sheet version of role detail for quick viewing. Keyboard fix applied (Task A8): `SingleChildScrollView` bottom padding uses `MediaQuery.viewInsetsOf(context).bottom + 32` to avoid keyboard occlusion in edit mode. |
| `create_role_sheet.dart` | `CreateRoleSheet` | ✅ Complete | Form to create a new system role — name, description, initial permissions. |

**Shared permission editor (Task B1):** All three role files (`create_role_sheet.dart`, `role_detail_screen.dart`, `role_detail_sheet.dart`) now import `ui/screens/shared/role_permission_editor.dart` for `kResourceGroups`, `kActionColors`, `kActionIcons`, and `actionLabel`. The old per-file `_buildResourceGroups`, `_ResourceGroup`, `_kBaseActions`, `_kActionColors`, `_kActionIcons`, and `_capitalise` have been removed. Resource groups now use typed `Resource`/`Action` enums from `models/permissions.dart` instead of string-keyed maps. The flat `kResourceGroups` list (19 resources, one per `ResourceGroup`) replaces the old category-grouped structure ("People", "Academic", etc.). Permission state keys use `resource.name` + `action.name` (e.g. `"classes.assign"`, `"attendance.mark"`), eliminating the old string-based key mismatch (e.g. `"classTeachers"` vs `"classes"`).

**Key private widgets:** `_RowAction` (action descriptor), `_RoleRow` / `_RoleRowState` (flat-row with accent bar, scale animation, hover states), `_InlineActions` / `_InlineActionButton` (desktop 28×28 icon buttons), `_MobileActions` (three-dot popup menu), `_RoleIdentityCell` (28×28 tinted icon only — name moved to row), `_RoleDescriptionCell` (kept for reuse, currently unused in row), `_RolePermissionsBadge` (plain text count), `_Toolbar`, `_ListShimmer`

**Data source:** `RolesDao.watchSystemRoles()`, `RolesDao.watchRoleById(id)`, `RolesDao.watchSystemScopes(userId)`
**Dependencies:** `database/daos/roles_dao.dart`, `models/system_permissions.dart` (`SystemPermissions`, `RolePermissions`), `models/permissions.dart`, `ui/screens/shared/role_permission_editor.dart`, `ui/widgets/edu_tab_bar.dart`

---

### `settings/`
| File | Widget | Status | Description |
|---|---|---|---|
| `system_settings_screen.dart` | `SystemSettingsScreen` | ✅ Complete | System-wide settings management. Currently a minimal screen — placeholder for future system configuration options. |
| `subjects_section.dart` | `SubjectsSection` | ✅ Complete | Global subject & topic catalog management. Each topic's expanded content (`_TopicExpandedContent`) now includes a **Questions panel** with: FutureBuilder-driven question count badge (via `questionBankService.listQuestions`), permission-gated "Add question" button (`Subjects.create`) that opens `CreateQuestionSheet` via `showEduSheet`, "Import questions" button (opens `BulkImportSheet` via `showEduSheet`), "View all questions →" navigation row (navigates to `QuestionsListPage`), and "Bulk import" row (opens `BulkImportSheet`). `_TopicExpandedContent` converted from StatelessWidget to StatefulWidget to cache the count future; now accepts `canEdit` and `canDelete` props (passed through from `_TopicTile`) for forwarding to `QuestionsListPage`. `_TopicTile` and `_TopicList` pass `canCreate`, `canEdit`, `canDelete` down the widget tree. Topic tiles now show a question count badge (pill-shaped, primary-tinted, "N questions") next to the topic name, loaded via `questionBankService.listQuestions` with limit 1 to fetch only the count. |
| `questions_list_page.dart` | `QuestionsListPage` | ✅ Complete | Full-page screen showing all questions for a topic with paginated loading (50 per page, "Load more" button). Constructor accepts `topicId`, `topicName`, `subjectName`, `grade`, `canEdit`, `canDelete`, `canCreate`. AppBar: back chevron + "{subjectName} › {topicName}" title (w400, 17px) + "+" create button. Body: data-table-style list with `AppTheme.tableRowDivider` between rows; each row shows question number badge, truncated text (2 lines, w300, 13px), marks pill badge, rubric count badge, and action buttons (desktop: inline edit/delete 28×28 icon buttons; mobile: `Icons.more_vert` → bottom sheet). Tapping a row expands inline (animated `SizeTransition` like `_TopicTile` pattern) showing full question text, rubric criteria list with marks badges, example answer (italic), and image references with context badges. Edit opens `_EditQuestionSheet` (self-contained per BUG-010, wraps in `EduSheet`, pre-fills all fields from `Question`, calls `questionBankService.updateQuestion`). Delete shows `showEduConfirmDialog` → `questionBankService.deleteQuestion` → removes from list → SnackBar. Empty state: book icon + "No questions yet" message. Error state: retry button. Private widgets: `_QuestionRow`, `_QuestionExpandedContent`, `_SectionLabel`, `_TinyAction`, `_EmptyState`, `_ErrorState`, `_LoadMoreButton`, `_EditQuestionSheet`, `_RubricEntry`, `_ImageEntry`, `_ErrorBanner`. |
| `create_question_sheet.dart` | `CreateQuestionSheet` | ✅ Complete | Bottom sheet / desktop dialog for creating a single question under a topic. Launched via `showEduSheet`. Self-contained per BUG-010/BUG-016 — wraps content in `EduSheet` for mobile background, drag handle, title row, and keyboard padding. Form fields: multiline question text (`EduFormField`, minLines 3), total marks (numeric, 80px), dynamic rubric criteria list (criterion text + marks + delete, with sum-equals-total validation), collapsible example answer section, and collapsible image references section (context dropdown, filename, caption, description per image). Submit calls `questionBankService.createQuestion()` with `accessToken`. On success: pops sheet, fires `onCreated` callback, shows SnackBar. On error: shows `_ErrorBanner`. Private helper widgets: `_SmallIconButton`, `_TinyIconButton`, `_ErrorBanner`, `_AddRowButton`, `_ExpandLink`, `_RubricEntry`, `_ImageEntry`. |
| `bulk_import_sheet.dart` | `BulkImportSheet` | ✅ Complete | Bottom sheet / desktop dialog for bulk-importing questions from pasted JSON content into a topic. Launched via `showEduSheet`. Self-contained per BUG-010 — wraps content in `EduSheet` wrapper. Constructor params: `topicId`, `topicName`, `subjectName`, `onImported` (VoidCallback?). **Two-phase flow:** (1) **Validate** — user pastes JSON into a multiline `_JsonTextField` (monospace, line numbers, syntax-aware), taps "Validate" `_ActionChip` → local JSON parse + schema validation (`_validate()` method checks array of objects with required `text`/`marks`/`rubric` fields, optional `exampleAnswer`/`images`). Shows `_ValidationResults` widget: green success banner with valid question count, or error list with per-question error messages. (2) **Import** — taps "Import" `_ActionChip` (primary-tinted, enabled only after successful validation) → calls `questionBankService.bulkImport(jsonContent:)` with 60s timeout. Shows `_ImportResults` widget: success count + any server-side errors (partial success supported). On success: fires `onImported` callback. States: `_validated`, `_validQuestionCount`, `_validationErrors`, `_importing`, `_importResult`, `_importError`. Private widgets: `_JsonTextField` (custom monospace text field with dark bg), `_ActionChip` (compact action button with loading state), `_ValidationResults` (success/error display), `_ImportResults` (import outcome display), `_ErrorBanner`. **Dependencies:** `client.dart` (`questionBankService`, `accessToken`), `models/question.dart` (`BulkImportResult`), `models/result.dart`, `ui/theme/app_theme.dart`, `ui/widgets/edu_sheet.dart`. |

**Dependencies:** `client.dart` (`questionBankService`, `accessToken`), `models/result.dart` (`Ok`/`Err`), `models/question.dart` (`RubricCriterion`, `QuestionImage`, `ImageContext`, `BulkImportResult`), `models/permissions.dart`, `models/system_permissions.dart`, `database/daos/catalog_dao.dart`, `ui/theme/app_theme.dart`, `ui/widgets/edu_sheet.dart`, `ui/widgets/edu_confirm_dialog.dart`, `ui/widgets/edu_form_field.dart`.

---

### `notifications/`
| File | Widget | Status | Description |
|---|---|---|---|
| `notifications_section.dart` | `NotificationsSection` | ✅ Complete | Displays failed sync log entries as notifications. Lists all `logs` rows with `status = failed` for the current account, mapped to `AppNotification` display models. Each notification tile now includes **Retry** and **Delete** action buttons (28×28 `IconButton`s per UI guidelines). Retry resets `status` to `pending` and `attempts` to `0` via `LogsDao.retryLog()`, then triggers `sync.schedulePush()`. Delete shows a `showEduConfirmDialog` confirmation and calls `LogsDao.deleteLogAndRevert()` which also reverts optimistic local writes for create actions. Both buttons show inline `CircularProgressIndicator` (16×16, strokeWidth 1.5) while executing and are mutually exclusive (one disables the other during execution). `_NotificationTile` converted from `StatelessWidget` to `StatefulWidget` to manage `_retrying`/`_deleting` state. |
| `notifications_panel.dart` | `NotificationsPanel` | ✅ Complete | Panel/overlay version of the notifications list, used in the dashboard shell for quick access. |

**Data source:** `LogsDao.watchFailedLogs(accountId)` → mapped to `List<AppNotification>`
**Dependencies:** `database/daos/logs_dao.dart`, `models/app_notification.dart` (`AppNotification`), `database/tables/enums.dart` (`SyncAction`), `ui/widgets/edu_confirm_dialog.dart` (`showEduConfirmDialog`)

**Migration note (Task C13):** All three notification widgets were updated to use the action-based `SyncAction` enum instead of the old `LogTable`/`LogOperation` enums. Icon mapping is now by domain group derived from `SyncAction`, and operation badges derive create/update/delete/assign/mark/approve/upload labels from the action name prefix. The old `_OperationBadge` widget was replaced by `_ActionBadge`. The `notification.rowKey` field was replaced by `notification.resource`.

## Permission Gating

System sections check `SystemPermissions` before rendering sensitive actions:

| Action | Required permission |
|---|---|
| View users | `users.read` (auto-granted for system/super_ levels) |
| Promote user to System | `users.update` + target must be `UserLevel.normal` |
| Promote user to Super | `users.update` + `permissions.level == UserLevel.super_` + target must be `UserLevel.system` |
| Demote to Normal | `users.update` + target must be `UserLevel.system` |
| Demote to System | `users.update` + `permissions.level == UserLevel.super_` + target must be `UserLevel.super_` |
| Suspend/restore user | `users.update` |
| Delete user (soft) | `users.delete` |
| Purge user | Only `UserLevel.super_` (`canSeeDeleted`) |
| Suspend/restore/demote member | `users.update` |
| Delete member (soft) | `users.delete` |
| Promote member to Super | Only `UserLevel.super_` + target must be `UserStatus.active` + cannot self-promote |
| Purge member | Only `UserLevel.super_` |
| Activate/suspend/restore school | `schools.update` |
| Delete school (soft) | `schools.delete` |
| Purge school | Only `UserLevel.super_` (`canSeeDeleted`) |
| Create school | `schools.create` |
| Edit role | `roles.update` |
| Delete role | `roles.delete` |
| Purge role | Only `UserLevel.super_` |
| Manage plans | `plans.create`, `plans.update`, `plans.delete` |
| See deleted records | Only `UserLevel.super_` (`SystemPermissions.canSeeDeleted`) |

All action buttons in `users_section.dart`, `members_section.dart`, `schools_section.dart`, `roles_section.dart`, and `plans_section.dart` are now permission-gated. Each section computes `canUpdate` / `canDelete` from `widget.permissions.can(Resource.xxx, Action.yyy)` and conditionally includes row actions. Super-only actions (purge, promote-to-super, demote-from-super) additionally check `widget.permissions.level == UserLevel.super_` or `canSeeDeleted`.

**Privilege escalation guards (A03):**
- `_promoteMember` in `members_section.dart`: blocks self-promotion, requires `UserLevel.super_` to promote to Super, requires target `UserStatus.active`.
- `_promoteUser` in `users_section.dart`: blocks self-promotion, requires `UserLevel.super_` to promote to Super, blocks promoting deleted/suspended users. "Promote to System" row action gated by `users.update` (was incorrectly `users.assign` — `Resource.users` does not include `assign` in its applicable actions per §17a, so the permission could never be granted). "Elevate to Super" and "Demote to System" now use explicit `widget.permissions.level == UserLevel.super_` check instead of `canSeeDeleted` proxy.
- `_canCreateSystemUser` in `invite_user_sheet.dart`: now requires both `isElevated` AND `users.create` permission (was `isElevated` alone).
- `_submit` in `invite_user_sheet.dart`: hard guard blocks Super-level invites unconditionally; blocks System-level invites without `users.create` permission.

For `UserLevel.super_` users, all permissions are granted unconditionally via `SystemPermissions.superUser()`. `UserLevel.system` users now go through role-based permission loading: `_loadPermissions()` calls `usersDao.getSystemPermissions()` and passes the result to `SystemPermissions.forUser()`, which merges level-based defaults with the user's actual system-scoped role permissions.

## Dependencies

- **Depends on:** `models/system_permissions.dart`, `models/system_stats.dart`, `models/app_notification.dart`, `models/plan_features.dart`, `models/authenticated.dart`, `database/daos/` (system_stats_dao, users_dao, schools_dao, roles_dao, plans_dao, logs_dao, members_dao, settings_dao), `database/tables/enums.dart`, `ui/widgets/edu_tab_bar.dart`, `core/extensions.dart`, `client.dart`
- **Depended on by:** `home/home_screen.dart` (navigates to `SystemDashboardScreen` for elevated users)

## Conventions

- All sections receive `SystemPermissions` from the shell — they never compute their own.
- Data is not school-scoped — all queries are system-wide (no `schoolId` filter).
- The notification system reads from the `logs` table directly — it does not depend on the sync engine.
- Permission gating uses `SystemPermissions.can(action)` — never raw `UserLevel` checks in UI code (except `canSeeDeleted` which is level-specific by design).
- **Destructive action confirmations (E03):** All destructive or privilege-changing actions show a `showEduConfirmDialog` before executing. Specifically:
  - `schools_section.dart` `_trashSchool`: dialog now has `isDestructive: true`.
  - `plans_section.dart` `_deletePlan`: added confirmation dialog (`isDestructive: true`) and success snackbar on completion.
- **Subjects permission gate (E04):** `subjects_section.dart` `SubjectsSection.build()` now checks `subjects.read` permission at the top — returns `EduEmptyState` with lock icon when denied. `CreateSubjectSheet` gains optional `SystemPermissions? permissions` parameter; `_submit()` includes a defense-in-depth check for `subjects.create`. `system_dashboard_screen.dart` `_SettingsTabBodyState._showCreateSubject` now passes `widget.permissions` to `CreateSubjectSheet`.
- **Reactive system permissions (D01):** `system_dashboard_screen.dart` `_SystemDashboardScreenState` now mixes in `WidgetsBindingObserver`. After initial `_loadPermissions()` one-shot load, subscribes to `usersDao.watchSystemPermissions(userId)` — a Drift reactive stream that re-emits when any system-scoped scope or role row changes via sync deltas. On change, rebuilds `SystemPermissions` and calls `setState`. Also re-loads permissions on `AppLifecycleState.resumed` via `_reloadPermissionsOnResume()`. New field: `_permissionsSub` (`StreamSubscription<List<RolePermissions>>?`). New import: `dart:async`.

## Last Updated
Task B9 — `users/users_section.dart`: Fixed permission gate inconsistencies. (1) "Promote to System" action now gated by `canUpdate` instead of `canAssign` — `Resource.users` applicable actions are `[read, update, delete]` per §17a, so `users.assign` could never be granted through the role UI, making the button permanently invisible. Removed unused `canAssign` variable. (2) "Elevate to Super" and "Demote to System" actions now use explicit `widget.permissions.level == UserLevel.super_` check instead of `canSeeDeleted` as a proxy for Super-level check. Both express the same condition (`_level == UserLevel.super_`) but the explicit level check is clearer in intent and consistent with `user_detail_sheet.dart`.

Previous: Task B10 — `schools/schools_section.dart`: Gated Purge action behind `school.status == SchoolStatus.deleted` in addition to `widget.permissions.canSeeDeleted`. Previously, the Purge button appeared for every school when the user was Super (including active/trial/suspended schools). Now it only appears for deleted schools, matching the pattern used in the Plans section.

Previous: Task B1 — `roles/`: Extracted shared permission editor helpers (`_buildResourceGroups`, `_ResourceGroup`, `_kBaseActions`, `_kActionColors`, `_kActionIcons`, `_capitalise`) from `create_role_sheet.dart`, `role_detail_screen.dart`, and `role_detail_sheet.dart` into `ui/screens/shared/role_permission_editor.dart`. All three files now use typed `Resource`/`Action` enums from `models/permissions.dart` via the shared `kResourceGroups`, `kActionColors`, `kActionIcons`, and `actionLabel` exports. Removed unused `database/tables/enums.dart` imports from `create_role_sheet.dart` and `role_detail_sheet.dart`. Previous: Task A5 — `members_section.dart`: `AddMemberSheet._promote()` now has a defense-in-depth permission guard checking `widget.permissions.can(Resource.users, Action.update)` at the start; returns early if the caller lacks permission. Previous: Tasks A1, A2 — `user_detail_sheet.dart`: Super-only gate on "Elevate to super" action (Task A1) and self-action guard preventing users from modifying their own level/status (Task A2). Added `viewerId` parameter to `_ViewBody` and `_AccountActionsCard`, threaded from `cache.currentUser?.user.id`. Previous: Tasks F01, F02 — Notification retry/delete action buttons (`_NotificationTile` → StatefulWidget with `_retryLog`/`_deleteLog` methods, confirmation dialog, inline loading states). System stats resilience: replaced nested 6-StreamBuilder pyramid with independent per-card `_IndependentStatCard<T>` StreamBuilders; removed legacy `_StatsErrorCard`/`_CardGridSkeleton`; added `_SingleCardError` and `_SingleCardSkeleton` per-card widgets. Previous: Tasks F11, F12 — Deleted record filtering for non-Super users + dead code cleanup.

**(F11 — Filter deleted records)** `schools_section.dart`: Added pre-filter before `_applyFilters` — when `widget.permissions.canSeeDeleted` is false, `SchoolStatus.deleted` schools are excluded from the list before search/status filters are applied. Non-Super system users no longer see deleted schools in the default list. `users_section.dart`: Same pattern — `UserStatus.deleted` users are excluded from the visible list when `widget.permissions.canSeeDeleted` is false.

**(F12 — Dead code cleanup)** `system_dashboard_screen.dart`: Removed dead `_FabAction.createPlan` enum value and its handler in `_onFabAction` — the value was never dispatched from the FAB builder (plans are created via `openCreatePlan()` called directly from `_SettingsTabBody`). Added documentation comment on `_desktopTabController` explaining why it has no explicit listener (desktop uses `AnimatedBuilder` directly on the controller in `_DesktopBody`).

Previous: Task E05 — Defense-in-depth permission guards for member status-change actions. Previous: Tasks D01, E04 — Reactive system permissions via watch stream + lifecycle observer, subjects permission gate with Read guard and CreateSubjectSheet defense-in-depth. Previous: Task E03 — Added confirmation dialogs for destructive system actions. Previous: Task C01 — Fixed logout not navigating away from System Dashboard.