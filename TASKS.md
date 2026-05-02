# EduXal Flutter — Sync Invite User Task List

## Status Legend
- [ ] Pending
- [x] Complete

---

## Contract Assumption

This client task list is paired with `../ledger/TASKS.md` and assumes the server is adding a new standalone sync action for inviting a user with the payload:
- `id`
- `phone`
- `name`
- `level`

The standalone invite contract intentionally drops the old create-via-update workaround.

### Backward-compatibility goal
Already-failed queued `updateUser` invite attempts must work after the app upgrades:
1. Upgrade the stored log rows in the local database.
2. Reset failed invite-shaped rows back to `pending` so sync replays them automatically.
3. Keep genuine user updates on `updateUser`.
4. Remove redundant standalone invite logs from school-owner flows that already embed invite data in their parent action payloads.

---

## Dependency Graph

```text
01 → 02
01 → 03
03 → 04
01 → 05
02 + 03 + 04 + 05 → 06
```

---

### Task 01: Land the new standalone invite wire contract locally
**Files to create/modify:** `generate.sh`, `lib/proto/services/sync.pb.dart`, `lib/proto/services/sync.pbgrpc.dart`, `lib/proto/services/sync.pbjson.dart`, `lib/proto/services/sync.pbenum.dart`, `lib/database/tables/enums.dart`, `lib/proto/CONTEXT.md`, `lib/database/tables/CONTEXT.md`
**Reference files to read:** `../ledger/protos/services/sync.proto`, `../ledger/src/db/database/tables/actions.rs`
**Depends on:** nothing
**Parallel group:** sequential

**Specification:**
- Pull the exact standalone invite payload from `../ledger/protos/services/sync.proto` and regenerate the Dart stubs with `./generate.sh`.
- Add the new action to `lib/database/tables/enums.dart` using the exact server integer value.
- The server task list reserves `95` for the new action; keep all current action numbers stable.
- Do **not** renumber or reorder any existing action values because the `logs` table stores raw action integers on disk.
- Keep `SyncAction.updateUser` and `SyncAction.deleteUser` unchanged for real update/delete flows.
- Update `lib/proto/CONTEXT.md` and `lib/database/tables/CONTEXT.md` so they mention:
  - the new standalone invite payload
  - the new standalone invite action
  - the fact that action integers are persisted and must remain append-only

