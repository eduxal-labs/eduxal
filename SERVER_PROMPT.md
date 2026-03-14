# Server Task: Answer Sheet File Upload API

## Context

EduXal is a school management app. Teachers can photograph student exam answer sheets and upload
them for AI-assisted grading. This document is the **complete specification** for the backend
developer to implement the answer sheet file upload API.

---

## Background: Existing Sync Architecture

The current server exposes two gRPC services:

1. **`Authentication`** (`authentication.proto`) — unary RPCs: `login`, `verify`, `setup`, `refresh`,
   `changePhone`, `confirmChangePhone`.

2. **`Sync`** (`sync.proto`) — two streaming RPCs:
   - `PushActions` — bidirectional stream. Client sends `ActionRequest` (one action at a time),
     server returns `ActionResponse` for each. Used for all data mutations (91 `SyncAction` types).
   - `WatchChanges` — server-streaming. Server pushes `SyncDelta` messages to clients. Used for
     receiving all data changes from other sessions.

The existing `ActionResponse` message already carries a `repeated FileUrl file_urls = 6` field.
`FileUrl` carries `path`, `put_url`, `get_url`, and `expiry`. This mechanism is used for data
entity files (profile photos, school logos, student images) where the file is a side-effect of a
data action.

**Answer sheet uploads are different.** They are:
- Not tied to a single data record mutation in the `papers` or `grades` tables.
- Potentially multiple files per upload session (a teacher photographs 2–5 pages per paper).
- Re-uploadable (idempotent: re-uploading the same path overwrites).
- Not part of the offline action queue — there is no value in queuing "get me a signed URL"; the
  client simply retries when connectivity is restored.
- Not synced to other clients via `WatchChanges` — only the teacher who uploaded needs the URLs.

For these reasons, answer sheet file operations use **direct unary RPCs** in a new **`Files`**
service, not the `pushActions` bidirectional stream.

---

## Database Schema Reference (Relevant Tables)

```sql
-- papers table (primary key: school, exam, subject, paper)
CREATE TABLE papers (
    school      TEXT    NOT NULL,
    exam        TEXT    NOT NULL,       -- FK → exams.id (UUID)
    subject     INTEGER NOT NULL,       -- FK → subjects.id (global catalog; integer)
    topic       INTEGER,                -- FK → topics.id; null = whole-subject paper
    paper       SMALLINT,               -- paper number: 1, 2, 3; null = unnumbered
    invigilator TEXT    NOT NULL,       -- FK → teachers(school, user)
    start       BIGINT  NOT NULL,       -- seconds since epoch
    end         BIGINT  NOT NULL,       -- seconds since epoch
    status      SMALLINT NOT NULL DEFAULT 0,
    -- status: Pending=0, Progress=1, Done=2, Marked=3
    PRIMARY KEY (school, exam, subject, paper)
);

-- grades table (primary key: school, exam, student, subject, paper)
CREATE TABLE grades (
    school      TEXT    NOT NULL,
    exam        TEXT    NOT NULL,
    student     INTEGER NOT NULL,       -- student admission number (integer)
    subject     INTEGER NOT NULL,       -- FK → subjects.id
    paper       SMALLINT,               -- matches papers.paper
    score       REAL    NOT NULL,
    total       INTEGER NOT NULL,
    PRIMARY KEY (school, exam, student, subject, paper)
);

-- exams table
CREATE TABLE exams (
    id          TEXT    NOT NULL PRIMARY KEY,  -- UUID
    school      TEXT    NOT NULL,
    year        INTEGER NOT NULL,
    term        SMALLINT NOT NULL,
    name        TEXT    NOT NULL,
    personalized BOOLEAN NOT NULL DEFAULT false,
    type        SMALLINT NOT NULL,    -- Exam=0, Assignment=1, Assessment=2
    start       INTEGER NOT NULL,    -- days since epoch
    end         INTEGER NOT NULL,    -- days since epoch
    teacher     TEXT    NOT NULL
);
```

---

## S3 Storage Path Convention

Answer sheet images are stored in S3-compatible storage at the following path:

```
schools/{school_id}/exams/{exam_id}/{subject_code}/{paper_number}/{student_adm}/{file_number}.jpg
```

| Segment | Type | Example | Notes |
|---|---|---|---|
| `school_id` | UUID string | `"f3a7b...c2"` | UUID of the school |
| `exam_id` | UUID string | `"9b2e1...f4"` | UUID of the exam |
| `subject_code` | integer | `12` | `subjects.id` from the global catalog |
| `paper_number` | integer | `1` | `papers.paper` value; use `0` when `paper IS NULL` |
| `student_adm` | integer | `1042` | `students.adm` (admission number) |
| `file_number` | integer | `1`, `2`, `3`... | Sequential per upload request, 1-indexed |

