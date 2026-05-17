import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../core/permission_parser.dart';
import '../database/database.dart';
import '../database/tables/curriculum_subjects.dart';
import '../database/tables/enums.dart';
import '../database/tables/mpesa.dart';
import '../models/permissions.dart';
import '../proto/services/sync.pb.dart';

/// Receives [SyncDelta] proto messages from the server and writes them
/// directly to the local Drift database.
///
/// **Critical:** All writes bypass the DAO layer so that no rows are
/// inserted into the `logs` table. The sync engine must never log its
/// own incoming deltas — only user-initiated mutations are logged.
class DeltaWriter {
  DeltaWriter(this._db);
  final AppDatabase _db;

  /// Internal buffer for batching writes during bulk sync.
  final List<SyncDelta> _buffer = [];
  static const _batchSize = 100;

  /// Whether the internal buffer is currently empty.
  ///
  /// Used by the sync engine to determine when a flush just occurred
  /// (i.e. the buffer was drained inside [apply]), so it can persist
  /// the latest sequence number at that point.
  bool get bufferIsEmpty => _buffer.isEmpty;

  /// Apply a single delta. Buffers internally and flushes every
  /// [_batchSize] deltas for efficiency.
  Future<void> apply(SyncDelta delta) async {
    _buffer.add(delta);
    if (_buffer.length >= _batchSize) {
      await flush();
    }
  }

  /// Flush all buffered deltas to the database in a single transaction.
  ///
  /// Foreign key enforcement is temporarily disabled for the duration of the
  /// flush. The server streams deltas in `seq` order (chronological), NOT in
  /// FK-dependency order — so a `subjects` row referencing a `teachers` row
  /// may arrive before the teacher itself. Disabling FK checks lets the
  /// entire batch settle; once all deltas are applied the data is consistent.
  ///
  /// This mirrors the approach used by [AppDatabase.deleteAllData].
  /// Map from proto table index to SQLite table name, used to notify Drift's
  /// stream engine after a flush so that watch queries re-emit.
  static const _tableNames = <int, String>{
    1: 'users',
    2: 'schools',
    3: 'owners',
    4: 'students',
    5: 'guardians',
    6: 'departments',
    7: 'teachers',
    8: 'staff',
    9: 'terms',
    10: 'class_teachers',
    11: 'enrollments',
    12: 'subject_teachers',
    13: 'attendance',
    14: 'timetable',
    15: 'lessons',
    16: 'exams',
    17: 'papers',
    18: 'grades',
    19: 'fees',
    20: 'invoices',
    21: 'payments',
    22: 'announcements',
    23: 'mastery',
    24: 'aiusage',
    26: 'roles',
    27: 'scopes',
    28: 'plans',
    29: 'subscriptions',
    30: 'discounts',
    31: 'subjects',
    32: 'topics',
    33: 'streams',
    34: 'mpesa',
    36: 'scheme_pages',
    37: 'answer_pages',
    38: 'events',
    39: 'papers_v2',
    42: 'marking_queue',
  };

  /// Dependency-ordered table indices for flushing.
  ///
  /// Parent tables (e.g. `schools`) are listed before child tables that
  /// reference them (e.g. `teachers`, `owners`). This mirrors the server's
  /// `SNAPSHOT_TABLE_ORDER` and ensures that within a single flush batch,
  /// parent rows are always written before child rows — preventing a window
  /// where a child row exists in SQLite but its parent does not, which would
  /// cause reactive queries (like `MembershipsDao.watchMemberships`) to skip
  /// valid entries.
  static const _flushOrder = <int>[
    1,
    2,
    28,
    26,
    31,
    32,
    3,
    7,
    8,
    4,
    5,
    6,
    27,
    9,
    33,
    11,
    10,
    12,
    13,
    14,
    15,
    16,
    17,
    36,
    18,
    37,
    38,
    39,
    42,
    19,
    20,
    21,
    22,
    23,
    24,
    29,
    30,
    34,
  ];

  /// Lookup from table index → position in [_flushOrder].
  /// Tables not in the list get [_flushOrder.length] (sorted last).
  static final _flushPriority = <int, int>{
    for (var i = 0; i < _flushOrder.length; i++) _flushOrder[i]: i,
  };

  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<SyncDelta>.from(_buffer);
    _buffer.clear();

    // Sort by dependency order so parent tables (e.g. schools) are written
    // before child tables (e.g. teachers, owners) within the same batch.
    final fallback = _flushOrder.length;
    batch.sort(
      (a, b) => (_flushPriority[a.table] ?? fallback).compareTo(
        _flushPriority[b.table] ?? fallback,
      ),
    );

