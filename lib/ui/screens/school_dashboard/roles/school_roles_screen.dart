import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:bson/bson.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/school_scopes_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart' as models;
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_sheet.dart';
import 'school_role_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local permission helpers (mirrored from school_role_detail_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _kLocalBaseActions = ['read', 'create', 'update', 'delete'];

List<_LocalResourceGroup> _buildLocalResourceGroups() {
  List<String> a([List<String> actions = _kLocalBaseActions]) => actions;
  return <_LocalResourceGroup>[
    _LocalResourceGroup('People', {
      'users': a(),
      'students': a(),
      'guardians': a(),
      'teachers': a(),
      'staff': a(),
    }),
    _LocalResourceGroup('Academic', {
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
    _LocalResourceGroup('Finance', {
      'fees': a(),
      'invoices': a(),
      'payments': a(),
      'discounts': a(),
      'subscriptions': a(),
    }),
    _LocalResourceGroup('School Admin', {
      'schools': a(),
      'departments': a(),
      'owners': a(['read', 'create', 'delete']),
      'settings': a(['read', 'update']),
      'announcements': a(),
      'aiusage': a(['read', 'update']),
    }),
    _LocalResourceGroup('System', {
      'roles': a(),
      'scopes': a(['read', 'create', 'delete']),
      'plans': a(),
    }),
  ];
}

class _LocalResourceGroup {
  const _LocalResourceGroup(this.label, this.resources);
  final String label;
  final Map<String, List<String>> resources;
}

const _kLocalActionColors = <String, Color>{
  'read': Color(0xFF42A5F5),
  'create': Color(0xFF66BB6A),
  'update': Color(0xFFFFA726),
  'delete': Color(0xFFEF5350),
};

const _kLocalActionIcons = <String, IconData>{
  'read': Icons.visibility_outlined,
  'create': Icons.add_circle_outline,
  'update': Icons.edit_outlined,
  'delete': Icons.delete_outline_rounded,
};

String _localSerialisePermissions(Map<String, bool> perms) {
  final grouped = <String, List<String>>{};
  for (final e in perms.entries) {
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

String _localCapitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class SchoolRolesScreen extends StatelessWidget {
  const SchoolRolesScreen({super.key, required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return _SchoolRolesBody(schoolContext: schoolContext);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body — EduDataTable-based role list + search + FAB
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolRolesBody extends StatefulWidget {
  const _SchoolRolesBody({required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  State<_SchoolRolesBody> createState() => _SchoolRolesBodyState();
}

class _SchoolRolesBodyState extends State<_SchoolRolesBody> {
  late final SchoolScopesDao _dao;
  late final TextEditingController _searchController;
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _dao = SchoolScopesDao(db);
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _schoolId => widget.schoolContext.membership.school.id;

  bool get _isSuper => cache.currentUser?.user.level == UserLevel.super_;

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  List<Role> _applyFilters(List<Role> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openDetail(BuildContext context, Role role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SchoolRoleDetailScreen(
          role: role,
          schoolContext: widget.schoolContext,
          dao: _dao,
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showEduSheet<void>(
      context: context,
      builder: (_) => _RoleFormSheet(schoolId: _schoolId, dao: _dao),
    );
  }

  Future<void> _deleteRole(BuildContext context, Role role) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete role',
      message:
          'Delete "${role.name}"?\n\n'
          'Users assigned this role will lose its permissions.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await _dao.deleteRole(role.id, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${role.name}" deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete role: $e')));
      }
    }
  }

  Future<void> _purgeRole(BuildContext context, Role role) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Permanently delete role',
      message:
          'Permanently delete "${role.name}"?\n\n'
          'This action is irreversible and will permanently remove '
          'this record from the local database.',
      confirmLabel: 'Purge',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await _dao.deleteRole(role.id, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${role.name}" permanently deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to purge role: $e')));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final perms = widget.schoolContext.permissions;

    return StreamBuilder<List<Role>>(
      stream: _dao.watchSchoolRoles(_schoolId),
      builder: (ctx, snap) {
        final allRoles = snap.data ?? [];
        final filtered = _applyFilters(allRoles);

        return Stack(
          children: [
            Column(
              children: [
                // ── Search toolbar ───────────────────────────────────────
                _SearchToolbar(searchController: _searchController, cs: cs),

                // ── Table ────────────────────────────────────────────────
                Expanded(
                  child: !snap.hasData
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        )
                      : SingleChildScrollView(
                          child: EduDataTable<Role>(
                            items: filtered,
                            emptyIcon: Icons.shield_outlined,
                            emptyTitle: _searchQuery.isNotEmpty
                                ? 'No roles found'
                                : 'No Custom Roles',
                            emptySubtitle: _searchQuery.isNotEmpty
                                ? 'No roles match your search.'
                                : 'Create roles with specific permissions to control what '
                                      'staff members can see and do.',
                            onItemTap: (r) => _openDetail(context, r),
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 88),
                            actions: (role) => [
                              EduDataTableAction<Role>(
                                icon: Icons.open_in_new_rounded,
                                label: 'View',
                                onTap: (r) => _openDetail(context, r),
                              ),
                              if (perms.can(
                                models.Resource.roles,
                                models.Action.update,
                              ))
                                EduDataTableAction<Role>(
                                  icon: Icons.edit_outlined,
                                  label: 'Edit',
                                  onTap: (_) => _showCreateSheet(context),
                                ),
                              if (perms.can(
                                models.Resource.roles,
                                models.Action.delete,
                              ))
                                EduDataTableAction<Role>(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Delete',
                                  isDestructive: true,
                                  onTap: (r) => _deleteRole(context, r),
                                ),
                              if (_isSuper)
                                EduDataTableAction<Role>(
                                  icon: Icons.delete_forever_rounded,
                                  label: 'Purge',
                                  isDestructive: true,
                                  onTap: (r) => _purgeRole(context, r),
                                ),
                            ],
                            columns: const [
                              EduDataTableColumn(label: 'Role', flex: 2),
                              EduDataTableColumn(label: 'Description', flex: 3),
                              EduDataTableColumn(label: 'Permissions', flex: 1),
                            ],
                            cellBuilder: (context, role, index, isHovered) {
                              return switch (index) {
                                0 => _RoleIdentityCell(role: role),
                                1 => _RoleDescriptionCell(role: role),
                                2 => _RolePermissionsBadge(role: role),
                                _ => const SizedBox.shrink(),
                              };
                            },
                          ),
                        ),
                ),
              ],
            ),

            // ── FAB ──────────────────────────────────────────────────────
            Positioned(
              right: 20,
              bottom: 24,
              child: FloatingActionButton.small(
                heroTag: 'fab_roles_create',
                onPressed: () => _showCreateSheet(context),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 4,
                highlightElevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({required this.searchController, required this.cs});

  final TextEditingController searchController;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: searchController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: 'Search roles…',
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: Icon(
                Icons.search_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 20,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (_, value, __) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  onPressed: () => searchController.clear(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  splashRadius: 14,
                );
              },
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1A2536)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              borderSide: BorderSide(
                color: cs.primary.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role identity cell — icon + name
// ─────────────────────────────────────────────────────────────────────────────

class _RoleIdentityCell extends StatelessWidget {
  const _RoleIdentityCell({required this.role});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 14,
            color: cs.primary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            role.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role description cell
// ─────────────────────────────────────────────────────────────────────────────

class _RoleDescriptionCell extends StatelessWidget {
  const _RoleDescriptionCell({required this.role});
  final Role role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDescription =
        role.description != null && role.description!.isNotEmpty;

    return Text(
      hasDescription ? role.description! : '—',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(
          alpha: hasDescription ? 0.8 : 0.5,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role permissions badge — descriptive count or dash
// ─────────────────────────────────────────────────────────────────────────────

class _RolePermissionsBadge extends StatelessWidget {
  const _RolePermissionsBadge({required this.role});
  final Role role;

  static int _permissionCount(String permissionsJson) {
    try {
      final decoded = jsonDecode(permissionsJson);
      if (decoded is! List) return 0;
      var count = 0;
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final actions = entry['actions'];
          if (actions is List) count += actions.length;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _permissionCount(role.permissions);
    final cs = Theme.of(context).colorScheme;

    if (count == 0) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    return Text(
      '$count ${count == 1 ? 'perm' : 'perms'}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role create sheet (create-only — editing is now done in the detail screen)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleFormSheet extends StatefulWidget {
  const _RoleFormSheet({required this.schoolId, required this.dao});
  final String schoolId;
  final SchoolScopesDao dao;

  @override
  State<_RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<_RoleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  /// Working permissions map: "resource.action" → bool
  final Map<String, bool> _permissions = {};

  /// Resources that are currently expanded in the picker
  final Set<String> _expandedResources = {};

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _hasAnyPermission => _permissions.values.any((v) => v);

  bool get _isDirty => _nameCtrl.text.trim().isNotEmpty || _hasAnyPermission;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = cache.currentUser?.user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final id = ObjectId().oid;

      await widget.dao.createRole(
        RolesCompanion(
          id: Value(id),
          school: Value(widget.schoolId),
          name: Value(_nameCtrl.text.trim()),
          description: Value(
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          ),
          permissions: Value(_localSerialisePermissions(_permissions)),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        accountId: user.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _togglePermission(String key) {
    setState(() {
      _permissions[key] = !(_permissions[key] ?? false);
    });
  }

  void _toggleExpand(String resource) {
    setState(() {
      if (_expandedResources.contains(resource)) {
        _expandedResources.remove(resource);
      } else {
        _expandedResources.add(resource);
      }
    });
  }

  Widget _buildFormContent(
    BuildContext context,
    ColorScheme cs,
    bool isDark, {
    required bool isSheet,
  }) {
    final groups = _buildLocalResourceGroups();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle (sheet only) ────────────────────────────────────────
          if (isSheet) ...[
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],

          // ── Header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Text(
                  'New Role',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(30, 30),
                  ),
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Name field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EduFormField(
              controller: _nameCtrl,
              label: 'Role name',
              hint: 'e.g. Registrar',
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Role name is required';
                return null;
              },
            ),
          ),

          const SizedBox(height: 10),

          // ── Description field ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EduFormField(
              controller: _descCtrl,
              label: 'Description',
              hint: 'Optional',
              maxLines: 2,
            ),
          ),

          const SizedBox(height: 12),

          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),

          // ── Permissions label ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'Permissions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),

          // ── Permissions resource list ──────────────────────────────────
          // Wrapped in a constrained box so the sheet doesn't grow unbounded
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in groups)
                    _buildPermGroup(group, cs, isDark),
                ],
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),

          // ── Footer ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              isSheet
                  ? (MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 24)
                  : 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSaveButton(
                  isDirty: _isDirty,
                  isSaving: _saving,
                  onSave: (_isDirty && !_saving) ? _save : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermGroup(
    _LocalResourceGroup group,
    ColorScheme cs,
    bool isDark,
  ) {
    // Only render resources that have at least one toggleable action
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Text(
            group.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              letterSpacing: 1.1,
            ),
          ),
        ),
        for (final entry in group.resources.entries)
          _buildResourceRow(entry.key, entry.value, cs, isDark),
      ],
    );
  }

  Widget _buildResourceRow(
    String resource,
    List<String> actions,
    ColorScheme cs,
    bool isDark,
  ) {
    final activeCount = actions
        .where((a) => _permissions['$resource.$a'] == true)
        .length;
    final isExpanded = _expandedResources.contains(resource);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Collapsed row ────────────────────────────────────────────────
        InkWell(
          onTap: () => _toggleExpand(resource),
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _localCapitalise(resource),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: activeCount > 0
                            ? cs.onSurface
                            : cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  if (activeCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        '$activeCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Expanded action buttons ──────────────────────────────────────
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final action in actions)
                  _buildActionChip(resource, action, cs),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionChip(String resource, String action, ColorScheme cs) {
    final key = '$resource.$action';
    final isActive = _permissions[key] == true;
    final icon = _kLocalActionIcons[action] ?? Icons.circle_outlined;
    final color = _kLocalActionColors[action] ?? cs.primary;

    return GestureDetector(
      onTap: () => _togglePermission(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Tooltip(
          message: _localCapitalise(action),
          child: Icon(
            icon,
            size: 14,
            color: isActive
                ? color
                : cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Wrapping (Dialog on desktop / bottom sheet on mobile) is handled by
    // showEduSheet — this widget only returns the form content.
    // isSheet: false so we don't render a duplicate drag handle (EduSheet
    // already provides one on mobile).
    return _buildFormContent(context, cs, isDark, isSheet: false);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
