import 'dart:async';

import 'package:async/async.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database.dart';
import '../tables/guardians.dart';
import '../tables/owners.dart';
import '../tables/schools.dart';
import '../tables/staff.dart';
import '../tables/students.dart';
import '../tables/subject_teachers.dart';
import '../tables/teachers.dart';
import '../tables/terms.dart';
import '../../models/membership.dart';

part 'memberships_dao.g.dart';

/// DAO that assembles [SchoolMembership] objects for a given user by querying
/// the five membership tables (`owners`, `teachers`, `staff`, `students`,
/// `guardians`) and joining the results with `schools`.
///
/// This is the single reactive source for the home-screen membership picker.
/// Gemini's UI binds to [watchMemberships] and re-renders whenever any
/// membership row or school row changes.
@DriftAccessor(
  tables: [
    Owners,
    Teachers,
    Staff,
    Students,
    Guardians,
    Schools,
    SubjectTeachers,
    Terms,
  ],
)
class MembershipsDao extends DatabaseAccessor<AppDatabase>
    with _$MembershipsDaoMixin {
  MembershipsDao(super.db);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// A reactive stream that emits a fully assembled list of [SchoolMembership]
  /// objects for [userId] whenever any relevant table changes.
  ///
  /// Each [SchoolMembership] groups all of the user's navigation entries for a
  /// single school. The list is ordered by school name (ascending).
  ///
  /// The stream emits the current state immediately on subscription, then again
  /// on every change to any of: `owners`, `teachers`, `staff`, `students`,
  /// `guardians`, `schools`, `subjects`, or `terms`.
  Stream<List<SchoolMembership>> watchMemberships(String userId) async* {
    // Emit the current state immediately.
    yield await _fetchMemberships(userId);

    // Re-emit on any change to any of the tables involved in the query.
    // Drift's TableUpdateQuery only targets a single table at a time, so we
    // merge per-table streams into one using StreamGroup.
    final merged = StreamGroup.merge([
      db.tableUpdates(TableUpdateQuery.onTable(db.owners)),
      db.tableUpdates(TableUpdateQuery.onTable(db.teachers)),
      db.tableUpdates(TableUpdateQuery.onTable(db.staff)),
      db.tableUpdates(TableUpdateQuery.onTable(db.students)),
      db.tableUpdates(TableUpdateQuery.onTable(db.guardians)),
      db.tableUpdates(TableUpdateQuery.onTable(db.schools)),
      db.tableUpdates(TableUpdateQuery.onTable(db.subjectTeachers)),
      db.tableUpdates(TableUpdateQuery.onTable(db.terms)),
    ]);

    await for (final _ in merged) {
      yield await _fetchMemberships(userId);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetches and assembles the full list of [SchoolMembership] objects for
  /// [userId] in a single async operation.
  ///
  /// Steps:
  /// 1. Query each of the five membership tables for rows matching [userId].
  /// 2. Collect the full set of referenced school IDs.
  /// 3. Fetch all those school rows in one IN query.
  /// 4. For teacher rows, compute the subject count in the current term.
  /// 5. For guardian rows, load each ward's [StudentsData] row.
  /// 6. Group all entries by school and build [SchoolMembership] objects.
  Future<List<SchoolMembership>> _fetchMemberships(String userId) async {
    // ── 1. Fetch all membership rows for this user ───────────────────────────

    final ownerRows = await (select(
      owners,
    )..where((t) => t.user.equals(userId))).get();

    final teacherRows = await (select(
      teachers,
    )..where((t) => t.user.equals(userId))).get();

    final staffRows = await (select(
      staff,
    )..where((t) => t.user.equals(userId))).get();

    // Students link to a user only when their `user` column is non-null.
    final studentRows = await (select(
      students,
    )..where((t) => t.user.equals(userId))).get();

    final guardianRows = await (select(
      guardians,
    )..where((t) => t.user.equals(userId))).get();

    // ── 2. Collect all referenced school IDs ────────────────────────────────

    final schoolIds = <String>{
      for (final r in ownerRows) r.school,
      for (final r in teacherRows) r.school,
      for (final r in staffRows) r.school,
      for (final r in studentRows) r.school,
      for (final r in guardianRows) r.school,
    };

    if (schoolIds.isEmpty) return const [];

    // ── 3. Fetch all referenced schools in one query ─────────────────────────

    final schoolList = await (select(
      schools,
    )..where((t) => t.id.isIn(schoolIds))).get();

    // Build a lookup map for O(1) access when assembling entries.
    final schoolMap = {for (final s in schoolList) s.id: s};

    // ── 4 & 5. Build per-school entry lists ──────────────────────────────────

    // Track skipped entries for diagnostic logging.
    var skippedCount = 0;

    // Map from schoolId → mutable entry list assembled below.
    final entriesMap = <String, List<MembershipEntry>>{};

    void addEntry(String schoolId, MembershipEntry entry) {
      entriesMap.putIfAbsent(schoolId, () => []).add(entry);
    }

    // Owners — no extra data needed.
    for (final owner in ownerRows) {
      if (!schoolMap.containsKey(owner.school)) {
        debugPrint(
          '[MembershipsDao] SKIPPED owner ${owner.user} — school ${owner.school} not in local DB yet',
        );
        skippedCount++;
        continue;
      }
      addEntry(owner.school, OwnerEntry(owner: owner));
    }

    // Teachers — requires subject count for the current active term.
    for (final teacher in teacherRows) {
      if (!schoolMap.containsKey(teacher.school)) {
        debugPrint(
          '[MembershipsDao] SKIPPED teacher ${teacher.user} — school ${teacher.school} not in local DB yet',
        );
        skippedCount++;
        continue;
      }
      final count = await _subjectCount(teacher.school, userId);
      addEntry(
        teacher.school,
        TeacherEntry(teacher: teacher, subjectCount: count),
      );
    }

    // Staff — no extra data needed.
    for (final member in staffRows) {
      if (!schoolMap.containsKey(member.school)) {
        debugPrint(
          '[MembershipsDao] SKIPPED staff ${member.user} — school ${member.school} not in local DB yet',
        );
        skippedCount++;
        continue;
      }
      addEntry(member.school, StaffEntry(staff: member));
    }

    // Students — no extra data needed (the row itself carries all display info).
    for (final student in studentRows) {
      if (!schoolMap.containsKey(student.school)) {
        debugPrint(
          '[MembershipsDao] SKIPPED student ${student.user ?? student.adm} — school ${student.school} not in local DB yet',
        );
        skippedCount++;
        continue;
      }
      addEntry(student.school, StudentEntry(student: student));
    }

    // Guardians — each guardian entry is expanded per ward (one entry per
    // student the guardian is responsible for at that school).
    for (final guardian in guardianRows) {
      if (!schoolMap.containsKey(guardian.school)) {
        debugPrint(
          '[MembershipsDao] SKIPPED guardian ${guardian.user} — school ${guardian.school} not in local DB yet',
        );
        skippedCount++;
        continue;
      }

      final ward =
          await (select(students)..where(
                (t) =>
                    t.school.equals(guardian.school) &
                    t.adm.equals(guardian.student),
              ))
              .getSingleOrNull();

      if (ward == null) {
        debugPrint(
          'MembershipsDao: Guardian ${guardian.user} references missing student ${guardian.student} at school ${guardian.school} — skipping',
        );
        continue;
      }

      addEntry(guardian.school, GuardianEntry(guardian: guardian, ward: ward));
    }

    // ── 6. Group into SchoolMembership objects ───────────────────────────────

    final memberships = <SchoolMembership>[];

    for (final schoolId in entriesMap.keys) {
      final school = schoolMap[schoolId];
      if (school == null) continue;

      final entries = entriesMap[schoolId]!;

      // Deduplicate roles, preserving display order:
      // owner → teacher → staff → student → guardian.
      final roles = <MembershipRole>[];
      final seenRoles = <MembershipRole>{};
      for (final entry in entries) {
        if (seenRoles.add(entry.role)) {
          roles.add(entry.role);
        }
      }
      // Sort roles by canonical display order.
      roles.sort((a, b) => a.index.compareTo(b.index));

      memberships.add(
        SchoolMembership(school: school, roles: roles, entries: entries),
      );
    }

    // Sort the final list by school name for consistent ordering.
    memberships.sort((a, b) => a.school.name.compareTo(b.school.name));

    if (skippedCount > 0) {
      debugPrint(
        '[MembershipsDao] WARNING: $skippedCount membership entries skipped due to missing school rows. '
        'This is expected during delta sync batching — the stream will re-emit when the school row arrives.',
      );
    }

    return memberships;
  }

  /// Counts the number of subjects assigned to [teacherId] at [schoolId] in
  /// the current active term (the term whose `start <= now <= end`).
  ///
  /// Returns 0 if no active term exists for [schoolId].
  ///
  /// The `terms.start` and `terms.end` columns are stored as seconds since
  /// Unix epoch (bigint).
  Future<int> _subjectCount(String schoolId, String teacherId) async {
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Find the current active term for this school.
    final currentTerm =
        await (select(terms)..where(
              (t) =>
                  t.school.equals(schoolId) &
                  t.start.isSmallerOrEqualValue(nowSeconds) &
                  t.end.isBiggerOrEqualValue(nowSeconds),
            ))
            .getSingleOrNull();

    if (currentTerm == null) return 0;

    // Count subjects taught by this teacher in the current term.
    final countExpr = subjectTeachers.subject.count();
    final query = selectOnly(subjectTeachers)
      ..addColumns([countExpr])
      ..where(
        subjectTeachers.school.equals(schoolId) &
            subjectTeachers.year.equals(currentTerm.year) &
            subjectTeachers.term.equals(currentTerm.term) &
            subjectTeachers.teacher.equals(teacherId),
      );

    final result = await query.getSingleOrNull();
    return result?.read(countExpr) ?? 0;
  }
}