    final touchedTables = <int>{};
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        for (final delta in batch) {
          try {
            await _applySingle(delta);
            touchedTables.add(delta.table);
          } catch (e, st) {
            debugPrint(
              '[DeltaWriter] ⚠ Error applying delta: '
              'table=${delta.table}, op=${delta.operation}, '
              'key=${delta.rowKey}, hasData=${delta.hasData()} — $e',
            );
            debugPrint('[DeltaWriter]   stack: $st');
            // Continue with remaining deltas — don't let one bad row
            // kill the entire batch.
          }
        }
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }

    // Notify Drift's stream engine about tables modified via customStatement.
    // Without this, watch queries (e.g. watchGradesForPaper) would NOT re-emit
    // because Drift doesn't track raw SQL writes for stream invalidation.
    if (touchedTables.isNotEmpty) {
      final updates = <TableUpdate>{};
      for (final idx in touchedTables) {
        final name = _tableNames[idx];
        if (name != null) {
          updates.add(TableUpdate(name));
        } else {
          debugPrint(
            '[DeltaWriter] ⚠ Table index $idx has no entry in _tableNames — '
            'notifyUpdates will NOT fire for this table',
          );
        }
      }
      if (updates.isNotEmpty) {
        debugPrint(
          '[DeltaWriter] 🔔 notifyUpdates: '
          '${updates.map((u) => u.table).toList()}',
        );
        _db.notifyUpdates(updates);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _parseKey(String rowKey) => rowKey.split('|');

  int _parseInt(String s) => int.parse(s);

  int? _parseIntNullable(String s) =>
      (s.isEmpty || s == 'null') ? null : int.parse(s);

  String? _parseStringNullable(String s) =>
      (s.isEmpty || s == 'null') ? null : s;

  /// Returns the current time as seconds since Unix epoch, as BigInt.
  /// Used as a local approximation for server-managed timestamps.
  BigInt _now() => BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

  // ---------------------------------------------------------------------------
  // Core dispatch
  // ---------------------------------------------------------------------------

  Future<void> _applySingle(SyncDelta delta) async {
    // operation: 0=Insert, 1=Update, 2=Delete
    // table: 1-based proto oneof field number (user=1, school=2, ..., discount=30)
    switch (delta.table) {
      case 1:
        await _applyUsers(delta);
      case 2:
        await _applySchools(delta);
      case 3:
        await _applyOwners(delta);
      case 4:
        await _applyStudents(delta);
      case 5:
        await _applyGuardians(delta);
      case 6:
        await _applyDepartments(delta);
      case 7:
        await _applyTeachers(delta);
      case 8:
        await _applyStaff(delta);
      case 9:
        await _applyTerms(delta);
      case 10:
        await _applyClassTeachers(delta);
      case 11:
        await _applyEnrollments(delta);
      case 12:
        await _applySubjectTeachers(delta);
      case 13:
        await _applyAttendance(delta);
      case 14:
        await _applyTimetable(delta);
      case 15:
        await _applyLessons(delta);
      case 16:
        await _applyExams(delta);
      case 17:
        await _applyPapers(delta);
      case 18:
        await _applyGrades(delta);
      case 19:
        await _applyFees(delta);
      case 20:
        await _applyInvoices(delta);
      case 21:
        await _applyPayments(delta);
      case 22:
        await _applyAnnouncements(delta);
      case 23:
        await _applyMastery(delta);
      case 24:
        await _applyAiUsage(delta);
      case 25:
        // Settings table removed in schema v2 — ignore gracefully.
        debugPrint(
          '[DeltaWriter] ⚠ Received delta for removed settings table '
          '(table=25) — SKIPPED',
        );
      case 26:
        await _applyRoles(delta);
      case 27:
        await _applyScopes(delta);
      case 28:
        await _applyPlans(delta);
      case 29:
        await _applySubscriptions(delta);
      case 30:
        await _applyDiscounts(delta);
      case 31:
        await _applySubjectCatalog(delta);
      case 32:
        await _applyTopic(delta);
      case 33:
        await _applyStream(delta);
      case 34:
        await _applyMpesa(delta);
      case 35:
        // ExamGrades table removed — grade/stream moved to papers.
        debugPrint(
          '[DeltaWriter] ⚠ Received delta for removed exam_grades table '
          '(table=35) — SKIPPED',
        );
      case 36:
        await _applySchemePages(delta);
      case 37:
        await _applyAnswerPages(delta);
      case 38:
        await _applyEvents(delta);
      case 39:
        await _applyPapersV2(delta);
      case 40:
        // paper_schedules — not yet supported locally
        debugPrint('[DeltaWriter] table=40 (paper_schedules) — SKIPPED (NYI)');
      case 41:
        // taught_topics — not yet supported locally
        debugPrint('[DeltaWriter] table=41 (taught_topics) — SKIPPED (NYI)');
      case 42:
        await _applyMarkingQueue(delta);
      default:
        debugPrint(
          '[DeltaWriter] ⚠ UNKNOWN table=${delta.table}, '
          'op=${delta.operation}, key=${delta.rowKey} — SKIPPED',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // 1: users  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyUsers(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.users,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.user;
    final now = _now();

    // Before upserting, check if another user row (different id) already holds
    // this phone number. This can happen when the server DB is reset and the
    // same phone is assigned a new user id. Drift's insertOnConflictUpdate
    // only handles PK conflicts — the UNIQUE(phone) constraint would fire
    // otherwise. Deleting the stale row lets FK cascades clean up all
    // relationships that pointed to the old id.
    final existing =
        await (_db.select(_db.users)..where(
              (t) =>
                  t.phone.equals(row.phone) & t.id.equals(delta.rowKey).not(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.delete(
        _db.users,
      )..where((t) => t.id.equals(existing.id))).go();
    }

    await _db
        .into(_db.users)
        .insertOnConflictUpdate(
          UsersCompanion(
            id: Value(delta.rowKey),
            phone: Value(row.phone),
            email: Value(row.hasEmail() ? row.email : null),
            name: Value(row.name),
            level: Value(UserLevel.values[row.level]),
            status: Value(UserStatus.values[row.status]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 2: schools  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applySchools(SyncDelta delta) async {
    if (delta.operation == 2) {
      debugPrint('[DeltaWriter] 🏫 DELETE school: id=${delta.rowKey}');
      await (_db.delete(
        _db.schools,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    debugPrint(
      '[DeltaWriter] 🏫 UPSERT school: id=${delta.rowKey}, '
      'name=${delta.data.school.name}, op=${delta.operation}',
    );
    final row = delta.data.school;
    final now = _now();
    await _db
        .into(_db.schools)
        .insertOnConflictUpdate(
          SchoolsCompanion(
            id: Value(delta.rowKey),
            name: Value(row.name),
            motto: Value(row.hasMotto() ? row.motto : null),
            phone: Value(row.hasPhone() ? row.phone : null),
            email: Value(row.hasEmail() ? row.email : null),
            county: Value(row.county),
            domain: Value(row.hasDomain() ? row.domain : null),
            established: Value(row.hasEstablished() ? row.established : null),
            status: Value(SchoolStatus.values[row.status]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 3: owners  — PK: (school, user)  — rowKey: "{school}|{user}"
  //    Only has `created` (no `updated`).
  // ---------------------------------------------------------------------------

  Future<void> _applyOwners(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(
        _db.owners,
      )..where((t) => t.school.equals(k[0]) & t.user.equals(k[1]))).go();
      return;
    }
    final now = _now();
    await _db
        .into(_db.owners)
        .insertOnConflictUpdate(
          OwnersCompanion(
            school: Value(k[0]),
            user: Value(k[1]),
            created: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 4: students  — PK: (school, adm)  — rowKey: "{school}|{adm}"
  // ---------------------------------------------------------------------------

  Future<void> _applyStudents(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.students)..where(
            (t) => t.school.equals(k[0]) & t.adm.equals(_parseInt(k[1])),
          ))
          .go();
      return;
    }
    final row = delta.data.student;
    final now = _now();
    await _db
        .into(_db.students)
        .insertOnConflictUpdate(
          StudentsCompanion(
            school: Value(k[0]),
            adm: Value(_parseInt(k[1])),
            user: Value(row.hasUser() ? row.user : null),
            name: Value(row.name),
            dob: Value(row.hasDob() ? row.dob : null),
            gender: Value(row.hasGender() ? Gender.values[row.gender] : null),
            documents: Value(row.hasDocuments() ? row.documents : null),
            admitted: Value(row.hasAdmitted() ? row.admitted : null),
            status: Value(StudentStatus.values[row.status]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 5: guardians  — PK: (school, user, student)  — rowKey: "{school}|{user}|{student}"
  // ---------------------------------------------------------------------------

  Future<void> _applyGuardians(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.guardians)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.user.equals(k[1]) &
                t.student.equals(_parseInt(k[2])),
          ))
          .go();
      return;
    }
    final row = delta.data.guardian;
    final now = _now();
    await _db
        .into(_db.guardians)
        .insertOnConflictUpdate(
          GuardiansCompanion(
            school: Value(k[0]),
            user: Value(k[1]),
            student: Value(_parseInt(k[2])),
            relationship: Value(GuardianRelationship.values[row.relationship]),
            role: Value(GuardianRole.values[row.role]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 6: departments  — PK: (school, name)  — rowKey: "{school}|{name}"
  // ---------------------------------------------------------------------------

  Future<void> _applyDepartments(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(
        _db.departments,
      )..where((t) => t.school.equals(k[0]) & t.name.equals(k[1]))).go();
      return;
    }
    final row = delta.data.department;
    final now = _now();
    await _db
        .into(_db.departments)
        .insertOnConflictUpdate(
          DepartmentsCompanion(
            school: Value(k[0]),
            name: Value(k[1]),
            description: Value(row.hasDescription() ? row.description : null),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 7: teachers  — PK: (school, user)  — rowKey: "{school}|{user}"
  // ---------------------------------------------------------------------------

  Future<void> _applyTeachers(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(
        _db.teachers,
      )..where((t) => t.school.equals(k[0]) & t.user.equals(k[1]))).go();
      return;
    }
    final row = delta.data.teacher;
    final now = _now();
    await _db
        .into(_db.teachers)
        .insertOnConflictUpdate(
          TeachersCompanion(
            school: Value(k[0]),
            user: Value(k[1]),
            hired: Value(row.hasHired() ? row.hired : null),
            role: Value(row.hasRole() ? row.role : null),
            department: Value(row.hasDepartment() ? row.department : null),
            status: Value(TeacherStatus.values[row.status]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 8: staff  — PK: (school, user)  — rowKey: "{school}|{user}"
  // ---------------------------------------------------------------------------

  Future<void> _applyStaff(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(
        _db.staff,
      )..where((t) => t.school.equals(k[0]) & t.user.equals(k[1]))).go();
      return;
    }
    final row = delta.data.staffMember;
    final now = _now();
    await _db
        .into(_db.staff)
        .insertOnConflictUpdate(
          StaffCompanion(
            school: Value(k[0]),
            user: Value(k[1]),
            idnumber: Value(row.hasIdnumber() ? row.idnumber : null),
            role: Value(row.hasRole() ? row.role : null),
            department: Value(row.hasDepartment() ? row.department : null),
            status: Value(StaffStatus.values[row.status]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 9: terms  — PK: (school, year, term)  — rowKey: "{school}|{year}|{term}"
  // ---------------------------------------------------------------------------

  Future<void> _applyTerms(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.terms)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.year.equals(_parseInt(k[1])) &
                t.term.equals(_parseInt(k[2])),
          ))
          .go();
      return;
    }
    final row = delta.data.term;
    final now = _now();
    final school = k[0];
    final year = _parseInt(k[1]);
    final term = _parseInt(k[2]);

    // The terms_no_overlap BEFORE INSERT trigger checks the terms table itself
    // for any row with overlapping dates. When upserting a term that already
    // exists locally (same PK, same dates), the trigger finds the existing row
    // and aborts with "term dates overlap". Delete the local row first so the
    // trigger sees a clean table, then insert the server's authoritative row.
    await (_db.delete(_db.terms)..where(
          (t) =>
              t.school.equals(school) &
              t.year.equals(year) &
              t.term.equals(term),
        ))
        .go();
    await _db
        .into(_db.terms)
        .insert(
          TermsCompanion(
            school: Value(school),
            year: Value(year),
            term: Value(term),
            start: Value(BigInt.from(row.start.toInt())),
            end: Value(BigInt.from(row.end.toInt())),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 10: class_teachers  — PK: (school, year, term, grade, stream, teacher)
  //     rowKey: "{school}|{year}|{term}|{grade}|{stream}|{teacher}"
  //     Only has `created` (no `updated`).
  // ---------------------------------------------------------------------------

  Future<void> _applyClassTeachers(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.classTeachers)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.year.equals(_parseInt(k[1])) &
                t.term.equals(_parseInt(k[2])) &
                t.grade.equals(_parseInt(k[3])) &
                t.stream.equals(_parseInt(k[4])) &
                t.teacher.equals(k[5]),
          ))
          .go();
      return;
    }
    final row = delta.data.classTeacher;
    final now = _now();
    await _db
        .into(_db.classTeachers)
        .insertOnConflictUpdate(
          ClassTeachersCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
            grade: Value(_parseInt(k[3])),
            stream: Value(_parseInt(k[4])),
            teacher: Value(k[5]),
            start: Value(row.start),
            end: Value(row.hasEnd() ? row.end : null),
            created: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 11: enrollments  — PK: (school, year, term, grade, stream, student)
  //     rowKey: "{school}|{year}|{term}|{grade}|{stream}|{student}"
  //     Only has `created` (no `updated`).
  // ---------------------------------------------------------------------------

  Future<void> _applyEnrollments(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.enrollments)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.year.equals(_parseInt(k[1])) &
                t.term.equals(_parseInt(k[2])) &
                t.grade.equals(_parseInt(k[3])) &
                t.stream.equals(_parseInt(k[4])) &
                t.student.equals(_parseInt(k[5])),
          ))
          .go();
      return;
    }
    final now = _now();
    await _db
        .into(_db.enrollments)
        .insertOnConflictUpdate(
          EnrollmentsCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
            grade: Value(_parseInt(k[3])),
            stream: Value(_parseInt(k[4])),
            student: Value(_parseInt(k[5])),
            created: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 12: subjects  — PK: (school, year, term, grade, stream, subject)
  //     rowKey: "{school}|{year}|{term}|{grade}|{stream}|{subject}"
  //     Only has `created` (no `updated`).
  // ---------------------------------------------------------------------------

  Future<void> _applySubjectTeachers(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    debugPrint(
      '[DeltaWriter] _applySubjectTeachers — op=${delta.operation}, '
      'key=${delta.rowKey}, parts=${k.length}, '
      'hasData=${delta.hasData()}, '
      'hasSubjectTeacher=${delta.hasData() ? delta.data.hasSubjectTeacher() : "N/A"}',
    );
    if (delta.operation == 2) {
      await (_db.delete(_db.subjectTeachers)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.year.equals(_parseInt(k[1])) &
                t.term.equals(_parseInt(k[2])) &
                t.grade.equals(_parseInt(k[3])) &
                t.stream.equals(_parseInt(k[4])) &
                t.subject.equals(_parseInt(k[5])),
          ))
          .go();
      return;
    }
    if (!delta.hasData() || !delta.data.hasSubjectTeacher()) {
      debugPrint(
        '[DeltaWriter] ⚠ _applySubjectTeachers — delta has NO subjectTeacher data! '
        'hasData=${delta.hasData()}',
      );
      return;
    }
    final row = delta.data.subjectTeacher;
    debugPrint(
      '[DeltaWriter] _applySubjectTeachers — inserting: '
      'school=${k[0]}, year=${k[1]}, term=${k[2]}, '
      'grade=${k[3]}, stream=${k[4]}, subject=${k[5]}, '
      'teacher=${row.teacher}',
    );
    final now = _now();
    await _db
        .into(_db.subjectTeachers)
        .insertOnConflictUpdate(
          SubjectTeachersCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
            grade: Value(_parseInt(k[3])),
            stream: Value(_parseInt(k[4])),
            subject: Value(_parseInt(k[5])),
            teacher: Value(row.teacher),
            created: Value(now),
          ),
        );
    debugPrint('[DeltaWriter] _applySubjectTeachers — INSERT OK');
  }

  // ---------------------------------------------------------------------------
  // 13: attendance  — PK: (school, year, term, grade, stream, student, date)
  //     rowKey: "{school}|{year}|{term}|{grade}|{stream}|{student}|{date}"
  // ---------------------------------------------------------------------------

  Future<void> _applyAttendance(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.attendance)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.year.equals(_parseInt(k[1])) &
                t.term.equals(_parseInt(k[2])) &
                t.grade.equals(_parseInt(k[3])) &
                t.stream.equals(_parseInt(k[4])) &
                t.student.equals(_parseInt(k[5])) &
                t.date.equals(_parseInt(k[6])),
          ))
          .go();
      return;
    }
    final row = delta.data.attendance;
    final now = _now();
    await _db
        .into(_db.attendance)
        .insertOnConflictUpdate(
          AttendanceCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
            grade: Value(_parseInt(k[3])),
            stream: Value(_parseInt(k[4])),
            student: Value(_parseInt(k[5])),
            date: Value(_parseInt(k[6])),
            status: Value(
              AttendanceStatus.values.firstWhere((e) => e.value == row.status),
            ),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 14: timetable  — PK: (school, year, term, grade, stream, subject, day, start)
  //     rowKey: "{school}|{year}|{term}|{grade}|{stream}|{subject}|{day}|{start}"
  //     k[0]=school  k[1]=year  k[2]=term  k[3]=grade  k[4]=stream
  //     k[5]=subject  k[6]=day (DayOfWeek.index)  k[7]=start
  // ---------------------------------------------------------------------------

  Future<void> _applyTimetable(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.timetable)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.year.equals(_parseInt(k[1])) &
                t.term.equals(_parseInt(k[2])) &
                t.grade.equals(_parseInt(k[3])) &
                t.stream.equals(_parseInt(k[4])) &
                t.subject.equals(_parseInt(k[5])) &
                t.day.equals(_parseInt(k[6])) &
                t.start.equals(_parseInt(k[7])),
          ))
          .go();
      return;
    }
    final row = delta.data.timetable;
    final now = _now();
    await _db
        .into(_db.timetable)
        .insertOnConflictUpdate(
          TimetableCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
            grade: Value(_parseInt(k[3])),
            stream: Value(_parseInt(k[4])),
            subject: Value(_parseInt(k[5])),
            teacher: Value(row.teacher),
            day: Value(DayOfWeek.values[_parseInt(k[6])]),
            start: Value(_parseInt(k[7])),
            end: Value(row.end),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 15: lessons  — PK: (school, year, term, grade, stream, date, subject, teacher)
  //     rowKey: "{school}|{year}|{term}|{grade}|{stream}|{date}|{subject}|{teacher}"
  // ---------------------------------------------------------------------------

  Future<void> _applyLessons(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.lessons)..where(
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
          .go();
      return;
    }
    final now = _now();
    await _db
        .into(_db.lessons)
        .insertOnConflictUpdate(
          LessonsCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
            grade: Value(_parseInt(k[3])),
            stream: Value(_parseInt(k[4])),
            date: Value(_parseInt(k[5])),
            subject: Value(_parseInt(k[6])),
            teacher: Value(k[7]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 16: exams  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyExams(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.exams,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.exam;
    final now = _now();
    await _db
        .into(_db.exams)
        .insertOnConflictUpdate(
          ExamsCompanion(
            id: Value(delta.rowKey),
            school: Value(row.school),
            name: Value(row.name),
            year: Value(row.year),
            term: Value(row.term),
            personalized: Value(row.personalized),
            type: Value(ExamType.values[row.type]),
            start: Value(row.start),
            end: Value(row.end),
            teacher: Value(row.teacher),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 17: papers  — PK: (school, exam, subject, paper)  [paper nullable]
  //     rowKey: "{school}|{exam}|{subject}|{paper}"
  //
  //     SQLite NULL handling: ON CONFLICT (school, exam, subject, paper) does
  //     NOT match existing rows when paper IS NULL because NULL != NULL in SQL.
  //     The INSERT falls through to a fresh row, which then hits the partial
  //     unique index papers_subject_null_idx(school, exam, subject) WHERE
  //     paper IS NULL → UNIQUE constraint failed.
  //
  //     Fix: when paper is NULL we DELETE the existing row first (using
  //     IS NULL), then INSERT unconditionally. When paper is non-NULL the
  //     standard ON CONFLICT upsert works correctly.
  // ---------------------------------------------------------------------------

  Future<void> _applyPapers(SyncDelta delta) async {
    // rowKey format: "{school}|{exam}|{subject}|{paper}|{grade}|{stream}"
    // paper is empty-string when NULL; stream is empty-string when NULL.
    // Full composite PK: (school, exam, subject, paper, grade, stream) — all 6
    // columns must be used in every DELETE / ON CONFLICT clause.
    final k = _parseKey(delta.rowKey);
    final paperVal = _parseIntNullable(k[3]);
    final gradeVal = _parseInt(k[4]);
    final streamVal = _parseIntNullable(k[5]);

    if (delta.operation == 2) {
      // Delete exactly one row — must match all 6 PK columns.
      await _db.customStatement(
        'DELETE FROM papers WHERE school = ? AND exam = ? AND subject = ?'
        ' AND paper ${paperVal == null ? 'IS NULL' : '= ?'}'
        ' AND grade = ?'
        ' AND stream ${streamVal == null ? 'IS NULL' : '= ?'}',
        [k[0], k[1], _parseInt(k[2]), ?paperVal, gradeVal, ?streamVal],
      );
      return;
    }
    final row = delta.data.paper;
    final now = _now();
    final topicVal = row.hasTopic() ? row.topic : null;
    // streamVal is already parsed from the key above; cross-check with payload.
    // (They must agree — the key is the authoritative PK source.)

    if (paperVal == null) {
      // NULL paper — ON CONFLICT cannot match NULLs in SQLite, so we use
      // delete-then-insert. The delete must scope to the exact (grade, stream)
      // to avoid wiping sibling rows that share school/exam/subject/paper=NULL
      // but belong to a different stream.
      await _db.customStatement(
        'DELETE FROM papers WHERE school = ? AND exam = ? AND subject = ?'
        ' AND paper IS NULL'
        ' AND grade = ?'
        ' AND stream ${streamVal == null ? 'IS NULL' : '= ?'}',
        [k[0], k[1], _parseInt(k[2]), gradeVal, ?streamVal],
      );
      final timeAllowedVal = row.hasTimeAllowedMinutes()
          ? row.timeAllowedMinutes
          : null;
      final instructionsVal = row.hasInstructions() ? row.instructions : null;
      await _db.customStatement(
        'INSERT INTO papers (school, exam, subject, paper, topic, invigilator, start, "end", status, grade, stream, time_allowed_minutes, custom_instructions, created, updated)'
        ' VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          k[0],
          k[1],
          _parseInt(k[2]),
          topicVal,
          row.invigilator,
          row.start.toInt(),
          row.end.toInt(),
          row.status,
          gradeVal,
          streamVal,
          timeAllowedVal,
          instructionsVal,
          now.toInt(),
          now.toInt(),
        ],
      );
    } else {
      // Non-NULL paper — use ON CONFLICT with the full 6-column PK so that
      // papers for different (grade, stream) combinations are never confused.
      // Previously this only listed 4 columns, causing the upsert to match
      // the wrong row when multiple streams share the same (subject, paper).
      final timeAllowedVal = row.hasTimeAllowedMinutes()
          ? row.timeAllowedMinutes
          : null;
      final instructionsVal = row.hasInstructions() ? row.instructions : null;
      await _db.customStatement(
        'INSERT INTO papers (school, exam, subject, paper, topic, invigilator, start, "end", status, grade, stream, time_allowed_minutes, custom_instructions, created, updated)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        ' ON CONFLICT (school, exam, subject, paper, grade, stream) DO UPDATE SET'
        ' topic = excluded.topic,'
        ' invigilator = excluded.invigilator,'
        ' start = excluded.start,'
        ' "end" = excluded."end",'
        ' status = excluded.status,'
        ' time_allowed_minutes = excluded.time_allowed_minutes,'
        ' custom_instructions = excluded.custom_instructions,'
        ' created = excluded.created,'
        ' updated = excluded.updated',
        [
          k[0],
          k[1],
          _parseInt(k[2]),
          paperVal,
          topicVal,
          row.invigilator,
          row.start.toInt(),
          row.end.toInt(),
          row.status,
          gradeVal,
          streamVal,
          timeAllowedVal,
          instructionsVal,
          now.toInt(),
          now.toInt(),
        ],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 18: grades  — PK: (school, exam, student, subject, paper)  [paper nullable]
  //     rowKey: "{school}|{exam}|{student}|{subject}|{paper}"
  // ---------------------------------------------------------------------------

  Future<void> _applyGrades(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    final paperVal = _parseIntNullable(k[4]);

    // Delete any existing row matching the full PK first.
    // This uses a unified delete for both NULL and non-NULL paper.
    await _db.customStatement(
      'DELETE FROM grades WHERE school = ? AND exam = ? AND student = ? AND subject = ?'
      ' AND paper ${paperVal == null ? 'IS NULL' : '= ?'}',
      [
        k[0],
        k[1],
        _parseInt(k[2]),
        _parseInt(k[3]),
        if (paperVal != null) paperVal,
      ],
    );

    if (delta.operation == 2) return; // Pure delete — we're done.

    // Insert the server's authoritative row.
    //
    // We always delete-then-insert (instead of INSERT ON CONFLICT) because the
    // `grades_enrollment_check` BEFORE INSERT trigger queries the enrollments,
    // exams, and papers tables for validation. With INSERT ON CONFLICT, SQLite
    // fires the trigger BEFORE evaluating the ON CONFLICT clause, so the
    // trigger sees the existing row and may fail (e.g. if enrollment data
    // hasn't settled in this batch yet). Delete-then-insert avoids this:
    // the old row is gone, so the trigger validates a clean insert.
    final row = delta.data.grade;
    final now = _now();

    await _db.customStatement(
      'INSERT INTO grades (school, exam, student, subject, paper, score, total, created, updated)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        k[0],
        k[1],
        _parseInt(k[2]),
        _parseInt(k[3]),
        paperVal, // NULL is fine — SQLite accepts it as a positional param
        row.score,
        row.total,
        now.toInt(),
        now.toInt(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 19: fees  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyFees(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.fees,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.fee;
    final now = _now();
    await _db
        .into(_db.fees)
        .insertOnConflictUpdate(
          FeesCompanion(
            id: Value(delta.rowKey),
            school: Value(row.school),
            year: Value(row.year),
            term: Value(row.term),
            grade: Value(row.grade),
            title: Value(row.title),
            description: Value(row.description),
            amount: Value(row.amount),
            mandatory: Value(row.mandatory),
            due: Value(BigInt.from(row.due.toInt())),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 20: invoices  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyInvoices(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.invoices,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.invoice;
    final now = _now();
    await _db
        .into(_db.invoices)
        .insertOnConflictUpdate(
          InvoicesCompanion(
            id: Value(delta.rowKey),
            school: Value(row.school),
            year: Value(row.year),
            term: Value(row.term),
            fee: Value(row.hasFee() ? row.fee : null),
            description: Value(row.hasDescription() ? row.description : null),
            student: Value(row.student),
            amount: Value(row.amount),
            status: Value(InvoiceStatus.values[row.status]),
            due: Value(row.hasDue() ? BigInt.from(row.due.toInt()) : null),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 21: payments  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyPayments(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.payments,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.payment;
    final now = _now();
    await _db
        .into(_db.payments)
        .insertOnConflictUpdate(
          PaymentsCompanion(
            id: Value(delta.rowKey),
            invoice: Value(row.hasInvoice() ? row.invoice : null),
            school: Value(row.hasSchool() ? row.school : null),
            student: Value(row.hasStudent() ? row.student : null),
            amount: Value(row.amount),
            method: Value(PaymentMethod.values[row.method]),
            reference: Value(row.hasReference() ? row.reference : null),
            recorder: Value(row.hasRecorder() ? row.recorder : null),
            date: Value(row.hasDate() ? row.date : null),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 22: announcements  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyAnnouncements(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.announcements,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.announcement;
    final now = _now();
    await _db
        .into(_db.announcements)
        .insertOnConflictUpdate(
          AnnouncementsCompanion(
            id: Value(delta.rowKey),
            school: Value(row.school),
            title: Value(row.title),
            content: Value(row.content),
            grade: Value(row.hasGrade() ? row.grade : null),
            stream: Value(row.hasStream() ? row.stream : null),
            audience: Value(row.audience),
            author: Value(row.hasAuthor() ? row.author : null),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 23: mastery  — PK: (school, student, subject, topic)
  //     rowKey: "{school}|{student}|{subject}|{topic}"
  // ---------------------------------------------------------------------------

  Future<void> _applyMastery(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.mastery)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.student.equals(_parseInt(k[1])) &
                t.subject.equals(_parseInt(k[2])) &
                t.topic.equals(_parseInt(k[3])),
          ))
          .go();
      return;
    }
    final row = delta.data.mastery;
    final now = _now();
    await _db
        .into(_db.mastery)
        .insertOnConflictUpdate(
          MasteryCompanion(
            school: Value(k[0]),
            student: Value(_parseInt(k[1])),
            subject: Value(row.subject),
            topic: Value(row.topic),
            score: Value(row.score),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 24: aiusage  — PK: (school, student, year, term)
  //     rowKey: "{school}|{student}|{year}|{term}"
  // ---------------------------------------------------------------------------

  Future<void> _applyAiUsage(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.aiUsage)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.student.equals(_parseInt(k[1])) &
                t.year.equals(_parseInt(k[2])) &
                t.term.equals(_parseInt(k[3])),
          ))
          .go();
      return;
    }
    final row = delta.data.aiUsage;
    final now = _now();
    await _db
        .into(_db.aiUsage)
        .insertOnConflictUpdate(
          AiUsageCompanion(
            school: Value(k[0]),
            student: Value(_parseInt(k[1])),
            year: Value(_parseInt(k[2])),
            term: Value(_parseInt(k[3])),
            allocated: Value(row.allocated),
            used: Value(row.used),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 25: settings — REMOVED in schema v2. Handler retained as no-op so that
  //     old server deltas don't crash if they arrive during a migration window.
  // ---------------------------------------------------------------------------

  @Deprecated('Settings table removed in schema v2')
  // ignore: unused_element
  Future<void> _applySettings(SyncDelta delta) async {
    debugPrint(
      '[DeltaWriter] ⚠ _applySettings called — settings table was removed '
      'in schema v2. Delta discarded. key=${delta.rowKey}',
    );
  }

  // ---------------------------------------------------------------------------
  // 26: roles  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  /// Decodes the protobuf `bytes` field for role permissions back to a JSON
  /// string suitable for storage in the Drift `roles.permissions` text column.
  ///
  /// Converts proto permission bytes into the canonical binary blob format
  /// (`[resource_id: u8, actions_lo: u8, actions_hi: u8]` triplets) for
  /// storage in the `roles.permissions` blob column.
  ///
  /// The server may send bytes in two formats:
  /// 1. Canonical binary blob — store as-is.
  /// 2. UTF-8-encoded JSON (legacy) — parse via [parsePermissions] then
  ///    re-encode to blob via [Permissions.toBlob].
  Uint8List _convertPermissionsToBlob(List<int> bytes) {
    if (bytes.isEmpty) return Uint8List(0);

    final blob = Uint8List.fromList(bytes);

    // Try canonical binary blob first
    final fromBlob = Permissions.fromBlob(blob);
    if (fromBlob.isNotEmpty) return blob;

    // Fallback: try UTF-8 JSON decode (legacy server format)
    try {
      final json = utf8.decode(bytes);
      // ignore: deprecated_member_use
      final parsed = parsePermissions(json);
      if (parsed.isNotEmpty) return Permissions(parsed).toBlob();
    } catch (_) {
      // Not valid UTF-8 — unknown format
    }

    return Uint8List(0);
  }

  Future<void> _applyRoles(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.roles,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.role;
    final now = _now();
    await _db
        .into(_db.roles)
        .insertOnConflictUpdate(
          RolesCompanion(
            id: Value(delta.rowKey),
            school: Value(row.hasSchool() ? row.school : null),
            name: Value(row.name),
            description: Value(row.hasDescription() ? row.description : null),
            permissions: Value(_convertPermissionsToBlob(row.permissions)),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 27: scopes  — PK: (school, user, role)  [school nullable]
  //     rowKey: "{school}|{user}|{role}"  — school may be "null"
  //     Only has `created` (no `updated`).
  // ---------------------------------------------------------------------------

  Future<void> _applyScopes(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    final school = _parseStringNullable(k[0]);
    if (delta.operation == 2) {
      await _db.customStatement(
        'DELETE FROM scopes WHERE school ${school == null ? 'IS NULL' : '= ?'}'
        ' AND user = ? AND role = ?',
        [?school, k[1], k[2]],
      );
      return;
    }
    final now = _now();
    // scopes has a nullable PK column (school), so we must use raw SQL.
    // SQLite NULL handling: ON CONFLICT (school, user, role) does NOT match
    // existing rows when school IS NULL because NULL != NULL in SQL.
    // Fix: when school is NULL we delete-then-insert; otherwise standard upsert.
    if (school == null) {
      await _db.customStatement(
        'DELETE FROM scopes WHERE school IS NULL AND user = ? AND role = ?',
        [k[1], k[2]],
      );
      await _db.customStatement(
        'INSERT INTO scopes (school, user, role, created)'
        ' VALUES (NULL, ?, ?, ?)',
        [k[1], k[2], now.toInt()],
      );
    } else {
      await _db.customStatement(
        'INSERT INTO scopes (school, user, role, created)'
        ' VALUES (?, ?, ?, ?)'
        ' ON CONFLICT (school, user, role) DO UPDATE SET'
        ' created = excluded.created',
        [school, k[1], k[2], now.toInt()],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 28: plans  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyPlans(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.plans,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.plan;
    final now = _now();
    await _db
        .into(_db.plans)
        .insertOnConflictUpdate(
          PlansCompanion(
            id: Value(delta.rowKey),
            name: Value(row.name),
            description: Value(row.hasDescription() ? row.description : null),
            amount: Value(row.amount),
            levels: Value(row.levels),
            status: Value(PlanStatus.values[row.status]),
            features: Value(row.hasFeatures() ? row.features : null),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 29: subscriptions  — PK: (school, plan, year, term, student)
  //     rowKey: "{school}|{plan}|{year}|{term}|{student}"
  // ---------------------------------------------------------------------------

  Future<void> _applySubscriptions(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.subscriptions)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.plan.equals(k[1]) &
                t.year.equals(_parseInt(k[2])) &
                t.term.equals(_parseInt(k[3])) &
                t.student.equals(_parseInt(k[4])),
          ))
          .go();
      return;
    }
    final row = delta.data.subscription;
    final now = _now();
    await _db
        .into(_db.subscriptions)
        .insertOnConflictUpdate(
          SubscriptionsCompanion(
            school: Value(k[0]),
            plan: Value(k[1]),
            year: Value(_parseInt(k[2])),
            term: Value(_parseInt(k[3])),
            student: Value(_parseInt(k[4])),
            invoice: Value(row.hasInvoice() ? row.invoice : null),
            discount: Value(row.discount),
            status: Value(SubscriptionStatus.values[row.status]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 30: discounts  — PK: (school, plan, year, term, grade)
  //     rowKey: "{school}|{plan}|{year}|{term}|{grade}"
  // ---------------------------------------------------------------------------

  Future<void> _applyDiscounts(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.discounts)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.plan.equals(k[1]) &
                t.year.equals(_parseInt(k[2])) &
                t.term.equals(_parseInt(k[3])) &
                t.grade.equals(_parseInt(k[4])),
          ))
          .go();
      return;
    }
    final row = delta.data.discount;
    final now = _now();
    await _db
        .into(_db.discounts)
        .insertOnConflictUpdate(
          DiscountsCompanion(
            school: Value(k[0]),
            plan: Value(k[1]),
            year: Value(_parseInt(k[2])),
            term: Value(_parseInt(k[3])),
            grade: Value(_parseInt(k[4])),
            amount: Value(row.amount),
            unit: Value(DiscountUnit.values[row.unit]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 31: subjects (global catalog)  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applySubjectCatalog(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.subjects,
      )..where((t) => t.id.equals(_parseInt(delta.rowKey)))).go();
      return;
    }
    if (!delta.hasData() || !delta.data.hasSubjectCatalog()) {
      debugPrint(
        '[DeltaWriter] ⚠ _applySubjectCatalog — delta has NO subjectCatalog data!',
      );
      return;
    }
    final row = delta.data.subjectCatalog;
    final now = _now();
    final serverId = _parseInt(delta.rowKey);
    final curriculumIndex = CurriculumType.values
        .firstWhere((e) => e.index_ == row.curriculum)
        .index_;

    // The local optimistic insert uses autoIncrement(), so the local ID may
    // differ from the server-assigned ID. A plain ON CONFLICT(id) would fail
    // on the UNIQUE(name, curriculum) index when the IDs don't match.
    // Delete any stale local row that matches the natural key but has a
    // different id, then upsert with the server's authoritative id.
    await _db.customStatement(
      'DELETE FROM subjects WHERE name = ? AND curriculum = ? AND id != ?',
      [row.name, curriculumIndex, serverId],
    );
    await _db
        .into(_db.subjects)
        .insertOnConflictUpdate(
          SubjectsCompanion(
            id: Value(serverId),
            name: Value(row.name),
            curriculum: Value(
              CurriculumType.values.firstWhere(
                (e) => e.index_ == row.curriculum,
              ),
            ),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 32: topics  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyTopic(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.topics,
      )..where((t) => t.id.equals(_parseInt(delta.rowKey)))).go();
      return;
    }
    if (!delta.hasData() || !delta.data.hasTopic()) {
      debugPrint('[DeltaWriter] ⚠ _applyTopic — delta has NO topic data!');
      return;
    }
    final row = delta.data.topic;
    final now = _now();
    final serverId = _parseInt(delta.rowKey);

    // Same pattern as _applySubjectCatalog: the local autoIncrement ID may
    // differ from the server ID, causing a UNIQUE(subject, grade, name)
    // conflict. Delete any stale local row first.
    await _db.customStatement(
      'DELETE FROM topics WHERE subject = ? AND grade = ? AND name = ? AND id != ?',
      [row.subject, row.grade, row.name, serverId],
    );
    await _db
        .into(_db.topics)
        .insertOnConflictUpdate(
          TopicsCompanion(
            id: Value(serverId),
            subject: Value(row.subject),
            grade: Value(row.grade),
            name: Value(row.name),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 33: streams  — PK: (school, grade, stream)
  //     rowKey: "{school}|{grade}|{stream}"
  // ---------------------------------------------------------------------------

  Future<void> _applyStream(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.streams)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.grade.equals(_parseInt(k[1])) &
                t.stream.equals(_parseInt(k[2])),
          ))
          .go();
      return;
    }
    if (!delta.hasData() || !delta.data.hasStream()) {
      debugPrint('[DeltaWriter] ⚠ _applyStream — delta has NO stream data!');
      return;
    }
    final row = delta.data.stream;
    final now = _now();
    await _db
        .into(_db.streams)
        .insertOnConflictUpdate(
          StreamsCompanion(
            school: Value(k[0]),
            grade: Value(_parseInt(k[1])),
            stream: Value(_parseInt(k[2])),
            name: Value(row.name),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 34: mpesa  — PK: (school)  — rowKey: "{school}"
  // ---------------------------------------------------------------------------

  Future<void> _applyMpesa(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.mpesa,
      )..where((t) => t.school.equals(delta.rowKey))).go();
      return;
    }
    if (!delta.hasData() || !delta.data.hasMpesa()) {
      debugPrint('[DeltaWriter] ⚠ _applyMpesa — delta has NO mpesa data!');
      return;
    }
    final row = delta.data.mpesa;
    final now = _now();
    await _db
        .into(_db.mpesa)
        .insertOnConflictUpdate(
          MpesaCompanion(
            school: Value(delta.rowKey),
            consumerKey: Value(row.consumerKey),
            consumerSecret: Value(row.consumerSecret),
            passkey: Value(row.passkey),
            shortcode: Value(row.shortcode),
            env: Value(MpesaEnv.values[row.env]),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 36: scheme_pages  — PK: (school, exam, subject, paper, page)  [paper nullable]
  //     rowKey: "{school}|{exam}|{subject}|{paper}|{page}"
  //     paper is empty-string when NULL.
  // ---------------------------------------------------------------------------

  Future<void> _applySchemePages(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    final paperVal = _parseIntNullable(k[3]);
    final pageVal = _parseInt(k[4]);

    if (delta.operation == 2) {
      // DELETE
      await _db.customStatement(
        'DELETE FROM scheme_pages WHERE school = ? AND exam = ? AND subject = ?'
        ' AND paper ${paperVal == null ? 'IS NULL' : '= ?'}'
        ' AND page = ?',
        [k[0], k[1], _parseInt(k[2]), ?paperVal, pageVal],
      );
      return;
    }

    final row = delta.data.schemePage;

    if (paperVal == null) {
      // NULL paper — ON CONFLICT cannot match NULLs in SQLite, so use
      // delete-then-insert.
      await _db.customStatement(
        'DELETE FROM scheme_pages WHERE school = ? AND exam = ? AND subject = ?'
        ' AND paper IS NULL AND page = ?',
        [k[0], k[1], _parseInt(k[2]), pageVal],
      );
      await _db.customStatement(
        'INSERT INTO scheme_pages (school, exam, subject, paper, page, key, created)'
        ' VALUES (?, ?, ?, NULL, ?, ?, ?)',
        [k[0], k[1], _parseInt(k[2]), pageVal, row.key, row.created.toInt()],
      );
    } else {
      await _db.customStatement(
        'INSERT INTO scheme_pages (school, exam, subject, paper, page, key, created)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?)'
        ' ON CONFLICT (school, exam, subject, paper, page) DO UPDATE SET'
        ' key = excluded.key,'
        ' created = excluded.created',
        [
          k[0],
          k[1],
          _parseInt(k[2]),
          paperVal,
          pageVal,
          row.key,
          row.created.toInt(),
        ],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 37: answer_pages  — PK: (school, exam, student, subject, paper, page)  [paper nullable]
  //     rowKey: "{school}|{exam}|{student}|{subject}|{paper}|{page}"
  //     paper is empty-string when NULL.
  // ---------------------------------------------------------------------------

  Future<void> _applyAnswerPages(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    final paperVal = _parseIntNullable(k[4]);
    final pageVal = _parseInt(k[5]);

    if (delta.operation == 2) {
      await _db.customStatement(
        'DELETE FROM answer_pages WHERE school = ? AND exam = ? AND student = ? AND subject = ?'
        ' AND paper ${paperVal == null ? 'IS NULL' : '= ?'}'
        ' AND page = ?',
        [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), ?paperVal, pageVal],
      );
      return;
    }

    final row = delta.data.answerPage;

    if (paperVal == null) {
      // NULL paper — delete-then-insert.
      await _db.customStatement(
        'DELETE FROM answer_pages WHERE school = ? AND exam = ? AND student = ? AND subject = ?'
        ' AND paper IS NULL AND page = ?',
        [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), pageVal],
      );
      await _db.customStatement(
        'INSERT INTO answer_pages (school, exam, student, subject, paper, page, key, created)'
        ' VALUES (?, ?, ?, ?, NULL, ?, ?, ?)',
        [
          k[0],
          k[1],
          _parseInt(k[2]),
          _parseInt(k[3]),
          pageVal,
          row.key,
          row.created.toInt(),
        ],
      );
    } else {
      await _db.customStatement(
        'INSERT INTO answer_pages (school, exam, student, subject, paper, page, key, created)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        ' ON CONFLICT (school, exam, student, subject, paper, page) DO UPDATE SET'
        ' key = excluded.key,'
        ' created = excluded.created',
        [
          k[0],
          k[1],
          _parseInt(k[2]),
          _parseInt(k[3]),
          paperVal,
          pageVal,
          row.key,
          row.created.toInt(),
        ],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 39: papers_v2  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // 38: events — PK: (id) — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyEvents(SyncDelta delta) async {
    // rowKey format: "{id}" (UUID string)
    final eventId = delta.rowKey;

    if (delta.operation == 2) {
      await (_db.delete(_db.events)
            ..where((t) => t.id.equals(eventId)))
          .go();
      return;
    }
    final row = delta.data.event;
    final now = _now();

    await _db.customStatement(
      'INSERT INTO events (id, school, name, type, term, year,'
      ' start_date, end_date, status, created, updated)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (id) DO UPDATE SET'
      ' school = excluded.school,'
      ' name = excluded.name,'
      ' type = excluded.type,'
      ' term = excluded.term,'
      ' year = excluded.year,'
      ' start_date = excluded.start_date,'
      ' end_date = excluded.end_date,'
      ' status = excluded.status,'
      ' created = excluded.created,'
      ' updated = excluded.updated',
      [
        eventId,
        row.school,
        row.name,
        row.type,
        row.term,
        row.year,
        row.startDate,
        row.endDate,
        row.status,
        row.created.toInt(),
        now.toInt(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 39: papers_v2 — PK: (id) — rowKey: "{id}"
  // ---------------------------------------------------------------------------

  Future<void> _applyPapersV2(SyncDelta delta) async {
    // rowKey format: "{id}" (UUID string)
    final paperId = delta.rowKey;

    if (delta.operation == 2) {
      await (_db.delete(_db.papersV2)
            ..where((t) => t.id.equals(paperId)))
          .go();
      return;
    }
    final row = delta.data.paperV2;
    final now = _now();

    final eventVal = row.hasEvent() ? row.event : null;
    final streamVal = row.hasStream() ? row.stream : null;
    final pdfKeyVal = row.hasPdfKey() ? row.pdfKey : null;
    final msKeyVal = row.hasMsKey() ? row.msKey : null;
    final instructionsVal = row.hasInstructions() ? row.instructions : null;

    await _db.customStatement(
      'INSERT INTO papers_v2 (id, school, event, subject, grade, stream,'
      ' type, teacher, name, total_marks, duration_minutes, date, status,'
      ' pdf_key, ms_key, generation_mode, instructions, created, updated)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (id) DO UPDATE SET'
      ' school = excluded.school,'
      ' event = excluded.event,'
      ' subject = excluded.subject,'
      ' grade = excluded.grade,'
      ' stream = excluded.stream,'
      ' type = excluded.type,'
      ' teacher = excluded.teacher,'
      ' name = excluded.name,'
      ' total_marks = excluded.total_marks,'
      ' duration_minutes = excluded.duration_minutes,'
      ' date = excluded.date,'
      ' status = excluded.status,'
      ' pdf_key = excluded.pdf_key,'
      ' ms_key = excluded.ms_key,'
      ' generation_mode = excluded.generation_mode,'
      ' instructions = excluded.instructions,'
      ' created = excluded.created,'
      ' updated = excluded.updated',
      [
        paperId,
        row.school,
        eventVal,
        row.subject,
        row.grade,
        streamVal,
        row.type,
        row.teacher,
        row.name,
        row.totalMarks,
        row.durationMinutes,
        row.date,
        row.status,
        pdfKeyVal,
        msKeyVal,
        row.generationMode,
        instructionsVal,
        row.created.toInt(),
        now.toInt(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 42: marking_queue  — PK: (paper)  — rowKey: "{paper_uuid}"
  // ---------------------------------------------------------------------------

  Future<void> _applyMarkingQueue(SyncDelta delta) async {
    final paperId = delta.rowKey;

    if (delta.operation == 2) {
      await (_db.delete(_db.markingQueue)
            ..where((t) => t.paper.equals(paperId)))
          .go();
      return;
    }

    final row = delta.data.markingQueue;
    final errorVal = row.hasError() ? row.error : null;

    await _db.customStatement(
      'INSERT INTO marking_queue (id, paper, phase, progress, error,'
      ' total_students, marked_students, created, updated)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (paper) DO UPDATE SET'
      ' id = excluded.id,'
      ' phase = excluded.phase,'
      ' progress = excluded.progress,'
      ' error = excluded.error,'
      ' total_students = excluded.total_students,'
      ' marked_students = excluded.marked_students,'
      ' created = excluded.created,'
      ' updated = excluded.updated',
      [
        row.id,
        paperId,
        row.phase,
        row.progress,
        errorVal,
        row.totalStudents,
        row.markedStudents,
        row.created.toInt(),
        row.updated.toInt(),
      ],
    );
  }
}
