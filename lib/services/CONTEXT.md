# services/ — Business Logic Layer Context

> One file per domain. Services orchestrate DAO reads/writes + gRPC calls and expose `Stream<T>` / `Future<Result<T, E>>` to the UI layer.
> Services are the **only** place where business logic lives. UI code never calls DAOs or gRPC directly.

## Overview

This directory contains **8 service files**. Services sit between the UI and the data layer (DAOs + gRPC). They:
- Combine multiple DAO calls into transactional operations.
- Map between proto types and domain models.
- Write to the `logs` table alongside every synced-table mutation.
- Trigger `sync.pushNow()` (fire-and-forget) after every mutation that writes to the `logs` table, so changes reach the server as fast as possible. This is handled at the DAO level — every DAO method that writes a log entry calls `sync.pushNow()` after the transaction completes. Services and UI code benefit automatically.
- Return `Result<T, GrpcError>` for fallible operations and `Stream<T>` for reactive queries.

## Files

| File | Key Exports | Domain | Status |
|---|---|---|---|
| `authentication.dart` | `Authentication` | Login, verify, setup, refresh, change phone | ✅ Complete |
| `members.dart` | `MemberCreationService` | Phone-first member creation (owners, teachers, staff, students, guardians) + profile image saving | ✅ Complete |
| `member_management.dart` | `MemberManagementService` | Post-creation lifecycle: edit fields, change status, remove members (all types) | ✅ Complete |
| `ai_marking.dart` | `AiMarkingService` | AI-powered paper marking: request presigned S3 PUT URLs, upload files, trigger server-side AI marking. Wraps `AiMarking` gRPC service. | ✅ Complete |
| `question_bank.dart` | `QuestionBankService` | Question bank operations: CRUD for questions within topics, bulk import from JSON, presigned S3 upload URLs for question images. Wraps `QuestionBank` gRPC service. | ✅ Complete |
| `timetable_generator.dart` | `TimetableGenerator`, `TimetableSlot`, `GeneratorResult`, `GeneratorSuccess`, `GeneratorFailure`, `GeneratorInput`, `runTimetableGenerator` | Pure-Dart CSP backtracking solver for timetable generation. No Flutter dependencies. Run via `compute(runTimetableGenerator, input)`. | ✅ Complete |
| `import_file_parser.dart` | `ParsedImportFile`, `MissingImage`, `parseImportFile` | Pure-Dart utility for parsing and validating question bank JSON files for bulk import. Zero Flutter/UI dependencies. | ✅ Complete |

## Key Methods by Service

### `TimetableGenerator` — `timetable_generator.dart`

Pure-Dart backtracking CSP solver. No Flutter dependencies — safe to run on a background isolate via `compute()`.

**Constructor:** `TimetableGenerator({required assignments, required rules, maxRestarts = 5, Random? random})`

**Entry point:** `generate() → GeneratorResult` — runs three phases:
1. **Validation** — checks for empty assignments, blocked teachers, impossible configs. Returns `GeneratorFailure` immediately if any hard constraint is unsatisfiable.
2. **Domain construction + backtracking search** — builds a domain of `(day, slot)` pairs per variable, shuffles for variety, then runs recursive backtracking with MRV heuristic and forward-checking propagation. Retries up to `maxRestarts` times with freshly shuffled domains.
3. **Soft scoring** — penalises teacher free gaps (+2), duplicate subject on same day for a class (+1), and highly uneven day distribution for a class (+3). Score is informational only in the MVP.

Returns `GeneratorSuccess` (with `slots`, `softScore`, `iterations`, `elapsed`) or `GeneratorFailure` (with `reason` and `conflicts` list).

**Private helpers:**
- `_validate() → List<String>` — returns human-readable conflict messages; empty = valid input.
- `_buildDomains(variables, slots) → Map<_Variable, List<_Slot>>` — filters Cartesian product of `activeDays × buildSlots()` by teacher and subject block rules.
- `_solve(unassigned, assignment, domains) → Map<_Variable, _Slot>?` — recursive backtracking; MRV variable selection; deep-copies domains per iteration for safe backtracking.
- `_isConsistent(variable, slot, assignment) → bool` — enforces hard constraints: teacher double-booking, class double-booking, daily load caps, double-lesson rule.
- `_propagate(placed, slot, remaining, domains) → bool` — forward checking; prunes `(day, start)` from all peers sharing teacher or class; returns `false` on wipe-out.
- `_softScore(assignment) → int` — computes soft penalty score on the complete solution.

