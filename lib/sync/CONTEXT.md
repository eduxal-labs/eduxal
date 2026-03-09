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
| `delta_writer.dart` | ✅ Implemented | Receives `SyncDelta` proto messages and writes them directly to the local Drift database, bypassing DAOs to avoid log generation. |
| `log_processor.dart` | ✅ Implemented | Reads `logs` table, coalesces mutations, builds `MutationBatch` proto messages for pushing to server. |
| `sync_engine.dart` | ✅ Implemented | Top-level orchestrator — coordinates inbound deltas + outbound log replay via bidirectional gRPC streams. Exposes `ValueNotifier<SyncStatus> status` for UI binding. |
| `sync_status.dart` | ✅ Implemented | Defines `SyncStatus` enum: `disconnected`, `idle`, `pushing`, `pulling`. Used by `SyncEngine.status` and the `SyncIndicator` widget. |

## `delta_writer.dart`

**Class:** `DeltaWriter`

**Constructor:** `DeltaWriter(AppDatabase db)`

**Key methods:**
- `Future<void> apply(SyncDelta delta)` — Buffers a single delta; auto-flushes every 100 deltas.
- `Future<void> flush()` — Flushes all buffered deltas to the database in a single transaction.
- `bool get bufferIsEmpty` — Whether the internal buffer is currently empty. Used by `SyncEngine` to determine when a flush just occurred so it can persist the latest sequence number.

**Internal dispatch:** `_applySingle(SyncDelta delta)` switches on `delta.table` (1–30, matching proto oneof field numbers) to route to a per-table handler.

**Table coverage:** All 30 synced backend tables are handled:
- Tables 1–30 mapped to: users(1), schools(2), owners(3), students(4), guardians(5), departments(6), teachers(7), staff(8), terms(9), class_teachers(10), enrollments(11), subjects(12), attendance(13), timetable(14), lessons(15), exams(16), papers(17), grades(18), fees(19), invoices(20), payments(21), announcements(22), mastery(23), aiusage(24), settings(25), roles(26), scopes(27), plans(28), subscriptions(29), discounts(30).

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

**Permissions encoding:** `RoleInsert.permissions` arrives as `List<int>` (proto bytes) but the Drift `roles.permissions` column is currently `text`. The delta writer encodes bytes as base64 via `base64Encode()`.

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
- `../database/tables/enums.dart`
- `../proto/services/sync.pb.dart`

## `log_processor.dart`

**Class:** `LogProcessor`

**Constructor:** `LogProcessor(AppDatabase db, LogsDao logsDao)`

**Key public methods:**
- `Future<List<MutationBatch>> buildBatches(String accountId, {int batchSize = 50})` — Reads all pending logs for an account, coalesces mutations for the same `(tbl, rowKey)`, reads current row data from the local DB, detects invitation pairs, and splits into `MutationBatch` proto messages respecting invitation-grouping constraints.
- `List<int> logIdsForBatch(String batchId)` — Returns the log row IDs associated with a batch (for per-mutation error handling).
- `Future<void> acknowledgeBatch(String batchId)` — Deletes all log rows for a successfully acknowledged batch.
- `Future<void> markFailed(int logId, String error)` — Marks a single log entry as failed with an error message.
- `Future<void> markBatchFailed(String batchId, String error)` — Marks all log entries in a batch as failed.
- `void clearBatch(String batchId)` — Removes internal tracking for a batch without touching DB rows.

**Coalescing logic (in `buildBatches`):**
1. Groups pending logs by `(tbl, rowKey)`.
2. If any entry in a group is a Delete → discard all others, emit one Delete mutation (no row data needed).
3. If the first entry is an Insert (with optional subsequent Updates) → merge into a single Insert, read the full current row from the local DB.
4. If all entries are Updates → OR all `columns` bitmasks together, emit one Update with the current local values.

**Invitation batch grouping:**
Before splitting into batches, scans for member Insert mutations (owners, teachers, staff, students, guardians) whose `user` field references a user Insert also in the pending logs. These are grouped into the same `MutationBatch` with the user Insert placed before the member Insert. This allows the server to detect the invitation pattern and resolve phone conflicts.

