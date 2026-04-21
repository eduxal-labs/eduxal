# models/ — Domain Models Context

> Pure Dart domain models with no Drift or proto dependencies (except for generated data class references where needed for wrapping).
> These models are consumed by the services layer and UI layer.

## Overview

This directory contains **22 files** — each defining one or more pure Dart classes, sealed types, or enums used across the app. Models here never import `package:drift` directly (though some reference Drift-generated data classes like `UsersData`, `AccountsData`, `SchoolsData` from `database/database.dart`).

## Files

| File | Key Exports | Status |
|---|---|---|
| `active_term_context.dart` | `ActiveTermContext` | ✅ Complete |
| `app_notification.dart` | `AppNotification` | ✅ Complete |
| `authenticated.dart` | `Authenticated` | ✅ Complete |
| `curriculum_levels.dart` | `CurriculumLevel`, `kCbcLevels`, `k844Levels`, `levelsFor()`, `subjectLabel()` | ✅ Complete |
| `exam_group.dart` | `ExamGroup`, `ExamGradeEntry`, `ExamStreamEntry` | ✅ Complete |
| `grade_analytics.dart` | `StreamStats`, `Trajectory`, `SubjectTeacherEntry`, `GradeStudentRow`, `ClassTeacherHistoryEntry` | ✅ Complete |
| `marking_status.dart` | `MarkingPhase`, `MarkingStatus` | ✅ Complete |
| `membership.dart` | `MembershipRole`, `MembershipEntry` (sealed), `SchoolMembership` | ✅ Complete |
| `mpesa_config.dart` | `MpesaConfig`, `MpesaEnvironment` | ✅ Complete |
| `paper_generation.dart` | `TopicAllocation`, `PaperQuestion`, `PaperPdf` | ✅ Complete |
| `permissions.dart` | `Resource`, `Action`, `Permissions` | ✅ Complete |
| `plan_features.dart` | `PlanFeature`, `kPlanFeatures`, `GradeLevel`, `GradeLevelGroup`, `gradeLabel()`, `kCbcGroups` | ✅ Complete |
| `question.dart` | `ImageContext`, `RubricCriterion`, `QuestionImage`, `Question`, `BulkImportResult`, `ImportError` | ✅ Complete |
| `question_grade.dart` | `RubricResult`, `QuestionGradeDetail` | ✅ Complete |
| `result.dart` | `Result<T, E>` (sealed), `Ok<T, E>`, `Err<T, E>` | ✅ Complete |
| `school_config.dart` | `GradeStream`, `GradeConfig`, `CurriculumConfig`, `SchoolConfig`, `kCbcGradeLabels`, `kEightFourFourGradeLabels`, `gradeLabelsFor()` | ✅ Complete |
| `school_context.dart` | `SchoolContext` | ✅ Complete |
| `school_permissions.dart` | `SchoolPermissions` | ✅ Complete |
| `setup_result.dart` | `SetupResult` | ✅ Complete |
| `system_permissions.dart` | `SystemPermissions`, `RolePermissions` | ✅ Complete |
| `system_stats.dart` | `CurrentTerm`, `StatSegment`, `UserStats`, `SchoolStats`, `StudentStats`, `PlanSubscriptionCount`, `StudentPlanStats`, `TeacherStats`, `SubscriptionStats`, `RevenueStats` | ✅ Complete |
| `timetable_rules.dart` | `TimetableRules`, `TeacherBlockRule`, `SubjectBlockRule` | ✅ Complete |
| `verify_result.dart` | `VerifyResult` (sealed), `VerifyResultAuthenticated`, `VerifyResultRegistered` | ✅ Complete |

## Key Types — Detailed

### Grade Analytics Models — `grade_analytics.dart`
Pure domain models for the Grade Detail page. All reference Drift-generated data classes via `database/database.dart`.

