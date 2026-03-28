import 'dart:convert';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Resource groupings (approved by project owner)
// ─────────────────────────────────────────────────────────────────────────────

/// Base actions for each resource. `purge` is appended dynamically when the
/// current user is [UserLevel.super_].
const _kBaseActions = ['read', 'create', 'update', 'delete'];

/// Builds resource groups with the correct action lists.
///
/// When [isSuperUser] is `true`, every resource gains a fifth `purge` action.
///
/// Groupings:
/// - **People:** users, students, guardians, teachers, staff
/// - **Academic:** terms, subjects, enrollments, lessons, exams, papers, grades,
///   timetable, attendance, mastery, classTeachers
/// - **Finance:** fees, invoices, payments, discounts, subscriptions
/// - **School Admin:** schools, departments, owners, settings, announcements, aiusage
/// - **System:** roles, scopes, plans
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

// ─────────────────────────────────────────────────────────────────────────────
// Action colour / icon mapping (matches role_detail_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _kActionColors = <String, Color>{
  'read': Color(0xFF42A5F5), // blue
  'create': Color(0xFF66BB6A), // green
  'update': Color(0xFFFFA726), // orange
  'delete': Color(0xFFEF5350), // red
  'purge': Color(0xFFAB47BC), // purple
};

const _kActionIcons = <String, IconData>{
  'read': Icons.visibility_outlined,
  'create': Icons.add_circle_outline,
  'update': Icons.edit_outlined,
  'delete': Icons.delete_outline_rounded,
  'purge': Icons.local_fire_department_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _capitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ─────────────────────────────────────────────────────────────────────────────
// CreateRoleSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet (mobile) / dialog content (desktop) for creating a new
/// system-level role.
///
/// Collects name (required), description (optional), and a permission builder
/// with resource / action toggle chips grouped by category.
///
/// On submit, serialises the selected permissions into the list-of-objects
/// JSON format (D2) and calls [RolesDao.createRole] with `accountId`.
class CreateRoleSheet extends StatefulWidget {
  const CreateRoleSheet({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<CreateRoleSheet> createState() => _CreateRoleSheetState();
}

class _CreateRoleSheetState extends State<CreateRoleSheet> {
  // ── Form controllers ────────────────────────────────────────────────────────

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ── Permission state ────────────────────────────────────────────────────────

  /// Resource groups built once based on the current user's level.
  late final List<_ResourceGroup> _resourceGroups = _buildResourceGroups(
    isSuperUser: widget.permissions.level == UserLevel.super_,
  );

  /// Flat permission map: key = "resource.action", value = enabled.
  final Map<String, bool> _permissions = {};

  /// Resources that are currently expanded (showing full permission details).
  final Set<String> _expandedResources = {};

  // ── Validation / submit state ───────────────────────────────────────────────

  String? _nameError;
  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Global select all ──────────────────────────────────────────────────────

  bool get _allSelected {
    for (final group in _resourceGroups) {
      for (final entry in group.resources.entries) {
        for (final action in entry.value) {
          if (_permissions['${entry.key}.$action'] != true) return false;
        }
      }
    }
    return true;
  }

  int get _totalSelectedCount {
    int count = 0;
    for (final group in _resourceGroups) {
      for (final entry in group.resources.entries) {
        for (final action in entry.value) {
          if (_permissions['${entry.key}.$action'] == true) count++;
        }
      }
    }
    return count;
  }

  int get _totalPermissionCount {
    int count = 0;
    for (final group in _resourceGroups) {
      for (final entry in group.resources.entries) {
        count += entry.value.length;
      }
    }
    return count;
  }

  void _toggleSelectAll() {
    final setTo = !_allSelected;
    setState(() {
      for (final group in _resourceGroups) {
        for (final entry in group.resources.entries) {
          for (final action in entry.value) {
            _permissions['${entry.key}.$action'] = setTo;
          }
        }
      }
    });
  }

  // ── Per-resource select all ────────────────────────────────────────────────

  void _toggleResourceAll(String resource, List<String> actions) {
    final allOn = actions.every((a) => _permissions['$resource.$a'] == true);
    setState(() {
      for (final action in actions) {
        _permissions['$resource.$action'] = !allOn;
      }
    });
  }

  // ── Single permission toggle ───────────────────────────────────────────────

  void _togglePermission(String key) {
    setState(() {
      final current = _permissions[key] == true;
      _permissions[key] = !current;
    });
  }

  // ── Expand / collapse ──────────────────────────────────────────────────────

  void _toggleExpand(String resource) {
    setState(() {
      if (_expandedResources.contains(resource)) {
        _expandedResources.remove(resource);
      } else {
        _expandedResources.add(resource);
      }
    });
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  /// Serialises the current [_permissions] to a JSON string in the
  /// list-of-objects format: `[{"resource": "users", "actions": ["read"]}]`.
  String _serialisePermissions() {
    final grouped = <String, List<String>>{};
    for (final e in _permissions.entries) {
      if (!e.value) continue;
      final parts = e.key.split('.');
      if (parts.length < 2) continue;
      final resource = parts.first;
      final action = parts.skip(1).join('.');
      grouped.putIfAbsent(resource, () => []).add(action);
    }
    final list = grouped.entries
        .map((e) => {'resource': e.key, 'actions': e.value})
        .toList();
    return jsonEncode(list);
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool _validate() {
    final name = _nameCtrl.text.trim();
    String? nameErr;

    if (name.length < 2) {
      nameErr = 'Role name must be at least 2 characters.';
    }

    setState(() {
      _nameError = nameErr;
      _submitError = null;
    });

    return nameErr == null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validate()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final id = ObjectId().oid;
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();

      await rolesDao.createRole(
        RolesCompanion(
          id: Value(id),
          name: Value(name),
          description: Value(desc.isEmpty ? null : desc),
          permissions: Value(_serialisePermissions()),
          created: Value(nowSeconds),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Role '$name' created."),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitError = 'Failed to create role: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Resource helpers ────────────────────────────────────────────────────────

  int _resourceSelectedCount(String resource, List<String> actions) {
    return actions.where((a) => _permissions['$resource.$a'] == true).length;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

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

          // ── Header ──────────────────────────────────────────────────────
          _SheetHeader(submitting: _submitting, onSubmit: _submit, cs: cs),

          Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),

          // ── Form body ───────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error banner.
                  if (_submitError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _submitError!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Details card ────────────────────────────────────────
                  _FormCard(
                    cs: cs,
                    isLight: isLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormLabel(label: 'Name', cs: cs),
                        const SizedBox(height: 6),
                        _FormTextField(
                          controller: _nameCtrl,
                          hint: 'Role name',
                          cs: cs,
                          error: _nameError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _FormLabel(label: 'Description', cs: cs),
                        const SizedBox(height: 6),
                        _FormTextField(
                          controller: _descCtrl,
                          hint: 'Optional description',
                          cs: cs,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Permissions header ──────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'PERMISSIONS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_totalSelectedCount / $_totalPermissionCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      const Spacer(),
                      _SelectAllButton(
                        allSelected: _allSelected,
                        onTap: _toggleSelectAll,
                        cs: cs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Permission groups.
                  ..._resourceGroups.asMap().entries.map((groupEntry) {
                    final gi = groupEntry.key;
                    final group = groupEntry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: gi < _resourceGroups.length - 1 ? 20 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section header.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              group.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.45,
                                ),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          // Resource rows.
                          ...group.resources.entries.map((entry) {
                            final resource = entry.key;
                            final actions = entry.value;
                            final selectedCount = _resourceSelectedCount(
                              resource,
                              actions,
                            );

                            return _ResourceRow(
                              resource: resource,
                              actions: actions,
                              permissions: _permissions,
                              selectedCount: selectedCount,
                              totalCount: actions.length,
                              isExpanded: _expandedResources.contains(resource),
                              isLight: isLight,
                              onToggleExpand: () => _toggleExpand(resource),
                              onToggleAll: () =>
                                  _toggleResourceAll(resource, actions),
                              onTogglePermission: _togglePermission,
                              cs: cs,
                            );
                          }),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
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
    required this.submitting,
    required this.onSubmit,
    required this.cs,
  });

  final bool submitting;
  final VoidCallback onSubmit;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Create Role',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Save button.
          TextButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.primary,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.cs,
    required this.isLight,
    required this.child,
  });

  final ColorScheme cs;
  final bool isLight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          if (isLight)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 1,
            ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select all / deselect all button
// ─────────────────────────────────────────────────────────────────────────────

class _SelectAllButton extends StatelessWidget {
  const _SelectAllButton({
    required this.allSelected,
    required this.onTap,
    required this.cs,
  });

  final bool allSelected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: allSelected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
          color: allSelected
              ? cs.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              size: 13,
              color: allSelected
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 5),
            Text(
              allSelected ? 'Deselect all' : 'Select all',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: allSelected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resource row — expandable, with per-resource select-all
// ─────────────────────────────────────────────────────────────────────────────

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.actions,
    required this.permissions,
    required this.selectedCount,
    required this.totalCount,
    required this.isExpanded,
    required this.isLight,
    required this.onToggleExpand,
    required this.onToggleAll,
    required this.onTogglePermission,
    required this.cs,
  });

  final String resource;
  final List<String> actions;
  final Map<String, bool> permissions;
  final int selectedCount;
  final int totalCount;
  final bool isExpanded;
  final bool isLight;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleAll;
  final void Function(String key) onTogglePermission;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final allOn = selectedCount == totalCount;
    final activeActions = actions
        .where((a) => permissions['$resource.$a'] == true)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isLight ? Colors.white : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
              blurRadius: isExpanded ? 6 : 3,
              offset: const Offset(0, 1),
            ),
            if (isLight)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 1,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Collapsed header row ────────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      // Expand indicator.
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Resource name.
                      Expanded(
                        child: Text(
                          _capitalise(resource),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),

                      // Count chip.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selectedCount > 0
                              ? cs.primary.withValues(alpha: 0.08)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: selectedCount > 0
                                ? cs.primary.withValues(alpha: 0.25)
                                : cs.outlineVariant.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '$selectedCount/$totalCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selectedCount > 0
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Coloured action icons (collapsed summary).
                      ...activeActions.map((action) {
                        final color =
                            _kActionColors[action] ?? cs.onSurfaceVariant;
                        final icon =
                            _kActionIcons[action] ?? Icons.circle_outlined;
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Tooltip(
                            message: action,
                            child: Icon(
                              icon,
                              size: 15,
                              color: color.withValues(alpha: 0.75),
                            ),
                          ),
                        );
                      }),

                      // Select all toggle.
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onToggleAll,
                        behavior: HitTestBehavior.opaque,
                        child: Tooltip(
                          message: allOn ? 'Deselect all' : 'Select all',
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: allOn
                                  ? cs.primary.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: allOn
                                    ? cs.primary.withValues(alpha: 0.4)
                                    : cs.outlineVariant.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              allOn ? Icons.check_rounded : Icons.add_rounded,
                              size: 14,
                              color: allOn
                                  ? cs.primary
                                  : cs.onSurfaceVariant.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Expanded detail ─────────────────────────────────────────
            if (isExpanded)
              _ExpandedPermissions(
                resource: resource,
                actions: actions,
                permissions: permissions,
                isLight: isLight,
                onToggle: onTogglePermission,
                cs: cs,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded permissions detail
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandedPermissions extends StatelessWidget {
  const _ExpandedPermissions({
    required this.resource,
    required this.actions,
    required this.permissions,
    required this.isLight,
    required this.onToggle,
    required this.cs,
  });

  final String resource;
  final List<String> actions;
  final Map<String, bool> permissions;
  final bool isLight;
  final void Function(String key) onToggle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isLight ? cs.surfaceContainerLowest : cs.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions.map((action) {
            final key = '$resource.$action';
            final isOn = permissions[key] == true;
            final color = _kActionColors[action] ?? cs.onSurfaceVariant;
            final icon = _kActionIcons[action] ?? Icons.circle_outlined;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onToggle(key),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isOn
                            ? color.withValues(alpha: 0.85)
                            : cs.onSurfaceVariant.withValues(alpha: 0.25),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _capitalise(action),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isOn
                                ? cs.onSurface
                                : cs.onSurfaceVariant.withValues(alpha: 0.4),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        height: 22,
                        child: FittedBox(
                          child: Switch(
                            value: isOn,
                            onChanged: (_) => onToggle(key),
                            activeTrackColor: color.withValues(alpha: 0.3),
                            activeThumbColor: color,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
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
    this.error,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final ColorScheme cs;
  final String? error;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
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
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: error != null
                    ? cs.error
                    : cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: error != null
                    ? cs.error
                    : cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: error != null ? cs.error : cs.primary,
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.error,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}
