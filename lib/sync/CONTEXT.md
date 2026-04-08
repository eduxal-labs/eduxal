# sync/ — Sync Engine Context

## Overview

The sync engine is responsible for:
1. **Outbound sync:** Reading the `logs` table and replaying local mutations to the server via gRPC.
2. **Inbound sync:** Receiving server-streaming gRPC deltas and writing them to the local Drift database.
3. **Connectivity monitoring:** Detecting online/offline state and triggering sync when connectivity is restored.

## Current State

All three core sync components are implemented and **integrated into `client.dart`** (Task 06 complete). The `SyncEngine` starts/stops automatically with the active account lifecycle. Services can trigger immediate pushes via the global `sync.pushNow()` getter. The engine exposes a `ValueNotifier<SyncStatus>` for UI consumption via `sync.status`. Comprehensive `debugPrint` statements are placed at every lifecycle transition point for runtime diagnostics.

### Transport Error Resilience

The Dart `http2` package can throw uncaught assertion errors (`ConnectionMessageQueueIn.onTerminated`) during connection teardown when the gRPC server is unreachable. These fire asynchronously in zones that cannot be caught by normal `try/catch`. Two layers of protection are in place:

1. **`main.dart` global zone:** `runZonedGuarded` wraps the entire app, catching any uncaught async errors and logging them via `dart:developer` instead of crashing the isolate.
2. **`_runGuarded()` in `sync_engine.dart`:** A local helper that wraps `_startWatch()` (both initial and reconnect) in `runZonedGuarded` for sync-specific error logging. This catches transport errors closer to their source.
3. **`_ensurePushStream()` try/catch:** The push stream setup has its own `try/catch` — if `pushChanges()` throws synchronously (e.g. channel not connected), the push stream is torn down and `pushNow()` detects `_pushController == null`, logs the failure, sets status to `disconnected`, and returns. Mutations remain in the `logs` table for the next cycle.

### Status Flow

The `SyncStatus` lifecycle is carefully ordered so the UI indicator accurately reflects reality:

- `start()` sets status to **`disconnected`** (not `idle`) — the watch stream is lazy and we don't know if the TCP connection succeeded yet.
- `_startWatch()` attaches the listener but does NOT set `idle` — gRPC stream creation is deferred; the actual connection happens asynchronously.
- **First `_onDelta()` callback** transitions from `disconnected` → `pulling` → `idle` (on flush), confirming the connection is live.
- `pushNow()` only sets `pushing` after confirming `_pushController` is available. If unavailable, sets `disconnected`.
- `_onWatchError` / `_onWatchDone` → `disconnected` + `_scheduleReconnect()`.
- `stop()` → `disconnected`.

### Debug Print Coverage

Every lifecycle transition has a `debugPrint('[SyncEngine] ...')` call:

| Event | Print |
|---|---|
| `start()` | account, lastSeq |
| `_startWatch()` | seq, "waiting for server..." |
| First delta received | "Watch stream connected — first delta received" |
| `_onWatchError` | error details, "will reconnect" |
| `_onWatchDone` | "Watch stream completed", "will reconnect" |
| `_scheduleReconnect` | delay seconds, attempt number |
| Reconnect timer fires | "Reconnect timer fired — reopening watch..." |
| `pushNow` (no batches) | "no pending batches" |
| `pushNow` (sending) | batch count |
| `pushNow` (stream unavailable) | "Push stream not available — staying queued" |
| `_onPushAck` | batch ID, success |
| `_onPushError` | error details |
| `_ensurePushStream` failure | error details |

`client.dart` also prints: gRPC channel target on creation (`$kDomain:$kPort`), `_startSync()` account + target.

## Files

