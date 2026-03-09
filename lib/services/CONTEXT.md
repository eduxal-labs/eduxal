# services/ — Business Logic Layer Context

> One file per domain. Services orchestrate DAO reads/writes + gRPC calls and expose `Stream<T>` / `Future<Result<T, E>>` to the UI layer.
> Services are the **only** place where business logic lives. UI code never calls DAOs or gRPC directly.

## Overview

This directory contains **2 service files**. Services sit between the UI and the data layer (DAOs + gRPC). They:
- Combine multiple DAO calls into transactional operations.
- Map between proto types and domain models.
- Write to the `logs` table alongside every synced-table mutation.
- Trigger `sync.pushNow()` (fire-and-forget) after every mutation that writes to the `logs` table, so changes reach the server as fast as possible. This is handled at the DAO level — every DAO method that writes a log entry calls `sync.pushNow()` after the transaction completes. Services and UI code benefit automatically.
- Return `Result<T, GrpcError>` for fallible operations and `Stream<T>` for reactive queries.

## Files

| File | Class | Domain | Status |
|---|---|---|---|
| `authentication.dart` | `Authentication` | Login, verify, setup, refresh, change phone | ✅ Complete |
| `members.dart` | `MemberCreationService` | Phone-first member creation (owners, teachers, staff, students, guardians) + profile image saving | ✅ Complete |
| `member_management.dart` | `MemberManagementService` | Post-creation lifecycle: edit fields, change status, remove members (all types) | ✅ Complete |

## Key Methods by Service

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
- `MemberActionError` — enum: `noActiveAccount`, `notFound`, `databaseError`, `cannotRemoveSelf`.

| Method | Signature | Description |
|---|---|---|
| `updateTeacher` | `Future<Result<void, MemberActionError>> updateTeacher({required String schoolId, required String userId, String? role, String? department, DateTime? hiredDate})` | Updates mutable fields on a teacher row. Only non-null params are written. |
| `changeTeacherStatus` | `Future<Result<void, MemberActionError>> changeTeacherStatus({required String schoolId, required String userId, required TeacherStatus status})` | Changes a teacher's status (e.g. active → resigned). |
| `removeTeacher` | `Future<Result<void, MemberActionError>> removeTeacher({required String schoolId, required String userId})` | Removes a teacher from a school. |
| `updateStaff` | `Future<Result<void, MemberActionError>> updateStaff({required String schoolId, required String userId, String? role, String? department, String? idNumber})` | Updates mutable fields on a staff row. |
| `changeStaffStatus` | `Future<Result<void, MemberActionError>> changeStaffStatus({required String schoolId, required String userId, required StaffStatus status})` | Changes a staff member's status. |
| `removeStaff` | `Future<Result<void, MemberActionError>> removeStaff({required String schoolId, required String userId})` | Removes a staff member from a school. |
| `removeOwner` | `Future<Result<void, MemberActionError>> removeOwner({required String schoolId, required String userId})` | Removes an owner. Returns `cannotRemoveSelf` if caller tries to remove themselves. |
| `updateStudent` | `Future<Result<void, MemberActionError>> updateStudent({required String schoolId, required int adm, String? name, DateTime? dob, Gender? gender})` | Updates mutable fields on a student row. |
| `changeStudentStatus` | `Future<Result<void, MemberActionError>> changeStudentStatus({required String schoolId, required int adm, required StudentStatus status})` | Changes a student's status (e.g. active → expelled). |
| `updateGuardian` | `Future<Result<void, MemberActionError>> updateGuardian({required String schoolId, required String userId, required int studentAdm, GuardianRelationship? relationship, GuardianRole? role})` | Updates mutable fields on a guardian row. |
| `removeGuardian` | `Future<Result<void, MemberActionError>> removeGuardian({required String schoolId, required String userId, required int studentAdm})` | Removes a guardian link from a student. |

**Internal helpers:**
- `_dateToDaysSinceEpoch(DateTime date) → int` — static helper converting DateTime to days since epoch for date columns.

**Dependencies:** `database/daos/members_dao.dart`, `database/database.dart` (for generated companion types), `database/tables/enums.dart`, `models/result.dart`, `client.dart` (for global `cache`).

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
| `createStudent` | `Future<Result<void, MemberCreationError>> createStudent({required String schoolId, required int adm, required String name, ...})` | Name-first (not phone-first). Creates student row directly. Additional fields: `dob`, `gender`, `documents`. |
| `createGuardian` | `Future<Result<void, MemberCreationError>> createGuardian({required String schoolId, required int studentAdm, required String phone, ...})` | Phone-first, linked to a specific student. Additional fields: `relationship`, `role`. |
| `saveUserProfileImage` | `Future<Result<void, MemberCreationError>> saveUserProfileImage({required String userId, required List<int> bytes})` | Saves image bytes to `FileCache.profilePath(userId)`. |
| `saveStudentImage` | `Future<Result<void, MemberCreationError>> saveStudentImage({required String schoolId, required int adm, required List<int> bytes})` | Saves image bytes to `FileCache.studentImagePath(schoolId, adm)`. |

**Internal helpers:**
- `_dateToDaysSinceEpoch(DateTime date) → int` — Converts a `DateTime` to days since Unix epoch for date columns.

**Dependencies:** `database/daos/members_dao.dart`, `database/daos/logs_dao.dart`, `database/daos/users_dao.dart`, `database/database.dart`, `database/tables/enums.dart`, `models/result.dart`, `cache/file_cache.dart`, `core/extensions.dart` (for `toKenyanPhone()`), `client.dart` (for global DAOs).

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
Task 07 — Wire `pushNow()` into services and DAOs that write logs. All DAO mutation methods that write to the `logs` table now call `sync.pushNow()` (fire-and-forget) after the transaction completes. The `members.dart` service's `saveUserProfileImage`, `saveStudentImage`, and `_purgeDeletedUser` methods (which write directly to `db.logs`) also trigger `sync.pushNow()`. No changes needed in `member_management.dart` since it delegates all mutations to `MembersDao` methods which now handle the push internally. UI code that calls DAOs directly also benefits automatically from the DAO-level push.