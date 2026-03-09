import 'permissions.dart';

/// Aggregated permission set for a user within a specific school.
///
/// Assembled by loading all [scopes] rows for `(school, user)`, resolving each
/// scope's linked [roles] row, and parsing the binary permission blob (or
/// legacy JSON) from each role. All permissions across all roles are unioned
/// into a single [Permissions] bitmask instance.
///
/// [SchoolPermissions] is computed once when the user enters a school context
/// and held constant for the duration of that session. It is pure in-memory
/// state — never persisted to the local DB.
///
/// Permission checks use the typed [Resource] / [Action] API from
/// [Permissions]. See AGENT.md §17a for the full Resource and Action tables.
class SchoolPermissions {
  /// Creates a [SchoolPermissions] instance with a pre-assembled [Permissions].
  ///
  /// Prefer using [SchoolPermissions.empty] when no scopes exist for the user,
  /// and constructing manually from DAO results otherwise.
  const SchoolPermissions({
    required this.schoolId,
    required this.userId,
    required this.permissions,
  });

  /// Creates a [SchoolPermissions] with an empty permission set.
  ///
  /// Used when a user has no [scopes] rows for this school — e.g. a student
  /// or guardian who has no administrative role assignments.
  factory SchoolPermissions.empty(String schoolId, String userId) {
    return SchoolPermissions(
      schoolId: schoolId,
      userId: userId,
      permissions: const Permissions.empty(),
    );
  }

  /// The school this permission set applies to.
  final String schoolId;

  /// The user whose aggregated permissions are represented here.
  final String userId;

  /// Aggregated permissions from all roles linked to all scopes held by
  /// [userId] at [schoolId].
  ///
  /// Each resource maps to a u16 action bitmask. Membership tests are O(1).
  final Permissions permissions;

  /// Returns `true` if [action] is granted on [resource].
  ///
  /// ```dart
  /// if (perms.can(Resource.attendance, Action.mark)) { ... }
  /// ```
  bool can(Resource resource, Action action) =>
      permissions.can(resource, action);

  /// Returns `true` if **at least one** of [actions] is granted on [resource].
  ///
  /// Useful for showing UI that requires any one of several related actions.
  ///
  /// ```dart
  /// if (perms.canAny(Resource.students, [Action.read, Action.update])) { ... }
  /// ```
  bool canAny(Resource resource, List<Action> actions) =>
      permissions.canAny(resource, actions);

  /// Returns `true` if **all** of [actions] are granted on [resource].
  ///
  /// Useful for gating an action that requires several permissions simultaneously.
  ///
  /// ```dart
  /// if (perms.canAll(Resource.fees, [Action.read, Action.update])) { ... }
  /// ```
  bool canAll(Resource resource, List<Action> actions) =>
      permissions.canAll(resource, actions);

  @override
  String toString() =>
      'SchoolPermissions(schoolId: $schoolId, userId: $userId, '
      'permissions: $permissions)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolPermissions &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          userId == other.userId &&
          permissions == other.permissions;

  @override
  int get hashCode => Object.hash(schoolId, userId, permissions);
}
