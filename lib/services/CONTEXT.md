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
| `authorization_service.dart` | `AuthorizationService`, `PermissionException`, `PermissionResult`, `OrgContext`, `Organisation` | Pre-flight authorization engine — checks whether the current user may perform a given `SyncAction` before it is enqueued. Stateless; reads from the local Drift DB only (no network). Fail-open contract. | ✅ Complete |
| `authentication.dart` | `Authentication` | Login, verify, setup, refresh, change phone | ✅ Complete |
| `members.dart` | `MemberCreationService` | Phone-first member creation (owners, teachers, staff, students, guardians) + profile image saving | ✅ Complete |
| `member_management.dart` | `MemberManagementService` | Post-creation lifecycle: edit fields, change status, remove members (all types) | ✅ Complete |
| `ai_marking.dart` | `AiMarkingService` | AI-powered paper marking: request presigned S3 PUT URLs, upload files, trigger server-side AI marking. Wraps `AiMarking` gRPC service. | ✅ Complete |
| `question_bank.dart` | `QuestionBankService` | Question bank operations: CRUD for questions within topics, bulk import from JSON, presigned S3 upload URLs for question images. Wraps `QuestionBank` gRPC service. | ✅ Complete |
| `timetable_generator.dart` | `TimetableGenerator`, `TimetableSlot`, `GeneratorResult`, `GeneratorSuccess`, `GeneratorFailure`, `GeneratorInput`, `runTimetableGenerator` | Pure-Dart CSP backtracking solver for timetable generation. No Flutter dependencies. Run via `compute(runTimetableGenerator, input)`. | ✅ Complete |
| `import_file_parser.dart` | `ParsedImportFile`, `MissingImage`, `parseImportFile` | Pure-Dart utility for parsing and validating question bank JSON files for bulk import. Zero Flutter/UI dependencies. | ✅ Complete |
| `paper_service.dart` | `PaperService`, `TaughtTopic` | Exam lifecycle gRPC service wrapper: event creation, paper creation, paper scheduling, syllabus coverage confirmation, assessment/assignment generation, per-student paper status polling and PDF retrieval. Wraps `EventServiceClient`, `PaperServiceClient`, and `PaperManagementClient`. | ✅ Complete |

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
- `MemberActionError` — **sealed class** hierarchy (not an enum). Subtypes:
  - `NoActiveAccount` — user is not logged in.
  - `NotFound` — target member row not found locally.
  - `DatabaseError` — unexpected local DB error.
  - `CannotRemoveSelf` — caller attempted to remove their own owner row.
  - `PermissionDenied(String reason)` — carries the human-readable denial message from `AuthorizationService`. Auth-check denials propagate `authResult.reason!`; defense-in-depth denials use a generic fallback string.

All mutation methods accept an optional `SchoolPermissions? permissions` parameter for defense-in-depth RBAC enforcement. When provided, the method checks the caller has the required `Resource`/`Action` before proceeding; when `null`, the check is skipped (backward compatible with existing callers).