**Top-level wrapper:** `runTimetableGenerator(GeneratorInput) → GeneratorResult` — for use with `compute()`.

**Input container:** `GeneratorInput({required assignments, required rules, maxRestarts = 5})` — all plain Dart types, safe across isolate boundaries.

**Dependencies:** `dart:math`, `database/daos/timetable_dao.dart` (for `SolverAssignment`), `database/tables/enums.dart` (for `DayOfWeek`), `models/timetable_rules.dart` (for `TimetableRules`, `TeacherBlockRule`, `SubjectBlockRule`).

---


### `Authentication` — `authentication.dart`

gRPC wrapper for the Authentication service. All methods are unary gRPC calls.

**Constructor:** `Authentication(ClientChannel channel, UsersDao usersDao)`

| Method | Signature | Description |
|---|---|---|
| `login` | `Future<Result<void, GrpcError>> login(String phone)` | Sends OTP to phone number. Returns `Ok(void)` on success. |
| `verify` | `Future<Result<VerifyResult, GrpcError>> verify(String phone, String code)` | Verifies OTP. Returns `VerifyResultAuthenticated` (existing user) or `VerifyResultRegistered` (new user needing setup). |
| `setup` | `Future<Result<SetupResult, GrpcError>> setup(String token, String name)` | Completes new user registration. Returns `SetupResult` with `Authenticated` + optional `profileUploadUrl`. |
| `refresh` | `Future<Result<Authenticated, GrpcError>> refresh()` | Refreshes access token using the global `refreshToken`. Updates the `users` table via `UsersDao` on success. |
| `changePhone` | `Future<Result<void, GrpcError>> changePhone(String newPhone)` | Initiates phone number change — sends OTP to new phone. |
| `confirmChangePhone` | `Future<Result<Authenticated, GrpcError>> confirmChangePhone(String newPhone, String code)` | Confirms phone change with OTP. Returns updated `Authenticated`. |

**Internal helpers:**
- `_toUnavailable(Object e, StackTrace st) → GrpcError` — Wraps non-gRPC exceptions as `StatusCode.unavailable`.
- `_mapProtoAuthenticated(proto.Authenticated msg) → Authenticated` — Maps proto `Authenticated` message to domain model. Creates `UsersData` from proto `User`, constructs `Authenticated` with tokens and expiry.
- `_downloadProfileIfPresent(proto.Authenticated msg, String userId) → Future<void>` — Downloads profile image to `FileCache.profilePath(userId)` if the proto message contains a read URL.

**Dependencies:** `grpc` package, `proto/services/authentication.pbgrpc.dart`, `proto/types/user.pb.dart`, `database/daos/users_dao.dart`, `models/authenticated.dart`, `models/result.dart`, `models/verify_result.dart`, `models/setup_result.dart`, `cache/file_cache.dart`, `core/constants.dart`, `client.dart` (for global `accessToken`, `refreshToken`).

---

### `MemberManagementService` — `member_management.dart`

Handles post-creation lifecycle actions for all member types: editing fields, changing status, and removing members.

**Constructor:** `MemberManagementService(MembersDao dao)`

**Error type (defined in same file):**
- `MemberActionError` — enum: `noActiveAccount`, `notFound`, `databaseError`, `cannotRemoveSelf`, `permissionDenied`.

All mutation methods accept an optional `SchoolPermissions? permissions` parameter for defense-in-depth RBAC enforcement. When provided, the method checks the caller has the required `Resource`/`Action` before proceeding; when `null`, the check is skipped (backward compatible with existing callers).

