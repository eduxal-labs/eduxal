# EduXal — Conversation Context Snapshot (v2)

> **Purpose:** This document captures the complete state of an architectural redesign conversation.
> The sync layer is being migrated from a **mutation-based** model to an **action-based** model.
> This file is the ONLY thing the next session needs to read before creating tasks.
>
> **Date:** July 2025
>
> **Immediate next action:** Read this file, then create task lists in BOTH repos:
> - `eduxal/TASKS.md` — client tasks
> - `/home/abdihakim/Documents/GITHUB/eduxal-labs/ledger/TASKS.md` — server tasks
>
> **Timeline:** 7 days to product-ready. Sync redesign = 1 day. Tasks are executed by Claude Opus
> agents sequentially — one task at a time, clearly defined, self-sufficient.

---

## 1. What Is EduXal

School management application. Flutter (Android/iOS/desktop). Local-first architecture.

- All data in local **Drift (SQLite)** database on user's device.
- UI reads only from local DB via reactive Drift streams — never directly from network.
- Network layer (**gRPC**) handles authentication and syncing.
- App works fully offline. Mutations queue locally, replay when online.

**Backend:** Rust + tonic (gRPC) + Diesel ORM + SQLite. Located at `../ledger/`.
**Reference server:** `../server/` — old pre-local-first code. Patterns were already ported to `../ledger/`.

---

## 2. Project Paths

| Repo | Path | Purpose |
|------|------|---------|
| Client | `/home/abdihakim/Documents/GITHUB/eduxal-labs/eduxal/` | Flutter app (in-IDE project root) |
| Server (active) | `/home/abdihakim/Documents/GITHUB/eduxal-labs/ledger/` | Rust gRPC server |
| Server (reference) | `/home/abdihakim/Documents/GITHUB/eduxal-labs/server/` | Old server — patterns already ported, DO NOT modify |

---

## 3. What's Already Built

### Client — Complete

| Layer | Status |
|-------|--------|
| Database (32 Drift tables, 21 DAOs, all enums/converters) | ✅ Complete |
| Models (16 files: Result, Authenticated, SchoolContext, etc.) | ✅ Complete |
| Services (auth, members, member_management) | ✅ Complete |
| Auth flow (login, OTP, setup, splash) | ✅ Complete |
| Home screen (membership picker) | ✅ Complete |
| School dashboard (8 sections) | ✅ ~95% |
| System admin dashboard (8 sections) | ✅ Complete |
| Notifications UI (failed sync display — 3 surfaces) | ✅ Complete |
| Seeder (`lib/core/seeder.dart` — ~2200 lines) | ✅ Complete |
| Sync engine (`lib/sync/`) | ⚠️ EXISTS — being rewritten |

### Server — Complete Foundation + Working (Buggy) Sync

| Component | Status | Lines |
|-----------|--------|-------|
| Authentication (login, verify, setup, refresh, changePhone, confirmChangePhone) | ✅ Complete | — |
| Diesel schema (all 30 tables generated) | ✅ Complete | — |
| Domain types (Id, Phone, Token, Error, User, Role, Permissions, Actions, Resource, Organisation) | ✅ Complete | — |
| Authorization (`Authorize` trait — 3-tier: Super bypass, System+school merge, Normal) | ✅ Complete | ~150 lines |
| Database traits (Create, Find, Update, Load, Authorize, List, Search, Delete, Purge + Database blanket) | ✅ Complete | ~170 lines |
| Membership queries (user→schools, schools→co-members) | ✅ Complete | ~120 lines |
| Binary changelog (`changelog.rs` — append-only log + deletes sidecar) | ✅ Complete | ~350 lines |
| Sync service (`services/sync.rs` — full PushChanges + WatchChanges) | ✅ Complete but BUGGY | ~3400 lines |
| Per-table insert/update/delete/snapshot/rows | ✅ Complete (all 30 tables) | ~4300 lines |
| Proto definitions (`sync.proto` — mutation-based) | ✅ Complete — TO BE REPLACED | — |

**The server has a fully working mutation-based sync engine.** It is being replaced because of
structural issues (FK violations, database locks under load) that come from the mutation-based
transmission model, not from the data logic itself.

---

## 4. Why the Sync Layer Must Be Redesigned

### The Problem

When the client seeder creates hundreds of rows and the sync engine pushes them to the server,
two errors occur in massive amounts:

1. **FK violations** — The mutation-based model sends raw table inserts. Even with dependency
   ordering on both client and server, timing and concurrency create situations where child
   rows arrive before parent rows exist on the server.

2. **Database locks** — The batch-based push (up to 10 batches with 50ms gaps, each with up to
   500 mutations) creates extreme contention on the single SQLite file.

### The Root Cause

The mutation-based model requires the client to reconstruct the server's database row-by-row.
This is inherently fragile because:
- FK ordering across tables in a single-writer SQLite DB creates lock contention
- The client must understand and reproduce server-side relationships
- Error recovery is per-row, making debugging nearly impossible
- The `LogProcessor` (~2100 lines of coalescing/pairing/sorting) is a complexity hotspot

### The Decision

Replace the mutation-based sync with an **action-based** sync model where:
- Client logs semantic actions (like "CreateSchool", "InviteTeacher") instead of raw mutations
- Each action is a self-contained request with all data the server needs
- Server executes the action atomically, handles all side effects (FK creation, user lookup)
- Actions stream one-at-a-time (no batching) in creation order — natural backpressure
- Server responds per-action with success/failure + human-readable errors

This eliminates: the entire `LogProcessor`, batch tracking, FK ordering, invitation pairing,
coalescing, and all the bugs above.

---

## 5. The Action-Based Sync Design

### 5a. Design Philosophy

| Concern | Old (Mutation-Based) | New (Action-Based) |
|---------|---------------------|--------------------|
| Client logs | Raw table mutations (insert/update/delete per table) | Semantic actions (CreateSchool, InviteTeacher) |
| Payload | Row data read from local DB at sync time | Full action payload captured at action time, stored in log |
| FK ordering | Client sorts by dependency level (~2000 lines) | Server handles internally — single atomic transaction |
| Invitation flow | Client creates user + member rows, pairs in batch | Client sends single action, server creates both |
| Error messages | "row X in table Y: FK violation" | "InviteTeacher failed: school not found" |
| Batch complexity | Coalescing, pairing, FK sorting, batch ID tracking | Gone — one action per stream message |
| Transport | Up to 10 batches of 500 mutations concurrently | Sequential one-at-a-time with ack |
| DB locking | Massive contention from concurrent batch writes | Single sequential write per action |

### 5b. Optimistic Local-First

1. **User performs action** → client writes to local DB immediately
2. **Client logs the action** → stores action type + full payload in `logs` table
3. **Sync engine sends action** → when online, sends one action at a time via gRPC stream
4. **Server executes action** → validates permissions, applies to DB atomically, returns result
5. **Client applies server response** → updates local DB with server's authoritative data
6. **If server rejects** → mark as failed, show in notifications with human-readable error

### 5c. One-at-a-Time Streaming (No Batching)

Actions are sent **sequentially in creation order**. The client waits for the server's ack
before sending the next action. This guarantees:

