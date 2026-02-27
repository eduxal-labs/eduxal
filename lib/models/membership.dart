// The generated Drift data classes (OwnersData, TeachersData, etc.) are
// produced by `build_runner` from the table definitions in lib/database/tables/.
// They live in database.g.dart, which is a `part of` database.dart, so
// database.dart is the correct import target.
//
// NOTE: membership.dart imports database.dart, and database.dart must NOT
// import this file (even transitively through daos). MembershipsDao is
// therefore intentionally excluded from @DriftDatabase(daos: [...]) in
// database.dart to avoid a circular import that would break build_runner.
import '../database/database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MembershipRole
// ─────────────────────────────────────────────────────────────────────────────

/// The role a user holds at a particular school.
///
/// One value per membership table. Used as badge labels on home-screen school
/// cards and as navigation-route discriminators inside the school dashboard.
enum MembershipRole { owner, teacher, staff, student, guardian }

// ─────────────────────────────────────────────────────────────────────────────
// MembershipEntry  (sealed — one subtype per role)
// ─────────────────────────────────────────────────────────────────────────────

/// A single navigation entry point into a school dashboard.
///
/// One [MembershipEntry] is created for every distinct navigation target a
/// user has at a given school. Because a guardian can be responsible for
/// multiple students at the same school, guardian entries expand one-per-ward:
/// a user who is guardian to two students at School A gets two
/// [GuardianEntry] instances in the same [SchoolMembership].
///
/// Exhaustive switch on [MembershipEntry]:
/// ```dart
/// switch (entry) {
///   case OwnerEntry():                       ...
///   case TeacherEntry(:final subjectCount):  ...
///   case StaffEntry():                       ...
///   case StudentEntry():                     ...
///   case GuardianEntry(:final ward):         ...
/// }
/// ```
sealed class MembershipEntry {
  const MembershipEntry();

  /// The role this entry represents.
  MembershipRole get role;
}

/// Entry for a school owner.
final class OwnerEntry extends MembershipEntry {
  const OwnerEntry({required this.owner});

  /// The raw Drift data row from the `owners` table.
  final OwnersData owner;

  @override
  MembershipRole get role => MembershipRole.owner;
}

/// Entry for a teacher.
///
/// [subjectCount] is the number of subjects assigned to this teacher in the
/// **current term** (the term whose `start <= now <= end`). Zero if no active
/// term exists. Shown as a badge on the school card.
final class TeacherEntry extends MembershipEntry {
  const TeacherEntry({required this.teacher, required this.subjectCount});

  /// The raw Drift data row from the `teachers` table.
  final TeachersData teacher;

  /// Subjects taught by this teacher in the current active term.
  final int subjectCount;

  @override
  MembershipRole get role => MembershipRole.teacher;
}

/// Entry for a staff member.
final class StaffEntry extends MembershipEntry {
  const StaffEntry({required this.staff});

  /// The raw Drift data row from the `staff` table.
  final StaffData staff;

  @override
  MembershipRole get role => MembershipRole.staff;
}

/// Entry for a student.
///
/// Only created when the student row has a non-null `user` column linking
/// it to the current user's account.
final class StudentEntry extends MembershipEntry {
  const StudentEntry({required this.student});

  /// The raw Drift data row from the `students` table.
  final StudentsData student;

  @override
  MembershipRole get role => MembershipRole.student;
}

/// Entry for a guardian, expanded once per ward.
///
/// A guardian responsible for two students at School A produces two
/// [GuardianEntry] instances — one per ward — so the user can navigate
/// independently into each ward's dashboard.
///
/// The ward's cached image is served from:
/// `{appDir}/schools/{schoolId}/students/{adm}/image`
final class GuardianEntry extends MembershipEntry {
  const GuardianEntry({required this.guardian, required this.ward});

  /// The raw Drift data row from the `guardians` table.
  final GuardiansData guardian;

  /// The student this guardian entry represents (the ward).
  final StudentsData ward;

  @override
  MembershipRole get role => MembershipRole.guardian;
}

// ─────────────────────────────────────────────────────────────────────────────
// SchoolMembership  (one per unique school on the home screen)
// ─────────────────────────────────────────────────────────────────────────────

/// All of a user's memberships at a single school, grouped for home-screen
/// display and in-app navigation.
///
/// One [SchoolMembership] is rendered as one school card on the home screen.
/// The card's badge area shows [roles] (deduplicated).
///
/// Tapping behaviour (implemented by Gemini's UI layer):
/// - [hasSingleEntry] == true  → navigate directly to that entry's dashboard.
/// - [hasSingleEntry] == false → show a picker dialog so the user can choose
///   which entry (role / ward) to enter.
class SchoolMembership {
  const SchoolMembership({
    required this.school,
    required this.roles,
    required this.entries,
  });

  /// The school these memberships belong to.
  final SchoolsData school;

  /// Deduplicated list of roles this user holds at [school].
  ///
  /// Used for badge rendering on the home-screen card.
  /// Ordered: owner → teacher → staff → student → guardian.
  final List<MembershipRole> roles;

  /// All navigation targets this user has at [school].
  ///
  /// Guardian entries expand one-per-ward, so the list length may exceed the
  /// number of unique roles in [roles].
  final List<MembershipEntry> entries;

  /// True when the user has exactly one navigation entry for this school —
  /// the UI can skip the picker dialog and navigate directly.
  bool get hasSingleEntry => entries.length == 1;
}
