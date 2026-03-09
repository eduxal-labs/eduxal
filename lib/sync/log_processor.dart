import 'dart:convert';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart';
import 'package:fixnum/fixnum.dart';

import '../database/database.dart';
import '../database/daos/logs_dao.dart';
import '../database/tables/enums.dart';
import '../proto/services/sync.pb.dart';

/// Reads the local [Logs] table, coalesces mutations for the same row,
/// and builds [MutationBatch] proto messages ready to push to the server.
///
/// **Coalescing rules (from AGENT.md §7):**
/// - If any log for a `(tbl, rowKey)` is a Delete → discard all others,
///   emit one Delete.
/// - If the first log is an Insert and subsequent logs are Updates →
///   merge into a single Insert with the current full row from the DB.
/// - If all logs are Updates → OR all column bitmasks, emit one Update
///   with the current local values for those columns.
///
/// **FK-aware ordering within each batch (from AGENT.md §7a):**
/// The server processes mutations in the exact order received — it does NOT
/// reorder. The client MUST sort mutations within each [MutationBatch] to
/// avoid FK constraint violations:
/// - Inserts/Updates: parents before children (lower topological level first).
/// - Deletes: children before parents (higher topological level first).
/// - All inserts/updates come before all deletes.
/// See [kTableInsertPriority] for the per-table topological levels.
///
/// **Invitation batch grouping (from AGENT.md §16a):**
/// Member Inserts (owners, teachers, staff, students, guardians) whose
/// `user` field references a user Insert also in the pending logs MUST
/// be placed in the same [MutationBatch]. The topological sort naturally
/// places the user Insert (level 0) before the member Insert (level 1+).
///
/// **Proto mapping (post-regeneration):**
/// - Insert operations → `Mutation.insert` with `InsertData` (no PK/timestamp fields)
/// - Update operations → `Mutation.update` with `UpdateData` (only changed fields via `has*()`)
/// - Delete operations → no data payload, just `table`, `operation`, `rowKey`
/// - `Mutation.columns` no longer exists on the wire — the server uses `has*()`
///   on the `*Update` message to detect which fields changed.
/// Topological level of each table based on FK dependencies in `schema.sql`.
/// Lower value = closer to root = inserted first / deleted last.
const kTableInsertPriority = <LogTable, int>{
  // Level 0 — no FK dependencies
  LogTable.users: 0,
  LogTable.schools: 0,
  LogTable.plans: 0,
  // Level 1 — depends on L0
  LogTable.owners: 1,
  LogTable.students: 1,
  LogTable.departments: 1,
  LogTable.terms: 1,
  LogTable.settings: 1,
  LogTable.roles: 1,
  LogTable.announcements: 1,
  // Level 2 — depends on L0 + L1
  LogTable.teachers: 2,
  LogTable.staff: 2,
  LogTable.guardians: 2,
  LogTable.enrollments: 2,
  LogTable.classTeachers: 2,
  LogTable.scopes: 2,
  LogTable.fees: 2,
  // Level 3 — depends on L0–L2
  LogTable.subjects: 3,
  LogTable.exams: 3,
  LogTable.invoices: 3,
  LogTable.attendance: 3,
  // Level 4 — depends on L0–L3
  LogTable.timetable: 4,
  LogTable.lessons: 4,
  LogTable.papers: 4,
  LogTable.payments: 4,
  LogTable.subscriptions: 4,
  LogTable.discounts: 4,
  LogTable.mastery: 4,
  LogTable.aiusage: 4,
  LogTable.grades: 4,
};

class LogProcessor {
  LogProcessor(this._db, this._logsDao);

  final AppDatabase _db;
  final LogsDao _logsDao;

  /// Maps `batchId → [logIds]` so that [acknowledgeBatch] can delete the
  /// correct rows after the server acknowledges a batch.
  final Map<String, List<int>> _batchLogIds = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Read all pending logs for [accountId], coalesce, and return
  /// [MutationBatch] messages. Each batch contains up to [batchSize]
  /// mutations, respecting the invitation-grouping constraint.
  Future<List<MutationBatch>> buildBatches(
    String accountId, {
    int batchSize = 50,
  }) async {
    final logs = await _logsDao.getPendingLogs(accountId);
    if (logs.isEmpty) return [];

    // 1. Group by (tbl, rowKey).
    final groups = <_GroupKey, List<LogsData>>{};
    for (final log in logs) {
      final key = _GroupKey(log.tbl, log.rowKey);
      (groups[key] ??= []).add(log);
    }

    // 2. Coalesce each group into a single _CoalescedEntry.
    final coalesced = <_CoalescedEntry>[];
    for (final entry in groups.entries) {
      final c = _coalesce(entry.key, entry.value);
      if (c != null) coalesced.add(c);
    }

    // 3. Build proto Mutation for each coalesced entry (reading row data).
    final mutationsWithMeta = <_MutationWithMeta>[];
    for (final c in coalesced) {
      final mutation = await _buildMutation(c);
      if (mutation == null) continue; // row gone locally, skip
      mutationsWithMeta.add(_MutationWithMeta(mutation: mutation, entry: c));
    }

    // 4. Identify invitation pairs (user Insert + member Insert).
    final invitationPairs = _findInvitationPairs(mutationsWithMeta);

    // 5. Group into batches respecting invitation constraints.
    return _splitIntoBatches(mutationsWithMeta, invitationPairs, batchSize);
  }

  /// Returns the log IDs associated with a given [batchId], or empty list.
  List<int> logIdsForBatch(String batchId) => _batchLogIds[batchId] ?? const [];

  /// Called when the server acknowledges a batch successfully.
  /// Deletes the corresponding log rows.
  Future<void> acknowledgeBatch(String batchId) async {
    final ids = _batchLogIds.remove(batchId);
    if (ids != null && ids.isNotEmpty) {
      await _logsDao.deleteLogs(ids);
    }
  }

  /// Called when a specific mutation within a batch fails.
  /// Marks the log rows for that mutation as failed.
  Future<void> markFailed(int logId, String error) async {
    await _logsDao.markFailed(logId, error);
  }

  /// Mark all log IDs in a batch as failed (e.g. batch-level error).
  Future<void> markBatchFailed(String batchId, String error) async {
    final ids = _batchLogIds.remove(batchId);
    if (ids == null) return;
    for (final id in ids) {
      await _logsDao.markFailed(id, error);
    }
  }

  /// Removes tracking state for a batch without touching DB rows.
  /// Used when the caller handles the IDs itself.
  void clearBatch(String batchId) {
    _batchLogIds.remove(batchId);
  }

  // ---------------------------------------------------------------------------
  // Coalescing
  // ---------------------------------------------------------------------------

