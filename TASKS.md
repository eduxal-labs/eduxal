# EduXal — Task Board

> **Scope of this file:** Task Group 3 — Account Page, System Dashboard Button & System Dashboard Shell.
> Task Group 1 (Foundation) and Task Group 2 (Auth & Home) are complete.
> All 32 Drift tables, DAOs, domain models, auth flow, and home screen are done.
>
> **This file covers:**
> 1. A system dashboard button on the home screen for privileged users.
> 2. A full account/profile page (view, edit name, edit email, change photo, theme, logout).
> 3. A system dashboard shell for system/super users (placeholder until details are provided).
>
> **Legend:**
> - [ ] Not started
> - [~] In progress
> - [x] Done
> - [!] Blocked — see note
>
> **Agent:**
> - **Claude (Opus)** — handles everything: database, models, services, `client.dart`, and all UI.
> - There is no separate UI agent. Claude owns the full stack.

---

## Decisions Locked In for This Task Group

These were agreed in conversation and drive every task below. Do not re-open them.

1. **System dashboard button visibility** is driven by `UserLevel`. The `UserLevel`
   enum has three values:
   ```dart
   enum UserLevel {
     normal,  // 0 — regular user, no system access
     system,  // 1 — system-level admin
     super_,  // 2 — super admin (underscore avoids Dart keyword clash)
   }
   ```
   Only users with `level == UserLevel.system` or `level == UserLevel.super_` see
   the system dashboard button on the home screen.

2. **Tapping the avatar on the home screen navigates to the Account page** — not a
   bottom sheet. The existing bottom sheet account menu (theme, logout, add account)
   is replaced by a full Account page that contains all of that plus profile editing.

3. **Account page capabilities:**
   - View profile image in a larger form (hero-style expand or full-width header).
   - Change profile image (pick + cache locally).
   - Edit display name (local DB write, queued in `logs` for sync).
   - Edit email (local DB write, queued in `logs` for sync).
   - Change phone number — **display-only with a toast/snackbar** explaining that
     phone changes require server verification. No inline editing for phone.
   - Theme toggle (system / light / dark) — same as the existing toggle, now on
     this page instead of the bottom sheet.
   - Log out — same behaviour as the existing bottom sheet logout.
   - Account switcher — list of all local accounts, switch active account.

4. **Profile image upload on the account page** requires a fresh presigned PUT URL.
   Currently the only PUT URL we receive is from the auth flow (`Authenticated.profile`
   / `SetupResult.profileUploadUrl`). There is **no** gRPC endpoint yet to request a
   new PUT URL on demand. Until one is provided by the project owner:
   - The account page can **change the local cached image** (pick + save to
     `{appDir}/users/{userId}/profile`) so the avatar updates everywhere immediately.
   - The actual S3 upload is **deferred** — noted as a blocked item (P8).
   - When the user changes their profile image, a `logs` entry is written so the
     sync engine can handle the upload when the upload-URL endpoint exists.

5. **Name and email edits** are local-first. The user edits, we write to the local
   `users` table immediately, and write a row to `logs` so the sync engine replays
   the mutation to the server when online.

6. **System dashboard** is a placeholder shell for now. The project owner will provide
   detailed requirements before implementation. The shell includes:
   - A scaffold with the system dashboard title and a back button.
   - A placeholder body (empty state or simple message).
   - No real functionality until requirements are provided.

7. **No new gRPC endpoints are required** for this task group. Everything is local DB
   reads/writes plus the file cache. The only network action (profile image upload)
   is blocked on P8.

---

## Task Group 3: Account Page, Dashboard Button & System Dashboard Shell

### 3.1 — Add System Dashboard Button to Home Screen [Claude]

**Goal:** Users with `UserLevel.system` or `UserLevel.super_` see a subtle badge
in the home screen top bar that navigates to the system dashboard.

**Data available (no new DAO work needed):**
```dart
// Already available via cache:
final user = cache.currentUser; // Authenticated?
user.user.level // UserLevel — check against system / super_

// Enum from lib/database/tables/enums.dart:
enum UserLevel { normal, system, super_ }
```

**Design (revised — badge, not button):**
- The badge sits right after the "eduxal" wordmark, before the `Spacer`, like a
  role indicator that happens to be interactive — NOT like an action button.
- Only rendered when `user.user.level == UserLevel.system ||
  user.user.level == UserLevel.super_`.