- **`StreamStats`** — Statistics for one stream within a grade (Comparisons tab). Fields: `streamCode` (int), `streamName` (String), `studentCount` (int), `averageScore` (double), `lastExamAverage` (double?), `trajectory` (Trajectory), `attendanceRate` (double?), `masteryAverage` (double?).
- **`Trajectory`** — Enum: `improving`, `declining`, `stable`, `insufficientData`. Used for both stream-level and student-level trend indicators.
- **`SubjectTeacherEntry`** — One row on the Subjects tab: a subject taught in a specific stream by a specific teacher. Fields: `subject` (Subject), `streamCode` (int), `streamName` (String), `teacher` (UsersData), `streamMasteryAverage` (double?), `gradeMasteryAverage` (double?).
- **`GradeStudentRow`** — One student row on the Students tab, enriched with trajectory. Fields: `student` (StudentsData), `enrollment` (Enrollment), `trajectory` (Trajectory), `lastExamPercent` (double?), `overallAverage` (double?).
- **`ClassTeacherHistoryEntry`** — One class teacher assignment for the Teachers tab. Fields: `classTeacher` (ClassTeacher), `user` (UsersData), `isActive` (bool — true when `classTeacher.end` is null).

### `Result<T, E>` — `result.dart`
Sealed discriminated union for success/failure. Used as return type for all service methods.
- `Ok<T, E>` — carries `.value` of type `T`.
- `Err<T, E>` — carries `.error` of type `E`.
- Consumed via `switch` expression in UI. Convention: `E` is typically `GrpcError`.

### `Authenticated` — `authenticated.dart`
Domain model for the currently authenticated user session. Wraps a `UsersData` row (identity) alongside session fields from `AccountsData` (tokens, expiry, sync state, theme).
- **Factory:** `Authenticated.fromRows(AccountsData account, UsersData user)` — constructs from two Drift-generated data classes.
- **Converters:** `toAccountCompanion({bool isActive})` → `AccountsCompanion`, `toUserCompanion()` → `UsersCompanion`.
- **Token checks:** `isTokenExpired` (getter, compares `tokenExpiry` to `now`), `isRefreshTokenExpired` (compares `refreshTokenExpiry` to `now`).
- **Fields:** `user` (UsersData), `accessToken`, `refreshToken`, `tokenExpiry` (int, ms epoch), `refreshTokenExpiry` (int, ms epoch), `lastSyncedAt` (int?, ms epoch), `lastSeq` (int, default 0 — server sync sequence number for resumable `WatchRequest`), `theme` (AppThemeMode), `created` (int, ms epoch), `updated` (int, ms epoch).
- **Note:** This is NOT the proto-generated `Authenticated` message. The proto class is only used as a deserialization target in `services/authentication.dart`.

### `MembershipRole` / `MembershipEntry` / `SchoolMembership` — `membership.dart`
Home screen membership model.
- `MembershipRole` enum: `owner`, `teacher`, `staff`, `student`, `guardian`.
- `MembershipEntry` sealed class with 5 subtypes:
  - `OwnerEntry` — has `OwnersData owner`.
  - `TeacherEntry` — has `TeachersData teacher`, `int subjectCount`.
  - `StaffEntry` — has `StaffData staff`.
  - `StudentEntry` — has `StudentsData student`.
  - `GuardianEntry` — has `GuardiansData guardian`, `StudentsData ward`.
- `SchoolMembership` — groups all entries for a single school: `SchoolsData school`, `List<MembershipRole> roles`, `List<MembershipEntry> entries`, `bool hasSingleEntry`.
- **Import note:** `membership.dart` imports `database/database.dart` for generated data classes. To avoid circular imports, `MembershipsDao` is excluded from `@DriftDatabase(daos: [...])`.

### `SchoolContext` — `school_context.dart`
In-memory session object for a user's active school dashboard visit.
- **Fields:** `SchoolMembership membership`, `SchoolPermissions permissions`, `ValueNotifier<MembershipEntry> currentEntry`.
- **Methods:** `switchEntry(MembershipEntry)`, `dispose()`.
- **Lifecycle:** Created on school entry, provided via InheritedWidget/provider, disposed on route pop. Never persisted.
- **Key property:** `permissions` is computed once on entry and constant for the session. `currentEntry` changes trigger UI rebuilds via `ValueListenableBuilder`.