| Method | Signature | Permission Guard | Description |
|---|---|---|---|
| `updateTeacher` | `Future<Result<void, MemberActionError>> updateTeacher({required String schoolId, required String userId, String? role, String? department, DateTime? hiredDate, SchoolPermissions? permissions})` | `Resource.teachers` / `Action.update` | Updates mutable fields on a teacher row. Only non-null params are written. |
| `changeTeacherStatus` | `Future<Result<void, MemberActionError>> changeTeacherStatus({required String schoolId, required String userId, required TeacherStatus status, SchoolPermissions? permissions})` | `Resource.teachers` / `Action.update` | Changes a teacher's status (e.g. active → resigned). |
| `removeTeacher` | `Future<Result<void, MemberActionError>> removeTeacher({required String schoolId, required String userId, SchoolPermissions? permissions})` | `Resource.teachers` / `Action.delete` | Removes a teacher from a school. |
| `updateStaff` | `Future<Result<void, MemberActionError>> updateStaff({required String schoolId, required String userId, String? role, String? department, String? idNumber, SchoolPermissions? permissions})` | `Resource.staff` / `Action.update` | Updates mutable fields on a staff row. |
| `changeStaffStatus` | `Future<Result<void, MemberActionError>> changeStaffStatus({required String schoolId, required String userId, required StaffStatus status, SchoolPermissions? permissions})` | `Resource.staff` / `Action.update` | Changes a staff member's status. |
| `removeStaff` | `Future<Result<void, MemberActionError>> removeStaff({required String schoolId, required String userId, SchoolPermissions? permissions})` | `Resource.staff` / `Action.delete` | Removes a staff member from a school. |
| `removeOwner` | `Future<Result<void, MemberActionError>> removeOwner({required String schoolId, required String userId, SchoolPermissions? permissions})` | `Resource.owners` / `Action.delete` | Removes an owner. Returns `CannotRemoveSelf` if caller tries to remove themselves. |
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
| `requestUploadUrls` | `Future<Result<UploadUrlsResponse, GrpcError>> requestUploadUrls({required String paperId, required int schemeCount, required Map<int, int> studentSheetCounts, required String accessToken})` | Request presigned PUT URLs for marking scheme images and student answer sheets. `paperId` is the UUID of the paper row. `studentSheetCounts` maps `adm → count`. |
| `uploadFile` | `Future<bool> uploadFile(String putUrl, String localPath)` | Upload a single file to S3 using a presigned PUT URL. Returns `true` on success. Handles empty URLs (returns `true`), missing files (returns `false`), and HTTP errors (returns `false`). |
| `markPaper` | `Future<Result<MarkPaperResponse, GrpcError>> markPaper({required String paperId, required int totalMarks, required List<String> schemeKeys, required Map<int, List<String>> studentKeys, required String accessToken})` | Trigger server-side AI marking. `paperId` replaces the old 6-field composite (`school`, `exam`, `subject`, `paper`, `grade`, `stream`). Returns immediately; actual grades arrive via `watchChanges` SyncDelta stream. `studentKeys` maps `adm → list of S3 keys`. |

**Dependencies:** `dart:io` (HttpClient for HTTP PUT), `grpc` package (ClientChannel, CallOptions, GrpcError), `models/result.dart`, `proto/services/ai_marking.pbgrpc.dart` (generated stubs: `AiMarkingClient`, `UploadUrlsRequest`, `UploadUrlsResponse`, `MarkPaperRequest`, `MarkPaperResponse`, `StudentSheetCount`, `StudentMarkTarget`).

**Registered on `Client`:** Will be wired as `late final aiMarking = AiMarkingService(_channel);` in Task C3.

---

### `QuestionBankService` — `question_bank.dart`

Wraps the `QuestionBank` gRPC service for question bank operations. Handles CRUD for questions within topics, bulk import from JSON, requesting presigned S3 upload URLs for question images, AI paper generation & review, paper finalization & PDF retrieval, marking status polling, and per-question grade breakdowns.

**Constructor:** `QuestionBankService({required ClientChannel channel, required String host, required int port})`

#### Question CRUD & Import (Task 03)

| Method | Signature | Description |
|---|---|---|
| `listQuestions` | `Future<Result<(List<Question>, int), GrpcError>> listQuestions({required int topicId, int page = 0, int pageSize = 50, required String accessToken})` | Paginated question list for a topic. Returns `(questions, totalCount)`. Pagination params renamed from `offset`/`limit` to `page`/`pageSize` (FIX-03). |
| `getQuestion` | `Future<Result<Question, GrpcError>> getQuestion({required int id, required String accessToken})` | Single question by ID. |
| `createQuestion` | `Future<Result<Question, GrpcError>> createQuestion({required int topicId, required String body, required int marks, required List<RubricCriterion> rubric, String? exampleAnswer, List<QuestionImage> images = const [], required String accessToken})` | Create one question in a topic. Param renamed `text` → `body` (FIX-03). Maps domain models to proto types for rubric criteria. |
| `updateQuestion` | `Future<Result<Question, GrpcError>> updateQuestion({required int id, required String body, required int marks, required List<RubricCriterion> rubric, String? exampleAnswer, List<QuestionImage> images = const [], required String accessToken})` | Update an existing question. Param renamed `text` → `body` (FIX-03). |
| `deleteQuestion` | `Future<Result<void, GrpcError>> deleteQuestion({required int id, required String accessToken})` | Delete a question. Returns `Ok(null)` on success. |
| `bulkImport` | `Future<Result<BulkImportResult, GrpcError>> bulkImport({required String jsonContent, required String accessToken, String? diagnosticLabel})` | Bulk import questions from JSON content. Uses 60s timeout. Internally parses `jsonContent` JSON, builds a `BulkImportRequest` with a list of `CreateQuestionRequest` objects (each with `topicId`, `body`, `marks`, rubric, and optional `exampleAnswer`), then calls the renamed RPC `client.bulkImport()` (was `bulkImportQuestions`). Public signature unchanged (still accepts `jsonContent` string). School-agnostic: no school field on request. Diagnostics record `scope=system-wide`, `school=none`. (FIX-03) |
| `requestImageUploadUrls` | `Future<Result<List<String>, GrpcError>> requestImageUploadUrls({required int questionId, required int count, required String accessToken})` | Request `count` presigned S3/R2 PUT URLs for one question's images. Builds `ImageUploadUrlsRequest()..questionId = questionId..count = count`. Returns plain `List<String>` (raw PUT URL strings). Old batch `ImageUploadSpec` API removed (FIX-03). |

