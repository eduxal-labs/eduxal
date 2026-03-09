import 'dart:convert';

import '../database/tables/enums.dart';
import 'permissions.dart';

/// Evaluates system-level permissions for the currently active user.
///
/// Permission evaluation order:
/// 1. [UserLevel.super_] → all permissions granted unconditionally.
/// 2. [UserLevel.system] → roles parsed and permissions enforced, just like
///    normal users, but with system-scoped roles (where `scopes.school IS NULL`).
/// 3. [UserLevel.normal] → check the [Permissions] bitmask built from the
///    user's school-scoped roles.
///
/// The shortcut is internal — all callers use the same [can] / [canAny] /
/// [canAll] API regardless of user level, keeping the call sites uniform.
///
/// ### Permission storage format
/// The `roles.permissions` column stores either:
/// - A **binary blob** (production): 3 bytes per non-empty resource
///   `[resource_id: u8, actions_lo: u8, actions_hi: u8]` (little-endian u16).
/// - A **JSON string** (legacy/transition): list of `{resource, actions}` objects
///   or flat map of `"resource.action"` keys.
///
/// ### Internal representation
/// This class delegates to [Permissions] which holds a `Map<Resource, int>`
/// where the `int` is a u16 action bitmask per resource.
class SystemPermissions {
  SystemPermissions._({
    required UserLevel level,
    required Permissions permissions,
  }) : _level = level,
       _permissions = permissions;

  final UserLevel _level;
  final Permissions _permissions;

  // ─────────────────────────────────────────────────────────────────────────
  // Factory constructors
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a [SystemPermissions] instance for [user] from the list of
  /// system-scoped [roles] assigned to that user.
  ///
  /// For [UserLevel.super_] users the permissions set is not populated — the
  /// level shortcut in [can] handles them.
  ///
  /// For [UserLevel.system] and [UserLevel.normal] users, each role's
  /// `permissions` column is parsed (JSON or binary blob) and all permissions
  /// across all roles are unioned into a single [Permissions] instance.
  ///
  /// [roles] should be the list of [RolePermissions] objects obtained by
  /// querying all `scopes` rows where `school IS NULL` for this user and
  /// joining each with its `roles` row.
  factory SystemPermissions.forUser(
    UserLevel level,
    List<RolePermissions> roles,
  ) {
    if (level == UserLevel.super_) {
      // Shortcut: all permissions granted — no need to parse.
      return SystemPermissions._(
        level: level,
        permissions: const Permissions.empty(),
      );
    }

    var merged = const Permissions.empty();

    for (final role in roles) {
      try {
        final decoded = jsonDecode(role.permissionsJson);
        final parsed = Permissions.fromJson(decoded);
        merged = merged.union(parsed);
      } catch (_) {
        // Malformed JSON in a role row — skip silently.
        // A corrupted permissions column should not crash the app.
      }
    }

    return SystemPermissions._(level: level, permissions: merged);
  }

  /// Returns a [SystemPermissions] instance that grants all permissions
  /// unconditionally, regardless of roles.
  ///
  /// Useful as a fallback while permissions are loading, or in tests.
  factory SystemPermissions.superUser() {
    return SystemPermissions._(
      level: UserLevel.super_,
      permissions: const Permissions.empty(),
    );
  }

  /// Returns a [SystemPermissions] instance that grants no permissions at all.
  ///
  /// Useful as an initial/empty state while permissions are being loaded.
  factory SystemPermissions.none() {
    return SystemPermissions._(
      level: UserLevel.normal,
      permissions: const Permissions.empty(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permission checks — typed Resource/Action API
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns `true` if the current user is permitted to perform [action] on
  /// [resource].
  ///
  /// Always returns `true` for [UserLevel.super_].
  bool can(Resource resource, Action action) {
    if (_level == UserLevel.super_) return true;
    return _permissions.can(resource, action);
  }

  /// Returns `true` if the current user holds **at least one** of [actions]
  /// on [resource].
  ///
  /// Always returns `true` for [UserLevel.super_].
  bool canAny(Resource resource, List<Action> actions) {
    if (_level == UserLevel.super_) return true;
    return _permissions.canAny(resource, actions);
  }

  /// Returns `true` if the current user holds **all** of [actions] on
  /// [resource].
  ///
  /// Always returns `true` for [UserLevel.super_].
  bool canAll(Resource resource, List<Action> actions) {
    if (_level == UserLevel.super_) return true;
    return _permissions.canAll(resource, actions);
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

  /// Returns the underlying [Permissions] bitmask object.
  ///
  /// Empty for super_ users (the level shortcut applies instead).
  Permissions get permissions => _permissions;
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
  /// Expected to be a JSON list of `{"resource": "...", "actions": [...]}` objects,
  /// or a flat map of `"resource.action"` keys.
  final String permissionsJson;
}