  _CoalescedEntry? _coalesce(_GroupKey key, List<LogsData> entries) {
    // Collect all log IDs for this group.
    final logIds = entries.map((e) => e.id).toList();

    // Check if any entry is a Delete → supersede everything.
    final hasDelete = entries.any((e) => e.op == LogOperation.delete);
    if (hasDelete) {
      return _CoalescedEntry(
        tbl: key.tbl,
        rowKey: key.rowKey,
        op: LogOperation.delete,
        columns: null,
        logIds: logIds,
      );
    }

    // Check if the first entry is an Insert.
    final first = entries.first;
    if (first.op == LogOperation.insert) {
      // Merge into a single Insert — row data comes from current DB state.
      return _CoalescedEntry(
        tbl: key.tbl,
        rowKey: key.rowKey,
        op: LogOperation.insert,
        columns: null,
        logIds: logIds,
      );
    }

    // All entries are Updates — OR all bitmasks together.
    int combined = 0;
    for (final entry in entries) {
      if (entry.columns != null) combined |= entry.columns!;
    }
    return _CoalescedEntry(
      tbl: key.tbl,
      rowKey: key.rowKey,
      op: LogOperation.update,
      columns: combined,
      logIds: logIds,
    );
  }

  // ---------------------------------------------------------------------------
  // Build Mutation proto from coalesced entry
  // ---------------------------------------------------------------------------

  Future<Mutation?> _buildMutation(_CoalescedEntry c) async {
    final mutation = Mutation()
      ..table =
          c.tbl.value +
          1 // LogTable is 0-based; proto oneof fields are 1-based
      ..operation = c.op.index
      ..rowKey = c.rowKey;

    // For Delete: no row data needed.
    if (c.op == LogOperation.delete) return mutation;

    if (c.op == LogOperation.insert) {
      // For Insert: read current row from local DB → InsertData.
      final insertData = await _readInsertData(c.tbl, c.rowKey);
      if (insertData == null) return null; // row no longer exists locally
      mutation.insert = insertData;
    } else {
      // For Update: read current row from local DB → UpdateData with only
      // changed columns set (using has*() semantics on the wire).
      final updateData = await _readUpdateData(c.tbl, c.rowKey, c.columns ?? 0);
      if (updateData == null) return null; // row no longer exists locally
      mutation.update = updateData;
    }

    return mutation;
  }

  // ---------------------------------------------------------------------------
  // Invitation pair detection
  // ---------------------------------------------------------------------------

  /// Returns a set of user-mutation indices that must be paired with their
  /// corresponding member-mutation indices in the same batch.
  ///
  /// Each pair is (userMutationIndex, memberMutationIndex).
  List<_InvitationPair> _findInvitationPairs(
    List<_MutationWithMeta> mutations,
  ) {
    // Member tables: owners(2), students(3), guardians(4), teachers(6), staff(7)
    const memberTables = {
      LogTable.owners,
      LogTable.students,
      LogTable.guardians,
      LogTable.teachers,
      LogTable.staff,
    };

    // Find all user Insert mutations, indexed by rowKey (= userId).
    final userInserts = <String, int>{}; // userId → index in mutations
    for (var i = 0; i < mutations.length; i++) {
      final m = mutations[i];
      if (m.entry.tbl == LogTable.users && m.entry.op == LogOperation.insert) {
        userInserts[m.entry.rowKey] = i;
      }
    }

    if (userInserts.isEmpty) return [];

    final pairs = <_InvitationPair>[];

    for (var i = 0; i < mutations.length; i++) {
      final m = mutations[i];
      if (!memberTables.contains(m.entry.tbl)) continue;
      if (m.entry.op != LogOperation.insert) continue;

      // Extract the `user` field from the member's insert data to check if it
      // references a pending user Insert.
      final userId = _extractUserFromMemberInsert(m.entry.tbl, m.mutation);
      if (userId != null && userInserts.containsKey(userId)) {
        pairs.add(
          _InvitationPair(userIndex: userInserts[userId]!, memberIndex: i),
        );
      }
    }

    return pairs;
  }

