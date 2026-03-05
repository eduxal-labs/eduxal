import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/guardians.dart';
import '../tables/logs.dart';
import '../tables/owners.dart';
import '../tables/staff.dart';
import '../tables/students.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';

part 'members_dao.g.dart';

/// DAO for the five "member" tables: [Teachers], [Staff], [Students],
/// [Guardians], and their dependency on [Users].
///
/// Every local mutation:
///   - Writes the row to the relevant table.
///   - Writes a corresponding [Logs] entry inside the **same transaction**
///     so the sync engine can replay it to the server when connectivity
///     is restored.
///
/// ### Phone-first identity resolution
/// Teachers, Staff, and Guardians are resolved against the [Users] table by
/// phone number before linking to a role table.  Two outcomes:
///   1. User found  → link directly (no new user row needed).
///   2. User absent → create an invited user row first, then link.
///
/// Students do **not** go through phone-first resolution — they are created
/// by name, not by phone.  Optionally a student row can be linked to an
/// existing user via [linkStudentToUser].
@DriftAccessor(
  tables: [Users, Owners, Teachers, Staff, Students, Guardians, Logs],
)
class MembersDao extends DatabaseAccessor<AppDatabase> with _$MembersDaoMixin {
  MembersDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // User lookup  (phone-first resolution)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the first [UsersData] row whose phone number exactly matches
  /// [phone], or `null` if no local row exists.
  ///
  /// Called by the creation UI before deciding whether to expand the form
  /// for a "name" field.
  Future<UsersData?> findUserByPhone(String phone) =>
      (select(users)..where((t) => t.phone.equals(phone))).getSingleOrNull();

  /// Returns the [UsersData] row for [userId], or `null` if not found.
  ///
  /// Used by the Members page to resolve user details (name, phone, status)
  /// for member rows that reference a user by id.
  Future<UsersData?> findUserById(String userId) =>
      (select(users)..where((t) => t.id.equals(userId))).getSingleOrNull();