| File | Status | Purpose |
|---|---|---|
| `connectivity.dart` | ✅ Implemented | Monitors device connectivity via `connectivity_plus`. Detects offline→online transitions and fires a callback (wired to `SyncEngine.revive()` in `client.dart`). Debounces rapid flaps (500 ms). |
| `delta_writer.dart` | ✅ Implemented | Receives `SyncDelta` proto messages and writes them directly to the local Drift database, bypassing DAOs to avoid log generation. |
| `log_processor.dart` | ❌ Deleted (Task C8) | Was: batch-based mutation coalescing, FK ordering, invitation pairing. All replaced by action-based model — sync engine now sends actions one-at-a-time directly from `logs` table. |
| `sync_engine.dart` | ✅ Implemented | Top-level orchestrator — coordinates inbound deltas + outbound action replay via bidirectional gRPC streams. Exposes `ValueNotifier<SyncStatus> status` for UI binding. Push side rewritten for action-based model (Task C7). |
| `sync_status.dart` | ✅ Implemented | Defines `SyncStatus` enum: `disconnected`, `idle`, `pushing`, `pulling`. Used by `SyncEngine.status` and the `SyncIndicator` widget. |

## `delta_writer.dart`

**Class:** `DeltaWriter`

**Constructor:** `DeltaWriter(AppDatabase db)`

**Key methods:**
- `Future<void> apply(SyncDelta delta)` — Buffers a single delta; auto-flushes every 100 deltas.
- `Future<void> flush()` — Flushes all buffered deltas to the database in a single transaction.
- `bool get bufferIsEmpty` — Whether the internal buffer is currently empty. Used by `SyncEngine` to determine when a flush just occurred so it can persist the latest sequence number.

**Internal dispatch:** `_applySingle(SyncDelta delta)` switches on `delta.table` (1–30, matching proto oneof field numbers) to route to a per-table handler.

**Table coverage:** All 32 synced backend tables are handled:
- Tables 1–34 mapped to: users(1), schools(2), owners(3), students(4), guardians(5), departments(6), teachers(7), staff(8), terms(9), class_teachers(10), enrollments(11), subjects(12), attendance(13), timetable(14), lessons(15), exams(16), papers(17), grades(18), fees(19), invoices(20), payments(21), announcements(22), mastery(23), aiusage(24), settings(25 — removed, skipped gracefully), roles(26), scopes(27), plans(28), subscriptions(29), discounts(30), subject_catalog(31), topics(32), streams(33), mpesa(34).
- Table 35 (exam_grades) — removed from server schema; delta is received gracefully with a `debugPrint` skip.
- Table 36 (`scheme_pages`) — `_applySchemePages()`. rowKey: `"{school}|{exam}|{subject}|{paper}|{page}"` (paper = empty string when NULL). Nullable-paper handled with delete-then-insert for NULL paper, `ON CONFLICT DO UPDATE` for non-NULL.
- Table 37 (`answer_pages`) — `_applyAnswerPages()`. rowKey: `"{school}|{exam}|{student}|{subject}|{paper}|{page}"` (paper = empty string when NULL). Same nullable-paper strategy as table 36.

**Proto message types:** `SyncDelta.data` is of type `InsertData` (oneof with 30 `*Insert` messages). The old `RowData` / `*Row` types no longer exist. Key differences from old `*Row` messages:
- `*Insert` messages do NOT have `id` (for single-PK tables), `created`, or `updated` fields.
- PKs are derived from `delta.rowKey` (pipe-delimited string).
- Timestamps are synthesized locally via `_now()` → `BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000)` (seconds since epoch).

**PK-from-rowKey pattern:** Every `_apply*` method parses `delta.rowKey` to extract PK values:
- Single-PK tables (users, schools, exams, fees, invoices, payments, announcements, roles, plans): `id = delta.rowKey`
- Composite-PK tables: `k = _parseKey(delta.rowKey)` then index into `k[0]`, `k[1]`, etc.
- The `*Insert` message fields for PK columns (e.g. `OwnerInsert.school`, `OwnerInsert.user`) are redundant with `rowKey` and are NOT used — `rowKey` is the canonical PK source.

**Timestamp strategy:**
- For tables with both `created` and `updated`: both set to `_now()`.
- For tables with only `created` (owners, class_teachers, enrollments, subjects, scopes): only `created` set to `_now()`.
- The local timestamp is an approximation — the server is the source of truth.

**Insert/Update strategy:** Uses `insertOnConflictUpdate()` for tables with non-nullable PKs. For tables with nullable PK columns (`papers`, `grades`, `scopes`), uses raw SQL `INSERT ... ON CONFLICT DO UPDATE` to correctly handle `NULL` in composite primary keys.

**Delete strategy:** Parses `delta.rowKey` (pipe-delimited) into PK components and constructs a typed delete query. For nullable PK deletes, uses raw SQL with `IS NULL` / `= ?` conditionally.

