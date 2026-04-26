# EduXal — Agent Context Document

> **Read this file in full before writing a single line of code.**
> This document is the single source of truth for all architectural decisions, conventions,
> and constraints agreed upon between the project owner and the AI agents working on this codebase.
> It is updated as new decisions are made. If something is not in here, ask the project owner before assuming.

---

## 0. Three-Agent Workflow

This project uses three distinct agent roles that share this `AGENT.md` as their common rule book.

### 0a. Examiner Agent

**Trigger:** The user describes a feature, change, bug fix, or any non-trivial request in conversational language.

**Responsibilities:**
1. Read `AGENT.md` in full.
2. Read `BUG.md` in full to understand previously fixed bugs and avoid regressions.
3. Read all relevant `CONTEXT.md` files in `lib/` and its subdirectories to understand current project state.
4. Read actual source files as needed — use sub-agents (spawned threads) in parallel or sequentially to gather as much detail as possible about the affected areas.
5. Read `schema.sql` if the work touches the database layer.
6. Ask the user as many clarifying questions as needed — do not guess.
7. Research the codebase thoroughly: understand current implementations, identify patterns, find bugs, map dependencies.
8. Produce a **comprehensive, detailed task list** organized into tracks with dependency annotations, and **write it into `TASKS.md`**.
9. Each task MUST be **self-sufficient** for the executor — see §0c below.
10. Annotate which tasks can run in parallel and which have blocking dependencies.

**The examiner never writes application code.** It only researches and writes tasks. It is the "brain" that transforms user intent into actionable engineering specifications.

### 0b. Orchestrator Agent

**Trigger:** The user says simple words like "continue", "go ahead", "next", or similar — when `TASKS.md` has unchecked tasks.

**Responsibilities:**
1. Read `AGENT.md` in full.
2. Read `BUG.md` in full.
3. Read `TASKS.md` — scan all unchecked `[ ]` tasks.
4. Identify which tasks can be executed **in parallel** (no dependencies between them) and which must be **sequential** (blocking dependencies).
5. For parallel-eligible tasks: spawn multiple executor sub-agents simultaneously, assigning each to different files/directories to avoid conflicts.
6. For sequential/blocking tasks: execute them one at a time in dependency order.
7. **Context window awareness:** The orchestrator's context window is ~140K tokens. Before starting a task or batch, estimate whether there is enough remaining context. If the orchestrator believes the context window may fill up, it MUST stop and notify the human: _"Context window nearing capacity. Please start a new session to continue from Task XX."_ — do NOT attempt a task that might be cut off.
8. After each task (or parallel batch) completes, verify the task is marked `[x]` and the relevant `CONTEXT.md` files are updated.
9. After each task or batch, trigger a git commit with a descriptive message for the changes made.
10. Verify that each executor committed its changes. If an executor failed to commit, the orchestrator runs the commit on its behalf.
11. If the task list is now empty (all done), delete all content from `TASKS.md` except the header.

**The orchestrator never writes application code directly.** It delegates to executor agents and manages the execution flow.

### 0b-i. Orchestrator Commit Convention

After every completed task (or parallel batch), the orchestrator runs:
```
git add -A && git commit -m "<type>: <description>"
```
Where `<type>` is one of: `feat`, `fix`, `refactor`, `ui`, `docs`, `chore`, `db`, `test`.

### 0c. Executor Agent

**Trigger:** Spawned by the orchestrator (as a sub-agent) to execute a specific task.

**Responsibilities:**
1. Read `AGENT.md` in full (or receive relevant sections from orchestrator).
2. Read `BUG.md` in full to avoid reverting previously fixed bugs.
3. The task specification (from `TASKS.md`) should contain everything needed. If clarification is needed, read the `CONTEXT.md` file(s) referenced in the task. Avoid exploring the broader codebase.
4. Execute the task exactly as specified.
5. **Update the relevant `CONTEXT.md` file(s)** to reflect what changed — new files, modified exports, new methods, changed status. This is mandatory. The next executor session depends on fresh context.
6. Mark the task as `[x]` in `TASKS.md`.
7. **Commit immediately** after completing the task. Run `git add -A && git commit -m "<type>: <description>"`. Do NOT defer commits to the orchestrator — every executor commits its own work.
8. Report completion (or failure with details) back to the orchestrator.

**The executor never invents new tasks or architectural decisions.** It executes what the examiner wrote and the orchestrator dispatched.