- **No FK violations:** If a school was created before a teacher, the school action is sent
  and acked before the teacher action is sent. The server DB has the school by the time the
  teacher action arrives.
- **No database locks:** Only one write transaction at a time on the server's SQLite.
- **Natural backpressure:** The client can't overwhelm the server.
- **Simple error handling:** Each ack maps to exactly one log row.

The seeder must also create data sequentially (simulating human actions) rather than in batches.

### 5d. Action List

Actions map to the Resource × Action permission matrix. Each action is a semantic operation
that the server handles atomically, including all side effects.

**Resource: Schools**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateSchool` | School data + owner (phone, name) | Creates school, looks up owner by phone (create invited user if not found), creates owner record, creates default settings | School + Owner + User + Settings rows |
| `UpdateSchool` | School ID + changed fields | Updates school | Updated school row |
| `DeleteSchool` | School ID | Soft-deletes school (status change) | Updated school row |

**Resource: Teachers (member invitation pattern)**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateTeacher` | School ID + user (phone, name) + teacher data | Looks up user by phone → exists? Link. Doesn't exist? Create invited user. Creates teacher record. | Teacher + User rows |
| `UpdateTeacher` | School ID + user ID + changed fields | Updates teacher | Updated teacher row |
| `DeleteTeacher` | School ID + user ID | Deletes teacher record | — |

**Same invitation pattern applies to:** `CreateStaff`, `CreateOwner`, `CreateGuardian`

**Resource: Students**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateStudent` | School ID + student data (name, adm, etc.) | Creates student | Student row |
| `UpdateStudent` | School ID + adm + changed fields | Updates student | Updated student row |
| `DeleteStudent` | School ID + adm | Soft-deletes student | Updated student row |
| `EnrollStudent` | School + year + term + grade + stream + student adm | Creates enrollment | Enrollment row |
| `UnenrollStudent` | Same PK fields | Deletes enrollment | — |

**Resource: Departments**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateDepartment` | School ID + name + description? | Creates department | Department row |
| `UpdateDepartment` | School ID + name + changed fields | Updates department | Updated department row |
| `DeleteDepartment` | School ID + name | Deletes department | — |

**Resource: Terms**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateTerm` | School + year + term + start + end | Creates term | Term row |
| `UpdateTerm` | School + year + term + changed fields | Updates term | Updated term row |
| `DeleteTerm` | School + year + term | Deletes term | — |

**Resource: Classes (covers class_teachers, subjects, timetable)**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `AssignClassTeacher` | School + year + term + grade + stream + teacher + start + end? | Creates class_teacher | ClassTeacher row |
| `UnassignClassTeacher` | Full PK | Deletes class_teacher | — |
| `AssignSubject` | School + year + term + grade + stream + subject + teacher | Creates subject | Subject row |
| `UnassignSubject` | Full PK | Deletes subject | — |
| `CreateTimetableEntry` | Full timetable data | Creates timetable row | Timetable row |
| `UpdateTimetableEntry` | PK + changed fields | Updates timetable | Updated timetable row |
| `DeleteTimetableEntry` | Full PK | Deletes timetable row | — |

**Resource: Attendance**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `MarkAttendance` | School + year + term + grade + stream + date + records: [{student, status}] | Upserts attendance records (batch within single action) | All affected attendance rows |
| `DeleteAttendance` | Full PK | Deletes single attendance record | — |

**Resource: Lessons**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateLesson` | Full lesson data | Creates lesson | Lesson row |
| `DeleteLesson` | Full PK | Deletes lesson | — |

**Resource: Exams**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateExam` | Exam data | Creates exam | Exam row |
| `UpdateExam` | Exam ID + changed fields | Updates exam | Updated exam row |
| `DeleteExam` | Exam ID | Deletes exam | — |
| `CreatePaper` | Paper data | Creates paper | Paper row |
| `UpdatePaper` | PK + changed fields | Updates paper | Updated paper row |
| `DeletePaper` | Full PK | Deletes paper | — |

**Resource: Grades**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `MarkGrades` | School + exam + subject + paper? + records: [{student, score, total}] | Upserts grade records | All affected grade rows |
| `UpdateGrade` | Full PK + changed fields | Updates single grade | Updated grade row |
| `DeleteGrade` | Full PK | Deletes grade | — |
| `UpdateMastery` | Full PK + score | Upserts mastery | Mastery row |

**Resource: Fees**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateFee` | Fee data | Creates fee | Fee row |
| `UpdateFee` | Fee ID + changed fields | Updates fee | Updated fee row |
| `DeleteFee` | Fee ID | Deletes fee | — |
| `CreateInvoice` | Invoice data | Creates invoice | Invoice row |
| `UpdateInvoice` | Invoice ID + changed fields | Updates invoice | Updated invoice row |
| `DeleteInvoice` | Invoice ID | Deletes invoice | — |

**Resource: Payments**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreatePayment` | Payment data | Creates payment | Payment row |
| `UpdatePayment` | Payment ID + changed fields | Updates payment | Updated payment row |
| `DeletePayment` | Payment ID | Deletes payment | — |
| `ApprovePayment` | Payment ID | Marks payment approved | Updated payment row |

**Resource: Announcements**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateAnnouncement` | Announcement data | Creates announcement | Announcement row |
| `UpdateAnnouncement` | Announcement ID + changed fields | Updates announcement | Updated announcement row |
| `DeleteAnnouncement` | Announcement ID | Deletes announcement | — |

**Resource: Roles**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateRole` | Role data (school?, name, description?, permissions blob) | Creates role | Role row |
| `UpdateRole` | Role ID + changed fields | Updates role | Updated role row |
| `DeleteRole` | Role ID | Deletes role | — |
| `AssignRole` | School? + user + role | Creates scope | Scope row |
| `UnassignRole` | School? + user + role | Deletes scope | — |

**Resource: Users**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `UpdateUser` | User ID + changed fields | Updates user | Updated user row |
| `DeleteUser` | User ID | Soft-deletes user (status change) | Updated user row |

**Resource: Settings**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `UpdateSettings` | School ID + data? + mpesa? | Upserts settings | Settings row |

**Resource: Plans (System/Super only)**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreatePlan` | Plan data | Creates plan | Plan row |
| `UpdatePlan` | Plan ID + changed fields | Updates plan | Updated plan row |
| `DeletePlan` | Plan ID | Deletes plan | — |

**Resource: AI**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `UpdateAiUsage` | Full PK + allocated? + used? | Upserts AI usage | AiUsage row |

**Resource: Subscriptions/Discounts (under Plans)**

| Action | Client sends | Server does | Server returns |
|--------|-------------|-------------|----------------|
| `CreateSubscription` | Subscription data | Creates subscription | Subscription row |
| `UpdateSubscription` | Full PK + changed fields | Updates subscription | Updated subscription row |
| `DeleteSubscription` | Full PK | Deletes subscription | — |
| `CreateDiscount` | Discount data | Creates discount | Discount row |
| `UpdateDiscount` | Full PK + changed fields | Updates discount | Updated discount row |
| `DeleteDiscount` | Full PK | Deletes discount | — |