**Critical design constraint:** All writes bypass the DAO layer entirely — they go directly to Drift table references (`_db.into(...)`, `_db.delete(...)`, `_db.customStatement(...)`). This ensures no rows are inserted into the `logs` table from incoming sync deltas.

**Enum conversion:** Proto sends raw integers for enum columns. The delta writer converts them to the corresponding Dart enum types (e.g., `UserLevel.values[row.level]`, `AttendanceStatus.values.firstWhere((e) => e.value == row.status)` for non-zero-indexed enums).

**Permissions encoding:** `RoleInsert.permissions` arrives as `List<int>` (proto bytes) but the Drift `roles.permissions` column is currently `text`. The delta writer decodes bytes via the `_decodePermissions()` helper: tries `utf8.decode` first (restoring the original JSON string the client sent), falls back to `base64Encode` if bytes aren't valid UTF-8. This ensures `parsePermissions()` in `_role_helpers.dart` can always recover the permissions. **BUG-012 fix:** Previously used `base64Encode()` directly, which produced a base64 string that `jsonDecode()` couldn't parse, causing permissions to appear empty after sync.

**Helpers:**
- `_parseKey(String rowKey) → List<String>` — splits pipe-delimited row keys
- `_parseInt(String s) → int` — parses integer PK parts
- `_parseIntNullable(String s) → int?` — handles `"null"` literal for nullable PK parts
- `_parseStringNullable(String s) → String?` — handles `"null"` literal for nullable string PK parts (used by scopes)
- `_now() → BigInt` — returns current time as seconds since Unix epoch; local approximation for server-managed timestamps

**Imports:**
- `dart:convert` (for base64Encode)
- `package:drift/drift.dart`
- `../database/database.dart`
- `../database/tables/curriculum_subjects.dart` (for `MpesaEnv`)
- `../database/tables/enums.dart`
- `../database/tables/mpesa.dart` (for `MpesaCompanion`)
- `../proto/services/sync.pb.dart`

## `log_processor.dart` — ❌ DELETED (Task C8)

This file has been deleted. It contained ~2097 lines of batch-based mutation processing logic that was entirely replaced by the action-based sync model:

- Batch building & coalescing → replaced by one-action-at-a-time push in `sync_engine.dart`
- FK dependency ordering (`kTableInsertPriority`) → no longer needed; each action is self-contained
- Invitation pairing → server handles user lookup/creation from member action payloads
- Column bitmask OR-ing → replaced by proto `*Payload` messages with explicit fields
- Row data reading from local DB → replaced by pre-serialized payload blobs stored in `logs.payload`

No files import `log_processor.dart` — all references were removed in Task C7.

## `sync_engine.dart`

**Class:** `SyncEngine`

**Constructor:** `SyncEngine(ClientChannel channel, AccountsDao accountsDao, LogsDao logsDao)`

**Key public fields:**
- `VoidCallback? onUnauthenticated` — Callback invoked when the server returns `StatusCode.unauthenticated` on either push or watch streams. Set by `client.dart` to trigger token refresh and sync restart. Called after `stop()`. **(Added Task D5)**

**Key public methods:**
- `Future<void> start({required String accountId, required String accessToken, required int lastSeq})` — Starts sync for a specific account. Stops any existing session first. Pushes pending actions, opens watch stream, starts periodic push timer (5s).
- `Future<void> stop()` — Stops sync entirely. Cancels all streams, subscriptions, and timers.
- `Future<bool> pushNow()` — Pushes pending local actions immediately. Returns `true` if at least one action was sent. Safe to call from anywhere (fire-and-forget). No-op if not running or offline.
- `void schedulePush()` — Deferred push (150ms delay) to allow outer Drift transactions to commit before querying the `logs` table. Coalesces multiple calls within the same frame.
- `void revive()` — Called when the app returns from background or regains network. Resets backoff and reconnects immediately if the watch stream is dead; otherwise just triggers a push.
- `bool get isRunning` — Whether the sync engine is currently running.
- `ValueNotifier<SyncStatus> status` — Observable sync status for UI widgets. Starts as `disconnected`. Transitions to `pulling` on first delta, `idle` on flush, `pushing` during active push, `disconnected` on `stop()` / stream error. Does NOT optimistically set `idle` on `start()` or `_startWatch()` — only confirmed activity moves the status.

