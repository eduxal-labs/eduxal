import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/departments.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/staff.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';
import '../../client.dart';

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

  /// Inserts a new department row and enqueues a [LogTable.departments] insert
  /// entry, both in a single transaction.
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
    await transaction(() async {
      await into(departments).insert(companion);

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final rowKey = '${companion.school.value}|${companion.name.value}';

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.departments),
          op: const Value(LogOperation.insert),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
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

      int mask = 0;
      mask |= (1 << DepartmentsColumn.description.bit);
      mask |= (1 << DepartmentsColumn.updated.bit);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.departments),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$name'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Assigns [teacherUserId] to [departmentName] (or unassigns when null).
  ///
  /// Updates the [Teachers.department] column and writes a log update entry
  /// for [LogTable.teachers] with the [TeachersColumn.department] bit set.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignTeacherToDepartment(
    String schoolId,
    String teacherUserId, {
    required String? departmentName,
    required String accountId,
  }) async {
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

      int mask = 0;
      mask |= (1 << TeachersColumn.department.bit);
      mask |= (1 << TeachersColumn.updated.bit);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.teachers),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$teacherUserId'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
    sync.schedulePush();
  }

  /// Assigns [staffUserId] to [departmentName] (or unassigns when null).
  ///
  /// Updates the [Staff.department] column and writes a log update entry
  /// for [LogTable.staff] with the [StaffColumn.department] bit set.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignStaffToDepartment(
    String schoolId,
    String staffUserId, {
    required String? departmentName,
    required String accountId,
  }) async {
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

      int mask = 0;
      mask |= (1 << StaffColumn.department.bit);
      mask |= (1 << StaffColumn.updated.bit);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.staff),
          op: const Value(LogOperation.update),
          rowKey: Value('$schoolId|$staffUserId'),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
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
    await transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final rowKey = '$schoolId|$name';

      // Insert the delete log first — supersedes any pending inserts/updates.
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.departments),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      // Remove superseded pending insert/update entries for the same row.
      await (delete(logs)..where(
            (t) =>
                t.account.equals(accountId) &
                t.tbl.equalsValue(LogTable.departments) &
                t.rowKey.equals(rowKey) &
                (t.op.equalsValue(LogOperation.insert) |
                    t.op.equalsValue(LogOperation.update)),
          ))
          .go();

      await (delete(
        departments,
      )..where((t) => t.school.equals(schoolId) & t.name.equals(name))).go();
    });
    sync.schedulePush();
  }
}
