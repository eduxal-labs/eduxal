# database/ — Drift Database Layer Context

> Everything related to the local SQLite database via Drift 2.x lives here.

## Overview

The Drift database contains **35 tables total**:
- **32 backend-mirrored tables** — exact replicas of the server SQL schema (see `schema.sql`).
- **3 client-only tables** — `accounts` (session management), `logs` (offline mutation queue), and `paper_submissions` (local answer image paths).

All tables are defined in `tables/`, all query logic lives in `daos/`, and the `AppDatabase` class in `database.dart` registers everything.

## Files

| File | Status | Description |
|---|---|---|
| `database.dart` | ✅ Complete | `AppDatabase` class — registers all 35 tables + all DAOs. Schema version **11**. `MigrationStrategy.onUpgrade` handles: v1→v2 (add `accounts.lastSeq` column), v2→v3 (drop+recreate `logs` table for action-based model), v3→v4 (drop overly-restrictive unique indexes on exams), v4→v5 (create `paper_submissions` table), v5→v6 (add `accounts.theme` column), v6→v7 (add `papers.grade`/`stream`, drop `exam_grades`, recreate triggers), v7→v8 (rebuild `papers` and `grades` tables for new composite PK shape), v8→v9 (create `scheme_pages` and `answer_pages` tables), v9→v10 (migrate `roles.permissions` from TEXT to BLOB — table recreation with data conversion via `parsePermissions()` → `Permissions.toBlob()`), v10→v11 (add `papers.time_allowed_minutes` and `papers.custom_instructions` nullable columns via `ALTER TABLE`). `onCreate` applies triggers + indexes as raw SQL. Singleton accessed via global `db` variable set in `client.dart`'s `initializeClient()`. |
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
- `SubjectTeachersData`, `EnrollmentsData`, `ClassTeachersData`, `AttendanceData`
- `TimetableData`, `LessonsData`, `ExamsData`, `PapersData`, `GradesData`
- `FeesData`, `InvoicesData`, `PaymentsData`, `DiscountsData`
- `AnnouncementsData`, `MasteryData`, `AiusageData`, `SettingsData`
- `RolesData`, `ScopesData`, `PlansData`, `SubscriptionsData`
- `SchemePagesData`, `AnswerPagesData`
- `LogsData`
- `PaperSubmissionData`

Companion classes for inserts/updates: `{TableName}Companion` (e.g. `UsersCompanion`, `AccountsCompanion`).

## Conventions

- **Enum columns:** Every `smallint` enum column uses a `TypeConverter<EnumType, int>`. All enums and converters live in `tables/enums.dart`. The `SyncAction` enum (81 values) and `LogStatus` enum are the log-specific enums; the old `LogTable`, `LogOperation`, and all `*Column` bitset enums have been removed.
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

## Logs Table Schema (Action-Based Model)

The `logs` table was redesigned in Task C2 from a mutation-tracking model (`tbl`/`op`/`rowKey`/`columns`) to an action-based model:

| Column | Type | Description |
|---|---|---|
| `id` | `integer` (autoIncrement) | Surrogate PK — preserves replay order |
| `account` | `text` (FK → accounts.id) | The account that performed this action |
| `action` | `integer` (mapped via `SyncActionConverter`) | `SyncAction` enum — 81 semantic action types |
| `resource` | `text` | Human-readable display key for notification UI |
| `payload` | `blob` | Serialized protobuf action payload bytes (self-contained) |
| `status` | `integer` (mapped via `LogStatusConverter`) | `LogStatus` enum: pending (0) / failed (1) |
| `attempts` | `integer` (default 0) | Sync retry attempt count |
| `error` | `text` (nullable) | Last server error message |
| `created` | `int64` | Milliseconds since epoch |

**Removed columns:** `tbl`, `op`, `rowKey`, `columns` (bitmask).

**Removed enums (from `enums.dart`):** `LogTable`, `LogTableConverter`, `LogOperation`, `LogOperationConverter`, and all 27 `*Column` bitset enums (`UsersColumn`, `SchoolsColumn`, `StudentsColumn`, etc.).

**Added enums:** `SyncAction` (81 values, explicit `int value` per entry) + `SyncActionConverter`.

## Last Updated
Task AUTH-B03 — Authorization checks added to all `AnnouncementsDao` mutation methods:
- `lib/database/daos/announcements_dao.dart` — added `import '../../services/authorization_service.dart'`. Added pre-flight `authorization.check(...)` + `PermissionException` throw as the first statement in: `createAnnouncement` (`SyncAction.createAnnouncement`, `schoolId: schoolId`, `recordId: null`), `updateAnnouncement` (`SyncAction.updateAnnouncement`, `schoolId: null`, `recordId: id`), `deleteAnnouncement` (`SyncAction.deleteAnnouncement`, `schoolId: null`, `recordId: id`). The existing `getSchoolForAnnouncement` helper (added in AUTH-A01) is used internally by `AuthorizationService._resolveOrganisation()` for update/delete — no manual school lookup needed in the DAO.

