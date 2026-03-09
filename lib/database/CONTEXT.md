# database/ — Drift Database Layer Context

> Everything related to the local SQLite database via Drift 2.x lives here.

## Overview

The Drift database contains **32 tables total**:
- **30 backend-mirrored tables** — exact replicas of the server SQL schema (see `schema.sql`).
- **2 client-only tables** — `accounts` (session management) and `logs` (offline mutation queue).

All tables are defined in `tables/`, all query logic lives in `daos/`, and the `AppDatabase` class in `database.dart` registers everything.

## Files

| File | Status | Description |
|---|---|---|
| `database.dart` | ✅ Complete | `AppDatabase` class — registers all 32 tables + all DAOs. Defines `MigrationStrategy` with `onCreate` (triggers, indexes as raw SQL). Singleton accessed via global `db` variable set in `client.dart`'s `initializeClient()`. |
| `database.g.dart` | ✅ Generated | Drift code-gen output — `part of` `database.dart`. Contains all generated data classes (`UsersData`, `SchoolsData`, `AccountsData`, etc.) and table accessors. **Never edit manually.** Regenerate with `dart run build_runner build`. |

## Subdirectories

| Directory | Purpose | CONTEXT.md |
|---|---|---|
| `tables/` | One file per Drift table definition + shared enums/converters in `enums.dart` | `tables/CONTEXT.md` |
| `daos/` | Domain-grouped DAOs — typed queries, inserts, updates, watches | `daos/CONTEXT.md` |

## Key Types (from database.g.dart)

All Drift-generated data classes follow the pattern `{TableName}Data` (singular of table class name):
- `UsersData`, `SchoolsData`, `AccountsData`, `StudentsData`, `TeachersData`, `StaffData`
- `OwnersData`, `GuardiansData`, `DepartmentsData`, `TermsData` (alias: `Term`)
- `SubjectsData`, `EnrollmentsData`, `ClassTeachersData`, `AttendanceData`
- `TimetableData`, `LessonsData`, `ExamsData`, `PapersData`, `GradesData`
- `FeesData`, `InvoicesData`, `PaymentsData`, `DiscountsData`
- `AnnouncementsData`, `MasteryData`, `AiusageData`, `SettingsData`
- `RolesData`, `ScopesData`, `PlansData`, `SubscriptionsData`
- `LogsData`

Companion classes for inserts/updates: `{TableName}Companion` (e.g. `UsersCompanion`, `AccountsCompanion`).

## Conventions

- **Enum columns:** Every `smallint` enum column uses a `TypeConverter<EnumType, int>`. All enums and converters live in `tables/enums.dart`.
- **BigInt DateTime:** `bigint` columns representing timestamps are `Int64Column` in Drift → `BigInt` in Dart. Converted to `int` via `.toInt()` in domain models.
- **Integer Date:** `integer` columns representing dates are days since Unix epoch.
- **Composite PKs:** Reproduced via `@override Set<Column> get primaryKey => {col1, col2, ...}`.
- **Triggers & Indexes:** Applied as raw SQL in `MigrationStrategy.onCreate` inside `database.dart`, not generated from table definitions.
- **No raw SQL in services:** All queries go through DAOs. Services never import `database.dart` directly for queries.

## Dependencies

- **Depends on:** `drift`, `drift_flutter` packages
- **Depended on by:** `lib/models/` (via generated data classes), `lib/services/` (via DAOs), `lib/client.dart` (initialization + global DAO singletons)

## Schema Reference

The definitive source for all 30 backend table definitions is `eduxal/schema.sql`. It contains exact column names, types, CHECK constraints, FK relationships, triggers, and indexes. Always consult it when modifying or adding table definitions.

## Last Updated
Phase 1 Task 01 — Added `watchFailedLogCount(String accountId) → Stream<int>` to `LogsDao` (see `daos/CONTEXT.md` for full method listing). This method powers the sync-failure badge count on dashboard user avatars across both System and School dashboards.