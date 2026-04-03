import 'package:flutter/foundation.dart';

import '../core/permission_parser.dart';
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
/// The `roles.permissions` column currently stores data as `text()` in Drift,
/// but the data may be in **multiple formats** due to the transition period:
/// 1. Standard JSON objects: `[{"resource": "users", "actions": ["read"]}]`
/// 2. JSON integer arrays (old seeder): `[5,2,0,7,2,0,...]` — raw binary blob
///    bytes serialised as a JSON array of ints.
/// 3. Base64-encoded strings (old delta writer bug).
///
/// This class uses [parsePermissions] from `lib/core/permission_parser.dart`
/// which handles all three formats resilently. See BUG-012 in BUG.md.
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
  /// `permissions` column is parsed using [parsePermissions] which handles
  /// all known storage formats (standard JSON, seeder int-array JSON,
  /// base64-encoded strings). All permissions across all roles are unioned
  /// into a single [Permissions] instance.
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
        final map = parsePermissions(role.permissionsData);
        if (map.isNotEmpty) {
          final parsed = Permissions(map);
          merged = merged.union(parsed);
        } else {
          debugPrint(
            '[SystemPermissions] Role "${role.roleName}" (${role.roleId}) '
            'has empty/unparseable permissions data',
          );
        }
      } catch (e, st) {
        // parsePermissions is designed to never throw, but guard defensively.
        debugPrint(
          '[SystemPermissions] Unexpected error parsing permissions for '
          'role "${role.roleName}" (${role.roleId}): $e\n$st',
        );
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

/// A lightweight container carrying the raw permissions data string from a
/// single `roles` row, used when building a [SystemPermissions] instance.
///
/// The [permissionsData] field is format-agnostic — it may contain standard
/// JSON, a JSON integer array (seeder format), or a base64-encoded string.
/// [SystemPermissions.forUser] uses [parsePermissions] to handle all formats.
///
/// Callers construct these from a joined `scopes + roles` query.
class RolePermissions {
  const RolePermissions({
    required this.roleId,
    required this.roleName,
    required this.permissionsData,
  });

  /// The `roles.id` value.
  final String roleId;

  /// The `roles.name` value — useful for debugging / display.
  final String roleName;

  /// The raw data from `roles.permissions` (currently a `text()` column).
  ///
  /// May be in any of the known storage formats — standard JSON, seeder
  /// int-array JSON, or base64-encoded string. See BUG-012.
  final String permissionsData;
}
