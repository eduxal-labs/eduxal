import 'dart:typed_data';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';

/// Modal bottom sheet showing the full details of a [Role] row.
///
/// Displays name, description, and the parsed permissions grouped by resource.
/// Tapping the edit icon (if permitted) switches to an inline edit form using
/// the same permission builder as [CreateRoleSheet].
/// A delete button (if permitted) triggers a confirmation dialog then calls
/// [RolesDao.deleteRole].
///
/// The sheet watches [RolesDao.watchSystemRoles] so it reflects live updates.
class RoleDetailSheet extends StatefulWidget {
  const RoleDetailSheet({
    super.key,
    required this.role,
    required this.permissions,
  });

  final Role role;
  final SystemPermissions permissions;

  @override
  State<RoleDetailSheet> createState() => _RoleDetailSheetState();
}

class _RoleDetailSheetState extends State<RoleDetailSheet> {
  bool _editing = false;
  bool _deleting = false;
  bool _saving = false;
  String? _saveError;

  // ── Edit form state ────────────────────────────────────────────────────────

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  /// The mutable permissions map during edit mode.
  /// Key = permission key (e.g. "users.read"), value = true/false.
  late Map<String, bool> _editPermissions;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.role.name);
    _descCtrl = TextEditingController(text: widget.role.description ?? '');
    _editPermissions = _parsePermissionsFromBlob(widget.role.permissions);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Permission parsing ─────────────────────────────────────────────────────

  /// Parses a binary blob from `roles.permissions` into a flat
  /// `Map<String, bool>` keyed by `"resource.action"`.
  ///
  /// Uses [Permissions.fromBlob] to decode the canonical triplet format,
  /// then expands each resource/action pair into the string-keyed map that
  /// the system role UI widgets expect.
  static Map<String, bool> _parsePermissionsFromBlob(Uint8List blob) {
    final perms = Permissions.fromBlob(blob);
    final result = <String, bool>{};
    for (final entry in perms.map.entries) {
      for (final action in Action.values) {
        if (entry.value & action.mask != 0) {
          result['${entry.key.name}.${action.name}'] = true;
        }
      }
    }
    return result;
  }

  /// Serialises the current [_editPermissions] to a [Uint8List] blob in the
  /// canonical `[resource_id: u8, actions_lo: u8, actions_hi: u8]` format.
  Uint8List _serialisePermissionsToBlob() {
    final map = <Resource, int>{};
    for (final e in _editPermissions.entries) {
      if (!e.value) continue;
      final parts = e.key.split('.');
      if (parts.length < 2) continue;
      final resourceName = parts.first;
      final actionName = parts.skip(1).join('.');
      final resource = Resource.values
          .where((r) => r.name == resourceName)
          .firstOrNull;
      final action = Action.values
          .where((a) => a.name == actionName)
          .firstOrNull;
      if (resource == null || action == null) continue;
      map[resource] = (map[resource] ?? 0) | action.mask;
    }
    return Permissions(map).toBlob();
  }

  // ── Group permissions for display ─────────────────────────────────────────

  /// Groups a flat permission map by resource prefix.
  ///
  /// E.g. {"users.read": true, "users.create": true, "schools.read": true}
  /// → {"users": ["read", "create"], "schools": ["read"]}
  static Map<String, List<String>> _groupByResource(Map<String, bool> perms) {
    final grouped = <String, List<String>>{};
    for (final entry in perms.entries) {
      if (!entry.value) continue;
      final parts = entry.key.split('.');
      if (parts.length < 2) continue;
      final resource = parts.first;
      final action = parts.skip(1).join('.');
      grouped.putIfAbsent(resource, () => []).add(action);
    }
    return grouped;
  }

  // ── Edit helpers ───────────────────────────────────────────────────────────

  void _startEditing(Role current) {
    setState(() {
      _nameCtrl.text = current.name;
      _descCtrl.text = current.description ?? '';
      _editPermissions = _parsePermissionsFromBlob(current.permissions);
      _editing = true;
      _saveError = null;
    });
  }

  Future<void> _save(Role current) async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _saveError = 'Role name must be at least 2 characters.');
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final desc = _descCtrl.text.trim();

      await rolesDao.updateRole(
        current.id,
        RolesCompanion(
          name: Value(name),
          description: Value(desc.isEmpty ? null : desc),
          permissions: Value(_serialisePermissionsToBlob()),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete helpers ─────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Role current) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete role?',
      message:
          'Are you sure you want to delete "${current.name}"? '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _deleting = true);

    try {
      await rolesDao.deleteRole(current.id, accountId: accountId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role "${current.name}" deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete role: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Role>>(
      stream: rolesDao.watchSystemRoles(),
      builder: (context, snapshot) {
        // Find the current version of this role in the stream. If deleted, fall
        // back to the initial snapshot (sheet will close after delete anyway).
        final role =
            snapshot.data
                ?.where((r) => r.id == widget.role.id)
                .cast<Role?>()
                .firstOrNull ??
            widget.role;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──────────────────────────────────────────────────────
              _SheetHandle(cs: cs),

              // ── Header ───────────────────────────────────────────────────────
              _SheetHeader(
                role: role,
                editing: _editing,
                saving: _saving,
                deleting: _deleting,
                canEdit: widget.permissions.can(Resource.roles, Action.update),
                canDelete: widget.permissions.can(
                  Resource.roles,
                  Action.delete,
                ),
                onEdit: () => _startEditing(role),
                onSave: () => _save(role),
                onCancel: () => setState(() {
                  _editing = false;
                  _saveError = null;
                }),
                onDelete: () => _confirmDelete(role),
                cs: cs,
              ),

              Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),

              // ── Body ─────────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.viewInsetsOf(context).bottom + 32,
                  ),
                  child: _editing
                      ? _EditBody(
                          nameCtrl: _nameCtrl,
                          descCtrl: _descCtrl,
                          permissions: _editPermissions,
                          isSuperUser:
                              widget.permissions.level == UserLevel.super_,
                          onPermissionToggled: (key, value) {
                            setState(() => _editPermissions[key] = value);
                          },
                          onSelectAllForResource: (resource, keys, allOn) {
                            setState(() {
                              for (final k in keys) {
                                _editPermissions[k] = !allOn;
                              }
                            });
                          },
                          error: _saveError,
                          cs: cs,
                        )
                      : _ViewBody(role: role, cs: cs),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet handle
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet header
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.role,
    required this.editing,
    required this.saving,
    required this.deleting,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
    required this.cs,
  });

  final Role role;
  final bool editing;
  final bool saving;
  final bool deleting;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
      child: Row(
        children: [
          // Role icon.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: cs.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role.description != null && role.description!.isNotEmpty)
                  Text(
                    role.description!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Action icons.
          if (editing) ...[
            if (saving || deleting)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: cs.error),
                onPressed: onCancel,
                tooltip: 'Cancel',
              ),
              IconButton(
                icon: Icon(Icons.check_rounded, size: 20, color: cs.primary),
                onPressed: onSave,
                tooltip: 'Save',
              ),
            ],
          ] else ...[
            if (canDelete)
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: cs.error.withValues(alpha: 0.7),
                ),
                onPressed: deleting ? null : onDelete,
                tooltip: 'Delete',
              ),
            if (canEdit)
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View body — read-only permissions display grouped by resource
// ─────────────────────────────────────────────────────────────────────────────