| Method | Signature | Permission Guard | Description |
|---|---|---|---|
| `updateTeacher` | `Future<Result<void, MemberActionError>> updateTeacher({required String schoolId, required String userId, String? role, String? department, DateTime? hiredDate, SchoolPermissions? permissions})` | `Resource.teachers` / `Action.update` | Updates mutable fields on a teacher row. Only non-null params are written. |
| `changeTeacherStatus` | `Future<Result<void, MemberActionError>> changeTeacherStatus({required String schoolId, required String userId, required TeacherStatus status, SchoolPermissions? permissions})` | `Resource.teachers` / `Action.update` | Changes a teacher's status (e.g. active → resigned). |
| `removeTeacher` | `Future<Result<void, MemberActionError>> removeTeacher({required String schoolId, required String userId, SchoolPermissions? permissions})` | `Resource.teachers` / `Action.delete` | Removes a teacher from a school. |
| `updateStaff` | `Future<Result<void, MemberActionError>> updateStaff({required String schoolId, required String userId, String? role, String? department, String? idNumber, SchoolPermissions? permissions})` | `Resource.staff` / `Action.update` | Updates mutable fields on a staff row. |
| `changeStaffStatus` | `Future<Result<void, MemberActionError>> changeStaffStatus({required String schoolId, required String userId, required StaffStatus status, SchoolPermissions? permissions})` | `Resource.staff` / `Action.update` | Changes a staff member's status. |
| `removeStaff` | `Future<Result<void, MemberActionError>> removeStaff({required String schoolId, required String userId, SchoolPermissions? permissions})` | `Resource.staff` / `Action.delete` | Removes a staff member from a school. |
| `removeOwner` | `Future<Result<void, MemberActionError>> removeOwner({required String schoolId, required String userId, SchoolPermissions? permissions})` | `Resource.owners` / `Action.delete` | Removes an owner. Returns `cannotRemoveSelf` if caller tries to remove themselves. |
| `updateStudent` | `Future<Result<void, MemberActionError>> updateStudent({required String schoolId, required int adm, String? name, DateTime? dob, Gender? gender, String? phone, SchoolPermissions? permissions})` | `Resource.students` / `Action.update` | Updates mutable fields on a student row. |
| `changeStudentStatus` | `Future<Result<void, MemberActionError>> changeStudentStatus({required String schoolId, required int adm, required StudentStatus status, SchoolPermissions? permissions})` | `Resource.students` / `Action.update` | Changes a student's status (e.g. active → expelled). |
| `removeStudent` | `Future<Result<void, MemberActionError>> removeStudent({required String schoolId, required int adm, SchoolPermissions? permissions})` | `Resource.students` / `Action.delete` | Removes a student from a school. Hard-deletes the row locally and enqueues a `SyncAction.deleteStudent` log. |
| `updateGuardian` | `Future<Result<void, MemberActionError>> updateGuardian({required String schoolId, required String userId, required int studentAdm, GuardianRelationship? relationship, GuardianRole? role, SchoolPermissions? permissions})` | `Resource.students` / `Action.update` | Updates mutable fields on a guardian row. Guardians fall under Students resource per §17a. |
| `removeGuardian` | `Future<Result<void, MemberActionError>> removeGuardian({required String schoolId, required String userId, required int studentAdm, SchoolPermissions? permissions})` | `Resource.students` / `Action.delete` | Removes a guardian link from a student. Guardians fall under Students resource per §17a. |

**Internal helpers:**
- `_dateToDaysSinceEpoch(DateTime date) → int` — static helper converting DateTime to days since epoch for date columns.

**Dependencies:** `database/daos/members_dao.dart`, `database/database.dart` (for generated companion types), `database/tables/enums.dart`, `models/result.dart`, `models/permissions.dart`, `models/school_permissions.dart`, `client.dart` (for global `cache`).

---

### `MemberCreationService` — `members.dart`

Handles the phone-first member creation flow for all school member types + profile image handling.

**Constructor:** `MemberCreationService(MembersDao dao)`

**Phone lookup types (defined in same file):**
- `PhoneLookupResult` — sealed class.
  - `UserFound` — has `UsersData user`.
  - `UserNotFound` — has `String phone`.
- `MemberCreationError` — enum: `alreadyExists`, `invalidPhone`, `userNotFound`, `databaseError`, `studentAdmExists`, `guardianExists`.

