# proto/ — Generated Protobuf/gRPC Stubs Context

> **NEVER edit files in this directory manually.** All files are generated from `.proto` definitions by `protoc`. Regeneration will overwrite any manual changes.

## Overview

This directory contains Dart stubs generated from Protocol Buffer definitions. These stubs are used by the `services/` layer to make gRPC calls to the backend server.

The generated code lives in two subdirectories:
- `services/` — gRPC service client stubs (request/response handling).
- `types/` — Protobuf message type definitions (data structures).
- `google/` — Google well-known protobuf types (e.g. `Timestamp`, `Empty`).

## Directory Structure

```
proto/
├── google/                          # Google well-known types (generated)
├── services/
│   ├── authentication.pb.dart       # Message classes: Login, Verify, Verified, Authenticated, Setup, Refresh
│   ├── authentication.pbenum.dart   # Enums defined in authentication.proto (if any)
│   ├── authentication.pbgrpc.dart   # gRPC client/server stubs: AuthenticationClient
│   ├── authentication.pbjson.dart   # JSON serialization support
│   ├── sync.pb.dart                 # Message classes: MutationBatch, Mutation, PushAck, MutationResult, WatchRequest, SyncDelta, FileUrl, InsertData (30 *Insert messages), UpdateData (25 *Update messages)
│   ├── sync.pbenum.dart             # Enums from sync.proto (InsertData_Row, UpdateData_Row oneof enums)
│   ├── sync.pbgrpc.dart             # gRPC client/server stubs: SyncClient
│   └── sync.pbjson.dart             # JSON serialization support
└── types/
    ├── member.pb.dart               # Message class: Membership; Enum: Role (Owner, Guardian, Student, Teacher, Staff)
    ├── member.pbenum.dart           # Member-related enums
    ├── member.pbjson.dart           # JSON serialization support
    ├── role.pb.dart                 # Message classes: Permission, Role, Assignment; Enums: Resource (18 values), Action (9 values)
    ├── role.pbenum.dart             # Role-related enums (Resource, Action)
    ├── role.pbjson.dart             # JSON serialization support
    ├── user.pb.dart                 # Message classes: User, Update; Enums: Level, Status
    ├── user.pbenum.dart             # User-related enums
    ├── user.pbjson.dart             # JSON serialization support
    ├── verification.pb.dart         # Message class: Verification; Enum: Purpose
    ├── verification.pbenum.dart     # Verification-related enums
    └── verification.pbjson.dart     # JSON serialization support
```

## Available Services

| Service | Client Class | File | Methods | Status |
|---|---|---|---|---|
| Authentication | `AuthenticationClient` | `services/authentication.pbgrpc.dart` | `login`, `verify`, `setup`, `refresh` | ✅ Generated |
| Account | — | — | — | ❌ Not needed (P2 closed) |
| Sync | `SyncClient` | `services/sync.pbgrpc.dart` | `pushChanges` (client-streaming → server ack stream), `watchChanges` (server-streaming) | ✅ Generated |

## Key Proto Message Types

### `services/authentication.pb.dart`

| Message | Fields | Used by |
|---|---|---|
| `Login` | `phone` (string) | `Authentication.login()` |
| `Verify` | `phone` (string), `code` (string) | `Authentication.verify()` |
| `Verified` | `token` (string), `authenticated` (Authenticated) | Response from `verify` — branches on whether `authenticated` is present |
| `Authenticated` | `user` (User), `access_token`, `refresh_token`, `profile` (string — write URL, never stored) | Response payload for successful auth |
| `Setup` | `token` (string), `name` (string) | `Authentication.setup()` |
| `Refresh` | `token` (string) | `Authentication.refresh()` |

> **Important:** The proto `Authenticated` message is NOT the same as `lib/models/authenticated.dart`. The proto class is only used as a deserialization target inside `services/authentication.dart`. The domain model `Authenticated` wraps a `UsersData` + `AccountsData` pair.

