/// Bitmask-based permission model for the EduXal app.
///
/// Permissions are stored as a binary blob in the `roles.permissions` column:
/// 3 bytes per non-empty resource `[resource_id: u8, actions_lo: u8, actions_hi: u8]`
/// (little-endian u16). Empty resources are skipped. Max size: 54 bytes.
///
/// The client represents this as a [Permissions] class with a
/// `Map<Resource, int>` where `int` is a u16 action bitmask.
///
/// See AGENT.md §17a for the full specification.
library;

import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
// Resource enum — 18 logical resources
// ─────────────────────────────────────────────────────────────────────────────

/// Logical domain resources that permissions can be granted on.
///
/// Each resource maps to one or more database tables. See AGENT.md §17a for
/// the full mapping.
///
/// The enum index is used as the `resource_id` byte in the binary encoding.
enum Resource {
  users,
  schools,
  owners,
  teachers,
  staff,
  students,
  departments,
  classes,
  attendance,
  lessons,
  exams,
  grades,
  fees,
  payments,
  announcements,
  roles,
  plans,
  ai,
  subjects;

  /// Human-readable label for UI display.
  String get label => switch (this) {
    Resource.users => 'Users',
    Resource.schools => 'Schools',
    Resource.owners => 'Owners',
    Resource.teachers => 'Teachers',
    Resource.staff => 'Staff',
    Resource.students => 'Students',
    Resource.departments => 'Departments',
    Resource.classes => 'Classes',
    Resource.attendance => 'Attendance',
    Resource.lessons => 'Lessons',
    Resource.exams => 'Exams',
    Resource.grades => 'Grades',
    Resource.fees => 'Fees',
    Resource.payments => 'Payments',
    Resource.announcements => 'Announcements',
    Resource.roles => 'Roles',
    Resource.plans => 'Plans',
    Resource.ai => 'AI',
    Resource.subjects => 'Subjects',
  };

