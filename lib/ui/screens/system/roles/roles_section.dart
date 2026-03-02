import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
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
  final Set<String> _selectedIds = {};

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

  // ── Build ───────────────────────────────────────────────────────────────────

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
            if (_selectedIds.isNotEmpty)
              Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                color: cs.primaryContainer.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _selectedIds.clear()),
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${_selectedIds.length} selected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        // TODO: Bulk delete
                      },
                      color: cs.error,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () {
                        // TODO: Bulk actions
                      },
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              )
            else
              _Toolbar(searchController: _searchController, cs: cs),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : filtered.isEmpty
                  ? _EmptyState(hasQuery: _searchQuery.isNotEmpty, cs: cs)
                  : _RoleList(
                      roles: filtered,
                      selectedIds: _selectedIds,
                      onTap: (r) {
                        if (_selectedIds.isNotEmpty) {
                          setState(() {
                            if (_selectedIds.contains(r.id)) {
                              _selectedIds.remove(r.id);
                            } else {
                              _selectedIds.add(r.id);
                            }
                          });
                        } else {
                          _openDetail(context, r);
                        }
                      },
                      onLongPress: (r) {
                        setState(() {
                          _selectedIds.add(r.id);
                        });
                      },
                      onToggleSelection: (r) {
                        setState(() {
                          if (_selectedIds.contains(r.id)) {
                            _selectedIds.remove(r.id);
                          } else {
                            _selectedIds.add(r.id);
                          }
                        });
                      },
                      cs: cs,
                    ),
            ),
          ],
        );
      },
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
          separatorBuilder: (_, _) => Divider(
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
                  // Rounded rect icon placeholder.
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

// ─────────────────────────────────────────────────────────────────────────────
// Role list
// ─────────────────────────────────────────────────────────────────────────────

class _RoleList extends StatelessWidget {
  const _RoleList({
    required this.roles,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.cs,
  });

  final List<Role> roles;
  final Set<String> selectedIds;
  final void Function(Role) onTap;
  final void Function(Role) onLongPress;
  final void Function(Role) onToggleSelection;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final selectionMode = selectedIds.isNotEmpty;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: roles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = roles[index];
        final isSelected = selectedIds.contains(r.id);

        return _RoleRow(
          role: r,
          isSelected: isSelected,
          selectionMode: selectionMode,
          onTap: () => onTap(r),
          onLongPress: () => onLongPress(r),
          onToggleSelection: () => onToggleSelection(r),
          cs: cs,
        );
      },
    );
  }
}

class _RoleRow extends StatefulWidget {
  const _RoleRow({
    required this.role,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.cs,
  });

  final Role role;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;
  final ColorScheme cs;

  @override
  State<_RoleRow> createState() => _RoleRowState();
}

class _RoleRowState extends State<_RoleRow> {
  bool _isHovering = false;

  /// Counts the total number of `resource.action` permission keys in the
  /// role's permissions JSON (new list-of-objects format).
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
    final cs = widget.cs;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
    final count = _permissionCount(widget.role.permissions);

    final isDark = cs.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? cs.primaryContainer.withValues(alpha: isDark ? 0.2 : 0.3)
            : _isHovering && !widget.selectionMode
            ? cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.3)
            : isDark
            ? cs.surface
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected
              ? cs.primary
              : isDark
              ? cs.outline.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onHover: (hovering) {
            if (isDesktop) {
              setState(() => _isHovering = hovering);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (widget.selectionMode || (_isHovering && isDesktop)) ...[
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggleSelection(),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Role icon.
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: isDark ? 0.3 : 0.18),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: cs.primary.withValues(alpha: isDark ? 0.85 : 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.role.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.role.description != null &&
                          widget.role.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.role.description!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Permission count badge.
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark
                            ? cs.outline.withValues(alpha: 0.5)
                            : cs.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (!widget.selectionMode) ...[
                  const SizedBox(width: 12),
                  if (isDesktop)
                    IgnorePointer(
                      ignoring: !_isHovering,
                      child: AnimatedOpacity(
                        opacity: _isHovering ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              iconSize: 18,
                              color: cs.onSurfaceVariant,
                              onPressed: widget.onTap,
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              iconSize: 18,
                              color: cs.error,
                              onPressed: () {
                                // Handle delete action (TODO)
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      color: cs.surfaceContainerHighest,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark
                              ? cs.outline.withValues(alpha: 0.5)
                              : cs.outlineVariant,
                          width: 1,
                        ),
                      ),
                      position: PopupMenuPosition.under,
                      onSelected: (val) {
                        if (val == 'edit') {
                          widget.onTap();
                        } else if (val == 'delete') {
                          // Handle delete action (TODO)
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: cs.onSurface,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: cs.error,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: TextStyle(fontSize: 13, color: cs.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.cs});

  final bool hasQuery;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'No roles match your search.' : 'No roles yet.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