- For `normal` users, the top bar looks exactly as it does today (wordmark + avatar).
- Badge appearance: a compact pill with `BorderRadius.circular(4)`, thin 0.5px
  border in `cs.primary` at 15% opacity, fill in `cs.primary` at 8% opacity.
  Contains a small `Icons.shield_outlined` (12px) + text label ("system" or
  "super") in `cs.primary` at 70% opacity, fontSize 11, w400. Feels like a
  status tag, not a button. Wrapped in a `GestureDetector` (no splash).
- Tap → navigate to `SystemDashboardScreen` (push, not replace — user can go back).

- [x] In `lib/ui/screens/home/home_screen.dart`, update `_buildTopBar`:
  - Read `cache.currentUser!.user.level`
  - If `system` or `super_` → render a badge `Container` after the wordmark
  - Label shows "super" or "system" based on actual level
  - Tap navigates to `SystemDashboardScreen` with a fade transition
- [x] Import the (not yet created) `SystemDashboardScreen` — use a forward
  declaration or create the placeholder file first (task 3.6)
- [x] Verify the button does NOT appear for `UserLevel.normal` users
- [x] Verify the button appears correctly on both mobile and desktop widths

**Acceptance:** A `system` or `super_` user sees a subtle badge next to the wordmark.
A `normal` user does not. Tapping the badge navigates to the system dashboard placeholder.

---

### 3.2 — Replace Avatar Bottom Sheet with Account Page Navigation [Claude]

**Goal:** Tapping the avatar on the home screen now navigates to a full Account page
instead of opening the bottom sheet menu.

- [x] In `lib/ui/screens/home/home_screen.dart`:
  - Change `_openAccountMenu` to navigate to `AccountScreen` (push, not replace)
  - Remove the entire `showModalBottomSheet` body from `_openAccountMenu`
  - Remove the `_AccountMenuItem` widget class (no longer needed)
  - Remove the `_ThemeToggle` widget class (moves to Account page)
- [x] Create the (initially empty) file at `lib/ui/screens/account/account_screen.dart`
  as a placeholder so the import resolves — task 3.4 implements the full screen

**Acceptance:** Tapping the avatar on the home screen pushes the Account page.
The bottom sheet no longer appears. Back navigation returns to the home screen.

---

### 3.3 — Add `AccountService` Helper Methods [Claude]

**Goal:** Provide the service-layer methods that the Account page needs. All are
local DB operations — no gRPC calls.

**Methods to add to `lib/database/daos/accounts_dao.dart`:**

- [x] `Future<void> updateName(String userId, String name)`:
  - Update `users.name` for the given `userId`
  - Update `users.updated` to `now` (ms since epoch)
  - Write a row to `logs`:
    - `tbl` = `LogTable.users`
    - `op` = `LogOperation.update`
    - `row_key` = `userId`
    - `columns` = bitmask with `UsersColumn.name.bit` set
    - `status` = `LogStatus.pending`
    - `account` = `userId`
    - `created` = `now`

- [x] `Future<void> updateEmail(String userId, String? email)`:
  - Update `users.email` for the given `userId`
  - Update `users.updated` to `now`
  - Write a row to `logs`:
    - `tbl` = `LogTable.users`
    - `op` = `LogOperation.update`
    - `row_key` = `userId`
    - `columns` = bitmask with `UsersColumn.email.bit` set
    - `status` = `LogStatus.pending`
    - `account` = `userId`
    - `created` = `now`

- [!] `Future<void> logProfileImageChange(String userId)`:
  - Does NOT write to any table other than `logs` — the file cache handles
    the actual image storage. This just records the intent to sync.
  - Write a row to `logs`:
    - `tbl` = `LogTable.users`
    - `op` = `LogOperation.update`
    - `row_key` = `userId`
    - `columns` = bitmask — no dedicated `profile` column in `UsersColumn`
      (profile is a file, not a DB column). **Decision needed:** either add
      a `profile` variant to `UsersColumn` or use a sentinel value.
      For now, skip the log entry — the sync engine will handle profile
      images via a dedicated file-sync mechanism (P8). Mark this as `[!]`.

- [x] Ensure `updateTheme` (already exists) is still accessible — it moves
  from the bottom sheet to the account page but the DAO method is unchanged.

**Note on `cache.currentUser` freshness:**
After `updateName` or `updateEmail`, the in-memory `cache.currentUser` becomes
stale. The Account page should either:
- Re-read from `watchActiveAccount()` (preferred — reactive), or
- Manually update `cache.currentUser` after the write.

Recommendation: the Account page should use a `StreamBuilder` on
`accountsDao.watchActiveAccount()` so all fields update reactively.

**Acceptance:** `updateName` and `updateEmail` exist, write to both `users` and
`logs` tables in a single transaction. `updateTheme` is unchanged.