### 0d. Self-Sufficient Task Format

Every task in `TASKS.md` must follow this structure so the executor can work without exploration:

```
### Task XX: <Title>
**Files to create/modify:** `lib/path/to/file.dart`, `lib/path/to/other.dart`
**Context files to read (if needed):** `lib/layer/CONTEXT.md`
**Depends on:** Task YY (if any)
**Parallel group:** P1 (tasks sharing a group ID can run in parallel)

**Specification:**
Exact description: what to create, exact method signatures, exact types,
exact imports, exact return types. If the executor needs content from another
file, the examiner INLINES it here rather than saying "go look at X".

**Update after completion:**
- [ ] Update `lib/layer/CONTEXT.md` — add/modify entries for changed files
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task
```

The examiner should inline all necessary type definitions, method signatures, and code patterns that the executor will need. The goal is zero filesystem exploration by the executor.

### 0e. CONTEXT.md Files

Each significant directory in `lib/` has a `CONTEXT.md` file that serves as a living inventory of that layer. These files:
- Are **created and maintained by the executor** as the final step of every task.
- Are **read by the orchestrator** when building new tasks.
- Are **read by the executor** only when a task explicitly references them.
- Contain: file listings, status, key exports/types, dependencies, and conventions specific to that layer.

See the existing `CONTEXT.md` files for the standard format. Every `CONTEXT.md` must include a `## Last Updated` line noting which task last modified it.

> **Schema reference:** `schema.sql` is located at `eduxal/schema.sql`. It defines the backend tables, triggers, and indexes. Read it when working on database layer tasks. Note: schema v2 adds `subjects`, `topics`, `streams`, `mpesa` and removes `settings`. The old `subjects` table is renamed to `subject_teachers`. Schema v3 removes `exam_grades` — grade/stream moved to `papers`.

### 0f. BUG.md — Bug Regression Prevention

`BUG.md` is located at the project root (`eduxal/BUG.md`). It is a living log of all bugs encountered and their fixes. Its purpose is to prevent regression — when a bug is fixed, its root cause and solution are recorded so that no future agent accidentally reintroduces the same issue.

**Rules:**
- **Every agent (Examiner, Orchestrator, Executor)** MUST read `BUG.md` before starting any work.
- When a bug is fixed, the executor MUST append an entry to `BUG.md` with: bug ID, title, root cause, files changed, and the fix applied.
- Before writing code that touches a file listed in a `BUG.md` entry, the agent MUST review that entry to ensure the fix is preserved.
- If an agent's changes would revert a previously fixed bug, the agent MUST stop and flag the conflict to the orchestrator/user.
- `BUG.md` is append-only — entries are never deleted or modified after creation (except to add cross-references).

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

### Data Sync (action-based gRPC streams)
- **Push:** The client sends pending actions one at a time via `pushActions` (bidirectional gRPC stream). Each `ActionRequest` contains a `SyncAction` enum and the corresponding protobuf payload. The server responds with `ActionResponse` for each action before the client sends the next.
- **Watch:** The server pushes deltas to the client via `watchChanges` (server-streaming gRPC). The client applies `SyncDelta` messages to local Drift tables via `DeltaWriter`.
- Sync protos are fully defined and generated. See §14 for current proto file state.

---

## 4. Folder Structure (Option A — Layer-First)