### `SchoolPermissions` — `school_permissions.dart`
Aggregated permission set for a user at a specific school. Now wraps [Permissions] bitmask model.
- **Fields:** `String schoolId`, `String userId`, `Permissions permissions`, `UserLevel _level` (private, exposed via `level` getter).
- **Super bypass (Task B2):** When `_level == UserLevel.super_`, `can()`, `canAny()`, and `canAll()` return `true` unconditionally — even if the underlying `permissions` bitmask is empty. Mirrors the pattern in `SystemPermissions`.
- **API:** `can(Resource, Action)`, `canAny(Resource, List<Action>)`, `canAll(Resource, List<Action>)` — typed Resource/Action parameters. `level` getter exposes the user level.
- **Constructor:** `SchoolPermissions({schoolId, userId, permissions, level})` — `level` defaults to `UserLevel.normal`.
- **Factory:** `SchoolPermissions.empty(schoolId, userId, {level})` — for users with no scopes. Also accepts optional `level` for Super bypass.
- **Import:** `UserLevel` from `../database/tables/enums.dart`.
- **Call sites updated (Task B2):** `SchoolScopesDao.getAggregatedPermissions()` and `watchAggregatedPermissions()` now pass `level: userLevel` to the constructor.
- **Fix (Task P2):** Replaced `Set<String>` with `Permissions` bitmask model. Construction site in `school_dashboard_screen.dart` updated to use `Permissions.fromJson` + `union()`.

### `Permissions` / `Resource` / `Action` — `permissions.dart`
Bitmask-based permission model. See AGENT.md §17a.
- **`Resource` enum** — 18 logical resources: `users`, `schools`, `owners`, `teachers`, `staff`, `students`, `departments`, `classes`, `attendance`, `lessons`, `exams`, `grades`, `fees`, `payments`, `announcements`, `roles`, `plans`, `ai`. Each has a `label` getter and `applicableActions` list for UI display.
- **`Action` enum** — 9 actions with bit positions: `create(0)`, `read(1)`, `update(2)`, `delete(3)`, `purge(4)`, `assign(5)`, `unassign(6)`, `mark(7)`, `approve(8)`. Each has `bit`, `mask`, and `label` getters.
- **`Permissions` class** — holds `Map<Resource, int>` where `int` is a u16 action bitmask.
  - `can(Resource, Action)` — O(1) bitmask check.
  - `canAny(Resource, List<Action>)` — any match.
  - `canAll(Resource, List<Action>)` — all match.
  - `maskFor(Resource)` — raw bitmask.
  - `actionsFor(Resource)` — list of granted actions.
  - `union(Permissions)` — OR merge for aggregating multiple roles.
  - `Permissions.fromBlob(Uint8List?)` — decode binary blob from `roles.permissions`.
  - `toBlob()` — encode to binary blob.
  - `Permissions.fromJson(dynamic)` — parse legacy JSON (list of `{resource, actions}` objects or flat `"resource.action"` map).
  - `Permissions.empty()` — const constructor, no permissions.
- **Private helpers:** `_resourceFromName(String)` maps resource names + aliases to `Resource` enum. `_actionFromName(String)` maps action names + aliases to `Action` enum.

### `SystemPermissions` — `system_permissions.dart`
System-level permissions with level-based shortcuts. Now wraps [Permissions] bitmask model.
- `super_` users → all permissions granted unconditionally (bypass).
- `system` users → roles parsed and permissions enforced, same as normal users but with system-scoped roles (where `scopes.school IS NULL`). **Not** treated as super users.
- `normal` users → [Permissions] bitmask parsed from `roles.permissions` (now a `blob()` column storing `Uint8List`) via `parsePermissionsBlob()` from `lib/core/permission_parser.dart`.
- **API:** `can(Resource, Action)`, `canAny(Resource, List<Action>)`, `canAll(Resource, List<Action>)` — typed Resource/Action parameters (no more string keys).
- **Factory:** `SystemPermissions.forUser(UserLevel level, List<RolePermissions> roles)`.
- **Helper type:** `RolePermissions` — `{roleId, roleName, permissionsData}` where `permissionsData` is `Uint8List` (changed from `String` in Task A01).
- **Fix (Task P1):** Removed `|| level == UserLevel.system` shortcut. Only `UserLevel.super_` bypasses.
- **Fix (Task P2):** Replaced `Set<String>` with `Permissions` bitmask model. `can()` signature changed from `can(String)` to `can(Resource, Action)`.
- **Fix (Task A2):** `forUser()` now uses `parsePermissionsBlob()` (from `lib/core/permission_parser.dart`) instead of raw `jsonDecode` + `Permissions.fromJson`. Handles the canonical binary blob format and falls back to legacy text formats for migration compatibility. Logs warnings via `debugPrint` instead of silently swallowing parse failures.
- **Fix (Task A01):** `RolePermissions.permissionsData` changed from `String` to `Uint8List` to match the `roles.permissions` blob column. `forUser()` switched from `parsePermissions()` to `parsePermissionsBlob()`.