> **Important:** The `profile` field in proto `Authenticated` is a presigned S3 **write** (PUT) URL valid for ~1 hour. It is used immediately for upload and **never stored** anywhere in the app.

### `types/user.pb.dart`

| Message/Enum | Fields/Values | Used by |
|---|---|---|
| `User` | `id`, `phone`, `email`, `name`, `level` (Level), `status` (Status), `profile` (read URL), `created`, `updated` | Nested inside proto `Authenticated` |
| `Update` | Various update fields | Not currently used by client |
| `Level` enum | `NORMAL` (0), `SYSTEM` (1), `SUPER` (2) | Maps to `UserLevel` in `enums.dart` |
| `Status` enum | `INVITED` (0), `ACTIVE` (1), `SUSPENDED` (2), `DELETED` (3) | Maps to `UserStatus` in `enums.dart` |

### `services/sync.pb.dart`

| Message | Fields | Used by |
|---|---|---|
| `MutationBatch` | `batchId` (string), `mutations` (repeated Mutation) | `LogProcessor.buildBatches()` → pushed to server via `SyncClient.pushChanges()` |
| `Mutation` | `table` (int32), `operation` (int32), `rowKey` (string), `insert` (InsertData, optional), `update` (UpdateData, optional) | Individual mutation within a batch. `insert` set for op=Insert, `update` set for op=Update, neither for op=Delete. No `columns` field — bitmask stays local in `logs` table. |
| `PushAck` | `batchId` (string), `success` (bool), `error` (optional string), `serverSeq` (int64), `results` (repeated MutationResult) | Server acknowledgement of a pushed batch |
| `MutationResult` | `index` (int32), `success` (bool), `error` (optional string), `code` (int32: 0=ok, 1=permission_denied, 2=conflict, 3=validation_error, 4=not_found), `fileUrls` (repeated FileUrl) | Per-mutation result within a PushAck |
| `WatchRequest` | `lastSeq` (int64) | Client sends to start server-streaming watch |
| `SyncDelta` | `seq` (int64), `table` (int32), `operation` (int32), `rowKey` (string), `data` (InsertData), `fileUrls` (repeated FileUrl) | Server-pushed change event. `data` carries an `InsertData` with the row's mutable fields. PKs come from `rowKey` (pipe-delimited). |
| `FileUrl` | `path` (string), `putUrl` (optional string), `getUrl` (optional string), `expiry` (int64) | S3 presigned URLs for file sync |
| `InsertData` | oneof `row` with 30 per-table `*Insert` messages | Wrapper for full row data (all mutable non-PK, non-timestamp fields). Used in `Mutation.insert` and `SyncDelta.data`. |
| `UpdateData` | oneof `row` with 25 per-table `*Update` messages (missing: owners, enrollments, subjects, lessons, scopes) | Wrapper for partial row data (only updatable fields). Used in `Mutation.update`. Server uses `has*()` to detect which fields were set. |

### `services/sync.pb.dart` — Per-Table Insert & Update Messages

**Key difference from old `*Row` messages:** `*Insert` messages do NOT carry PK fields (`id` for single-PK tables) or timestamp fields (`created`, `updated`). PKs come from `Mutation.rowKey` / `SyncDelta.rowKey` (pipe-delimited). Timestamps are server-managed.

**Exception:** For composite-PK tables, some PK fields ARE present on the `*Insert` message (e.g. `OwnerInsert` has `school` and `user`), but these are redundant with `rowKey` and should not be relied upon — always use `rowKey` as the canonical PK source.

#### Insert Messages (30 total — in `InsertData` oneof)