### Path Examples

```
schools/f3a7b/exams/9b2e1/12/1/1042/1.jpg    ← subject 12, paper 1, student 1042, file 1
schools/f3a7b/exams/9b2e1/12/1/1042/2.jpg    ← same paper, second image
schools/f3a7b/exams/9b2e1/7/0/2031/1.jpg     ← subject 7, unnumbered paper, student 2031
```

> **Note on `paper_number = 0`:** The `papers.paper` column in the database is a `SMALLINT` that
> can be `NULL` (meaning the subject has a single unnumbered paper). In S3 paths, `NULL` paper is
> represented as `0` to keep paths unambiguous. The server must map `paper = 0` → `papers.paper IS NULL`
> when validating permissions against the database.

---

## Required Changes

### 1. New Proto File: `files.proto`

Create a new proto file `files.proto` in the same directory as `sync.proto` and
`authentication.proto`. This defines a new `Files` gRPC service with three unary RPCs.

```protobuf
syntax = "proto3";

package files;

// ─── Message Types ───────────────────────────────────────────────────────────

// Reuse the FileUrl message from sync.proto if your import structure allows it,
// OR redeclare it here. The message has four fields:
//
//   message FileUrl {
//     string path    = 1;   // S3 object key (path only, no host)
//     string put_url = 2;   // signed PUT URL; only populated in upload responses
//     string get_url = 3;   // signed GET URL; only populated in read responses
//     int64  expiry  = 4;   // seconds since Unix epoch when the URL expires
//   }
//
// If importing from sync.proto, reference it as sync.FileUrl.

// ─── Upload ──────────────────────────────────────────────────────────────────

// Request signed PUT URLs for uploading answer sheet images.
message AnswerSheetUploadRequest {
  string school_id   = 1;  // UUID of the school
  string exam_id     = 2;  // UUID of the exam
  int32  subject     = 3;  // subjects.id (integer, from global catalog)
  int32  paper       = 4;  // papers.paper value; send 0 for unnumbered (null) papers
  int32  student_adm = 5;  // students.adm (admission number)
  int32  file_count  = 6;  // number of PUT URLs requested (1–10)
  int32  start_from  = 7;  // first file_number to generate; default 1 (used for append uploads)
}

// Response containing one signed PUT URL per requested file.
message AnswerSheetUploadResponse {
  repeated FileUrl urls = 1;  // length == request.file_count; each has path + put_url + expiry
}

// ─── Read ─────────────────────────────────────────────────────────────────────

// Request signed GET URLs for existing answer sheet images.
message AnswerSheetReadRequest {
  string school_id   = 1;
  string exam_id     = 2;
  int32  subject     = 3;
  int32  paper       = 4;  // 0 for unnumbered
  int32  student_adm = 5;
}

// Response listing all files currently stored for this paper+student combination.
message AnswerSheetReadResponse {
  repeated AnswerSheetFile files = 1;  // sorted ascending by file_number
}

message AnswerSheetFile {
  int32  file_number  = 1;  // sequential index (1, 2, 3...)
  string path         = 2;  // S3 object key
  string get_url      = 3;  // signed GET URL (valid 24 hours)
  int64  expiry       = 4;  // seconds since epoch when get_url expires
  int64  uploaded_at  = 5;  // seconds since epoch (S3 LastModified)
  int64  size_bytes   = 6;  // file size in bytes (S3 ContentLength)
}

// ─── Delete ───────────────────────────────────────────────────────────────────

// Request to delete specific answer sheet files for a paper+student combination.
message AnswerSheetDeleteRequest {
  string school_id    = 1;
  string exam_id      = 2;
  int32  subject      = 3;
  int32  paper        = 4;  // 0 for unnumbered
  int32  student_adm  = 5;
  repeated int32 file_numbers = 6;  // which file_number(s) to delete; empty = delete ALL
}

message AnswerSheetDeleteResponse {
  int32 deleted_count = 1;  // number of files actually deleted from S3
}

// ─── Bulk Read (for a whole paper, all students) ──────────────────────────────

// Request GET URLs for all students' answer sheets for a specific paper in one call.
// Used by the teacher to load the full paper grading view.
message PaperAnswerSheetsRequest {
  string school_id = 1;
  string exam_id   = 2;
  int32  subject   = 3;
  int32  paper     = 4;  // 0 for unnumbered
}

// One entry per student who has uploaded files.
message StudentSheets {
  int32  student_adm = 1;
  repeated AnswerSheetFile files = 2;  // sorted ascending by file_number
}

message PaperAnswerSheetsResponse {
  repeated StudentSheets students = 1;  // sorted ascending by student_adm
}

// ─── Service Definition ───────────────────────────────────────────────────────

service Files {
  // Get signed PUT URLs for uploading answer sheet images for one student's paper.
  // PUT URLs expire in 1 hour.
  rpc GetAnswerSheetUploadUrls(AnswerSheetUploadRequest) returns (AnswerSheetUploadResponse);

  // Get signed GET URLs for reading existing answer sheet images for one student's paper.
  // GET URLs expire in 24 hours.
  rpc GetAnswerSheetReadUrls(AnswerSheetReadRequest) returns (AnswerSheetReadResponse);

  // Delete specific (or all) answer sheet files for one student's paper.
  rpc DeleteAnswerSheetFiles(AnswerSheetDeleteRequest) returns (AnswerSheetDeleteResponse);

  // Get all answer sheet files across all students for an entire paper.
  // Useful for loading the full grading view without N+1 RPC calls.
  rpc GetPaperAnswerSheets(PaperAnswerSheetsRequest) returns (PaperAnswerSheetsResponse);
}
```