#### Paper Generation (Task 04)

| Method | Signature | Description |
|---|---|---|
| `generatePaper` | `Future<Result<List<PaperQuestion>, GrpcError>> generatePaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required int totalMarks, required List<TopicAllocation> allocations, required String accessToken})` | Generate paper questions from topic allocations using AI. Uses 60s timeout. Builds `pb.TopicAllocation` for each allocation. |
| `regenerateQuestion` | `Future<Result<PaperQuestion, GrpcError>> regenerateQuestion({required String school, required String exam, required int subject, int? paper, required int grade, required String paperQuestionId, required int topicId, required int marks, required String accessToken})` | Regenerate a single question on the paper. Uses 60s timeout. |
| `editPaperQuestion` | `Future<Result<PaperQuestion, GrpcError>> editPaperQuestion({required String school, required String exam, required int subject, int? paper, required String paperQuestionId, required String text, required int marks, required List<RubricCriterion> rubric, required String accessToken})` | Edit a question on the generated paper. Uses existing `_toProtoCriterion` helper for rubric conversion. |
| `finalizePaper` | `Future<Result<PaperPdf, GrpcError>> finalizePaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required List<String> paperQuestionIds, required String accessToken})` | Finalize the paper and generate PDF. Uses 60s timeout. Returns `PaperPdf` via `PaperPdf.fromProto(resp)`. |
| `clearPaperQuestions` | `Future<Result<int, GrpcError>> clearPaperQuestions({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required String accessToken})` | Delete all generated questions for a paper and invalidate its S3 PDF. Only valid when the paper is still in Pending status. Returns count of `paper_questions` rows deleted on success. Uses 30s timeout. |
| `copyPaperToStreams` | `Future<Result<List<StreamCopyResult>, GrpcError>> copyPaperToStreams({required String school, required String exam, required int subject, int? paper, required int grade, int? sourceStream, required List<int> targetStreams, required String accessToken})` | Copy a finalized paper's question set to one or more additional streams. Server copies question rows and generates a PDF for each target stream. Source stream must already have generated questions. Partial failures are possible — check `StreamCopyResult.success` per stream. Uses 120s timeout. Returns `List<StreamCopyResult>` via `StreamCopyResult.fromProto` mapping. |
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
| `_uploadFile` | `Future<bool> _uploadFile(String putUrl, String localPath)` | Private instance helper added in FIX-03. Reads entire file into bytes and PUTs to the presigned URL with `Content-Type: application/octet-stream`. Returns `true` on HTTP 2xx, `false` on any failure (file missing, network error, non-2xx). Used by the per-question image upload loop in `importFileWithImages`. |

#### File Import Orchestrator (Task 04)

| Method | Signature | Description |
|---|---|---|
| `importFileWithImages` | `Future<FileImportResult> importFileWithImages({required ParsedImportFile parsed, required String accessToken, ImportProgressCallback? onProgress})` | High-level orchestrator for a single parsed file. Pipeline: (1) bulk import questions via `bulkImport()`; (2) per-question loop — for each created question, collect local image paths, call `requestImageUploadUrls(questionId, count)`, then upload each file via `_uploadFile()`. Phase 2 replaces the old single-batch `ImageUploadSpec` approach with per-question `requestImageUploadUrls` calls (FIX-03). Missing images increment `imagesSkipped`; URL-request failures add an error and skip uploads for that question. Returns `FileImportResult` with counts and per-item errors. |

