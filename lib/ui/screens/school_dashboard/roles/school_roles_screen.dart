import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import 'package:bson/bson.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/school_scopes_dao.dart';
import '../../../../database/tables/enums.dart';

import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_sheet.dart';
import '_role_helpers.dart';
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

  void _showCreateSheet(BuildContext context, {Role? existing}) {
    showEduSheet<void>(
      context: context,
      builder: (_) => _RoleFormSheet(
        schoolId: _schoolId,
        dao: _dao,
        existing: existing,
        schoolContext: widget.schoolContext,
      ),
    );
  }

  // TODO: Implement soft-delete for roles when a role status column is added.
  // Currently there is no soft-delete path — both Delete and Purge call the
  // same DAO hard-delete method. To avoid confusing users with two identical
  // destructive actions, the Delete button is hidden from the UI. Only Purge
  // is shown (Super users only). Re-enable Delete once soft-delete exists.
  // ignore: unused_element
  Future<void> _deleteRole(BuildContext context, Role role) async {
    // Stub — soft-delete not yet implemented.
  }

  Future<void> _purgeRole(BuildContext context, Role role) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Permanently destroy role',
      message:
          'Permanently destroy "${role.name}"? This cannot be undone.\n\n'
          'The role and all its permission assignments will be '
          'irrecoverably removed.',
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
    final entry = widget.schoolContext.currentEntry.value;
    final isOwner = entry is OwnerEntry;
    final perms = widget.schoolContext.permissions;

    // Defense-in-depth: nav routing should prevent unauthorized access,
    // but guard here as well.
    if (!isOwner && !perms.can(Resource.roles, Action.read)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Access restricted'),
            SizedBox(height: 4),
            Text(
              'You don\'t have permission to view roles.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final canCreate = isOwner || perms.can(Resource.roles, Action.create);
    final canEdit = isOwner || perms.can(Resource.roles, Action.update);

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
                              if (canEdit)
                                EduDataTableAction<Role>(
                                  icon: Icons.edit_outlined,
                                  label: 'Edit',
                                  onTap: (r) =>
                                      _showCreateSheet(context, existing: r),
                                ),
                              // NOTE: Delete button hidden — roles currently
                              // only support hard delete (purge). Soft-delete
                              // will be added when a role status column exists.
                              // Until then, only Purge is shown to Super users.
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
            if (canCreate)
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

  static int _permissionCount(Uint8List blob) {
    return countPermissions(parsePermissionsBlob(blob));
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
// Role create / edit sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RoleFormSheet extends StatefulWidget {
  const _RoleFormSheet({
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
    this.existing,
  });
  final String schoolId;
  final SchoolScopesDao dao;
  final SchoolContext schoolContext;
  final Role? existing;

  @override
  State<_RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<_RoleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  // ── Permission state ────────────────────────────────────────────────────
  late final List<ResourceGroup> _resourceGroups = buildResourceGroups();
  final Map<Resource, int> _permissions = {};
  final Set<Resource> _expandedResources = {};

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    if (e != null) {
      _permissions.addAll(parsePermissionsBlob(e.permissions));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty => _nameCtrl.text.trim().isNotEmpty;

  // ── Permission toggles ─────────────────────────────────────────────────

  // ── Editor permission helpers ───────────────────────────────────────────
  bool get _isOwner => widget.schoolContext.currentEntry.value is OwnerEntry;

  bool _canEditPermission(Resource r, Action a) =>
      _isOwner || widget.schoolContext.permissions.can(r, a);

  void _togglePermission(Resource r, Action a) {
    if (!_canEditPermission(r, a)) return;
    setState(() {
      final current = _permissions[r] ?? 0;
      _permissions[r] = current ^ a.mask;
      if (_permissions[r] == 0) _permissions.remove(r);
    });
  }

  void _toggleResourceAll(Resource r) {
    setState(() {
      final allMask = r.applicableActions
          .where((a) => _canEditPermission(r, a))
          .fold<int>(0, (m, a) => m | a.mask);
      if (allMask == 0) return;
      final current = _permissions[r] ?? 0;
      // Only consider the bits the editor can toggle
      if ((current & allMask) == allMask) {
        // All editable bits are on — turn them off
        _permissions[r] = current & ~allMask;
        if (_permissions[r] == 0) _permissions.remove(r);
      } else {
        _permissions[r] = current | allMask;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final editablePerms = <Resource, int>{};
      for (final g in _resourceGroups) {
        for (final r in g.resources) {
          final mask = r.applicableActions
              .where((a) => _canEditPermission(r, a))
              .fold<int>(0, (m, a) => m | a.mask);
          if (mask != 0) editablePerms[r] = mask;
        }
      }
      final totalPossible = editablePerms.values.fold<int>(
        0,
        (s, v) => s + popcount(v),
      );
      // Count only editable bits in current permissions
      int totalCurrent = 0;
      for (final entry in editablePerms.entries) {
        totalCurrent += popcount((_permissions[entry.key] ?? 0) & entry.value);
      }
      if (totalCurrent == totalPossible) {
        // All editable bits on — clear only the editable bits
        for (final entry in editablePerms.entries) {
          final r = entry.key;
          final newMask = (_permissions[r] ?? 0) & ~entry.value;
          if (newMask == 0) {
            _permissions.remove(r);
          } else {
            _permissions[r] = newMask;
          }
        }
      } else {
        for (final entry in editablePerms.entries) {
          _permissions[entry.key] =
              (_permissions[entry.key] ?? 0) | entry.value;
        }
      }
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = cache.currentUser?.user;
    if (user == null) return;

    // ── Privilege escalation guard ────────────────────────────────────────
    if (!_isOwner) {
      final editorPerms = widget.schoolContext.permissions;
      for (final entry in _permissions.entries) {
        final resource = entry.key;
        final mask = entry.value;
        for (final action in Action.values) {
          if (mask & action.mask != 0 && !editorPerms.can(resource, action)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot grant permissions you do not hold.'),
                ),
              );
            }
            return;
          }
        }
      }
    }

    setState(() => _saving = true);
    try {
      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final blob = Permissions(_permissions).toBlob();
      debugPrint('[_RoleFormSheet._save] blob: ${blob.length} bytes');
      debugPrint(
        '[_RoleFormSheet._save] roundtrip: ${parsePermissionsBlob(blob)}',
      );

      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();

      if (_isEditing) {
        await widget.dao.updateRole(
          widget.existing!.id,
          RolesCompanion(
            name: Value(_nameCtrl.text.trim()),
            description: Value(desc),
            permissions: Value(blob),
            updated: Value(nowMs),
          ),
          accountId: user.id,
        );
      } else {
        final id = ObjectId().oid;
        await widget.dao.createRole(
          RolesCompanion(
            id: Value(id),
            school: Value(widget.schoolId),
            name: Value(_nameCtrl.text.trim()),
            description: Value(desc),
            permissions: Value(blob),
            created: Value(nowMs),
            updated: Value(nowMs),
          ),
          accountId: user.id,
        );
      }
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
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ─────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Text(
              _isEditing ? 'Edit Role' : 'New Role',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Scrollable form fields ─────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, viewInsetsBottom + 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Name field ───────────────────────────────────────
                    EduFormField(
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

                    const SizedBox(height: 10),

                    // ── Description field ────────────────────────────────
                    EduFormField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Optional',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    // ── Divider ──────────────────────────────────────────
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppTheme.borderColor(isDark, cs),
                    ),

                    const SizedBox(height: 12),

                    // ── Permissions header ───────────────────────────────
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: countPermissions(_permissions) > 0
                                ? cs.primary.withValues(alpha: 0.08)
                                : cs.surfaceContainerHighest.withValues(
                                    alpha: 0.5,
                                  ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.kChipRadius,
                            ),
                          ),
                          child: Text(
                            '${countPermissions(_permissions)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: countPermissions(_permissions) > 0
                                  ? cs.primary.withValues(alpha: 0.8)
                                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _toggleSelectAll,
                          child: Text(
                            'Select All',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: cs.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Permission groups ────────────────────────────────
                    ..._resourceGroups.asMap().entries.map((groupEntry) {
                      final gi = groupEntry.key;
                      final group = groupEntry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: gi < _resourceGroups.length - 1 ? 16 : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section header
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
                            // Resource rows
                            ...group.resources.map((resource) {
                              final currentMask = _permissions[resource] ?? 0;
                              final applicable = resource.applicableActions;
                              final activeCount = applicable
                                  .where((a) => currentMask & a.mask != 0)
                                  .length;
                              final totalCount = applicable.length;
                              final isExpanded = _expandedResources.contains(
                                resource,
                              );

                              return _PermResourceRow(
                                resource: resource,
                                activeCount: activeCount,
                                totalCount: totalCount,
                                isExpanded: isExpanded,
                                isDark: isDark,
                                onToggleExpand: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedResources.remove(resource);
                                    } else {
                                      _expandedResources.add(resource);
                                    }
                                  });
                                },
                                onToggleAll: () => _toggleResourceAll(resource),
                                cs: cs,
                                expandedChild: isExpanded
                                    ? _PermExpandedActions(
                                        resource: resource,
                                        permissions: _permissions,
                                        isDark: isDark,
                                        onToggle: _togglePermission,
                                        cs: cs,
                                        canEditPermission: _canEditPermission,
                                      )
                                    : null,
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),

          // ── Action buttons (fixed outside scroll) ──────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, viewInsetsBottom + 16),
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
// Inline permissions editor widgets (used by _RoleFormSheet)
// ─────────────────────────────────────────────────────────────────────────────

class _PermResourceRow extends StatelessWidget {
  const _PermResourceRow({
    required this.resource,
    required this.activeCount,
    required this.totalCount,
    required this.isExpanded,
    required this.isDark,
    required this.onToggleExpand,
    required this.onToggleAll,
    required this.cs,
    this.expandedChild,
  });

  final Resource resource;
  final int activeCount;
  final int totalCount;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleAll;
  final ColorScheme cs;
  final Widget? expandedChild;

  @override
  Widget build(BuildContext context) {
    final hasAny = activeCount > 0;
    final isLight = !isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isLight ? Colors.white : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
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
            // ── Collapsed header row ──────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggleExpand,
                onLongPress: onToggleAll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: Text(
                          resource.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      // Count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasAny
                              ? cs.primary.withValues(alpha: 0.08)
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.kChipRadius,
                          ),
                        ),
                        child: Text(
                          '$activeCount\u202F/\u202F$totalCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: hasAny
                                ? cs.primary.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant.withValues(alpha: 0.4),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expandedChild != null) expandedChild!,
          ],
        ),
      ),
    );
  }
}

class _PermExpandedActions extends StatelessWidget {
  const _PermExpandedActions({
    required this.resource,
    required this.permissions,
    required this.isDark,
    required this.onToggle,
    required this.cs,
    this.canEditPermission,
  });

  final Resource resource;
  final Map<Resource, int> permissions;
  final bool isDark;
  final void Function(Resource r, Action a) onToggle;
  final ColorScheme cs;
  final bool Function(Resource r, Action a)? canEditPermission;

  @override
  Widget build(BuildContext context) {
    final applicableActions = resource.applicableActions;
    final currentMask = permissions[resource] ?? 0;
    final isLight = !isDark;

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
          children: applicableActions.map((action) {
            final isOn = (currentMask & action.mask) != 0;
            final editable = canEditPermission?.call(resource, action) ?? true;
            final color = kActionColors[action] ?? cs.primary;
            final icon = kActionIcons[action] ?? Icons.help_outline;

            return Opacity(
              opacity: editable ? 1.0 : 0.4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: editable ? () => onToggle(resource, action) : null,
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
                            action.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: isOn
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant.withValues(alpha: 0.45),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        if (!editable)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                            ),
                          ),
                        SizedBox(
                          width: 36,
                          height: 22,
                          child: FittedBox(
                            child: Switch(
                              value: isOn,
                              onChanged: editable
                                  ? (_) => onToggle(resource, action)
                                  : null,
                              activeTrackColor: color.withValues(alpha: 0.3),
                              activeThumbColor: color,
                              inactiveTrackColor: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              inactiveThumbColor: cs.onSurfaceVariant
                                  .withValues(alpha: 0.3),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
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