**Update after completion:**
- [x] Update `lib/proto/CONTEXT.md`
- [x] Update `lib/database/tables/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 02: Migrate legacy invite-shaped `updateUser` logs and auto-replay failed ones
**Files to create/modify:** `lib/database/database.dart`, `lib/database/CONTEXT.md`, `lib/database/daos/CONTEXT.md`, `BUG.md`
**Reference files to read:** `lib/database/database.dart`, `lib/database/CONTEXT.md`, `lib/database/daos/CONTEXT.md`, `lib/database/tables/enums.dart`, `lib/proto/services/sync.pb.dart`
**Depends on:** Task 01
**Parallel group:** P1

**Specification:**
- Bump the Drift schema version from `11` to `12`.
- Add a one-time migration that rewrites legacy standalone-invite logs which were incorrectly stored as `SyncAction.updateUser`.
- Implement the rewrite in Dart, not SQL, because the payload is protobuf bytes.
- Run the migration during database open/upgrade before sync processing starts.
- Rewrite only rows matching the legacy standalone-invite shape:
  - `action == SyncAction.updateUser`
  - payload decodes as `UpdateUserPayload`
  - `id` is present
  - `phone` is present
  - `name` is present
  - `level` is present
  - `status == invited`
- For matching rows:
  - rebuild the payload using the new standalone invite message
  - keep only `id`, `phone`, `name`, `level`
  - drop legacy `email` because the new server contract does not use it
  - replace the stored action with the new standalone invite action
- For matching rows currently marked `failed`, reset them so they replay automatically after upgrade:
  - `status = pending`
  - `error = NULL`
  - `attempts = 0`
- Also rewrite matching rows already in `pending` so the first post-upgrade push uses the right contract.
- Leave genuine user updates untouched. In particular, do **not** rewrite logs produced by:
  - `UsersDao.updateUserDetails()`
  - `UsersDao.updateUserStatus()`
  - `UsersDao.setUserLevel()`
  - `UsersDao.bulkUpdateStatus()`
  - `UsersDao.bulkUpdateLevel()`
  - `AccountsDao.updateName()`
  - `AccountsDao.updateEmail()`
  - `AccountsDao.deleteUserAccount()`
  - any profile-image or other non-invite `updateUser` intents
- Factor the migration logic into a helper that can be tested without needing a full historical database file.
- Append a `BUG.md` entry describing:
  - the old create-via-update bug
  - why invites got stuck as failed logs
  - how version `12` rewrites and replays them automatically

**Update after completion:**
- [x] Update `lib/database/CONTEXT.md`
- [x] Update `lib/database/daos/CONTEXT.md`
- [x] Append a new entry to `BUG.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 03: Rewire the standalone invite DAO and invite-user UI to the new contract
**Files to create/modify:** `lib/database/daos/users_dao.dart`, `lib/ui/screens/system/users/invite_user_sheet.dart`, `lib/database/daos/CONTEXT.md`, `lib/ui/screens/system/CONTEXT.md`
**Reference files to read:** `../ledger/TASKS.md`, `lib/database/daos/users_dao.dart`, `lib/ui/screens/system/users/invite_user_sheet.dart`
**Depends on:** Task 01
**Parallel group:** P1

**Specification:**
- Update `UsersDao.inviteUser()` so it still does the local-first two-step behavior inside one transaction:
  1. insert the optimistic local `users` row
  2. insert the matching `logs` row
- Replace the old `SyncAction.updateUser` workaround with the new standalone invite action and payload.
- The queued payload for standalone invites must contain only:
  - `id`
  - `phone`
  - `name`
  - `level`
- Remove the old inline comments that describe standalone user creation as an “upsert via update” workaround.
- Update `invite_user_sheet.dart` so the form and submit path match the new contract.
- If the sheet currently collects email for standalone invites, remove that field from this sheet or stop serializing it entirely; the standalone server contract is `name + phone + level` only.
- Mirror the final server invite-level rules from `../ledger/TASKS.md`:
  - system creators with `Users.Create` may invite `System` users only
  - only super creators may invite `Normal` or `Super` through the standalone invite action
  - keep normal-user invites in school/member side-effect flows, not this standalone screen
- Preserve the existing optimistic local row behavior so the invited user still appears locally before sync completes.

