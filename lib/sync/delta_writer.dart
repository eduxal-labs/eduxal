import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables/enums.dart';
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
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<SyncDelta>.from(_buffer);
    _buffer.clear();
    await _db.transaction(() async {
      for (final delta in batch) {
        await _applySingle(delta);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _parseKey(String rowKey) => rowKey.split('|');

  int _parseInt(String s) => int.parse(s);

  int? _parseIntNullable(String s) => s == 'null' ? null : int.parse(s);

  String? _parseStringNullable(String s) => s == 'null' ? null : s;

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
        await _applySubjects(delta);
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
        await _applySettings(delta);
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
      await (_db.delete(
        _db.schools,
      )..where((t) => t.id.equals(delta.rowKey))).go();
      return;
    }
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
    await _db
        .into(_db.terms)
        .insertOnConflictUpdate(
          TermsCompanion(
            school: Value(k[0]),
            year: Value(_parseInt(k[1])),
            term: Value(_parseInt(k[2])),
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

  Future<void> _applySubjects(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.subjects)..where(
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
    final row = delta.data.subject;
    final now = _now();
    await _db
        .into(_db.subjects)
        .insertOnConflictUpdate(
          SubjectsCompanion(
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
                t.day.equals(_parseInt(k[5])) &
                t.subject.equals(_parseInt(k[6])) &
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
            subject: Value(_parseInt(k[6])),
            teacher: Value(row.teacher),
            day: Value(DayOfWeek.values[_parseInt(k[5])]),
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
            year: Value(row.year),
            term: Value(row.term),
            grade: Value(row.grade),
            stream: Value(row.hasStream() ? row.stream : null),
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
  // ---------------------------------------------------------------------------

  Future<void> _applyPapers(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      final paper = _parseIntNullable(k[3]);
      await _db.customStatement(
        'DELETE FROM papers WHERE school = ? AND exam = ? AND subject = ?'
        ' AND paper ${paper == null ? 'IS NULL' : '= ?'}',
        [k[0], k[1], _parseInt(k[2]), ?paper],
      );
      return;
    }
    final row = delta.data.paper;
    final now = _now();
    // papers has a nullable PK column (paper), so we must use raw SQL for
    // upsert because Drift's insertOnConflictUpdate cannot handle nullable PKs.
    final paperVal = _parseIntNullable(k[3]);
    await _db.customStatement(
      'INSERT INTO papers (school, exam, subject, paper, invigilator, start, "end", status, created, updated)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (school, exam, subject, paper) DO UPDATE SET'
      ' invigilator = excluded.invigilator,'
      ' start = excluded.start,'
      ' "end" = excluded."end",'
      ' status = excluded.status,'
      ' created = excluded.created,'
      ' updated = excluded.updated',
      [
        k[0],
        k[1],
        _parseInt(k[2]),
        paperVal,
        row.invigilator,
        row.start.toInt(),
        row.end.toInt(),
        row.status,
        now.toInt(),
        now.toInt(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 18: grades  — PK: (school, exam, student, subject, paper)  [paper nullable]
  //     rowKey: "{school}|{exam}|{student}|{subject}|{paper}"
  // ---------------------------------------------------------------------------

  Future<void> _applyGrades(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      final paper = _parseIntNullable(k[4]);
      await _db.customStatement(
        'DELETE FROM grades WHERE school = ? AND exam = ? AND student = ? AND subject = ?'
        ' AND paper ${paper == null ? 'IS NULL' : '= ?'}',
        [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), ?paper],
      );
      return;
    }
    final row = delta.data.grade;
    final now = _now();
    final paperVal = _parseIntNullable(k[4]);
    await _db.customStatement(
      'INSERT INTO grades (school, exam, student, subject, paper, score, total, created, updated)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (school, exam, student, subject, paper) DO UPDATE SET'
      ' score = excluded.score,'
      ' total = excluded.total,'
      ' created = excluded.created,'
      ' updated = excluded.updated',
      [
        k[0],
        k[1],
        _parseInt(k[2]),
        _parseInt(k[3]),
        paperVal,
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
  // 23: mastery  — PK: (school, student, grade, subject, topic)
  //     rowKey: "{school}|{student}|{grade}|{subject}|{topic}"
  // ---------------------------------------------------------------------------

  Future<void> _applyMastery(SyncDelta delta) async {
    final k = _parseKey(delta.rowKey);
    if (delta.operation == 2) {
      await (_db.delete(_db.mastery)..where(
            (t) =>
                t.school.equals(k[0]) &
                t.student.equals(_parseInt(k[1])) &
                t.grade.equals(_parseInt(k[2])) &
                t.subject.equals(_parseInt(k[3])) &
                t.topic.equals(_parseInt(k[4])),
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
            grade: Value(_parseInt(k[2])),
            subject: Value(_parseInt(k[3])),
            topic: Value(_parseInt(k[4])),
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
  // 25: settings  — PK: (school)  — rowKey: "{school}"
  // ---------------------------------------------------------------------------

  Future<void> _applySettings(SyncDelta delta) async {
    if (delta.operation == 2) {
      await (_db.delete(
        _db.settings,
      )..where((t) => t.school.equals(delta.rowKey))).go();
      return;
    }
    final row = delta.data.settings;
    final now = _now();
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(
            school: Value(delta.rowKey),
            data: Value(row.data),
            mpesa: Value(row.hasMpesa() ? row.mpesa : null),
            created: Value(now),
            updated: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // 26: roles  — PK: (id)  — rowKey: "{id}"
  // ---------------------------------------------------------------------------

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
            permissions: Value(base64Encode(row.permissions)),
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
    // scopes has a nullable PK column (school), so we must use raw SQL for
    // upsert because Drift's insertOnConflictUpdate cannot handle nullable PKs.
    await _db.customStatement(
      'INSERT INTO scopes (school, user, role, created)'
      ' VALUES (?, ?, ?, ?)'
      ' ON CONFLICT (school, user, role) DO UPDATE SET'
      ' created = excluded.created',
      [school, k[1], k[2], now.toInt()],
    );
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
}