  /// Extracts the `user` field value from a member-table mutation's insert data.
  String? _extractUserFromMemberInsert(LogTable tbl, Mutation mutation) {
    if (!mutation.hasInsert()) return null;
    final data = mutation.insert;
    switch (tbl) {
      case LogTable.owners:
        return data.hasOwner() ? data.owner.user : null;
      case LogTable.teachers:
        return data.hasTeacher() ? data.teacher.user : null;
      case LogTable.staff:
        return data.hasStaffMember() ? data.staffMember.user : null;
      case LogTable.students:
        return data.hasStudent() ? data.student.user : null;
      case LogTable.guardians:
        return data.hasGuardian() ? data.guardian.user : null;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Batch splitting
  // ---------------------------------------------------------------------------

  List<MutationBatch> _splitIntoBatches(
    List<_MutationWithMeta> mutations,
    List<_InvitationPair> pairs,
    int batchSize,
  ) {
    // Track which mutations are "spoken for" by an invitation pair.
    final pairedIndices = <int>{};
    for (final p in pairs) {
      pairedIndices.add(p.userIndex);
      pairedIndices.add(p.memberIndex);
    }

    // Build groups: invitation pairs as multi-element groups, rest as singletons.
    // Each group is a list of indices into `mutations`.
    final groups = <List<int>>[];

    // Add invitation pairs as groups (ordering within handled by sort below).
    for (final p in pairs) {
      groups.add([p.userIndex, p.memberIndex]);
    }

    // Add standalone mutations.
    for (var i = 0; i < mutations.length; i++) {
      if (!pairedIndices.contains(i)) {
        groups.add([i]);
      }
    }

    // Split groups into batches of up to batchSize mutations.
    final batches = <MutationBatch>[];
    var currentMutations = <_MutationWithMeta>[];
    var currentLogIds = <int>[];

    for (final group in groups) {
      // If adding this group would exceed batchSize, flush current batch.
      if (currentMutations.isNotEmpty &&
          currentMutations.length + group.length > batchSize) {
        batches.add(_createBatch(_sortForFk(currentMutations), currentLogIds));
        currentMutations = [];
        currentLogIds = [];
      }

      for (final idx in group) {
        currentMutations.add(mutations[idx]);
        currentLogIds.addAll(mutations[idx].entry.logIds);
      }
    }

    // Flush remaining.
    if (currentMutations.isNotEmpty) {
      batches.add(_createBatch(_sortForFk(currentMutations), currentLogIds));
    }

    return batches;
  }

  /// Sorts mutations within a batch to satisfy FK constraints (AGENT.md §7a).
  /// - Inserts/Updates: lower topological level first (parents before children).
  /// - Deletes: higher topological level first (children before parents).
  /// - All inserts/updates come before all deletes.
  List<Mutation> _sortForFk(List<_MutationWithMeta> mutations) {
    mutations.sort((a, b) {
      final aLevel = kTableInsertPriority[a.entry.tbl]!;
      final bLevel = kTableInsertPriority[b.entry.tbl]!;
      final aIsDelete = a.entry.op == LogOperation.delete;
      final bIsDelete = b.entry.op == LogOperation.delete;

      // Deletes go after all inserts/updates.
      if (aIsDelete && !bIsDelete) return 1;
      if (!aIsDelete && bIsDelete) return -1;

      // Both deletes: higher level first (children before parents).
      if (aIsDelete && bIsDelete) return bLevel.compareTo(aLevel);

      // Both inserts/updates: lower level first (parents before children).
      return aLevel.compareTo(bLevel);
    });
    return mutations.map((m) => m.mutation).toList();
  }

  MutationBatch _createBatch(List<Mutation> mutations, List<int> logIds) {
    final batchId = ObjectId().oid;
    _batchLogIds[batchId] = List.unmodifiable(logIds);
    return MutationBatch(batchId: batchId, mutations: mutations);
  }

  // ---------------------------------------------------------------------------
  // Read current row data from local Drift DB → InsertData (for Insert ops)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readInsertData(LogTable tbl, String rowKey) async {
    switch (tbl) {
      case LogTable.users:
        return _readUserInsert(rowKey);
      case LogTable.schools:
        return _readSchoolInsert(rowKey);
      case LogTable.owners:
        return _readOwnerInsert(rowKey);
      case LogTable.students:
        return _readStudentInsert(rowKey);
      case LogTable.guardians:
        return _readGuardianInsert(rowKey);
      case LogTable.departments:
        return _readDepartmentInsert(rowKey);
      case LogTable.teachers:
        return _readTeacherInsert(rowKey);
      case LogTable.staff:
        return _readStaffInsert(rowKey);
      case LogTable.terms:
        return _readTermInsert(rowKey);
      case LogTable.classTeachers:
        return _readClassTeacherInsert(rowKey);
      case LogTable.enrollments:
        return _readEnrollmentInsert(rowKey);
      case LogTable.subjects:
        return _readSubjectInsert(rowKey);
      case LogTable.attendance:
        return _readAttendanceInsert(rowKey);
      case LogTable.timetable:
        return _readTimetableInsert(rowKey);
      case LogTable.lessons:
        return _readLessonInsert(rowKey);
      case LogTable.exams:
        return _readExamInsert(rowKey);
      case LogTable.papers:
        return _readPaperInsert(rowKey);
      case LogTable.grades:
        return _readGradeInsert(rowKey);
      case LogTable.fees:
        return _readFeeInsert(rowKey);
      case LogTable.invoices:
        return _readInvoiceInsert(rowKey);
      case LogTable.payments:
        return _readPaymentInsert(rowKey);
      case LogTable.announcements:
        return _readAnnouncementInsert(rowKey);
      case LogTable.mastery:
        return _readMasteryInsert(rowKey);
      case LogTable.aiusage:
        return _readAiUsageInsert(rowKey);
      case LogTable.settings:
        return _readSettingsInsert(rowKey);
      case LogTable.roles:
        return _readRoleInsert(rowKey);
      case LogTable.scopes:
        return _readScopeInsert(rowKey);
      case LogTable.plans:
        return _readPlanInsert(rowKey);
      case LogTable.subscriptions:
        return _readSubscriptionInsert(rowKey);
      case LogTable.discounts:
        return _readDiscountInsert(rowKey);
    }
  }

  // ---------------------------------------------------------------------------
  // Read current row data from local Drift DB → UpdateData (for Update ops)
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readUpdateData(
    LogTable tbl,
    String rowKey,
    int columns,
  ) async {
    switch (tbl) {
      case LogTable.users:
        return _readUserUpdate(rowKey, columns);
      case LogTable.schools:
        return _readSchoolUpdate(rowKey, columns);
      case LogTable.students:
        return _readStudentUpdate(rowKey, columns);
      case LogTable.guardians:
        return _readGuardianUpdate(rowKey, columns);
      case LogTable.departments:
        return _readDepartmentUpdate(rowKey, columns);
      case LogTable.teachers:
        return _readTeacherUpdate(rowKey, columns);
      case LogTable.staff:
        return _readStaffUpdate(rowKey, columns);
      case LogTable.terms:
        return _readTermUpdate(rowKey, columns);
      case LogTable.classTeachers:
        return _readClassTeacherUpdate(rowKey, columns);
      case LogTable.attendance:
        return _readAttendanceUpdate(rowKey, columns);
      case LogTable.timetable:
        return _readTimetableUpdate(rowKey, columns);
      case LogTable.exams:
        return _readExamUpdate(rowKey, columns);
      case LogTable.papers:
        return _readPaperUpdate(rowKey, columns);
      case LogTable.grades:
        return _readGradeUpdate(rowKey, columns);
      case LogTable.fees:
        return _readFeeUpdate(rowKey, columns);
      case LogTable.invoices:
        return _readInvoiceUpdate(rowKey, columns);
      case LogTable.payments:
        return _readPaymentUpdate(rowKey, columns);
      case LogTable.announcements:
        return _readAnnouncementUpdate(rowKey, columns);
      case LogTable.mastery:
        return _readMasteryUpdate(rowKey, columns);
      case LogTable.aiusage:
        return _readAiUsageUpdate(rowKey, columns);
      case LogTable.settings:
        return _readSettingsUpdate(rowKey, columns);
      case LogTable.roles:
        return _readRoleUpdate(rowKey, columns);
      case LogTable.plans:
        return _readPlanUpdate(rowKey, columns);
      case LogTable.subscriptions:
        return _readSubscriptionUpdate(rowKey, columns);
      case LogTable.discounts:
        return _readDiscountUpdate(rowKey, columns);
      // These 5 tables have no *Update message — they are insert/delete only.
      case LogTable.owners:
      case LogTable.enrollments:
      case LogTable.subjects:
      case LogTable.lessons:
      case LogTable.scopes:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _parseKey(String rowKey) => rowKey.split('|');
  int _parseInt(String s) => int.parse(s);
  int? _parseIntNullable(String s) => s == 'null' ? null : int.parse(s);
  Int64 _toInt64(BigInt v) => Int64(v.toInt());

  bool _bit(int columns, int bit) => columns & (1 << bit) != 0;

  // ===========================================================================
  // Insert readers — produce InsertData from local DB rows.
  // *Insert messages omit PK fields and timestamp fields (id, created, updated).
  // PKs come from rowKey; timestamps are server-managed.
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // 0: users — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readUserInsert(String rowKey) async {
    final row = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = UserInsert()
      ..id = row.id
      ..phone = row.phone
      ..name = row.name
      ..level = row.level.index
      ..status = row.status.index;
    if (row.email != null) proto.email = row.email!;

    return InsertData()..user = proto;
  }

  // ---------------------------------------------------------------------------
  // 1: schools — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readSchoolInsert(String rowKey) async {
    final row = await (_db.select(
      _db.schools,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = SchoolInsert()
      ..id = row.id
      ..name = row.name
      ..county = row.county
      ..status = row.status.index;
    if (row.motto != null) proto.motto = row.motto!;
    if (row.phone != null) proto.phone = row.phone!;
    if (row.email != null) proto.email = row.email!;
    if (row.domain != null) proto.domain = row.domain!;
    if (row.established != null) proto.established = row.established!;

    return InsertData()..school = proto;
  }

  // ---------------------------------------------------------------------------
  // 2: owners — PK: (school, user)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readOwnerInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.owners)
              ..where((t) => t.school.equals(k[0]) & t.user.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..owner = (OwnerInsert()
        ..school = row.school
        ..user = row.user);
  }

  // ---------------------------------------------------------------------------
  // 3: students — PK: (school, adm)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readStudentInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.students)..where(
              (t) => t.school.equals(k[0]) & t.adm.equals(_parseInt(k[1])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = StudentInsert()
      ..school = row.school
      ..adm = row.adm
      ..name = row.name
      ..status = row.status.index;
    if (row.user != null) proto.user = row.user!;
    if (row.dob != null) proto.dob = row.dob!;
    if (row.gender != null) proto.gender = row.gender!.index;
    if (row.documents != null) proto.documents = row.documents!;
    if (row.admitted != null) proto.admitted = row.admitted!;

    return InsertData()..student = proto;
  }

  // ---------------------------------------------------------------------------
  // 4: guardians — PK: (school, user, student)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readGuardianInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.guardians)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.user.equals(k[1]) &
                  t.student.equals(_parseInt(k[2])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..guardian = (GuardianInsert()
        ..school = row.school
        ..user = row.user
        ..student = row.student
        ..relationship = row.relationship.index
        ..role = row.role.index);
  }

  // ---------------------------------------------------------------------------
  // 5: departments — PK: (school, name)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readDepartmentInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.departments)
              ..where((t) => t.school.equals(k[0]) & t.name.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = DepartmentInsert()
      ..school = row.school
      ..name = row.name;
    if (row.description != null) proto.description = row.description!;

    return InsertData()..department = proto;
  }

  // ---------------------------------------------------------------------------
  // 6: teachers — PK: (school, user)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readTeacherInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.teachers)
              ..where((t) => t.school.equals(k[0]) & t.user.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = TeacherInsert()
      ..school = row.school
      ..user = row.user
      ..status = row.status.index;
    if (row.hired != null) proto.hired = row.hired!;
    if (row.role != null) proto.role = row.role!;
    if (row.department != null) proto.department = row.department!;

    return InsertData()..teacher = proto;
  }

  // ---------------------------------------------------------------------------
  // 7: staff — PK: (school, user)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readStaffInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.staff)
              ..where((t) => t.school.equals(k[0]) & t.user.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = StaffInsert()
      ..school = row.school
      ..user = row.user
      ..status = row.status.index;
    if (row.idnumber != null) proto.idnumber = row.idnumber!;
    if (row.role != null) proto.role = row.role!;
    if (row.department != null) proto.department = row.department!;

    return InsertData()..staffMember = proto;
  }

  // ---------------------------------------------------------------------------
  // 8: terms — PK: (school, year, term)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readTermInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.terms)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..term = (TermInsert()
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..start = _toInt64(row.start)
        ..end = _toInt64(row.end));
  }

  // ---------------------------------------------------------------------------
  // 9: class_teachers — PK: (school, year, term, grade, stream, teacher)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readClassTeacherInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.classTeachers)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.teacher.equals(k[5]),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = ClassTeacherInsert()
      ..school = row.school
      ..year = row.year
      ..term = row.term
      ..grade = row.grade
      ..stream = row.stream
      ..teacher = row.teacher
      ..start = row.start;
    if (row.end != null) proto.end = row.end!;

    return InsertData()..classTeacher = proto;
  }

