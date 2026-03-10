# EduXal — Task Board

> Tasks are ordered by dependency and priority. Execute top-to-bottom.
> Server tasks are in `LEDGER_TASKS.md` — complete those first before starting client tasks.

---

### Task C0: Commit current client state

**Files to create/modify:** None (git operations only)
**Context files to read (if needed):** None
**Depends on:** Nothing

**Specification:**

Create meaningful, chunked git commits of the current dirty working tree in the `eduxal` repo.
Run `git status` first to see all 157+ uncommitted changes. Group the commits logically:

1. `chore: update android build config and assets` — `android/`
2. `chore: update iOS config and assets` — `ios/`
3. `chore: update project config` — `pubspec.yaml`, `pubspec.lock`, root-level config files
4. `feat: database layer (tables, DAOs, enums, converters)` — `lib/database/`
5. `feat: domain models` — `lib/models/`
6. `feat: services layer` — `lib/services/`
7. `feat: sync engine (pre-redesign snapshot)` — `lib/sync/`
8. `feat: proto stubs` — `lib/proto/`
9. `feat: core utilities and cache` — `lib/core/`, `lib/cache/`
10. `feat: UI layer (screens, widgets, theme)` — `lib/ui/`
11. `feat: client entry point` — `lib/client.dart`, `lib/main.dart`
12. `docs: update AGENT.md and TASKS.md` — `AGENT.md`, `TASKS.md`, `CONVERSATION_CONTEXT.md`

Use `git add <paths>` + `git commit -m "<message>"` for each group. Skip any group that has no changes. Do NOT use `git add .`.

**Update after completion:**
- [x] Update any relevant `CONTEXT.md` files if they exist
- [x] Mark this task `[x]`

---

### Task C1: Regenerate Dart proto stubs from new `sync.proto`

**Files to create/modify:**
- `lib/proto/services/sync.pb.dart` (regenerated)
- `lib/proto/services/sync.pbgrpc.dart` (regenerated)
- `lib/proto/services/sync.pbenum.dart` (regenerated)
- `lib/proto/services/sync.pbjson.dart` (regenerated)

**Context files to read (if needed):** `generate.sh`
**Depends on:** Server Task L1 (new `sync.proto` must exist at `../ledger/protos/services/sync.proto`)

**Specification:**

Run the proto generation script:
```bash
cd /home/abdihakim/Documents/GITHUB/eduxal-labs/eduxal
bash generate.sh
```

This runs `protoc` against `../ledger/protos/services/sync.proto` and outputs Dart files to `lib/proto/services/`.

After generation, verify the new files contain:
- `ActionRequest` class (not `MutationBatch`)
- `ActionResponse` class (not `PushAck`)
- `ActionRow` class
- `SyncClient` with `pushActions` method (not `pushChanges`)
- `WatchRequest`, `SyncDelta`, `FileUrl` — unchanged
- All 77 `*Payload` message classes (`CreateSchoolPayload`, etc.)
- `AttendanceRecord`, `GradeRecord` helper messages
- `InsertData` oneof with all 30 `*Insert` messages — unchanged

Run `dart analyze lib/proto/services/sync.pb.dart 2>&1 | head -20` to verify the generated code is valid.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task C2: Update `logs` table and enums for action-based model

**Files to create/modify:**
- `lib/database/tables/logs.dart`
- `lib/database/tables/enums.dart`

**Context files to read (if needed):** `lib/database/CONTEXT.md` (if exists)
**Depends on:** Task C1

**Specification:**

**`lib/database/tables/enums.dart` changes:**

1. **Add** the `SyncAction` enum (77 values) and its `TypeConverter`. Place it after the existing `LogStatus` enum. Values from CONVERSATION_CONTEXT §5g:

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

class SyncActionConverter extends TypeConverter<SyncAction, int> {
  const SyncActionConverter();
  @override
  SyncAction fromSql(int fromDb) =>
      SyncAction.values.firstWhere((e) => e.value == fromDb);
  @override
  int toSql(SyncAction value) => value.value;
}
```

2. **Remove** these enums and their converters (no longer needed):
   - `LogTable` enum + `LogTableConverter` (lines ~332–374)
   - `LogOperation` enum + `LogOperationConverter` (lines ~378–389)
   - All `*Column` bitset enums (lines ~420–end): `UsersColumn`, `SchoolsColumn`, `StudentsColumn`, `GuardiansColumn`, `DepartmentsColumn`, `TeachersColumn`, `StaffColumn`, `TermsColumn`, `ClassTeachersColumn`, `SubjectsColumn`, `AttendanceColumn`, `TimetableColumn`, `LessonsColumn`, `ExamsColumn`, `PapersColumn`, `GradesColumn`, `FeesColumn`, `InvoicesColumn`, `PaymentsColumn`, `AnnouncementsColumn`, `MasteryColumn`, `AiusageColumn`, `SettingsColumn`, `RolesColumn`, `PlansColumn`, `SubscriptionsColumn`, `DiscountsColumn`

3. **Keep** these enums:
   - `LogStatus` enum + `LogStatusConverter` — still needed (pending/failed)
   - All non-log domain enums (`AppThemeMode`, `UserLevel`, `UserStatus`, `SchoolStatus`, `StudentStatus`, `Gender`, `GuardianRelationship`, `GuardianRole`, `TeacherStatus`, `StaffStatus`, `AttendanceStatus`, `ExamType`, `PaperStatus`, `PaymentMethod`, `PaymentStatus`, `Audience`, `PlanStatus`, `InvoiceStatus`, `DiscountUnit`, `SubscriptionStatus`, `Resource`, `Action`)

**`lib/database/tables/logs.dart` changes:**

Replace the entire table definition with the new schema:

```dart
import 'package:drift/drift.dart';
import 'enums.dart';
import 'accounts.dart';

