# lib/ — Top-Level Context

> This file is the entry point for understanding the `lib/` directory structure.
> Each subdirectory listed below has its own `CONTEXT.md` with detailed file inventories.

## Architecture

```
UI (screens/widgets) → Services → DAOs → Drift (SQLite)
                         ↓
                    gRPC (proto/)    → Network (auth + sync)
                         ↓
                    Sync Engine      → lib/sync/ (✅ implemented, integrated into client.dart)
```

- **Local-first:** All data lives in a local Drift (SQLite) database. The UI reads only from local DB via reactive streams.
- **Offline-capable:** Mutations are queued in the `logs` table and replayed when online.
- **Network boundary:** Authentication uses unary gRPC calls. The `SyncEngine` uses bidirectional gRPC streams (`pushChanges` client→server, `watchChanges` server→client) for data sync.

## Directory Map

| Directory | Purpose | CONTEXT.md |
|---|---|---|
| `database/` | Drift tables, DAOs, `AppDatabase` singleton, code-gen output | `database/CONTEXT.md` |
| `database/tables/` | One Drift table definition per file + shared enums/converters | `database/tables/CONTEXT.md` |
| `database/daos/` | Domain-grouped DAOs with typed queries and reactive streams | `database/daos/CONTEXT.md` |
| `models/` | Pure Dart domain models — no Drift or proto imports | `models/CONTEXT.md` |
| `services/` | Business logic — orchestrates DAOs + gRPC, exposes `Stream<T>` / `Future<Result<T,E>>` | `services/CONTEXT.md` |
| `core/` | Shared utilities, constants, extensions — no domain knowledge | `core/CONTEXT.md` |
| `proto/` | Generated protobuf/gRPC stubs — **never edit manually** | `proto/CONTEXT.md` |
| `sync/` | Sync engine — bidirectional gRPC sync (delta_writer, log_processor, sync_engine) | `sync/CONTEXT.md` |
| `cache/` | File system cache for images/assets at predictable paths | `cache/CONTEXT.md` |
| `ui/` | Flutter UI layer — screens, widgets, theme | `ui/CONTEXT.md` |

## Top-Level Files

### `client.dart`
- **Status:** ✅ Complete (sync integrated)
- **Purpose:** gRPC `ClientChannel` owner + account lifecycle controller (active, switch, refresh, logout) + `SyncEngine` lifecycle management.
- **Key exports:**
  - `Client` class — holds `ClientChannel`, exposes `Authentication` service and `SyncEngine`, manages sessions.
  - `Client.syncEngine` — the `SyncEngine` instance, created in the constructor alongside the `Authentication` service.
  - `SyncEngine get sync` — **global getter** so services can trigger `sync.pushNow()` fire-and-forget after writing to the `logs` table. No-op if sync is not running or device is offline.
  - `initializeClient()` — async bootstrap called from `main()`. Opens DB, creates Client, restores session (which starts sync), starts `watchActiveAccount()` listener.
  - Global `late` variables: `accessToken`, `refreshToken`, `cache` (`AppCache`), `client` (`Client`).
  - Global DAO singletons: `accountsDao`, `usersDao`, `logsDao`, `schoolsDao`, `membershipsDao`, `rolesDao`, `plansDao`, `settingsDao`, `systemStatsDao`.
- **Dependencies:** `core/constants.dart`, `core/app_cache.dart`, `database/database.dart`, all DAO files, `models/authenticated.dart`, `models/result.dart`, `services/authentication.dart`, `sync/sync_engine.dart`.
- **Key behaviour:**
  - `active()` — pure DB read. If access token expired → `_refresh()`. If refresh token expired → delete account, return null. **On success, starts `SyncEngine`** via `_startSync()`.
  - `saveAccount()` — recomputes token expiry from `now`, writes to both `users` and `accounts` tables in a transaction, sets active. **If sync was running, restarts it** with the fresh token.
  - `switchAccount()` — **stops sync** for the previous account, switches, and **starts sync** for the new one.
  - `logOut()` — **stops sync**, deletes active account. If 1 remains, auto-activates it and starts sync. If 0, returns to unauthenticated state.
  - `_startSync(Authenticated)` — internal helper that calls `syncEngine.start()` with accountId, accessToken, and lastSeq from the `Authenticated` model.

### `main.dart`
- **Status:** ✅ Complete
- **Purpose:** App entry point. Calls `initializeClient()`, then `runApp()`.
- **Key behaviour:** Wraps `MaterialApp` in a `StreamBuilder` on `accountsDao.watchActiveAccount()` to reactively switch theme mode based on the active account's `theme` preference.

## Conventions

- Services expose `Stream<T>` (from Drift `.watch()`) and `Future<Result<T, GrpcError>>`.
- Widgets consume streams and results. No direct DB or gRPC calls in UI code.
- `client.dart` is the **only** file that holds a reference to the gRPC `ClientChannel`.
- `AppDatabase` is a singleton accessed via the global `db` variable initialized in `initializeClient()`.
- Every local mutation to a synced table writes a corresponding row to the `logs` table.

## Last Updated
Task 1001 — Updated to reflect UI overhaul (Tracks 1–10). No structural changes to `lib/` top-level layout — all changes were within existing subdirectories (`ui/`, `models/`, `database/`, `services/`, `core/`).