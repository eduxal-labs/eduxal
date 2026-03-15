import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart' as models;
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_sheet.dart';
import 'role_detail_screen.dart';
import 'role_detail_sheet.dart';

/// The Roles data section of the system dashboard.
///
/// Shows a reactive list of system-level roles (school IS NULL) from
/// [RolesDao.watchSystemRoles], with client-side name search.
///
/// On **mobile** this is the body of the Roles tab.
/// On **desktop** this is the content inside the Roles tab of the data area.
class RolesSection extends StatefulWidget {
  const RolesSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<RolesSection> {
  // ── Filter state ───────────────────────────────────────────────────────────

  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Search debounce ────────────────────────────────────────────────────────

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<Role> _applyFilters(List<Role> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openDetail(BuildContext context, Role role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RoleDetailScreen(role: role, permissions: widget.permissions),
      ),
    );
  }

  void _openEditSheet(BuildContext context, Role role) {
    showEduSheet(
      context: context,
      title: 'Role Details',
      maxWidth: 480,
      builder: (_) =>
          RoleDetailSheet(role: role, permissions: widget.permissions),
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
      await rolesDao.deleteRole(role.id, accountId: accountId);
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
      // Purge uses the same deleteRole DAO call — it's a hard delete.
      await rolesDao.deleteRole(role.id, accountId: accountId);
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

    return StreamBuilder<List<Role>>(
      stream: rolesDao.watchSystemRoles(),
      builder: (context, snapshot) {
        final allRoles = snapshot.data ?? [];
        final filtered = _applyFilters(allRoles);

        return Column(
          children: [
            // ── Toolbar ────────────────────────────────────────────────────
            _Toolbar(searchController: _searchController, cs: cs),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No roles found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No roles match your search.'
                                : 'Create a system role to get started.',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final role = filtered[index];
                        final actions = <EduDataTableAction<Role>>[
                          EduDataTableAction(
                            icon: Icons.open_in_new_rounded,
                            label: 'View',
                            onTap: (r) => _openDetail(context, r),
                          ),
                        ];

                        if (widget.permissions.can(
                          models.Resource.roles,
                          models.Action.update,
                        )) {
                          actions.add(
                            EduDataTableAction(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              onTap: (r) => _openEditSheet(context, r),
                            ),
                          );
                        }

                        if (widget.permissions.can(
                          models.Resource.roles,
                          models.Action.delete,
                        )) {
                          actions.add(
                            EduDataTableAction(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              isDestructive: true,
                              onTap: (r) => _deleteRole(context, r),
                            ),
                          );
                        }

                        if (widget.permissions.level == UserLevel.super_) {
                          actions.add(
                            EduDataTableAction(
                              icon: Icons.delete_forever_rounded,
                              label: 'Purge',
                              isDestructive: true,
                              onTap: (r) => _purgeRole(context, r),
                            ),
                          );
                        }

                        return _RoleCard(
                          role: role,
                          onTap: () => _openDetail(context, role),
                          actions: actions,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role identity cell — icon + name only
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.role,
    required this.onTap,
    required this.actions,
  });

  final Role role;
  final VoidCallback onTap;
  final List<EduDataTableAction<Role>> actions;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _RoleIdentityCell(role: widget.role),
                  ),
                  if (!isMobile)
                    Expanded(
                      flex: 3,
                      child: _RoleDescriptionCell(role: widget.role),
                    ),
                  _RolePermissionsBadge(role: widget.role),
                  if (widget.actions.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    if (isMobile)
                      MenuAnchor(
                        builder: (context, controller, child) {
                          return IconButton(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                          );
                        },
                        menuChildren: widget.actions.map((action) {
                          return MenuItemButton(
                            leadingIcon: Icon(
                              action.icon,
                              size: 18,
                              color: action.color ?? cs.onSurfaceVariant,
                            ),
                            child: Text(
                              action.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: action.color ?? cs.onSurface,
                              ),
                            ),
                            onPressed: () => action.onTap(widget.role),
                          );
                        }).toList(),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.actions.map((action) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Tooltip(
                              message: action.label,
                              child: Material(
                                color:
                                    action.color?.withValues(alpha: 0.1) ??
                                    cs.surfaceContainerHighest,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => action.onTap(widget.role),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      action.icon,
                                      size: 18,
                                      color:
                                          action.color ?? cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleIdentityCell extends StatelessWidget {
  const _RoleIdentityCell({required this.role});

  final Role role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Row(
      children: [
        // ── Role icon ──────────────────────────────────────────────────
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

        // ── Name ───────────────────────────────────────────────────────
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
          color: cs.onSurfaceVariant,
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
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.searchController, required this.cs});

  final TextEditingController searchController;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 42,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: TextField(
          controller: searchController,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            filled: false,
            hintText: 'Search roles...',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List shimmer — loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ListShimmer extends StatefulWidget {
  const _ListShimmer();

  @override
  State<_ListShimmer> createState() => _ListShimmerState();
}

class _ListShimmerState extends State<_ListShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainer;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            indent: 52,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
                        end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
                        colors: [baseColor, highlightColor, baseColor],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBar(110, 12, baseColor, highlightColor),
                        const SizedBox(height: 6),
                        _shimmerBar(70, 10, baseColor, highlightColor),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerBar(
    double width,
    double height,
    Color baseColor,
    Color highlightColor,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * _animation.value, 0),
          end: Alignment(-1.0 + 2.0 * _animation.value + 1.0, 0),
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