**Module-level helper:**
- `_runGuarded(void Function() body)` — Wraps `body` in `runZonedGuarded` to catch unhandled async errors from the `http2` transport layer. Used for `_startWatch()` calls (initial + reconnect). Logs caught errors via `dart:developer` with name `'SyncEngine'` and `debugPrint`.

**Inbound (watch) flow:**
1. Opens `SyncClient.watchChanges(WatchRequest(lastSeq: ...))` server-streaming call (wrapped in `_runGuarded` to catch transport teardown errors). Uses a raw-bytes streaming call for better proto parse error diagnostics.
2. Each incoming `SyncDelta` is applied via `DeltaWriter.apply()`. The first delta transitions status from `disconnected` → `pulling` (with a debugPrint confirming connection).
3. After `DeltaWriter.apply()`, if `delta.fileUrls.isNotEmpty`, calls `_handleFileUrls(delta.fileUrls, isPushOriginator: false)` to download files from S3.
4. After `_handleFileUrls`, if `delta.table == 37` (answer_pages) and `delta.operation != 2` (not a delete), calls `_insertAnswerSubmissions(delta)` to populate `paper_submissions` rows so the UI can discover the downloaded answer files immediately.
5. Tracks `_lastSeq` — persists it to `accounts.lastSeq` via `AccountsDao.updateLastSeq()` whenever the DeltaWriter flushes its buffer (checked via `bufferIsEmpty` getter). Status transitions to `idle` on flush.
6. On `GrpcError(StatusCode.unauthenticated)` → stops sync entirely and calls `onUnauthenticated?.call()` so `client.dart` can attempt token refresh and restart sync. **(Updated Task D5)**
7. On other errors or stream completion → sets status to `disconnected`, schedules reconnect with exponential backoff (1s→2s→4s→8s→16s→30s max). All transitions have `debugPrint` for visibility.

**`_insertAnswerSubmissions(SyncDelta delta)`:**
- Called only for `delta.table == 37` (answer_pages) after `_handleFileUrls` has downloaded the file(s).
- Parses `delta.rowKey` (`"{school}|{exam}|{student}|{subject}|{paper}|{page}"`) to extract identity fields.
- For each `FileUrl` entry in `delta.fileUrls`, resolves `fileUrl.path` to an absolute path via `FileCache.baseDir()` and checks that the file actually exists on disk (only inserts if download succeeded).
- Calls `ExamsGradesDao(db).insertSubmission(...)` for each confirmed file. Uses `insertOnConflictUpdate` so re-syncing the same file is idempotent.
- For scheme files (table 36) no hook is needed — the scheme UI uses filesystem directory listing (`_loadSchemeFiles()`) and automatically discovers files at the expected `FileCache.schemeDir(...)` path.
- Errors are caught and printed; a failed hook never aborts the sync stream.

**Outbound (push) flow — REWRITTEN (Task C7):**
The push flow was rewritten from a batch-based model (via `LogProcessor`) to a one-at-a-time action-based model. `LogProcessor` is no longer used.

1. `pushNow()` calls `LogsDao.getPendingLogs(accountId)` to get all pending `LogsData` rows (oldest first).
2. Calls `_pushActions(pending)` which opens a bidirectional gRPC stream via `SyncClient.pushActions()`.
3. Sends the first `ActionRequest` (with `id`, `action` int value, and serialized `payload` bytes from the log row).
4. Waits for the `ActionResponse` from the server.
5. Processes the response via `_processActionResponse()`, then sends the next action.
6. After all actions are acknowledged, closes the stream.

**ActionResponse handling (`_processActionResponse(ActionResponse response, SyncAction? action)`):**
- Accepts the `SyncAction` from the originating log entry (looked up via `actionByLogId` map built in `_pushActions`). **(Updated Task D4)**
- If `response.success` → apply returned `ActionRow` objects to local DB via `_applyActionRow()`, then delete the log entry.
- Error codes:
  - Code 1 (permission_denied): marks log as failed via `LogsDao.markFailed()` (shown in notifications).
  - Code 2 (conflict): applies server's rows to local DB, deletes the log entry.
  - Code 3 (validation_error): marks log as failed (user must fix).
  - Code 4 (not_found): **if `_isDeleteAction(action)` → deletes log (target already gone = success); otherwise marks log as failed.** **(Fixed Task D4)**
  - Default: marks log as failed.