**Top-level types (defined above `QuestionBankService` class):**

| Type | Description |
|---|---|
| `ImportProgressCallback` | `typedef void Function(String phase, String detail, double progress)` — Progress callback for `importFileWithImages`. |
| `FileImportResult` | Result of importing a single file. Fields: `fileName`, `topic`, `questionsCreated`, `questionsErrored`, `imagesUploaded`, `imagesFailed`, `imagesSkipped`, `errors`. Getters: `isFullSuccess` (no errors/failures/skips), `isPartialSuccess` (at least one question created). |

**Dependencies:** `grpc` package (ClientChannel, CallOptions, GrpcError), `dart:io` (HttpClient, HttpHeaders, File), `dart:convert` (jsonDecode — used by `importFileWithImages`), `models/question.dart` (domain models: `Question`, `RubricCriterion`, `QuestionImage`, `ImageContext`, `BulkImportResult`), `models/paper_generation.dart` (`PaperQuestion`, `PaperPdf`, `TopicAllocation`, `StreamCopyResult`), `models/marking_status.dart` (`MarkingStatus`, `MarkingPhase`), `models/question_grade.dart` (`QuestionGradeDetail`, `RubricResult`), `models/result.dart`, `proto/services/question_bank.pb.dart` (proto message types), `proto/services/question_bank.pbgrpc.dart` (`QuestionBankClient`), `import_file_parser.dart` (`ParsedImportFile` — used by `importFileWithImages`).

### `ImportFileParser` — `import_file_parser.dart`

Pure-Dart utility for parsing and validating question bank JSON files for bulk import. Zero Flutter/UI dependencies.

**Top-level function:** `parseImportFile(String filePath, String jsonContent) → ParsedImportFile` — intentionally school-agnostic for system question import; validates only file-local payload structure and image references, never a school identifier. This parser is not responsible for any school lookup and should not be treated as part of a school-scoped import contract.

**Data classes:**
- `ParsedImportFile` — Full result of parsing: file metadata (subject, curriculum, grade, rawGrade, topic), question count, image reference analysis (found/missing counts), cleaned JSON with basenames, `imagePathMap` (basename→absolute path), `questionImageMap` (question index→basenames).
- `MissingImage` — A single missing image reference: `questionIndex`, `filename` (basename), `absolutePath`.

**Key properties on `ParsedImportFile`:**
- `isValid` — `true` if no validation errors
- `hasMissingImages` — `true` if any image file was not found on disk
- `hasImages` — `true` if any image references exist
- `cleanedJson` — JSON string with image filenames stripped to basenames (null if invalid)

**Grade normalization:** The private top-level helper `_normalizeGrade(String curriculum, int rawGrade) → int` maps raw Form 1–4 grades (1–4) to DB-compatible grade numbers (41–44) for the 8-4-4 curriculum. CBC grades and already-normalized 8-4-4 grades pass through unchanged. Called inside `parseImportFile()` after grade validation; the result is stored in `ParsedImportFile.grade` while the original value is preserved in `ParsedImportFile.rawGrade`.

**Dependencies:** `dart:convert`, `dart:io` only.

---

### `PaperService` — `paper_service.dart`

Wraps three gRPC service clients for the full exam lifecycle. Uses `EventServiceClient`, `PaperServiceClient`, and `PaperManagementClient` (one instance per call, stateless, channel reused).

**Constructor:** `PaperService({required ClientChannel channel})`

**Helper class (defined in same file):**
- `TaughtTopic` — topic with current taught status. Fields: `topicId` (int), `status` (int: 0=not_started, 1=in_progress, 2=completed), `taughtDate` (DateTime?, non-null when status==2). **No `topicName` field** — the proto does not carry it; callers must join against the local `topics` Drift table to resolve display names.

#### Event Lifecycle

| Method | Signature | Description |
|---|---|---|
| `createEvent` | `Future<Result<String, GrpcError>> createEvent({required String school, required String name, required int type, required int term, required int year, required DateTime startDate, required DateTime endDate, required String accessToken})` | Create an exam event. `type`: 0=exam, 1=mock, 2=holiday_revision. Dates converted to days-since-epoch. Returns new event ID. |

