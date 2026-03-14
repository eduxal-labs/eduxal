import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:bson/bson.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/school_scopes_dao.dart';

import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
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
// Body — single flat list of role cards + FAB
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolRolesBody extends StatefulWidget {
  const _SchoolRolesBody({required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  State<_SchoolRolesBody> createState() => _SchoolRolesBodyState();
}

class _SchoolRolesBodyState extends State<_SchoolRolesBody> {
  late final SchoolScopesDao _dao;

  @override
  void initState() {
    super.initState();
    _dao = SchoolScopesDao(db);
  }

  String get _schoolId => widget.schoolContext.membership.school.id;

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
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppTheme.kMobileBreakpoint) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => _RoleFormSheet(schoolId: _schoolId, dao: _dao),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RoleFormSheet(schoolId: _schoolId, dao: _dao),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Role>>(
      stream: _dao.watchSchoolRoles(_schoolId),
      builder: (ctx, snap) {
        final roles = snap.data ?? [];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          children: [
            if (roles.isEmpty &&
                snap.connectionState != ConnectionState.waiting)
              _EmptyState(
                icon: Icons.shield_outlined,
                title: 'No Custom Roles',
                subtitle:
                    'Create roles with specific permissions to control what '
                    'staff members can see and do.',
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                itemCount: roles.length,
                itemBuilder: (_, i) {
                  final role = roles[i];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RoleRow(
                        role: role,
                        onTap: () => _openDetail(context, roles[i]),
                        onEdit: () => _showCreateSheet(context),
                      ),
                      if (i < roles.length - 1)
                        AppTheme.tableRowDivider(isDark, cs),
                    ],
                  );
                },
              ),

            // ── FAB ─────────────────────────────────────────────────────
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
// Role row — data-table-style row (replaces old _RoleCard)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleRow extends StatefulWidget {
  const _RoleRow({
    required this.role,
    required this.onTap,
    required this.onEdit,
  });
  final Role role;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  State<_RoleRow> createState() => _RoleRowState();
}

class _RoleRowState extends State<_RoleRow> {
  bool _isHovered = false;

  bool get _isDesktop =>
      MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

  int _parsePermCount(String permJson) {
    try {
      final decoded = jsonDecode(permJson);
      if (decoded is List) {
        int count = 0;
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final actions = entry['actions'];
            if (actions is List) count += actions.length;
          }
        }
        return count;
      }
      if (decoded is Map) return decoded.length;
    } catch (_) {}
    return 0;
  }

  void _showMobileActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18222E) : cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.kModalRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // role name header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                widget.role.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              title: const Text(
                'Edit Role',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400),
              ),
              onTap: () {
                Navigator.of(context).pop();
                widget.onEdit();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final permCount = _parsePermCount(widget.role.permissions);
    final hasPerms = permCount > 0;
    final hoverColor = cs.primary.withValues(alpha: 0.04);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered ? hoverColor : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // ── Name + description ──────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.role.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.role.description != null &&
                              widget.role.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.role.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Permission count badge ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: hasPerms
                          ? cs.primary.withValues(alpha: 0.10)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    ),
                    child: Text(
                      hasPerms
                          ? '$permCount permission${permCount == 1 ? '' : 's'}'
                          : 'No permissions',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hasPerms
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // ── Desktop: inline edit button (hover-sensitive) ────────
                  if (_isDesktop)
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 100),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Tooltip(
                          message: 'Edit',
                          child: InkWell(
                            onTap: widget.onEdit,
                            splashFactory: NoSplash.splashFactory,
                            borderRadius: BorderRadius.circular(6),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    // ── Mobile: three-dot menu ────────────────────────────
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: InkWell(
                        onTap: () => _showMobileActions(context),
                        splashFactory: NoSplash.splashFactory,
                        borderRadius: BorderRadius.circular(6),
                        child: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),

                  // ── Chevron ────────────────────────────────────────────
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
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
            child: TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              decoration: _inputDeco(cs, 'Role name (e.g. Registrar)'),
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
            child: TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              decoration: _inputDeco(cs, 'Description (optional)'),
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      // ── Desktop: adaptive dialog ─────────────────────────────────────
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
              border: Border.all(
                color: AppTheme.borderColor(isDark, cs),
                width: 1,
              ),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
              child: _buildFormContent(context, cs, isDark, isSheet: false),
            ),
          ),
        ),
      );
    }

    // ── Mobile: bottom sheet ─────────────────────────────────────────────
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.kModalRadius),
          ),
          border: Border(
            top: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 1),
          ),
        ),
        child: _buildFormContent(context, cs, isDark, isSheet: true),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDeco(ColorScheme cs, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
    ),
    filled: true,
    fillColor: cs.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