- Note: `ActionResponse` does not carry a `serverSeq` field — seq advances come through the watch stream exclusively.

**`_isDeleteAction(SyncAction action)` helper:** **(Added Task D4)**
- Returns `true` for all 27 delete/remove/unassign actions: `deleteSchool`, `deleteTeacher`, `deleteStaff`, `deleteOwner`, `deleteStudent`, `deleteGuardian`, `deleteDepartment`, `deleteTerm`, `deleteTimetableEntry`, `deleteAttendance`, `deleteLesson`, `deleteExam`, `deletePaper`, `deleteGrade`, `deleteFee`, `deleteInvoice`, `deletePayment`, `deleteAnnouncement`, `deleteRole`, `deleteUser`, `deletePlan`, `deleteSubscription`, `deleteDiscount`, `deleteSubject`, `deleteTopic`, `deleteStream`, `deleteMpesa`, `unenrollStudent`, `unassignClassTeacher`, `unassignSubject`, `unassignRole`.
- Used by error code 4 handler: if the server says "not found" for a delete action, the resource is already gone — treat as success.

**`_applyActionRow(ActionRow row)`:**
- Converts `ActionRow` to a `SyncDelta` (with `seq: Int64.ZERO`, copying `table`, `operation`, `rowKey`, `data`).
- Calls `DeltaWriter.apply()` then immediately `DeltaWriter.flush()` — push response rows are written right away rather than waiting for the buffer to fill.

**Push stream error handling:**
- On `GrpcError(StatusCode.unauthenticated)` during push → stops sync entirely and calls `onUnauthenticated?.call()`. **(Updated Task D5)**
- On other gRPC errors → sets status to `disconnected`, actions remain in logs table for next push cycle.
- Stream controller is always closed in a `finally` block.

**Reconnection:**
- Exponential backoff with `_reconnectAttempts` counter.
- Delay: `min(2^attempts, 30)` seconds.
- Reset to 0 on first successful delta (not on stream open — gRPC stream creation is lazy).
- Uses a `Timer` (`_reconnectTimer`) that is cancelled on `stop()`.

**Logging:** Uses `dart:developer` `dev.log()` with name `'SyncEngine'` for DevTools filtering. Extensive `debugPrint` coverage for each action sent/acknowledged.

**`_handleFileUrls(List<sync_pb.FileUrl> fileUrls, {required bool isPushOriginator})`:**
- Called after `_processActionResponse()` succeeds (code 0 or code 2 conflict) with `isPushOriginator: true`.
- Called after `_deltaWriter.apply(delta)` in `_onDelta()` with `isPushOriginator: false`.
- When `isPushOriginator: true` — this device performed the action and already has the file locally. Calls `FileCache.upload(putUrl, path)` for each entry with a non-empty `putUrl`.
- When `isPushOriginator: false` — this device is a watcher receiving a `SyncDelta`. Calls `FileCache.download(getUrl, path)` for each entry with a non-empty `getUrl`.
- Skips entries with empty `path`, empty `putUrl` (originator path), or empty `getUrl` (watcher path).
- Errors in individual upload/download operations are logged via `debugPrint` but do not throw — a failed file transfer never aborts the sync engine.

**Imports:**
- `dart:async`
- `dart:convert`
- `dart:developer`
- `dart:io` ← **added Tasks C3–C8** (for `File.existsSync()` in `_insertAnswerSubmissions`)
- `dart:math`
- `package:fixnum/fixnum.dart`
- `package:flutter/foundation.dart`
- `package:grpc/grpc.dart`
- `../database/database.dart`
- `../database/daos/accounts_dao.dart`
- `../database/daos/exams_grades_dao.dart` ← **added Tasks C3–C8** (for `_insertAnswerSubmissions`)
- `../database/daos/logs_dao.dart`
- `../proto/services/sync.pb.dart` (as `sync_pb`)
- `../proto/services/sync.pbgrpc.dart`
- `../cache/file_cache.dart`
- `delta_writer.dart`
- `sync_status.dart`