| Method | Signature | Description |
|---|---|---|
| `lookupPhone` | `Future<PhoneLookupResult> lookupPhone(String phone)` | Normalizes phone via `toKenyanPhone()`, queries `users` by phone. Returns `UserFound` or `UserNotFound`. |
| `createOwner` | `Future<Result<void, MemberCreationError>> createOwner({required String schoolId, required String phone, String? name})` | Phone-first: lookup user → if found, link to `owners`. If not found, create invited user + link. Writes `logs` entries. Transaction. |
| `createTeacher` | `Future<Result<void, MemberCreationError>> createTeacher({required String schoolId, required String phone, String? name, String? department, ...})` | Same pattern as owner but writes to `teachers` table. Additional fields: `hired`, `role`, `department`. |
| `createStaff` | `Future<Result<void, MemberCreationError>> createStaff({required String schoolId, required String phone, String? name, String? idnumber, ...})` | Same pattern, writes to `staff` table. Additional fields: `idnumber`, `role`, `department`. |
| `createStudent` | `Future<Result<StudentsData, MemberCreationError>> createStudent({required String schoolId, required String name, int? adm, ...})` | Name-first (not phone-first). Creates student row directly. If `adm` is provided and > 0, uses it directly (after validating no conflict at the school); otherwise auto-assigns via `_dao.nextAdmissionNumber(schoolId)`. Additional fields: `dob`, `gender`, `admitted`, `phone`. |
| `createGuardian` | `Future<Result<void, MemberCreationError>> createGuardian({required String schoolId, required int studentAdm, required String phone, ...})` | Phone-first, linked to a specific student. Additional fields: `relationship`, `role`. |
| `saveUserProfileImage` | `Future<Result<void, MemberCreationError>> saveUserProfileImage({required String userId, required List<int> bytes})` | Saves image bytes to `FileCache.profilePath(userId)`. |
| `saveStudentImage` | `Future<Result<void, MemberCreationError>> saveStudentImage({required String schoolId, required int adm, required List<int> bytes})` | Saves image bytes to `FileCache.studentImagePath(schoolId, adm)`. |

**Internal helpers:**
- `_dateToDaysSinceEpoch(DateTime date) → int` — Converts a `DateTime` to days since Unix epoch for date columns.

**Dependencies:** `database/daos/members_dao.dart`, `database/daos/logs_dao.dart`, `database/daos/users_dao.dart`, `database/database.dart`, `database/tables/enums.dart`, `models/result.dart`, `cache/file_cache.dart`, `core/extensions.dart` (for `toKenyanPhone()`), `client.dart` (for global DAOs).

---

### `AiMarkingService` — `ai_marking.dart`

Wraps the `AiMarking` gRPC service for AI-powered paper marking. Handles requesting presigned S3 PUT URLs, uploading files via HTTP PUT, and triggering server-side AI marking.

**Constructor:** `AiMarkingService(ClientChannel channel)`

| Method | Signature | Description |
|---|---|---|
| `requestUploadUrls` | `Future<Result<UploadUrlsResponse, GrpcError>> requestUploadUrls({required String school, required String exam, required int subject, int? paper, required int schemeCount, required Map<int, int> studentSheetCounts, required String accessToken})` | Request presigned PUT URLs for marking scheme images and student answer sheets. `studentSheetCounts` maps `adm → count`. |
| `uploadFile` | `Future<bool> uploadFile(String putUrl, String localPath)` | Upload a single file to S3 using a presigned PUT URL. Returns `true` on success. Handles empty URLs (returns `true`), missing files (returns `false`), and HTTP errors (returns `false`). |
| `markPaper` | `Future<Result<MarkPaperResponse, GrpcError>> markPaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required int totalMarks, required List<String> schemeKeys, required Map<int, List<String>> studentKeys, required String accessToken})` | Trigger server-side AI marking. Returns immediately; actual grades arrive via `watchChanges` SyncDelta stream. `studentKeys` maps `adm → list of S3 keys`. |

**Dependencies:** `dart:io` (HttpClient for HTTP PUT), `grpc` package (ClientChannel, CallOptions, GrpcError), `models/result.dart`, `proto/services/ai_marking.pbgrpc.dart` (generated stubs: `AiMarkingClient`, `UploadUrlsRequest`, `UploadUrlsResponse`, `MarkPaperRequest`, `MarkPaperResponse`, `StudentSheetCount`, `StudentMarkTarget`).

**Registered on `Client`:** Will be wired as `late final aiMarking = AiMarkingService(_channel);` in Task C3.

---

### `QuestionBankService` — `question_bank.dart`

Wraps the `QuestionBank` gRPC service for question bank operations. Handles CRUD for questions within topics, bulk import from JSON, requesting presigned S3 upload URLs for question images, AI paper generation & review, paper finalization & PDF retrieval, marking status polling, and per-question grade breakdowns.

**Constructor:** `QuestionBankService({required ClientChannel channel, required String host, required int port})`

#### Question CRUD & Import (Task 03)