**Row data reading (`_readRowData`):**
- Dispatches on `LogTable` (0–29) to a per-table `_readXxx(rowKey)` method.
- Each method parses the row key, queries the local Drift table by PK, and maps the Drift data class to the corresponding proto `*Row` message wrapped in a `RowData` oneof.
- Returns `null` if the row no longer exists locally (mutation is skipped).
- For tables with nullable PK columns (`papers`, `grades`, `scopes`): uses raw `customSelect` SQL with `IS NULL` / `= ?` conditionally, same pattern as `DeltaWriter`.

**Enum conversion (Drift → Proto):**
- Standard zero-indexed enums: use `.index` (e.g., `row.level.index`, `row.status.index`).
- Non-zero-indexed enums (e.g., `AttendanceStatus`): use `.value` (e.g., `row.status.value`).

**Permissions encoding (Drift → Proto):**
- Drift stores `roles.permissions` as `text` (base64-encoded bytes).
- Proto `RoleRow.permissions` expects `List<int>` (bytes).
- The processor tries `base64Decode()` first; falls back to `utf8.encode()` for older raw JSON formats.

**Batch ID generation:** Uses `ObjectId().oid` from the `bson` package (already in pubspec).

**Internal tracking:** `Map<String, List<int>> _batchLogIds` maps `batchId → [logIds]` for acknowledgement and failure handling.

**Internal helper types:**
- `_GroupKey` — `(LogTable tbl, String rowKey)` with proper equality/hashCode for grouping.
- `_CoalescedEntry` — result of coalescing: `tbl`, `rowKey`, `op`, `columns` (nullable), `logIds`.
- `_MutationWithMeta` — a built `Mutation` proto alongside its `_CoalescedEntry` metadata.
- `_InvitationPair` — `(userIndex, memberIndex)` pairing for batch grouping.

**Helpers:**
- `_parseKey(String rowKey) → List<String>` — splits pipe-delimited row keys
- `_parseInt(String s) → int` — parses integer PK parts
- `_parseIntNullable(String s) → int?` — handles `"null"` literal for nullable PK parts
- `_toInt64(BigInt v) → Int64` — converts Dart BigInt to fixnum Int64 for proto fields

**Imports:**
- `dart:convert` (for base64Decode, utf8)
- `package:bson/bson.dart` (for ObjectId)
- `package:drift/drift.dart`
- `package:fixnum/fixnum.dart`
- `../database/database.dart`
- `../database/daos/logs_dao.dart`
- `../database/tables/enums.dart`
- `../proto/services/sync.pb.dart`

## `sync_engine.dart`

**Class:** `SyncEngine`

**Constructor:** `SyncEngine(ClientChannel channel, AccountsDao accountsDao, LogsDao logsDao)`

**Key public methods:**
- `Future<void> start({required String accountId, required String accessToken, required int lastSeq})` — Starts sync for a specific account. Stops any existing session first. Pushes pending mutations, opens watch stream, starts periodic push timer (5s).
- `Future<void> stop()` — Stops sync entirely. Cancels all streams, subscriptions, and timers.
- `Future<void> pushNow()` — Pushes pending local mutations immediately. Safe to call from anywhere (fire-and-forget). No-op if not running or offline.
- `bool get isRunning` — Whether the sync engine is currently running.
- `ValueNotifier<SyncStatus> status` — Observable sync status for UI widgets. Starts as `disconnected`. Transitions to `pulling` on first delta, `idle` on flush, `pushing` during active push, `disconnected` on `stop()` / stream error / push stream unavailable. Does NOT optimistically set `idle` on `start()` or `_startWatch()` — only confirmed activity moves the status.

**Module-level helper:**
- `_runGuarded(void Function() body)` — Wraps `body` in `runZonedGuarded` to catch unhandled async errors from the `http2` transport layer. Used for `_startWatch()` calls (initial + reconnect). Logs caught errors via `dart:developer` with name `'SyncEngine'` and `debugPrint`.