#### Paper Creation

| Method | Signature | Description |
|---|---|---|
| `createPaper` | `Future<Result<String, GrpcError>> createPaper({required String school, required String eventId, required int subject, required int grade, int stream = 0, required int type, required String name, required int totalMarks, required int durationMinutes, required DateTime date, int generationMode = 0, String instructions = '', List<({int topicId, int marks})> topicWeights = const [], required String accessToken})` | Create an exam paper within an event. `topicWeights` marks are converted to `double` for the proto `PaperTopicWeight.weight` field. Returns new paper ID. |

#### Scheduling

| Method | Signature | Description |
|---|---|---|
| `schedulePaper` | `Future<Result<String, GrpcError>> schedulePaper({required String eventId, required int subject, required int grade, int stream = 0, required DateTime date, required int startMinutes, required int endMinutes, String? invigilatorId, required String accessToken})` | Schedule a paper within an event. `startMinutes`/`endMinutes` are minutes since midnight. `durationMinutes` is derived. Returns new schedule ID. |

#### Topic Coverage

| Method | Signature | Description |
|---|---|---|
| `getTaughtTopics` | `Future<Result<List<TaughtTopic>, GrpcError>> getTaughtTopics({required String school, required int subject, required int grade, int stream = 0, required String accessToken})` | Fetch taught-topic statuses. Returns `topicId` + `status` + `taughtDate` only — no topic name in proto. |
| `setTaughtTopics` | `Future<Result<void, GrpcError>> setTaughtTopics({required String school, required int subject, required int grade, required int stream, required List<({int topicId, int status})> updates, required String accessToken})` | Update taught status for a list of topics in one call. |
| `confirmExamCoverage` | `Future<Result<int, GrpcError>> confirmExamCoverage({required String scheduleId, required List<int> topicIds, required String accessToken})` | Confirm syllabus coverage for a scheduled paper. Returns count of topics confirmed. |

#### Generation

| Method | Signature | Description |
|---|---|---|
| `generateAssessment` | `Future<Result<bool, GrpcError>> generateAssessment({required String paperId, required String accessToken})` | Trigger assessment generation for an already-created paper. Returns `true` if server accepted. |
| `generateAssignment` | `Future<Result<bool, GrpcError>> generateAssignment({required String paperId, required String accessToken})` | Trigger assignment generation for an already-created paper. Returns `true` if server accepted. |
| `finalizeStudentPapers` | `Future<Result<String, GrpcError>> finalizeStudentPapers({required String paperId, required String accessToken})` | Trigger per-student PDF generation for all enrolled students. Returns job ID for status polling. |

#### Per-Student Status & Retrieval

| Method | Signature | Description |
|---|---|---|
| `getStudentPapersStatus` | `Future<Result<StudentPapersStatus, GrpcError>> getStudentPapersStatus({required String paperId, required String accessToken})` | Poll generation progress for all students. `StudentPaperEntry.studentId` is the string of the int DB student ID. `studentName`/`admNo` are empty — join from local `students` table. |
| `getStudentPaperPdf` | `Future<Result<StudentPaperPdf, GrpcError>> getStudentPaperPdf({required String paperId, required String studentId, required String accessToken})` | Get presigned PDF URL for a specific student's paper. `studentId` is parsed to int for the proto request. `studentName`/`admNo` are empty — join from local `students` table. |

**Global accessor:** `PaperService get paperService => client.paper;` (in `client.dart`)

**Client field:** `late final paper = PaperService(channel: _channel);` (in `Client` class)