| Method | Signature | Description |
|---|---|---|
| `listQuestions` | `Future<Result<(List<Question>, int), GrpcError>> listQuestions({required int topicId, int offset = 0, int limit = 50, required String accessToken})` | Paginated question list for a topic. Returns `(questions, totalCount)`. |
| `getQuestion` | `Future<Result<Question, GrpcError>> getQuestion({required int id, required String accessToken})` | Single question by ID. |
| `createQuestion` | `Future<Result<Question, GrpcError>> createQuestion({required int topicId, required String text, required int marks, required List<RubricCriterion> rubric, String? exampleAnswer, List<QuestionImage> images = const [], required String accessToken})` | Create one question in a topic. Maps domain models to proto types for rubric criteria and images. |
| `updateQuestion` | `Future<Result<Question, GrpcError>> updateQuestion({required int id, required String text, required int marks, required List<RubricCriterion> rubric, String? exampleAnswer, List<QuestionImage> images = const [], required String accessToken})` | Update an existing question. |
| `deleteQuestion` | `Future<Result<void, GrpcError>> deleteQuestion({required int id, required String accessToken})` | Delete a question. Returns `Ok(null)` on success. |
| `bulkImport` | `Future<Result<BulkImportResult, GrpcError>> bulkImport({required String jsonContent, required String accessToken})` | Bulk import questions from JSON content. Uses 60s timeout. |
| `requestImageUploadUrls` | `Future<Result<List<SignedImageUrl>, GrpcError>> requestImageUploadUrls({required int questionId, required List<String> filenames, required String accessToken})` | Get presigned PUT URLs for question images. Returns proto `SignedImageUrl` directly (no domain model — transient upload flow only). |

#### Paper Generation (Task 04)

| Method | Signature | Description |
|---|---|---|
| `generatePaper` | `Future<Result<List<PaperQuestion>, GrpcError>> generatePaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required int totalMarks, required List<TopicAllocation> allocations, required String accessToken})` | Generate paper questions from topic allocations using AI. Uses 60s timeout. Builds `pb.TopicAllocation` for each allocation. |
| `regenerateQuestion` | `Future<Result<PaperQuestion, GrpcError>> regenerateQuestion({required String school, required String exam, required int subject, int? paper, required int grade, required String paperQuestionId, required int topicId, required int marks, required String accessToken})` | Regenerate a single question on the paper. Uses 60s timeout. |
| `editPaperQuestion` | `Future<Result<PaperQuestion, GrpcError>> editPaperQuestion({required String school, required String exam, required int subject, int? paper, required String paperQuestionId, required String text, required int marks, required List<RubricCriterion> rubric, required String accessToken})` | Edit a question on the generated paper. Uses existing `_toProtoCriterion` helper for rubric conversion. |
| `finalizePaper` | `Future<Result<PaperPdf, GrpcError>> finalizePaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required List<String> paperQuestionIds, required String accessToken})` | Finalize the paper and generate PDF. Uses 60s timeout. Returns `PaperPdf` via `PaperPdf.fromProto(resp)`. |
| `getPaperPdf` | `Future<Result<PaperPdf, GrpcError>> getPaperPdf({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required String accessToken})` | Get the PDF URL for a finalized paper. Returns `PaperPdf` via `PaperPdf.fromGetPdfProto(resp)`. |

#### Marking Status & Question Grades (Task 05)

| Method | Signature | Description |
|---|---|---|
| `getMarkingStatus` | `Future<Result<MarkingStatus, GrpcError>> getMarkingStatus({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required String accessToken})` | Get current marking job status. Maps `MarkingStatusResponse` → `MarkingStatus.fromProto`. |
| `getQuestionGrades` | `Future<Result<List<QuestionGradeDetail>, GrpcError>> getQuestionGrades({required String school, required String exam, required int student, required int subject, int? paper, required String accessToken})` | Get per-question grade breakdown for a student. Maps `QuestionGrade` protos → `QuestionGradeDetail.fromProto`. |
| `watchMarkingStatus` | `Stream<MarkingStatus> watchMarkingStatus({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required String accessToken, Duration interval = const Duration(seconds: 3)})` | Convenience polling stream. Yields `MarkingStatus` every `interval` until `MarkingPhase.complete` or `MarkingPhase.failed`. On gRPC error, yields a failed status and terminates. |