### 5e. Invitation / Phone Conflict Resolution

When the client invites a member (teacher/staff/owner/guardian), it creates a local user row
with the provided phone and name, plus the member row linking to that user ID. Both are written
to the local DB immediately (optimistic).

When the action syncs to the server:

**Happy path (phone doesn't exist on server):**
1. Server creates user with `status = Invited`, assigns its own ID
2. Server creates member record pointing to the new user
3. Server returns both rows
4. Client updates local DB with server's authoritative data (IDs, timestamps)

**Conflict path (phone already exists on server):**
1. Server finds existing user by phone
2. Server creates member record pointing to the EXISTING user (ID = `u`)
3. Server returns: existing user row (ID = `u`) + member row
4. Client must reconcile:
   - The local user (ID = `i`, phone = `x`) was optimistic and wrong
   - Change local user `i`'s phone from `x` to `"0"` (or delete user `i`)
   - Create/update local user `u` with the server's data (phone = `x`)
   - Update all local records that reference user `i` to reference user `u`
   - Delete local user `i` if it has no remaining references

This reconciliation happens in the sync engine's response handler, not in the DAO layer.

### 5f. The Redesigned `logs` Table (Client-Side)

```sql
CREATE TABLE logs (
    id        INTEGER  PRIMARY KEY AUTOINCREMENT,
    account   TEXT     NOT NULL,      -- FK → accounts.id
    action    SMALLINT NOT NULL,      -- SyncAction enum
    resource  TEXT     NOT NULL,      -- Display key (school name, user phone, etc.)
    payload   BLOB     NOT NULL,      -- Serialized proto action message
    status    SMALLINT NOT NULL DEFAULT 0,  -- 0 = pending, 1 = failed
    attempts  SMALLINT NOT NULL DEFAULT 0,
    error     TEXT,                   -- Human-readable error from server
    created   BIGINT   NOT NULL       -- ms since epoch
);
```

**Key differences from old logs table:**
- `tbl` + `op` + `columns` → replaced by single `action` (SyncAction enum)
- `row_key` → replaced by `resource` (for display/dedup only, not for data lookup)
- NEW: `payload` (BLOB) — protobuf-serialized action data, captured at action time
- Payload is self-contained: sync engine does NOT read from other tables to build the message
- Successful log rows are DELETED (not marked)
- Failed rows persist and show in notifications UI

### 5g. The `SyncAction` Enum (Client-Side)

```dart
enum SyncAction {
  // Schools
  createSchool(0),
  updateSchool(1),
  deleteSchool(2),
  
  // Teachers
  createTeacher(3),
  updateTeacher(4),
  deleteTeacher(5),
  
  // Staff
  createStaff(6),
  updateStaff(7),
  deleteStaff(8),
  
  // Owners
  createOwner(9),
  deleteOwner(10),
  
  // Students
  createStudent(11),
  updateStudent(12),
  deleteStudent(13),
  enrollStudent(14),
  unenrollStudent(15),
  
  // Guardians
  createGuardian(16),
  updateGuardian(17),
  deleteGuardian(18),
  
  // Departments
  createDepartment(19),
  updateDepartment(20),
  deleteDepartment(21),
  
  // Terms
  createTerm(22),
  updateTerm(23),
  deleteTerm(24),
  
  // Classes
  assignClassTeacher(25),
  unassignClassTeacher(26),
  assignSubject(27),
  unassignSubject(28),
  createTimetableEntry(29),
  updateTimetableEntry(30),
  deleteTimetableEntry(31),
  
  // Attendance
  markAttendance(32),
  deleteAttendance(33),
  
  // Lessons
  createLesson(34),
  deleteLesson(35),
  
  // Exams
  createExam(36),
  updateExam(37),
  deleteExam(38),
  createPaper(39),
  updatePaper(40),
  deletePaper(41),
  
  // Grades
  markGrades(42),
  updateGrade(43),
  deleteGrade(44),
  updateMastery(45),
  
  // Fees
  createFee(46),
  updateFee(47),
  deleteFee(48),
  createInvoice(49),
  updateInvoice(50),
  deleteInvoice(51),
  
  // Payments
  createPayment(52),
  updatePayment(53),
  deletePayment(54),
  approvePayment(55),
  
  // Announcements
  createAnnouncement(56),
  updateAnnouncement(57),
  deleteAnnouncement(58),
  
  // Roles
  createRole(59),
  updateRole(60),
  deleteRole(61),
  assignRole(62),
  unassignRole(63),
  
  // Users
  updateUser(64),
  deleteUser(65),
  
  // Settings
  updateSettings(66),
  
  // Plans
  createPlan(67),
  updatePlan(68),
  deletePlan(69),
  
  // AI
  updateAiUsage(70),
  
  // Subscriptions
  createSubscription(71),
  updateSubscription(72),
  deleteSubscription(73),
  
  // Discounts
  createDiscount(74),
  updateDiscount(75),
  deleteDiscount(76);

  const SyncAction(this.value);
  final int value;
}
```

### 5h. Server-Side Change Tracking (Adapted Changelog)

The existing binary changelog (`src/db/changelog.rs`) is kept and adapted. Instead of storing
raw mutation metadata, it stores action results.

**Current changelog record (24 bytes, fixed width):**
```
[user_id: 12 bytes, table: 1 byte, op: 1 byte, columns: 2 bytes, created: 8 bytes]
```

**Adapted approach:** The changelog record format stays the same (it already has `table` and `op`
which is all the watch loop needs). When the watch loop sees a new record, it:

1. Reads the `table` and `op` from the changelog record
2. If `op` is Insert or Update: queries the actual DB table for the current row data using
   timestamp-based filtering (`snapshot_table_since`)
3. If `op` is Delete: reads from the deletes sidecar file (which stores `table + row_key`)
4. Streams the result as a `SyncDelta` to connected clients

This is exactly what the current watch loop already does. **The watch side needs minimal changes.**

The push side changes significantly: instead of `process_batch` handling N mutations, we have
`process_action` handling one semantic action at a time, executing it in a single transaction,
and appending to the changelog on success.

### 5i. Redesigned Push Flow

**Old flow:**
1. Client sends `MutationBatch` with up to 500 mutations
2. Server processes all mutations, tracks batch IDs, returns per-mutation results
3. Client maps results back to log IDs (broken mapping)

**New flow:**
1. Client sends `ActionRequest` with exactly one action
2. Server validates permissions, executes action in single transaction
3. Server appends changelog record(s) for affected tables
4. Server returns `ActionResponse` with success/failure + affected row data
5. Client receives response, updates local DB, deletes log row (or marks failed)
6. Client sends next action

### 5j. The Redesigned `sync.proto`

```protobuf
syntax = "proto3";
package sync;

service Sync {
  // Client streams actions one at a time, server responds to each
  rpc PushActions(stream ActionRequest) returns (stream ActionResponse);
  // Server streams changes to client (UNCHANGED from current)
  rpc WatchChanges(WatchRequest) returns (stream SyncDelta);
}

// ─── Push (Client → Server) ───

message ActionRequest {
  int32 id = 1;           // Client-assigned ID for correlation (log row ID)
  int32 action = 2;       // SyncAction enum value
  bytes payload = 3;      // Serialized action-specific proto message
}

message ActionResponse {
  int32 id = 1;           // Matches ActionRequest.id
  bool success = 2;
  int32 code = 3;         // 0=ok, 1=permission_denied, 2=conflict, 3=validation, 4=not_found
  string error = 4;       // Human-readable error message
  repeated ActionRow rows = 5;    // Affected rows (for client to update local DB)
  repeated FileUrl file_urls = 6; // Presigned URLs if action involves files
}

// A row returned by the server after an action executes
message ActionRow {
  int32 table = 1;        // Which table this row belongs to (same numbering as current)
  int32 operation = 2;    // 0=upsert, 2=delete
  string row_key = 3;
  InsertData data = 4;    // Full row data (for upsert); absent for delete
}

// ─── Watch (Server → Client) — UNCHANGED ───

message WatchRequest {
  int64 last_seq = 1;
}

message SyncDelta {
  int64 seq = 1;
  int32 table = 2;
  int32 operation = 3;    // 0=Insert (upsert), 2=Delete
  string row_key = 4;
  InsertData data = 5;
  repeated FileUrl file_urls = 6;
}

message FileUrl {
  string path = 1;
  optional string put_url = 2;
  optional string get_url = 3;
  int64 expiry = 4;
}

// ─── Action Payload Messages ───
// Each action has a purpose-built payload message.
// These replace the old per-table Insert/Update messages for the push direction.
// The old InsertData/UpdateData oneofs are KEPT for the watch direction (SyncDelta.data).

message CreateSchoolPayload {
  string id = 1;               // Client-generated school ID
  string name = 2;
  optional string motto = 3;
  optional string phone = 4;
  optional string email = 5;
  int32 county = 6;
  optional string domain = 7;
  optional int32 established = 8;
  // Owner info (invitation pattern)
  string owner_id = 10;        // Client-generated user ID for owner
  string owner_phone = 11;
  string owner_name = 12;
  optional string owner_email = 13;
}

message UpdateSchoolPayload {
  string id = 1;
  optional string name = 2;
  optional string motto = 3;
  optional string phone = 4;
  optional string email = 5;
  optional int32 county = 6;
  optional string domain = 7;
  optional int32 established = 8;
  optional int32 status = 9;
}

message DeleteSchoolPayload {
  string id = 1;
}

// Member invitation pattern (same structure for Teacher/Staff/Owner/Guardian)
message CreateTeacherPayload {
  string school = 1;
  string user_id = 2;          // Client-generated user ID
  string phone = 3;
  string name = 4;
  optional string email = 5;
  optional int32 hired = 6;
  optional string role = 7;
  optional string department = 8;
}

message UpdateTeacherPayload {
  string school = 1;
  string user = 2;
  optional int32 hired = 3;
  optional string role = 4;
  optional string department = 5;
  optional int32 status = 6;
}

message DeleteTeacherPayload {
  string school = 1;
  string user = 2;
}

message CreateStaffPayload {
  string school = 1;
  string user_id = 2;
  string phone = 3;
  string name = 4;
  optional string email = 5;
  optional string idnumber = 6;
  optional string role = 7;
  optional string department = 8;
}

message UpdateStaffPayload {
  string school = 1;
  string user = 2;
  optional string idnumber = 3;
  optional string role = 4;
  optional string department = 5;
  optional int32 status = 6;
}

message DeleteStaffPayload {
  string school = 1;
  string user = 2;
}

message CreateOwnerPayload {
  string school = 1;
  string user_id = 2;
  string phone = 3;
  string name = 4;
  optional string email = 5;
}

message DeleteOwnerPayload {
  string school = 1;
  string user = 2;
}

message CreateStudentPayload {
  string school = 1;
  int32 adm = 2;
  optional string user = 3;
  string name = 4;
  optional int32 dob = 5;
  optional int32 gender = 6;
  optional string documents = 7;
  optional int32 admitted = 8;
}

message UpdateStudentPayload {
  string school = 1;
  int32 adm = 2;
  optional string user = 3;
  optional string name = 4;
  optional int32 dob = 5;
  optional int32 gender = 6;
  optional string documents = 7;
  optional int32 admitted = 8;
  optional int32 status = 9;
}

message DeleteStudentPayload {
  string school = 1;
  int32 adm = 2;
}

message EnrollStudentPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 student = 6;
}

message UnenrollStudentPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 student = 6;
}

message CreateGuardianPayload {
  string school = 1;
  string user_id = 2;
  string phone = 3;
  string name = 4;
  optional string email = 5;
  int32 student = 6;
  int32 relationship = 7;
  int32 role = 8;
}

message UpdateGuardianPayload {
  string school = 1;
  string user = 2;
  int32 student = 3;
  optional int32 relationship = 4;
  optional int32 role = 5;
}

message DeleteGuardianPayload {
  string school = 1;
  string user = 2;
  int32 student = 3;
}

message CreateDepartmentPayload {
  string school = 1;
  string name = 2;
  optional string description = 3;
}

message UpdateDepartmentPayload {
  string school = 1;
  string name = 2;
  optional string description = 3;
}

message DeleteDepartmentPayload {
  string school = 1;
  string name = 2;
}

message CreateTermPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int64 start = 4;
  int64 end = 5;
}

message UpdateTermPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  optional int64 start = 4;
  optional int64 end = 5;
}

message DeleteTermPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
}

message AssignClassTeacherPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  string teacher = 6;
  int32 start = 7;
  optional int32 end = 8;
}

message UnassignClassTeacherPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  string teacher = 6;
}

message AssignSubjectPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 subject = 6;
  string teacher = 7;
}

message UnassignSubjectPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 subject = 6;
}

message CreateTimetableEntryPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 subject = 6;
  string teacher = 7;
  int32 day = 8;
  int32 start = 9;
  int32 end = 10;
}

message UpdateTimetableEntryPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 subject = 6;
  int32 day = 7;
  int32 start = 8;
  optional string teacher = 9;
  optional int32 end = 10;
}

message DeleteTimetableEntryPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 subject = 6;
  int32 day = 7;
  int32 start = 8;
}

message AttendanceRecord {
  int32 student = 1;
  int32 status = 2;
}

message MarkAttendancePayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 date = 6;
  repeated AttendanceRecord records = 7;
}

message DeleteAttendancePayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 student = 6;
  int32 date = 7;
}

message CreateLessonPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 date = 6;
  int32 subject = 7;
  string teacher = 8;
}

message DeleteLessonPayload {
  string school = 1;
  int32 year = 2;
  int32 term = 3;
  int32 grade = 4;
  int32 stream = 5;
  int32 date = 6;
  int32 subject = 7;
  string teacher = 8;
}

message CreateExamPayload {
  string id = 1;
  string school = 2;
  int32 year = 3;
  int32 term = 4;
  int32 grade = 5;
  optional int32 stream = 6;
  bool personalized = 7;
  int32 type = 8;
  int32 start = 9;
  int32 end = 10;
  string teacher = 11;
}

message UpdateExamPayload {
  string id = 1;
  optional int32 stream = 2;
  optional bool personalized = 3;
  optional int32 type = 4;
  optional int32 start = 5;
  optional int32 end = 6;
  optional string teacher = 7;
}

message DeleteExamPayload {
  string id = 1;
}

message CreatePaperPayload {
  string school = 1;
  string exam = 2;
  int32 subject = 3;
  optional int32 paper = 4;
  string invigilator = 5;
  int64 start = 6;
  int64 end = 7;
}

message UpdatePaperPayload {
  string school = 1;
  string exam = 2;
  int32 subject = 3;
  optional int32 paper = 4;
  optional string invigilator = 5;
  optional int64 start = 6;
  optional int64 end = 7;
  optional int32 status = 8;
}

message DeletePaperPayload {
  string school = 1;
  string exam = 2;
  int32 subject = 3;
  optional int32 paper = 4;
}

message GradeRecord {
  int32 student = 1;
  float score = 2;
  int32 total = 3;
}

message MarkGradesPayload {
  string school = 1;
  string exam = 2;
  int32 subject = 3;
  optional int32 paper = 4;
  repeated GradeRecord records = 5;
}

message UpdateGradePayload {
  string school = 1;
  string exam = 2;
  int32 student = 3;
  int32 subject = 4;
  optional int32 paper = 5;
  optional float score = 6;
  optional int32 total = 7;
}

message DeleteGradePayload {
  string school = 1;
  string exam = 2;
  int32 student = 3;
  int32 subject = 4;
  optional int32 paper = 5;
}

message UpdateMasteryPayload {
  string school = 1;
  int32 student = 2;
  int32 grade = 3;
  int32 subject = 4;
  int32 topic = 5;
  float score = 6;
}

message CreateFeePayload {
  string id = 1;
  string school = 2;
  int32 year = 3;
  int32 term = 4;
  int32 grade = 5;
  string title = 6;
  string description = 7;
  float amount = 8;
  bool mandatory = 9;
  int64 due = 10;
}

message UpdateFeePayload {
  string id = 1;
  optional string title = 2;
  optional string description = 3;
  optional float amount = 4;
  optional bool mandatory = 5;
  optional int64 due = 6;
}

message DeleteFeePayload {
  string id = 1;
}

message CreateInvoicePayload {
  string id = 1;
  string school = 2;
  int32 year = 3;
  int32 term = 4;
  optional string fee = 5;
  optional string description = 6;
  int32 student = 7;
  float amount = 8;
  optional int64 due = 9;
}

message UpdateInvoicePayload {
  string id = 1;
  optional string fee = 2;
  optional string description = 3;
  optional float amount = 4;
  optional int32 status = 5;
  optional int64 due = 6;
}

message DeleteInvoicePayload {
  string id = 1;
}

message CreatePaymentPayload {
  string id = 1;
  optional string invoice = 2;
  optional string school = 3;
  optional int32 student = 4;
  float amount = 5;
  int32 method = 6;
  optional string reference = 7;
  optional string recorder = 8;
  optional int32 date = 9;
}

message UpdatePaymentPayload {
  string id = 1;
  optional string invoice = 2;
  optional float amount = 3;
  optional int32 method = 4;
  optional string reference = 5;
  optional string recorder = 6;
  optional int32 date = 7;
}

message DeletePaymentPayload {
  string id = 1;
}

message ApprovePaymentPayload {
  string id = 1;
}

message CreateAnnouncementPayload {
  string id = 1;
  string school = 2;
  string title = 3;
  string content = 4;
  optional int32 grade = 5;
  optional int32 stream = 6;
  int32 audience = 7;
  optional string author = 8;
}

message UpdateAnnouncementPayload {
  string id = 1;
  optional string title = 2;
  optional string content = 3;
  optional int32 grade = 4;
  optional int32 stream = 5;
  optional int32 audience = 6;
}

message DeleteAnnouncementPayload {
  string id = 1;
}

message CreateRolePayload {
  string id = 1;
  optional string school = 2;
  string name = 3;
  optional string description = 4;
  bytes permissions = 5;
}

message UpdateRolePayload {
  string id = 1;
  optional string name = 2;
  optional string description = 3;
  optional bytes permissions = 4;
}

message DeleteRolePayload {
  string id = 1;
}

message AssignRolePayload {
  optional string school = 1;
  string user = 2;
  string role = 3;
}

message UnassignRolePayload {
  optional string school = 1;
  string user = 2;
  string role = 3;
}

message UpdateUserPayload {
  string id = 1;
  optional string phone = 2;
  optional string email = 3;
  optional string name = 4;
  optional int32 level = 5;
  optional int32 status = 6;
}

message DeleteUserPayload {
  string id = 1;
}

message UpdateSettingsPayload {
  string school = 1;
  optional string data = 2;
  optional string mpesa = 3;
}

message CreatePlanPayload {
  string id = 1;
  string name = 2;
  optional string description = 3;
  float amount = 4;
  int32 levels = 5;
  optional string features = 6;
}

message UpdatePlanPayload {
  string id = 1;
  optional string name = 2;
  optional string description = 3;
  optional float amount = 4;
  optional int32 levels = 5;
  optional int32 status = 6;
  optional string features = 7;
}

message DeletePlanPayload {
  string id = 1;
}

message UpdateAiUsagePayload {
  string school = 1;
  int32 student = 2;
  int32 year = 3;
  int32 term = 4;
  optional int32 allocated = 5;
  optional int32 used = 6;
}

message CreateSubscriptionPayload {
  string school = 1;
  string plan = 2;
  int32 year = 3;
  int32 term = 4;
  int32 student = 5;
  optional string invoice = 6;
  float discount = 7;
}

message UpdateSubscriptionPayload {
  string school = 1;
  string plan = 2;
  int32 year = 3;
  int32 term = 4;
  int32 student = 5;
  optional string invoice = 6;
  optional float discount = 7;
  optional int32 status = 8;
}

message DeleteSubscriptionPayload {
  string school = 1;
  string plan = 2;
  int32 year = 3;
  int32 term = 4;
  int32 student = 5;
}

message CreateDiscountPayload {
  string school = 1;
  string plan = 2;
  int32 year = 3;
  int32 term = 4;
  int32 grade = 5;
  float amount = 6;
  int32 unit = 7;
}

message UpdateDiscountPayload {
  string school = 1;
  string plan = 2;
  int32 year = 3;
  int32 term = 4;
  int32 grade = 5;
  optional float amount = 6;
  optional int32 unit = 7;
}

message DeleteDiscountPayload {
  string school = 1;
  string plan = 2;
  int32 year = 3;
  int32 term = 4;
  int32 grade = 5;
}

// ─── InsertData (KEPT — used by WatchChanges/SyncDelta) ───
// Same as current sync.proto — 30 per-table insert messages
// This is the READ direction format (server → client via watch stream)

message InsertData {
  oneof row {
    UserInsert user = 1;
    SchoolInsert school = 2;
    OwnerInsert owner = 3;
    StudentInsert student = 4;
    GuardianInsert guardian = 5;
    DepartmentInsert department = 6;
    TeacherInsert teacher = 7;
    StaffInsert staff_member = 8;
    TermInsert term = 9;
    ClassTeacherInsert class_teacher = 10;
    EnrollmentInsert enrollment = 11;
    SubjectInsert subject = 12;
    AttendanceInsert attendance = 13;
    TimetableInsert timetable = 14;
    LessonInsert lesson = 15;
    ExamInsert exam = 16;
    PaperInsert paper = 17;
    GradeInsert grade = 18;
    FeeInsert fee = 19;
    InvoiceInsert invoice = 20;
    PaymentInsert payment = 21;
    AnnouncementInsert announcement = 22;
    MasteryInsert mastery = 23;
    AiUsageInsert ai_usage = 24;
    SettingsInsert settings = 25;
    RoleInsert role = 26;
    ScopeInsert scope = 27;
    PlanInsert plan = 28;
    SubscriptionInsert subscription = 29;
    DiscountInsert discount = 30;
  }
}

// All 30 *Insert messages stay EXACTLY as they are in the current sync.proto
// (UserInsert, SchoolInsert, OwnerInsert, etc.)
// They are used by SyncDelta and ActionRow for the read/watch direction.
```

**What changed vs current `sync.proto`:**
- `MutationBatch` / `Mutation` / `PushAck` / `MutationResult` → REMOVED
- `UpdateData` oneof → REMOVED (not needed for watch; action payloads handle updates)
- `ActionRequest` / `ActionResponse` / `ActionRow` → NEW (push direction)
- ~77 action payload messages → NEW
- `InsertData` + all 30 `*Insert` messages → KEPT (watch direction)
- `WatchRequest` / `SyncDelta` / `FileUrl` → KEPT (unchanged)

---

## 6. Permission Model (Three-Tier)

### User Levels

```
enum UserLevel { normal = 0, system = 1, super_ = 2 }
```

### Super (level = 2) — Unrestricted

- See everything, write anything, bypass all checks.
- Only level that can Purge or see deleted records.

### System (level = 1) — Global but Role-Gated

- NOT full access. Permissions from system-scoped roles (`scopes.school IS NULL`).
- Can also be school members — system + school roles merge.
- If has `Read` on a resource → sees ALL records globally for that resource.

### Normal (level = 0) — Membership-Based

- Only sees schools where they are a member.
- Own user row always visible. All plans always visible.
- Permissions from school-scoped roles via `scopes` table.

### Client Bug to Fix

`lib/models/system_permissions.dart` line 78 treats System = Super:
```dart
if (level == UserLevel.super_ || level == UserLevel.system) {
  return SystemPermissions._(level: level, permissions: const {});
}
```
Fix: Remove `UserLevel.system` from the shortcut.

---

## 7. Resource & Action Design (18 Resources × 9 Actions)

### Actions (u16 bitmask)

| Action | Bit | Value |
|--------|-----|-------|
| Create | 0 | 1 |
| Read | 1 | 2 |
| Update | 2 | 4 |
| Delete | 3 | 8 |
| Purge | 4 | 16 |
| Assign | 5 | 32 |
| Unassign | 6 | 64 |
| Mark | 7 | 128 |
| Approve | 8 | 256 |

### Resources (18 logical)

| # | Resource | Covers tables |
|---|----------|--------------|
| 1 | Users | `users` |
| 2 | Schools | `schools`, `settings` |
| 3 | Owners | `owners` |
| 4 | Teachers | `teachers` |
| 5 | Staff | `staff` |
| 6 | Students | `students`, `guardians`, `enrollments` |
| 7 | Departments | `departments` |
| 8 | Classes | `class_teachers`, `subjects`, `timetable` |
| 9 | Attendance | `attendance` |
| 10 | Lessons | `lessons` |
| 11 | Exams | `exams`, `papers` |
| 12 | Grades | `grades`, `mastery` |
| 13 | Fees | `fees`, `invoices` |
| 14 | Payments | `payments` |
| 15 | Announcements | `announcements` |
| 16 | Roles | `roles`, `scopes` |
| 17 | Plans | `plans`, `subscriptions`, `discounts` |
| 18 | AI | `aiusage` |

### Permission Check Per Action

The server maps each `SyncAction` to a `(Resource, Action)` pair for authorization:

| SyncAction | Required Permission |
|-----------|-------------------|
| `CreateSchool` | `Schools.Create` |
| `CreateTeacher` | `Teachers.Create` |
| `CreateStaff` | `Staff.Create` |
| `CreateOwner` | `Owners.Create` |
| `CreateStudent` | `Students.Create` |
| `CreateGuardian` | `Students.Create` |
| `EnrollStudent` | `Students.Assign` |
| `UnenrollStudent` | `Students.Unassign` |
| `AssignClassTeacher` | `Classes.Assign` |
| `AssignSubject` | `Classes.Assign` |
| `MarkAttendance` | `Attendance.Mark` |
| `MarkGrades` | `Grades.Mark` |
| `ApprovePayment` | `Payments.Approve` |
| `AssignRole` | `Roles.Assign` |
| `UnassignRole` | `Roles.Unassign` |
| `Update*` | `{Resource}.Update` |
| `Delete*` | `{Resource}.Delete` |
| `Create*` (others) | `{Resource}.Create` |

---

## 8. Sync Permission Filtering (Watch Stream — Server-Side)

| User Level | What data to send |
|-----------|------------------|
| Super | Everything — no filter |
| System | For each resource with system-level `Read`: ALL records globally. Plus school-scoped data for member schools. |
| Normal | Data for member schools only. Plus own user row. Plus all plans. |

**This is already implemented** in `services/sync.rs` via `SyncFilter` enum (Super/System/Normal variants).

---

## 9. Error Codes

| Code | Meaning | Client Action |
|------|---------|--------------|
| 0 | Success | Delete log entry, apply returned rows |
| 1 | Permission denied | Mark failed, show in notifications |
| 2 | Conflict | Apply server's version of affected rows, delete log |
| 3 | Validation error | Mark failed, user must fix |
| 4 | Not found | Mark failed |

---

## 10. Existing Server Code — What to Keep vs Rewrite

### KEEP (unchanged or minimal changes)

| File | Lines | Reason |
|------|-------|--------|
| `src/db/changelog.rs` | ~350 | Binary changelog + deletes sidecar — works fine |
| `src/db/database/authorize.rs` | ~150 | Full 3-tier auth — works perfectly |
| `src/db/database/traits.rs` | ~170 | All DB traits — works perfectly |
| `src/db/database/tables/insert.rs` | ~564 | All 30 insert functions — reused by action handlers |
| `src/db/database/tables/update.rs` | ~849 | All 30 update functions — reused by action handlers |
| `src/db/database/tables/delete.rs` | ~461 | All 30 delete functions — reused by action handlers |
| `src/db/database/tables/snapshot.rs` | ~546 | snapshot_table + snapshot_table_since — used by watch |
| `src/db/database/tables/rows.rs` | ~1513 | All 30 XxxRow structs + From impls — used by snapshot/watch |
| `src/db/database/tables/memberships.rs` | ~122 | User→schools, schools→co-members queries |
| `src/proto/services/sync.rs` | ~100 | Sync trait + tonic adapter — needs minor update for new RPC |
| `src/types/role/*` | ~all | Resource, Action, Actions, Permissions, Organisation, Role — fully ported |
| `src/types/error.rs` | ~all | Error enum + Status mapping — may need new variants |

### REWRITE

| File | Lines | What changes |
|------|-------|-------------|
| `src/services/sync.rs` | ~3400 | Replace `process_batch`/`process_mutation` with `process_action`. Replace batch-based push with sequential action processing. Watch loop stays mostly the same. |
| `protos/services/sync.proto` | ~all | New action-based messages (see §5j). Keep InsertData + all *Insert messages. |
| `src/db/database/tables/apply.rs` | ~222 | Replace `apply_mutation` dispatcher with `execute_action` dispatcher that handles semantic actions |

### DELETE

| What | Reason |
|------|--------|
| `src/db/database/tables/apply.rs` — `validate_insert`/`validate_update` | No longer needed (actions are typed) |
| Old `MutationBatch`/`Mutation`/`PushAck` handling in sync.rs | Replaced by action handling |
| Old invitation flow detection logic in sync.rs | Replaced by explicit action payloads |

---

## 11. Existing Client Code — What to Keep vs Rewrite

### KEEP

| File/Layer | Reason |
|-----------|--------|
| All 32 Drift table definitions (`lib/database/tables/`) | Unchanged |
| All 21 DAOs (`lib/database/daos/`) | Log-writing code within DAOs changes, query/watch methods stay |
| All 16 models (`lib/models/`) | `AppNotification` needs minor update for action display |
| All services (`lib/services/`) | Unchanged |
| All UI (`lib/ui/`) | Minor updates to notifications display |
| `lib/sync/delta_writer.dart` | May need minor updates for new delta format (but SyncDelta is unchanged) |
| `lib/sync/sync_status.dart` | Unchanged |
| `lib/cache/`, `lib/core/constants.dart`, `lib/core/extensions.dart` | Unchanged |
| `lib/client.dart` | Unchanged (sync engine interface stays the same) |

### REWRITE

| File | What changes |
|------|-------------|
| `lib/sync/sync_engine.dart` (~800 lines) | Replace batch-based push with sequential action sender. Watch logic stays. |
| `lib/sync/log_processor.dart` (~2100 lines) | **DELETE ENTIRELY** — no more coalescing, pairing, FK sorting |
| `lib/database/tables/logs.dart` | New schema (action/resource/payload instead of tbl/op/rowKey/columns) |
| `lib/database/tables/enums.dart` | Add `SyncAction` enum + converter. Remove `LogTable`, `LogOperation`, `LogStatus`, and all column bitset enums |
| `lib/database/daos/logs_dao.dart` (~200 lines) | Updated for new schema |
| `lib/models/app_notification.dart` | Updated for action-based display |
| `lib/core/seeder.dart` (~2200 lines) | Update `_log()` to write action-based log entries. Change batch inserts to sequential. |
| All DAOs that write log entries | Change from `LogsCompanion(tbl, op, rowKey, columns)` to `LogsCompanion(action, resource, payload)` |
| `lib/proto/` (generated) | Regenerate from new `sync.proto` |

### Client DAOs That Write Log Entries

These DAOs currently create `LogsCompanion` entries and must be updated:

| DAO File | Operations that log |
|----------|-------------------|
| `accounts_dao.dart` | updateName, updateEmail, updateStatus (logs as Users.Update) |
| `announcements_dao.dart` | create, update, delete |
| `attendance_dao.dart` | mark (upsert), delete |
| `departments_dao.dart` | create, update, delete, assignTeacherDept, assignStaffDept |
| `enrollments_dao.dart` | enroll, unenroll |
| `exams_grades_dao.dart` | createExam, updateExam, deleteExam, createPaper, updatePaper, deletePaper, markGrades, updateGrade, deleteGrade |
| `finance_dao.dart` | createFee, updateFee, deleteFee, createInvoice, updateInvoice, deleteInvoice, createPayment, updatePayment, deletePayment |
| `members_dao.dart` | createTeacher, createStaff, createOwner, createGuardian, updateTeacher, updateStaff, deleteTeacher, deleteStaff, deleteOwner, deleteGuardian |
| `plans_dao.dart` | createPlan, updatePlan, deletePlan |
| `roles_dao.dart` | createRole, updateRole, deleteRole, assignRole, unassignRole |
| `schools_dao.dart` | createSchool, updateSchool |
| `settings_dao.dart` | updateSettings |
| `subjects_dao.dart` | assignSubject, unassignSubject, assignClassTeacher, unassignClassTeacher |
| `terms_dao.dart` | createTerm, updateTerm, deleteTerm |
| `timetable_dao.dart` | createEntry, updateEntry, deleteEntry |

---

## 12. Key Server Types (Already Implemented in `../ledger/`)

### `types/role/resource.rs` — 18 Resources

```rust
pub enum Resource {
    Users = 1, Schools = 2, Owners = 3, Teachers = 4, Staff = 5,
    Students = 6, Departments = 7, Classes = 8, Attendance = 9,
    Lessons = 10, Exams = 11, Grades = 12, Fees = 13, Payments = 14,
    Announcements = 15, Roles = 16, Plans = 17, AI = 18,
}
```

### `types/role/action.rs` — 9 Actions (bitmask values)

```rust
pub enum Action {
    Create = 1, Read = 2, Update = 4, Delete = 8, Purge = 16,
    Assign = 32, Unassign = 64, Mark = 128, Approve = 256,
}
```

### `types/role/permissions.rs` — Binary blob, 3 bytes per resource

```rust
pub struct Permissions([Actions; Resource::COUNT]);  // 18 entries
// Binary: [resource_id: u8, actions_lo: u8, actions_hi: u8] per non-empty resource
// Supports: Index, IndexMut, Add, AddAssign, Sub, SubAssign, Diesel ToSql/FromSql
```

### `types/role/organisation.rs` — Scope context

```rust
pub enum Organisation { System, Account, School(Id) }
```

### `types/error.rs` — Unified error type

```rust
pub enum Error {
    InvalidId, InvalidPhone, Unauthorized, InvalidToken, UserNotFound,
    SchoolNotFound, Forbidden, Conflict, ForeignKey, DatabaseLocked,
    NothingToUpdate, Internal, // ... and more
}
```
All errors map to `tonic::Status` via `From<Error> for Status`.

### `db/changelog.rs` — Binary append-only change log

- Fixed 24-byte records: `[user_id: 12B, table: 1B, op: 1B, columns: 2B, created: 8B]`
- Deletes sidecar: variable-length records `[table: 1B, key_len: 1B, key: N bytes, created: 8B]`
- Cursor-based reads via byte offset
- `thread_local! { pub static LOG }` for global access

### `db/database/authorize.rs` — 3-tier authorization

```rust
impl Authorize for Conn {
    fn authorize(&mut self, token: Token, org: Organisation, perms: Permissions) -> Result<()> {
        // 1. Load user, check active status
        // 2. Super → bypass all
        // 3. System context → check system-scoped roles
        // 4. School context → check owner bypass, load school+system roles, check perms
    }
}
```

---

## 13. Schema Overview (30 Tables)

All defined in `schema.sql` and `../ledger/migrations/.../up.sql`.

**Identity:** users, schools, owners
**Members:** students, guardians, teachers, staff, departments
**Academic:** terms, enrollments, subjects, class_teachers
**Schedule:** timetable, lessons
**Assessment:** exams, papers, grades, mastery
**Finance:** fees, invoices, payments, subscriptions, discounts
**Communication:** announcements
**AI:** aiusage
**Config:** settings, roles, scopes, plans
**Client-only:** accounts, logs

Type conventions: DateTime = bigint (seconds since epoch), Date = integer (days since epoch),
Enums = smallint, Boolean = integer (0/1), IDs = text (BSON ObjectId, 24-char hex).

---

## 14. Task Plan — High-Level Phases

### Phase 0: Commit current state (FIRST TASK in both repos)

Meaningful, chunked commits of both repos. Not a single dump — structured commits
by layer (database, sync, services, proto, etc.) so we can roll back if needed.

### Phase 1: Proto redesign (Server)

1. Write new `sync.proto` with action-based messages (per §5j)
2. Compile and verify generated Rust code
3. Regenerate Dart stubs on client side

### Phase 2: Server sync rewrite

1. Create action dispatcher (`execute_action` function mapping SyncAction → handler)
2. Create action handlers that reuse existing `insert_*`, `update_*`, `delete_*` functions
3. Implement invitation flow handlers (CreateTeacher, CreateStaff, CreateOwner, CreateGuardian)
4. Implement bulk handlers (MarkAttendance, MarkGrades)
5. Rewrite push_changes to process ActionRequest one-at-a-time
6. Keep watch_changes mostly unchanged (it already works with changelog + snapshots)
7. Update proto adapter (`proto/services/sync.rs`) for new RPC signature

### Phase 3: Client sync rewrite

1. Update `logs` table schema (Drift) + enums
2. Update `logs_dao.dart` for new schema
3. Rewrite `sync_engine.dart` push flow (sequential action sender)
4. Delete `log_processor.dart` entirely
5. Update `delta_writer.dart` if needed (probably minimal — SyncDelta format unchanged)
6. Update `app_notification.dart` for action-based display

### Phase 4: Client DAO updates

Update all DAOs that write log entries to use the new action-based format.
Each DAO method that currently writes a `LogsCompanion(tbl, op, rowKey, columns)` must:
1. Build the action payload proto message
2. Serialize it to bytes
3. Write `LogsCompanion(action, resource, payload)` instead

### Phase 5: Seeder update

Update `lib/core/seeder.dart` to:
1. Create data sequentially (not in batches)
2. Use new action-based log format
3. Simulate realistic human actions

### Phase 6: Fix SystemPermissions bug

Remove `UserLevel.system` from the super bypass in `system_permissions.dart`.

---

## 15. Key Design Decisions (All Resolved)

| Decision | Resolution |
|----------|-----------|
| Sync model | Action-based (not mutation-based) |
| Action granularity | Resource-level semantic actions (Option A — ~77 actions) |
| Local-first strategy | Optimistic — write locally first, sync later |
| Transport | One-at-a-time streaming, wait for ack before next |
| Batching | None — each action is one stream message |
| Invitation flow | Server handles entirely. Client sends single action with phone+name. |
| Server change tracking | Keep binary changelog as-is. Action handlers append to it. |
| Watch stream | Unchanged. Reads changelog + queries DB for current state. |
| Proto approach | Clean redesign of push direction. Keep InsertData for watch direction. |
| FK ordering | Gone from client. Server executes atomically. Sequential streaming ensures parents exist. |
| Seeder | Sequential (simulate human), not batch |
| Timeline | 1 day for sync, 7 days total to product-ready |

---

## 16. Reference Files

| File | Contains |
|------|----------|
| `eduxal/AGENT.md` | Client master architecture doc (~735 lines) — needs updating after redesign |
| `eduxal/schema.sql` | All 30 backend tables + triggers + indexes |
| `../ledger/AGENT.md` | Server architecture doc |
| `../ledger/protos/services/sync.proto` | Current mutation-based proto (TO BE REPLACED) |
| `../ledger/src/services/sync.rs` | Current sync service (~3400 lines, TO BE REWRITTEN) |
| `../ledger/src/db/changelog.rs` | Binary changelog (KEEP) |
| `../ledger/src/db/database/authorize.rs` | 3-tier authorization (KEEP) |
| `../ledger/src/db/database/tables/insert.rs` | All 30 insert functions (KEEP — reused by actions) |
| `../ledger/src/db/database/tables/update.rs` | All 30 update functions (KEEP — reused by actions) |
| `../ledger/src/db/database/tables/delete.rs` | All 30 delete functions (KEEP — reused by actions) |
| `../ledger/src/db/database/tables/snapshot.rs` | Snapshot queries for watch (KEEP) |
| `../ledger/src/db/database/tables/rows.rs` | 30 XxxRow structs (KEEP) |
| `../ledger/src/types/role/` | Resource, Action, Permissions, etc. (KEEP) |
| `../ledger/src/types/error.rs` | Error enum (KEEP, may extend) |
| `eduxal/lib/sync/sync_engine.dart` | Current client sync engine (REWRITE push, KEEP watch) |
| `eduxal/lib/sync/log_processor.dart` | Current log processor (DELETE) |
| `eduxal/lib/sync/delta_writer.dart` | Current delta writer (KEEP/minor update) |
| `eduxal/lib/database/tables/logs.dart` | Current logs table (REWRITE) |
| `eduxal/lib/database/tables/enums.dart` | Current enums (UPDATE — add SyncAction, remove old log enums) |
| `eduxal/lib/database/daos/logs_dao.dart` | Current logs DAO (REWRITE) |
| `eduxal/lib/models/app_notification.dart` | Notification model (UPDATE) |
| `eduxal/lib/core/seeder.dart` | Demo data seeder (UPDATE) |

---

## 17. How to Continue

Feed this file to a new session with:

> "Read CONVERSATION_CONTEXT.md. I'm the project owner of EduXal. Create detailed,
> self-sufficient task lists in BOTH repos: `eduxal/TASKS.md` for the client and
> `../ledger/TASKS.md` for the server. Follow the task format from `eduxal/AGENT.md` §0c.
> The first task in BOTH repos must be meaningful chunked commits of the current state.
> Server tasks come first (proto → sync service), then client tasks (proto regen → sync
> engine → DAOs → seeder). Use terminal commands to read server files since they're
> outside the project root."

**Important paths:**
- Client project root: `/home/abdihakim/Documents/GITHUB/eduxal-labs/eduxal/`
- Active server: `/home/abdihakim/Documents/GITHUB/eduxal-labs/ledger/`
- Reference server: `/home/abdihakim/Documents/GITHUB/eduxal-labs/server/` (DO NOT modify)
- Proto generation: `eduxal/generate.sh` runs `protoc` from `../ledger/protos/` → `lib/proto/`