| # | Message | Accessor | Non-PK mutable fields | Used for table |
|---|---|---|---|---|
| 0 | `UserInsert` | `.user` | phone, email, name, level, status | `users` |
| 1 | `SchoolInsert` | `.school` | name, motto, phone, email, county, domain, established, status | `schools` |
| 2 | `OwnerInsert` | `.owner` | school, user (both are PKs — redundant with rowKey) | `owners` |
| 3 | `StudentInsert` | `.student` | school, adm, user, name, dob, gender, documents, admitted, status | `students` |
| 4 | `GuardianInsert` | `.guardian` | school, user, student, relationship, role | `guardians` |
| 5 | `DepartmentInsert` | `.department` | school, name, description | `departments` |
| 6 | `TeacherInsert` | `.teacher` | school, user, hired, role, department, status | `teachers` |
| 7 | `StaffInsert` | `.staffMember` | school, user, idnumber, role, department, status | `staff` |
| 8 | `TermInsert` | `.term` | school, year, term, start, end | `terms` |
| 9 | `ClassTeacherInsert` | `.classTeacher` | school, year, term, grade, stream, teacher, start, end | `class_teachers` |
| 10 | `EnrollmentInsert` | `.enrollment` | school, year, term, grade, stream, student | `enrollments` |
| 11 | `SubjectInsert` | `.subject` | school, year, term, grade, stream, subject, teacher | `subjects` |
| 12 | `AttendanceInsert` | `.attendance` | school, year, term, grade, stream, student, date, status | `attendance` |
| 13 | `TimetableInsert` | `.timetable` | school, year, term, grade, stream, subject, teacher, day, start, end | `timetable` |
| 14 | `LessonInsert` | `.lesson` | school, year, term, grade, stream, date, subject, teacher | `lessons` |
| 15 | `ExamInsert` | `.exam` | school, year, term, grade, stream, personalized, type, start, end, teacher | `exams` |
| 16 | `PaperInsert` | `.paper` | school, exam, subject, paper, invigilator, start, end, status | `papers` |
| 17 | `GradeInsert` | `.grade` | school, exam, student, subject, paper, score, total | `grades` |
| 18 | `FeeInsert` | `.fee` | school, year, term, grade, title, description, amount, mandatory, due | `fees` |
| 19 | `InvoiceInsert` | `.invoice` | school, year, term, fee, description, student, amount, status, due | `invoices` |
| 20 | `PaymentInsert` | `.payment` | invoice, school, student, amount, method, reference, recorder, date | `payments` |
| 21 | `AnnouncementInsert` | `.announcement` | school, title, content, grade, stream, audience, author | `announcements` |
| 22 | `MasteryInsert` | `.mastery` | school, student, grade, subject, topic, score | `mastery` |
| 23 | `AiUsageInsert` | `.aiUsage` | school, student, year, term, allocated, used | `aiusage` |
| 24 | `SettingsInsert` | `.settings` | school, data, mpesa | `settings` |
| 25 | `RoleInsert` | `.role` | school, name, description, permissions (bytes) | `roles` |
| 26 | `ScopeInsert` | `.scope` | school, user, role | `scopes` |
| 27 | `PlanInsert` | `.plan` | name, description, amount, levels, status, features | `plans` |
| 28 | `SubscriptionInsert` | `.subscription` | school, plan, year, term, student, invoice, discount, status | `subscriptions` |
| 29 | `DiscountInsert` | `.discount` | school, plan, year, term, grade, amount, unit | `discounts` |

#### Update Messages (25 total — in `UpdateData` oneof)

**5 tables have NO `*Update` message** (insert/delete only): `owners`, `enrollments`, `subjects`, `lessons`, `scopes`.