```
lib/
├── proto/                  # Generated protobuf stubs — do NOT edit manually.
│   ├── services/           # gRPC service clients (e.g. AuthenticationClient, SyncClient)
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
│   ├── sync_engine.dart    # Orchestrates push (pushActions) + watch (watchChanges) streams.
│   ├── delta_writer.dart   # Applies incoming SyncDelta messages to local Drift tables.
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

The Drift database contains **33 synced backend schema tables** exactly mirrored from the server SQL schema, plus **2 client-only tables**: `accounts` and `logs`.

Schema v2 changes (applied in task group C):
- **Removed:** `settings` table (school config now handled separately)
- **Renamed:** old `subjects` table (subject-teacher assignments) → `subject_teachers`
- **New global catalog tables:** `subjects` (id, name, curriculum), `topics` (subject subdivisions by grade)
- **New per-school tables:** `streams` (named stream definitions), `mpesa` (Daraja API config)

Schema v3 changes:
- **Removed:** `exam_grades` junction table (grade/stream participation now tracked directly on `papers`)
- **Modified:** `papers` table gains `grade` (smallint, NOT NULL) and `stream` (text, nullable) columns

The `logs` table uses an **action-based model**: each row stores a `SyncAction` enum value and a serialized protobuf payload (`blob`). The payload is self-contained — the sync engine does NOT read other tables to build the push message. See §7 for full details.

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

This is the **offline action queue**. Every local mutation produces one log entry containing the action type and a self-contained protobuf payload. The sync engine reads these and replays them to the server one at a time.

```sql
CREATE TABLE logs (
    id        INTEGER  PRIMARY KEY AUTOINCREMENT,
    account   TEXT     NOT NULL,      -- FK → accounts.id (actions are per-account)
    action    SMALLINT NOT NULL,      -- SyncAction enum (95 values, 91 active + 4 deprecated; see §7a)
    resource  TEXT     NOT NULL,      -- Human-readable display key (school name, user phone, etc.)
    payload   BLOB     NOT NULL,      -- Serialized protobuf action message (self-contained)
    status    SMALLINT NOT NULL DEFAULT 0, -- LogStatus enum: 0=Pending, 1=Failed
    attempts  SMALLINT NOT NULL DEFAULT 0,
    error     TEXT,                   -- Human-readable error message from server
    created   BIGINT   NOT NULL       -- ms since epoch
);
```

**Key rules:**
- **Synced log rows are DELETED** — they are not marked as synced. The table only contains work yet to be done.
- `status = Failed` rows are kept and shown in the notifications UI. The sync engine retries with exponential backoff (1s→2s→4s→8s→30s max, 5 attempts max before permanent failure).
- The `logs` table only tracks mutations to the **34 synced backend tables**. The `accounts` and `logs` tables themselves are never logged.
- The `payload` is a protobuf-serialized action message (e.g. `CreateSchoolPayload`, `UpdateTeacherPayload`) captured at action time. The sync engine does NOT read other tables to build the push message — the payload is self-contained.
- The `resource` field is for display only (notifications UI) — it is not used for data lookup or deduplication.
- Actions are sent **sequentially in creation order** (by `id`). The client waits for the server's ack before sending the next action.

### LogStatus Enum

```dart
enum LogStatus { pending, failed }
```

### Error Handling

Server responses include per-action error codes:
- `0` (ok) → delete log row
- `1` (permission_denied) → mark failed, show in notifications
- `2` (conflict) → apply server version, delete log
- `3` (validation_error) → mark failed, user must fix
- `4` (not_found) → mark failed for updates, delete for deletes

---

## 7a. The `SyncAction` Enum (95 Values — 91 Active)

Each value represents a single, self-contained operation that the client can push to the server. Values are fixed — do not reorder or renumber. Defined in `lib/database/tables/enums.dart`.

```dart
enum SyncAction {
  // Schools
  createSchool(0), updateSchool(1), deleteSchool(2),
  // Teachers (invitation pattern)
  createTeacher(3), updateTeacher(4), deleteTeacher(5),
  // Staff (invitation pattern)
  createStaff(6), updateStaff(7), deleteStaff(8),
  // Owners (invitation pattern)
  createOwner(9), deleteOwner(10),
  // Students
  createStudent(11), updateStudent(12), deleteStudent(13),
  enrollStudent(14), unenrollStudent(15),
  // Guardians (invitation pattern)
  createGuardian(16), updateGuardian(17), deleteGuardian(18),
  // Departments
  createDepartment(19), updateDepartment(20), deleteDepartment(21),
  // Terms
  createTerm(22), updateTerm(23), deleteTerm(24),
  // Classes (class_teachers, subject_teachers, timetable)
  assignClassTeacher(25), unassignClassTeacher(26),
  assignSubject(27), unassignSubject(28),
  createTimetableEntry(29), updateTimetableEntry(30), deleteTimetableEntry(31),
  // Attendance
  markAttendance(32), deleteAttendance(33),
  // Lessons
  createLesson(34), deleteLesson(35),
  // Exams
  createExam(36), updateExam(37), deleteExam(38),
  createPaper(39), updatePaper(40), deletePaper(41),
  // Grades
  markGrades(42), updateGrade(43), deleteGrade(44), updateMastery(45),
  // Fees
  createFee(46), updateFee(47), deleteFee(48),
  createInvoice(49), updateInvoice(50), deleteInvoice(51),
  // Payments
  createPayment(52), updatePayment(53), deletePayment(54), approvePayment(55),
  // Announcements
  createAnnouncement(56), updateAnnouncement(57), deleteAnnouncement(58),
  // Roles
  createRole(59), updateRole(60), deleteRole(61),
  assignRole(62), unassignRole(63),
  // Users
  updateUser(64), deleteUser(65),
  // Settings — DEPRECATED (table removed in schema v2; value retained for wire compat)
  @Deprecated('Settings table removed in schema v2')
  updateSettings(66),
  // Plans
  createPlan(67), updatePlan(68), deletePlan(69),
  // AI
  updateAiUsage(70),
  // Subscriptions
  createSubscription(71), updateSubscription(72), deleteSubscription(73),
  // Discounts
  createDiscount(74), updateDiscount(75), deleteDiscount(76),
  // Subjects (global catalog — System/Super only)
  createSubject(77), updateSubject(78), deleteSubject(79),
  // Topics (global catalog — System/Super only)
  createTopic(80), updateTopic(81), deleteTopic(82),
  // Streams (per-school)
  createStream(83), updateStream(84), deleteStream(85),
  // M-Pesa (per-school)
  createMpesa(86), updateMpesa(87), deleteMpesa(88),
  // Exam Grades — DEPRECATED (exam_grades table removed in schema v3; values retained for wire compat)
  @Deprecated('exam_grades table removed in schema v3 — grade/stream moved to papers')
  addExamGrade(89),
  @Deprecated('exam_grades table removed in schema v3 — grade/stream moved to papers')
  removeExamGrade(90),
  // Scheme pages (marking scheme file sync)
  uploadScheme(91),
  deleteScheme(92),
  // Answer pages (student answer sheet file sync)
  uploadAnswerSheet(93),
  deleteAnswerSheet(94);