---

### 3.4 — Account Page [Claude]

**Goal:** A full-screen profile and settings page. Aesthetic, spacious, and pleasant.
This is the user's personal space — it should feel calm and well-organised.

**Service contract:**
```dart
// Reactive stream — already implemented in AccountsDao:
Stream<Authenticated?> accountsDao.watchActiveAccount()

// Write methods (task 3.3):
Future<void> accountsDao.updateName(String userId, String name)
Future<void> accountsDao.updateEmail(String userId, String? email)
Future<void> accountsDao.updateTheme(String id, AppThemeMode theme)

// Logout — already implemented:
Future<void> client.logOut()

// All accounts (for switcher):
Future<Map<String, Authenticated>> client.accounts()

// Switch account:
Future<Authenticated?> client.switchAccount(String id)

// File cache:
static Future<File?> FileCache.get(String relativePath)
static String FileCache.profilePath(String userId)

// Image picker (already in pubspec):
ImagePicker().pickImage(source: ImageSource.gallery, ...)
```

**Screen location:** `lib/ui/screens/account/account_screen.dart`

**Layout — overall structure:**
The page is a single scrollable column. No tabs.

```
┌─────────────────────────────────────────┐
│  ← Back                                 │  ← AppBar: transparent, back arrow only
├─────────────────────────────────────────┤
│                                         │
│         ┌───────────┐                   │
│         │  Profile   │                  │  ← Large avatar (radius ~56), tappable
│         │   Image    │                  │     camera badge overlay (same as setup)
│         └───────────┘                   │
│          User Name                      │  ← Title style, centred
│          +254 7xx xxx xxx               │  ← Secondary style, centred
│                                         │
├─────────────────────────────────────────┤
│  Profile Section                        │
│  ┌─────────────────────────────────┐    │
│  │ 👤  Name              John Doe  │→   │  ← Tap to edit (inline or bottom sheet)
│  │ 📧  Email         john@mail.com │→   │  ← Tap to edit
│  │ 📱  Phone        0712 345 678   │    │  ← Tap shows snackbar: "Contact support"
│  └─────────────────────────────────┘    │
│                                         │
├─────────────────────────────────────────┤
│  Preferences Section                    │
│  ┌─────────────────────────────────┐    │
│  │ 🎨  Theme         [sys][☀][🌙] │    │  ← Inline 3-option toggle (same widget)
│  └─────────────────────────────────┘    │
│                                         │
├─────────────────────────────────────────┤
│  Accounts Section                       │
│  ┌─────────────────────────────────┐    │
│  │ 👤  Other Account 1     ✓/     │    │  ← Tap to switch
│  │ 👤  Other Account 2            │    │
│  │ ➕  Add account                 │    │  ← Navigates to LoginScreen
│  └─────────────────────────────────┘    │
│                                         │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │ 🚪  Log out                     │    │  ← Red/destructive style
│  └─────────────────────────────────┘    │
│                                         │
│         App version 1.0.0               │  ← Tiny footer, secondary text
└─────────────────────────────────────────┘
```

- [x] Create `lib/ui/screens/account/account_screen.dart`

- [x] **Profile header area:**
  - Large `UserAvatar` (radius ~56) centred at top
  - Camera badge overlay (green circle with camera icon, bottom-right of avatar)
  - Tap avatar or badge → open `ImagePicker` → on pick:
    - Show picked image immediately in the avatar (same pattern as setup screen)
    - Copy the picked file to `FileCache.profilePath(userId)` using the
      `_cacheLocalImage` pattern from setup screen (copy file to app dir)
    - Do NOT attempt S3 upload (blocked on P8 — no upload URL endpoint)
  - Below avatar: user's name in `titleLarge` style, centred
  - Below name: phone number in `bodyMedium` secondary colour, centred
    - Format phone for display with spaces: `0712 345 678`

- [x] **Profile section — Name edit:**
  - Tapping the name row opens a **bottom sheet** with:
    - A `TextFormField` pre-filled with the current name
    - A "Save" green `ElevatedButton`
    - Validation: ≥ 2 non-whitespace characters
  - On save:
    - Call `accountsDao.updateName(userId, newName)`
    - Dismiss the bottom sheet
    - The `StreamBuilder` on `watchActiveAccount()` picks up the change
      and rebuilds the UI automatically
  - Cancel: dismiss the sheet or tap outside

