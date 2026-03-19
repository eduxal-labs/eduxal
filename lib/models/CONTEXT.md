# models/ — Domain Models Context

> Pure Dart domain models with no Drift or proto dependencies (except for generated data class references where needed for wrapping).
> These models are consumed by the services layer and UI layer.

## Overview

This directory contains **18 files** — each defining one or more pure Dart classes, sealed types, or enums used across the app. Models here never import `package:drift` directly (though some reference Drift-generated data classes like `UsersData`, `AccountsData`, `SchoolsData` from `database/database.dart`).

## Files

| File | Key Exports | Status |
|---|---|---|
| `active_term_context.dart` | `ActiveTermContext` | ✅ Complete |
| `app_notification.dart` | `AppNotification` | ✅ Complete |
| `authenticated.dart` | `Authenticated` | ✅ Complete |
| `permissions.dart` | `Resource`, `Action`, `Permissions` | ✅ Complete |
| `curriculum_levels.dart` | `CurriculumLevel`, `kCbcLevels`, `k844Levels`, `levelsFor()`, `subjectLabel()` | ✅ Complete |
| `exam_group.dart` | `ExamGroup`, `ExamGradeEntry`, `ExamStreamEntry` | ✅ Complete |
| `grade_analytics.dart` | `StreamStats`, `Trajectory`, `SubjectTeacherEntry`, `GradeStudentRow`, `ClassTeacherHistoryEntry` | ✅ Complete |
| `membership.dart` | `MembershipRole`, `MembershipEntry` (sealed), `SchoolMembership` | ✅ Complete |
| `mpesa_config.dart` | `MpesaConfig`, `MpesaEnvironment` | ✅ Complete |
| `plan_features.dart` | `PlanFeature`, `kPlanFeatures`, `GradeLevel`, `GradeLevelGroup`, `gradeLabel()`, `kCbcGroups` | ✅ Complete |
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
- **Fields:** `String schoolId`, `String userId`, `Permissions permissions`.
- **API:** `can(Resource, Action)`, `canAny(Resource, List<Action>)`, `canAll(Resource, List<Action>)` — typed Resource/Action parameters (no more string keys).
- **Factory:** `SchoolPermissions.empty(schoolId, userId)` — for users with no scopes.
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
- `normal` users → [Permissions] bitmask parsed from `roles.permissions` JSON via `Permissions.fromJson`.
- **API:** `can(Resource, Action)`, `canAny(Resource, List<Action>)`, `canAll(Resource, List<Action>)` — typed Resource/Action parameters (no more string keys).
- **Factory:** `SystemPermissions.forUser(UserLevel level, List<RolePermissions> roles)`.
- **Helper type:** `RolePermissions` — `{roleId, roleName, permissionsJson}`.
- **Fix (Task P1):** Removed `|| level == UserLevel.system` shortcut. Only `UserLevel.super_` bypasses.
- **Fix (Task P2):** Replaced `Set<String>` with `Permissions` bitmask model. `can()` signature changed from `can(String)` to `can(Resource, Action)`.

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

## Dependencies

- **Depends on:** `database/database.dart` (for Drift-generated data classes like `UsersData`, `AccountsData`, `SchoolsData`, etc.), `database/tables/enums.dart` (for `AppThemeMode`, `UserLevel`, `SyncAction`, `LogStatus`, etc.), `database/tables/curriculum_subjects.dart` (for `CurriculumType`, `CbcSubject`, `EightFourFourSubject`), `package:flutter/foundation.dart` (only `school_context.dart` and `active_term_context.dart` for `ValueNotifier`/`ChangeNotifier`).
- **Depended on by:** `services/`, `ui/`, `client.dart`, `database/daos/memberships_dao.dart`.

## Conventions

- Models are pure Dart classes — no `package:drift` imports (references to generated classes come via `database/database.dart`).
- Sealed classes are used for discriminated unions (`Result`, `MembershipEntry`, `VerifyResult`).
- Serializable models provide `fromJson` factory + `toJson` method.
- Models that wrap DB rows provide `fromRows` factory + `toCompanion` converter.
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
Grouping model for the exams UI. Multiple exam rows sharing the same `(school, year, term, type, start, end)` are presented as one logical exam.

- **`ExamGroup`** — Top-level grouping. Fields: `school` (String), `year` (int), `term` (int), `type` (ExamType), `start` (int, days since epoch), `end` (int, days since epoch), `personalized` (bool), `teacher` (UsersData), `grades` (List<ExamGradeEntry>). Computed: `groupKey` (unique string key), `examIds` (all exam row IDs), `uniqueSubjectCount` (from papers), `participatingGrades` (sorted grade indices).
- **`ExamGradeEntry`** — One grade within a group. Fields: `grade` (int), `streams` (List<ExamStreamEntry>). Computed: `examIds`, `papers` (flattened).
- **`ExamStreamEntry`** — One exam row + its papers for a specific stream. Fields: `exam` (Exam), `streamCode` (int?), `papers` (List<Paper>).

## Last Updated
Task TW-08 — Model changes for remainder-based lesson scheduling. **Removed from `TimetableRules`:** `defaultLessonsPerWeek` (int field, constructor param, `copyWith` param, `default_lessons_per_week` JSON key), `lessonsPerWeekBySubject` (Map\<int,int\> field, constructor param, `copyWith` param, `lessons_per_week_by_subject` JSON key), `lessonsPerWeekForSubject(id)` helper method. **Added to `TimetableRules`:** `remainderPriority` (Map\<String, List\<int\>\> field) — key `"{grade}_{stream ?? 'null'}"`, value = ordered subject ID list; constructor param `Map<String, List<int>>? remainderPriority` defaulting to `{}`; `copyWith` param; serialised as `remainder_priority` in `toJson`; parsed in `fromJson` v2 path via `raw.map((k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()))`. Previous: Task TW-05 — No structural changes to `timetable_rules.dart`. Verified: `TimetableRules.defaults()` calls `TimetableRules()` which already uses `slots: []` (empty list) as its default — no pre-filled slots.