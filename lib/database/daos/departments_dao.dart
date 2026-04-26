import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/departments.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/staff.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../../client.dart';
import '../../proto/services/sync.pb.dart' as sync_pb;
import '../../services/authorization_service.dart';

part 'departments_dao.g.dart';

/// DAO for the [Departments] table.
///
/// Covers school-scoped departments — create, read, update, delete — plus
/// reactive streams for listing teachers and staff within a department.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay it to the server when
/// connectivity is restored.
@DriftAccessor(tables: [Departments, Teachers, Staff, Users, Logs])
class DepartmentsDao extends DatabaseAccessor<AppDatabase>
    with _$DepartmentsDaoMixin {
  DepartmentsDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits the full list of departments for [schoolId], ordered
  /// alphabetically, whenever the [Departments] table changes.
  Stream<List<Department>> watchDepartments(String schoolId) {
    return (select(departments)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Emits every (teacher row, user row) pair for [schoolId] that belongs to
  /// [departmentName], ordered by user name ascending.
  ///
  /// Re-emits on any change to [Teachers] or [Users].
  Stream<List<({TeachersData teacher, UsersData user})>> watchTeachersInDept(
    String schoolId,
    String departmentName,
  ) {
    final query =
        select(
            teachers,
          ).join([innerJoin(users, users.id.equalsExp(teachers.user))])
          ..where(
            teachers.school.equals(schoolId) &
                teachers.department.equals(departmentName),
          )
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (teacher: r.readTable(teachers), user: r.readTable(users)),
          )
          .toList(),
    );
  }

  /// Emits every (staff row, user row) pair for [schoolId] that belongs to
  /// [departmentName], ordered by user name ascending.
  ///
  /// Re-emits on any change to [Staff] or [Users].
  Stream<List<({StaffData staff, UsersData user})>> watchStaffInDept(
    String schoolId,
    String departmentName,
  ) {
    final query =
        select(staff).join([innerJoin(users, users.id.equalsExp(staff.user))])
          ..where(
            staff.school.equals(schoolId) &
                staff.department.equals(departmentName),
          )
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map(
      (rows) => rows
          .map((r) => (staff: r.readTable(staff), user: r.readTable(users)))
          .toList(),
    );
  }

  /// Emits every (teacher row, user row) pair for [schoolId] that has
  /// NO department assigned, ordered by user name ascending.
  ///
  /// Used by the "assign to department" picker so only unassigned teachers
  /// are shown as candidates.
  Stream<List<({TeachersData teacher, UsersData user})>>
  watchUnassignedTeachers(String schoolId) {
    final query =
        select(
            teachers,
          ).join([innerJoin(users, users.id.equalsExp(teachers.user))])
          ..where(
            teachers.school.equals(schoolId) & teachers.department.isNull(),
          )
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => (teacher: r.readTable(teachers), user: r.readTable(users)),
          )
          .toList(),
    );
  }

  /// Emits every (staff row, user row) pair for [schoolId] that has
  /// NO department assigned, ordered by user name ascending.
  Stream<List<({StaffData staff, UsersData user})>> watchUnassignedStaff(
    String schoolId,
  ) {
    final query =
        select(staff).join([innerJoin(users, users.id.equalsExp(staff.user))])
          ..where(staff.school.equals(schoolId) & staff.department.isNull())
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map(
      (rows) => rows
          .map((r) => (staff: r.readTable(staff), user: r.readTable(users)))
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns all departments for [schoolId] ordered alphabetically, once.
  Future<List<Department>> getDepartments(String schoolId) {
    return (select(departments)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Returns a single department by its (school, name) primary key, or null.
  Future<Department?> getDepartment(String schoolId, String name) {
    return (select(departments)
          ..where((t) => t.school.equals(schoolId) & t.name.equals(name)))
        .getSingleOrNull();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes
  // ─────────────────────────────────────────────────────────────────────────

  /// Inserts a new department row and enqueues a [SyncAction.createDepartment]
  /// log entry, both in a single transaction.
  ///
  /// [accountId] is the currently active account's user id.
  ///
  /// The [companion] must have:
  ///   - [DepartmentsCompanion.school]
  ///   - [DepartmentsCompanion.name]
  ///   - [DepartmentsCompanion.created] and [DepartmentsCompanion.updated]
  ///     (seconds since epoch)
  Future<void> createDepartment(
    DepartmentsCompanion companion, {
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.createDepartment,
      schoolId: companion.school.value,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      await into(departments).insert(companion);

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final schoolId = companion.school.value;
      final name = companion.name.value;

      final payload = sync_pb.CreateDepartmentPayload(
        school: schoolId,
        name: name,
      );
      if (companion.description.present &&
          companion.description.value != null) {
        payload.description = companion.description.value!;
      }

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.createDepartment),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Updates the description of a department and writes a log update entry.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateDepartmentDescription(
    String schoolId,
    String name, {
    required String? description,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateDepartment,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(
        departments,
      )..where((t) => t.school.equals(schoolId) & t.name.equals(name))).write(
        DepartmentsCompanion(
          description: Value(description),
          updated: Value(nowSeconds),
        ),
      );

      final payload = sync_pb.UpdateDepartmentPayload(
        school: schoolId,
        name: name,
      );
      if (description != null) payload.description = description;

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.updateDepartment),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Assigns [teacherUserId] to [departmentName] (or unassigns when null).
  ///
  /// Updates the [Teachers.department] column and writes a
  /// [SyncAction.updateTeacher] log entry with the department change.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignTeacherToDepartment(
    String schoolId,
    String teacherUserId, {
    required String? departmentName,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateTeacher,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(teachers)..where(
            (t) => t.school.equals(schoolId) & t.user.equals(teacherUserId),
          ))
          .write(
            TeachersCompanion(
              department: Value(departmentName),
              updated: Value(nowSeconds),
            ),
          );

      final payload = sync_pb.UpdateTeacherPayload(
        school: schoolId,
        user: teacherUserId,
      );
      if (departmentName != null) payload.department = departmentName;

      // Get user info for resource display.
      final user = await (select(
        users,
      )..where((t) => t.id.equals(teacherUserId))).getSingleOrNull();
      final resourceName = user?.name ?? teacherUserId;

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

  /// Assigns [staffUserId] to [departmentName] (or unassigns when null).
  ///
  /// Updates the [Staff.department] column and writes a
  /// [SyncAction.updateStaff] log entry with the department change.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignStaffToDepartment(
    String schoolId,
    String staffUserId, {
    required String? departmentName,
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.updateStaff,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await (update(staff)..where(
            (t) => t.school.equals(schoolId) & t.user.equals(staffUserId),
          ))
          .write(
            StaffCompanion(
              department: Value(departmentName),
              updated: Value(nowSeconds),
            ),
          );

      final payload = sync_pb.UpdateStaffPayload(
        school: schoolId,
        user: staffUserId,
      );
      if (departmentName != null) payload.department = departmentName;

      // Get user info for resource display.
      final user = await (select(
        users,
      )..where((t) => t.id.equals(staffUserId))).getSingleOrNull();
      final resourceName = user?.name ?? staffUserId;

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

  /// Deletes a department row and writes a log delete entry in a single
  /// transaction.
  ///
  /// Teachers and Staff whose department column referenced this department
  /// are NOT automatically unassigned here because the FK is ON DELETE NO
  /// ACTION — callers must re-assign or unassign members before deleting
  /// a department that still has members.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> deleteDepartment(
    String schoolId,
    String name, {
    required String accountId,
  }) async {
    final _authResult = await authorization.check(
      action: SyncAction.deleteDepartment,
      schoolId: schoolId,
      recordId: null,
    );
    if (!_authResult.allowed) throw PermissionException(_authResult.reason!);
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final payload = sync_pb.DeleteDepartmentPayload(
        school: schoolId,
        name: name,
      );

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          action: Value(SyncAction.deleteDepartment),
          resource: Value(name),
          payload: Value(payload.writeToBuffer()),
          created: Value(nowMs),
        ),
      );

      await (delete(
        departments,
      )..where((t) => t.school.equals(schoolId) & t.name.equals(name))).go();
    });
    sync.schedulePush();
  }
}