- [x] **Profile section — Email edit:**
  - Tapping the email row opens a **bottom sheet** with:
    - A `TextFormField` pre-filled with the current email (or empty)
    - A "Save" green `ElevatedButton`
    - Validation: basic email format check (contains `@` and `.`) or empty
      (null email is allowed — user can clear their email)
  - On save:
    - Call `accountsDao.updateEmail(userId, newEmail.isEmpty ? null : newEmail)`
    - Dismiss the bottom sheet
  - Cancel: dismiss the sheet or tap outside

- [x] **Profile section — Phone (display only):**
  - Row shows the phone number with a trailing info icon or no trailing icon
  - Tapping the row shows a `SnackBar`:
    - Message: "Phone number changes require verification. This feature is coming soon."
    - Duration: 4 seconds
    - No action button
  - Row should look slightly different from the editable rows — either no
    chevron arrow, or a lock icon as the trailing widget

- [x] **Preferences section — Theme toggle:**
  - Reuse the same 3-option toggle design (system / light / dark) from the
    old bottom sheet, but now as a row in the preferences section
  - Uses `accountsDao.updateTheme(userId, mode)` — same as before
  - Reactive via the `StreamBuilder` on `watchActiveAccount()`

- [x] **Accounts section:**
  - List all accounts from `client.accounts()` — each showing:
    - `UserAvatar(userId: id, radius: 18)` as leading
    - Name as title
    - Phone as subtitle
    - A green checkmark icon for the active account
  - Tap an inactive account → `client.switchAccount(id)`:
    - On success → rebuild (stream updates automatically)
    - On null → show snackbar "Session expired. Please log in again."
      and navigate to `LoginScreen`
  - "Add account" row at the bottom → navigate to `LoginScreen` (push)

- [x] **Logout button:**
  - Full-width row or button at the bottom of the scroll, separated from
    the accounts section
  - Red/destructive colour for the icon and text
  - On tap → `client.logOut()` → navigate to `LoginScreen` (replace all)

- [x] **App version footer:**
  - Tiny centred text below the logout button: "eduxal v1.0.0"
  - Use `bodySmall` in secondary colour with low opacity
  - Serves as visual bottom padding and branding

- [x] **Desktop layout:**
  - Max-width 520px, centred
  - Sections are `Card` widgets with rounded corners on desktop
  - On mobile, sections use a flat list style (no card wrappers), separated
    by thin dividers or section headers

- [x] **Page uses `StreamBuilder<Authenticated?>`** on
  `accountsDao.watchActiveAccount()` as its primary data source.
  All displayed values (name, email, phone, theme) come from this stream
  so any edit is reflected immediately without manual state management.

- [x] **Entrance animation:** same fade + slide up as other screens

**Acceptance:** Navigating to the account page shows the user's full profile.
Name and email are editable via bottom sheets. Phone tap shows a snackbar.
Theme toggle works reactively. Account switching works. Logout works.
Profile image can be changed locally (avatar updates everywhere).
The page is aesthetic, spacious, and pleasant on both mobile and desktop.

---

### 3.5 — Update `cache.currentUser` on Reactive Stream Changes [Claude]

**Goal:** When the Account page writes to the local DB (name, email, theme), the
`watchActiveAccount()` stream emits a new `Authenticated`. The `cache.currentUser`
in-memory reference must stay in sync so that other screens (home screen top bar,
etc.) don't show stale data.

- [x] In `lib/main.dart` or `lib/client.dart`, subscribe to
  `accountsDao.watchActiveAccount()` and keep `cache.currentUser` updated:
  - Option A: In `initializeClient()`, after creating the client, start a
    persistent subscription:
    ```dart
    accountsDao.watchActiveAccount().listen((auth) {
      cache.currentUser = auth;
    });
    ```
  - Option B: Let each screen that reads `cache.currentUser` use the stream
    directly instead — but this is a larger refactor and not needed now.
  - **Go with Option A** — simple, one line, keeps cache always fresh.

- [x] Verify that after `updateName` is called on the Account page,
  `cache.currentUser!.user.name` reflects the new value on the home screen
  without any manual refresh.

**Acceptance:** Editing the name on the account page → navigating back to home →
the home screen avatar / any name display shows the updated name immediately.

---

### 3.6 — System Dashboard Placeholder Screen [Claude]

**Goal:** A minimal placeholder screen for the system dashboard. No real content
until the project owner provides detailed requirements. Just enough to prove the
navigation works and to have a file in place.

**Screen location:** `lib/ui/screens/system/system_dashboard_screen.dart`