**Update after completion:**
- [x] Update `lib/database/daos/CONTEXT.md`
- [x] Update `lib/ui/screens/system/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 04: Remove redundant standalone invite logs from school-owner flows
**Files to create/modify:** `lib/ui/screens/system/schools/create_school_sheet.dart`, `lib/ui/screens/system/schools/school_detail_screen.dart`, `lib/ui/screens/system/CONTEXT.md`
**Reference files to read:** `lib/ui/screens/system/schools/create_school_sheet.dart`, `lib/ui/screens/system/schools/school_detail_screen.dart`, `lib/database/daos/users_dao.dart`
**Depends on:** Task 03
**Parallel group:** P2

**Specification:**
- Audit all call sites of `usersDao.inviteUser()`.
- Keep the standalone invite screen in `system/users` using the new standalone invite action from Task 03.
- Remove the extra `usersDao.inviteUser()` calls from these school-owner flows:
  - `create_school_sheet.dart`
  - `school_detail_screen.dart`
- Reason: both parent sync actions already carry owner invite data:
  - `CreateSchoolPayload` includes owner identity fields
  - `CreateOwnerPayload` includes owner invite fields
- The client should not queue a separate standalone user invite for those flows anymore.
- After this change:
  - creating a school should queue only the school action
  - linking an owner should queue only the owner action
  - the pushed action’s `ActionResponse.rows` should be trusted to upsert the owner’s user row locally
- If those screens currently rely on the standalone invite log for optimistic UI, replace that with local form state or rely on the parent action’s optimistic row handling instead of a second sync log.
- Update any stale comments in those files so they no longer describe school-owner creation as a standalone user invite followed by a second action.

**Update after completion:**
- [x] Update `lib/ui/screens/system/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 05: Update revert, notification, and authorization mappings for the new invite action
**Files to create/modify:** `lib/database/daos/logs_dao.dart`, `lib/models/app_notification.dart`, `lib/ui/screens/system/notifications/notifications_section.dart`, `lib/ui/screens/system/notifications/notifications_panel.dart`, `lib/ui/screens/notifications/notifications_page.dart`, `lib/services/authorization_service.dart`, `lib/models/CONTEXT.md`, `lib/ui/screens/CONTEXT.md`, `lib/ui/screens/system/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Reference files to read:** `lib/database/daos/logs_dao.dart`, `lib/models/app_notification.dart`, `lib/services/authorization_service.dart`
**Depends on:** Task 01
**Parallel group:** P1

**Specification:**
- In `LogsDao.deleteLogAndRevert()` / `_revertCreate(...)`, add explicit support for the new standalone invite action.
- When a failed standalone invite log is discarded by the user, remove the optimistic local invited `users` row for that log.
- Keep the delete narrow enough to avoid deleting unrelated established user rows.
- Update notification title/icon/badge mappings for the new action in:
  - `AppNotification`
  - system notification widgets
  - general notifications page
- Do not rely only on `action.name.startsWith('create')`; add an explicit branch if the final action name is `inviteUser`.
- Update `AuthorizationService` so the new action is classified exactly like the server:
  - `Resource.users`
  - `Action.create`
  - `Organisation.system`
- Keep existing `updateUser` authorization behavior untouched for real updates.

**Update after completion:**
- [x] Update `lib/models/CONTEXT.md`
- [x] Update `lib/ui/screens/CONTEXT.md`
- [x] Update `lib/ui/screens/system/CONTEXT.md`
- [x] Update `lib/database/daos/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 06: Add regression tests for queue migration, new invite queueing, and owner-flow cleanup
**Files to create/modify:** `test/database_test.dart` or a new focused file such as `test/user_invite_sync_test.dart`
**Reference files to read:** `lib/database/database.dart`, `lib/database/daos/users_dao.dart`, `lib/database/daos/logs_dao.dart`
**Depends on:** Task 02, Task 03, Task 04, Task 05
**Parallel group:** sequential

**Specification:**
- Add Drift/integration-style tests covering both the forward path and the upgrade path.
- Minimum coverage required:
  1. `UsersDao.inviteUser()` writes the new standalone invite action and payload.
  2. The optimistic local `users` row is still inserted before sync.
  3. A legacy invite-shaped `updateUser` log in `pending` is rewritten to the new action.
  4. A legacy invite-shaped `updateUser` log in `failed` is rewritten and reset to `pending` with cleared error/attempts.
  5. A genuine user-update log is **not** rewritten.
  6. Discarding a failed standalone invite log removes the optimistic local invited user row.
  7. The school-creation flow no longer queues a separate standalone invite log.
  8. The school-owner-link flow no longer queues a separate standalone invite log.
- If the migration helper is otherwise difficult to test through the full database upgrade path, expose it through a small internal helper and test that helper directly.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Notes for the executor
- The server action integers are not generated from proto; they are maintained manually on both sides.
- Persisted `logs.action` values are on-disk compatibility data. Treat the enum as append-only.
- The upgrade path matters more than fresh installs for this change because existing users already have failed invite logs stuck in local storage.