  const SyncAction(this.value);
  final int value;
}
```

### Action-Based Push Flow

1. User performs action → client writes to local DB immediately (optimistic)
2. Client logs the action → stores `SyncAction` + full protobuf payload in `logs` table
3. Sync engine sends action → when online, sends one `ActionRequest` at a time via bidirectional gRPC stream
4. Server validates permissions, executes action in single transaction, returns `ActionResponse`
5. Client applies server response → updates local DB with server's authoritative data, deletes log row (or marks failed)
6. Client sends next action

**No batching, no FK ordering, no coalescing.** Each action is atomic and self-contained. The server handles all FK dependencies internally within a single transaction. Invitation flows (e.g. `CreateTeacher` with a new phone) are single actions — the server creates the user + member atomically.

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
| P3 | ~~Sync stream proto definitions~~ | ✅ **Closed** — Sync protocol fully specified. Action-based model: `PushActions` (bidirectional stream — client sends `ActionRequest` one at a time, server returns `ActionResponse`) and `WatchChanges` (server→client, server-streaming). 77 action types with per-action `*Payload` messages. Sequence-based change tracking via `server_logs` table on backend. Client tracks `last_seq` in `accounts.lastSeq` column. |
| P4 | ~~Token expiry source~~ | ✅ **Closed** — access token: `+3 days`; refresh token: `+30 days`. Constants in `core/constants.dart`. Reactive Unauthorized expiry handled in sync engine. |
| P5 | ~~Failed log retry logic~~ | ✅ **Closed** — Per-action error codes from server: 0=ok (delete log), 1=permission_denied (mark failed, show in notifications), 2=conflict (apply server version, delete log), 3=validation_error (mark failed, user must fix), 4=not_found (mark failed for updates, delete for deletes). Exponential backoff: 1s→2s→4s→8s→30s max. Max 5 retry attempts before permanent failure. |
| P6 | ~~Missing relationship/table~~ — project owner mentioned a table or relationship they could not remember. | ✅ **Closed** — Owner does not recall at this time. Not blocking any current work. Will be reopened if/when the owner remembers. |
| P7 | ~~Permission key taxonomy~~ | ✅ **Closed** — Permissions use a structured Resource/Action bitmask model (not JSON string keys). 19 logical Resources and 9 Actions defined in §17a below. `roles.permissions` column changes from `text` to `blob` (binary bitmask). The client represents this as `Permissions` class with `Map<Resource, int>` where `int` is a u16 action bitmask. See §17a for full Resource/Action tables. |
| P8 | ~~Curriculum focus~~ | ✅ **Closed** — Only PP1 & PP2 (CBC level index 0) are removed. All other CBC levels (1–6) and all 8-4-4 levels (0–3) remain available. Demo pitch focuses on secondary (Senior Secondary CBC + Forms 3-4) but the app supports all remaining levels for schools that need them. |
| P9 | ~~File sync via S3~~ | ✅ **Closed** — Files (profile images, school logos, student photos) sync via the same push/watch streams as data. Client logs a data action on the parent record (users/students/schools). Server detects file-bearing records and returns presigned PUT URLs in `ActionResponse.file_urls`. Client uploads to S3 via PUT URL. Server notifies other clients via `SyncDelta.file_urls` with GET URLs. No separate file sync endpoint or new log columns needed. `FileUrl` proto message carries `path`, `put_url`, `get_url`, `expiry`. |

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
| `lib/proto/services/sync.pbgrpc.dart` | ✅ Generated | `SyncClient` with `pushActions` (bidirectional streaming: client sends `ActionRequest`, server returns `ActionResponse`) and `watchChanges` (server-streaming). |
| `lib/proto/services/sync.pb.dart` | ✅ Generated | `ActionRequest` (action enum + oneof payload with 91 `*Payload` messages — includes new `CreateSubjectPayload`, `UpdateSubjectPayload`, `DeleteSubjectPayload`, `CreateTopicPayload`, `UpdateTopicPayload`, `DeleteTopicPayload`, `CreateStreamPayload`, `UpdateStreamPayload`, `DeleteStreamPayload`, `CreateMpesaPayload`, `UpdateMpesaPayload`, `DeleteMpesaPayload`; `AddExamGradePayload` and `RemoveExamGradePayload` retained for wire compat but deprecated; `UpdateSettingsPayload` retained for wire compat but deprecated), `ActionResponse` (success/failure + `ActionRow` with server data), `WatchRequest`, `SyncDelta` (with `InsertData data`), `FileUrl`, `InsertData` (oneof, 34 `*Insert` messages — includes new `SubjectInsert`, `TopicInsert`, `StreamInsert`, `MpesaInsert`; `ExamGradeInsert` removed (field 35 reserved); `PaperInsert`/`CreatePaperPayload`/`UpdatePaperPayload` now include `grade` and `stream` fields; old `SubjectsInsert` renamed to `SubjectTeacherInsert`; `SettingsInsert` removed), `AttendanceRecord`, `GradeRecord` helper messages. |
| `lib/proto/types/user.pb.dart` | ✅ Generated | User, Update message types; Level and Status enums |
| `lib/proto/types/verification.pb.dart` | ✅ Generated | Verification message type; Purpose enum |
| `lib/proto/types/role.pb.dart` | ✅ Generated | Resource enum, Action enum, Permission message, Role message, Assignment message. |
| `lib/proto/types/member.pb.dart` | ✅ Generated | Role enum, Membership message. |

---

## 15. Known Code Issues in Existing Files

All previously tracked issues (I1, I2) have been resolved by the action-based sync redesign (Tasks C1–C17). `log_processor.dart` has been deleted. `delta_writer.dart` and `sync_engine.dart` compile cleanly.

No known code issues at this time.

---

## 16. Sync Strategy

**The UI binds only to Drift streams. Drift streams do not care where the data came from.**

A write from a local user action and a write from the sync engine both go to the same SQLite tables and both trigger the same `Stream<T>` updates. The UI requires zero changes when sync is plugged in.

### Sync Engine Architecture (`lib/sync/`)
- `sync_engine.dart` — orchestrates push (via `pushActions` bidirectional stream) and watch (via `watchChanges` server-streaming). Sends actions one at a time in creation order, waits for ack before sending next.
- `delta_writer.dart` — applies incoming `SyncDelta` messages from the watch stream to the local Drift tables.
- `connectivity.dart` — watches network state, triggers sync.

### Current Network Boundary
The only live network traffic is:
- `authentication.login()` — unary gRPC
- `authentication.verify()` — unary gRPC
- `authentication.setup()` — unary gRPC
- `authentication.refresh()` — unary gRPC (triggered by token expiry only)
- `sync.pushActions()` — bidirectional gRPC stream (when online, sends pending log entries)
- `sync.watchChanges()` — server-streaming gRPC (receives deltas from server)

Everything else is local SQLite reads/writes.

---

## 16b. Keeping `AuthorizationService` in Sync With the Server

The client-side `AuthorizationService` (`lib/services/authorization_service.dart`) replicates
the server's `action_permission()` and `action_organisation()` logic. When a new `SyncAction`
is added, ALL of the following must be updated in the same commit:

1. **Server** — add to `action_permission()` and `execute_action()` in `src/db/database/tables/actions.rs`
2. **`lib/database/tables/enums.dart`** — add new `SyncAction` enum value with the next integer
3. **`AuthorizationService._actionPermission()`** — add the `(Resource, Action)` mapping entry
4. **`AuthorizationService._resolveOrganisation()`** — add to `systemActions` set if system-level,
   or add a DB-lookup branch if school must be derived from a related record
5. **The relevant DAO mutation method** — add `authorization.check(...)` call at the top

The binary permissions format (`roles.permissions` blob) is defined in
`src/types/role/permissions.rs` on the server. If Resource IDs or the encoding format ever
change, update `lib/models/permissions.dart` simultaneously.

---

## 16a. User Invitation & Member Creation Rules

### Overview

When a school admin adds a member (teacher, staff, owner, guardian), the client sends a **single action** (e.g. `CreateTeacher`, `CreateOwner`) containing the member data plus the user's phone and name. The server handles user lookup/creation atomically within that action — the client does NOT send a separate user creation action.

Locally, the client creates both a `users` row (`status = Invited`) and the member row optimistically. Both writes happen in a single Drift transaction but produce only **one log entry** (the member creation action). The action payload contains all data the server needs.

### User Creation Permissions

Not all users are allowed to create users freely. The rules are:

| Creator Level | Can Create Normal (Invited) | Can Create System (Invited) | Can Create Super (Invited) |
|---|---|---|---|
| Normal | ✅ Only as side effect of member creation | ❌ | ❌ |
| System (with `Users.Create`) | ✅ | ✅ | ❌ |
| System (without `Users.Create`) | ✅ Only as side effect of member creation | ❌ | ❌ |
| Super | ✅ | ✅ | ✅ |

**All created users start as `status = Invited`** regardless of who creates them. The server rejects any user Insert with `status != Invited`.

For Normal invited users, the permission gate is on the **member table** (`Teachers.Create`, `Staff.Create`, `Owners.Create`, etc.), NOT on `Users.Create`. The user creation is a side effect.

### Phone Conflict Resolution (Server-Side)

When two school admins (both offline) invite the same phone number, the second push hits a `UNIQUE(phone)` constraint. The server resolves this automatically:

1. Server receives `CreateTeacher` (or similar) action with phone `x`
2. Server finds existing user by phone → links member to existing user
3. Server returns: existing user row + member row with corrected user ID
4. Client reconciles:
   - The local optimistic user (ID = `i`) was wrong
   - Update local records to reference the server's user (ID = `u`)
   - Delete the orphaned local user `i`
5. Server streams `SyncDelta { op: Delete, table: users, row_key: "orphaned_id" }` to all clients

This reconciliation happens in the sync engine's response handler, not in the DAO layer.

### Member Tables That Trigger Invitation Flow

All five member tables follow the same pattern:
- `owners` — school owner
- `teachers` — teacher at school
- `staff` — staff member at school
- `students` — student (may be a minor without a phone — TBD)
- `guardians` — parent/guardian of a student

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

## 17a. Resource & Action Design

### Design Principles

1. **Resources are logical domain entities**, NOT a 1:1 mapping to the 30 database tables. Join/junction tables are absorbed as actions on their parent resource.
2. **Actions expand beyond CRUD.** Relationship operations like Assign, Revoke, Enroll become actions, not separate resources.
3. **Actions apply bidirectionally.** "Assign a teacher to a subject" = "assign a subject to a teacher" — same join operation.
4. **Not every action applies to every resource.** The UI shows only relevant actions per resource. The bitmask uses the same bit positions globally.
5. **Members are split** into separate resources (Owners, Teachers, Staff) — a role that can add teachers should not automatically be able to add owners.

### Action Enum (u16 bitmask)

| Action | Bit | Value | Description |
|---|---|---|---|
| Create | 0 | 1 | Create a new record |
| Read | 1 | 2 | View records |
| Update | 2 | 4 | Modify existing records |
| Delete | 3 | 8 | Soft-delete / deactivate |
| Purge | 4 | 16 | Permanent delete (Super-only, never shown in UI) |
| Assign | 5 | 32 | Add a relationship (enroll student, assign teacher to subject, assign role to user) |
| Unassign | 6 | 64 | Remove a relationship |
| Mark | 7 | 128 | Record data (attendance, scores) |
| Approve | 8 | 256 | Approve/verify (payments, workflows) |

Bits 9-15 are reserved for future expansion.

### Resource Enum (19 logical resources)

| # | Resource | Covers tables | Notable non-CRUD actions |
|---|---|---|---|
| 1 | Users | `users` | Level/status changes |
| 2 | Schools | `schools` | |
| 3 | Owners | `owners` | |
| 4 | Teachers | `teachers` | |
| 5 | Staff | `staff` | |
| 6 | Students | `students`, `guardians` | Assign (enroll → `enrollments`), Unassign (unenroll) |
| 7 | Departments | `departments` | |
| 8 | Classes | `class_teachers`, `subject_teachers`, `timetable` | Assign (teacher→subject, teacher→class, timetable entry), Unassign |
| 9 | Attendance | `attendance` | Mark |
| 10 | Lessons | `lessons` | |
| 11 | Exams | `exams`, `papers` | |
| 12 | Grades | `grades`, `mastery` | Mark |
| 13 | Fees | `fees`, `invoices` | |
| 14 | Payments | `payments` | Approve |
| 15 | Announcements | `announcements` | |
| 16 | Roles | `roles`, `scopes` | Assign (role→user), Unassign (revoke) |
| 17 | Plans | `plans`, `subscriptions`, `discounts` | |
| 18 | AI | `aiusage` | |
| 19 | Subjects | `subjects`, `topics`, `streams`, `mpesa` | System/Super-only catalog + per-school config |

### Permissions Storage Format

`roles.permissions` column is `blob` (NOT `text`). Binary encoding: 3 bytes per non-empty resource: `[resource_id: u8, actions_lo: u8, actions_hi: u8]` (little-endian u16). Empty resources are skipped. Max size: 54 bytes.

### Client Representation

```dart
// lib/models/permissions.dart
enum Resource { users, schools, owners, teachers, staff, students, departments, classes, attendance, lessons, exams, grades, fees, payments, announcements, roles, plans, ai, subjects }