- [x] Create `lib/ui/screens/system/system_dashboard_screen.dart`
- [x] Scaffold with:
  - `AppBar` with back arrow and title "System Dashboard"
  - Body: centred empty state with:
    - An icon (e.g. `Icons.construction_rounded` or `Icons.dashboard_customize_outlined`)
      in a tinted circle (same style as home empty state)
    - Title: "System Dashboard"
    - Subtitle: "Management tools for system administrators."
    - Optionally: a placeholder card or two hinting at future sections
      (e.g. "Schools", "Users", "Plans") — non-functional, just visual
  - No real data queries, no gRPC calls — pure visual placeholder

- [x] Style matches the rest of the app — indigo/green branded, same
  border radii, same typography, same dark mode support

**Acceptance:** Navigating from the home screen dashboard button opens this screen.
Back button returns to home. The screen renders correctly in both light and dark mode.
No errors. No real functionality — just a placeholder.

---

### 3.7 — Wire Navigation [Claude]

**Goal:** All new navigation paths compile and work end-to-end.

- [x] Ensure all new DAO methods from task 3.3 are implemented and
  `flutter analyze` is clean
- [x] Ensure `cache.currentUser` sync from task 3.5 is wired up
- [x] Home screen top bar dashboard button (task 3.1) navigates to
  `SystemDashboardScreen`
- [x] Home screen avatar (task 3.2) navigates to `AccountScreen`
- [x] Account page "Add account" navigates to `LoginScreen`
- [x] Account page "Log out" navigates to `LoginScreen` (replace all)
- [x] Account page back button returns to home screen
- [x] System dashboard back button returns to home screen
- [x] Test full flow: home → account → edit name → back → home shows new name
- [x] Test full flow: home → system dashboard → back → home

**Acceptance:** All navigation paths work without runtime errors. The full cycle
of profile editing, theme switching, and account management works end-to-end.

---

## Execution Order

The tasks have dependencies. Execute in this order:

```
Logic first (unblocks UI):
  3.3 → 3.5

Then UI (3.6 first so the import in 3.1 resolves):
  3.6 → 3.1 → 3.2 → 3.4

Then integration:
  3.7
```

Tasks 3.3 and 3.5 must be done and `flutter analyze` must be clean
before starting UI work. Then build screens in order 3.6 → 3.1 → 3.2 → 3.4.
Task 3.6 is first so the import in 3.1 resolves.

---

## Task Summary

| Task | File(s) | Depends on |
|---|---|---|
| 3.1 — Dashboard button | `lib/ui/screens/home/home_screen.dart` | 3.6 (placeholder screen exists) |
| 3.2 — Replace bottom sheet | `lib/ui/screens/home/home_screen.dart` | 3.4 (account screen exists) |
| 3.3 — DAO helper methods | `lib/database/daos/accounts_dao.dart` | None |
| 3.4 — Account page | `lib/ui/screens/account/account_screen.dart` | 3.3 (DAO methods), 3.5 (cache sync) |
| 3.5 — Cache sync | `lib/client.dart` | 3.3 (DAO methods exist to test) |
| 3.6 — System dashboard placeholder | `lib/ui/screens/system/system_dashboard_screen.dart` | None |
| 3.7 — Wire navigation | All screen files | All of the above |

---

## Pending Task Groups (future TASKS files)

| Group | Covers | Blocked on |
|---|---|---|
| Task Group 4 | System Dashboard — full implementation (school CRUD, user management, plans) | Project owner to provide detailed requirements |
| Task Group 5 | School Dashboard shell + `SchoolService.enterSchool()` + `SchoolContext` | Task Group 3 complete |
| Task Group 6 | Role-specific dashboards (teacher, owner, student, guardian, staff) | Task Group 5 + permission model defined |
| Task Group 7 | Entity screens (students, attendance, grades, fees, etc.) | Task Group 6 + per-screen DAO/service |
| Task Group 8 | Sync engine | Sync proto definitions from backend |
| Task Group 9 | File cache v2 (URL expiry, background refresh, profile upload) | Sync engine + upload URL endpoint |

---

## Blocked Items

| ID | Blocked task | Waiting on |
|---|---|---|
| P3 | Task Group 8 (sync engine) | Sync stream proto definitions from backend |
| P5 | Failed log retry logic | Server error taxonomy from backend |
| P6 | Possibly missing schema table | Project owner to recall and specify |
| P7 | Permission key taxonomy / dashboard feature gates | Task Group 6 design session |
| P8 | Profile image S3 upload from account page | gRPC endpoint to request a fresh presigned PUT URL on demand — currently only available during auth flow. Until this exists, profile image changes are local-only. |
| P9 | System dashboard full implementation | Project owner to provide detailed requirements (school CRUD, user management, plans, subscriptions, etc.) |