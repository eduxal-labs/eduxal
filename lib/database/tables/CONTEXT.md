# database/tables/ — Drift Table Definitions Context

> One file per database table. Each file contains a single Drift `Table` class definition.
> Shared enums and `TypeConverter` classes live in `enums.dart`.

## Overview

This directory contains **35 files**: 34 table definition files (one per table) and 1 shared enums file.

The 34 tables break down as:
- **32 backend-mirrored tables** — exact replicas of the server schema defined in `schema.sql`.
- **2 client-only tables** — `accounts` (session/auth) and `logs` (offline mutation queue).

## Files

| File | Table class | Generated data class | PK | Status |
|---|---|---|---|---|
| `accounts.dart` | `Accounts` | `AccountsData` | `id` (TEXT) | ✅ Complete |
| `aiusage.dart` | `Aiusage` | `AiusageData` | `school`, `year`, `term` | ✅ Complete |
| `announcements.dart` | `Announcements` | `AnnouncementsData` | `id` (TEXT) | ✅ Complete |
| `attendance.dart` | `Attendance` | `AttendanceData` | `school`, `student`, `date` | ✅ Complete |
| `class_teachers.dart` | `ClassTeachers` | `ClassTeachersData` | `school`, `teacher`, `year`, `term`, `grade`, `stream` | ✅ Complete |
| `curriculum_subjects.dart` | `CurriculumSubjects` | N/A (not a Drift table — pure Dart enums) | N/A | ✅ Complete |
| `departments.dart` | `Departments` | `DepartmentsData` | `school`, `name` | ✅ Complete |
| `discounts.dart` | `Discounts` | `DiscountsData` | `id` (TEXT) | ✅ Complete |
| `enrollments.dart` | `Enrollments` | `EnrollmentsData` | `school`, `student`, `year`, `term` | ✅ Complete |
| `enums.dart` | N/A (shared enums + converters) | N/A | N/A | ✅ Complete |
| `exams.dart` | `Exams` | `ExamsData` | `id` (TEXT) | ✅ Complete |
| `fees.dart` | `Fees` | `FeesData` | `id` (TEXT) | ✅ Complete |
| `grades.dart` | `Grades` | `GradesData` | `paper`, `student` | ✅ Complete |
| `guardians.dart` | `Guardians` | `GuardiansData` | `school`, `user`, `student` | ✅ Complete |
| `invoices.dart` | `Invoices` | `InvoicesData` | `id` (TEXT) | ✅ Complete |
| `lessons.dart` | `Lessons` | `LessonsData` | `timetable`, `date` | ✅ Complete |
| `logs.dart` | `Logs` | `LogsData` | `id` (INTEGER AUTOINCREMENT) | ✅ Complete |
| `mastery.dart` | `Mastery` | `MasteryData` | `school`, `student`, `subject`, `year`, `term` | ✅ Complete |
| `owners.dart` | `Owners` | `OwnersData` | `school`, `user` | ✅ Complete |
| `papers.dart` | `Papers` | `PapersData` | `id` (TEXT) | ✅ Complete |
| `payments.dart` | `Payments` | `PaymentsData` | `id` (TEXT) | ✅ Complete |
| `plans.dart` | `Plans` | `PlansData` | `id` (TEXT) | ✅ Complete |
| `roles.dart` | `Roles` | `RolesData` | `id` (TEXT) | ✅ Complete |
| `schools.dart` | `Schools` | `SchoolsData` | `id` (TEXT) | ✅ Complete |
| `scopes.dart` | `Scopes` | `ScopesData` | `school`, `user`, `role` | ✅ Complete |
| `settings.dart` | `Settings` | `SettingsData` | `school` (TEXT) | ✅ Complete |
| `staff.dart` | `Staff` | `StaffData` | `school`, `user` | ✅ Complete |
| `students.dart` | `Students` | `StudentsData` | `school`, `adm` | ✅ Complete |
| `streams.dart` | `Streams` | `StreamsData` | `school`, `grade`, `stream` | ✅ Complete |
| `subject_teachers.dart` | `SubjectTeachers` | `SubjectTeachersData` | `school`, `year`, `term`, `grade`, `stream`, `subject` | ✅ Complete |
| `subscriptions.dart` | `Subscriptions` | `SubscriptionsData` | `id` (TEXT) | ✅ Complete |
| `topics.dart` | `Topics` | `TopicsData` | `id` (INTEGER AUTOINCREMENT) | ✅ Complete |
| `teachers.dart` | `Teachers` | `TeachersData` | `school`, `user` | ✅ Complete |
| `terms.dart` | `Terms` | `Term` | `school`, `year`, `term` | ✅ Complete |
| `timetable.dart` | `Timetable` | `TimetableData` | `id` (TEXT) | ✅ Complete |
| `users.dart` | `Users` | `UsersData` | `id` (TEXT) | ✅ Complete |