Previous: Task AUTH-B02 — Authorization checks added to all `FinanceDao` mutation methods:
- `lib/database/daos/finance_dao.dart` — added `import '../../services/authorization_service.dart'`. Added pre-flight `authorization.check(...)` + `PermissionException` throw as the first statement in: `createFee` (`SyncAction.createFee`, `schoolId: schoolId`), `updateFee` (`SyncAction.updateFee`, `recordId: id`), `deleteFee` (`SyncAction.deleteFee`, `recordId: id`), `createInvoice` (`SyncAction.createInvoice`, `schoolId: schoolId`), `updateInvoiceStatus` (`SyncAction.updateInvoice`, `recordId: id`), `recordPayment` (`SyncAction.createPayment`, `schoolId: schoolId`), `upsertDiscount` — update branch (`SyncAction.updateDiscount`, `schoolId: null, recordId: null`) and create branch (`SyncAction.createDiscount`, `schoolId: null, recordId: null`), `deleteDiscount` (`SyncAction.deleteDiscount`, `schoolId: null, recordId: null`). Note: `updatePayment`, `deletePayment`, and `approvePayment` do not exist in this file and were skipped. `_recalculateInvoiceStatus` was refactored to write directly to the DB instead of delegating to `updateInvoiceStatus`, preventing a double-auth-check when triggered internally by `recordPayment`.

Previous: Task AUTH-B01 — Authorization checks added to all `ExamsGradesDao` mutation methods:
- `lib/database/daos/exams_grades_dao.dart` — added `import '../../services/authorization_service.dart'`. Added pre-flight `authorization.check(...)` + `PermissionException` throw as the first statement in: `createExam` (`SyncAction.createExam`, `schoolId: exam.school.value`), `updateExam` (`SyncAction.updateExam`, `recordId: examId`), `deleteExam` (`SyncAction.deleteExam`, `recordId: examId`), `createPaper` (`SyncAction.createPaper`, `schoolId: paper.school.value`), `updatePaper` (`SyncAction.updatePaper`, `schoolId: schoolId`), `deletePaper` (`SyncAction.deletePaper`, `schoolId: schoolId`), `upsertGrade` (`SyncAction.markGrades`, `schoolId: grade.school.value`), `deleteGrade` (`SyncAction.deleteGrade`, `schoolId: schoolId`), `upsertMastery` (`SyncAction.updateMastery`, `schoolId: entry.school.value`), `logUploadScheme` (`SyncAction.uploadScheme`, `schoolId: schoolId`), `logDeleteScheme` (`SyncAction.deleteScheme`, `schoolId: schoolId`), `logUploadAnswerSheet` (`SyncAction.uploadAnswerSheet`, `schoolId: schoolId`), `logDeleteAnswerSheet` (`SyncAction.deleteAnswerSheet`, `schoolId: schoolId`). No new helper methods were needed — all methods already carried `schoolId` directly or via companion field.

Previous: Task AUTH-A01 — Added DAO authorization helper methods (read-only, no schema changes):
- `lib/database/daos/exams_grades_dao.dart` — added `getSchoolForExam(String examId) → Future<String?>`. Returns the school ID for an exam by ID. Used by `AuthorizationService` to resolve org context for `updateExam`/`deleteExam`.
- `lib/database/daos/finance_dao.dart` — added `getSchoolForFee(String feeId) → Future<String?>`, `getSchoolForInvoice(String invoiceId) → Future<String?>`, `getSchoolForPayment(String paymentId) → Future<String?>`. Used by `AuthorizationService` to resolve org context for fee/invoice/payment update and delete actions. Note: `getSchoolForPayment` may return null for invoice-linked payments (school is nullable on the payments table for that case).
- `lib/database/daos/announcements_dao.dart` — added `getSchoolForAnnouncement(String announcementId) → Future<String?>`. Used by `AuthorizationService` to resolve org context for `updateAnnouncement`/`deleteAnnouncement`.
- `lib/database/daos/roles_dao.dart` — added `getSystemRolesForUser(String userId) → Future<List<RolePermissions>>`. Returns all system-scoped roles (scopes where `school IS NULL`) for the user, joined with the roles table, as `RolePermissions` instances for `SystemPermissions.forUser()`. Added `import '../../models/system_permissions.dart'`.
- `lib/database/daos/schools_dao.dart` — `isOwner(String schoolId, String userId) → Future<bool>` already existed; no changes needed.

Previous: Task C03 — Add `time_allowed_minutes` and `custom_instructions` to `Papers` table:
- Bumped `schemaVersion` 10 → **11**. Added `from < 11` migration: two `ALTER TABLE papers ADD COLUMN` statements — `time_allowed_minutes INTEGER` (nullable) and `custom_instructions TEXT` (nullable).
- `lib/database/tables/papers.dart` — added `IntColumn get timeAllowedMinutes => integer().nullable()()` and `TextColumn get customInstructions => text().nullable()()` at end of `Papers` class.
- `database.g.dart` regenerated — `PapersData` now has `int? timeAllowedMinutes` and `String? customInstructions` fields; `PapersCompanion` has corresponding `Value<int?>` and `Value<String?>` fields.

Previous: Task A01 — Migrate `roles.permissions` from TEXT to BLOB (schema version 10).