---

### 2. Authentication & Authorization

All `Files` service RPCs require a valid **access token** passed in the gRPC metadata header:

```
authorization: Bearer <access_token>
```

The server must extract and validate the token identically to how `Sync.PushActions` and
`Sync.WatchChanges` do it.

#### Permission Model

| RPC | Required Permission |
|---|---|
| `GetAnswerSheetUploadUrls` | Teacher of the subject (`subject_teachers` row) OR `Grades.Mark` permission on the school |
| `GetAnswerSheetReadUrls` | Same as upload (teacher of the subject OR `Grades.Mark` or `Grades.Read`) |
| `DeleteAnswerSheetFiles` | Same as upload |
| `GetPaperAnswerSheets` | `Grades.Mark` or `Grades.Read` permission on the school |

**Teacher check for upload/read/delete:** The calling user must have an active row in
`subject_teachers` for `(school, year, term, grade_any, stream_any, subject)` where the exam is
currently active (within the exam's `start`..`end` date window). Alternatively, a scope-based
`Grades.Mark` permission bypasses the subject-teacher requirement.

**Important:** Do NOT restrict by `paper.status`. A teacher can upload images for a paper in any
status (Pending, Progress, Done, Marked). The upload does not change paper status — that remains
the domain of the `markGrades` / `updatePaper` sync actions.

#### Error Codes (gRPC status codes)

| Scenario | gRPC status |
|---|---|
| Missing or expired token | `UNAUTHENTICATED` |
| Token valid but no permission | `PERMISSION_DENIED` |
| `school_id`, `exam_id`, `subject`, or `paper` not found | `NOT_FOUND` |
| `file_count` < 1 or > 10 | `INVALID_ARGUMENT` |
| `student_adm` not enrolled in any class covered by the exam | `INVALID_ARGUMENT` |
| S3 operation failure | `INTERNAL` |

---

### 3. Server Implementation Details

#### 3a. `GetAnswerSheetUploadUrls`

```
Input:  AnswerSheetUploadRequest
Output: AnswerSheetUploadResponse
```

1. **Validate token** → extract user ID.

2. **Validate request fields:**
   - `file_count` must be in range [1, 10]. Return `INVALID_ARGUMENT` otherwise.
   - `start_from` defaults to 1 if not provided or ≤ 0.

3. **Validate existence:** Confirm the `(school_id, exam_id, subject, paper)` tuple maps to a row
   in `papers`. If `paper == 0` in the request, query for `papers.paper IS NULL`. Return
   `NOT_FOUND` if no matching paper row exists.

4. **Validate student:** Confirm `student_adm` has an enrollment row in `enrollments` for the
   school+exam scope (join `enrollments` through `exam_grades` — same logic as the
   `grades_enrollment_check` database trigger).

5. **Check permission:** (see §2 above).

6. **Generate PUT URLs:** For `i` in `[start_from, start_from + file_count - 1]`:
   - S3 path: `schools/{school_id}/exams/{exam_id}/{subject}/{paper}/{student_adm}/{i}.jpg`
   - Presign a PUT URL with:
     - Expiry: **3600 seconds (1 hour)**
     - `Content-Type: image/jpeg`
     - Max object size: **10 MB** (use `x-amz-content-sha256` or equivalent condition if supported
       by your S3 provider)
   - Populate `FileUrl { path, put_url, expiry }` (leave `get_url` empty).

7. **Return** `AnswerSheetUploadResponse { urls: [FileUrl, ...] }` with `len(urls) == file_count`.

**Do NOT write anything to the database.** The upload is tracked entirely by S3 object presence.
The client records the local file paths in its own client-only `paper_submissions` table (not
synced). Grades are written later via the normal `markGrades` sync action.

#### 3b. `GetAnswerSheetReadUrls`

```
Input:  AnswerSheetReadRequest
Output: AnswerSheetReadResponse
```

1. **Validate token and permission** (same as upload).

2. **Validate paper existence** (same as upload — `paper = 0` maps to `IS NULL`).

3. **List S3 objects** at prefix:
   ```
   schools/{school_id}/exams/{exam_id}/{subject}/{paper}/{student_adm}/
   ```
   Filter to files matching the pattern `{integer}.jpg`.

4. **For each object found:**
   - Extract `file_number` from the filename (the integer before `.jpg`).
   - Presign a GET URL with expiry **86400 seconds (24 hours)**.
   - Populate `AnswerSheetFile { file_number, path, get_url, expiry, uploaded_at, size_bytes }`.

5. **Sort** by `file_number` ascending.

6. **Return** `AnswerSheetReadResponse { files: [...] }`. Return an empty `files` list (not an
   error) if no objects exist at the prefix.

#### 3c. `DeleteAnswerSheetFiles`

```
Input:  AnswerSheetDeleteRequest
Output: AnswerSheetDeleteResponse
```

1. **Validate token and permission** (same as upload).

2. **Validate paper existence**.

3. **Determine which objects to delete:**
   - If `file_numbers` is empty → list all objects at prefix and delete all of them.
   - If `file_numbers` is non-empty → build the exact S3 paths for each file number and delete
     only those.

4. **Delete objects from S3.** Use batch delete if your S3 SDK supports it (e.g.
   `DeleteObjects` for AWS S3).

5. **Return** `AnswerSheetDeleteResponse { deleted_count: N }`.

**Do NOT touch the database.** If the client later tries to read grades for this paper, grades
remain in the `grades` table unchanged. Deleting images does not delete grades.

#### 3d. `GetPaperAnswerSheets`

```
Input:  PaperAnswerSheetsRequest
Output: PaperAnswerSheetsResponse
```

1. **Validate token and permission** (`Grades.Mark` or `Grades.Read` on the school).

2. **Validate paper existence**.

3. **List all S3 objects** at prefix:
   ```
   schools/{school_id}/exams/{exam_id}/{subject}/{paper}/
   ```
   This prefix covers all students (one level above student_adm).

4. **Group by `student_adm`:** The next path segment after the paper prefix is the student's adm
   number. Extract it from the key and group all files under that adm.

5. **For each student+file:**
   - Presign a GET URL (expiry 86400 seconds).
   - Populate `AnswerSheetFile` as in §3b.

6. **Sort:** students by `student_adm` ascending, files within each student by `file_number`
   ascending.

7. **Return** `PaperAnswerSheetsResponse { students: [...] }`.

---

### 4. Integration with the Existing Sync Protocol

Answer sheet file operations **do NOT go through `pushActions` / `watchChanges`**.

Rationale:
- `pushActions` is an offline action queue for data mutations. Requesting a signed URL is an
  online-only operation that makes no sense to queue — if the client is offline, it cannot upload
  anyway.
- The files themselves are large binary blobs and are uploaded directly to S3, not through gRPC.
- File presence/absence does not alter any synced database table. Grade recording happens
  separately via the normal `markGrades` sync action.
- No other clients need to be notified when an answer sheet image is uploaded — it is a private
  teacher work file, not a shared data record.

The existing `FileUrl` fields on `ActionResponse` and `SyncDelta` are used for a *different*
purpose: when a data entity (user, student, school) has an associated image that changes as a
**side-effect of a data action** (e.g. `CreateStudent` triggers the server to return a presigned
PUT URL for the student's photo). Answer sheets are not side-effects of data actions — they are
standalone file operations.

---

### 5. Relationship to `papers.status`

The `papers.status` column (Pending=0, Progress=1, Done=2, Marked=3) is **not affected** by any
`Files` service RPC. Status changes continue to flow through the `Sync.pushActions` stream via the
`updatePaper` action (`UpdatePaperPayload`).

The intended lifecycle for answer-sheet-assisted grading is:

```
Teacher sets paper status → Done  (via updatePaper sync action)
                 ↓
Teacher photographs answer sheets → uploads via Files.GetAnswerSheetUploadUrls + HTTP PUT
                 ↓
Teacher (or AI) grades → marks scores via markGrades sync action
                 ↓
Teacher sets paper status → Marked (via updatePaper sync action)
```

The server should not block `GetAnswerSheetUploadUrls` based on paper status. Teachers may upload
images in any order relative to status changes.

---

### 6. Dart Client Stub Generation

Once the `files.proto` is authored, the client team will run `protoc` with the `dart_plugin` to
generate:

```
lib/proto/services/files.pb.dart       ← message types
lib/proto/services/files.pbgrpc.dart   ← FilesClient stub
lib/proto/services/files.pbjson.dart   ← JSON helpers
lib/proto/services/files.pbenum.dart   ← enums (if any)
```

The `FilesClient` will be instantiated by the client's `lib/client.dart` using the same
`ClientChannel` as `AuthenticationClient` and `SyncClient`. No changes to `client.dart` are
needed until the stubs are generated.

The client will call each RPC as a **standard unary gRPC call**, passing the access token in
`CallOptions`:

```dart
final options = CallOptions(metadata: {'authorization': 'Bearer $accessToken'});
final response = await _filesClient.getAnswerSheetUploadUrls(request, options: options);
```

---

### 7. AI Grading Integration (Future — Design Guidance Only)

A future `GradeAnswerSheets` RPC will trigger server-side AI processing of uploaded images. The
current file storage structure already supports it: the server can list all objects under
`schools/{school_id}/exams/{exam_id}/{subject}/{paper}/` to find all students' sheets for a paper.

When that RPC is added, the suggested signature is:

```protobuf
message GradeRequest {
  string school_id = 1;
  string exam_id   = 2;
  int32  subject   = 3;
  int32  paper     = 4;
  repeated int32 student_adms = 5;  // empty = grade all students who have uploads
}

message GradeProgress {
  int32  student_adm  = 1;
  bool   done         = 2;
  float  score        = 3;   // suggested score (0.0 – total)
  float  confidence   = 4;   // 0.0 – 1.0
  string reasoning    = 5;   // optional explanation
  string error        = 6;   // non-empty if this student failed
}

rpc GradeAnswerSheets(GradeRequest) returns (stream GradeProgress);
```

**Do not implement this now.** Ensure only that the S3 path structure chosen above is consistent
with the `GradeRequest` parameters.

---

### 8. Security Considerations

1. **Pre-signed URLs must never be returned to unauthorized callers.** Always validate the access
   token and permissions before calling the S3 API. The signed URLs themselves carry no auth —
   anyone who has the URL can use it.

2. **PUT URL scoping:** The presigned PUT URL should be scoped to the specific S3 path. Do not
   return a wildcard or folder-scoped PUT URL.

3. **File type enforcement:** Set `Content-Type: image/jpeg` in the presigned PUT URL conditions
   where supported. The client MUST send `Content-Type: image/jpeg` in the PUT request.

4. **File size limit:** Enforce a maximum of **10 MB per file** at the S3 presigned URL level if
   your provider supports content-length restrictions in presigned URLs (AWS S3 supports
   `x-amz-content-sha256` conditions; other providers vary).

5. **path traversal:** Sanitize all integer inputs (`subject`, `paper`, `student_adm`,
   `file_number`, `file_count`) to ensure they are non-negative integers before interpolating into
   S3 paths. Reject requests with negative values with `INVALID_ARGUMENT`.

---

### 9. Summary of New Artifacts

| Artifact | Type | Description |
|---|---|---|
| `files.proto` | New proto file | Defines `Files` service + 4 RPCs + 8 message types |
| `FilesServiceImpl` | Server class | Implements the 4 RPCs with S3 + DB access |
| `files.pb.dart` | Generated (client) | Dart message stubs (generated from proto) |
| `files.pbgrpc.dart` | Generated (client) | `FilesClient` Dart stub (generated from proto) |

No changes are required to:
- `sync.proto` or `sync.pb.dart` — the existing sync protocol is untouched.
- `authentication.proto` — auth is unchanged.
- Any database tables — no new tables, triggers, or indexes are needed.
- `ActionResponse` or `SyncDelta` — these are not used for answer sheet files.