enum Action { create, read, update, delete, purge, assign, unassign, mark, approve }

class Permissions {
  final Map<Resource, int> _map;  // Resource → u16 action bitmask

  bool can(Resource resource, Action action) {
    final mask = _map[resource] ?? 0;
    return mask & (1 << action.index) != 0;
  }
}
```

### Action Context Per Resource (UI Display)

| Resource | Shown Actions |
|---|---|
| Users | Read, Update, Delete |
| Schools | Create, Read, Update, Delete |
| Owners | Create, Read, Delete |
| Teachers | Create, Read, Update, Delete |
| Staff | Create, Read, Update, Delete |
| Students | Create, Read, Update, Delete, Assign, Unassign |
| Departments | Create, Read, Update, Delete |
| Classes | Create, Read, Update, Delete, Assign, Unassign |
| Attendance | Read, Mark |
| Lessons | Create, Read, Update, Delete |
| Exams | Create, Read, Update, Delete |
| Grades | Read, Mark, Update, Delete |
| Fees | Create, Read, Update, Delete |
| Payments | Create, Read, Update, Delete, Approve |
| Announcements | Create, Read, Update, Delete |
| Roles | Create, Read, Update, Delete, Assign, Unassign |
| Plans | Create, Read, Update, Delete |
| AI | Read, Update |
| Subjects | Create, Read, Update, Delete |

### Three-Tier Permission Model

| Level | Behavior |
|---|---|
| **Super (2)** | Bypass all checks. See everything, write anything. Only level that can Purge or see deleted records. |
| **System (1)** | Globally scoped but role-gated. Permissions from system-scoped roles (`scopes.school IS NULL`). Can also be school members — system + school roles merge. NOT full access. |
| **Normal (0)** | Membership-based. Only sees schools where they are a member. Permissions from school-scoped roles. |

**Important:** The client code must NOT treat System users as Super users. Only `UserLevel.super_` bypasses permission checks. System users have their roles parsed and permissions enforced.

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
2. For each scope, load the linked `roles` row and parse `roles.permissions` (binary blob → `Permissions` object)
3. Union all permissions across all roles using bitmask OR per resource
4. Expose as `SchoolPermissions` model

```dart
// lib/models/school_permissions.dart
class SchoolPermissions {
  final String schoolId;
  final String userId;
  final Permissions permissions;  // from lib/models/permissions.dart