  /// The actions that are relevant for this resource in the UI.
  ///
  /// Not every action applies to every resource. This list is used to build
  /// the permission editor UI — only these actions are shown for this resource.
  List<Action> get applicableActions => switch (this) {
    Resource.users => [Action.read, Action.update, Action.delete],
    Resource.schools => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.owners => [Action.create, Action.read, Action.delete],
    Resource.teachers => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.staff => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.students => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.assign,
      Action.unassign,
    ],
    Resource.departments => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.classes => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.assign,
      Action.unassign,
    ],
    Resource.attendance => [Action.read, Action.mark],
    Resource.lessons => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.exams => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.grades => [Action.read, Action.mark, Action.update, Action.delete],
    Resource.fees => [Action.create, Action.read, Action.update, Action.delete],
    Resource.payments => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.approve,
    ],
    Resource.announcements => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.roles => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.assign,
      Action.unassign,
    ],
    Resource.plans => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
    Resource.ai => [Action.read, Action.update],
    Resource.subjects => [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Action enum — u16 bitmask positions
// ─────────────────────────────────────────────────────────────────────────────

/// Actions that can be performed on resources.
///
/// Each action corresponds to a specific bit position in a u16 bitmask.
/// The enum index matches the bit position.
enum Action {
  create,
  read,
  update,
  delete,
  purge,
  assign,
  unassign,
  mark,
  approve;

  /// The bit position for this action in the bitmask.
  int get bit => index;

  /// The bitmask value for this action: `1 << bit`.
  int get mask => 1 << index;

  /// Human-readable label for UI display.
  String get label => switch (this) {
    Action.create => 'Create',
    Action.read => 'Read',
    Action.update => 'Update',
    Action.delete => 'Delete',
    Action.purge => 'Purge',
    Action.assign => 'Assign',
    Action.unassign => 'Unassign',
    Action.mark => 'Mark',
    Action.approve => 'Approve',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Permissions class
// ─────────────────────────────────────────────────────────────────────────────

/// Holds a set of resource/action permissions represented as bitmasks.
///
/// Each entry in the internal map associates a [Resource] with a u16 action
/// bitmask. Checking a permission is O(1): look up the resource in the map
/// and test the action's bit.
///
/// [Permissions] is intentionally **not** aware of user level. The bypass
/// logic for super users is handled by [SystemPermissions] and
/// [SchoolPermissions], which wrap this class.
class Permissions {
  /// Creates a [Permissions] instance from a pre-built map.
  const Permissions(Map<Resource, int> map) : _map = map;

  /// Creates an empty [Permissions] instance — no actions granted on any
  /// resource.
  const Permissions.empty() : _map = const {};

  /// The internal resource → action bitmask map.
  final Map<Resource, int> _map;

  /// Returns `true` if [action] is granted on [resource].
  bool can(Resource resource, Action action) {
    final mask = _map[resource] ?? 0;
    return mask & action.mask != 0;
  }

  /// Returns `true` if **at least one** of [actions] is granted on [resource].
  bool canAny(Resource resource, List<Action> actions) {
    final mask = _map[resource] ?? 0;
    if (mask == 0) return false;
    return actions.any((a) => mask & a.mask != 0);
  }

  /// Returns `true` if **all** of [actions] are granted on [resource].
  bool canAll(Resource resource, List<Action> actions) {
    final mask = _map[resource] ?? 0;
    if (mask == 0) return actions.isEmpty;
    return actions.every((a) => mask & a.mask != 0);
  }

  /// Returns the raw action bitmask for [resource], or 0 if no permissions
  /// are granted.
  int maskFor(Resource resource) => _map[resource] ?? 0;

  /// Returns the list of granted [Action]s for [resource].
  List<Action> actionsFor(Resource resource) {
    final mask = _map[resource] ?? 0;
    if (mask == 0) return const [];
    return Action.values.where((a) => mask & a.mask != 0).toList();
  }

  /// Whether any permissions are granted at all.
  bool get isEmpty => _map.isEmpty;

  /// Whether at least one permission is granted.
  bool get isNotEmpty => _map.isNotEmpty;

  /// Returns an unmodifiable view of the internal map.
  Map<Resource, int> get map => Map.unmodifiable(_map);

  // ─────────────────────────────────────────────────────────────────────────
  // Binary encoding / decoding
  // ─────────────────────────────────────────────────────────────────────────

  /// Decodes a [Permissions] instance from the binary blob stored in the
  /// `roles.permissions` column.
  ///
  /// Format: 3 bytes per non-empty resource:
  /// `[resource_id: u8, actions_lo: u8, actions_hi: u8]` (little-endian u16).
  /// Empty resources are skipped. Max size: 54 bytes (18 resources × 3 bytes).
  ///
  /// Returns [Permissions.empty()] for null or empty input.
  factory Permissions.fromBlob(Uint8List? blob) {
    if (blob == null || blob.isEmpty) return const Permissions.empty();

    final map = <Resource, int>{};
    final resourceValues = Resource.values;

    for (var i = 0; i + 2 < blob.length; i += 3) {
      final resourceId = blob[i];
      if (resourceId >= resourceValues.length) continue; // unknown resource

      final actionsLo = blob[i + 1];
      final actionsHi = blob[i + 2];
      final actionsMask = actionsLo | (actionsHi << 8);

      if (actionsMask != 0) {
        map[resourceValues[resourceId]] = actionsMask;
      }
    }

    return Permissions(map);
  }

  /// Encodes this [Permissions] instance into the binary blob format for
  /// storage in the `roles.permissions` column.
  ///
  /// Resources with a zero action mask are skipped.
  Uint8List toBlob() {
    final nonEmpty = _map.entries.where((e) => e.value != 0).toList();
    final blob = Uint8List(nonEmpty.length * 3);
    var offset = 0;

    for (final entry in nonEmpty) {
      blob[offset] = entry.key.index;
      blob[offset + 1] = entry.value & 0xFF; // lo byte
      blob[offset + 2] = (entry.value >> 8) & 0xFF; // hi byte
      offset += 3;
    }

    return blob;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JSON encoding / decoding (legacy compatibility)
  // ─────────────────────────────────────────────────────────────────────────

  /// Parses permissions from the legacy JSON format used during the transition
  /// period before binary blobs are fully deployed.
  ///
  /// Supports two JSON shapes:
  ///
  /// **Shape 1 — list of objects:**
  /// ```json
  /// [
  ///   {"resource": "users", "actions": ["read", "create"]},
  ///   {"resource": "schools", "actions": ["read"]}
  /// ]
  /// ```
  ///
  /// **Shape 2 — flat map (keys are "resource.action"):**
  /// ```json
  /// {"users.read": true, "schools.create": true}
  /// ```
  ///
  /// Returns [Permissions.empty()] for null, empty, or malformed input.
  factory Permissions.fromJson(dynamic decoded) {
    if (decoded == null) return const Permissions.empty();

    final map = <Resource, int>{};

    if (decoded is List) {
      // Shape 1: list of {resource, actions} objects
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final resourceName = entry['resource'];
          final actions = entry['actions'];
          if (resourceName is String && actions is List) {
            final resource = _resourceFromName(resourceName);
            if (resource != null) {
              var mask = map[resource] ?? 0;
              for (final actionName in actions) {
                if (actionName is String) {
                  final action = _actionFromName(actionName);
                  if (action != null) {
                    mask |= action.mask;
                  }
                }
              }
              if (mask != 0) map[resource] = mask;
            }
          }
        }
      }
    } else if (decoded is Map) {
      // Shape 2: flat map {"resource.action": true/value}
      for (final key in decoded.keys) {
        if (key is String) {
          final parts = key.split('.');
          if (parts.length == 2) {
            final resource = _resourceFromName(parts[0]);
            final action = _actionFromName(parts[1]);
            if (resource != null && action != null) {
              map[resource] = (map[resource] ?? 0) | action.mask;
            }
          }
        }
      }
    }

    return Permissions(map);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Merge / union
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a new [Permissions] that is the union of this and [other].
  ///
  /// For each resource present in either set, the action masks are OR'd
  /// together. Used when aggregating permissions from multiple roles.
  Permissions union(Permissions other) {
    final merged = Map<Resource, int>.from(_map);
    for (final entry in other._map.entries) {
      merged[entry.key] = (merged[entry.key] ?? 0) | entry.value;
    }
    return Permissions(merged);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permissions &&
          runtimeType == other.runtimeType &&
          _mapsEqual(_map, other._map);

  @override
  int get hashCode =>
      Object.hashAll(_map.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() {
    final entries = _map.entries
        .map((e) => '${e.key.name}: 0x${e.value.toRadixString(16)}')
        .join(', ');
    return 'Permissions({$entries})';
  }

  static bool _mapsEqual(Map<Resource, int> a, Map<Resource, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers for name-based lookup (JSON parsing)
// ─────────────────────────────────────────────────────────────────────────────

/// Maps a string resource name to its [Resource] enum value.
///
/// Supports both the canonical enum name (e.g. `"users"`) and common aliases
/// (e.g. `"settings"` → `Resource.schools`).
Resource? _resourceFromName(String name) {
  return switch (name.toLowerCase()) {
    'users' => Resource.users,
    'schools' => Resource.schools,
    'settings' => Resource.schools,
    'owners' => Resource.owners,
    'teachers' => Resource.teachers,
    'staff' => Resource.staff,
    'students' => Resource.students,
    'guardians' => Resource.students,
    'departments' => Resource.departments,
    'classes' => Resource.classes,
    'class_teachers' => Resource.classes,
    'classteachers' => Resource.classes,
    'subject_teachers' => Resource.classes,
    'timetable' => Resource.classes,
    'subjects' => Resource.subjects,
    'topics' => Resource.subjects,
    'attendance' => Resource.attendance,
    'lessons' => Resource.lessons,
    'exams' => Resource.exams,
    'papers' => Resource.exams,
    'grades' => Resource.grades,
    'mastery' => Resource.grades,
    'fees' => Resource.fees,
    'invoices' => Resource.fees,
    'payments' => Resource.payments,
    'announcements' => Resource.announcements,
    'roles' => Resource.roles,
    'scopes' => Resource.roles,
    'plans' => Resource.plans,
    'subscriptions' => Resource.plans,
    'discounts' => Resource.plans,
    'ai' => Resource.ai,
    'aiusage' => Resource.ai,
    _ => null,
  };
}

/// Maps a string action name to its [Action] enum value.
Action? _actionFromName(String name) {
  return switch (name.toLowerCase()) {
    'create' => Action.create,
    'read' => Action.read,
    'view' => Action.read,
    'update' => Action.update,
    'edit' => Action.update,
    'manage' => Action.update,
    'delete' => Action.delete,
    'remove' => Action.delete,
    'purge' => Action.purge,
    'assign' => Action.assign,
    'enroll' => Action.assign,
    'unassign' => Action.unassign,
    'unenroll' => Action.unassign,
    'revoke' => Action.unassign,
    'mark' => Action.mark,
    'record' => Action.mark,
    'approve' => Action.approve,
    'verify' => Action.approve,
    _ => null,
  };
}