**Inbound (watch) flow:**
1. Opens `SyncClient.watchChanges(WatchRequest(lastSeq: ...))` server-streaming call (wrapped in `_runGuarded` to catch transport teardown errors). Does NOT set status to `idle` — gRPC stream creation is lazy and the actual TCP connection happens asynchronously.
2. Each incoming `SyncDelta` is applied via `DeltaWriter.apply()`. The first delta transitions status from `disconnected` → `pulling` (with a debugPrint confirming connection).
3. Tracks `_lastSeq` — persists it to `accounts.lastSeq` via `AccountsDao.updateLastSeq()` whenever the DeltaWriter flushes its buffer (checked via `bufferIsEmpty` getter). Status transitions to `idle` on flush.
4. On `GrpcError(StatusCode.unauthenticated)` → stops sync entirely (caller handles token refresh).
5. On other errors or stream completion → sets status to `disconnected`, schedules reconnect with exponential backoff (1s→2s→4s→8s→16s→30s max). All transitions have `debugPrint` for visibility.

**Outbound (push) flow:**
1. `pushNow()` calls `LogProcessor.buildBatches(accountId)` to get coalesced `MutationBatch` messages.
2. Calls `_ensurePushStream()` which has its own `try/catch` — opens a `SyncClient.pushChanges()` client-streaming call if not already open. If the call throws (server unreachable), the push stream is torn down and `_pushController` remains null.
3. After `_ensurePushStream()`, checks `_pushController == null || _pushController!.isClosed` — if true, logs and sets status to `disconnected`, returns without sending. Mutations stay queued.
4. If the push stream is available, sends batches through the stream controller.
5. Listens for `PushAck` responses from the server.

**PushAck handling (`_onPushAck`):**
- If `ack.success` → calls `LogProcessor.acknowledgeBatch(batchId)` to delete all associated log rows.
- If per-mutation results exist → processes each `MutationResult` by error code:
  - Code 0 (ok): log deleted via batch acknowledgement.
  - Code 1 (permission_denied): marks log as failed (shown in notifications).
  - Code 2 (conflict): deletes the local log entry; server version arrives via watch stream.
  - Code 3 (validation_error): marks log as failed (user must fix).
  - Code 4 (not_found): marks log as failed.
- If batch-level failure with no per-mutation detail → calls `LogProcessor.markBatchFailed()`.
- Updates `_lastSeq` from `ack.serverSeq` if it advanced, persists to DB.

**Push stream lifecycle:**
- `_ensurePushStream()` creates a new `StreamController<MutationBatch>` and opens `pushChanges()` if the controller is null or closed. Wrapped in `try/catch` — if the gRPC call throws (server unreachable), calls `_closePushStream()` so `_pushController` is null and the caller can detect the failure.
- `_closePushStream()` tears down the push stream so the next `pushNow()` creates a fresh one.
- On push error with `StatusCode.unauthenticated` → stops sync entirely.
- On other push errors → closes the push stream (will reopen on next `pushNow()`).

**Reconnection:**
- Exponential backoff with `_reconnectAttempts` counter.
- Delay: `min(2^attempts, 30)` seconds.
- Reset to 0 on successful watch connection.
- Uses a `Timer` (`_reconnectTimer`) that is cancelled on `stop()`.

**Logging:** Uses `dart:developer` `dev.log()` with name `'SyncEngine'` for DevTools filtering.

**Imports:**
- `dart:async`
- `dart:developer`
- `package:fixnum/fixnum.dart`
- `package:grpc/grpc.dart`
- `../database/database.dart`
- `../database/daos/accounts_dao.dart`
- `../database/daos/logs_dao.dart`
- `../proto/services/sync.pb.dart`
- `../proto/services/sync.pbgrpc.dart`
- `delta_writer.dart`
- `log_processor.dart`

## Design Decisions (from AGENT.md)