### `ActiveTermContext` — `active_term_context.dart`
In-memory session object tracking which academic term the user is viewing.
- **Fields:** `String schoolId`, `List<Term> allTerms` (unmodifiable), `ValueNotifier<Term?> termNotifier`.
- **Methods:** `setTerm(Term)`, `updateTerms(List<Term>)` (called when Drift stream emits).
- **Convenience:** `currentYear`, `currentTermNumber`, `currentTermLabel`, `hasTerms`, `isSelected(Term)`.
- Extends `ChangeNotifier`. Disposed when school route is popped.

### `SchoolConfig` — `school_config.dart`
Top-level settings config stored in `settings.data` JSON (version 2).
- `SchoolConfig` → has `List<CurriculumConfig> curricula`. Methods: `isEmpty`, `hasCbc`, `has844`, `configFor(CurriculumType)`.
- `CurriculumConfig` → has `CurriculumType type`, `List<GradeConfig> grades`.
- `GradeConfig` → has `int grade`, `List<GradeStream> streams`.
- `GradeStream` → has `String name`, `int code`.
- Grade label maps: `kCbcGradeLabels` (Map<int, String>), `kEightFourFourGradeLabels`, `gradeLabelsFor(CurriculumType)`.
- **Shared helpers (top-level functions):**
  - `CurriculumType curriculumForGrade(int grade, {Set<int> allGrades})` — determines curriculum type from a grade number. Grades ≥41 → 8-4-4, ≥9 → CBC, 1–8 resolved by checking `allGrades` for 8-4-4 markers (defaults to CBC).
  - `SchoolConfig buildConfigFromStreams(List<SchoolStream> allStreams)` — converts raw `SchoolStream` rows (from `CatalogDao.watchAllStreamsForSchool`) into a `SchoolConfig`, grouping by curriculum type and grade. Previously duplicated across `announcements_screen.dart`, `exams_grades_screen.dart`, `exams_tab.dart`; now centralized here.

### `VerifyResult` — `verify_result.dart`
Sealed union returned by `Authentication.verify()`:
- `VerifyResultAuthenticated` — existing user, has `Authenticated authenticated`, `String? profileUploadUrl`.
- `VerifyResultRegistered` — new user, has `String token` (short-lived registration token for setup).

### `SetupResult` — `setup_result.dart`
Returned by `Authentication.setup()`: `Authenticated authenticated`, `String? profileUploadUrl`.

### `MpesaConfig` — `mpesa_config.dart`
M-Pesa Daraja API configuration for a school. Serializable to/from JSON.
- Sensitive fields: `consumerKey`, `consumerSecret`, `passkey` (displayed as `•••••`).
- Non-sensitive: `shortCode`, `accountReference`, `callbackUrl`, `MpesaEnvironment environment`, `bool enabled`.
- `isConfigured` — true when all required fields non-empty.
- `MpesaEnvironment` enum: `sandbox`, `production`.

### `AppNotification` — `app_notification.dart`
Display model for failed log entries shown in the notifications panel.
- Fields: `logId` (int), `SyncAction action`, `String resource` (human-readable display key), `errorMessage` (String?), `attempts` (int), `DateTime occurred`.
- Helpers: `title` (e.g. "Sync failed — Create Teacher"), `subtitle` (error message or attempt count).
- Private: `_actionName(SyncAction)` — maps all 77 `SyncAction` values to human-readable names.

