# EduXal — Agent Context Document

> **Read this file in full before writing a single line of code.**
> This document is the single source of truth for all architectural decisions, conventions,
> and constraints agreed upon between the project owner and the AI agents working on this codebase.
> It is updated as new decisions are made. If something is not in here, ask the project owner before assuming.

---

## 0. Agent Startup Checklist

**Do these steps in order before touching any task in TASKS.md:**

1. **Read this file (`AGENT.md`) in full.** Every section. Do not skip.
2. **Read `TASKS.md` in full.** Understand the full task list and current state before starting work.
3. **Read `eduxal/schema.sql` in full.** This is the definitive source for all 30 backend table definitions — exact column names, types (`smallint`, `bigint`, `integer`, `text`, `real`, `boolean`), CHECK constraints, FK relationships with ON DELETE/ON UPDATE actions, all 18 triggers, and all indexes. It is **not** summarised anywhere else. You must read it before writing any Drift table definition.
4. **Check the existing project structure** with a directory listing of `eduxal/lib/` to understand what has already been created.
5. **Only then** pick up the first unchecked `[ ]` task in TASKS.md and begin.

> `schema.sql` is located at: `eduxal/schema.sql`
> The file is large. Read it in full. Do not guess column names or types from memory.

---

## 1. Project Overview

EduXal is a **school management application** targeting both mobile (Android/iOS) and desktop (Linux/macOS/Windows).

Core philosophy: **local-first, real-time UI**.

- All data is stored locally in a Drift (SQLite) database on the user's device.
- The UI always reads from the local database — never directly from the network.
- The network layer (gRPC) is responsible only for authentication and syncing the local database with the server.
- The app must be fully functional offline. Any mutations made offline are queued and replayed when connectivity is restored.

---

## 2. Tech Stack

| Concern | Technology |
|---|---|
| Language | Dart / Flutter |
| Local database | Drift 2.x (SQLite) via `drift_flutter` |
| Network | gRPC (`grpc` package ^5.1.0) |
| Serialization | Protocol Buffers (`protobuf` ^6.0.0) |
| Code generation | `drift_dev` + `build_runner` |
| File caching | Device file system via `path_provider` |
| State management | Drift reactive streams (`watch`/`watchSingle`) exposed as `Stream<T>` |

No `flutter_secure_storage`. It has been removed and replaced entirely by the Drift `accounts` table.

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                      UI Layer                        │  ← No business logic here.
│          (lib/ui/screens, lib/ui/widgets)            │     Consumes Stream<T> and Future<Result<T,E>>.
└────────────────────────┬────────────────────────────┘
                         │ Stream<T> / Future<Result<T,E>>
┌────────────────────────▼────────────────────────────┐
│                  Services Layer                      │  ← One file per domain.
│                  (lib/services/)                     │     Orchestrates DB reads/writes + gRPC calls.
└──────────┬──────────────────────────┬───────────────┘
           │                          │
┌──────────▼──────────┐   ┌───────────▼──────────────┐
│   Local DB (Drift)  │   │   Remote (gRPC)           │
│   lib/database/     │   │   lib/proto/ + services   │
│   tables/ + daos/   │   │   (thin gRPC wrappers)    │
└─────────────────────┘   └──────────────────────────-┘
           │