- **Logs table is the outbound queue.** Every local mutation to a synced table writes a row to `logs`. The log processor reads these and replays them.
- **Synced log rows are DELETED** — not marked as synced. The table only contains pending/failed work.
- **Update coalescing:** For the same `(tbl, row_key)`, the processor ORs all pending `columns` bitmasks, reads the current local values for those columns, and pushes once.
- **Delete supersedes:** If a Delete log exists for a `(tbl, row_key)`, it supersedes all Insert/Update logs for that row — others are deleted from the queue, only the Delete is sent.
- **Failed log retry:** Per-mutation error codes from server: 0=ok (delete log), 1=permission_denied (mark failed), 2=conflict (apply server version, delete log), 3=validation_error (mark failed), 4=not_found (mark failed for updates, delete for deletes). Exponential backoff: 1s→2s→4s→8s→30s max. Max 5 retries.
- **Reactive Unauthorized:** If the server responds with Unauthorized on a stream connection, the sync engine stops — `client.dart` handles token refresh and restarts sync.
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

- **Depends on:** `dart:async` (runZonedGuarded, StreamController, Timer), `dart:developer` (dev.log), `package:fixnum` (Int64 — used by log_processor and sync_engine, NOT by delta_writer), `package:flutter/foundation.dart` (debugPrint, ValueNotifier), `package:grpc` (ClientChannel, CallOptions, StatusCode, GrpcError, ResponseStream), `database/database.dart` (AppDatabase, global `db`), `database/tables/enums.dart` (all enum types + converters), `database/daos/logs_dao.dart` (LogsDao), `database/daos/accounts_dao.dart` (AccountsDao), `proto/services/sync.pb.dart` (SyncDelta, InsertData, UpdateData, MutationBatch, Mutation, PushAck, MutationResult, WatchRequest, FileUrl, all *Insert and *Update messages), `proto/services/sync.pbgrpc.dart` (SyncClient), `sync/sync_status.dart` (SyncStatus enum)
- **Depended on by:** `client.dart` (✅ integrated — `Client.syncEngine` field, `SyncEngine get sync` global getter, start/stop wired into `active()`, `saveAccount()`, `switchAccount()`, `logOut()`), `ui/widgets/sync_indicator.dart` (binds to `sync.status` ValueNotifier), `main.dart` (global `runZonedGuarded` zone catches unhandled http2 transport errors)

## Last Updated
Bugfix: Off-by-one in `mutation.table` (log_processor) and `delta.table` dispatch (delta_writer)

### Bugfix: Off-by-one in `mutation.table` and `delta.table` dispatch
- **Root cause:** `LogTable` enum values are 0-based (users=0, schools=1, ..., discounts=29) but the proto `InsertData.row` / `UpdateData.row` oneof field numbers are 1-based (user=1, school=2, ..., discount=30). The server uses the oneof field number as the canonical table identifier.
- **`log_processor.dart`:** In `_buildMutation()`, changed `mutation.table = c.tbl.value` → `mutation.table = c.tbl.value + 1`. This ensures the `Mutation.table` field sent to the server matches the proto oneof field number of whichever `InsertData.row` / `UpdateData.row` variant is set. Previously, every mutation was labeled one table behind (e.g. an Owners insert was sent with `table=2` which the server interpreted as Schools).
- **`delta_writer.dart`:** In `_applySingle()`, shifted all switch case labels from 0–29 to 1–30 to match the 1-based `SyncDelta.table` values the server sends. Updated all per-method comments to use 1-based numbering. Previously, incoming deltas were dispatched to the wrong table handler (e.g. a `table=3` delta meaning Owners was dispatched to `_applyStudents`).
- **Symptoms fixed:** Wrong permission checks on server, FK violation from incorrect dependency sorting, wrong changelog table in WatchChanges deltas.

