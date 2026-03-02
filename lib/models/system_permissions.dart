import 'dart:convert';

import '../database/tables/enums.dart';

/// Evaluates system-level permissions for the currently active user.
///
/// Permission evaluation order:
/// 1. [UserLevel.super_] → all permissions granted unconditionally.
/// 2. [UserLevel.system] → all permissions granted unconditionally.
/// 3. Otherwise → check the flat [_permissions] set built from the user's
///    system-scoped roles (where `scopes.school IS NULL`).
///
/// The shortcut for super_/system is internal — all callers use the same
/// [can] / [canAny] / [canAll] API regardless of user level, keeping the
/// call sites uniform.
///
/// ### Permission storage format
/// The `roles.permissions` column stores a JSON **list of objects**:
/// ```json
/// [
///   {"resource": "users", "actions": ["read", "create", "update"]},
///   {"resource": "schools", "actions": ["read"]}
/// ]
/// ```
///
/// ### Internal representation
/// This class flattens the list into a `Set<String>` of dot-separated keys:
/// `{"users.read", "users.create", "users.update", "schools.read"}`.
/// The [can] / [canAny] / [canAll] API operates on these flat keys.
///
/// ### Available actions
/// `"read"`, `"create"`, `"update"`, `"delete"`, `"purge"` (purge = super_ only).
///
/// ### Resource names (derived from LogTable enum)
/// `users`, `schools`, `owners`, `students`, `guardians`, `departments`,
/// `teachers`, `staff`, `terms`, `classTeachers`, `enrollments`, `subjects`,
/// `attendance`, `timetable`, `lessons`, `exams`, `papers`, `grades`, `fees`,
/// `invoices`, `payments`, `announcements`, `mastery`, `aiusage`, `settings`,
/// `roles`, `scopes`, `plans`, `subscriptions`, `discounts`.
class SystemPermissions {
  SystemPermissions._({
    required UserLevel level,
    required Set<String> permissions,
  }) : _level = level,
       _permissions = permissions;

  final UserLevel _level;
  final Set<String> _permissions;

  // ─────────────────────────────────────────────────────────────────────────
  // Factory constructors
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a [SystemPermissions] instance for [user] from the list of
  /// system-scoped [roles] assigned to that user.
  ///
  /// For [UserLevel.super_] and [UserLevel.system] users the permissions set
  /// is not populated — the level shortcut in [can] handles them.
  ///
  /// For other users, each role's `permissions` JSON column is expected to be
  /// a JSON list of `{resource, actions}` objects:
  /// ```json
  /// [
  ///   {"resource": "users", "actions": ["read", "create"]},
  ///   {"resource": "schools", "actions": ["read"]}
  /// ]
  /// ```
  /// Each `resource.action` pair across all roles is unioned into a single
  /// flat `Set<String>`.
  ///
  /// [roles] should be the list of [RolePermissions] objects obtained by
  /// querying all `scopes` rows where `school IS NULL` for this user and
  /// joining each with its `roles` row.
  factory SystemPermissions.forUser(
    UserLevel level,
    List<RolePermissions> roles,
  ) {
    if (level == UserLevel.super_ || level == UserLevel.system) {
      // Shortcut: all permissions granted — no need to parse JSON.
      return SystemPermissions._(level: level, permissions: const {});
    }

    final permissions = <String>{};

    for (final role in roles) {
      try {
        final decoded = jsonDecode(role.permissionsJson);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              final resource = entry['resource'];
              final actions = entry['actions'];
              if (resource is String && actions is List) {
                for (final action in actions) {
                  if (action is String) {
                    permissions.add('$resource.$action');
                  }
                }
              }
            }
          }
        }
      } catch (_) {
        // Malformed JSON in a role row — skip silently.
        // A corrupted permissions column should not crash the app.
      }
    }

    return SystemPermissions._(level: level, permissions: permissions);
  }

  /// Returns a [SystemPermissions] instance that grants all permissions
  /// unconditionally, regardless of roles.
  ///
  /// Useful as a fallback while permissions are loading, or in tests.
  factory SystemPermissions.superUser() {
    return SystemPermissions._(level: UserLevel.super_, permissions: const {});
  }

  /// Returns a [SystemPermissions] instance that grants no permissions at all.
  ///
  /// Useful as an initial/empty state while permissions are being loaded.
  factory SystemPermissions.none() {
    return SystemPermissions._(level: UserLevel.normal, permissions: const {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permission checks
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns `true` if the current user is permitted to perform [action].
  ///
  /// [action] is a dot-separated permission key, e.g. `"users.create"`.
  ///
  /// Always returns `true` for [UserLevel.super_] and [UserLevel.system].
  bool can(String action) {
    if (_level == UserLevel.super_ || _level == UserLevel.system) return true;
    return _permissions.contains(action);
  }

  /// Returns `true` if the current user holds **at least one** of [actions].
  ///
  /// Always returns `true` for [UserLevel.super_] and [UserLevel.system].
  bool canAny(List<String> actions) {
    if (_level == UserLevel.super_ || _level == UserLevel.system) return true;
    return actions.any(_permissions.contains);
  }

  /// Returns `true` if the current user holds **all** of [actions].
  ///
  /// Always returns `true` for [UserLevel.super_] and [UserLevel.system].
  bool canAll(List<String> actions) {
    if (_level == UserLevel.super_ || _level == UserLevel.system) return true;
    return actions.every(_permissions.contains);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Accessors
  // ─────────────────────────────────────────────────────────────────────────

  /// The user level this instance was built for.
  UserLevel get level => _level;

  /// Whether this user has elevated system-level access (super_ or system).
  bool get isElevated =>
      _level == UserLevel.super_ || _level == UserLevel.system;

  /// Whether deleted records should be shown to this user.
  ///
  /// Per the spec: deleted counts/rows are shown only to [UserLevel.super_]
  /// users. System-level users do not see deleted records.
  bool get canSeeDeleted => _level == UserLevel.super_;

  /// Returns an unmodifiable view of the raw permission key set.
  ///
  /// Empty for super_/system users (the level shortcut applies instead).
  Set<String> get permissions => Set.unmodifiable(_permissions);
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting value type
// ─────────────────────────────────────────────────────────────────────────────

/// A lightweight container carrying the raw JSON permissions string from a
/// single `roles` row, used when building a [SystemPermissions] instance.
///
/// Callers construct these from a joined `scopes + roles` query.
class RolePermissions {
  const RolePermissions({
    required this.roleId,
    required this.roleName,
    required this.permissionsJson,
  });

  /// The `roles.id` value.
  final String roleId;

  /// The `roles.name` value — useful for debugging / display.
  final String roleName;

  /// The raw JSON string from `roles.permissions`.
  /// Expected to be a JSON list of `{"resource": "...", "actions": [...]}` objects.
  final String permissionsJson;
}
