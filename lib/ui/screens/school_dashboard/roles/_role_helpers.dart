import 'dart:convert';

import 'package:flutter/material.dart' hide Action;

import '../../../../models/permissions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Resource groupings — uses the typed Resource enum from models/permissions.dart
// ─────────────────────────────────────────────────────────────────────────────

class ResourceGroup {
  const ResourceGroup(this.label, this.resources);
  final String label;
  final List<Resource> resources;
}

List<ResourceGroup> buildResourceGroups() => const [
  ResourceGroup('People', [
    Resource.users,
    Resource.students,
    Resource.teachers,
    Resource.staff,
    Resource.owners,
  ]),
  ResourceGroup('Academic', [
    Resource.subjects,
    Resource.lessons,
    Resource.exams,
    Resource.grades,
    Resource.attendance,
    Resource.classes,
    Resource.departments,
  ]),
  ResourceGroup('Finance', [Resource.fees, Resource.payments, Resource.plans]),
  ResourceGroup('School Admin', [
    Resource.schools,
    Resource.announcements,
    Resource.ai,
  ]),
  ResourceGroup('System', [Resource.roles]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Action colour / icon mapping
// ─────────────────────────────────────────────────────────────────────────────

const kActionColors = <Action, Color>{
  Action.read: Color(0xFF42A5F5),
  Action.create: Color(0xFF66BB6A),
  Action.update: Color(0xFFFFA726),
  Action.delete: Color(0xFFEF5350),
  Action.purge: Color(0xFFB71C1C),
  Action.assign: Color(0xFF26C6DA),
  Action.unassign: Color(0xFF78909C),
  Action.mark: Color(0xFF7E57C2),
  Action.approve: Color(0xFF26A69A),
};

const kActionIcons = <Action, IconData>{
  Action.create: Icons.add_rounded,
  Action.read: Icons.visibility_outlined,
  Action.update: Icons.edit_outlined,
  Action.delete: Icons.delete_outline_rounded,
  Action.purge: Icons.delete_forever_outlined,
  Action.assign: Icons.link_rounded,
  Action.unassign: Icons.link_off_rounded,
  Action.mark: Icons.check_box_outline_blank_rounded,
  Action.approve: Icons.thumb_up_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Permission helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Parses the JSON string stored in `roles.permissions` into a mutable
/// `Map<Resource, int>` bitmask map.  Handles null, empty string, empty
/// JSON array `"[]"`, and both legacy JSON shapes via [Permissions.fromJson].
/// Never throws — always returns an empty map on bad input.
Map<Resource, int> parsePermissions(String? jsonStr) {
  if (jsonStr == null ||
      jsonStr.isEmpty ||
      jsonStr == '[]' ||
      jsonStr == '{}') {
    return {};
  }
  try {
    final decoded = jsonDecode(jsonStr);
    final perms = Permissions.fromJson(decoded);
    return Map<Resource, int>.from(perms.map);
  } catch (_) {
    return {};
  }
}

/// Serialises a `Map<Resource, int>` bitmask map back to the JSON string
/// format stored in `roles.permissions`.
///
/// Output shape: `[{"resource": "users", "actions": ["read", "create"]}, …]`
String serialisePermissions(Map<Resource, int> perms) {
  final list = <Map<String, dynamic>>[];
  for (final entry in perms.entries) {
    if (entry.value == 0) continue;
    final actions = Action.values
        .where((a) => entry.value & a.mask != 0)
        .map((a) => a.name)
        .toList();
    if (actions.isNotEmpty) {
      list.add({'resource': entry.key.name, 'actions': actions});
    }
  }
  return jsonEncode(list);
}

/// Returns the total count of granted permissions across all resources.
int countPermissions(Map<Resource, int> perms) {
  var count = 0;
  for (final mask in perms.values) {
    count += popcount(mask);
  }
  return count;
}

/// Count set bits in a 16-bit integer (Hamming weight / popcount).
int popcount(int v) {
  var n = v & 0xFFFF;
  n = n - ((n >> 1) & 0x5555);
  n = (n & 0x3333) + ((n >> 2) & 0x3333);
  return (((n + (n >> 4)) & 0x0F0F) * 0x0101) & 0xFF;
}
