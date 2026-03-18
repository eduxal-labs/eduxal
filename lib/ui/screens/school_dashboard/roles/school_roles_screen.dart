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
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_sheet.dart';
import 'school_role_detail_screen.dart';

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
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
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

  bool get _isDirty => _nameCtrl.text.trim().isNotEmpty;

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
          permissions: const Value('[]'),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ─────────────────────────────────────────────────────
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

          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Text(
              'New Role',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),

          const SizedBox(height: 14),

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
                if (v == null || v.trim().isEmpty) {
                  return 'Role name is required';
                }
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

          // ── Action buttons ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 24,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancel
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    tooltip: 'Cancel',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Save
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    onPressed: (_isDirty && !_saving) ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    tooltip: 'Save',
                    style: IconButton.styleFrom(
                      backgroundColor: (_isDirty && !_saving)
                          ? Colors.green.shade600
                          : Colors.green.shade600.withValues(alpha: 0.4),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