**Internal helpers:**
- `_toProtoImageContext(ImageContext) → pbenum.ImageContext` — Maps domain `ImageContext` enum to proto enum.
- `_toProtoCriterion(RubricCriterion) → pb.RubricCriterion` — Maps domain rubric criterion to proto message. Also used by `editPaperQuestion`.
- `_toProtoImage(QuestionImage) → pb.QuestionImage` — Maps domain question image to proto message (including context, filename, caption, description).

#### Image Upload (Task 03)

| Method | Signature | Description |
|---|---|---|
| `uploadFileToUrl` | `static Future<bool> uploadFileToUrl(String putUrl, String localPath)` | Uploads a local file to a presigned S3/R2 PUT URL. Returns `true` on HTTP 2xx, `false` on failure. Auto-detects Content-Type from file extension. |
| `_contentTypeForExtension` | `static String _contentTypeForExtension(String path)` | Private helper: maps file extension to MIME type (svg, png, jpg, gif, webp). |

**Dependencies:** `grpc` package (ClientChannel, CallOptions, GrpcError), `dart:io` (HttpClient, HttpHeaders, File), `models/question.dart` (domain models: `Question`, `RubricCriterion`, `QuestionImage`, `ImageContext`, `BulkImportResult`), `models/paper_generation.dart` (`PaperQuestion`, `PaperPdf`, `TopicAllocation`), `models/marking_status.dart` (`MarkingStatus`, `MarkingPhase`), `models/question_grade.dart` (`QuestionGradeDetail`, `RubricResult`), `models/result.dart`, `proto/services/question_bank.pb.dart` (proto message types), `proto/services/question_bank.pbgrpc.dart` (`QuestionBankClient`), `proto/services/question_bank.pbenum.dart` (`ImageContext`, `MarkingStatusEnum` proto enums).

### `ImportFileParser` — `import_file_parser.dart`

Pure-Dart utility for parsing and validating question bank JSON files for bulk import. Zero Flutter/UI dependencies.

**Top-level function:** `parseImportFile(String filePath, String jsonContent) → ParsedImportFile`

**Data classes:**
- `ParsedImportFile` — Full result of parsing: file metadata (subject, curriculum, grade, topic), question count, image reference analysis (found/missing counts), cleaned JSON with basenames, `imagePathMap` (basename→absolute path), `questionImageMap` (question index→basenames).
- `MissingImage` — A single missing image reference: `questionIndex`, `filename` (basename), `absolutePath`.

**Key properties on `ParsedImportFile`:**
- `isValid` — `true` if no validation errors
- `hasMissingImages` — `true` if any image file was not found on disk
- `hasImages` — `true` if any image references exist
- `cleanedJson` — JSON string with image filenames stripped to basenames (null if invalid)

**Dependencies:** `dart:convert`, `dart:io` only.

---

## Planned Services (Not Yet Created)

| Future file | Domain | Blocked by |
|---|---|---|
| `sync.dart` | Sync orchestrator — coordinates delta sync via gRPC streams | P3 (sync proto definitions) |
| Domain-specific services (e.g. `students.dart`, `finance.dart`) | Per-entity CRUD + reactive streams for school dashboard | Will be created as needed by future tasks |

## Dependencies

- **Depends on:** `database/daos/` (all DAOs), `database/database.dart` (for generated types + `db` global for transactions), `models/` (domain models, `Result`, `Authenticated`, etc.), `proto/` (gRPC stubs — only `authentication.dart` currently), `cache/file_cache.dart`, `core/` (constants, extensions), `client.dart` (global token variables, global DAO singletons).
- **Depended on by:** `ui/` (screens consume service methods), `client.dart` (holds `Authentication` instance).

## Conventions

- All fallible methods return `Future<Result<T, GrpcError>>` or `Future<Result<T, MemberCreationError>>`.
- Reactive data streams from DAOs are passed through directly as `Stream<T>` — services don't re-wrap them unless transformation is needed.
- Every mutation to a synced table writes a corresponding `logs` entry in the same transaction.
- Services never hold state — they are stateless orchestrators. State lives in the DB (persistent) or in models like `SchoolContext` (in-memory session).
- gRPC calls are wrapped in try/catch → `Result`. Non-gRPC exceptions are mapped to `GrpcError` with `StatusCode.unavailable`.
- `client.dart` is the only file that holds the gRPC `ClientChannel`. Services receive the channel (or a service client) via constructor injection.

## Last Updated
Task 02 — Created import_file_parser.dart utility for JSON file parsing/validation.