  bool can(Resource resource, Action action) => permissions.can(resource, action);
  bool canAny(Resource resource, List<Action> actions) => actions.any((a) => permissions.can(resource, a));
  bool canAll(Resource resource, List<Action> actions) => actions.every((a) => permissions.can(resource, a));
}
```

### Permission Key Format
Permissions use a structured **Resource/Action bitmask** model. See §17a for the full Resource and Action enums. The `roles.permissions` column stores a binary blob, not JSON. The client decodes it into a `Permissions` object with typed `Resource` and `Action` enums.

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

### Aesthetic
Clean, minimal, and modern. No heavy, bold, or outdated elements. The gold-standard reference widget is `lib/ui/widgets/create_term_modal.dart` (`_CreateTermDialog`).

### Typography
- Body text: `w300` or `w400`.
- Headings / labels: `w500` max.
- Never use `w600` or `FontWeight.bold` unless strictly required for critical hierarchy.

### Border Radius
Three tiers — all codified as constants in `AppTheme`:

| Token | Value | Use |
|---|---|---|
| `AppTheme.kModalRadius` | `12.0` | Modal/dialog containers, bottom sheets |
| `AppTheme.kCardRadius` | `8.0` | Cards, inputs, buttons |
| `AppTheme.kChipRadius` | `4.0` | Chips, badges, small tags |

Never use `0` (too sharp) or `≥ 20` (pill-shaped) for general UI elements.

### Elevation & Shadows
Use the dual box-shadow pattern (`AppTheme.modalShadow(isDark)`) for all dialogs and sheets:
- Large diffuse shadow: `blurRadius 24/40`, `offset (0, 10)`, low alpha.
- Small tight shadow: `blurRadius 6`, `offset (0, 2)`, very low alpha.

No heavy drop shadows on cards or list rows. Use subtle color shifts (surface staircase) to separate layers.

### Spacing & Density
- Internal padding: `12–16 px`.
- Gap between items: `6–8 px`.
- Never use `20–32 px` internal padding — that feels bloated.

### Icon Buttons Over Text Buttons
- Prefer `IconButton` (28×28 or 36×36) with tooltips over full-text action buttons.
- Standard iconography: save → green check, delete → red trash (`Icons.delete_outline_rounded`), edit → pencil.

### Action Button Animations
Every mutation button must have visible feedback:
- **Press:** Scale `0.95 → 1.0`, `100 ms`.
- **Success:** Brief checkmark flash (`300 ms` elastic out) or color pulse.
- **Loading:** `16×16` `CircularProgressIndicator(strokeWidth: 1.5)`.
- Use the `AnimatedSaveButton` pattern as the standard.

### Back Button
Always use `Icons.chevron_left_rounded` (size `22–24`). Never `Icons.arrow_back` or any `arrow_back_*` variant.

### Dark Mode Colors
All contextual dark-mode colors are exposed as static helpers on `AppTheme`:

| Helper | Dark value | Light value |
|---|---|---|
| `AppTheme.modalBg(isDark, cs)` | `Color(0xFF18222E)` | `cs.surface` |
| `AppTheme.nestedBg(isDark, cs)` | `Color(0xFF1A2536)` | `cs.surfaceContainerHighest` |
| `AppTheme.overlayBg(isDark, cs)` | `Color(0xFF1E2A3A)` | `cs.surface` |
| `AppTheme.borderColor(isDark, cs)` | `Color(0xFF2A3848)` | `cs.outlineVariant @ 0.6` |

### Data Table List Style
All list views use the data-table pattern (not card-based lists):
- Items separated by `AppTheme.tableRowDivider(isDark, cs)` — `0.5 px` thin divider.
- Row height: `48–56 px` standard; up to `64 px` with subtitle.
- Hover highlight: `cs.primary.withValues(alpha: 0.04)` via `InkWell`.
- No per-item card/elevation — rows flow on a continuous surface.
- **Desktop (≥ 600 px):** Inline icon action buttons, `28×28`.
- **Mobile (< 600 px):** Single `Icons.more_vert` (18 px) opens a bottom sheet with action rows.
- Reference implementation: `_GradeSpreadsheet` in `paper_detail_page.dart`.