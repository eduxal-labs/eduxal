import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/class_teachers.dart';
import '../tables/enums.dart';
import '../tables/guardians.dart';
import '../tables/logs.dart';
import '../tables/owners.dart';
import '../tables/staff.dart';
import '../tables/students.dart';
import '../tables/subject_teachers.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

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
  tables: [
    Users,
    Owners,
    Teachers,
    Staff,
    Students,
    Guardians,
    ClassTeachers,
    SubjectTeachers,
    Logs,
  ],
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
  Future<UsersData?> findUserByPhone(String phone) {
    return (select(
      users,
    )..where((t) => t.phone.equals(phone))).getSingleOrNull();
  }

  /// Returns the [UsersData] row for a given [id], or `null`.
  Future<UsersData?> findUserById(String id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Returns `true` if a row exists in [Owners] for the given composite key.
  Future<bool> ownerExists(String schoolId, String userId) async {
    final row =
        await (select(owners)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns `true` if a row exists in [Teachers] for the given composite key.
  Future<bool> teacherExists(String schoolId, String userId) async {
    final row =
        await (select(teachers)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns `true` if a row exists in [Staff] for the given composite key.
  Future<bool> staffExists(String schoolId, String userId) async {
    final row =
        await (select(staff)
              ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
            .getSingleOrNull();
    return row != null;
  }

  /// Returns `true` if a row exists in [Guardians] for the given composite key.
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
  // Admission number generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the next available admission number for [schoolId].
  ///
  /// Currently returns `max(adm) + 1`, starting at `1` if no students exist.
  Future<int> nextAdmissionNumber(String schoolId) async {
    final maxAdm = students.adm.max();
    final query = selectOnly(students)
      ..addColumns([maxAdm])
      ..where(students.school.equals(schoolId));
    final row = await query.getSingle();
    final current = row.read(maxAdm);
    return (current ?? 0) + 1;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — membership lists
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<OwnersData>> watchOwners(String schoolId) =>
      (select(owners)..where((t) => t.school.equals(schoolId))).watch();

  Stream<List<TeachersData>> watchTeachers(String schoolId) =>
      (select(teachers)..where((t) => t.school.equals(schoolId))).watch();

  Stream<List<StaffData>> watchStaff(String schoolId) =>
      (select(staff)..where((t) => t.school.equals(schoolId))).watch();

  Stream<List<StudentsData>> watchStudents(String schoolId) =>
      (select(students)..where((t) => t.school.equals(schoolId))).watch();

  Stream<List<GuardiansData>> watchGuardians(String schoolId, int studentAdm) =>
      (select(guardians)..where(
            (t) => t.school.equals(schoolId) & t.student.equals(studentAdm),
          ))
          .watch();

  Stream<List<GuardiansData>> watchAllGuardians(String schoolId) =>
      (select(guardians)..where((t) => t.school.equals(schoolId))).watch();

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  Future<OwnersData?> getOwner(String schoolId, String userId) =>
      (select(owners)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .getSingleOrNull();

  Future<TeachersData?> getTeacher(String schoolId, String userId) =>
      (select(teachers)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .getSingleOrNull();

  Future<StaffData?> getStaffMember(String schoolId, String userId) =>
      (select(staff)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .getSingleOrNull();

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
  /// Writes a single [SyncAction.createOwner] log entry whose
  /// [CreateOwnerPayload] carries the user's phone/name/email so the server
  /// can perform user lookup/creation.
  Future<void> inviteAndAddOwner({
    required UsersCompanion newUser,
    required OwnersCompanion owner,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createOwner,
      schoolId: owner.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // 1. Persist the new invited user.
      await into(users).insert(newUser);

      // 2. Persist the owner row.
      final ownerWithTimestamp = owner.copyWith(created: Value(nowSec));
      await into(owners).insert(ownerWithTimestamp);

      final schoolId = owner.school.value;
      final userId = newUser.id.value;

      // 3. Log: createOwner action with user identity embedded.
      final payload = sync_pb.CreateOwnerPayload(
        school: schoolId,
        userId: userId,
        phone: newUser.phone.value,
        name: newUser.name.value,
      );
      if (newUser.email.present && newUser.email.value != null) {
        payload.email = newUser.email.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createOwner),
          resource: Value(newUser.phone.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Links an **existing** user (already in the local DB) as an owner at
  /// [schoolId]. Writes only the owner row + log entry.
  ///
  /// Use this overload when [findUserByPhone] returned a non-null row.
  Future<void> addExistingUserAsOwner({
    required OwnersCompanion owner,
    required UsersData existingUser,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createOwner,
      schoolId: owner.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final ownerWithTimestamp = owner.copyWith(created: Value(nowSec));
      await into(owners).insert(ownerWithTimestamp);

      final schoolId = owner.school.value;

      final payload = sync_pb.CreateOwnerPayload(
        school: schoolId,
        userId: existingUser.id,
        phone: existingUser.phone,
        name: existingUser.name,
      );
      if (existingUser.email != null) {
        payload.email = existingUser.email!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createOwner),
          resource: Value(existingUser.phone),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes an owner row from [schoolId] and enqueues a delete log entry.
  Future<void> removeOwner({
    required String schoolId,
    required String userId,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Get user info for resource display before deletion.
      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final payload = sync_pb.DeleteOwnerPayload(
        school: schoolId,
        user: userId,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteOwner),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
      await (delete(
        owners,
      )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).go();
    });
    sync.schedulePush();
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
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createTeacher,
      schoolId: teacher.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // 1. Persist the new invited user.
      await into(users).insert(newUser);

      // 2. Persist the teacher row.
      final teacherWithTimestamp = teacher.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(teachers).insert(teacherWithTimestamp);

      final schoolId = teacher.school.value;
      final userId = newUser.id.value;

      // 3. Log: createTeacher action with user identity embedded.
      final payload = sync_pb.CreateTeacherPayload(
        school: schoolId,
        userId: userId,
        phone: newUser.phone.value,
        name: newUser.name.value,
      );
      if (newUser.email.present && newUser.email.value != null) {
        payload.email = newUser.email.value!;
      }
      if (teacher.hired.present && teacher.hired.value != null) {
        payload.hired = teacher.hired.value!;
      }
      if (teacher.role.present && teacher.role.value != null) {
        payload.role = teacher.role.value!;
      }
      if (teacher.department.present && teacher.department.value != null) {
        payload.department = teacher.department.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createTeacher),
          resource: Value(newUser.phone.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Links an **existing** user (already in the local DB) as a teacher at
  /// [schoolId]. Writes only the teacher row + log entry.
  ///
  /// Use this overload when [findUserByPhone] returned a non-null row.
  Future<void> addExistingUserAsTeacher({
    required TeachersCompanion teacher,
    required UsersData existingUser,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createTeacher,
      schoolId: teacher.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final teacherWithTimestamp = teacher.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(teachers).insert(teacherWithTimestamp);

      final schoolId = teacher.school.value;

      final payload = sync_pb.CreateTeacherPayload(
        school: schoolId,
        userId: existingUser.id,
        phone: existingUser.phone,
        name: existingUser.name,
      );
      if (existingUser.email != null) {
        payload.email = existingUser.email!;
      }
      if (teacher.hired.present && teacher.hired.value != null) {
        payload.hired = teacher.hired.value!;
      }
      if (teacher.role.present && teacher.role.value != null) {
        payload.role = teacher.role.value!;
      }
      if (teacher.department.present && teacher.department.value != null) {
        payload.department = teacher.department.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createTeacher),
          resource: Value(existingUser.phone),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable fields on a teacher row and writes a log entry with
  /// [SyncAction.updateTeacher] containing an [UpdateTeacherPayload].
  /// The server uses protobuf `has*()` semantics to determine which fields
  /// were changed.
  Future<void> updateTeacher({
    required String schoolId,
    required String userId,
    required TeachersCompanion changes,
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(teachers)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .write(changes);

      // Build the UpdateTeacherPayload with only changed fields.
      final payload = sync_pb.UpdateTeacherPayload(
        school: schoolId,
        user: userId,
      );
      bool hasChanges = false;

      if (changes.hired.present) {
        if (changes.hired.value != null) payload.hired = changes.hired.value!;
        hasChanges = true;
      }
      if (changes.role.present) {
        if (changes.role.value != null) payload.role = changes.role.value!;
        hasChanges = true;
      }
      if (changes.department.present) {
        if (changes.department.value != null) {
          payload.department = changes.department.value!;
        }
        hasChanges = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        hasChanges = true;
      }

      if (!hasChanges) return;

      // Get user phone for human-readable resource display.
      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateTeacher),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes a teacher row from [schoolId] and enqueues a delete log entry.
  Future<void> removeTeacher({
    required String schoolId,
    required String userId,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final payload = sync_pb.DeleteTeacherPayload(
        school: schoolId,
        user: userId,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteTeacher),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
      await (delete(
        teachers,
      )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).go();
    });
    sync.schedulePush();
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
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createStaff,
      schoolId: member.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await into(users).insert(newUser);

      final memberWithTimestamp = member.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(staff).insert(memberWithTimestamp);

      final schoolId = member.school.value;
      final userId = newUser.id.value;

      final payload = sync_pb.CreateStaffPayload(
        school: schoolId,
        userId: userId,
        phone: newUser.phone.value,
        name: newUser.name.value,
      );
      if (newUser.email.present && newUser.email.value != null) {
        payload.email = newUser.email.value!;
      }
      if (member.idnumber.present && member.idnumber.value != null) {
        payload.idnumber = member.idnumber.value!;
      }
      if (member.role.present && member.role.value != null) {
        payload.role = member.role.value!;
      }
      if (member.department.present && member.department.value != null) {
        payload.department = member.department.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createStaff),
          resource: Value(newUser.phone.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Links an existing user as staff. Writes only the staff row + log entry.
  Future<void> addExistingUserAsStaff({
    required StaffCompanion member,
    required UsersData existingUser,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createStaff,
      schoolId: member.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final memberWithTimestamp = member.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(staff).insert(memberWithTimestamp);

      final schoolId = member.school.value;

      final payload = sync_pb.CreateStaffPayload(
        school: schoolId,
        userId: existingUser.id,
        phone: existingUser.phone,
        name: existingUser.name,
      );
      if (existingUser.email != null) {
        payload.email = existingUser.email!;
      }
      if (member.idnumber.present && member.idnumber.value != null) {
        payload.idnumber = member.idnumber.value!;
      }
      if (member.role.present && member.role.value != null) {
        payload.role = member.role.value!;
      }
      if (member.department.present && member.department.value != null) {
        payload.department = member.department.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createStaff),
          resource: Value(existingUser.phone),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable fields on a staff row and writes a log entry with
  /// [SyncAction.updateStaff] containing an [UpdateStaffPayload].
  Future<void> updateStaff({
    required String schoolId,
    required String userId,
    required StaffCompanion changes,
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(staff)
            ..where((t) => t.school.equals(schoolId) & t.user.equals(userId)))
          .write(changes);

      final payload = sync_pb.UpdateStaffPayload(
        school: schoolId,
        user: userId,
      );
      bool hasChanges = false;

      if (changes.idnumber.present) {
        if (changes.idnumber.value != null) {
          payload.idnumber = changes.idnumber.value!;
        }
        hasChanges = true;
      }
      if (changes.role.present) {
        if (changes.role.value != null) payload.role = changes.role.value!;
        hasChanges = true;
      }
      if (changes.department.present) {
        if (changes.department.value != null) {
          payload.department = changes.department.value!;
        }
        hasChanges = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        hasChanges = true;
      }

      if (!hasChanges) return;

      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateStaff),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes a staff row and enqueues a delete log entry.
  Future<void> removeStaff({
    required String schoolId,
    required String userId,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final payload = sync_pb.DeleteStaffPayload(
        school: schoolId,
        user: userId,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteStaff),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
      await (delete(
        staff,
      )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).go();
    });
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Student mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new student row and enqueues a [SyncAction.createStudent] log.
  ///
  /// The admission number ([StudentsCompanion.adm]) must already be set
  /// by the caller (obtained via [nextAdmissionNumber]).
  Future<void> createStudent({
    required StudentsCompanion student,
    required String accountId,
    String? userPhone,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createStudent,
      schoolId: student.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final studentWithTimestamp = student.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(students).insert(studentWithTimestamp);

      final schoolId = student.school.value;
      final adm = student.adm.value;

      final payload = sync_pb.CreateStudentPayload(
        school: schoolId,
        adm: adm,
        name: student.name.value,
      );
      // Send phone in payload for server-side user resolution.
      // The local DB may have user ID set (optimistic link to known user),
      // but the server always resolves by phone.
      if (userPhone != null && userPhone.isNotEmpty) {
        payload.user = userPhone;
      } else if (student.user.present && student.user.value != null) {
        payload.user = student.user.value!;
      }
      if (student.dob.present && student.dob.value != null) {
        payload.dob = student.dob.value!;
      }
      if (student.gender.present && student.gender.value != null) {
        payload.gender = student.gender.value!.index;
      }
      if (student.documents.present && student.documents.value != null) {
        payload.documents = student.documents.value!;
      }
      if (student.admitted.present && student.admitted.value != null) {
        payload.admitted = student.admitted.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createStudent),
          resource: Value(student.name.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable fields on a student row and writes a log entry with
  /// [SyncAction.updateStudent] containing an [UpdateStudentPayload].
  Future<void> updateStudent({
    required String schoolId,
    required int adm,
    required StudentsCompanion changes,
    required String accountId,
    String? userPhone,
  }) async {
    await transaction(() async {
      await (update(students)
            ..where((t) => t.school.equals(schoolId) & t.adm.equals(adm)))
          .write(changes);

      final payload = sync_pb.UpdateStudentPayload(school: schoolId, adm: adm);
      bool hasChanges = false;

      if (userPhone != null) {
        // Phone-based user resolution: send phone to server.
        // "-" = "unlink user". Non-empty phone = "resolve this phone".
        payload.user = userPhone;
        hasChanges = true;
      } else if (changes.user.present) {
        if (changes.user.value != null) payload.user = changes.user.value!;
        hasChanges = true;
      }
      if (changes.name.present) {
        payload.name = changes.name.value;
        hasChanges = true;
      }
      if (changes.dob.present) {
        if (changes.dob.value != null) payload.dob = changes.dob.value!;
        hasChanges = true;
      }
      if (changes.gender.present) {
        if (changes.gender.value != null) {
          payload.gender = changes.gender.value!.index;
        }
        hasChanges = true;
      }
      if (changes.documents.present) {
        if (changes.documents.value != null) {
          payload.documents = changes.documents.value!;
        }
        hasChanges = true;
      }
      if (changes.admitted.present) {
        if (changes.admitted.value != null) {
          payload.admitted = changes.admitted.value!;
        }
        hasChanges = true;
      }
      if (changes.status.present) {
        payload.status = changes.status.value.index;
        hasChanges = true;
      }

      if (!hasChanges) return;

      // Get student name for resource display.
      String resourceName = 'Student #$adm';
      if (changes.name.present) {
        resourceName = changes.name.value;
      } else {
        final existing = await getStudent(schoolId, adm);
        if (existing != null) resourceName = existing.name;
      }

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateStudent),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
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

  /// Removes a student row from the local database and enqueues a
  /// [SyncAction.deleteStudent] log with [DeleteStudentPayload].
  ///
  /// Follows the same hard-delete pattern as [removeTeacher], [removeStaff],
  /// etc. — the row is deleted locally and the sync engine replays the
  /// deletion to the server when online.
  Future<void> removeStudent({
    required String schoolId,
    required int adm,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      // Get student name for resource display before deletion.
      final student = await getStudent(schoolId, adm);
      final resourceName = student?.name ?? 'Student #$adm';

      final payload = sync_pb.DeleteStudentPayload(school: schoolId, adm: adm);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteStudent),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
      await (delete(
        students,
      )..where((t) => t.school.equals(schoolId) & t.adm.equals(adm))).go();
    });
    sync.schedulePush();
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
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createGuardian,
      schoolId: guardian.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await into(users).insert(newUser);

      final guardianWithTimestamp = guardian.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(guardians).insert(guardianWithTimestamp);

      final schoolId = guardian.school.value;
      final studentAdm = guardian.student.value;

      final payload = sync_pb.CreateGuardianPayload(
        school: schoolId,
        userId: newUser.id.value,
        phone: newUser.phone.value,
        name: newUser.name.value,
        student: studentAdm,
        relationship: guardian.relationship.value.index,
      );
      if (newUser.email.present && newUser.email.value != null) {
        payload.email = newUser.email.value!;
      }
      if (guardian.role.present) {
        payload.role = guardian.role.value.index;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createGuardian),
          resource: Value(newUser.phone.value),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Links an existing user as a guardian of [studentAdm].
  Future<void> addExistingUserAsGuardian({
    required GuardiansCompanion guardian,
    required UsersData existingUser,
    required String accountId,
  }) async {
    final authResult = await authorization.check(
      action: SyncAction.createGuardian,
      schoolId: guardian.school.value,
      recordId: null,
    );
    if (!authResult.allowed) throw PermissionException(authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      final guardianWithTimestamp = guardian.copyWith(
        created: Value(nowSec),
        updated: Value(nowSec),
      );
      await into(guardians).insert(guardianWithTimestamp);

      final schoolId = guardian.school.value;
      final studentAdm = guardian.student.value;

      final payload = sync_pb.CreateGuardianPayload(
        school: schoolId,
        userId: existingUser.id,
        phone: existingUser.phone,
        name: existingUser.name,
        student: studentAdm,
        relationship: guardian.relationship.value.index,
      );
      if (existingUser.email != null) {
        payload.email = existingUser.email!;
      }
      if (guardian.role.present) {
        payload.role = guardian.role.value.index;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createGuardian),
          resource: Value(existingUser.phone),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates mutable fields on a guardian row and writes a log entry with
  /// [SyncAction.updateGuardian] containing an [UpdateGuardianPayload].
  Future<void> updateGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    required GuardiansCompanion changes,
    required String accountId,
  }) async {
    await transaction(() async {
      await (update(guardians)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.user.equals(userId) &
                t.student.equals(studentAdm),
          ))
          .write(changes);

      final payload = sync_pb.UpdateGuardianPayload(
        school: schoolId,
        user: userId,
        student: studentAdm,
      );
      bool hasChanges = false;

      if (changes.relationship.present) {
        payload.relationship = changes.relationship.value.index;
        hasChanges = true;
      }
      if (changes.role.present) {
        payload.role = changes.role.value.index;
        hasChanges = true;
      }

      if (!hasChanges) return;

      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateGuardian),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Removes a guardian row and enqueues a delete log entry.
  Future<void> removeGuardian({
    required String schoolId,
    required String userId,
    required int studentAdm,
    required String accountId,
  }) async {
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final user = await findUserById(userId);
      final resourceName = user?.phone ?? userId;

      final payload = sync_pb.DeleteGuardianPayload(
        school: schoolId,
        user: userId,
        student: studentAdm,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteGuardian),
          resource: Value(resourceName),
          payload: Value(payload.writeToBuffer()),
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
    sync.schedulePush();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Student queries (list, search, detail)
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the list of ALL [StudentsData] for [schoolId] ordered by
  /// admission number ascending. Includes all statuses (active, expelled, etc.).
  /// Re-emits on every change.
  Stream<List<StudentsData>> watchAllStudents(String schoolId) =>
      (select(students)
            ..where((t) => t.school.equals(schoolId))
            ..orderBy([(t) => OrderingTerm.asc(t.adm)]))
          .watch();

  /// Searches students at [schoolId] by name (case-insensitive contains) or
  /// admission number (exact match). Only returns active students.
  /// Returns a one-shot list, not a stream — this is for search-as-you-type.
  Future<List<StudentsData>> searchStudents(
    String schoolId,
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) {
      return (select(students)
            ..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.status.equals(StudentStatus.active.index),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.adm)])
            ..limit(50))
          .get();
    }

    final admNum = int.tryParse(q);

    // Name search (case-insensitive LIKE)
    final nameResults =
        await (select(students)
              ..where(
                (t) =>
                    t.school.equals(schoolId) &
                    t.status.equals(StudentStatus.active.index) &
                    t.name.like('%$q%'),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.adm)])
              ..limit(50))
            .get();

    if (admNum != null) {
      final admResults =
          await (select(students)..where(
                (t) =>
                    t.school.equals(schoolId) &
                    t.status.equals(StudentStatus.active.index) &
                    t.adm.equals(admNum),
              ))
              .get();
      // Merge, deduplicate by adm
      final seen = <int>{};
      final merged = <StudentsData>[];
      for (final s in [...admResults, ...nameResults]) {
        if (seen.add(s.adm)) merged.add(s);
      }
      return merged;
    }

    return nameResults;
  }

  /// Reactively watches a single student row by [schoolId] and [adm].
  /// Returns `null` if the student does not exist.
  Stream<StudentsData?> watchStudent(String schoolId, int adm) =>
      (select(students)
            ..where((t) => t.school.equals(schoolId) & t.adm.equals(adm)))
          .watchSingleOrNull();

  // ─────────────────────────────────────────────────────────────────────────
  // Teacher assignment queries (class teacher + subjects)
  // ─────────────────────────────────────────────────────────────────────────

  /// Watches all class_teachers rows for a teacher at a school, across all
  /// years/terms. Ordered by year descending, then grade ascending.
  Stream<List<ClassTeacher>> watchClassTeacherAssignments(
    String schoolId,
    String teacherUserId,
  ) =>
      (select(classTeachers)
            ..where(
              (t) =>
                  t.school.equals(schoolId) & t.teacher.equals(teacherUserId),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.year),
              (t) => OrderingTerm.asc(t.grade),
            ]))
          .watch();

  /// Watches all subjects rows assigned to a teacher at a school, across all
  /// years/terms. Ordered by year descending, then grade ascending.
  Stream<List<SubjectTeacher>> watchTeacherSubjects(
    String schoolId,
    String teacherUserId,
  ) =>
      (select(subjectTeachers)
            ..where(
              (t) =>
                  t.school.equals(schoolId) & t.teacher.equals(teacherUserId),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.year),
              (t) => OrderingTerm.asc(t.grade),
            ]))
          .watch();

  /// Watches subjects assigned to a teacher at a school for a **specific**
  /// year/term. Used by the overview quick-stats to build a live subject set.
  Stream<List<SubjectTeacher>> watchTeacherSubjectsForTerm(
    String schoolId,
    String teacherUserId, {
    required int year,
    required int term,
  }) =>
      (select(subjectTeachers)
            ..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.teacher.equals(teacherUserId) &
                  t.year.equals(year) &
                  t.term.equals(term),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.grade)]))
          .watch();

  /// Reactive count of **distinct subjects** assigned to [teacherUserId] at
  /// [schoolId] for the given [year] and [term].
  ///
  /// Returns a `Stream<int>` that re-emits whenever `subject_teachers` changes.
  Stream<int> watchTeacherSubjectCount(
    String schoolId,
    String teacherUserId, {
    required int year,
    required int term,
  }) {
    final countExpr = subjectTeachers.subject.count(distinct: true);
    final query = selectOnly(subjectTeachers)
      ..addColumns([countExpr])
      ..where(
        subjectTeachers.school.equals(schoolId) &
            subjectTeachers.teacher.equals(teacherUserId) &
            subjectTeachers.year.equals(year) &
            subjectTeachers.term.equals(term),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Unique guardians + ward queries
  // ─────────────────────────────────────────────────────────────────────────

  /// Watches all guardians for [schoolId] and deduplicates by user ID.
  /// Returns a list of unique `(user, wardCount)` records — one per distinct
  /// guardian user, regardless of how many students they are linked to.
  Stream<List<({UsersData user, int wardCount})>> watchUniqueGuardians(
    String schoolId,
  ) {
    return watchAllGuardians(schoolId).asyncMap((all) async {
      final byUser = <String, int>{};
      for (final g in all) {
        byUser[g.user] = (byUser[g.user] ?? 0) + 1;
      }
      final results = <({UsersData user, int wardCount})>[];
      for (final entry in byUser.entries) {
        final u = await findUserById(entry.key);
        if (u != null) results.add((user: u, wardCount: entry.value));
      }
      return results;
    });
  }

  /// Returns all guardian links for a specific user at a school, paired with
  /// their student (ward) data. One entry per guardian row.
  Stream<List<({GuardiansData guardian, StudentsData? student})>>
  watchGuardianWards(String schoolId, String guardianUserId) {
    return (select(guardians)..where(
          (t) => t.school.equals(schoolId) & t.user.equals(guardianUserId),
        ))
        .watch()
        .asyncMap((guardianRows) async {
          final results = <({GuardiansData guardian, StudentsData? student})>[];
          for (final g in guardianRows) {
            final student = await getStudent(schoolId, g.student);
            results.add((guardian: g, student: student));
          }
          return results;
        });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Class teacher check
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns `true` if [teacherUserId] is the active class teacher for the
  /// given grade/stream in the specified school/year/term.
  ///
  /// "Active" means a row exists in [ClassTeachers] with `end IS NULL`
  /// (the teacher has not been replaced).
  Future<bool> isClassTeacherFor({
    required String schoolId,
    required int year,
    required int term,
    required int grade,
    required int stream,
    required String teacherUserId,
  }) async {
    final row =
        await (select(classTeachers)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.year.equals(year) &
                  t.term.equals(term) &
                  t.grade.equals(grade) &
                  t.stream.equals(stream) &
                  t.teacher.equals(teacherUserId) &
                  t.end.isNull(),
            ))
            .getSingleOrNull();
    return row != null;
  }
}