┌──────────▼──────────┐
│   Sync Engine        │  ← lib/sync/
│   Log Processor      │     Reads logs table, replays to server.
└─────────────────────┘
```

### Authentication (online-first)
- Authentication is the **only** online-first flow.
- All auth calls are **unary gRPC** calls.
- On successful auth the result is persisted to the `accounts` Drift table.
- All subsequent app starts read the active account from the local DB.

### Data Sync (gRPC streams)
- Sync uses **server-streaming gRPC** calls (server pushes deltas to client).
- The client also pushes mutations from the `logs` table to the server when online.
- Sync protos do not exist yet — they will be defined by the project owner and provided as generated Dart stubs. The sync engine is built around an interface/placeholder until then.

---

## 4. Folder Structure (Option A — Layer-First)

```
lib/
├── proto/                  # Generated protobuf stubs — do NOT edit manually.
│   ├── services/           # gRPC service clients (e.g. AuthenticationClient)
│   └── types/              # Protobuf message types (User, Verification, etc.)
│
├── database/               # Everything Drift.
│   ├── tables/             # One file per table. Pure Drift table definitions + converters.
│   ├── daos/               # One file per domain group. Typed query + watch methods.
│   └── database.dart       # AppDatabase class. Registers all tables + DAOs.
│
├── models/                 # Pure Dart domain models. No Drift, no proto dependencies.
│   ├── result.dart         # Result<T,E> sealed class (Ok / Err).
│   ├── authenticated.dart  # Authenticated domain model (backed by accounts table row).
│   └── ...                 # Other domain models as needed.
│
├── services/               # Business logic. One file per domain.
│   ├── authentication.dart # Auth flow: login, verify, setup, refresh, logout.
│   ├── sync.dart           # (future) Sync orchestrator.
│   ├── students.dart       # (future) Student CRUD + reactive streams.
│   └── ...
│
├── sync/                   # Sync engine internals.
│   ├── log_processor.dart  # Reads logs table, replays mutations to server.
│   ├── connectivity.dart   # Watches network state, triggers sync.
│   └── ...
│
├── cache/                  # File system image/asset cache manager.
│   └── file_cache.dart     # Download, store, and serve cached files.
│
├── core/                   # Shared utilities with no domain knowledge.
│   ├── constants.dart      # App-wide constants (domain, port, retry limits, etc.)
│   └── extensions.dart     # Dart extension methods.
│
├── ui/                     # UI layer. No business logic permitted here.
│   ├── screens/
│   ├── widgets/
│   └── theme/
│
├── client.dart             # gRPC channel + top-level Client class. Account lifecycle.
└── main.dart               # App entry point.
```

---

## 5. Database Design

### 5.1 Overview

The Drift database contains **all 30 backend schema tables** exactly mirrored from the server SQL schema, plus **2 client-only tables**: `accounts` and `logs`.

The backend schema uses:
- `bigint` (Drift: `int64`) for `DateTime` values — **seconds since Unix epoch**.
- `integer` for `Date` values — **days since Unix epoch**.
- `smallint` (Drift: `int`) for enums — mapped via custom `TypeConverter`.
- `text` for UUIDs and string identifiers.
- `boolean` mapped as `int` (0/1) in SQLite, Drift handles this automatically.
- `real` for monetary/score values.

### 5.2 Enum Mapping Convention

Every `smallint` enum column has a corresponding Dart enum and a Drift `TypeConverter`.

```dart
// Pattern for every enum:
enum UserStatus { invited, active, suspended, deleted }

class UserStatusConverter extends TypeConverter<UserStatus, int> {
  const UserStatusConverter();
  @override UserStatus fromSql(int fromDb) => UserStatus.values[fromDb];
  @override int toSql(UserStatus value) => value.index;
}
```

Enum files live in `lib/database/tables/` alongside the table that first defines them,
or in a shared `lib/database/tables/enums.dart` if used across multiple tables.

### 5.3 Composite Primary Keys

Drift supports composite PKs via `@override Set<Column> get primaryKey => {col1, col2, ...}`.
All composite PKs from the backend schema are reproduced exactly.

### 5.4 Triggers

The backend schema has ~18 triggers. Drift does not generate these from table definitions.
They are applied as raw SQL in the `MigrationStrategy.onCreate` callback inside `AppDatabase`.

### 5.5 Indexes

All backend indexes (unique and performance) are reproduced as raw SQL in `MigrationStrategy.onCreate`.

---

## 6. The `accounts` Table (Client-Only)

This table replaces `flutter_secure_storage` entirely. It stores one row per logged-in user.

```sql
CREATE TABLE accounts (
    id                  TEXT    PRIMARY KEY NOT NULL,  -- user id (from server)
    phone               TEXT    NOT NULL,
    name                TEXT    NOT NULL,
    email               TEXT,
    level               SMALLINT NOT NULL DEFAULT 0,  -- UserLevel enum
    status              SMALLINT NOT NULL DEFAULT 0,  -- UserStatus enum
    access_token        TEXT    NOT NULL,
    refresh_token       TEXT    NOT NULL,
    token_expiry        BIGINT  NOT NULL,              -- ms since epoch
    is_active           INTEGER NOT NULL DEFAULT 0,   -- bool: 0=false, 1=true
    last_synced_at          BIGINT,                    -- null = never synced
    profile_read_url        TEXT,                      -- S3-like read URL (valid ~1 month)
    profile_url_expiry      BIGINT,                    -- ms since epoch when URL expires
    refresh_token_expiry    BIGINT  NOT NULL,          -- ms since epoch: token_created_at + 30 days
    created                 BIGINT  NOT NULL,
    updated                 BIGINT  NOT NULL
);