  // ---------------------------------------------------------------------------
  // 10: enrollments — PK: (school, year, term, grade, stream, student)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readEnrollmentInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.enrollments)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.student.equals(_parseInt(k[5])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..enrollment = (EnrollmentInsert()
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..stream = row.stream
        ..student = row.student);
  }

  // ---------------------------------------------------------------------------
  // 11: subjects — PK: (school, year, term, grade, stream, subject)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readSubjectInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.subjects)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.subject.equals(_parseInt(k[5])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..subject = (SubjectInsert()
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..stream = row.stream
        ..subject = row.subject
        ..teacher = row.teacher);
  }

  // ---------------------------------------------------------------------------
  // 12: attendance — PK: (school, year, term, grade, stream, student, date)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readAttendanceInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.attendance)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.student.equals(_parseInt(k[5])) &
                  t.date.equals(_parseInt(k[6])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..attendance = (AttendanceInsert()
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..stream = row.stream
        ..student = row.student
        ..date = row.date
        ..status = row.status.value);
  }

  // ---------------------------------------------------------------------------
  // 13: timetable — PK: (school, year, term, grade, stream, day, subject, start)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readTimetableInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.timetable)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.day.equalsValue(DayOfWeek.values[_parseInt(k[5])]) &
                  t.subject.equals(_parseInt(k[6])) &
                  t.start.equals(_parseInt(k[7])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..timetable = (TimetableInsert()
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..stream = row.stream
        ..subject = row.subject
        ..teacher = row.teacher
        ..day = row.day.index
        ..start = row.start
        ..end = row.end);
  }

  // ---------------------------------------------------------------------------
  // 14: lessons — PK: (school, year, term, grade, stream, date, subject, teacher)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readLessonInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.lessons)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.date.equals(_parseInt(k[5])) &
                  t.subject.equals(_parseInt(k[6])) &
                  t.teacher.equals(k[7]),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..lesson = (LessonInsert()
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..stream = row.stream
        ..date = row.date
        ..subject = row.subject
        ..teacher = row.teacher);
  }

  // ---------------------------------------------------------------------------
  // 15: exams — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readExamInsert(String rowKey) async {
    final row = await (_db.select(
      _db.exams,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = ExamInsert()
      ..id = row.id
      ..school = row.school
      ..year = row.year
      ..term = row.term
      ..grade = row.grade
      ..personalized = row.personalized
      ..type = row.type.index
      ..start = row.start
      ..end = row.end
      ..teacher = row.teacher;
    if (row.stream != null) proto.stream = row.stream!;

    return InsertData()..exam = proto;
  }

  // ---------------------------------------------------------------------------
  // 16: papers — PK: (school, exam, subject, paper) — paper nullable
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readPaperInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final school = k[0];
    final exam = k[1];
    final subject = _parseInt(k[2]);
    final paper = _parseIntNullable(k[3]);

    // Use raw query for nullable PK column.
    final results = await _db
        .customSelect(
          'SELECT * FROM papers WHERE school = ? AND exam = ? AND subject = ? '
          'AND ${paper == null ? 'paper IS NULL' : 'paper = ?'}',
          variables: [
            Variable.withString(school),
            Variable.withString(exam),
            Variable.withInt(subject),
            if (paper != null) Variable.withInt(paper),
          ],
        )
        .get();
    if (results.isEmpty) return null;

    final r = results.first;
    final proto = PaperInsert()
      ..school = r.read<String>('school')
      ..exam = r.read<String>('exam')
      ..subject = r.read<int>('subject')
      ..invigilator = r.read<String>('invigilator')
      ..start = Int64(r.read<BigInt>('start').toInt())
      ..end = Int64(r.read<BigInt>('end').toInt())
      ..status = r.read<int>('status');
    final paperVal = r.readNullable<int>('paper');
    if (paperVal != null) proto.paper = paperVal;

    return InsertData()..paper = proto;
  }

  // ---------------------------------------------------------------------------
  // 17: grades — PK: (school, exam, student, subject, paper) — paper nullable
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readGradeInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final school = k[0];
    final exam = k[1];
    final student = _parseInt(k[2]);
    final subject = _parseInt(k[3]);
    final paper = _parseIntNullable(k[4]);

    final results = await _db
        .customSelect(
          'SELECT * FROM grades WHERE school = ? AND exam = ? AND student = ? '
          'AND subject = ? AND ${paper == null ? 'paper IS NULL' : 'paper = ?'}',
          variables: [
            Variable.withString(school),
            Variable.withString(exam),
            Variable.withInt(student),
            Variable.withInt(subject),
            if (paper != null) Variable.withInt(paper),
          ],
        )
        .get();
    if (results.isEmpty) return null;

    final r = results.first;
    final proto = GradeInsert()
      ..school = r.read<String>('school')
      ..exam = r.read<String>('exam')
      ..student = r.read<int>('student')
      ..subject = r.read<int>('subject')
      ..score = r.read<double>('score')
      ..total = r.read<int>('total');
    final paperVal = r.readNullable<int>('paper');
    if (paperVal != null) proto.paper = paperVal;

    return InsertData()..grade = proto;
  }

  // ---------------------------------------------------------------------------
  // 18: fees — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readFeeInsert(String rowKey) async {
    final row = await (_db.select(
      _db.fees,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..fee = (FeeInsert()
        ..id = row.id
        ..school = row.school
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..title = row.title
        ..description = row.description
        ..amount = row.amount
        ..mandatory = row.mandatory
        ..due = _toInt64(row.due));
  }

  // ---------------------------------------------------------------------------
  // 19: invoices — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readInvoiceInsert(String rowKey) async {
    final row = await (_db.select(
      _db.invoices,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = InvoiceInsert()
      ..id = row.id
      ..school = row.school
      ..year = row.year
      ..term = row.term
      ..student = row.student
      ..amount = row.amount
      ..status = row.status.index;
    if (row.fee != null) proto.fee = row.fee!;
    if (row.description != null) proto.description = row.description!;
    if (row.due != null) proto.due = _toInt64(row.due!);

    return InsertData()..invoice = proto;
  }

  // ---------------------------------------------------------------------------
  // 20: payments — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readPaymentInsert(String rowKey) async {
    final row = await (_db.select(
      _db.payments,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = PaymentInsert()
      ..id = row.id
      ..amount = row.amount
      ..method = row.method.index;
    if (row.invoice != null) proto.invoice = row.invoice!;
    if (row.school != null) proto.school = row.school!;
    if (row.student != null) proto.student = row.student!;
    if (row.reference != null) proto.reference = row.reference!;
    if (row.recorder != null) proto.recorder = row.recorder!;
    if (row.date != null) proto.date = row.date!;

    return InsertData()..payment = proto;
  }

  // ---------------------------------------------------------------------------
  // 21: announcements — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readAnnouncementInsert(String rowKey) async {
    final row = await (_db.select(
      _db.announcements,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = AnnouncementInsert()
      ..id = row.id
      ..school = row.school
      ..title = row.title
      ..content = row.content
      ..audience = row.audience;
    if (row.grade != null) proto.grade = row.grade!;
    if (row.stream != null) proto.stream = row.stream!;
    if (row.author != null) proto.author = row.author!;

    return InsertData()..announcement = proto;
  }

  // ---------------------------------------------------------------------------
  // 22: mastery — PK: (school, student, grade, subject, topic)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readMasteryInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.mastery)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.student.equals(_parseInt(k[1])) &
                  t.grade.equals(_parseInt(k[2])) &
                  t.subject.equals(_parseInt(k[3])) &
                  t.topic.equals(_parseInt(k[4])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..mastery = (MasteryInsert()
        ..school = row.school
        ..student = row.student
        ..grade = row.grade
        ..subject = row.subject
        ..topic = row.topic
        ..score = row.score);
  }

  // ---------------------------------------------------------------------------
  // 23: aiusage — PK: (school, student, year, term)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readAiUsageInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.aiUsage)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.student.equals(_parseInt(k[1])) &
                  t.year.equals(_parseInt(k[2])) &
                  t.term.equals(_parseInt(k[3])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..aiUsage = (AiUsageInsert()
        ..school = row.school
        ..student = row.student
        ..year = row.year
        ..term = row.term
        ..allocated = row.allocated
        ..used = row.used);
  }

  // ---------------------------------------------------------------------------
  // 24: settings — PK: (school)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readSettingsInsert(String rowKey) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.school.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = SettingsInsert()
      ..school = row.school
      ..data = row.data;
    if (row.mpesa != null) proto.mpesa = row.mpesa!;

    return InsertData()..settings = proto;
  }

  // ---------------------------------------------------------------------------
  // 25: roles — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readRoleInsert(String rowKey) async {
    final row = await (_db.select(
      _db.roles,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = RoleInsert()
      ..id = row.id
      ..name = row.name;
    if (row.school != null) proto.school = row.school!;
    if (row.description != null) proto.description = row.description!;

    // Permissions: Drift stores as text (base64-encoded bytes).
    // Proto expects List<int> (bytes). Decode base64 → bytes.
    try {
      proto.permissions = base64Decode(row.permissions);
    } catch (_) {
      // If permissions is not valid base64 (e.g. raw JSON from older format),
      // send as UTF-8 bytes. The server will handle accordingly.
      proto.permissions = utf8.encode(row.permissions);
    }

    return InsertData()..role = proto;
  }

  // ---------------------------------------------------------------------------
  // 26: scopes — PK: (school, user, role) — school nullable
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readScopeInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final school = k[0] == 'null' ? null : k[0];
    final user = k[1];
    final role = k[2];

    final results = await _db
        .customSelect(
          'SELECT * FROM scopes WHERE '
          '${school == null ? 'school IS NULL' : 'school = ?'} '
          'AND user = ? AND role = ?',
          variables: [
            if (school != null) Variable.withString(school),
            Variable.withString(user),
            Variable.withString(role),
          ],
        )
        .get();
    if (results.isEmpty) return null;

    final r = results.first;
    final proto = ScopeInsert()
      ..user = r.read<String>('user')
      ..role = r.read<String>('role');
    final schoolVal = r.readNullable<String>('school');
    if (schoolVal != null) proto.school = schoolVal;

    return InsertData()..scope = proto;
  }

  // ---------------------------------------------------------------------------
  // 27: plans — PK: (id)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readPlanInsert(String rowKey) async {
    final row = await (_db.select(
      _db.plans,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = PlanInsert()
      ..id = row.id
      ..name = row.name
      ..amount = row.amount
      ..levels = row.levels
      ..status = row.status.index;
    if (row.description != null) proto.description = row.description!;
    if (row.features != null) proto.features = row.features!;

    return InsertData()..plan = proto;
  }

  // ---------------------------------------------------------------------------
  // 28: subscriptions — PK: (school, plan, year, term, student)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readSubscriptionInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.subscriptions)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.plan.equals(k[1]) &
                  t.year.equals(_parseInt(k[2])) &
                  t.term.equals(_parseInt(k[3])) &
                  t.student.equals(_parseInt(k[4])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = SubscriptionInsert()
      ..school = row.school
      ..plan = row.plan
      ..year = row.year
      ..term = row.term
      ..student = row.student
      ..discount = row.discount
      ..status = row.status.index;
    if (row.invoice != null) proto.invoice = row.invoice!;

    return InsertData()..subscription = proto;
  }

  // ---------------------------------------------------------------------------
  // 29: discounts — PK: (school, plan, year, term, grade)
  // ---------------------------------------------------------------------------

  Future<InsertData?> _readDiscountInsert(String rowKey) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.discounts)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.plan.equals(k[1]) &
                  t.year.equals(_parseInt(k[2])) &
                  t.term.equals(_parseInt(k[3])) &
                  t.grade.equals(_parseInt(k[4])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return InsertData()
      ..discount = (DiscountInsert()
        ..school = row.school
        ..plan = row.plan
        ..year = row.year
        ..term = row.term
        ..grade = row.grade
        ..amount = row.amount
        ..unit = row.unit.index);
  }

  // ===========================================================================
  // Update readers — produce UpdateData from local DB rows.
  // *Update messages contain only mutable fields. We set only the fields
  // whose bits are set in the coalesced `columns` bitmask. The server uses
  // `has*()` on the proto message to detect which fields were changed.
  //
  // Note: 5 tables (owners, enrollments, subjects, lessons, scopes) have
  // no *Update message — they are insert/delete only.
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // 0: users
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readUserUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = UserUpdate();
    if (_bit(columns, UsersColumn.phone.bit)) proto.phone = row.phone;
    if (_bit(columns, UsersColumn.email.bit) && row.email != null)
      proto.email = row.email!;
    if (_bit(columns, UsersColumn.name.bit)) proto.name = row.name;
    if (_bit(columns, UsersColumn.level.bit)) proto.level = row.level.index;
    if (_bit(columns, UsersColumn.status.bit)) proto.status = row.status.index;

    return UpdateData()..user = proto;
  }

  // ---------------------------------------------------------------------------
  // 1: schools
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readSchoolUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.schools,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = SchoolUpdate();
    if (_bit(columns, SchoolsColumn.name.bit)) proto.name = row.name;
    if (_bit(columns, SchoolsColumn.motto.bit) && row.motto != null)
      proto.motto = row.motto!;
    if (_bit(columns, SchoolsColumn.phone.bit) && row.phone != null)
      proto.phone = row.phone!;
    if (_bit(columns, SchoolsColumn.email.bit) && row.email != null)
      proto.email = row.email!;
    if (_bit(columns, SchoolsColumn.county.bit)) proto.county = row.county;
    if (_bit(columns, SchoolsColumn.domain.bit) && row.domain != null)
      proto.domain = row.domain!;
    if (_bit(columns, SchoolsColumn.established.bit) && row.established != null)
      proto.established = row.established!;
    if (_bit(columns, SchoolsColumn.status.bit))
      proto.status = row.status.index;

    return UpdateData()..school = proto;
  }

  // ---------------------------------------------------------------------------
  // 3: students
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readStudentUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.students)..where(
              (t) => t.school.equals(k[0]) & t.adm.equals(_parseInt(k[1])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = StudentUpdate();
    if (_bit(columns, StudentsColumn.user.bit) && row.user != null)
      proto.user = row.user!;
    if (_bit(columns, StudentsColumn.name.bit)) proto.name = row.name;
    if (_bit(columns, StudentsColumn.dob.bit) && row.dob != null)
      proto.dob = row.dob!;
    if (_bit(columns, StudentsColumn.gender.bit) && row.gender != null)
      proto.gender = row.gender!.index;
    if (_bit(columns, StudentsColumn.documents.bit) && row.documents != null)
      proto.documents = row.documents!;
    if (_bit(columns, StudentsColumn.admitted.bit) && row.admitted != null)
      proto.admitted = row.admitted!;
    if (_bit(columns, StudentsColumn.status.bit))
      proto.status = row.status.index;

    return UpdateData()..student = proto;
  }

  // ---------------------------------------------------------------------------
  // 4: guardians
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readGuardianUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.guardians)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.user.equals(k[1]) &
                  t.student.equals(_parseInt(k[2])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = GuardianUpdate();
    if (_bit(columns, GuardiansColumn.relationship.bit))
      proto.relationship = row.relationship.index;
    if (_bit(columns, GuardiansColumn.role.bit)) proto.role = row.role.index;

    return UpdateData()..guardian = proto;
  }

  // ---------------------------------------------------------------------------
  // 5: departments
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readDepartmentUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.departments)
              ..where((t) => t.school.equals(k[0]) & t.name.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = DepartmentUpdate();
    if (_bit(columns, DepartmentsColumn.description.bit) &&
        row.description != null) {
      proto.description = row.description!;
    }

    return UpdateData()..department = proto;
  }

  // ---------------------------------------------------------------------------
  // 6: teachers
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readTeacherUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.teachers)
              ..where((t) => t.school.equals(k[0]) & t.user.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = TeacherUpdate();
    if (_bit(columns, TeachersColumn.hired.bit) && row.hired != null)
      proto.hired = row.hired!;
    if (_bit(columns, TeachersColumn.role.bit) && row.role != null)
      proto.role = row.role!;
    if (_bit(columns, TeachersColumn.department.bit) && row.department != null)
      proto.department = row.department!;
    if (_bit(columns, TeachersColumn.status.bit))
      proto.status = row.status.index;

    return UpdateData()..teacher = proto;
  }

  // ---------------------------------------------------------------------------
  // 7: staff
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readStaffUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.staff)
              ..where((t) => t.school.equals(k[0]) & t.user.equals(k[1])))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = StaffUpdate();
    if (_bit(columns, StaffColumn.idnumber.bit) && row.idnumber != null)
      proto.idnumber = row.idnumber!;
    if (_bit(columns, StaffColumn.role.bit) && row.role != null)
      proto.role = row.role!;
    if (_bit(columns, StaffColumn.department.bit) && row.department != null)
      proto.department = row.department!;
    if (_bit(columns, StaffColumn.status.bit)) proto.status = row.status.index;

    return UpdateData()..staffMember = proto;
  }

  // ---------------------------------------------------------------------------
  // 8: terms
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readTermUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.terms)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = TermUpdate();
    if (_bit(columns, TermsColumn.start.bit)) proto.start = _toInt64(row.start);
    if (_bit(columns, TermsColumn.end.bit)) proto.end = _toInt64(row.end);

    return UpdateData()..term = proto;
  }

  // ---------------------------------------------------------------------------
  // 9: class_teachers
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readClassTeacherUpdate(
    String rowKey,
    int columns,
  ) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.classTeachers)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.teacher.equals(k[5]),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = ClassTeacherUpdate();
    // ClassTeachersColumn only has `end(0)`.
    if (_bit(columns, ClassTeachersColumn.end.bit) && row.end != null)
      proto.end = row.end!;

    return UpdateData()..classTeacher = proto;
  }

  // ---------------------------------------------------------------------------
  // 12: attendance
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readAttendanceUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.attendance)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.student.equals(_parseInt(k[5])) &
                  t.date.equals(_parseInt(k[6])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = AttendanceUpdate();
    if (_bit(columns, AttendanceColumn.status.bit))
      proto.status = row.status.value;

    return UpdateData()..attendance = proto;
  }

  // ---------------------------------------------------------------------------
  // 13: timetable
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readTimetableUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.timetable)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.year.equals(_parseInt(k[1])) &
                  t.term.equals(_parseInt(k[2])) &
                  t.grade.equals(_parseInt(k[3])) &
                  t.stream.equals(_parseInt(k[4])) &
                  t.day.equalsValue(DayOfWeek.values[_parseInt(k[5])]) &
                  t.subject.equals(_parseInt(k[6])) &
                  t.start.equals(_parseInt(k[7])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = TimetableUpdate();
    if (_bit(columns, TimetableColumn.teacher.bit)) proto.teacher = row.teacher;
    if (_bit(columns, TimetableColumn.end.bit)) proto.end = row.end;

    return UpdateData()..timetable = proto;
  }

  // ---------------------------------------------------------------------------
  // 15: exams
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readExamUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.exams,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = ExamUpdate();
    if (_bit(columns, ExamsColumn.stream.bit) && row.stream != null)
      proto.stream = row.stream!;
    if (_bit(columns, ExamsColumn.personalized.bit))
      proto.personalized = row.personalized;
    if (_bit(columns, ExamsColumn.type.bit)) proto.type = row.type.index;
    if (_bit(columns, ExamsColumn.start.bit)) proto.start = row.start;
    if (_bit(columns, ExamsColumn.end.bit)) proto.end = row.end;
    if (_bit(columns, ExamsColumn.teacher.bit)) proto.teacher = row.teacher;

    return UpdateData()..exam = proto;
  }

  // ---------------------------------------------------------------------------
  // 16: papers
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readPaperUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final school = k[0];
    final exam = k[1];
    final subject = _parseInt(k[2]);
    final paper = _parseIntNullable(k[3]);

    final results = await _db
        .customSelect(
          'SELECT * FROM papers WHERE school = ? AND exam = ? AND subject = ? '
          'AND ${paper == null ? 'paper IS NULL' : 'paper = ?'}',
          variables: [
            Variable.withString(school),
            Variable.withString(exam),
            Variable.withInt(subject),
            if (paper != null) Variable.withInt(paper),
          ],
        )
        .get();
    if (results.isEmpty) return null;

    final r = results.first;
    final proto = PaperUpdate();
    if (_bit(columns, PapersColumn.invigilator.bit))
      proto.invigilator = r.read<String>('invigilator');
    if (_bit(columns, PapersColumn.start.bit))
      proto.start = Int64(r.read<BigInt>('start').toInt());
    if (_bit(columns, PapersColumn.end.bit))
      proto.end = Int64(r.read<BigInt>('end').toInt());
    if (_bit(columns, PapersColumn.status.bit))
      proto.status = r.read<int>('status');

    return UpdateData()..paper = proto;
  }

  // ---------------------------------------------------------------------------
  // 17: grades
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readGradeUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final school = k[0];
    final exam = k[1];
    final student = _parseInt(k[2]);
    final subject = _parseInt(k[3]);
    final paper = _parseIntNullable(k[4]);

    final results = await _db
        .customSelect(
          'SELECT * FROM grades WHERE school = ? AND exam = ? AND student = ? '
          'AND subject = ? AND ${paper == null ? 'paper IS NULL' : 'paper = ?'}',
          variables: [
            Variable.withString(school),
            Variable.withString(exam),
            Variable.withInt(student),
            Variable.withInt(subject),
            if (paper != null) Variable.withInt(paper),
          ],
        )
        .get();
    if (results.isEmpty) return null;

    final r = results.first;
    final proto = GradeUpdate();
    if (_bit(columns, GradesColumn.score.bit))
      proto.score = r.read<double>('score');
    if (_bit(columns, GradesColumn.total.bit))
      proto.total = r.read<int>('total');

    return UpdateData()..grade = proto;
  }

  // ---------------------------------------------------------------------------
  // 18: fees
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readFeeUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.fees,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = FeeUpdate();
    if (_bit(columns, FeesColumn.title.bit)) proto.title = row.title;
    if (_bit(columns, FeesColumn.description.bit))
      proto.description = row.description;
    if (_bit(columns, FeesColumn.amount.bit)) proto.amount = row.amount;
    if (_bit(columns, FeesColumn.mandatory.bit))
      proto.mandatory = row.mandatory;
    if (_bit(columns, FeesColumn.due.bit)) proto.due = _toInt64(row.due);

    return UpdateData()..fee = proto;
  }

  // ---------------------------------------------------------------------------
  // 19: invoices
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readInvoiceUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.invoices,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = InvoiceUpdate();
    if (_bit(columns, InvoicesColumn.fee.bit) && row.fee != null)
      proto.fee = row.fee!;
    if (_bit(columns, InvoicesColumn.description.bit) &&
        row.description != null)
      proto.description = row.description!;
    if (_bit(columns, InvoicesColumn.amount.bit)) proto.amount = row.amount;
    if (_bit(columns, InvoicesColumn.status.bit))
      proto.status = row.status.index;
    if (_bit(columns, InvoicesColumn.due.bit) && row.due != null)
      proto.due = _toInt64(row.due!);

    return UpdateData()..invoice = proto;
  }

  // ---------------------------------------------------------------------------
  // 20: payments
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readPaymentUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.payments,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = PaymentUpdate();
    if (_bit(columns, PaymentsColumn.amount.bit)) proto.amount = row.amount;
    if (_bit(columns, PaymentsColumn.method.bit))
      proto.method = row.method.index;
    if (_bit(columns, PaymentsColumn.reference.bit) && row.reference != null)
      proto.reference = row.reference!;
    if (_bit(columns, PaymentsColumn.recorder.bit) && row.recorder != null)
      proto.recorder = row.recorder!;
    if (_bit(columns, PaymentsColumn.date.bit) && row.date != null)
      proto.date = row.date!;
    // PaymentsColumn has no `invoice` bit — invoice is not updatable after creation.

    return UpdateData()..payment = proto;
  }

  // ---------------------------------------------------------------------------
  // 21: announcements
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readAnnouncementUpdate(
    String rowKey,
    int columns,
  ) async {
    final row = await (_db.select(
      _db.announcements,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = AnnouncementUpdate();
    if (_bit(columns, AnnouncementsColumn.title.bit)) proto.title = row.title;
    if (_bit(columns, AnnouncementsColumn.content.bit))
      proto.content = row.content;
    if (_bit(columns, AnnouncementsColumn.grade.bit) && row.grade != null)
      proto.grade = row.grade!;
    if (_bit(columns, AnnouncementsColumn.stream.bit) && row.stream != null)
      proto.stream = row.stream!;
    if (_bit(columns, AnnouncementsColumn.audience.bit))
      proto.audience = row.audience;

    return UpdateData()..announcement = proto;
  }

  // ---------------------------------------------------------------------------
  // 22: mastery
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readMasteryUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.mastery)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.student.equals(_parseInt(k[1])) &
                  t.grade.equals(_parseInt(k[2])) &
                  t.subject.equals(_parseInt(k[3])) &
                  t.topic.equals(_parseInt(k[4])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = MasteryUpdate();
    if (_bit(columns, MasteryColumn.score.bit)) proto.score = row.score;

    return UpdateData()..mastery = proto;
  }

  // ---------------------------------------------------------------------------
  // 23: aiusage
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readAiUsageUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.aiUsage)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.student.equals(_parseInt(k[1])) &
                  t.year.equals(_parseInt(k[2])) &
                  t.term.equals(_parseInt(k[3])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = AiUsageUpdate();
    if (_bit(columns, AiusageColumn.allocated.bit))
      proto.allocated = row.allocated;
    if (_bit(columns, AiusageColumn.used.bit)) proto.used = row.used;

    return UpdateData()..aiUsage = proto;
  }

  // ---------------------------------------------------------------------------
  // 24: settings
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readSettingsUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.school.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = SettingsUpdate();
    if (_bit(columns, SettingsColumn.data.bit)) proto.data = row.data;
    if (_bit(columns, SettingsColumn.mpesa.bit) && row.mpesa != null)
      proto.mpesa = row.mpesa!;

    return UpdateData()..settings = proto;
  }

  // ---------------------------------------------------------------------------
  // 25: roles
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readRoleUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.roles,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = RoleUpdate();
    if (_bit(columns, RolesColumn.name.bit)) proto.name = row.name;
    if (_bit(columns, RolesColumn.description.bit) && row.description != null) {
      proto.description = row.description!;
    }
    if (_bit(columns, RolesColumn.permissions.bit)) {
      try {
        proto.permissions = base64Decode(row.permissions);
      } catch (_) {
        proto.permissions = utf8.encode(row.permissions);
      }
    }

    return UpdateData()..role = proto;
  }

  // ---------------------------------------------------------------------------
  // 27: plans
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readPlanUpdate(String rowKey, int columns) async {
    final row = await (_db.select(
      _db.plans,
    )..where((t) => t.id.equals(rowKey))).getSingleOrNull();
    if (row == null) return null;

    final proto = PlanUpdate();
    if (_bit(columns, PlansColumn.name.bit)) proto.name = row.name;
    if (_bit(columns, PlansColumn.description.bit) && row.description != null)
      proto.description = row.description!;
    if (_bit(columns, PlansColumn.amount.bit)) proto.amount = row.amount;
    if (_bit(columns, PlansColumn.levels.bit)) proto.levels = row.levels;
    if (_bit(columns, PlansColumn.status.bit)) proto.status = row.status.index;
    if (_bit(columns, PlansColumn.features.bit) && row.features != null)
      proto.features = row.features!;

    return UpdateData()..plan = proto;
  }

  // ---------------------------------------------------------------------------
  // 28: subscriptions
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readSubscriptionUpdate(
    String rowKey,
    int columns,
  ) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.subscriptions)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.plan.equals(k[1]) &
                  t.year.equals(_parseInt(k[2])) &
                  t.term.equals(_parseInt(k[3])) &
                  t.student.equals(_parseInt(k[4])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = SubscriptionUpdate();
    if (_bit(columns, SubscriptionsColumn.invoice.bit) && row.invoice != null)
      proto.invoice = row.invoice!;
    if (_bit(columns, SubscriptionsColumn.discount.bit))
      proto.discount = row.discount;
    if (_bit(columns, SubscriptionsColumn.status.bit))
      proto.status = row.status.index;

    return UpdateData()..subscription = proto;
  }

  // ---------------------------------------------------------------------------
  // 29: discounts
  // ---------------------------------------------------------------------------

  Future<UpdateData?> _readDiscountUpdate(String rowKey, int columns) async {
    final k = _parseKey(rowKey);
    final row =
        await (_db.select(_db.discounts)..where(
              (t) =>
                  t.school.equals(k[0]) &
                  t.plan.equals(k[1]) &
                  t.year.equals(_parseInt(k[2])) &
                  t.term.equals(_parseInt(k[3])) &
                  t.grade.equals(_parseInt(k[4])),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    final proto = DiscountUpdate();
    if (_bit(columns, DiscountsColumn.amount.bit)) proto.amount = row.amount;
    if (_bit(columns, DiscountsColumn.unit.bit)) proto.unit = row.unit.index;

    return UpdateData()..discount = proto;
  }
}

// =============================================================================
// Internal helper types
// =============================================================================

/// Grouping key for log coalescing — identifies a unique row across tables.
class _GroupKey {
  const _GroupKey(this.tbl, this.rowKey);
  final LogTable tbl;
  final String rowKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GroupKey && tbl == other.tbl && rowKey == other.rowKey;

  @override
  int get hashCode => Object.hash(tbl, rowKey);
}

/// Result of coalescing all log entries for a single `(tbl, rowKey)`.
class _CoalescedEntry {
  const _CoalescedEntry({
    required this.tbl,
    required this.rowKey,
    required this.op,
    required this.columns,
    required this.logIds,
  });

  final LogTable tbl;
  final String rowKey;
  final LogOperation op;
  final int? columns; // only meaningful for Update
  final List<int> logIds; // all original log IDs that were coalesced
}

/// A built [Mutation] proto alongside its metadata.
class _MutationWithMeta {
  const _MutationWithMeta({required this.mutation, required this.entry});
  final Mutation mutation;
  final _CoalescedEntry entry;
}

/// An invitation pair: a user Insert and a member Insert that reference it.
class _InvitationPair {
  const _InvitationPair({required this.userIndex, required this.memberIndex});
  final int userIndex;
  final int memberIndex;
}