## Special File: `enums.dart`

Contains **all** enum types and their `TypeConverter` classes used across the table definitions. This is the single source of truth for enum↔smallint mapping.

### Domain Enums (alphabetical)

| Enum | Converter | Column usage | Values |
|---|---|---|---|
| `AppThemeMode` | `AppThemeModeConverter` | `accounts.theme` | system(0), light(1), dark(2) |
| `AttendanceStatus` | `AttendanceStatusConverter` | `attendance.status` | present(1), absent(2), leave(3) — **starts at 1** |
| `DayOfWeek` | `DayOfWeekConverter` | `timetable.day` | sunday(0)–saturday(6) |
| `DiscountUnit` | `DiscountUnitConverter` | `discounts.unit` | percentage(0), amount(1) |
| `ExamType` | `ExamTypeConverter` | `exams.type` | exam(0), assignment(1), assessment(2) |
| `Gender` | `GenderConverter` | `students.gender` | male(0), female(1) |
| `GuardianRelationship` | `GuardianRelationshipConverter` | `guardians.relationship` | father(0), mother(1), brother(2), sister(3), guardian(4) |
| `GuardianRole` | `GuardianRoleConverter` | `guardians.role` | primary(0), secondary(1), sponsor(2) |
| `InvoiceStatus` | `InvoiceStatusConverter` | `invoices.status` | pending(0), partial(1), paid(2), overdue(3), cancelled(4) |
| `PaperStatus` | `PaperStatusConverter` | `papers.status` | pending(0), progress(1), done(2), marked(3) |
| `PaymentMethod` | `PaymentMethodConverter` | `payments.method` | cash(0), cheque(1), mpesa(2), bank(3) |
| `PlanStatus` | `PlanStatusConverter` | `plans.status` | pending(0), active(1), suspended(2), deleted(3) |
| `SchoolStatus` | `SchoolStatusConverter` | `schools.status` | trial(0), active(1), cancelled(2), suspended(3), deleted(4) |
| `StaffStatus` | `StaffStatusConverter` | `staff.status` | active(0), resigned(1), transferred(2), fired(3), retired(4) |
| `StudentStatus` | `StudentStatusConverter` | `students.status` | active(0), expelled(1), graduated(2), transferred(3), withdrawn(4), deleted(5) |
| `SubscriptionStatus` | `SubscriptionStatusConverter` | `subscriptions.status` | pending(0), active(1), cancelled(2), deleted(3) |
| `TeacherStatus` | `TeacherStatusConverter` | `teachers.status` | active(0), resigned(1), transferred(2), fired(3), retired(4) |
| `UserLevel` | `UserLevelConverter` | `users.level` | normal(0), system(1), super_(2) |
| `UserStatus` | `UserStatusConverter` | `users.status` | invited(0), active(1), suspended(2), deleted(3) |

### Log Enums

| Enum | Converter | Column usage | Values |
|---|---|---|---|
| `LogTable` | `LogTableConverter` | `logs.tbl` | users(0)–discounts(29) — 30 values, explicit `.value` field |
| `LogOperation` | `LogOperationConverter` | `logs.op` | insert(0), update(1), delete(2) |
| `LogStatus` | `LogStatusConverter` | `logs.status` | pending(0), failed(1) |

### Column Bitset Enums

Used for the `logs.columns` bitmask on UPDATE entries. One enum per synced table with updatable columns. Each variant has a `.bit` field (0-indexed bit position).