-- Only one account can be active at a time.
CREATE UNIQUE INDEX uq_accounts_active ON accounts(is_active) WHERE is_active = 1;
```

**Key rules:**
- `is_active = 1` on exactly zero or one rows at all times (enforced by partial unique index).
- `profile_read_url` is the **read** S3 URL only. The write URL from `Authenticated.profile` in the proto is **never stored** (it expires in 1 hour and is only used immediately for upload).
- When `profile_url_expiry` is in the past and the app is online, re-fetch a fresh read URL and update the row.
- `token_expiry` = `created_at + 3 days` (ms since epoch). When `now > token_expiry`, call the `refresh` gRPC endpoint and update `access_token`, `refresh_token`, `token_expiry`, and `refresh_token_expiry` in this table.
- `refresh_token_expiry` = `created_at + 30 days` (ms since epoch). When `now > refresh_token_expiry`, the refresh token is also expired — the user must go through full login again. Return `null` from `active()` to force re-login.
- Reactive expiry (server responds with Unauthorized on stream connection) is handled in the sync engine (Task Group 2), not in `client.dart`.
- Timeline note: the 3-day / 30-day durations are current values. If the backend changes them, update `core/constants.dart` only — no logic changes needed.



---

## 7. The `logs` Table (Client-Only)

This is the **offline mutation queue**. Every local write to a synced table produces one or more log entries. The sync engine reads these and replays them to the server in order.

```sql
CREATE TABLE logs (
    id        INTEGER  PRIMARY KEY AUTOINCREMENT,
    account   TEXT     NOT NULL,      -- FK → accounts.id (mutations are per-account)
    tbl       SMALLINT NOT NULL,      -- LogTable enum: which table was mutated
    op        SMALLINT NOT NULL,      -- LogOperation enum: 0=Insert, 1=Update, 2=Delete
    row_key   TEXT     NOT NULL,      -- "|"-delimited PK values e.g. "schoolId|2024|1"
    columns   INTEGER,                -- Bitset of changed columns (UPDATE only; null for Insert/Delete)
    status    SMALLINT NOT NULL DEFAULT 0, -- LogStatus enum: 0=Pending, 1=Failed
    attempts  SMALLINT NOT NULL DEFAULT 0,
    error     TEXT,                   -- Last error message from server
    created   BIGINT   NOT NULL
);
```

**Key rules:**
- **Synced log rows are DELETED** — they are not marked as synced. The table only contains work yet to be done.
- `status = Failed` rows are kept until the sync engine decides to retry or abandon based on the server error type. Retry logic is **TBD** — the server error will indicate whether the failure is reversible or irreversible.
- The `logs` table only tracks mutations to the **30 synced backend tables**. The `accounts` and `logs` tables themselves are never logged.
- `columns` is a bitmask. Each bit position maps to a column of `tbl` via a per-table Dart enum (see §8).
- For `op = Delete`: `columns` is null. The sync engine just sends the `row_key` as a delete instruction.
- For `op = Insert`: `columns` is null. The sync engine reads the full current row from the local DB and sends it.
- For `op = Update`: `columns` is a bitset. The sync engine ORs all pending bitsets for the same `(tbl, row_key)`, reads the current local values for those columns, and pushes once.
- If a Delete log exists for a `(tbl, row_key)`, it **supersedes** all Insert/Update logs for that same row — the others are deleted from the queue, only the Delete is sent.

### LogTable Enum

```dart
enum LogTable {
  users(0), schools(1), owners(2), students(3), guardians(4),
  departments(5), teachers(6), staff(7), terms(8), classTeachers(9),
  enrollments(10), subjects(11), attendance(12), timetable(13),
  lessons(14), exams(15), papers(16), grades(17), fees(18),
  invoices(19), payments(20), announcements(21), mastery(22),
  aiusage(23), settings(24), roles(25), scopes(26), plans(27),
  subscriptions(28), discounts(29);
  const LogTable(this.value);
  final int value;
}
```

### LogOperation Enum

```dart
enum LogOperation { insert, update, delete }
```

### LogStatus Enum

```dart
enum LogStatus { pending, failed }
```

### Column Bitset Convention

Each synced table has a corresponding `XxxColumn` Dart enum where the enum's value is the **bit position** (0-indexed):

```dart
// Example — students table
enum StudentColumn {
  user(0), name(1), dob(2), gender(3),
  documents(4), admitted(5), status(6), updated(7);
  const StudentColumn(this.bit);
  final int bit;
}