**Dependencies:** `grpc` package (ClientChannel, CallOptions, GrpcError), `models/event.dart` (PaperGenerationPhase), `models/paper.dart` (StudentPaperEntry, StudentPapersStatus, StudentPaperPdf), `models/result.dart`, `proto/services/event.pb.dart` + `event.pbgrpc.dart` (EventServiceClient, CreateEventRequest/Response), `proto/services/paper.pb.dart` + `paper.pbgrpc.dart` (PaperServiceClient, CreatePaperRequest/Response, PaperTopicWeight), `proto/services/paper_management.pb.dart` + `paper_management.pbgrpc.dart` (PaperManagementClient, SchedulePaperRequest/Response, TaughtTopicProto, SetTaughtTopicsRequest, GetTaughtTopicsRequest/Response, ConfirmExamCoverageRequest/Response, GenerateAssessmentRequest/Response, GenerateAssignmentRequest/Response, FinalizeStudentPapersRequest/Response, GetStudentPapersStatusRequest/Response, StudentPdfStatus, GetStudentPaperPdfRequest/Response).

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
Task A1 — Updated `ImportFileParser` (`import_file_parser.dart`):
- Added `rawGrade` field to `ParsedImportFile` — preserves the original grade number from JSON before normalization.
- Added private top-level helper `_normalizeGrade(String curriculum, int rawGrade) → int` — maps Form 1–4 (1–4) to DB-compatible 41–44 for 8-4-4; CBC passes through.
- `parseImportFile()` now normalizes the grade after validation and passes both `grade` (normalized) and `rawGrade` to the result.
- Updated `_errorResult`, `_buildResult`, and all `_buildResult` call sites to include `rawGrade`.

Previous: Task FIX-03 — Updated `QuestionBankService` (`question_bank.dart`):
- `listQuestions`: pagination params renamed `offset`/`limit` → `page`/`pageSize`; proto request fields updated accordingly; print log updated.
- `createQuestion`: param `text` → `body`; proto request field `..text` → `..body`.
- `updateQuestion`: param `text` → `body`; proto request field `..text` → `..body`.
- `bulkImport`: try block now parses `jsonContent` JSON internally and builds `BulkImportRequest` with a list of `CreateQuestionRequest` objects (body, marks, topicId, rubric, exampleAnswer); RPC call renamed from `client.bulkImportQuestions()` to `client.bulkImport()`.
- `requestImageUploadUrls`: completely replaced — new signature `({required int questionId, required int count, required String accessToken})` → `Future<Result<List<String>, GrpcError>>`; builds `ImageUploadUrlsRequest()..questionId..count`; old `ImageUploadSpec`/`ImageUploadUrl` proto types no longer used.
- `importFileWithImages` Phase 2+3: replaced single-batch `ImageUploadSpec` approach with per-question loop calling `requestImageUploadUrls` and `_uploadFile` per question.
- Added `_uploadFile(String putUrl, String localPath)` private instance helper (reads bytes, raw PUT to URL, `Content-Type: application/octet-stream`).

Previous: Task FIX-02 — Updated `AiMarkingService` (`ai_marking.dart`): `requestUploadUrls` and `markPaper` signatures now use `required String paperId` instead of the previous 6-field composite (`school`, `exam`, `subject`, `paper`, `grade`, `stream`). Proto-building blocks updated to `UploadUrlsRequest()..paperId = paperId` and `MarkPaperRequest()..paperId = paperId` respectively. Print log lines updated to reflect new signature.

Previous: Task M4 — Added `paper_service.dart` (9 public methods, `TaughtTopic` helper class). File count updated from 8 → 9. Wired in `client.dart` as `late final paper = PaperService(channel: _channel)` with global getter `PaperService get paperService => client.paper`. Key implementation note: `PaperTopicWeight.weight` is a `double` proto field — `int marks` parameters are converted via `.toDouble()`. `TaughtTopic` carries no `topicName` field (not in proto). `StudentPaperEntry.studentId` is the string representation of the integer DB student ID from `StudentPdfStatus.student`.

Previous: AUTH-C05 — `MemberActionError` converted from enum to sealed class hierarchy in `member_management.dart`:
- `enum MemberActionError` replaced with `sealed class MemberActionError` and five `final class` subtypes: `NoActiveAccount`, `NotFound`, `DatabaseError`, `CannotRemoveSelf`, `PermissionDenied(String reason)`.
- All 12 `authorization.check()` denial sites now return `Err(PermissionDenied(authResult.reason!))` — the actual denial reason propagates to the UI.
- All 12 defense-in-depth `permissions?.can()` denial sites return `const Err(PermissionDenied('You don\'t have permission to perform this action.'))`.
- All 12 `noActiveAccount` sites updated to `const Err(NoActiveAccount())`.
- All 12 `databaseError` sites updated to `const Err(DatabaseError())`.
- `cannotRemoveSelf` site updated to `const Err(CannotRemoveSelf())`.
- UI switch expressions in `teachers_tab.dart` (3 sites), `staff_tab.dart` (2 sites), `students_tab.dart` (2 sites), `guardians_tab.dart` (1 site), `owners_tab.dart` (3 sites) updated from `case Err(error: MemberActionError.permissionDenied)` to `case Err(error: PermissionDenied(:final reason))` — `showPermissionDenied(context, reason)` now shows the actual server-provided message.

