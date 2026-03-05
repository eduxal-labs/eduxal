import 'dart:async';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/enums.dart';
import '../tables/logs.dart';
import '../tables/owners.dart';
import '../tables/roles.dart';
import '../tables/scopes.dart';
import '../tables/staff.dart';
import '../tables/teachers.dart';
import '../tables/users.dart';

part 'school_scopes_dao.g.dart';

/// DAO for managing school-scoped [Roles] and [Scopes] rows.
///
/// A school-scoped role has `roles.school = schoolId` (as opposed to
/// system-level roles where `roles.school IS NULL`).  A school-scoped scope
/// has `scopes.school = schoolId`.
///
/// All mutating methods write a corresponding [Logs] entry inside the same
/// transaction so the sync engine can replay mutations to the server when
/// connectivity is restored.
@DriftAccessor(tables: [Roles, Scopes, Users, Logs, Teachers, Staff, Owners])
class SchoolScopesDao extends DatabaseAccessor<AppDatabase>
    with _$SchoolScopesDaoMixin {
  SchoolScopesDao(super.db);

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — roles
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits all school-scoped roles for [schoolId], ordered by name ascending.
  ///
  /// Re-emits on any change to the [Roles] table for matching rows.
  Stream<List<Role>> watchSchoolRoles(String schoolId) {
    return (select(roles)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Emits all school-scoped roles for [schoolId] that are **not yet**
  /// assigned to [userId] via a school-scoped scope.
  ///
  /// Used by the "assign role" picker on the staff/teacher permissions sheet.
  Stream<List<Role>> watchEligibleRolesForUser(String schoolId, String userId) {
    final assignedSubquery = selectOnly(scopes)
      ..addColumns([scopes.role])
      ..where(scopes.school.equals(schoolId) & scopes.user.equals(userId));

    return (select(roles)
          ..where(
            (r) =>
                r.school.equals(schoolId) & r.id.isNotInQuery(assignedSubquery),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .watch();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive streams — scopes (user ↔ role assignments)
  // ─────────────────────────────────────────────────────────────────────────

  /// Emits all (scope, role) pairs assigned to [userId] at [schoolId],
  /// ordered by role name ascending.
  ///
  /// Re-emits on any change to [Scopes] or [Roles] for matching rows.
  Stream<List<({Scope scope, Role role})>> watchScopesForUser(
    String schoolId,
    String userId,
  ) {
    final query =
        select(scopes).join([innerJoin(roles, roles.id.equalsExp(scopes.role))])
          ..where(scopes.school.equals(schoolId) & scopes.user.equals(userId))
          ..orderBy([OrderingTerm.asc(roles.name)]);

    return query.watch().map((rows) {
      return rows.map((r) {
        return (scope: r.readTable(scopes), role: r.readTable(roles));
      }).toList();
    });
  }

  /// Emits all (scope, user) pairs assigned to [roleId] at [schoolId],
  /// ordered by user name ascending.
  ///
  /// Re-emits on any change to [Scopes] or [Users] for matching rows.
  Stream<List<({Scope scope, UsersData user})>> watchUsersForRole(
    String schoolId,
    String roleId,
  ) {
    final query =
        select(scopes).join([innerJoin(users, users.id.equalsExp(scopes.user))])
          ..where(scopes.school.equals(schoolId) & scopes.role.equals(roleId))
          ..orderBy([OrderingTerm.asc(users.name)]);

    return query.watch().map((rows) {
      return rows
          .map((r) => (scope: r.readTable(scopes), user: r.readTable(users)))
          .toList();
    });
  }

  /// Emits every (user, list-of-roles) aggregation for users at [schoolId]
  /// who have at least one school-scoped scope.
  ///
  /// The result is a flat list of (scope, user, role) triples.  The UI groups
  /// by user to display each person's assigned roles as chips.  Re-emits on
  /// any change to [Scopes], [Roles], or [Users].
  Stream<List<({Scope scope, UsersData user, Role role})>> watchAllScopes(
    String schoolId,
  ) {
    final query =
        select(scopes).join([
            innerJoin(users, users.id.equalsExp(scopes.user)),
            innerJoin(roles, roles.id.equalsExp(scopes.role)),
          ])
          ..where(scopes.school.equals(schoolId))
          ..orderBy([
            OrderingTerm.asc(users.name),
            OrderingTerm.asc(roles.name),
          ]);

    return query.watch().map((rows) {
      return rows
          .map(
            (r) => (
              scope: r.readTable(scopes),
              user: r.readTable(users),
              role: r.readTable(roles),
            ),
          )
          .toList();
    });
  }

  /// Emits school members (owners, teachers, staff) at [schoolId] who are
  /// **not** already assigned to [roleId] via a school-scoped scope.
  ///
  /// Used by the "Assign user" sheet on the school role detail screen to show
  /// only eligible candidates.  The stream unions user IDs from [Owners],
  /// [Teachers], and [Staff] for the school, excludes those already assigned
  /// to [roleId], then resolves the [Users] rows.
  ///
  /// Re-emits on any change to [Owners], [Teachers], [Staff], [Scopes], or
  /// [Users] for matching rows.
  Stream<List<UsersData>> watchEligibleSchoolUsers(
    String schoolId,
    String roleId,
  ) {
    // Owner user IDs at this school.
    final ownerIds = (select(owners)..where((t) => t.school.equals(schoolId)))
        .watch()
        .map<Set<String>>((rows) => rows.map((r) => r.user).toSet());

    // Teacher user IDs at this school.
    final teacherIds =
        (select(teachers)..where((t) => t.school.equals(schoolId)))
            .watch()
            .map<Set<String>>((rows) => rows.map((r) => r.user).toSet());

    // Staff user IDs at this school.
    final staffIds = (select(staff)..where((t) => t.school.equals(schoolId)))
        .watch()
        .map<Set<String>>((rows) => rows.map((r) => r.user).toSet());

    // Already-assigned user IDs (reactive).
    final assignedIds =
        (select(scopes)
              ..where((t) => t.school.equals(schoolId) & t.role.equals(roleId)))
            .watch()
            .map<Set<String>>((rows) => rows.map((r) => r.user).toSet());

    // Combine all four streams and resolve eligible users.
    return _combineLatest4(
      ownerIds,
      teacherIds,
      staffIds,
      assignedIds,
    ).asyncMap((record) async {
      final allMemberIds = <String>{
        ...record.owners,
        ...record.teachers,
        ...record.staff,
      };
      final eligible = allMemberIds.difference(record.assigned);
      if (eligible.isEmpty) return <UsersData>[];
      return (select(users)
            ..where((u) => u.id.isIn(eligible))
            ..orderBy([(u) => OrderingTerm.asc(u.name)]))
          .get();
    });
  }

  /// Combines four streams into a single stream of a named record.
  ///
  /// Emits whenever any of the four input streams emits, once all four have
  /// emitted at least once.
  Stream<
    ({
      Set<String> owners,
      Set<String> teachers,
      Set<String> staff,
      Set<String> assigned,
    })
  >
  _combineLatest4(
    Stream<Set<String>> ownersStream,
    Stream<Set<String>> teachersStream,
    Stream<Set<String>> staffStream,
    Stream<Set<String>> assignedStream,
  ) {
    Set<String> latestOwners = {};
    Set<String> latestTeachers = {};
    Set<String> latestStaff = {};
    Set<String> latestAssigned = {};
    int arrived = 0; // bit flags: 0b1111 when all have emitted

    late StreamController<
      ({
        Set<String> owners,
        Set<String> teachers,
        Set<String> staff,
        Set<String> assigned,
      })
    >
    controller;

    StreamSubscription<Set<String>>? subO;
    StreamSubscription<Set<String>>? subT;
    StreamSubscription<Set<String>>? subS;
    StreamSubscription<Set<String>>? subA;

    void emit() {
      if (arrived == 0x0F) {
        controller.add((
          owners: latestOwners,
          teachers: latestTeachers,
          staff: latestStaff,
          assigned: latestAssigned,
        ));
      }
    }

    controller = StreamController(
      onListen: () {
        subO = ownersStream.listen((v) {
          latestOwners = v;
          arrived |= 0x01;
          emit();
        });
        subT = teachersStream.listen((v) {
          latestTeachers = v;
          arrived |= 0x02;
          emit();
        });
        subS = staffStream.listen((v) {
          latestStaff = v;
          arrived |= 0x04;
          emit();
        });
        subA = assignedStream.listen((v) {
          latestAssigned = v;
          arrived |= 0x08;
          emit();
        });
      },
      onCancel: () {
        subO?.cancel();
        subT?.cancel();
        subS?.cancel();
        subA?.cancel();
      },
    );

    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // One-shot reads
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns all school-scoped roles for [schoolId] in a single query.
  Future<List<Role>> getSchoolRoles(String schoolId) {
    return (select(roles)
          ..where((t) => t.school.equals(schoolId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Returns a single role by [roleId], or null.
  Future<Role?> getRole(String roleId) {
    return (select(roles)..where((t) => t.id.equals(roleId))).getSingleOrNull();
  }

  /// Returns all scopes for [userId] at [schoolId].
  Future<List<Scope>> getScopesForUser(String schoolId, String userId) {
    return (select(
      scopes,
    )..where((t) => t.school.equals(schoolId) & t.user.equals(userId))).get();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes — roles
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new school-scoped role and enqueues a log insert entry.
  ///
  /// [companion] must have:
  ///   - [RolesCompanion.id]          — caller generates via `Uuid().v4()`
  ///   - [RolesCompanion.school]      — set to [schoolId]
  ///   - [RolesCompanion.name]
  ///   - [RolesCompanion.permissions] — JSON-encoded permissions map
  ///   - [RolesCompanion.created] and [RolesCompanion.updated]
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> createRole(
    RolesCompanion companion, {
    required String accountId,
  }) {
    return transaction(() async {
      await into(roles).insert(companion);

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.roles),
          op: const Value(LogOperation.insert),
          rowKey: companion.id,
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Updates [name], [description], and/or [permissions] on an existing role
  /// and writes a log update entry with the correct [RolesColumn] bitmask.
  ///
  /// Only the fields present in [changes] are updated.
  /// [changes] must include [RolesCompanion.updated] with the current
  /// timestamp (seconds since epoch).
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> updateRole(
    String roleId,
    RolesCompanion changes, {
    required String accountId,
  }) {
    return transaction(() async {
      await (update(roles)..where((t) => t.id.equals(roleId))).write(changes);

      int mask = 0;
      if (changes.name.present) mask |= (1 << RolesColumn.name.bit);
      if (changes.description.present) {
        mask |= (1 << RolesColumn.description.bit);
      }
      if (changes.permissions.present) {
        mask |= (1 << RolesColumn.permissions.bit);
      }
      if (changes.updated.present) mask |= (1 << RolesColumn.updated.bit);

      if (mask == 0) return;

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.roles),
          op: const Value(LogOperation.update),
          rowKey: Value(roleId),
          columns: Value(mask),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Deletes a school-scoped role and writes a log delete entry.
  ///
  /// All [Scopes] rows referencing this role cascade-delete automatically due
  /// to the FK `ON DELETE CASCADE`.  The sync engine will handle reconciling
  /// those scope deletions server-side.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> deleteRole(String roleId, {required String accountId}) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.roles),
          op: const Value(LogOperation.delete),
          rowKey: Value(roleId),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      // Supersede any pending insert/update logs for the same role row.
      await (delete(logs)..where(
            (t) =>
                t.account.equals(accountId) &
                t.tbl.equalsValue(LogTable.roles) &
                t.rowKey.equals(roleId) &
                (t.op.equalsValue(LogOperation.insert) |
                    t.op.equalsValue(LogOperation.update)),
          ))
          .go();

      await (delete(roles)..where((t) => t.id.equals(roleId))).go();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local mutation writes — scopes (role assignments)
  // ─────────────────────────────────────────────────────────────────────────

  /// Assigns [roleId] to [userId] at [schoolId] by inserting a scope row and
  /// enqueuing a log insert entry.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> assignRole({
    required String schoolId,
    required String userId,
    required String roleId,
    required String accountId,
  }) {
    return transaction(() async {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await into(scopes).insert(
        ScopesCompanion(
          school: Value(schoolId),
          user: Value(userId),
          role: Value(roleId),
          created: Value(nowSeconds),
        ),
      );

      // Row key format: "schoolId|userId|roleId"
      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.scopes),
          op: const Value(LogOperation.insert),
          rowKey: Value('$schoolId|$userId|$roleId'),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );
    });
  }

  /// Removes the scope that assigns [roleId] to [userId] at [schoolId] and
  /// enqueues a log delete entry.
  ///
  /// If no matching scope exists, this is a no-op.
  ///
  /// [accountId] is the currently active account's user id.
  Future<void> unassignRole({
    required String schoolId,
    required String userId,
    required String roleId,
    required String accountId,
  }) {
    return transaction(() async {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final rowKey = '$schoolId|$userId|$roleId';

      await into(logs).insert(
        LogsCompanion(
          account: Value(accountId),
          tbl: const Value(LogTable.scopes),
          op: const Value(LogOperation.delete),
          rowKey: Value(rowKey),
          status: const Value(LogStatus.pending),
          created: Value(nowMs),
        ),
      );

      // Supersede any pending insert log for the same scope row.
      await (delete(logs)..where(
            (t) =>
                t.account.equals(accountId) &
                t.tbl.equalsValue(LogTable.scopes) &
                t.rowKey.equals(rowKey) &
                t.op.equalsValue(LogOperation.insert),
          ))
          .go();

      await (delete(scopes)..where(
            (t) =>
                t.school.equals(schoolId) &
                t.user.equals(userId) &
                t.role.equals(roleId),
          ))
          .go();
    });
  }
}