class _ViewBody extends StatelessWidget {
  const _ViewBody({required this.role, required this.cs});

  final Role role;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final perms = _RoleDetailSheetState._parsePermissionsFromBlob(
      role.permissions,
    );
    final grouped = _RoleDetailSheetState._groupByResource(perms);

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No permissions assigned to this role.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final groups = _buildResourceGroups(isSuperUser: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Permissions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        ...groups.map((group) {
          final groupResources = group.resources.keys
              .where((r) => grouped.containsKey(r))
              .toList();
          if (groupResources.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    group.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = (constraints.maxWidth / 160).floor();
                    if (crossAxisCount < 1) crossAxisCount = 1;
                    final itemWidth =
                        (constraints.maxWidth - (crossAxisCount - 1) * 12) /
                        crossAxisCount;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: groupResources.map((resource) {
                        final actions = grouped[resource]!;

                        return Container(
                          width: itemWidth,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _capitalise(resource),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: actions.map((action) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: cs.primary.withValues(
                                          alpha: 0.22,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: cs.primary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit body — name / description fields + permission builder
// ─────────────────────────────────────────────────────────────────────────────

/// The known resources and their available actions, grouped for display.
/// Base actions available to all users.
const _kBaseActions = ['read', 'create', 'update', 'delete'];

/// Builds resource groups with the correct action lists.
///
/// When [isSuperUser] is `true`, every resource gains a fifth `purge` action.
List<_ResourceGroup> _buildResourceGroups({required bool isSuperUser}) {
  List<String> a([List<String> actions = _kBaseActions]) =>
      isSuperUser ? [...actions, 'purge'] : actions;

  return <_ResourceGroup>[
    _ResourceGroup('People', {
      'users': a(),
      'students': a(),
      'guardians': a(),
      'teachers': a(),
      'staff': a(),
    }),
    _ResourceGroup('Academic', {
      'terms': a(),
      'subjects': a(),
      'enrollments': a(['read', 'create', 'delete']),
      'lessons': a(),
      'exams': a(),
      'papers': a(),
      'grades': a(),
      'timetable': a(),
      'attendance': a(),
      'mastery': a(['read', 'update']),
      'classTeachers': a(['read', 'create', 'delete']),
    }),
    _ResourceGroup('Finance', {
      'fees': a(),
      'invoices': a(),
      'payments': a(),
      'discounts': a(),
      'subscriptions': a(),
    }),
    _ResourceGroup('School Admin', {
      'schools': a(),
      'departments': a(),
      'owners': a(['read', 'create', 'delete']),
      'settings': a(['read', 'update']),
      'announcements': a(),
      'aiusage': a(['read', 'update']),
    }),
    _ResourceGroup('System', {
      'roles': a(),
      'scopes': a(['read', 'create', 'delete']),
      'plans': a(),
    }),
  ];
}

class _ResourceGroup {
  const _ResourceGroup(this.label, this.resources);
  final String label;
  final Map<String, List<String>> resources;
}

class _PermissionGroupSection extends StatelessWidget {
  const _PermissionGroupSection({
    required this.group,
    required this.permissions,
    required this.onToggle,
    required this.onToggleResourceAll,
    required this.cs,
  });

  final _ResourceGroup group;
  final Map<String, bool> permissions;
  final void Function(String key, bool value) onToggle;
  final void Function(String resource, List<String> actions, bool allOn)
  onToggleResourceAll;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            group.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              letterSpacing: 0.6,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = (constraints.maxWidth / 160).floor();
            if (crossAxisCount < 1) crossAxisCount = 1;
            final itemWidth =
                (constraints.maxWidth - (crossAxisCount - 1) * 12) /
                crossAxisCount;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: group.resources.entries.map((entry) {
                final resource = entry.key;
                final actions = entry.value;
                final keys = actions.map((a) => '$resource.$a').toList();
                final allOn = keys.every((k) => permissions[k] == true);

                return SizedBox(
                  width: itemWidth,
                  child: _ResourceBlock(
                    resource: resource,
                    actions: actions,
                    permissions: permissions,
                    allOn: allOn,
                    onToggle: onToggle,
                    onSelectAll: () =>
                        onToggleResourceAll(resource, keys, allOn),
                    cs: cs,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _EditBody extends StatelessWidget {
  const _EditBody({
    required this.nameCtrl,
    required this.descCtrl,
    required this.permissions,
    required this.onPermissionToggled,
    required this.onSelectAllForResource,
    required this.isSuperUser,
    required this.error,
    required this.cs,
  });

  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final Map<String, bool> permissions;
  final void Function(String key, bool value) onPermissionToggled;
  final void Function(String resource, List<String> keys, bool allOn)
  onSelectAllForResource;
  final bool isSuperUser;
  final String? error;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
            ),
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Name field.
        _FormLabel(label: 'Name', cs: cs),
        const SizedBox(height: 6),
        _FormTextField(
          controller: nameCtrl,
          hint: 'Role name',
          cs: cs,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),

        // Description field.
        _FormLabel(label: 'Description', cs: cs),
        const SizedBox(height: 6),
        _FormTextField(
          controller: descCtrl,
          hint: 'Optional',
          cs: cs,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),

        // Permission builder.
        Text(
          'Permissions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),

        ..._buildResourceGroups(isSuperUser: isSuperUser).map((group) {
          return _PermissionGroupSection(
            group: group,
            permissions: permissions,
            onToggle: onPermissionToggled,
            onToggleResourceAll: onSelectAllForResource,
            cs: cs,
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resource permission block
// ─────────────────────────────────────────────────────────────────────────────

class _ResourceBlock extends StatelessWidget {
  const _ResourceBlock({
    required this.resource,
    required this.actions,
    required this.permissions,
    required this.allOn,
    required this.onToggle,
    required this.onSelectAll,
    required this.cs,
  });

  final String resource;
  final List<String> actions;
  final Map<String, bool> permissions;
  final bool allOn;
  final void Function(String key, bool value) onToggle;
  final VoidCallback onSelectAll;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ViewBody._capitalise(resource),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSelectAll,
                child: Text(
                  allOn ? 'Deselect all' : 'Select all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: actions.map((action) {
              final key = '$resource.$action';
              final on = permissions[key] == true;
              return GestureDetector(
                onTap: () => onToggle(key, !on),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: on
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: on
                          ? cs.primary.withValues(alpha: 0.35)
                          : cs.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: on ? cs.primary : cs.onSurfaceVariant,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.hint,
    required this.cs,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final ColorScheme cs;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: cs.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          borderSide: BorderSide(color: cs.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }
}