  /// Returns `true` if [schoolId] already has an owner row for [userId].
  Future<bool> ownerExists(String schoolId, String userId) async {
    final row =
        await (select(owners)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns `true` if [schoolId] already has a teacher row for [userId].
  Future<bool> teacherExists(String schoolId, String userId) async {
    final row =
        await (select(teachers)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns `true` if [schoolId] already has a staff row for [userId].
  Future<bool> staffExists(String schoolId, String userId) async {
    final row =
        await (select(staff)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns `true` if [schoolId] already has a guardian row for
  /// [userId] linked to [studentAdm].
  Future<bool> guardianExists(
    String schoolId,
    String userId,
    int studentAdm,
  ) async {
    final row =
        await (select(guardians)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.user.equals(userId) &
                  t.student.equals(studentAdm),
            ))
            .getSingleOrNull();
    return row != null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Next admission number
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the next available admission number for [schoolId].
  ///
  /// Uses `MAX(adm) + 1`, or `1` when no student rows exist for the school.
  Future<int> nextAdmissionNumber(String schoolId) async {
    final maxAdm = students.adm.max();
    final query = selectOnly(students)
      ..addColumns([maxAdm])
      ..where(students.school.equals(schoolId));
    final row = await query.getSingleOrNull();
    return (row?.read(maxAdm) ?? 0) + 1;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the list of [OwnersData] for [schoolId] ordered by creation
  /// timestamp descending. Re-emits on every change.
  Stream<List<OwnersData>> watchOwners(String schoolId) =>
      (select(owners)
            ..where((t) => t.school.equals(schoolId))
            ..orderBy([(t) => OrderingTerm.desc(t.created)]))
          .watch();

  /// Emits the list of [TeachersData] for [schoolId] ordered by creation
  /// timestamp descending. Re-emits on every change.
  Stream<List<TeachersData>> watchTeachers(String schoolId) =>
      (select(teachers)
            ..where((t) => t.school.equals(schoolId))
            ..orderBy([(t) => OrderingTerm.desc(t.created)]))
          .watch();

  /// Emits the list of [StaffData] for [schoolId] ordered by creation
  /// timestamp descending. Re-emits on every change.
  Stream<List<StaffData>> watchStaff(String schoolId) =>
      (select(staff)
            ..where((t) => t.school.equals(schoolId))
            ..orderBy([(t) => OrderingTerm.desc(t.created)]))
          .watch();

  /// Emits the list of active [StudentsData] for [schoolId] ordered by
  /// admission number ascending. Re-emits on every change.
  Stream<List<StudentsData>> watchStudents(String schoolId) =>
      (select(students)
            ..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.status.equals(StudentStatus.active.index),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.adm)]))
          .watch();

  /// Emits all [GuardiansData] for [schoolId] and [studentAdm], ordered
  /// by role (primary first). Re-emits on every change.
  Stream<List<GuardiansData>> watchGuardians(String schoolId, int studentAdm) =>
      (select(guardians)
            ..where(
              (t) => t.school.equals(schoolId) & t.student.equals(studentAdm),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.role)]))
          .watch();

  /// Emits **all** [GuardiansData] for [schoolId] regardless of student,
  /// ordered by creation timestamp descending. Used by the Members page
  /// Guardians tab to display every guardian at the school.
  Stream<List<GuardiansData>> watchAllGuardians(String schoolId) =>
      (select(guardians)
            ..where((t) => t.school.equals(schoolId))
            ..orderBy([(t) => OrderingTerm.desc(t.created)]))
          .watch();

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the [OwnersData] row for [schoolId]/[userId], or `null`.
  Future<OwnersData?> getOwner(String schoolId, String userId) =>
      (select(owners)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .getSingleOrNull();

  /// Returns the [TeachersData] row for [schoolId]/[userId], or `null`.
  Future<TeachersData?> getTeacher(String schoolId, String userId) =>
      (select(teachers)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .getSingleOrNull();

  /// Returns the [StaffData] row for [schoolId]/[userId], or `null`.
  Future<StaffData?> getStaffMember(String schoolId, String userId) =>
      (select(staff)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .getSingleOrNull();

  /// Returns the [StudentsData] row for [schoolId]/[adm], or `null`.
  Future<StudentsData?> getStudent(String schoolId, int adm) =>
      (select(students)
            ..where((t) => t.school.equals(schoolId) & t.adm.equals(adm)))
          .getSingleOrNull();

  // ─────────────────────────────────────────────────────────────────────────
  // Owner mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates an invited [Users] row and immediately links it as an owner at
  /// [schoolId], all in a single transaction.
  ///
  /// Use this overload when [findUserByPhone] returned `null` (user unknown).
  Future<void> inviteAndAddOwner({
    required UsersCompanion newUser,
    required OwnersCompanion owner,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // 1. Persist the new invited user.
      await into(users).insert(newUser);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.users),
          op: const Value(LogOperation.insert),
          rowKey: newUser.id,
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      // 2. Persist the owner row.
      final ownerWithTimestamp = owner.copyWith(created: Value(nowSec));
      await into(owners).insert(ownerWithTimestamp);
      final schoolId = owner.school.value;
      final userId = newUser.id.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.owners),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Links an **existing** user (already in the local DB) as an owner at
  /// [schoolId]. Writes only the owner row + log entry.
  ///
  /// Use this overload when [findUserByPhone] returned a non-null row.
  Future<void> addExistingUserAsOwner({
    required OwnersCompanion owner,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final ownerWithTimestamp = owner.copyWith(created: Value(nowSec));
      await into(owners).insert(ownerWithTimestamp);

      final schoolId = owner.school.value;
      final userId = owner.user.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.owners),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Removes an owner row from [schoolId] and enqueues a delete log entry.
  Future<void> removeOwner({
    required String schoolId,
    required String userId,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.owners),
          op: const Value(LogOperation.delete),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
      await (delete(
        owners,
      )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).go();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Teacher mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates an invited [Users] row for [newUser] and immediately links it
  /// as a teacher at [schoolId], all in a single transaction.
  ///
  /// Use this overload when [findUserByPhone] returned `null` (user unknown).
  ///
  /// [newUser] must have all required fields:
  ///   - `id` (UUID), `phone`, `name`, `status = invited`, `created`, `updated`
  ///
  /// [teacher] must have `school` and `user` set.
  Future<void> inviteAndAddTeacher({
    required UsersCompanion newUser,
    required TeachersCompanion teacher,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // 1. Persist the new invited user.
      await into(users).insert(newUser);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.users),
          op: const Value(LogOperation.insert),
          rowKey: newUser.id,
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      // 2. Persist the teacher row.
      final teacherWithTimestamp = teacher.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(teachers).insert(teacherWithTimestamp);
      final schoolId = teacher.school.value;
      final userId = newUser.id.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.teachers),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Links an **existing** user (already in the local DB) as a teacher at
  /// [schoolId]. Writes only the teacher row + log entry.
  ///
  /// Use this overload when [findUserByPhone] returned a non-null row.
  Future<void> addExistingUserAsTeacher({
    required TeachersCompanion teacher,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final teacherWithTimestamp = teacher.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(teachers).insert(teacherWithTimestamp);

      final schoolId = teacher.school.value;
      final userId = teacher.user.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.teachers),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Updates mutable fields on a teacher row and writes a log UPDATE entry.
  Future<void> updateTeacher({
    required String schoolId,
    required String userId,
    required TeachersCompanion changes,
    required String accountId,
  }) {
    return transaction(() async {
      await (update(teachers)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .write(changes);

      int mask = 0;
      if (changes.hired.present) mask |= (1 << TeachersColumn.hired.bit);
      if (changes.role.present) mask |= (1 << TeachersColumn.role.bit);
      if (changes.department.present) {
        mask |= (1 << TeachersColumn.department.bit);
      }
      if (changes.status.present) mask |= (1 << TeachersColumn.status.bit);
      if (changes.updated.present) mask |= (1 << TeachersColumn.updated.bit);

      if (mask == 0) return;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.teachers),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$userId'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Removes a teacher row from [schoolId] and enqueues a delete log entry.
  Future<void> removeTeacher({
    required String schoolId,
    required String userId,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.teachers),
          op: const Value(LogOperation.delete),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
      await (delete(
        teachers,
      )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).go();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Staff mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates an invited [Users] row and links them as staff, all in one
  /// transaction.
  Future<void> inviteAndAddStaff({
    required UsersCompanion newUser,
    required StaffCompanion member,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await into(users).insert(newUser);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.users),
          op: const Value(LogOperation.insert),
          rowKey: newUser.id,
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      final memberWithTimestamp = member.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(staff).insert(memberWithTimestamp);
      final schoolId = member.school.value;
      final userId = newUser.id.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.staff),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Links an existing user as staff. Writes only the staff row + log entry.
  Future<void> addExistingUserAsStaff({
    required StaffCompanion member,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final memberWithTimestamp = member.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(staff).insert(memberWithTimestamp);

      final schoolId = member.school.value;
      final userId = member.user.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.staff),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Updates mutable fields on a staff row and writes a log UPDATE entry.
  Future<void> updateStaff({
    required String schoolId,
    required String userId,
    required StaffCompanion changes,
    required String accountId,
  }) {
    return transaction(() async {
      await (update(staff)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .write(changes);

      int mask = 0;
      if (changes.idnumber.present) mask |= (1 << StaffColumn.idnumber.bit);
      if (changes.role.present) mask |= (1 << StaffColumn.role.bit);
      if (changes.department.present) {
        mask |= (1 << StaffColumn.department.bit);
      }
      if (changes.status.present) mask |= (1 << StaffColumn.status.bit);
      if (changes.updated.present) mask |= (1 << StaffColumn.updated.bit);

      if (mask == 0) return;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.staff),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$userId'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Removes a staff row and enqueues a delete log entry.
  Future<void> removeStaff({
    required String schoolId,
    required String userId,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.staff),
          op: const Value(LogOperation.delete),
          rowKey: Value('$schoolId|$userId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
      await (delete(
        staff,
      )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).go();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Student mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new student row and enqueues an INSERT log entry.
  ///
  /// The admission number ([StudentsCompanion.adm]) must already be set
  /// by the caller (obtained via [nextAdmissionNumber]).
  Future<void> createStudent({
    required StudentsCompanion student,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final studentWithTimestamp = student.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(students).insert(studentWithTimestamp);

      final schoolId = student.school.value;
      final adm = student.adm.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.students),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$adm'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Updates mutable fields on a student row and writes a log UPDATE entry.
  Future<void> updateStudent({
    required String schoolId,
    required int adm,
    required StudentsCompanion changes,
    required String accountId,
  }) {
    return transaction(() async {
      await (update(students)
            ..where((t) => t.school.equals(schoolId) & t.adm.equals(adm)))
          .write(changes);

      int mask = 0;
      if (changes.user.present) mask |= (1 << StudentsColumn.user.bit);
      if (changes.name.present) mask |= (1 << StudentsColumn.name.bit);
      if (changes.dob.present) mask |= (1 << StudentsColumn.dob.bit);
      if (changes.gender.present) mask |= (1 << StudentsColumn.gender.bit);
      if (changes.documents.present) {
        mask |= (1 << StudentsColumn.documents.bit);
      }
      if (changes.admitted.present) mask |= (1 << StudentsColumn.admitted.bit);
      if (changes.status.present) mask |= (1 << StudentsColumn.status.bit);
      if (changes.updated.present) mask |= (1 << StudentsColumn.updated.bit);

      if (mask == 0) return;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.students),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$adm'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Links an existing [Users] row to a student row by setting [student.user].
  ///
  /// This is a convenience wrapper around [updateStudent] for the common
  /// "attach user account to student" scenario.
  Future<void> linkStudentToUser({
    required String schoolId,
    required int adm,
    required String userId,
    required String accountId,
  }) {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return updateStudent(
      schoolId: schoolId,
      adm: adm,
      changes: StudentsCompanion(
        user: Value(userId),
        updated: Value(nowSeconds),
      ),
      accountId: accountId,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Guardian mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates an invited [Users] row and links them as a guardian of
  /// [studentAdm], all in a single transaction.
  Future<void> inviteAndAddGuardian({
    required UsersCompanion newUser,
    required GuardiansCompanion guardian,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await into(users).insert(newUser);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.users),
          op: const Value(LogOperation.insert),
          rowKey: newUser.id,
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      final guardianWithTimestamp = guardian.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(guardians).insert(guardianWithTimestamp);

      final schoolId = guardian.school.value;
      final userId = newUser.id.value;
      final studentAdm = guardian.student.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.guardians),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId|$studentAdm'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Links an existing user as a guardian of [studentAdm].
  Future<void> addExistingUserAsGuardian({
    required GuardiansCompanion guardian,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final guardianWithTimestamp = guardian.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(guardians).insert(guardianWithTimestamp);

      final schoolId = guardian.school.value;
      final userId = guardian.user.value;
      final studentAdm = guardian.student.value;
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.guardians),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId|$studentAdm'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Updates mutable fields on a guardian row and writes a log UPDATE entry.
  Future<void> updateGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    required GuardiansCompanion changes,
    required String accountId,
  }) {
    return transaction(() async {
      await (update(guardians)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.user.equals(userId) &
                t.student.equals(studentAdm),
          ))
          .write(changes);

      int mask = 0;
      if (changes.relationship.present) {
        mask |= (1 << GuardiansColumn.relationship.bit);
      }
      if (changes.role.present) mask |= (1 << GuardiansColumn.role.bit);
      if (changes.updated.present) mask |= (1 << GuardiansColumn.updated.bit);

      if (mask == 0) return;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.guardians),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$userId|$studentAdm'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Removes a guardian row and enqueues a delete log entry.
  Future<void> removeGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.guardians),
          op: const Value(LogOperation.delete),
          rowKey: Value('$schoolId|$userId|$studentAdm'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
      await (delete(guardians)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.user.equals(userId) &
                t.student.equals(studentAdm),
          ))
          .go();
    });
  }
}