**No longer imports:** `log_processor.dart` (removed in Task C7)

## Design Decisions (from AGENT.md)

- **Logs table is the outbound queue.** Every local action writes a row to `logs` with a `SyncAction` enum, a human-readable `resource` string, and a serialized protobuf `payload` blob. The sync engine reads these and replays them one at a time.
- **Synced log rows are DELETED** — not marked as synced. The table only contains pending/failed work.
- **No coalescing or batching.** Each log row maps 1:1 to an `ActionRequest`. The old batch/coalesce/supersede logic (via `LogProcessor`) has been removed.
- **One-at-a-time push.** Actions are sent sequentially over a bidirectional gRPC stream. The client sends one `ActionRequest`, waits for the `ActionResponse`, processes it, then sends the next.
- **Self-contained payloads.** The `payload` blob in each log row is a serialized proto message (e.g. `CreateSchoolPayload`). The sync engine does NOT read other tables to build the request — the payload is pre-built by the DAO at mutation time.
- **Failed log retry:** Per-action error codes from server: 0=ok (delete log), 1=permission_denied (mark failed), 2=conflict (apply server version, delete log), 3=validation_error (mark failed), 4=not_found (**delete log for delete/unassign actions, mark failed for others** — Task D4).
- **Reactive Unauthorized:** If the server responds with Unauthorized on a push or watch stream, the sync engine stops and calls `onUnauthenticated` — `client.dart` sets this callback to attempt token refresh and restart sync automatically (Task D5).
- **UI independence:** The UI binds only to Drift streams. Drift streams don't care where data came from. A write from user action and a write from sync both trigger the same `Stream<T>` updates.

## Sync-Write vs User-Write Verification (Task 11)

**Verified:** The `DeltaWriter` does NOT trigger any DAO-level log writing. All writes go directly to Drift table references:
- `_db.into(_db.<table>).insertOnConflictUpdate(...)` for standard inserts/updates
- `_db.delete(_db.<table>)..where(...)` for standard deletes
- `_db.customStatement(...)` for tables with nullable PK columns (`papers`, `grades`, `scopes`)

**No DAO imports or DAO method calls exist in `delta_writer.dart`.** The only reference to "DAO" is in the doc comment explaining why DAOs are bypassed.

**Verified:** Drift reactive streams (`watch()` / `watchSingle()`) DO fire when data is written directly via `_db.into(...)`, `_db.delete(...)`, and `_db.customStatement(...)`. Drift's `StreamQueryStore` monitors all statement executions at the database engine level and invalidates active stream queries for affected tables regardless of whether the write came from a DAO method or a raw Drift operation. This is what makes the UI update in real-time when sync deltas arrive.

**Design summary (no infinite loop):**
- **User-initiated mutations** → DAO methods → write to data table + write to `logs` table + `sync.pushNow()`
- **Incoming sync deltas** → `DeltaWriter` → write directly to data table only (no `logs` entry, no DAO call)
- Both paths trigger Drift stream notifications for the affected tables, so the UI updates either way.

## Dependencies

- **Depends on:** `dart:async` (runZonedGuarded, StreamController, Timer), `dart:developer` (dev.log), `package:fixnum` (Int64 — used by log_processor and sync_engine, NOT by delta_writer), `package:flutter/foundation.dart` (debugPrint, ValueNotifier), `package:grpc` (ClientChannel, CallOptions, StatusCode, GrpcError, ResponseStream), `package:connectivity_plus` (Connectivity, ConnectivityResult — used by connectivity.dart), `database/database.dart` (AppDatabase, global `db`), `database/tables/enums.dart` (all enum types + converters), `database/daos/logs_dao.dart` (LogsDao), `database/daos/accounts_dao.dart` (AccountsDao), `proto/services/sync.pb.dart` (SyncDelta, InsertData, UpdateData, MutationBatch, Mutation, PushAck, MutationResult, WatchRequest, FileUrl, all *Insert and *Update messages), `proto/services/sync.pbgrpc.dart` (SyncClient), `sync/sync_status.dart` (SyncStatus enum)
- **Depended on by:** `client.dart` (✅ integrated — `Client.syncEngine` field, `Client._connectivityMonitor` field, `SyncEngine get sync` global getter, start/stop wired into `active()`, `saveAccount()`, `switchAccount()`, `logOut()`; connectivity monitor started in `_startSync()`, stopped in `switchAccount()` and `logOut()`), `ui/widgets/sync_indicator.dart` (binds to `sync.status` ValueNotifier), `main.dart` (global `runZonedGuarded` zone catches unhandled http2 transport errors, `_SyncLifecycleObserver` calls `sync.revive()` on app resume)

