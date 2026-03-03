# EduXal

A **local-first, real-time** school management application for Android, iOS, Linux, macOS, and Windows, built with Flutter and Dart.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [Database Design](#database-design)
6. [Authentication & Session Management](#authentication--session-management)
7. [Offline-First & Sync Strategy](#offline-first--sync-strategy)
8. [UI Design System](#ui-design-system)
9. [Getting Started](#getting-started)
10. [Code Generation](#code-generation)
11. [Feature Status](#feature-status)
12. [Pending Items](#pending-items)

---

## Overview

EduXal is a comprehensive school management platform targeting schools in Kenya. It handles:

- **Multi-school, multi-role access** — a single user can be an owner at one school, a teacher at another, and a guardian at a third, all within the same app session.
- **CBC and 8-4-4 curriculum support** — full grade/stream/subject configuration for both curricula, including all CBC pathways (STEM, Social Sciences, Arts & Sports Science) and all 8-4-4 levels.
- **System administration** — a super-admin dashboard for managing users, schools, subscription plans, roles, and system-wide permissions.
- **Financial management** — fee structures, invoices, payments, and M-Pesa integration (planned).
- **Academic management** — timetables, lessons, exams, papers, grades, attendance, and mastery tracking.

### Core Philosophy

> **Local-first, real-time UI.**

All data lives in a local Drift (SQLite) database on the user's device. The UI always reads from the local database — never directly from the network. The gRPC layer is responsible only for authentication and syncing the local database with the server. The app is fully functional offline; mutations made offline are queued and replayed when connectivity is restored.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                      UI Layer                        │
│          (lib/ui/screens, lib/ui/widgets)            │
│    Consumes Stream<T> and Future<Result<T,E>>        │
└────────────────────────┬────────────────────────────┘
                         │ Stream<T> / Future<Result<T,E>>
┌────────────────────────▼────────────────────────────┐
│                  Services Layer                      │
│                  (lib/services/)                     │
│       Orchestrates DB reads/writes + gRPC calls      │
└──────────┬──────────────────────────┬───────────────┘
           │                          │
┌──────────▼──────────┐   ┌───────────▼──────────────┐
│   Local DB (Drift)  │   │   Remote (gRPC)           │
│   lib/database/     │   │   lib/proto/ + services   │
│   tables/ + daos/   │   │   (thin gRPC wrappers)    │
└─────────────────────┘   └──────────────────────────-┘
           │
┌──────────▼──────────┐
│   Sync Engine        │
│   lib/sync/          │
│   (deferred — TG2)   │
└─────────────────────┘
```

### Key Principles

- **No business logic in widgets.** Widgets bind to `Stream<T>` (reactive Drift streams) and call `Future<Result<T, E>>` service methods. All logic lives in the services layer.
- **No raw SQL in services.** All queries go through DAOs. Services are unaware of the underlying SQL.
- **One gRPC channel.** `lib/client.dart` is the only file that holds a direct reference to the `ClientChannel`. All service wrappers receive the channel via constructor injection.
- **Result type over exceptions.** All service methods return `Future<Result<T, GrpcError>>` or `Stream<Result<T, GrpcError>>`. Widgets switch on the result — no raw try/catch in widget code.

### Authentication Flow (Online-First)

Authentication is the **only** online-first flow. All auth calls are unary gRPC. On success, the result is persisted to the local `accounts` + `users` Drift tables. All subsequent app starts read from the local DB — no network call on startup unless the access token needs refreshing.

```
LoginScreen → phone number → gRPC login()
    → OtpScreen → verification code → gRPC verify()
    → SetupScreen (first login) → name/email → gRPC setup()
    → HomeScreen (persisted to local DB)
```

---

## Tech Stack

| Concern | Technology |
|---|---|
| Language | Dart 3 / Flutter |
| Local database | Drift 2.x (SQLite) via `drift_flutter` |
| Network | gRPC (`grpc` ^5.1.0) |
| Serialization | Protocol Buffers (`protobuf` ^6.0.0) |
| Code generation | `drift_dev` + `build_runner` |
| File caching | Device file system via `path_provider` |
| State management | Drift reactive streams (`watch`/`watchSingle`) exposed as `Stream<T>` |
| Charts | `fl_chart` ^0.70.2 |
| IDs | `bson` (ObjectId-style generation) |

---

## Project Structure

```
lib/
├── proto/                  # Generated protobuf stubs — do NOT edit manually.
│   ├── services/           # gRPC service clients (AuthenticationClient, etc.)
│   └── types/              # Protobuf message types (User, Verification, etc.)
│
├── database/               # Everything Drift.
│   ├── tables/             # One file per table. Drift table defs + TypeConverters.
│   │   ├── enums.dart      # All shared enums (UserStatus, UserLevel, LogTable, …)
│   │   ├── curriculum_subjects.dart  # CBC & 8-4-4 subject enums + CurriculumType
│   │   └── ...             # One file per backend table (32 total)
│   ├── daos/               # One file per domain group. Typed query + watch methods.
│   │   ├── accounts_dao.dart   # Active session CRUD + reactive stream
│   │   ├── users_dao.dart      # User list, invite, bulk ops, permissions
│   │   ├── schools_dao.dart    # School CRUD + settings
│   │   ├── plans_dao.dart      # Subscription plan CRUD
│   │   ├── roles_dao.dart      # Role + scope management
│   │   ├── settings_dao.dart   # School settings + config serialization
│   │   ├── memberships_dao.dart # Home-screen membership stream (5 tables merged)
│   │   ├── system_stats_dao.dart # Real-time stat streams for the dashboard
│   │   └── logs_dao.dart       # Offline mutation queue read/write
│   └── database.dart       # AppDatabase singleton. 32 tables registered.
│
├── models/                 # Pure Dart domain models. No Drift, no proto deps.
│   ├── result.dart         # Result<T,E> sealed class (Ok / Err)
│   ├── authenticated.dart  # Active session domain model
│   ├── membership.dart     # SchoolMembership, MembershipEntry hierarchy
│   ├── school_config.dart  # SchoolConfig v2 (curricula, grades, streams)
│   ├── curriculum_levels.dart  # CBC & 8-4-4 level/subject definitions
│   ├── school_context.dart # In-session role context (navigational state)
│   ├── school_permissions.dart # Aggregated RBAC permission set
│   ├── system_permissions.dart # System-level permission set
│   ├── system_stats.dart   # DTO for the 6 dashboard stat streams
│   ├── plan_features.dart  # Subscription plan feature flags
│   ├── mpesa_config.dart   # M-Pesa payment configuration
│   └── app_notification.dart  # In-app notification model
│
├── services/               # Business logic. One file per domain.
│   └── authentication.dart # login, verify, setup, refresh, changePhone
│
├── sync/                   # Sync engine internals. (Deferred — Task Group 2)
│
├── cache/                  # File system image/asset cache manager.
│   └── file_cache.dart     # Download, store, and serve cached files
│
├── core/                   # Shared utilities with no domain knowledge.
│   ├── constants.dart      # kDomain, kPort, token durations, etc.
│   ├── app_cache.dart      # In-memory hot-data cache (cleared on logout)
│   ├── extensions.dart     # Dart extension methods
│   └── grpc_errors.dart    # gRPC error mapping utilities
│
├── ui/
│   ├── theme/
│   │   └── app_theme.dart  # Design tokens: colours, radii, breakpoints
│   ├── widgets/
│   │   ├── animated_save_button.dart  # 4-state animated save icon button
│   │   ├── status_indicator.dart      # Coloured status dot/pill
│   │   └── user_avatar.dart           # Cached profile image with fallback
│   └── screens/
│       ├── splash/         # Splash + session restore
│       ├── auth/           # Login, OTP, Setup screens
│       ├── home/           # Membership picker home screen
│       ├── account/        # Account settings screen
│       └── system/         # System admin dashboard
│           ├── home/       # Stats & donut charts section
│           ├── users/      # User list + invite + bulk actions
│           ├── members/    # System-member list + bulk actions
│           ├── schools/    # School list + detail (settings, config)
│           ├── plans/      # Subscription plan management
│           ├── roles/      # Role + permission management
│           ├── settings/   # System-wide settings
│           └── notifications/ # In-app notifications
│
├── client.dart             # gRPC channel + Client class. Account lifecycle.
└── main.dart               # App entry point.
```

---

## Database Design

### Overview

The Drift database contains **32 tables**:
- **30 backend-mirrored tables** — exact replicas of the server SQL schema, kept in sync by the sync engine.
- **2 client-only tables** — `accounts` (session storage, replaces `flutter_secure_storage`) and `logs` (offline mutation queue).

### Type Conventions

| SQL type | Dart/Drift type | Notes |
|---|---|---|
| `bigint` | `int64` (BigInt) | Used for `DateTime` — seconds or ms since Unix epoch |
| `integer` | `int` | Used for `Date` values — days since Unix epoch |
| `smallint` | `int` + `TypeConverter` | Used for enums |
| `text` | `String` | Used for UUIDs and string identifiers |
| `boolean` | `bool` | Drift maps to 0/1 in SQLite automatically |
| `real` | `double` | Used for monetary/score values |

### Enum Convention

Every `smallint` enum column has a Dart enum and a `TypeConverter`:

```dart
enum UserStatus { invited, active, suspended, deleted }

class UserStatusConverter extends TypeConverter<UserStatus, int> {
  const UserStatusConverter();
  UserStatus fromSql(int v) => UserStatus.values[v];
  int toSql(UserStatus v) => v.index;
}
```

### The `accounts` Table (Client-Only)

Replaces `flutter_secure_storage` entirely. Stores one row per logged-in user.

- `is_active = 1` on exactly zero or one rows at a time (enforced by a partial unique index).
- `token_expiry` = `created_at + 3 days`. When expired, the `refresh` gRPC endpoint is called automatically on the next `active()` call.
- `refresh_token_expiry` = `created_at + 30 days`. When expired, the user must log in again; `active()` returns `null`.

### The `logs` Table (Offline Mutation Queue)

Every local write to a synced table produces one or more `logs` rows. The sync engine reads these and replays them to the server in order.

- `op = Insert` → sync sends the full current row.
- `op = Update` → `columns` is a bitset of changed columns. The sync engine ORs all pending bitsets for the same `(tbl, row_key)` and pushes once.
- `op = Delete` → supersedes all Insert/Update logs for that `(tbl, row_key)`.
- Synced rows are **deleted** from `logs`; only pending/failed work remains.

### Triggers and Indexes

The backend schema has ~18 triggers and multiple indexes. These are applied as raw SQL in `AppDatabase.migration.onCreate`. Drift table definitions do not encode them — refer to `schema.sql` for the full source of truth.

---

## Authentication & Session Management

### Flow

1. **`client.active()`** — called on every app start. Pure DB read (no network) unless the access token has expired.
   - Refresh token expired → delete account row, return `null` (force re-login).
   - Access token expired, refresh token valid → call `authentication.refresh()` → return refreshed `Authenticated`.
   - Both valid → return `Authenticated` from the local DB.

2. **`Client.saveAccount(authenticated)`** — persists a new or refreshed session. Writes to both `users` and `accounts` tables in a single transaction. Activates the account and updates in-memory token globals.

3. **`Client.logOut()`** — deletes the active account row. If exactly one other account remains it is auto-activated; if more remain, the UI is expected to prompt the user.

### `Authenticated` Domain Model

`lib/models/authenticated.dart` wraps a full `UsersData` row + session fields from `AccountsData`. Constructed via `Authenticated.fromRows(AccountsData, UsersData)`. Written back to the DB via `toAccountCompanion()` and `toUserCompanion()`.

### In-Memory Cache

`AppCache` (in `lib/core/app_cache.dart`) is a simple in-memory store. `cache.currentUser` is kept in sync with the active `accounts` row via a `watchActiveAccount()` subscription started in `initializeClient()`. Cleared entirely on logout.

---

## Offline-First & Sync Strategy

### Sync-Last Approach

The sync engine (Task Group 2) is deliberately deferred until the UI and local data layer are solid. This is safe because:

> The UI binds only to Drift streams. Drift streams do not care where the data came from.

A write from a local user action and a write from the sync engine both write to the same SQLite tables and both trigger the same reactive `Stream<T>` updates. The UI requires zero changes when sync is plugged in.

### What Happens Right Now

- Every local mutation to a synced table writes a row to `logs` in the same transaction (atomic).
- The log processor does not exist yet — so nothing reads those rows.
- When Task Group 2 arrives, the full mutation history is already queued and ready to replay.
- The only live network traffic today is the four auth gRPC calls.

### File Caching

Files live at **constant, predictable paths** derived from entity identity:

| Entity | Local path |
|---|---|
| User profile image | `{appDir}/users/{userId}/profile` |
| Student image | `{appDir}/schools/{schoolId}/students/{adm}/image` |
| School logo | `{appDir}/schools/{schoolId}/logo` |

`{appDir}` is resolved via `path_provider`'s `getApplicationDocumentsDirectory()`. File paths are **never stored in the database** — they are derived at runtime from the entity's identity.

---

## UI Design System

### Design Mandate

> Thin typography, generous whitespace, precise borders, sharp corners. No pill shapes, no heavy shadows, no bold colours competing with each other.

### Colour Tokens (`app_theme.dart`)

| Token | Value | Usage |
|---|---|---|
| `brandIndigo` | `#3949AB` | Primary interactive elements, tab indicators, active states |
| `brandGreen` | `#69F0AE` (light) / `#00E676` (dark) | Positive action buttons, success states, FAB |

### Shape Tokens

- Standard radius: `4px` — used on cards, containers, input fields.
- Large radius: `6px` — used on bottom sheets.
- **No pill shapes** (radius ≥ 24 is never used).

### Responsive Breakpoints

| Constant | Value | Behaviour |
|---|---|---|
| `kMobileBreakpoint` | `720px` | Below: mobile layout. Above: desktop layout. |
| `kTabletBreakpoint` | `1024px` | Above: wider desktop layout. |

### Key Widgets

- **`AnimatedSaveButton`** — a compact icon button with a 4-state machine (idle → dirty → saving → success). Used on all edit forms. Communicates unsaved state, in-progress saves, and success without any text labels.
- **`UserAvatar`** — displays a cached profile image with a monogram fallback. Reads from `FileCache.profilePath(userId)`.
- **`StatusIndicator`** — a coloured dot/pill reflecting `UserStatus`, `SchoolStatus`, or `PlanStatus`.

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.10.0`
- Dart SDK `^3.10.8`
- A running instance of the EduXal gRPC backend (or use `localhost:50051` for local dev)

### Clone and Install

```bash
git clone https://github.com/eduxal-labs/eduxal.git
cd eduxal
flutter pub get
```

### Run Code Generation

Drift requires generated code. After any change to a table or DAO definition, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Or for continuous watch mode during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

> The generated `.g.dart` files are committed to version control so you do not need to run this on a fresh clone unless you change database definitions.

### Run the App

```bash
# Desktop (Linux)
flutter run -d linux

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### Configuration

The gRPC endpoint is configured in `lib/core/constants.dart`:

```dart
const String kDomain = 'localhost';   // change to your server address
const int kPort = 50051;
```

> For production builds, these values should be supplied via environment variables or a build-time config file. This is a planned improvement.

---

## Code Generation

This project uses two code generators:

| Generator | Input | Output |
|---|---|---|
| `drift_dev` | `@DriftDatabase`, `@DriftAccessor` annotations | `database.g.dart`, `*_dao.g.dart` |
| `protoc` (external) | `.proto` files | `lib/proto/**/*.pb.dart`, `*.pbgrpc.dart` |

The `lib/proto/` directory contains **pre-generated** Dart stubs committed to the repository. Do not edit these files manually — they are regenerated from `.proto` files using `generate.sh` when the backend changes its proto definitions.

---

## Feature Status

### Completed ✅

| Area | Description |
|---|---|
| **Database** | All 32 Drift tables defined and generated. Full FK structure, enum converters, composite PKs, triggers, and indexes applied via `MigrationStrategy.onCreate`. |
| **Authentication** | Full gRPC auth flow: login → OTP verification → setup → session persistence. Token refresh on expiry. Multi-account support with account switching. |
| **Client / Session** | `client.dart` manages gRPC channel lifecycle, session restore, token refresh, logout, and account switching. |
| **DAOs** | `AccountsDao`, `UsersDao`, `SchoolsDao`, `PlansDao`, `RolesDao`, `SettingsDao`, `MembershipsDao`, `SystemStatsDao`, `LogsDao` — all with reactive streams and write methods that log mutations. |
| **Models** | `Authenticated`, `SchoolMembership`, `MembershipEntry` hierarchy, `SchoolConfig` v2, `CurriculumLevel`, `SchoolContext`, `SchoolPermissions`, `SystemPermissions`, `SystemStats`, `Result<T,E>`. |
| **System Dashboard** | Full system admin UI — stats/donut charts, Users tab (invite, bulk actions, "This Is Me" indicator), Members tab (promote/demote/suspend/purge), Schools tab (CRUD, status actions, settings/config), Plans tab (CRUD, status actions), Roles tab (create/edit with permissions). |
| **School Settings** | CBC and 8-4-4 curriculum configuration — grade and stream picker, full subject enumerations for both curricula. |
| **Theme** | Brand colour tokens (indigo primary, bright green action), responsive breakpoints, sharp-corner design system. |
| **Widgets** | `AnimatedSaveButton`, `UserAvatar`, `StatusIndicator`. |
| **File Cache** | `FileCache` with `profilePath`, `logoPath`, `studentImagePath` helpers and `saveBytes` method. |

### In Progress / Planned 🔄

| Area | Status | Blocking |
|---|---|---|
| **Sync Engine** | Deferred (Task Group 2) | Server-streaming gRPC proto definitions (P3) |
| **Home Screen** | Auth complete; membership picker UI planned | — |
| **School Dashboard** | RBAC model defined; dashboard screens not yet built | Permission key taxonomy from backend (P7) |
| **Student Management** | DB tables ready; service + UI not yet built | — |
| **Academic Features** | DB tables ready; timetables, lessons, exams, grades services not yet built | — |
| **Finance Features** | DB tables ready; fees, invoices, payments, M-Pesa not yet built | — |
| **Profile Image Upload** | Local save works; upload endpoint pending | gRPC upload URL endpoint (P8) |

---

## Pending Items

| # | Item | Blocking |
|---|---|---|
| P3 | Sync stream proto definitions (server-streaming gRPC delta sync) | `lib/sync/`, all entity services |
| P5 | Failed log retry logic — reversible vs irreversible server errors | `lib/sync/log_processor.dart` |
| P7 | Permission key taxonomy (`"attendance.record"`, `"students.manage"`, etc.) | School dashboard feature-gate wiring |
| P8 | gRPC endpoint for requesting a fresh presigned PUT URL for profile image upload | `AccountsDao.logProfileImageChange` |

---

## Development Notes

### Adding a New Table

1. Create `lib/database/tables/your_table.dart` with the Drift `Table` class.
2. Add the table class to the `tables: [...]` list in `lib/database/database.dart`.
3. Add the corresponding `XxxColumn` enum to the relevant enum file (for the `logs` bitmask).
4. Add the table's `LogTable` enum value to `enum LogTable` in `lib/database/tables/enums.dart`.
5. Run `dart run build_runner build --delete-conflicting-outputs`.
6. Create `lib/database/daos/your_dao.dart` with typed queries.
7. Add the DAO to `daos: [...]` in `AppDatabase` (or instantiate it directly if it has circular imports).

### Writing a DAO Mutation

Every mutation to a synced table must:
1. Write the change to the table.
2. Write a `LogsCompanion` row inside the **same transaction**.

```dart
Future<void> updateFoo(String id, FooCompanion changes, {required String accountId}) {
  return transaction(() async {
    await (update(foos)..where((t) => t.id.equals(id))).write(changes);
    await into(logs).insert(LogsCompanion(
      account: Value(accountId),
      tbl: Value(LogTable.foos),
      op: Value(LogOperation.update),
      rowKey: Value(id),
      columns: Value(mask), // bitset of changed columns
      status: const Value(LogStatus.pending),
      created: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
    ));
  });
}
```

### Schema Source of Truth

`schema.sql` (at the project root) is the definitive source for all table definitions, triggers, and indexes. It is the server's production schema. All Drift table definitions must match it exactly. When in doubt, read `schema.sql`.

---

## Licence

Proprietary — © EduXal Labs. All rights reserved.