/// Client-only offline action queue — not synced to the server directly.
///
/// Every local action (create, update, delete, assign, etc.) produces one row here.
/// The sync engine sends these one-at-a-time to the server via gRPC stream.
/// Successfully synced rows are DELETED (never marked as synced).
@DataClassName('LogsData')
class Logs extends Table {
  @override
  String get tableName => 'logs';

  /// Auto-incrementing surrogate PK — ensures replay order is preserved.
  IntColumn get id => integer().autoIncrement()();

  /// The account that performed this action.
  TextColumn get account =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();

  /// The semantic action type (e.g. createSchool, updateTeacher, markAttendance).
  IntColumn get action => integer().map(const SyncActionConverter())();

  /// Human-readable display key for the notification UI.
  /// E.g. school name, user phone, "Attendance 2025-01-15", etc.
  TextColumn get resource => text()();

  /// Serialized protobuf action payload (e.g. CreateSchoolPayload bytes).
  /// Self-contained — the sync engine does NOT read other tables to build the message.
  BlobColumn get payload => blob()();

  /// Whether this entry is awaiting replay or has permanently failed.
  IntColumn get status => integer()
      .map(const LogStatusConverter())
      .withDefault(const Constant(0))();

  /// Number of times the sync engine has attempted to send this action.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Human-readable error message from server, if any.
  TextColumn get error => text().nullable()();

  /// Milliseconds since epoch when this log entry was created.
  Int64Column get created => int64()();
}
```

After modifying both files, run `dart analyze lib/database/tables/logs.dart lib/database/tables/enums.dart 2>&1 | head -20` to check for immediate issues. Expect errors from files that import the removed enums — those will be fixed in subsequent tasks.

**IMPORTANT:** The `AppDatabase` class in `lib/database/database.dart` has a `schemaVersion` that must be incremented and a migration added for the `logs` table schema change. But Drift generates the schema from the table class, so the code generation step (`dart run build_runner build`) will handle the DDL. The migration strategy in `database.dart` should drop and recreate `logs` on upgrade (data loss in logs is acceptable — they are transient).

**Update after completion:**
- [x] Update `lib/database/CONTEXT.md` if it exists — note logs table schema change, SyncAction enum addition, removed enums
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C3: Update `logs_dao.dart` for new schema

**Files to create/modify:** `lib/database/daos/logs_dao.dart`
**Context files to read (if needed):** None — current file inlined in task
**Depends on:** Task C2

**Specification:**

Rewrite `logs_dao.dart` to work with the new `logs` table schema. The DAO becomes simpler because there is no coalescing, no column bitmask collapsing, no supersede-with-delete logic.

**New `logs_dao.dart`:**

```dart
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../../models/app_notification.dart';

part 'logs_dao.g.dart';

@DriftAccessor(tables: [Logs])
class LogsDao extends DatabaseAccessor<AppDatabase> with _$LogsDaoMixin {
  LogsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────
  // Writes — enqueueing actions
  // ─────────────────────────────────────────────────────────────────────