| # | Message | Accessor | Updatable fields | Used for table |
|---|---|---|---|---|
| 0 | `UserUpdate` | `.user` | phone, email, name, level, status | `users` |
| 1 | `SchoolUpdate` | `.school` | name, motto, phone, email, county, domain, established, status | `schools` |
| 2 | `StudentUpdate` | `.student` | user, name, dob, gender, documents, admitted, status | `students` |
| 3 | `GuardianUpdate` | `.guardian` | relationship, role | `guardians` |
| 4 | `DepartmentUpdate` | `.department` | description | `departments` |
| 5 | `TeacherUpdate` | `.teacher` | hired, role, department, status | `teachers` |
| 6 | `StaffUpdate` | `.staffMember` | idnumber, role, department, status | `staff` |
| 7 | `TermUpdate` | `.term` | start, end | `terms` |
| 8 | `ClassTeacherUpdate` | `.classTeacher` | start, end | `class_teachers` |
| 9 | `AttendanceUpdate` | `.attendance` | status | `attendance` |
| 10 | `TimetableUpdate` | `.timetable` | teacher, end | `timetable` |
| 11 | `ExamUpdate` | `.exam` | stream, personalized, type, start, end, teacher | `exams` |
| 12 | `PaperUpdate` | `.paper` | invigilator, start, end, status | `papers` |
| 13 | `GradeUpdate` | `.grade` | score, total | `grades` |
| 14 | `FeeUpdate` | `.fee` | title, description, amount, mandatory, due | `fees` |
| 15 | `InvoiceUpdate` | `.invoice` | fee, description, amount, status, due | `invoices` |
| 16 | `PaymentUpdate` | `.payment` | invoice, amount, method, reference, recorder, date | `payments` |
| 17 | `AnnouncementUpdate` | `.announcement` | title, content, grade, stream, audience | `announcements` |
| 18 | `MasteryUpdate` | `.mastery` | score | `mastery` |
| 19 | `AiUsageUpdate` | `.aiUsage` | allocated, used | `aiusage` |
| 20 | `SettingsUpdate` | `.settings` | data, mpesa | `settings` |
| 21 | `RoleUpdate` | `.role` | name, description, permissions | `roles` |
| 22 | `PlanUpdate` | `.plan` | name, description, amount, levels, status, features | `plans` |
| 23 | `SubscriptionUpdate` | `.subscription` | invoice, discount, status | `subscriptions` |
| 24 | `DiscountUpdate` | `.discount` | amount, unit | `discounts` |

### `types/role.pb.dart`

| Message/Enum | Fields/Values | Used by |
|---|---|---|
| `Permission` | `resource` (Resource), `actions` (repeated Action) | Nested inside `Role` message |
| `Role` | `id`, `name`, `permissions` (repeated Permission), `created` | Role definitions from server |
| `Assignment` | `id`, `name`, `assigned` (int64), `profile` (optional string) | Role assignment display info |
| `Resource` enum | `USERS` (0), `SCHOOLS` (1), `OWNERS` (2), `TEACHERS` (3), `STAFF` (4), `STUDENTS` (5), `DEPARTMENTS` (6), `CLASSES` (7), `ATTENDANCE` (8), `LESSONS` (9), `EXAMS` (10), `GRADES` (11), `FEES` (12), `PAYMENTS` (13), `ANNOUNCEMENTS` (14), `ROLES` (15), `PLANS` (16), `AI` (17) | Permission resource targeting |
| `Action` enum | `CREATE` (0), `READ` (1), `UPDATE` (2), `DELETE` (3), `PURGE` (4), `ASSIGN` (5), `UNASSIGN` (6), `MARK` (7), `APPROVE` (8) | Permission action bitmask |

### `types/member.pb.dart`

| Message/Enum | Fields/Values | Used by |
|---|---|---|
| `Membership` | `id`, `name`, `roles` (repeated Role), `logo` (optional string), `created` | School membership info from server |
| `Role` enum | `OWNER` (0), `GUARDIAN` (1), `STUDENT` (2), `TEACHER` (3), `STAFF` (4) | Membership role type |

### `types/verification.pb.dart`

| Message/Enum | Fields/Values | Used by |
|---|---|---|
| `Verification` | `phone`, `code`, `purpose`, `expires` | Not directly used — server-side |
| `Purpose` enum | `LOGIN` (0), `CHANGE_PHONE` (1) | Not directly used by client |