### `CurriculumLevel` / level data — `curriculum_levels.dart`
Defines all CBC and 8-4-4 levels with their valid subject lists.
- `CurriculumLevel` — `{index, label, subjects}` (list of int subject indices).
- `kCbcLevels` — 6 levels (Lower Primary through 3 Senior Secondary pathways; PP1/PP2 index 0 removed per §P8).
- `k844Levels` — 4 levels (Lower/Upper Primary, Forms 1-2, Forms 3-4).
- `levelsFor(CurriculumType)`, `subjectLabel(CurriculumType, int)`.

### Stats models — `system_stats.dart`
System dashboard aggregate statistics. All have `static const empty` for initial state.
- `CurrentTerm` — `{year, term, startEpochSecs, endEpochSecs}`, computed `label`, `startDays`, `endDays`.
- `StatSegment` — `{label, value}` for chart rendering.
- `UserStats`, `SchoolStats`, `StudentStats`, `TeacherStats`, `SubscriptionStats`, `RevenueStats` — status-grouped counts.
- `StudentPlanStats`, `PlanSubscriptionCount` — per-plan subscription breakdown for donut chart.

### Plan features — `plan_features.dart`
- `PlanFeature` — `{key, title, description}`.
- `kPlanFeatures` — const list of 10 features (attendance, timetable, notifications, AI, fees, etc.).
- `GradeLevel` enum — 16 values with `bit`, `label`, `description`, `mask` for bitmask encoding.
- `GradeLevelGroup`, `kCbcGroups` — groupings for UI display.

### Question Bank models — `question.dart`
Domain models for the AI question bank. All have `fromProto` factories mapping from proto-generated types in `question_bank.pb.dart`. Imports: `proto/services/question_bank.pb.dart`, `question_bank.pbenum.dart`.

- **`ImageContext`** — Enum: `question`, `rubric`, `exampleAnswer`. Maps from proto `ImageContext` (QUESTION=0, RUBRIC=1, EXAMPLE_ANSWER=2).
- **`RubricCriterion`** — One rubric criterion with mark allocation. Fields: `criterion` (String), `marks` (int). Factory: `fromProto(pb.RubricCriterion)`.
- **`QuestionImage`** — Image attached to a question. Fields: `context` (ImageContext), `filename` (String), `caption` (String?), `description` (String), `getUrl` (String? — populated after upload or from server). Factory: `fromProto(pb.QuestionImage)`.
- **`Question`** — A question in the question bank. Fields: `id` (int), `topicId` (int), `text` (String), `marks` (int), `rubric` (List\<RubricCriterion\>), `exampleAnswer` (String?), `images` (List\<QuestionImage\>), `created` (DateTime), `updated` (DateTime). Factory: `fromProto(pb.Question)` — proto `created`/`updated` are Int64 seconds since epoch, converted via `DateTime.fromMillisecondsSinceEpoch(proto.field.toInt() * 1000)`.
- **`BulkImportResult`** — Result of bulk import. Fields: `createdCount` (int), `questionIds` (List\<int\> — server-assigned IDs for uploaded questions, used for image upload), `errors` (List\<ImportError\>). Factory: `fromProto(pb.BulkImportResponse)`.
- **`ImportError`** — Single error from bulk import. Fields: `index` (int), `message` (String). Factory: `fromProto(pb.ImportError)`.

### Paper Generation models — `paper_generation.dart`
Domain models for AI paper generation flow. Imports `question.dart` for `RubricCriterion` and `QuestionImage`, plus `proto/services/question_bank.pb.dart` and `package:fixnum/fixnum.dart` (for `Int64.ZERO` comparisons).