// Setting bits:   mask |= (1 << StudentColumn.name.bit);
// Checking bits:  mask & (1 << StudentColumn.name.bit) != 0
```

No table in the schema has more than 15 columns, so `int` (32-bit in Dart) is sufficient.

---

## 8. File Caching Strategy

**No file paths and no file blobs are stored in the database.**

Files live at **constant, predictable paths** derived from entity identity:

| Entity | Local path |
|---|---|
| User profile image | `{appDir}/users/{userId}/profile` |
| Student image | `{appDir}/schools/{schoolId}/students/{adm}/image` |
| School logo | `{appDir}/schools/{schoolId}/logo` |
| Any other asset | `{appDir}/{entityType}/{id}/{assetName}` |

`{appDir}` is resolved at runtime via `path_provider`'s `getApplicationDocumentsDirectory()`.

**Read URL strategy:**
- The server issues S3-like signed **read URLs** valid for **~1 month**.
- The read URL is stored in the relevant DB column (e.g. `accounts.profile_read_url`).
- `profile_url_expiry` (bigint, ms since epoch) tracks when the URL expires.
- When online and URL is still valid → serve from local file at constant path; re-download only if the file is missing.
- When online and URL has expired → re-fetch a fresh URL from server, update DB, re-download file.
- When offline → serve from local file at constant path regardless of URL expiry.

**Write URLs are never stored.** The proto `Authenticated.profile` field is a PUT-only write URL expiring in 1 hour. It is used immediately for the upload action and then discarded.

---

## 9. The `Result<T, E>` Type

A simple sealed class lives in `lib/models/result.dart`:

```dart
sealed class Result<T, E> {
  const Result();
}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}
```

All service methods return `Future<Result<T, E>>` or `Stream<Result<T, E>>`.
The UI consumes these with a `switch` expression — no raw try/catch in widgets.

---

## 10. The `Authenticated` Domain Model

The proto-generated `Authenticated` class (in `lib/proto/services/authentication.pb.dart`)
is **not** used as a domain model in the app. It is only used as a deserialization target
when receiving responses from the gRPC auth service.

The domain model `Authenticated` lives in `lib/models/authenticated.dart` and is constructed
from a Drift `AccountsData` row (the Drift-generated data class for the `accounts` table).

It exposes:
- User identity fields (`id`, `phone`, `name`, `email`, `level`, `status`)
- Token fields (`accessToken`, `refreshToken`, `tokenExpiry`)
- Sync metadata (`lastSyncedAt`)
- Profile cache fields (`profileReadUrl`, `profileUrlExpiry`)
- A factory `Authenticated.fromRow(AccountsData row)`
- A method `AccountsCompanion toCompanion()` for writing back to Drift

---

### `client.dart` — gRPC Channel and Account Lifecycle

`lib/client.dart` is the top-level entry point for:
1. Establishing the gRPC `ClientChannel`.
2. Managing the active account lifecycle (active, switch, logout, refresh).
3. Holding references to gRPC service wrapper instances (currently only `Authentication`).

**After migration from `flutter_secure_storage`:**
- All account reads/writes go through the Drift `accounts` table via the DAOs.
- The global `accessToken` and `refreshToken` in-memory variables are kept for fast access during a session but are always written through to the DB on change.
- `AppCache` is a simple in-memory store cleared on logout. It caches hot data (e.g. current user) to avoid repeated DB queries.
- There is **no** `Account` gRPC service. The `account` field is removed from `Client` entirely.

**Token expiry logic:**
- `active()` is a pure DB read — no network call is ever made inside it except `_refresh()`.
- The `stale` parameter from the old implementation is removed — it is no longer meaningful.
- On `active()`: if `now > refresh_token_expiry` → return `null` (force full re-login).
- On `active()`: if `now > token_expiry` but refresh token still valid → call `_refresh()` → return result.
- Otherwise → return `Authenticated.fromRow(row)` directly from DB.
- Access token duration: `kAccessTokenDuration = Duration(days: 3)` in `core/constants.dart`.
- Refresh token duration: `kRefreshTokenDuration = Duration(days: 30)` in `core/constants.dart`.

---

## 12. Pending / Undecided Items

These must be resolved before the relevant code is written. Do not guess — ask the project owner.

| # | Item | Blocking what |
|---|---|---|
| P2 | ~~The `Account` gRPC service~~ | ✅ **Closed** — no Account service. `client.dart` never makes a network call in `active()`. All account data comes from the local `accounts` table. |
| P3 | Sync stream proto definitions — server-streaming gRPC for delta sync. Not yet defined. | lib/sync/, entity services — **deferred to Task Group 2** |
| P4 | ~~Token expiry source~~ | ✅ **Closed** — access token: `+3 days`; refresh token: `+30 days`. Constants in `core/constants.dart`. Reactive Unauthorized expiry handled in sync engine. |
| P5 | Failed log retry logic — server error types that distinguish reversible vs irreversible failures. | lib/sync/log_processor.dart |
| P6 | Missing relationship/table — project owner mentioned a table or relationship they could not remember. To be added when recalled. | database schema |

---

## 13. Division of Labour

| Agent | Owns |
|---|---|
| **Claude (Opus)** | Full stack: `lib/database/`, `lib/models/`, `lib/services/`, `lib/sync/`, `lib/cache/`, `lib/core/`, `lib/client.dart`, `lib/ui/` |
| **Project owner** | Backend (gRPC server), proto definitions, architecture decisions |

**Architectural contract (UI ↔ Services):**
- Services expose `Stream<T>` (reactive, from Drift `.watch()`) and `Future<Result<T,E>>`.
- Widgets bind to those streams and futures. No direct DB or gRPC calls in widget code.

---

## 14. gRPC Proto Files — Current State

| File | Status | Notes |
|---|---|---|
| `lib/proto/services/authentication.pbgrpc.dart` | ✅ Generated | login, verify, setup, refresh — all unary |
| `lib/proto/services/authentication.pb.dart` | ✅ Generated | Login, Verify, Verified, Authenticated, Setup, Refresh message types |
| `lib/proto/types/user.pb.dart` | ✅ Generated | User, Update message types; Level and Status enums |
| `lib/proto/types/verification.pb.dart` | ✅ Generated | Verification message type; Purpose enum |
| Account service proto | ❌ Missing | Needed for `account.user()` in client.dart (P2) |
| Sync stream protos | ❌ Missing | Needed for sync engine (P3) |

---

## 15. Known Code Issues in Existing Files

### `lib/client.dart`
- Imports `FlutterSecureStorage` — not in `pubspec.yaml`, must be removed.
- Uses `Authenticated.fromJsonString()` and `Authenticated.fromJson(Map)` — these are custom methods on a domain model that does not exist yet (the proto class has different signatures).
- References `Account` gRPC service wrapper — not yet implemented (blocked by P2).
- References `AppCache` — not yet defined.
- References `Ok`/`Err` — `Result` type not yet defined.
- The `profile` field passed around in `Authenticated(accessToken, refreshToken, value, authenticated.profile)` was the write URL — this is dropped in the new model.

### `lib/services/authentication.dart`
- Completely empty. Needs full implementation.

---

## 16. Sync-Last Strategy

The sync engine (Task Group 2) is deliberately deferred until the UI and local data layer show good progress. This is safe because of the following property:

**The UI binds only to Drift streams. Drift streams do not care where the data came from.**

A write from a local user action and a write from the sync engine both go to the same SQLite tables and both trigger the same `Stream<T>` updates. The UI requires zero changes when sync is plugged in.

### What We Do From Day One Anyway
Even before the sync engine exists, every local mutation writes a row to the `logs` table. The log processor does not exist yet so nothing reads those rows. But they accumulate correctly. When Task Group 2 arrives, the full mutation history is already queued and ready to replay.

### Current Network Boundary
While sync is deferred, the only live network traffic is:
- `authentication.login()` — unary gRPC
- `authentication.verify()` — unary gRPC
- `authentication.setup()` — unary gRPC
- `authentication.refresh()` — unary gRPC (triggered by token expiry only)

Everything else is local SQLite reads/writes.

---

## 17. Navigation Model and Home Screen

### School Context
School context (which school + which role the user is currently viewing) is **navigational state only** — it is never persisted in the `accounts` table or any other DB table. When a user switches accounts or re-opens the app, they land on the home screen and pick a context by tapping a membership card.

### Membership Model
A user can simultaneously hold multiple memberships across different schools and roles. The home screen is a **membership picker** assembled by querying five tables against the current user's id:

| Table | Membership role |
|---|---|
| `owners` | School owner |
| `teachers` | Teacher (includes subject count badge for current term) |
| `staff` | Staff member |
| `students` | Student |
| `guardians` | Guardian (includes the name of the ward student) |

The **subjects badge** on a teacher's membership card = count of subjects in `subjects` table for `(school, currentYear, currentTerm, teacher = userId)`. Only applicable to the teacher role.

### `MembershipRole` Enum
Five values — one per membership table. Used as badge labels on each school card:

```dart
enum MembershipRole { owner, teacher, staff, student, guardian }
```

### `SchoolMembership` — Home Screen Item
One instance per unique school the user belongs to. Lives in `lib/models/membership.dart`:

```dart
// One card on the home screen — one per unique school
class SchoolMembership {
  final SchoolsData school;
  final List<MembershipRole> roles;   // deduplicated — for badge display
  final List<MembershipEntry> entries; // one per navigation target (guardians expand per ward)