## How Proto Types Map to Domain Models

| Proto type | Domain model | Mapping location |
|---|---|---|
| `proto.Authenticated` + `proto.User` | `Authenticated` (in `models/authenticated.dart`) | `Authentication._mapProtoAuthenticated()` in `services/authentication.dart` |
| `proto.User.Level` | `UserLevel` (in `database/tables/enums.dart`) | Mapped by index in `_mapProtoAuthenticated()` |
| `proto.User.Status` | `UserStatus` (in `database/tables/enums.dart`) | Mapped by index in `_mapProtoAuthenticated()` |
| `sync.*Insert` messages | Drift `*Companion` objects | `DeltaWriter._applySingle()` in `sync/delta_writer.dart` — derives PKs from `rowKey`, mutable fields from `*Insert`, timestamps synthesized locally |
| `sync.InsertData` | Local Drift row data (full row) | `LogProcessor._readInsertData()` in `sync/log_processor.dart` — reads full row from DB, maps to `*Insert` message |
| `sync.UpdateData` | Local Drift row data (partial) | `LogProcessor._readUpdateData()` in `sync/log_processor.dart` — reads row, maps only bitmask-selected columns to `*Update` message |
| `role.Resource` enum | `Resource` (in `models/permissions.dart`) | Mapped by index |
| `role.Action` enum | `Action` (in `models/permissions.dart`) | Mapped by index |

## gRPC Channel

The `AuthenticationClient` is instantiated in `services/authentication.dart` using the `ClientChannel` passed from `client.dart`. The channel is configured in `Client.create()`:

```
ClientChannel(kDomain, port: kPort, options: ChannelOptions(credentials: ChannelCredentials.insecure()))
```

All gRPC calls attach the access token via metadata when needed (e.g. `refresh` uses the global `refreshToken`).

## Dependencies

- **Depends on:** `package:protobuf` (^6.0.0), `package:grpc` (^5.1.0)
- **Depended on by:** `services/authentication.dart`, `sync/delta_writer.dart` (✅ implemented — uses `InsertData` / `*Insert`), `sync/log_processor.dart` (uses `InsertData` / `UpdateData` / `*Insert` / `*Update` — pending S2 migration), `sync/sync_engine.dart` (✅ implemented)

## Conventions

- **Never edit generated files.** If proto definitions change, regenerate with `protoc`.
- Only `services/` layer files should import from `proto/`. UI and models never import proto types directly.
- Proto enums map to Dart enums by index (e.g. `proto.Level.NORMAL.value` → `UserLevel.values[0]`).
- The proto `Authenticated.profile` field (write URL) is **always discarded** after immediate use — never stored in DB or cache.

### `services/question_bank.pbgrpc.dart`

**Service:** `QuestionBankClient` — 14 unary RPCs for question bank management, paper generation, AI marking status, and per-question grade breakdowns.

| RPC | Request | Response |
|---|---|---|
| `CreateQuestion` | `CreateQuestionRequest` | `CreateQuestionResponse` |
| `UpdateQuestion` | `UpdateQuestionRequest` | `UpdateQuestionResponse` |
| `DeleteQuestion` | `DeleteQuestionRequest` | `DeleteQuestionResponse` |
| `BulkImportQuestions` | `BulkImportRequest` | `BulkImportResponse` |
| `RequestImageUploadUrls` | `ImageUploadUrlsRequest` | `ImageUploadUrlsResponse` |
| `GeneratePaper` | `GeneratePaperRequest` | `GeneratePaperResponse` |
| `RegenerateQuestion` | `RegenerateQuestionRequest` | `RegenerateQuestionResponse` |
| `EditPaperQuestion` | `EditPaperQuestionRequest` | `EditPaperQuestionResponse` |
| `FinalizePaper` | `FinalizePaperRequest` | `FinalizePaperResponse` |
| `GetPaperPdf` | `GetPaperPdfRequest` | `GetPaperPdfResponse` |
| `ListQuestions` | `ListQuestionsRequest` | `ListQuestionsResponse` |
| `GetQuestion` | `GetQuestionRequest` | `GetQuestionResponse` |
| `GetQuestionGrades` | `GetQuestionGradesRequest` | `GetQuestionGradesResponse` |
| `GetMarkingStatus` | `MarkingStatusRequest` | `MarkingStatusResponse` |