| Enum | For table | Variants |
|---|---|---|
| `UsersColumn` | `users` | phone(0), email(1), name(2), level(3), status(4), updated(5) |
| `SchoolsColumn` | `schools` | name(0), motto(1), phone(2), email(3), county(4), domain(5), established(6), status(7), updated(8) |
| `StudentsColumn` | `students` | user(0), name(1), dob(2), gender(3), documents(4), admitted(5), status(6), updated(7) |
| `GuardiansColumn` | `guardians` | relationship(0), role(1), updated(2) |
| `DepartmentsColumn` | `departments` | description(0), updated(1) |
| `TeachersColumn` | `teachers` | hired(0), role(1), department(2), status(3), updated(4) |
| `StaffColumn` | `staff` | idnumber(0), role(1), department(2), status(3), updated(4) |
| `TermsColumn` | `terms` | start(0), end(1), updated(2) |
| `ClassTeachersColumn` | `class_teachers` | end(0) |
| `SubjectTeachersColumn` | `subject_teachers` | teacher(0) |
| `AttendanceColumn` | `attendance` | status(0), updated(1) |
| `TimetableColumn` | `timetable` | teacher(0), start(1), end(2), updated(3) |
| `LessonsColumn` | `lessons` | updated(0) |
| `ExamsColumn` | `exams` | stream(0), personalized(1), type(2), start(3), end(4), teacher(5), updated(6) |
| `PapersColumn` | `papers` | invigilator(0), start(1), end(2), status(3), updated(4) |
| `GradesColumn` | `grades` | score(0), total(1), updated(2) |
| `FeesColumn` | `fees` | title(0), description(1), amount(2), mandatory(3), due(4), updated(5) |
| `InvoicesColumn` | `invoices` | fee(0), description(1), amount(2), status(3), due(4), updated(5) |
| `PaymentsColumn` | `payments` | amount(0), method(1), reference(2), recorder(3), date(4), updated(5) |
| `AnnouncementsColumn` | `announcements` | title(0), content(1), grade(2), stream(3), audience(4), author(5), updated(6) |
| `MasteryColumn` | `mastery` | score(0), updated(1) |
| `AiusageColumn` | `aiusage` | allocated(0), used(1), updated(2) |
| `SettingsColumn` | `settings` | data(0), mpesa(1), updated(2) |
| `RolesColumn` | `roles` | name(0), description(1), permissions(2), updated(3) |
| `PlansColumn` | `plans` | name(0), description(1), amount(2), levels(3), status(4), features(5), updated(6) |
| `SubscriptionsColumn` | `subscriptions` | invoice(0), discount(1), status(2), updated(3) |
| `DiscountsColumn` | `discounts` | amount(0), unit(1), updated(2) |

> Tables with no updatable columns (insert/delete only): `owners`, `enrollments`, `scopes` — no column bitset enum exists for these.

## Special File: `curriculum_subjects.dart`

**Not a Drift table.** Contains pure Dart enums defining curriculum-specific subjects:
- `CurriculumType` — `cbc` (index 0), `eightFourFour` (index 1). Has `.index_` and `.label` getters.
- `CbcSubject` — ~104 values. Each has `.index_` (int) and `.label` (String).
- `EightFourFourSubject` — ~50 values. Same pattern.

These are referenced by `lib/models/curriculum_levels.dart` and `lib/models/school_config.dart`.

## Client-Only Table Details

### `accounts` table
- Single-row-active constraint: partial unique index on `is_active` WHERE `is_active = 1`.
- Columns: `id`, `access_token`, `refresh_token`, `token_expiry` (bigint), `is_active` (bool), `last_synced_at` (bigint nullable), `refresh_token_expiry` (bigint), `theme` (smallint → `AppThemeMode`), `created` (bigint), `updated` (bigint), `last_seq` (bigint, client default 0 — server sync sequence number for resumable `WatchRequest`).
- No FK to `users` in the Drift definition (to avoid circular dependency), but logically `id` references `users.id`.

### `logs` table
- Auto-increment integer PK (`id`).
- Columns: `account` (text), `tbl` (smallint → `LogTable`), `op` (smallint → `LogOperation`), `row_key` (text), `columns` (nullable integer — bitmask), `status` (smallint → `LogStatus`), `attempts` (smallint), `error` (nullable text), `created` (bigint).
- Synced rows are **deleted** from this table — it only contains pending/failed work.

## Dependencies

- **Depends on:** `drift` package
- **Depended on by:** `database/database.dart` (registers all tables), `database/daos/` (queries against tables)

## Conventions

- File names are snake_case matching the SQL table name: `students.dart`, `class_teachers.dart`.
- Each file exports exactly one `Table` class (except `enums.dart` and `curriculum_subjects.dart`).
- Enum converters are defined in `enums.dart`, not alongside individual table files.
- Nullable columns use `.nullable()()` in Drift definitions.
- Boolean columns use `BoolColumn` (Drift maps to INTEGER 0/1 automatically).

## Last Updated
Task 1001 — No table definition changes during UI overhaul tracks. All 35 files (34 table + 1 enums) remain current.