### Task S1: InsertData / *Insert Proto Migration (delta_writer.dart)
- **`delta_writer.dart`:** Rewritten for new `InsertData` / `*Insert` proto messages. All 30 `_apply*` methods updated:
  - Removed all references to `row.id`, `row.created`, `row.updated` (no longer on `*Insert` messages).
  - PKs now derived from `delta.rowKey` using `_parseKey()` for composite PKs or `delta.rowKey` directly for single-PK tables.
  - Timestamps synthesized locally via new `_now()` helper (seconds since epoch as BigInt).
  - Removed `_toBigInt(Int64)` helper and `package:fixnum` import (no longer needed — no Int64 timestamp fields on proto messages).
  - Added `_parseStringNullable(String)` helper for nullable string PKs (scopes table).
  - For composite-PK tables, PK fields from `rowKey` are used instead of redundant fields from the `*Insert` message.
  - Raw SQL tables (`papers`, `grades`, `scopes`) updated similarly — PK values from rowKey, timestamps from `_now()`.
  - 62 compile errors resolved → 0 errors.

### Previous: Sync diagnostics & status flow fix (post http2 crash fix)

### Sync Diagnostics & Status Flow Fix
- **`sync_engine.dart`:** Fixed status flow — `start()` now sets `disconnected` (not `idle`) since gRPC stream creation is lazy and the connection hasn't been confirmed yet. `_startWatch()` no longer sets `idle` on stream listener attachment — status only moves to `idle` when the first delta is received and flushed, confirming a live connection. Added comprehensive `debugPrint` at every lifecycle point: `_startWatch()` (open + waiting), `_onWatchError` (error + reconnect intent), `_onWatchDone` (completed + reconnect intent), `_scheduleReconnect` (delay + attempt), reconnect timer fire, first delta received. `pushNow()` only sets `pushing` after confirming push stream is available; sets `disconnected` if unavailable.
- **`client.dart`:** Added `debugPrint` showing gRPC channel target (`$kDomain:$kPort`) on creation and `_startSync()` account + target for tracing connection issues (e.g. Android emulator `localhost` → `10.0.2.2`).

### http2 Transport Crash Fix (previous)
- **`sync_engine.dart`:** Added `_runGuarded()` module-level helper that wraps a callback in `runZonedGuarded` to catch unhandled async errors from the `http2` transport layer. Applied to `_startWatch()` calls (initial start + reconnect timer). Added `try/catch` inside `_ensurePushStream()` — if `pushChanges()` throws, calls `_closePushStream()` so `_pushController` is null. `pushNow()` now checks for null/closed `_pushController` after `_ensurePushStream()` and sets status to `disconnected` if the push stream is unavailable.
- **`main.dart`:** Wrapped `main()` body in `runZonedGuarded` to catch any uncaught async errors (primarily `http2` `ConnectionMessageQueueIn.onTerminated` assertion during gRPC connection teardown). Errors are logged via `dart:developer` with name `'Main'` instead of crashing the isolate.

### Tasks 1–4 Changes
- **`sync_status.dart` (new):** Added `SyncStatus` enum with 4 values: `disconnected`, `idle`, `pushing`, `pulling`.
- **`sync_engine.dart`:** Added `ValueNotifier<SyncStatus> status` field. Status transitions emitted at key lifecycle points: `start()` → idle, `stop()` → disconnected, `pushNow()` → pushing → idle, `_onDelta()` → pulling → idle (on flush), watch error/done → disconnected. Added `debugPrint` statements at push/ack/error points for diagnostics.
- **`client.dart` fix:** `saveAccount()` now always calls `_startSync(updated)` instead of only when `syncEngine.isRunning`. Previously, on first login the sync engine was never started because `saveAccount` was called before any `active()` call — the user navigated directly to HomeScreen via setup flow, bypassing the splash screen's `active()` call. This was the root cause of "mutations not reaching the server" on first login sessions.

### Previous: Task 10 Changes
- Removed unnecessary `sync.pb.dart` import in `sync_engine.dart` (already re-exported by `sync.pbgrpc.dart`).
- Applied `use_null_aware_elements` fixes in `delta_writer.dart` (3 occurrences: papers delete, grades delete, scopes delete) — uses `?variable` syntax instead of `if (variable != null) variable`.
- Full static code review of all 3 sync files confirmed correctness: proto field mapping, row key parsing, authorization metadata, Drift companion types, BigInt/Int64 conversions, and nullable PK handling all verified.
- Manual E2E test (steps 1-12 in task spec) still required — needs a running Rust backend + emulator.