  bool get hasSingleEntry => entries.length == 1;
}
```

### `MembershipEntry` — Navigation Entry Points
Each entry is a distinct navigation target shown either directly (single entry) or in a picker dialog (multiple entries). Guardian entries expand one-per-ward so a user who is guardian to two students at the same school gets two distinct entries.

```dart
sealed class MembershipEntry {
  MembershipRole get role;
}

final class OwnerEntry extends MembershipEntry {
  final OwnersData owner;
  @override MembershipRole get role => MembershipRole.owner;
}

final class TeacherEntry extends MembershipEntry {
  final TeachersData teacher;
  final int subjectCount; // badge: subjects in current term
  @override MembershipRole get role => MembershipRole.teacher;
}

final class StaffEntry extends MembershipEntry {
  final StaffData staff;
  @override MembershipRole get role => MembershipRole.staff;
}

final class StudentEntry extends MembershipEntry {
  final StudentsData student;
  @override MembershipRole get role => MembershipRole.student;
}

final class GuardianEntry extends MembershipEntry {
  final GuardiansData guardian;
  final StudentsData ward;        // the specific child
  // ward image at: {appDir}/schools/{schoolId}/students/{adm}/image
  @override MembershipRole get role => MembershipRole.guardian;
}
```

### Tap Behaviour
- **1 entry** → navigate directly to that role's dashboard
- **2+ entries** → show a picker dialog; each entry displays the role name + relevant name/image
  - Teacher: role label
  - Guardian entries: ward's name + ward's cached image (if available)

### DAO Contract (Claude's responsibility)
`lib/database/daos/memberships_dao.dart`:
```dart
Stream<List<SchoolMembership>> watchMemberships(String userId)
```
Single reactive stream assembling all five membership tables + schools. The UI binds to this.

---

## 17. School Dashboard — RBAC and Visibility

### Two-Layer Access Model
When a user enters a school in a specific role, two independent layers determine what they see:

| Layer | Source | Determines |
|---|---|---|
| **Entry role** | Which `MembershipEntry` was tapped | Base page layout (teacher-centric, owner-centric, etc.) |
| **Permissions** | `scopes` + `roles` tables | Which features are visible and actionable within that layout |

A teacher who is also a principal enters as `TeacherEntry` but their scopes carry admin-level permissions, so they see both lesson management pages AND administrative features. The base layout does not hide content — the permissions layer adds to it.

### Permission Aggregation
When entering a school context, Claude's services layer loads and aggregates permissions:

1. Query all `scopes` rows for `(school = schoolId, user = userId)`
2. For each scope, load the linked `roles` row and parse `roles.permissions` (JSON map)
3. Union all permission keys across all roles into one flat `Set<String>`
4. Expose as `SchoolPermissions` model

```dart
// lib/models/school_permissions.dart
class SchoolPermissions {
  final String schoolId;
  final String userId;
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
  bool canAny(List<String> perms) => perms.any(permissions.contains);
  bool canAll(List<String> perms) => perms.every(permissions.contains);
}
```

### Permission Key Format
Permission key names (e.g. `"attendance.record"`, `"students.manage"`, `"fees.view"`) are defined on the **backend** in the `roles.permissions` JSON map. The client treats them as opaque strings. **Alignment on the key taxonomy is required from the project owner before the dashboard feature-gate logic is wired up** — noted as P7 in §14.

---

## 18. School Dashboard — In-Session Role Switching (`SchoolContext`)

### Overview
When a user enters a school, a `SchoolContext` object is created and lives for the duration of that school session. It is disposed when the user navigates back to the home screen. It is **not persisted** — it is pure in-memory navigational state.

### `SchoolContext` Model
Lives in `lib/models/school_context.dart`:

```dart
class SchoolContext {
  final SchoolMembership membership;       // all entries for this school
  final SchoolPermissions permissions;     // aggregated scopes — constant for the session
  final ValueNotifier<MembershipEntry> currentEntry; // drives all reactive UI

