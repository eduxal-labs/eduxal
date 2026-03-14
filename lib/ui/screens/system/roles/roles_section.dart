import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../models/permissions.dart' as models;
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_data_table.dart';
import 'role_detail_screen.dart';

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

  Future<void> _deleteRole(BuildContext context, Role role) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Delete role'),
        content: Text(
          'Delete "${role.name}"?\n\nUsers assigned this role will lose its permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
                  : SingleChildScrollView(
                      child: EduDataTable<Role>(
                        items: filtered,
                        emptyIcon: Icons.verified_user_outlined,
                        emptyTitle: 'No roles found',
                        emptySubtitle: _searchQuery.isNotEmpty
                            ? 'No roles match your search.'
                            : 'Create a system role to get started.',
                        onItemTap: (r) => _openDetail(context, r),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        actions: (role) => [
                          EduDataTableAction<Role>(
                            icon: Icons.open_in_new_rounded,
                            label: 'View',
                            onTap: (r) => _openDetail(context, r),
                          ),
                          if (widget.permissions.can(
                            models.Resource.roles,
                            models.Action.delete,
                          ))
                            EduDataTableAction<Role>(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              isDestructive: true,
                              onTap: (r) => _deleteRole(context, r),
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role identity cell — icon + name only
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
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: searchController,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by role name…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
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
          separatorBuilder: (_, __) => Divider(
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
