/// Aggregated permission set for a user within a specific school.
///
/// Assembled by loading all [scopes] rows for `(school, user)`, resolving each
/// scope's linked [roles] row, and taking the union of every permission key
/// found in every `roles.permissions` JSON map.
///
/// [SchoolPermissions] is computed once when the user enters a school context
/// and held constant for the duration of that session. It is pure in-memory
/// state — never persisted to the local DB.
///
/// Permission key strings are **opaque** to the client. They are defined by
/// the backend in the `roles.permissions` JSON map (e.g. `"attendance.record"`,
/// `"students.manage"`, `"fees.view"`). The client treats them as plain strings
/// and never hard-codes their structure. See P7 in AGENT.md for the pending
/// alignment on the key taxonomy.
class SchoolPermissions {
  /// Creates a [SchoolPermissions] instance with a pre-assembled permission set.
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
      permissions: const {},
    );
  }

  /// The school this permission set applies to.
  final String schoolId;

  /// The user whose aggregated permissions are represented here.
  final String userId;

  /// Flat union of all permission keys from all roles linked to all scopes
  /// held by [userId] at [schoolId].
  ///
  /// Each key is an opaque string defined by the backend (e.g. `"fees.view"`).
  /// The set is unordered. Membership tests are O(1).
  final Set<String> permissions;

  /// Returns `true` if [permission] is in the aggregated permission set.
  ///
  /// ```dart
  /// if (perms.can('attendance.record')) { ... }
  /// ```
  bool can(String permission) => permissions.contains(permission);

  /// Returns `true` if **at least one** of [perms] is in the permission set.
  ///
  /// Useful for showing UI that requires any one of several related permissions.
  ///
  /// ```dart
  /// if (perms.canAny(['students.view', 'students.manage'])) { ... }
  /// ```
  bool canAny(List<String> perms) => perms.any(permissions.contains);

  /// Returns `true` if **all** of [perms] are in the permission set.
  ///
  /// Useful for gating an action that requires several permissions simultaneously.
  ///
  /// ```dart
  /// if (perms.canAll(['fees.view', 'fees.manage'])) { ... }
  /// ```
  bool canAll(List<String> perms) => perms.every(permissions.contains);

  @override
  String toString() =>
      'SchoolPermissions(schoolId: $schoolId, userId: $userId, '
      'count: ${permissions.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolPermissions &&
          runtimeType == other.runtimeType &&
          schoolId == other.schoolId &&
          userId == other.userId &&
          permissions.length == other.permissions.length &&
          permissions.containsAll(other.permissions);

  @override
  int get hashCode => Object.hash(schoolId, userId, permissions.length);
}