## Last Updated
Tasks D4, D5 — Sync engine fixes:
- **D4:** Error code 4 (not_found) now distinguishes delete/unassign actions from update/create actions. Delete actions whose target is already gone server-side are treated as success (log deleted). Other actions are still marked failed. Added `_isDeleteAction(SyncAction)` helper and `SyncAction? action` parameter to `_processActionResponse`. `_pushActions` builds `actionByLogId` map from pending logs to pass action to response handler.
- **D5:** Added `VoidCallback? onUnauthenticated` field. Both push (`_pushActions` catch block) and watch (`_onWatchError`) unauthenticated handlers now call `onUnauthenticated?.call()` after `stop()`. `client.dart` wires this to attempt token refresh via `_refresh()` and restart sync via `_startSync()`.

Previous:
Connectivity monitoring fix (BUG-020 — Sync engine does not react to connectivity changes):
- **New file:** `connectivity.dart` — `ConnectivityMonitor` class using `connectivity_plus: ^6.1.4`. Listens to `Connectivity().onConnectivityChanged` (returns `List<ConnectivityResult>` in v6 API). Tracks `_wasOnline` state to detect offline→online transitions. Debounces rapid flaps with a 500 ms `Timer`. Fires `onOnline` callback on confirmed transition. `start()` does an initial `checkConnectivity()` call (fire-and-forget) to set accurate baseline. `stop()` cancels subscription and debounce timer.
- **Modified:** `client.dart` — Added `import 'sync/connectivity.dart'`. Added `late final ConnectivityMonitor _connectivityMonitor` field to `Client`, initialized in constructor with `onOnline: () => syncEngine.revive()`. `_startSync()` now calls `_connectivityMonitor.start()` after `syncEngine.start()`. `switchAccount()` and `logOut()` call `_connectivityMonitor.stop()` before `syncEngine.stop()`.
- **Modified:** `pubspec.yaml` — Added `connectivity_plus: ^6.1.4` to dependencies.
- **Not modified:** `sync_engine.dart` (already has `revive()` method), `main.dart` (lifecycle observer kept as-is for app-resume case).

Previous: Task 03 (BUG-012 — Permissions data corruption fix):
- `delta_writer.dart`: Added `_decodePermissions(List<int> bytes)` helper method — tries `utf8.decode` first (with `jsonDecode` validation), falls back to `base64Encode`. Changed `_applyRoles` from `permissions: Value(base64Encode(row.permissions))` to `permissions: Value(_decodePermissions(row.permissions))`. This fixes the root cause where base64-encoded permissions were unparseable by `parsePermissions()`.

Previous: Tasks C3–C8 (File Sync — Marking Schemes & Answer Sheets):
- `delta_writer.dart`: Added `case 36: await _applySchemePages(delta)` and `case 37: await _applyAnswerPages(delta)` to `_applySingle` switch. Implemented `_applySchemePages()` and `_applyAnswerPages()` with full nullable-paper handling (delete-then-insert for NULL paper, `ON CONFLICT DO UPDATE SET` for non-NULL).
- `sync_engine.dart`: Added `_insertAnswerSubmissions(SyncDelta delta)` — post-download hook that inserts `paper_submissions` rows after answer sheet files are downloaded via the watch stream. Hook fires in `_onDelta()` after `_handleFileUrls()` when `delta.table == 37 && delta.operation != 2`. Added `dart:io` and `../database/daos/exams_grades_dao.dart` imports.

Previous: Task 1 — Added `_handleFileUrls()` to `SyncEngine`. Called from `_processActionResponse()` (after success/conflict log deletion, `isPushOriginator: true`) and from `_onDelta()` (after `_deltaWriter.apply()`, `isPushOriginator: false`). Added `../cache/file_cache.dart` import.