  /// Appends a new action log entry to the queue.
  ///
  /// The caller provides:
  /// - [LogsCompanion.action] — SyncAction enum value
  /// - [LogsCompanion.resource] — human-readable display key
  /// - [LogsCompanion.payload] — serialized proto payload bytes
  /// - [LogsCompanion.created] — milliseconds since epoch
  Future<void> insertLog(LogsCompanion log) {
    return into(logs).insert(log);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Reads — sync engine consumption
  // ─────────────────────────────────────────────────────────────────────

  /// Returns all pending entries for [accountId], oldest first.
  Future<List<LogsData>> getPendingLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.pending),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// Returns all failed entries for [accountId].
  Future<List<LogsData>> getFailedLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.failed),
          ))
        .get();
  }

  /// Emits all failed log entries as [AppNotification] objects,
  /// ordered by created descending, whenever the logs table changes.
  Stream<List<AppNotification>> watchFailedLogs(String accountId) {
    return (select(logs)
          ..where(
            (t) =>
                t.account.equals(accountId) &
                t.status.equalsValue(LogStatus.failed),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.created)]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => AppNotification(
                  logId: row.id,
                  action: row.action,
                  resource: row.resource,
                  errorMessage: row.error,
                  attempts: row.attempts,
                  occurred: DateTime.fromMillisecondsSinceEpoch(
                    row.created.toInt(),
                  ),
                ),
              )
              .toList(),
        );
  }

  /// Reactive count of failed entries for [accountId].
  Stream<int> watchFailedLogCount(String accountId) {
    final countExpr = logs.id.count();
    final query = selectOnly(logs)
      ..addColumns([countExpr])
      ..where(
        logs.account.equals(accountId) &
            logs.status.equalsValue(LogStatus.failed),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Deletes — after successful sync
  // ─────────────────────────────────────────────────────────────────────

  /// Deletes a single log entry by [id] after successful sync.
  Future<void> deleteLog(int id) {
    return (delete(logs)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes multiple log entries by their [ids].
  Future<void> deleteLogs(List<int> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(logs)..where((t) => t.id.isIn(ids))).go();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Error tracking
  // ─────────────────────────────────────────────────────────────────────

  /// Marks a log entry as failed and records the error message.
  Future<void> markFailed(int id, String error) {
    return customStatement(
      'UPDATE logs SET status = ?, error = ?, attempts = attempts + 1 WHERE id = ?',
      [LogStatus.failed.index, error, id],
    );
  }
}
```

**Removed methods (no longer needed):**
- `collapseUpdateLogs` — no more column bitmask coalescing
- `supersedWithDelete` — no more delete-supersedes-insert logic

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C4: Update `app_notification.dart` for action-based display

**Files to create/modify:** `lib/models/app_notification.dart`
**Context files to read (if needed):** None
**Depends on:** Task C2

**Specification:**

Replace the current `AppNotification` model to use `SyncAction` + `resource` instead of `LogTable` + `LogOperation` + `rowKey`.

```dart
import '../database/tables/enums.dart';

/// A thin display model wrapping a failed log row from the offline action queue.
class AppNotification {
  const AppNotification({
    required this.logId,
    required this.action,
    required this.resource,
    required this.errorMessage,
    required this.attempts,
    required this.occurred,
  });

  /// The auto-incremented primary key of the logs row.
  final int logId;

  /// Which action failed.
  final SyncAction action;

  /// Human-readable resource identifier (school name, user phone, etc.).
  final String resource;

  /// The error message returned by the server on the last attempt.
  final String? errorMessage;

  /// How many times the sync engine has attempted this action.
  final int attempts;

  /// When this log entry was originally created.
  final DateTime occurred;

  /// Human-readable title for the notification row.
  /// Example: "Sync failed — Create Teacher"
  String get title => 'Sync failed \u2014 ${_actionName(action)}';

  /// Human-readable subtitle.
  String get subtitle => (errorMessage != null && errorMessage!.isNotEmpty)
      ? errorMessage!
      : 'Attempt $attempts';

  static String _actionName(SyncAction action) => switch (action) {
    SyncAction.createSchool => 'Create School',
    SyncAction.updateSchool => 'Update School',
    SyncAction.deleteSchool => 'Delete School',
    SyncAction.createTeacher => 'Create Teacher',
    SyncAction.updateTeacher => 'Update Teacher',
    SyncAction.deleteTeacher => 'Delete Teacher',
    SyncAction.createStaff => 'Create Staff',
    SyncAction.updateStaff => 'Update Staff',
    SyncAction.deleteStaff => 'Delete Staff',
    SyncAction.createOwner => 'Create Owner',
    SyncAction.deleteOwner => 'Delete Owner',
    SyncAction.createStudent => 'Create Student',
    SyncAction.updateStudent => 'Update Student',
    SyncAction.deleteStudent => 'Delete Student',
    SyncAction.enrollStudent => 'Enroll Student',
    SyncAction.unenrollStudent => 'Unenroll Student',
    SyncAction.createGuardian => 'Create Guardian',
    SyncAction.updateGuardian => 'Update Guardian',
    SyncAction.deleteGuardian => 'Delete Guardian',
    SyncAction.createDepartment => 'Create Department',
    SyncAction.updateDepartment => 'Update Department',
    SyncAction.deleteDepartment => 'Delete Department',
    SyncAction.createTerm => 'Create Term',
    SyncAction.updateTerm => 'Update Term',
    SyncAction.deleteTerm => 'Delete Term',
    SyncAction.assignClassTeacher => 'Assign Class Teacher',
    SyncAction.unassignClassTeacher => 'Unassign Class Teacher',
    SyncAction.assignSubject => 'Assign Subject',
    SyncAction.unassignSubject => 'Unassign Subject',
    SyncAction.createTimetableEntry => 'Create Timetable Entry',
    SyncAction.updateTimetableEntry => 'Update Timetable Entry',
    SyncAction.deleteTimetableEntry => 'Delete Timetable Entry',
    SyncAction.markAttendance => 'Mark Attendance',
    SyncAction.deleteAttendance => 'Delete Attendance',
    SyncAction.createLesson => 'Create Lesson',
    SyncAction.deleteLesson => 'Delete Lesson',
    SyncAction.createExam => 'Create Exam',
    SyncAction.updateExam => 'Update Exam',
    SyncAction.deleteExam => 'Delete Exam',
    SyncAction.createPaper => 'Create Paper',
    SyncAction.updatePaper => 'Update Paper',
    SyncAction.deletePaper => 'Delete Paper',
    SyncAction.markGrades => 'Mark Grades',
    SyncAction.updateGrade => 'Update Grade',
    SyncAction.deleteGrade => 'Delete Grade',
    SyncAction.updateMastery => 'Update Mastery',
    SyncAction.createFee => 'Create Fee',
    SyncAction.updateFee => 'Update Fee',
    SyncAction.deleteFee => 'Delete Fee',
    SyncAction.createInvoice => 'Create Invoice',
    SyncAction.updateInvoice => 'Update Invoice',
    SyncAction.deleteInvoice => 'Delete Invoice',
    SyncAction.createPayment => 'Create Payment',
    SyncAction.updatePayment => 'Update Payment',
    SyncAction.deletePayment => 'Delete Payment',
    SyncAction.approvePayment => 'Approve Payment',
    SyncAction.createAnnouncement => 'Create Announcement',
    SyncAction.updateAnnouncement => 'Update Announcement',
    SyncAction.deleteAnnouncement => 'Delete Announcement',
    SyncAction.createRole => 'Create Role',
    SyncAction.updateRole => 'Update Role',
    SyncAction.deleteRole => 'Delete Role',
    SyncAction.assignRole => 'Assign Role',
    SyncAction.unassignRole => 'Unassign Role',
    SyncAction.updateUser => 'Update User',
    SyncAction.deleteUser => 'Delete User',
    SyncAction.updateSettings => 'Update Settings',
    SyncAction.createPlan => 'Create Plan',
    SyncAction.updatePlan => 'Update Plan',
    SyncAction.deletePlan => 'Delete Plan',
    SyncAction.updateAiUsage => 'Update AI Usage',
    SyncAction.createSubscription => 'Create Subscription',
    SyncAction.updateSubscription => 'Update Subscription',
    SyncAction.deleteSubscription => 'Delete Subscription',
    SyncAction.createDiscount => 'Create Discount',
    SyncAction.updateDiscount => 'Update Discount',
    SyncAction.deleteDiscount => 'Delete Discount',
  };
}
```

After writing, search for any UI files that reference the old `AppNotification` fields (`table`, `operation`, `rowKey`) and note them — they'll need minor updates in Task C10.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C5: Run Drift code generation

**Files to create/modify:** All `*.g.dart` files in `lib/database/`
**Context files to read (if needed):** None
**Depends on:** Tasks C2, C3

**Specification:**

Run the Drift code generator to regenerate all `*.g.dart` files after the `logs` table and enum changes:

```bash
cd /home/abdihakim/Documents/GITHUB/eduxal-labs/eduxal
dart run build_runner build --delete-conflicting-outputs
```

This may take a few minutes. After completion:
1. Check for errors: `dart analyze lib/database/ 2>&1 | head -40`
2. Verify the generated `LogsCompanion` class now has `action`, `resource`, `payload` fields (not `tbl`, `op`, `rowKey`, `columns`)
3. Verify `SyncAction` and `SyncActionConverter` are accessible from generated code

If there are errors due to other files still referencing removed enums (`LogTable`, `LogOperation`, column bitset enums), that's expected — those files will be updated in subsequent tasks.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C6: Update `database.dart` — migration for logs table

**Files to create/modify:** `lib/database/database.dart`
**Context files to read (if needed):** Read current `lib/database/database.dart` to see existing migration strategy
**Depends on:** Task C5

**Specification:**

Increment `schemaVersion` by 1 in `AppDatabase`. Add a migration step that drops and recreates the `logs` table. Log data is transient (pending sync actions) so data loss is acceptable.

In the `MigrationStrategy`:
```dart
onUpgrade: (migrator, from, to) async {
  // ... existing migrations ...
  if (from < NEW_VERSION) {
    // Logs table schema changed: action-based model replaces mutation-based model.
    // Drop old logs and recreate — pending sync data is lost but that's acceptable.
    await migrator.deleteTable('logs');
    await migrator.createTable(logs);
  }
},
```

Also update `onCreate` if the raw SQL for logs indexes/triggers needs changing (the old `logs` table had no special indexes beyond the autoincrement PK, so this should be minimal).

Run `dart analyze lib/database/database.dart 2>&1 | head -20` to verify.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C7: Rewrite `sync_engine.dart` — action-based push flow

**Files to create/modify:** `lib/sync/sync_engine.dart`
**Context files to read (if needed):** Read current `lib/sync/sync_engine.dart` to understand the watch loop (KEEP) and push loop (REPLACE)
**Depends on:** Tasks C1, C3, C5

**Specification:**

Rewrite the push side of `sync_engine.dart`. The watch side stays.

**Push flow — what to remove:**
- All references to `LogProcessor` / `log_processor.dart`
- Batch-based push logic (`MutationBatch`, batch tracking, mutation result mapping)
- Any `import` of `log_processor.dart`

**Push flow — new implementation:**

The push loop reads pending log entries one at a time (oldest first) and sends each as an `ActionRequest` via the gRPC bidirectional stream. It waits for the `ActionResponse` before sending the next action.

```dart
// Pseudocode for the new push loop:
Future<void> _pushActions(String accountId, String accessToken) async {
  final logsDao = _db.logsDao;
  final pending = await logsDao.getPendingLogs(accountId);
  if (pending.isEmpty) return;

  // Open bidirectional stream
  final requestController = StreamController<ActionRequest>();
  final responseStream = _syncClient.pushActions(
    requestController.stream,
    options: CallOptions(metadata: {'authorization': 'Bearer $accessToken'}),
  );

  int nextIndex = 0;

  // Listen for responses
  await for (final response in responseStream) {
    // Process the response for the current action
    if (response.success) {
      // Apply returned rows to local DB via delta_writer
      for (final row in response.rows) {
        await _applyActionRow(row);
      }
      // Delete the log entry
      await logsDao.deleteLog(response.id);
    } else {
      // Map error code to action
      switch (response.code) {
        case 1: // permission_denied
          await logsDao.markFailed(response.id, response.error);
        case 2: // conflict — apply server's version, delete log
          for (final row in response.rows) {
            await _applyActionRow(row);
          }
          await logsDao.deleteLog(response.id);
        case 3: // validation_error
          await logsDao.markFailed(response.id, response.error);
        case 4: // not_found
          await logsDao.markFailed(response.id, response.error);
        default:
          await logsDao.markFailed(response.id, response.error);
      }
    }

    // Send the next action (if any)
    nextIndex++;
    if (nextIndex < pending.length) {
      final next = pending[nextIndex];
      requestController.add(ActionRequest(
        id: next.id,
        action: next.action.value,
        payload: next.payload,
      ));
    } else {
      await requestController.close();
    }
  }
}
```

Send the first action to kick off the stream, then send subsequent actions only after receiving each response.

**`_applyActionRow` method:**
Reuse the existing `DeltaWriter` logic. An `ActionRow` is structurally similar to a `SyncDelta` — it has `table`, `operation`, `row_key`, and `data` (InsertData). Write a thin adapter that converts `ActionRow` to the format `DeltaWriter` expects, or call the delta writer's internal methods directly.

**Watch flow — keep as-is:**
The watch side of `sync_engine.dart` should remain unchanged. It already uses `WatchRequest`/`SyncDelta` which are not changing.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C8: Delete `log_processor.dart`

**Files to create/modify:**
- `lib/sync/log_processor.dart` — DELETE entirely
- Any file that imports `log_processor.dart` — remove the import

**Context files to read (if needed):** None
**Depends on:** Task C7

**Specification:**

Delete `lib/sync/log_processor.dart` (2097 lines). This file contained:
- Batch building logic
- FK dependency ordering (`kTableInsertPriority`)
- Invitation pairing
- Coalescing/collapsing mutations
- Column bitmask OR-ing
- All of which are eliminated by the action-based model

Search for any remaining imports:
```bash
grep -rn "log_processor" lib/
```

Remove all `import` statements referencing this file. If any code still calls `LogProcessor`, it should have been replaced in Task C7.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C9: Update DAOs — schools_dao.dart, members_dao.dart

**Files to create/modify:**
- `lib/database/daos/schools_dao.dart`
- `lib/database/daos/members_dao.dart`

**Context files to read (if needed):** Read these DAO files to see which methods write `LogsCompanion` entries
**Depends on:** Tasks C2, C5

**Specification:**

Update every method that creates a `LogsCompanion` to use the new action-based format.

**Pattern — old:**
```dart
await into(db.logs).insert(LogsCompanion(
  account: Value(accountId),
  tbl: Value(LogTable.schools),
  op: Value(LogOperation.insert),
  rowKey: Value(schoolId),
  columns: const Value.absent(),
  created: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
));
```

**Pattern — new:**
```dart
final payload = CreateSchoolPayload(
  id: schoolId,
  name: name,
  // ... all fields
);
await into(db.logs).insert(LogsCompanion(
  account: Value(accountId),
  action: Value(SyncAction.createSchool),
  resource: Value(name),  // human-readable display key
  payload: Value(payload.writeToBuffer()),
  created: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
));
```

**`schools_dao.dart` (5 LogsCompanion calls):**
For each method that logs:
1. Import the appropriate `*Payload` class from `lib/proto/services/sync.pb.dart`
2. Build the payload proto message with all the data the method already has
3. Write the new `LogsCompanion` with `action`, `resource`, and `payload`

- `createSchool` → `SyncAction.createSchool`, `CreateSchoolPayload`, resource = school name
- `updateSchool` → `SyncAction.updateSchool`, `UpdateSchoolPayload`, resource = school name or ID

**`members_dao.dart` (21 LogsCompanion calls):**
This is the largest DAO to update. Methods include:
- `createTeacher` → `SyncAction.createTeacher`, `CreateTeacherPayload`
- `updateTeacher` → `SyncAction.updateTeacher`, `UpdateTeacherPayload`
- `deleteTeacher` → `SyncAction.deleteTeacher`, `DeleteTeacherPayload`
- Same pattern for staff, owner, guardian CRUD
- Resource display key = user phone or name

For create-member methods (invitation pattern), the payload includes the user's phone and name (which the method already has as parameters). The server will handle the user lookup/creation.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C10: Update DAOs — accounts_dao.dart, departments_dao.dart, terms_dao.dart, subjects_dao.dart, enrollments_dao.dart

**Files to create/modify:**
- `lib/database/daos/accounts_dao.dart` (3 LogsCompanion calls)
- `lib/database/daos/departments_dao.dart` (5 LogsCompanion calls)
- `lib/database/daos/terms_dao.dart` (3 LogsCompanion calls)
- `lib/database/daos/subjects_dao.dart` (6 LogsCompanion calls)
- `lib/database/daos/enrollments_dao.dart` (3 LogsCompanion calls)

**Context files to read (if needed):** Read each DAO to see current `LogsCompanion` patterns
**Depends on:** Tasks C2, C5

**Specification:**

Same pattern as Task C9. For each DAO:

**`accounts_dao.dart`:**
- `updateName` / `updateEmail` / `updateStatus` → `SyncAction.updateUser`, `UpdateUserPayload`
- Resource = user name or phone

**`departments_dao.dart`:**
- `create` → `SyncAction.createDepartment`, `CreateDepartmentPayload`, resource = dept name
- `update` → `SyncAction.updateDepartment`, `UpdateDepartmentPayload`
- `delete` → `SyncAction.deleteDepartment`, `DeleteDepartmentPayload`
- `assignTeacherDept` / `assignStaffDept` → These update the teacher/staff record's department field. Use `SyncAction.updateTeacher` / `SyncAction.updateStaff` with the appropriate `Update*Payload`.

**`terms_dao.dart`:**
- `createTerm` → `SyncAction.createTerm`, `CreateTermPayload`
- `updateTerm` → `SyncAction.updateTerm`, `UpdateTermPayload`
- `deleteTerm` → `SyncAction.deleteTerm`, `DeleteTermPayload`
- Resource = "Year YYYY Term T"

**`subjects_dao.dart`:**
- `assignSubject` → `SyncAction.assignSubject`, `AssignSubjectPayload`
- `unassignSubject` → `SyncAction.unassignSubject`, `UnassignSubjectPayload`
- `assignClassTeacher` → `SyncAction.assignClassTeacher`, `AssignClassTeacherPayload`
- `unassignClassTeacher` → `SyncAction.unassignClassTeacher`, `UnassignClassTeacherPayload`
- Plus any create/update methods
- Resource = subject name or class description

**`enrollments_dao.dart`:**
- `enroll` → `SyncAction.enrollStudent`, `EnrollStudentPayload`
- `unenroll` → `SyncAction.unenrollStudent`, `UnenrollStudentPayload`
- Plus other logged methods
- Resource = student name or ADM

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C11: Update DAOs — exams_grades_dao.dart, finance_dao.dart

**Files to create/modify:**
- `lib/database/daos/exams_grades_dao.dart` (11 LogsCompanion calls)
- `lib/database/daos/finance_dao.dart` (9 LogsCompanion calls)

**Context files to read (if needed):** Read each DAO to see current `LogsCompanion` patterns
**Depends on:** Tasks C2, C5

**Specification:**

**`exams_grades_dao.dart` (11 log calls):**
- `createExam` → `SyncAction.createExam`, `CreateExamPayload`
- `updateExam` → `SyncAction.updateExam`, `UpdateExamPayload`
- `deleteExam` → `SyncAction.deleteExam`, `DeleteExamPayload`
- `createPaper` → `SyncAction.createPaper`, `CreatePaperPayload`
- `updatePaper` → `SyncAction.updatePaper`, `UpdatePaperPayload`
- `deletePaper` → `SyncAction.deletePaper`, `DeletePaperPayload`
- `markGrades` → `SyncAction.markGrades`, `MarkGradesPayload` (includes `repeated GradeRecord`)
- `updateGrade` → `SyncAction.updateGrade`, `UpdateGradePayload`
- `deleteGrade` → `SyncAction.deleteGrade`, `DeleteGradePayload`
- `updateMastery` (if logged) → `SyncAction.updateMastery`, `UpdateMasteryPayload`

For `markGrades`: the payload's `records` field is a `repeated GradeRecord`. Build one `GradeRecord` per student grade being marked, then wrap in `MarkGradesPayload`.

**`finance_dao.dart` (9 log calls):**
- `createFee` → `SyncAction.createFee`, `CreateFeePayload`
- `updateFee` → `SyncAction.updateFee`, `UpdateFeePayload`
- `deleteFee` → `SyncAction.deleteFee`, `DeleteFeePayload`
- `createInvoice` → `SyncAction.createInvoice`, `CreateInvoicePayload`
- `updateInvoice` → `SyncAction.updateInvoice`, `UpdateInvoicePayload`
- `deleteInvoice` → `SyncAction.deleteInvoice`, `DeleteInvoicePayload`
- `createPayment` → `SyncAction.createPayment`, `CreatePaymentPayload`
- `updatePayment` → `SyncAction.updatePayment`, `UpdatePaymentPayload`
- `deletePayment` → `SyncAction.deletePayment`, `DeletePaymentPayload`

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C12: Update DAOs — attendance_dao.dart, timetable_dao.dart, announcements_dao.dart, roles_dao.dart, plans_dao.dart, settings_dao.dart

**Files to create/modify:**
- `lib/database/daos/attendance_dao.dart` (3 LogsCompanion calls)
- `lib/database/daos/timetable_dao.dart` (6 LogsCompanion calls)
- `lib/database/daos/announcements_dao.dart` (3 LogsCompanion calls)
- `lib/database/daos/roles_dao.dart` (5 LogsCompanion calls)
- `lib/database/daos/plans_dao.dart` (5 LogsCompanion calls)
- `lib/database/daos/settings_dao.dart` (2 LogsCompanion calls)

**Context files to read (if needed):** Read each DAO
**Depends on:** Tasks C2, C5

**Specification:**

**`attendance_dao.dart`:**
- `mark` → `SyncAction.markAttendance`, `MarkAttendancePayload` (includes `repeated AttendanceRecord`)
- `delete` → `SyncAction.deleteAttendance`, `DeleteAttendancePayload`

For `mark`: build one `AttendanceRecord` per student, wrap in `MarkAttendancePayload`.

**`timetable_dao.dart`:**
- `createEntry` → `SyncAction.createTimetableEntry`, `CreateTimetableEntryPayload`
- `updateEntry` → `SyncAction.updateTimetableEntry`, `UpdateTimetableEntryPayload`
- `deleteEntry` → `SyncAction.deleteTimetableEntry`, `DeleteTimetableEntryPayload`

**`announcements_dao.dart`:**
- `create` → `SyncAction.createAnnouncement`, `CreateAnnouncementPayload`
- `update` → `SyncAction.updateAnnouncement`, `UpdateAnnouncementPayload`
- `delete` → `SyncAction.deleteAnnouncement`, `DeleteAnnouncementPayload`

**`roles_dao.dart`:**
- `createRole` → `SyncAction.createRole`, `CreateRolePayload`
- `updateRole` → `SyncAction.updateRole`, `UpdateRolePayload`
- `deleteRole` → `SyncAction.deleteRole`, `DeleteRolePayload`
- `assignRole` → `SyncAction.assignRole`, `AssignRolePayload`
- `unassignRole` → `SyncAction.unassignRole`, `UnassignRolePayload`

**`plans_dao.dart`:**
- `createPlan` → `SyncAction.createPlan`, `CreatePlanPayload`
- `updatePlan` → `SyncAction.updatePlan`, `UpdatePlanPayload`
- `deletePlan` → `SyncAction.deletePlan`, `DeletePlanPayload`
- Plus subscription/discount methods if they exist in this DAO

**`settings_dao.dart`:**
- `updateSettings` → `SyncAction.updateSettings`, `UpdateSettingsPayload`

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C13: Fix UI references to old AppNotification fields

**Files to create/modify:** Any UI files that reference `AppNotification.table`, `AppNotification.operation`, or `AppNotification.rowKey`
**Context files to read (if needed):** None — search with grep
**Depends on:** Task C4

**Specification:**

Search for all UI references to the old `AppNotification` fields:
```bash
grep -rn "\.table\b\|\.operation\b\|\.rowKey\b" lib/ui/
grep -rn "AppNotification" lib/ui/
```

Update any widgets that display notification details to use `.action` and `.resource` instead.

The `title` and `subtitle` getters on `AppNotification` already provide the formatted display strings, so most UI code should just work. If any widget was accessing `.table` or `.operation` directly (e.g. for filtering or icons), update it to use `.action` (a `SyncAction` value).

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE**

---

### Task C14: Update `delta_writer.dart` if needed

**Files to create/modify:** `lib/sync/delta_writer.dart`
**Context files to read (if needed):** Read current `delta_writer.dart` to check if it references any removed types
**Depends on:** Task C1

**Specification:**

The `SyncDelta` message format is unchanged, so `delta_writer.dart` should mostly work as-is. However, check for:

1. Any imports of removed proto types (`MutationBatch`, `Mutation`, `PushAck`, `MutationResult`, `UpdateData`)
2. Any references to `LogTable`, `LogOperation`, or column bitset enums from `enums.dart`
3. The `ActionRow` type from push responses also needs to be handled — add a method that converts `ActionRow` to the format the delta writer expects (or reuse the existing `SyncDelta` processing path)

If the file compiles cleanly after Tasks C1 and C2 with no changes needed, just verify and mark complete.

Add a helper method for processing `ActionRow` from push responses:
```dart
/// Applies a single ActionRow (from push response) to the local database.
/// ActionRow has the same shape as SyncDelta: table, operation, row_key, data.
Future<void> applyActionRow(ActionRow row) async {
  // Reuse the same logic as processDelta but with ActionRow fields
  if (row.operation == 0) {
    // Upsert
    await _upsertRow(row.table, row.rowKey, row.data);
  } else if (row.operation == 2) {
    // Delete
    await _deleteRow(row.table, row.rowKey);
  }
}
```

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE** — Verified: `delta_writer.dart` compiles cleanly with zero errors. No references to removed types (`MutationBatch`, `Mutation`, `PushAck`, `MutationResult`, `UpdateData`, `LogTable`, `LogOperation`, column bitset enums). The `ActionRow` handling is already implemented in `sync_engine.dart`'s `_applyActionRow` method which converts `ActionRow` → `SyncDelta` and delegates to `DeltaWriter`. No changes needed.

---

### Task C15: Update seeder for action-based logging

**Files to create/modify:** `lib/core/seeder.dart`
**Context files to read (if needed):** Read current `lib/core/seeder.dart` to understand the `_log()` helper
**Depends on:** Tasks C2, C5

**Specification:**

The seeder (~2200 lines) creates demo data by writing directly to the local DB and creating log entries for sync. Update it for the action-based model:

1. **Find the `_log()` helper function** — it currently creates `LogsCompanion(tbl, op, rowKey, columns)`. Replace it with a new helper:

```dart
Future<void> _log(SyncAction action, String resource, GeneratedMessage payload) async {
  await _db.logsDao.insertLog(LogsCompanion(
    account: Value(_accountId),
    action: Value(action),
    resource: Value(resource),
    payload: Value(Uint8List.fromList(payload.writeToBuffer())),
    created: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
  ));
}
```

2. **Update every `_log()` call site** throughout the seeder. Each call currently passes `LogTable`, `LogOperation`, `rowKey`, and optionally `columns`. Replace with `SyncAction`, display string, and the appropriate `*Payload` proto message.

3. **Sequential creation:** The CONVERSATION_CONTEXT specifies the seeder should create data sequentially (simulating human actions) rather than in batches. If the seeder currently uses `Future.wait()` or parallel inserts for independent rows, convert them to sequential `await` calls. This is important because the action-based model sends actions one-at-a-time in creation order.

4. **Import** `package:protobuf/protobuf.dart` for `GeneratedMessage` and the proto payload classes from `lib/proto/services/sync.pb.dart`.

The seeder is large so this is a significant update. Focus on correctness: every log call must build the correct `*Payload` with all fields that the server will need to recreate the row.

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE** — Rewrote `_log()` helper to accept `SyncAction`, `resource` string, and `GeneratedMessage` payload. Updated all ~31 call sites plus the inline invoice-update log. Added imports for `dart:typed_data`, `fixnum`, `protobuf`, and `sync.pb.dart`. Attendance and grades now batch records per class/stream/date into single `MarkAttendancePayload` / `MarkGradesPayload` payloads. Removed all references to `LogTable`, `LogOperation`, `InvoicesColumn`. File compiles cleanly with zero errors or warnings.

---

### Task C16: Full build + analysis

**Files to create/modify:** None (verification only)
**Context files to read (if needed):** None
**Depends on:** All previous tasks

**Specification:**

1. Run Drift code generation one final time:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

2. Run full analysis:
   ```bash
   dart analyze lib/
   ```

3. Fix any remaining compile errors. Common issues:
   - Lingering imports of `LogTable`, `LogOperation`, or column bitset enums
   - Missing imports of `SyncAction` or proto payload classes
   - Type mismatches in `LogsCompanion` constructor calls

4. Search for any remaining references to removed types:
   ```bash
   grep -rn "LogTable\|LogOperation\|LogProcessor\|MutationBatch\|PushAck\|UpdateData" lib/ --include="*.dart" | grep -v ".g.dart" | grep -v "proto/"
   ```

5. Verify no `log_processor.dart` references remain:
   ```bash
   grep -rn "log_processor" lib/
   ```

**Update after completion:**
- [x] Mark this task `[x]`

✅ **DONE** — Drift code generation succeeded (250 outputs). Full `dart analyze lib/` reports 0 errors, 5 pre-existing warnings (all UI unused parameters), 36 info-level lint hints. Fixed two missed DAOs (`users_dao.dart` and `school_scopes_dao.dart`) that still referenced `LogTable`, `LogOperation`, `UsersColumn`, and `RolesColumn` — converted all log calls to action-based `SyncAction`/payload model. Verified zero references to `LogTable`, `LogOperation`, `LogProcessor`, `MutationBatch`, `PushAck` remain in non-generated, non-proto Dart files. No `log_processor.dart` code references remain (only CONTEXT.md documentation).

---

### Task C17: Commit the sync redesign

**Files to create/modify:** None (git operations only)
**Context files to read (if needed):** None
**Depends on:** Task C16

**Specification:**

Create structured commits for the sync redesign:

1. `proto: regenerate Dart stubs for action-based sync` — `lib/proto/`
2. `db: redesign logs table and enums for action-based model` — `lib/database/tables/logs.dart`, `lib/database/tables/enums.dart`, `lib/database/database.dart`
3. `db: rewrite logs_dao for action-based model` — `lib/database/daos/logs_dao.dart`
4. `model: update AppNotification for action-based display` — `lib/models/app_notification.dart`
5. `sync: rewrite sync engine push flow for action-based model` — `lib/sync/sync_engine.dart`
6. `sync: delete log_processor (replaced by action-based model)` — delete `lib/sync/log_processor.dart`
7. `sync: update delta_writer for action row handling` — `lib/sync/delta_writer.dart`
8. `db: update DAOs for action-based logging` — all modified DAO files
9. `feat: update seeder for action-based logging` — `lib/core/seeder.dart`
10. `ui: fix notification display for action-based model` — UI files
11. `chore: regenerate Drift code` — all `*.g.dart` files

Use `git add <paths>` + `git commit -m "<message>"` for each group.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task C18: Update AGENT.md for action-based sync model

**Files to create/modify:** `AGENT.md`
**Context files to read (if needed):** `CONVERSATION_CONTEXT.md`
**Depends on:** Task C17

**Specification:**

Update `AGENT.md` to reflect the sync redesign:

1. **§7 (The `logs` Table):** Replace the old schema with the new one (action/resource/payload). Remove all column bitset documentation. Remove LogTable/LogOperation/LogStatus enums (keep LogStatus, add SyncAction).

2. **§7a (Client-Side Batch Ordering):** DELETE this entire section — FK ordering is gone.

3. **Update §15 (Known Code Issues):** Remove I1 and I2 (delta_writer and log_processor compile errors) — both are resolved by the redesign.

4. **Update §5 (Database Design):** Note that the `logs` table now stores action payloads as blobs, not table/operation/rowKey.

5. **Add a new section** documenting the SyncAction enum (77 values) and the action-based push flow.

6. **Update §14 (gRPC Proto Files):** Reflect the new `sync.proto` structure — `PushActions` replaces `PushChanges`, `ActionRequest`/`ActionResponse` replace `MutationBatch`/`PushAck`.

**Update after completion:**
- [ ] Mark this task `[x]`