- **`TopicAllocation`** — Topic with mark allocation for paper generation. Fields: `topicId` (int), `topicName` (String — display only, not sent to server), `marks` (int, mutable, default 0). No `fromProto` — constructed locally by the UI.
- **`PaperQuestion`** — Generated question for a paper before finalization. Fields: `id` (String — server-assigned temp ID), `questionId` (int), `text` (String), `marks` (int), `rubric` (List\<RubricCriterion\>), `images` (List\<QuestionImage\>), `order` (int). Factory: `fromProto(pb.PaperQuestion)`.
- **`PaperPdf`** — Result of paper finalization with PDF URL. Fields: `pdfUrl` (String), `pdfExpiry` (DateTime). Factories: `fromProto(pb.FinalizePaperResponse)`, `fromGetPdfProto(pb.GetPaperPdfResponse)` — both convert Int64 seconds to DateTime.
- **`StreamCopyResult`** — Result for a single target stream in a `copyPaperToStreams` operation. Fields: `stream` (int), `success` (bool), `pdfUrl` (String?), `pdfExpiry` (DateTime?), `markingSchemeUrl` (String?), `markingSchemeExpiry` (DateTime?), `error` (String?). Factory: `fromProto(pb.StreamCopyResult)` — checks `Int64.ZERO` for expiry fields, empty string for optional string fields.

### Marking Status models — `marking_status.dart`
Domain models for AI marking job status polling. Imports: `proto/services/question_bank.pb.dart`, `question_bank.pbenum.dart`.

- **`MarkingPhase`** — Enum: `queued`, `downloading`, `marking`, `computing`, `complete`, `failed`. Mapped from proto `MarkingStatusEnum` (0–5).
- **`MarkingStatus`** — Status of an AI marking job. Fields: `phase` (MarkingPhase), `progressCurrent` (int), `progressTotal` (int), `errorMessage` (String?). Computed: `progressFraction` (double, 0.0–1.0), `displayLabel` (String — human-readable status text). Factory: `fromProto(pb.MarkingStatusResponse)`.

### Question Grade models — `question_grade.dart`
Domain models for per-question AI marking results. Import: `proto/services/question_bank.pb.dart`.

- **`RubricResult`** — Per-rubric-criterion result from AI marking. Fields: `criterion` (String), `satisfied` (bool), `marksAwarded` (double), `marksAvailable` (int). Factory: `fromProto(pb.RubricResult)`.
- **`QuestionGradeDetail`** — Per-question grade breakdown. Fields: `questionText` (String), `marksAwarded` (double), `totalMarks` (int), `feedback` (String), `rubricResults` (List\<RubricResult\>). Factory: `fromProto(pb.QuestionGrade)`.

## Dependencies

- **Depends on:** `database/database.dart` (for Drift-generated data classes like `UsersData`, `AccountsData`, `SchoolsData`, etc.), `database/tables/enums.dart` (for `AppThemeMode`, `UserLevel`, `SyncAction`, `LogStatus`, etc.), `database/tables/curriculum_subjects.dart` (for `CurriculumType`, `CbcSubject`, `EightFourFourSubject`), `package:flutter/foundation.dart` (only `school_context.dart` and `active_term_context.dart` for `ValueNotifier`/`ChangeNotifier`), `proto/services/question_bank.pb.dart` and `question_bank.pbenum.dart` (for question bank model `fromProto` factories).
- **Depended on by:** `services/`, `ui/`, `client.dart`, `database/daos/memberships_dao.dart`.

## Conventions

- Models are pure Dart classes — no `package:drift` imports (references to generated classes come via `database/database.dart`).
- Sealed classes are used for discriminated unions (`Result`, `MembershipEntry`, `VerifyResult`).
- Serializable models provide `fromJson` factory + `toJson` method.
- Models that wrap DB rows provide `fromRows` factory + `toCompanion` converter.
- Models that wrap proto messages provide `fromProto` factory (used in question bank models).
- No business logic in models — they are data holders with computed getters only.

