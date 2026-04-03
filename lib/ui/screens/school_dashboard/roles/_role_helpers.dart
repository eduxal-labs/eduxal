import 'package:flutter/material.dart' hide Action;

import '../../../../models/permissions.dart';

export '../../../../core/permission_parser.dart'
    show parsePermissions, parsePermissionsBlob, serialisePermissions, countPermissions, popcount;

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