  SchoolContext({
    required this.membership,
    required this.permissions,
    required MembershipEntry initialEntry,
  }) : currentEntry = ValueNotifier(initialEntry);

  void switchEntry(MembershipEntry entry) {
    assert(membership.entries.contains(entry));
    currentEntry.value = entry;
  }

  void dispose() => currentEntry.dispose();
}
```

### Key Properties
- `SchoolPermissions` is computed once on entry and never changes during the session — it reflects all the user's scopes at that school regardless of which entry is active.
- `currentEntry` is a `ValueNotifier<MembershipEntry>`. Widgets use `ValueListenableBuilder` to rebuild when it changes.
- Switching entry does NOT trigger a new DB query for permissions — only for entry-specific data streams (e.g. lessons filtered by teacher, grades visible to a guardian's ward).
- The role switcher UI widget reads `context.membership.entries` to build the switcher options and calls `context.switchEntry(entry)` on tap.

### Data Streams and Entry Sensitivity
Some data streams depend on the current entry:

| Stream | Depends on entry? | Why |
|---|---|---|
| Teacher lessons / timetable | Yes — `TeacherEntry` | Queries by `teacher = userId` |
| Guardian ward's attendance/grades | Yes — `GuardianEntry` | Queries by `student = ward.adm` |
| Owner school settings / finances | Yes — `OwnerEntry` | Shows admin-level data |
| School announcements | No | Visible to all roles |
| School-wide student list (if permitted) | No — permission-gated | Driven by `SchoolPermissions` |

Streams that are entry-sensitive accept a `MembershipEntry` parameter. The service layer exposes them as:
```dart
Stream<T> watchXxx(String schoolId, MembershipEntry entry, SchoolPermissions permissions)
```

### `SchoolContext` Lifecycle
- **Created by:** A factory method in the future `SchoolService` (Task Group 3) after loading `SchoolMembership` + computing `SchoolPermissions`.
- **Provided to widgets via:** An `InheritedWidget` or provider.
- **Disposed by:** The navigation layer when popping the school route.

---

## 20. Code Style Conventions

- All service method return types are `Future<Result<T, GrpcError>>` or `Stream<Result<T, GrpcError>>`.
- Drift table files are named in snake_case matching the SQL table name: `students.dart`, `class_teachers.dart`.
- DAO files are named by domain group: `students_dao.dart`, `finance_dao.dart`, `academic_dao.dart`.
- Enum converters are defined in the same file as the table that first uses the enum.
- No raw SQL in service files — all queries go through DAOs.
- `client.dart` is the only file that holds a direct reference to the gRPC `ClientChannel`.
- `AppDatabase` is a singleton accessed via a global instance initialized in `main.dart`.

---

## 21. UI Design Guidelines

- **Aesthetic:** Clean, minimal, thin, and modern UI. Absolutely no heavy, bold, or outdated elements.
- **Typography:** Use thin/light font weights (e.g., `w300` or `w400` for body, `w500` max for headings). Avoid `w600` or `bold` unless strictly necessary for hierarchy.
- **Shapes & Borders:** Rigid, sharp, or very slightly blunted corners. Use `BorderRadius.circular(4)` or `0` for a sharp, modern, boxy look. Absolutely no pill shapes (`24` or `50` radius).
- **Borders:** Prefer thin, crisp borders (1px) over heavy shadows or thick fills.
- **General:** Maximize whitespace. Keep the UI feeling airy, precise, and architectural.