### `TimetableRules` / `TimetableSlot` / `TeacherConstraintEntry` / `SubjectConstraintEntry` — `timetable_rules.dart`
Generation constraints for the timetable solver — **slot-based model (v2)**.
- **`SlotType`** enum — `lesson` | `breakSlot`. Distinguishes bookable lesson periods from non-schedulable gaps.
- **`TimetableSlot`** — one element in the ordered school-day sequence. Fields: `type` (SlotType), `durationMinutes` (int). Start times are **derived**, not stored: computed from `TimetableRules.dayStartTime` + cumulative preceding-slot durations. Serialisable via `toJson`/`fromJson`.
- **`TimetableRules`** — top-level config object. Fields: `dayStartTime` (TimeOfDay), `slots` (List\<TimetableSlot\> — ordered day sequence), `activeDays` (List\<int\>, 1=Mon…7=Sun), `maxLessonsPerDayTeacher` (int), `maxLessonsPerDayClass` (int), `allowDoubles` (bool), `remainderPriority` (Map\<String, List\<int\>\>), `teacherConstraints` (List\<TeacherConstraintEntry\>), `subjectConstraints` (List\<SubjectConstraintEntry\>). Key helpers: `buildLessonSlots()` — returns ordered list of `({int index, int start, int end})` for lesson-only slots with computed times (seconds since midnight). Serialised as JSON (version: 2) at `{appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json`. Legacy v1 format cannot be migrated and silently falls back to `defaults()`. `copyWith` pattern. Factory `TimetableRules.defaults()`.
- **`remainderPriority`** — `Map<String, List<int>>`. Key format: `"{grade}_{stream}"` (e.g. `"44_1"`) or `"{grade}_null"` for un-streamed grades. Value: ordered list of subject IDs — the first `remainder` subjects in this list receive one extra lesson per week beyond the base allocation (`base = totalPerWeek ~/ subjectCount`, `remainder = totalPerWeek % subjectCount`). Absent keys fall back to ascending subject-ID order. Serialised as `remainder_priority` in JSON v2.
- **Removed (TW-08):** `defaultLessonsPerWeek` (int), `lessonsPerWeekBySubject` (Map\<int,int\>), `lessonsPerWeekForSubject(id)`. Weekly lesson counts are now fully derived by the generator via `_computeLessonsPerWeek()` using the slot sequence and `remainderPriority`.
- **`TeacherConstraintEntry`** — per-teacher scheduling constraint. Fields: `teacherId` (String UUID), `days` (List\<int\>, weekday indices), `slotIndices` (List\<int\>, 0-based indices into `TimetableRules.slots`), `isBlock` (bool — `true` = blocked from those slots; `false` = requirement, only allowed in those slots). Serialisable.
- **`SubjectConstraintEntry`** — per-subject scheduling constraint. Fields: `subjectId` (int, global catalog PK), `days`, `slotIndices`, `isBlock`. Same block/requirement semantics as `TeacherConstraintEntry`. Serialisable.
- **Removed** (v1 model): `TeacherBlockRule`, `SubjectBlockRule`, `dayStartSeconds`, `dayEndSeconds`, `lessonDurationMinutes`, `breakDurationMinutes`, `lunchStartSeconds`, `lunchDurationMinutes`, `buildSlots()`.

### Exam Group models — `exam_group.dart`
Grouping model for the exams UI. Multiple exam rows sharing the same name are presented as one logical exam.

- **`ExamGroup`** — Top-level grouping. Fields: `name` (String — exam display name, used as the grouping key), `school` (String), `year` (int), `term` (int), `type` (ExamType), `start` (int, days since epoch), `end` (int, days since epoch), `personalized` (bool), `teacher` (UsersData), `grades` (List<ExamGradeEntry>). Computed: `groupKey` (`'$school|$year|$term|$name'`), `examIds` (all exam row IDs), `uniqueSubjectCount` (from papers), `participatingGrades` (sorted grade indices).
- **`ExamGradeEntry`** — One grade within a group. Fields: `grade` (int), `streams` (List<ExamStreamEntry>). Computed: `examIds`, `papers` (flattened).
- **`ExamStreamEntry`** — One exam row + its papers for a specific stream. Fields: `exam` (Exam), `streamCode` (int?), `papers` (List<Paper>).

## Last Updated
Task P05 — Added `StreamCopyResult` class to `paper_generation.dart`. Added `import 'package:fixnum/fixnum.dart' show Int64;` to support `Int64.ZERO` comparisons in `fromProto`. Factory maps proto optional Int64 expiry fields via zero-check and optional string fields via empty-string check.

Previous:
Task 01 — Added `questionIds` (List\<int\>) field to `BulkImportResult` in `question.dart` for server-assigned question IDs used in image upload flow.