**Server base class:** `QuestionBankServiceBase` (for server-side implementation).

### `services/question_bank.pb.dart`

**Key message types (37 total):**

- `RubricCriterion` — criterion (string), marks (int)
- `QuestionImage` — context (ImageContext enum), filename (string), caption (string?), description (string), getUrl (string?)
- `Question` — id (int), topicId (int), text (string), marks (int), rubric (repeated RubricCriterion), exampleAnswer (string?), images (repeated QuestionImage), created (Int64), updated (Int64)
- `CreateQuestionRequest/Response`, `UpdateQuestionRequest/Response`, `DeleteQuestionRequest/Response` — standard CRUD wrappers
- `BulkImportRequest` — jsonContent (string); `BulkImportResponse` — createdCount (int), errors (repeated ImportError)
- `ImportError` — index (int), message (string)
- `ImageUploadUrlsRequest` — questionId (int), filenames (repeated string); `ImageUploadUrlsResponse` — urls (repeated SignedImageUrl)
- `SignedImageUrl` — filename (string), putUrl (string), getUrl (string), expiry (Int64)
- `TopicAllocation` — topicId (int), marks (int)
- `GeneratePaperRequest` — school, exam, subject, paper?, grade, stream?, totalMarks, topicAllocations; `GeneratePaperResponse` — paperQuestions (repeated PaperQuestion)
- `PaperQuestion` — id (string), questionId (int), text, marks, rubric, images, order
- `RegenerateQuestionRequest/Response`, `EditPaperQuestionRequest/Response` — single-question mutation wrappers
- `FinalizePaperRequest` — school, exam, subject, paper?, grade, stream?, paperQuestionIds; `FinalizePaperResponse` — pdfUrl, pdfExpiry
- `GetPaperPdfRequest/Response` — same fields as FinalizePaper request/response
- `ListQuestionsRequest` — topicId, offset, limit; `ListQuestionsResponse` — questions, total
- `GetQuestionRequest/Response` — single question by ID
- `GetQuestionGradesRequest` — school, exam, student, subject, paper?; `GetQuestionGradesResponse` — questionGrades (repeated QuestionGrade)
- `QuestionGrade` — questionText, marksAwarded (double), totalMarks (int), feedback, rubricResults (repeated RubricResult)
- `RubricResult` — criterion, satisfied (bool), marksAwarded (double), marksAvailable (int)
- `MarkingStatusRequest` — school, exam, subject, paper?, grade, stream?; `MarkingStatusResponse` — status (MarkingStatusEnum), progressCurrent, progressTotal, errorMessage?

### `services/question_bank.pbenum.dart`

**Enums:**
- `ImageContext` — QUESTION (0), RUBRIC (1), EXAMPLE_ANSWER (2)
- `MarkingStatusEnum` — QUEUED (0), DOWNLOADING (1), MARKING (2), COMPUTING (3), COMPLETE (4), FAILED (5)

### `services/question_bank.pbjson.dart`

Minimal stub — JSON descriptors placeholder. Not required for runtime operation.

**Note:** All four files are hand-written Dart stubs (no `.proto` source file). They follow the same `$pb.GeneratedMessage` / `$grpc.Client` patterns as `ai_marking.*`. If the server provides a `.proto` file in the future, regenerate with `protoc` to replace these stubs.

## Last Updated
Task 20 — Final CONTEXT.md sweep for question bank feature.