Previous: Task AUTH-B06 — Authorization pre-flight checks added to `MemberManagementService`:
- `lib/services/member_management.dart` — added `authorization.check(...)` call (using the global `authorization` from `client.dart`) immediately after the `accountId` null check in all 12 public mutation methods. Each check uses `schoolId` (already a direct parameter in every method) and `recordId: null`. On denial, returns `Err(MemberActionError.permissionDenied)`. No new import needed — `authorization` is accessible via the existing `import '../client.dart'`. Existing `SchoolPermissions`-based defense-in-depth guards are retained below the new pre-flight check. Action mapping: `updateTeacher`/`changeTeacherStatus` → `SyncAction.updateTeacher`; `removeTeacher` → `SyncAction.deleteTeacher`; `updateStaff`/`changeStaffStatus` → `SyncAction.updateStaff`; `removeStaff` → `SyncAction.deleteStaff`; `removeOwner` → `SyncAction.deleteOwner`; `updateStudent`/`changeStudentStatus` → `SyncAction.updateStudent`; `removeStudent` → `SyncAction.deleteStudent`; `updateGuardian` → `SyncAction.updateGuardian`; `removeGuardian` → `SyncAction.deleteGuardian`.

Previous: Task AUTH-A01 — Added `authorization_service.dart`. New stateless `AuthorizationService` class with:
- `check({action, schoolId, recordId}) → Future<PermissionResult>` — top-level pre-flight check.
- `_resolveOrganisation(...)` — maps a `SyncAction` + optional IDs to `OrgContext` (system / account / school).
- `_loadSystemPermissions(userId, level)` — builds `SystemPermissions` from system-scoped roles via `db.rolesDao.getSystemRolesForUser()`.
- `_actionPermission(SyncAction)` — exhaustive static switch mapping all 95 `SyncAction` values to `(Resource, Action)` pairs.
- `_denialMessage(Resource, Action)` — human-readable denial string for display in the UI.
Supporting types: `PermissionException`, `PermissionResult`, `Organisation` enum, `OrgContext` sealed class hierarchy (`_SystemOrg`, `_AccountOrg`, `_SchoolOrg`).

Previous: Task P05 — Added `copyPaperToStreams` to `QuestionBankService`. New method copies a finalized paper's question set to one or more additional streams; returns `List<StreamCopyResult>` on success (partial failures possible per stream). Updated dependencies entry to include `StreamCopyResult` from `models/paper_generation.dart`.

Previous:
Task P03 — Added `clearPaperQuestions` to `QuestionBankService`. New method deletes all generated questions for a paper and invalidates its S3 PDF; returns `int` (questions deleted count) on success. Wraps the new `ClearPaperQuestions` RPC in `question_bank.pbgrpc.dart`. Added to Paper Generation table in this CONTEXT.md.

Previous:
Task 04 — Context refresh after question-import investigation: documented that `QuestionBankService` question import remains school-agnostic at the request-shape level (`BulkImportRequest()..jsonContent = ...` only, no school field), that `ImportFileParser` is purely file-structure/image validation and never participates in school lookup, and that the new diagnostics in `bulkImport()` / `importFileWithImages()` explicitly capture system-wide scope plus exact backend gRPC failures for future audits.

Previous:
Task 02 — Clarified system question-bank import as school-agnostic in both `QuestionBankService` and `ImportFileParser`. `bulkImport()` now accepts an optional `diagnosticLabel` used only for logging; the request shape is still just `BulkImportRequest()..jsonContent = ...` with no school field. Added concise request/response diagnostics for system-wide imports (`scope=system-wide`, `school=none`) and preserved exact backend gRPC messages in surfaced import failures. `importFileWithImages()` now logs file/topic-level import and image-upload stages without changing partial-success or image-upload behavior.

Previous:
Task 04 — Added `importFileWithImages` orchestrator, `ImportProgressCallback` typedef, and `FileImportResult` class to `QuestionBankService`.