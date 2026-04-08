import 'package:flutter/material.dart' hide Action;

import '../../../models/permissions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResourceGroup — typed wrapper for permission editor UI
// ─────────────────────────────────────────────────────────────────────────────

/// A single resource with its applicable actions, used by permission editor UIs.
class ResourceGroup {
  final String label;
  final Resource resource;
  final List<Action> actions;

  const ResourceGroup({
    required this.label,
    required this.resource,
    required this.actions,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Canonical resource groups — one per Resource, actions from AGENT.md §17a
// ─────────────────────────────────────────────────────────────────────────────

/// The complete list of resources with their applicable actions, as defined
/// in AGENT.md §17a "Action Context Per Resource (UI Display)".
///
/// Used by all permission editor UIs (create role, role detail, etc.) to
/// build the permission toggle grid.
const kResourceGroups = [
  ResourceGroup(
    label: 'Users',
    resource: Resource.users,
    actions: [Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Schools',
    resource: Resource.schools,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Owners',
    resource: Resource.owners,
    actions: [Action.create, Action.read, Action.delete],
  ),
  ResourceGroup(
    label: 'Teachers',
    resource: Resource.teachers,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Staff',
    resource: Resource.staff,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Students',
    resource: Resource.students,
    actions: [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.assign,
      Action.unassign,
    ],
  ),
  ResourceGroup(
    label: 'Departments',
    resource: Resource.departments,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Classes',
    resource: Resource.classes,
    actions: [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.assign,
      Action.unassign,
    ],
  ),
  ResourceGroup(
    label: 'Attendance',
    resource: Resource.attendance,
    actions: [Action.read, Action.mark],
  ),
  ResourceGroup(
    label: 'Lessons',
    resource: Resource.lessons,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Exams',
    resource: Resource.exams,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Grades',
    resource: Resource.grades,
    actions: [Action.read, Action.mark, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Fees',
    resource: Resource.fees,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Payments',
    resource: Resource.payments,
    actions: [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.approve,
    ],
  ),
  ResourceGroup(
    label: 'Announcements',
    resource: Resource.announcements,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'Roles',
    resource: Resource.roles,
    actions: [
      Action.create,
      Action.read,
      Action.update,
      Action.delete,
      Action.assign,
      Action.unassign,
    ],
  ),
  ResourceGroup(
    label: 'Plans',
    resource: Resource.plans,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
  ResourceGroup(
    label: 'AI',
    resource: Resource.ai,
    actions: [Action.read, Action.update],
  ),
  ResourceGroup(
    label: 'Subjects',
    resource: Resource.subjects,
    actions: [Action.create, Action.read, Action.update, Action.delete],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Action display helpers — colours, icons, labels for all 9 actions
// ─────────────────────────────────────────────────────────────────────────────

/// Colour associated with each action in the permission editor UI.
const kActionColors = <Action, Color>{
  Action.read: Colors.blue,
  Action.create: Colors.green,
  Action.update: Colors.orange,
  Action.delete: Colors.red,
  Action.purge: Colors.purple,
  Action.assign: Colors.teal,
  Action.unassign: Colors.deepOrange,
  Action.mark: Colors.indigo,
  Action.approve: Colors.amber,
};

/// Icon associated with each action in the permission editor UI.
const kActionIcons = <Action, IconData>{
  Action.read: Icons.visibility_outlined,
  Action.create: Icons.add_circle_outline,
  Action.update: Icons.edit_outlined,
  Action.delete: Icons.delete_outline_rounded,
  Action.purge: Icons.delete_forever_outlined,
  Action.assign: Icons.link_rounded,
  Action.unassign: Icons.link_off_rounded,
  Action.mark: Icons.check_circle_outline,
  Action.approve: Icons.verified_outlined,
};

/// Human-readable label for an [Action].
String actionLabel(Action a) => switch (a) {
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
