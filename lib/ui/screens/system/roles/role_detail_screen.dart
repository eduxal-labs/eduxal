import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_action_button.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../shared/role_permission_editor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, bool> _parsePermissions(Uint8List blob) {
  if (blob.isEmpty) return {};

  // Try canonical binary blob format first
  final perms = Permissions.fromBlob(blob);
  if (perms.isNotEmpty) {
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

  // Fallback: try UTF-8 JSON decode (legacy / migration compat)
  try {
    final json = utf8.decode(blob);
    final decoded = jsonDecode(json);
    if (decoded is List) {
      final result = <String, bool>{};
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final resource = entry['resource'];
          final actions = entry['actions'];
          if (resource is String && actions is List) {
            for (final action in actions) {
              if (action is String) {
                result['$resource.$action'] = true;
              }
            }
          }
        }
      }
      return result;
    }
  } catch (_) {}
  return {};
}

Uint8List _serialisePermissions(Map<String, bool> perms) {
  final map = <Resource, int>{};
  for (final entry in perms.entries) {
    if (!entry.value) continue;
    final parts = entry.key.split('.');
    if (parts.length < 2) continue;
    final resourceName = parts.first;
    final actionName = parts.skip(1).join('.');
    final resource = Resource.values
        .where((r) => r.name == resourceName)
        .firstOrNull;
    final action = Action.values.where((a) => a.name == actionName).firstOrNull;
    if (resource == null || action == null) continue;
    map[resource] = (map[resource] ?? 0) | action.mask;
  }
  return Permissions(map).toBlob();
}

Map<String, List<String>> _groupByResource(Map<String, bool> perms) {
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ═════════════════════════════════════════════════════════════════════════════
// RoleDetailScreen
// ═════════════════════════════════════════════════════════════════════════════

/// Full-page role detail screen, pushed onto the navigator from
/// [RolesSection] when the user taps a role row.
///
/// Contains:
/// - Header: role icon + name + description
/// - Tabs: Permissions, Assigned
class RoleDetailScreen extends StatefulWidget {
  const RoleDetailScreen({
    super.key,
    required this.role,
    required this.permissions,
  });

  final Role role;
  final SystemPermissions permissions;

  @override
  State<RoleDetailScreen> createState() => _RoleDetailScreenState();
}

class _RoleDetailScreenState extends State<RoleDetailScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _confirmDelete(Role role) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete role?',
      message:
          'Are you sure you want to delete "${role.name}"? '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await rolesDao.deleteRole(role.id, accountId: accountId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role "${role.name}" deleted.'),
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
    }
  }

  void _openAssignSheet(Role role) {
    showEduSheet(
      context: context,
      builder: (_) =>
          _AssignUserSheet(roleId: role.id, permissions: widget.permissions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppTheme.kMobileBreakpoint;
    final isLight = cs.brightness == Brightness.light;

    final maxWidth = isDesktop ? 760.0 : double.infinity;
    final horizontalPadding = isDesktop ? 28.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: StreamBuilder<List<Role>>(
          stream: rolesDao.watchSystemRoles(),
          builder: (context, snapshot) {
            final role =
                snapshot.data
                    ?.where((r) => r.id == widget.role.id)
                    .cast<Role?>()
                    .firstOrNull ??
                widget.role;
            return Text(
              role.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (widget.permissions.can(Resource.roles, Action.delete))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedActionButton(
                icon: Icons.delete_outline_rounded,
                iconSize: 18,
                color: cs.error.withValues(alpha: 0.7),
                backgroundColor: cs.surfaceContainer,
                size: 36,
                tooltip: 'Delete role',
                showCheckOnSuccess: false,
                onTap: () async => _confirmDelete(widget.role),
              ),
            ),
        ],
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: StreamBuilder<List<Role>>(
            stream: rolesDao.watchSystemRoles(),
            builder: (context, snapshot) {
              final role =
                  snapshot.data
                      ?.where((r) => r.id == widget.role.id)
                      .cast<Role?>()
                      .firstOrNull ??
                  widget.role;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              4,
                              horizontalPadding,
                              12,
                            ),
                            child: _HeaderSection(role: role, cs: cs),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarDelegate(
                            tabController: _tabController,
                            cs: cs,
                            isLight: isLight,
                            horizontalPadding: horizontalPadding,
                            canAssign: widget.permissions.can(
                              Resource.roles,
                              Action.assign,
                            ),
                            onAssign: () => _openAssignSheet(role),
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _PermissionsTab(
                          key: ValueKey('perms_${role.id}_${role.updated}'),
                          role: role,
                          permissions: widget.permissions,
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                        ),
                        _AssignedTab(
                          role: role,
                          permissions: widget.permissions,
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Header Section
// ═════════════════════════════════════════════════════════════════════════════

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.role, required this.cs});

  final Role role;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final perms = _parsePermissions(role.permissions);
    final grouped = _groupByResource(perms);
    final totalPerms = perms.values.where((v) => v).length;
    final totalResources = grouped.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                  size: 22,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        height: 1.2,
                        letterSpacing: -0.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role.description != null &&
                        role.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        role.description!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DetailChip(
                icon: Icons.shield_outlined,
                label: '$totalPerms permissions',
                cs: cs,
              ),
              _DetailChip(
                icon: Icons.category_outlined,
                label: '$totalResources resources',
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab Bar Delegate — includes + assign button visible on the Assigned tab
// ═════════════════════════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({
    required this.tabController,
    required this.cs,
    required this.isLight,
    required this.horizontalPadding,
    required this.canAssign,
    required this.onAssign,
  });

  final TabController tabController;
  final ColorScheme cs;
  final bool isLight;
  final double horizontalPadding;
  final bool canAssign;
  final VoidCallback onAssign;

  @override
  double get minExtent => 56.0;
  @override
  double get maxExtent => 56.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final hasScrolled = shrinkOffset > 0;

    return Container(
      decoration: BoxDecoration(
        color: scaffoldBg,
        border: Border(
          bottom: BorderSide(
            color: hasScrolled
                ? cs.outlineVariant
                : cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                height: 36,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isLight
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
                      : cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(
                      alpha: isLight ? 0.3 : 0.4,
                    ),
                    width: 0.5,
                  ),
                ),
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isLight ? Colors.white : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.06 : 0.15,
                        ),
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
                  labelColor: cs.onSurface,
                  unselectedLabelColor: cs.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                  tabs: const [
                    Tab(text: 'Permissions'),
                    Tab(text: 'Assigned'),
                  ],
                ),
              ),
            ),
          ),

          // + assign button — always visible when permitted.
          if (canAssign) ...[
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                // Only show on the Assigned tab.
                final isAssignedTab = tabController.index == 1;
                return AnimatedOpacity(
                  opacity: isAssignedTab ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(ignoring: !isAssignedTab, child: child),
                );
              },
              child: SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: onAssign,
                  icon: Icon(Icons.add_rounded, size: 18, color: cs.primary),
                  tooltip: 'Assign user',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// Permissions Tab
// ═════════════════════════════════════════════════════════════════════════════

class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab({
    super.key,
    required this.role,
    required this.permissions,
    required this.cs,
    required this.horizontalPadding,
  });

  final Role role;
  final SystemPermissions permissions;
  final ColorScheme cs;
  final double horizontalPadding;

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  /// The working copy of permissions — mutated during editing.
  late Map<String, bool> _editPermissions;

  /// The original permissions from the role at the start of editing.
  late Map<String, bool> _originalPermissions;

  /// Resources selected for bulk removal.
  final Set<Resource> _selectedResources = {};

  /// Resources that are currently expanded (showing full permission details).
  final Set<Resource> _expandedResources = {};

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _resetFromRole(widget.role);
  }

  @override
  void didUpdateWidget(_PermissionsTab old) {
    super.didUpdateWidget(old);
    // If the role changed from outside (stream update) and we're not mid-edit,
    // refresh the working copy.
    if (old.role.permissions != widget.role.permissions && !_hasChanges) {
      _resetFromRole(widget.role);
    }
  }

  void _resetFromRole(Role role) {
    _originalPermissions = _parsePermissions(role.permissions);
    _editPermissions = Map.of(_originalPermissions);
    _selectedResources.clear();
  }

  bool get _hasChanges {
    final allKeys = <String>{
      ..._originalPermissions.keys,
      ..._editPermissions.keys,
    };
    for (final k in allKeys) {
      final orig = _originalPermissions[k] == true;
      final curr = _editPermissions[k] == true;
      if (orig != curr) return true;
    }
    return false;
  }

  ({int added, int removed}) get _changeSummary {
    int added = 0;
    int removed = 0;
    final allKeys = <String>{
      ..._originalPermissions.keys,
      ..._editPermissions.keys,
    };
    for (final k in allKeys) {
      final orig = _originalPermissions[k] == true;
      final curr = _editPermissions[k] == true;
      if (!orig && curr) added++;
      if (orig && !curr) removed++;
    }
    return (added: added, removed: removed);
  }

  ({int added, int removed}) _resourceChangeSummary(Resource resource) {
    int added = 0;
    int removed = 0;
    final allKeys = <String>{
      ..._originalPermissions.keys,
      ..._editPermissions.keys,
    };
    for (final k in allKeys) {
      if (!k.startsWith('${resource.name}.')) continue;
      final orig = _originalPermissions[k] == true;
      final curr = _editPermissions[k] == true;
      if (!orig && curr) added++;
      if (orig && !curr) removed++;
    }
    return (added: added, removed: removed);
  }

  void _togglePermission(String key) {
    setState(() {
      final current = _editPermissions[key] == true;
      _editPermissions[key] = !current;
    });
  }

  void _removeResource(Resource resource) {
    setState(() {
      final keysToRemove = _editPermissions.keys
          .where((k) => k.startsWith('${resource.name}.'))
          .toList();
      for (final k in keysToRemove) {
        _editPermissions[k] = false;
      }
      _expandedResources.remove(resource);
      _selectedResources.remove(resource);
    });
  }

  void _removeSelectedResources() {
    setState(() {
      for (final resource in _selectedResources) {
        final keysToRemove = _editPermissions.keys
            .where((k) => k.startsWith('${resource.name}.'))
            .toList();
        for (final k in keysToRemove) {
          _editPermissions[k] = false;
        }
        _expandedResources.remove(resource);
      }
      _selectedResources.clear();
    });
  }

  void _toggleResourceSelection(Resource resource) {
    setState(() {
      if (_selectedResources.contains(resource)) {
        _selectedResources.remove(resource);
      } else {
        _selectedResources.add(resource);
      }
    });
  }

  void _toggleExpand(Resource resource) {
    setState(() {
      if (_expandedResources.contains(resource)) {
        _expandedResources.remove(resource);
      } else {
        _expandedResources.add(resource);
      }
    });
  }

  Future<void> _save() async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      // Privilege escalation guard — skip for Super users.
      if (widget.permissions.level != UserLevel.super_) {
        for (final entry in _editPermissions.entries) {
          if (!entry.value) continue;
          final parts = entry.key.split('.');
          if (parts.length < 2) continue;
          final resource = Resource.values
              .where((r) => r.name == parts.first)
              .firstOrNull;
          final action = Action.values
              .where((a) => a.name == parts.skip(1).join('.'))
              .firstOrNull;
          if (resource != null &&
              action != null &&
              !widget.permissions.can(resource, action)) {
            setState(
              () => _saveError = 'Cannot grant permissions you do not hold.',
            );
            return;
          }
        }
      }

      final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      await rolesDao.updateRole(
        widget.role.id,
        RolesCompanion(
          permissions: Value(_serialisePermissions(_editPermissions)),
          updated: Value(nowMs),
        ),
        accountId: accountId,
      );

      // ── Post-save verification ──────────────────────────────────────────
      final verifyRows = await (rolesDao.select(
        rolesDao.roles,
      )..where((t) => t.id.equals(widget.role.id))).get();
      if (verifyRows.isNotEmpty) {
        final saved = verifyRows.first;
        debugPrint(
          '[PermTab._save] VERIFY permissions in DB: ${saved.permissions.length} bytes',
        );
        debugPrint('[PermTab._save] VERIFY updated in DB: ${saved.updated}');
      } else {
        debugPrint('[PermTab._save] ⚠️ Role not found in DB after save!');
      }

      if (mounted) {
        setState(() {
          _originalPermissions = Map.of(_editPermissions);
        });
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Permissions saved.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[PermTab._save] ERROR: $e');
      if (mounted) {
        setState(() => _saveError = 'Failed to save: $e');
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _discardChanges() {
    setState(() {
      _editPermissions = Map.of(_originalPermissions);
      _saveError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isLight = cs.brightness == Brightness.light;
    final groups = kResourceGroups;

    final hasAnyPermissions = _editPermissions.values.any((v) => v == true);
    final hasChanges = _hasChanges;
    final changes = _changeSummary;
    final selectionMode = _selectedResources.isNotEmpty;

    return Column(
      children: [
        // ── Save / selection bar ──────────────────────────────────────────
        if (selectionMode)
          _SelectionBar(
            count: _selectedResources.length,
            onClear: () => setState(() => _selectedResources.clear()),
            onDelete: _removeSelectedResources,
            cs: cs,
          )
        else if (hasChanges)
          _ChangeBar(
            added: changes.added,
            removed: changes.removed,
            saving: _saving,
            onSave: _save,
            onDiscard: _discardChanges,
            cs: cs,
          ),

        if (_saveError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: cs.errorContainer.withValues(alpha: 0.5),
            child: Text(
              _saveError!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onErrorContainer,
              ),
            ),
          ),

        // ── Resource list ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              widget.horizontalPadding,
              16,
              widget.horizontalPadding,
              40,
            ),
            itemCount: groups.length + (hasAnyPermissions ? 0 : 1),
            itemBuilder: (context, index) {
              // ── Info banner when no permissions are set ──
              if (!hasAnyPermissions && index == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: cs.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No permissions configured yet. Expand a resource to start granting actions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final gi = hasAnyPermissions ? index : index - 1;
              final group = groups[gi];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: gi < groups.length - 1 ? 6 : 0,
                ),
                child: _ResourceRow(
                  resource: group.resource,
                  allActions: group.actions,
                  editPermissions: _editPermissions,
                  originalPermissions: _originalPermissions,
                  isExpanded: _expandedResources.contains(group.resource),
                  isSelected: _selectedResources.contains(group.resource),
                  selectionMode: selectionMode,
                  changeSummary: _resourceChangeSummary(group.resource),
                  canEdit: widget.permissions.can(
                    Resource.roles,
                    Action.update,
                  ),
                  isLight: isLight,
                  onToggleExpand: () => _toggleExpand(group.resource),
                  onToggleSelection: () =>
                      _toggleResourceSelection(group.resource),
                  onTogglePermission: _togglePermission,
                  onRemove: () => _removeResource(group.resource),
                  canEditPermission: (r, a) => widget.permissions.can(r, a),
                  cs: cs,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection bar
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onDelete,
    required this.cs,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(
            color: cs.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Text(
            '$count selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: cs.error),
            label: Text(
              'Remove',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change bar — git-like indicator
// ─────────────────────────────────────────────────────────────────────────────

class _ChangeBar extends StatelessWidget {
  const _ChangeBar({
    required this.added,
    required this.removed,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
    required this.cs,
  });

  final int added;
  final int removed;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (added > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+$added',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF66BB6A),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (removed > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '-$removed',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF5350),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            'Unsaved changes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: saving ? null : onDiscard,
            child: Text(
              'Discard',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSaveButton(
            isDirty: true,
            isSaving: saving,
            onSave: saving ? null : onSave,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resource row — elevated card, expandable, selectable, with action indicators
// ─────────────────────────────────────────────────────────────────────────────

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.allActions,
    required this.editPermissions,
    required this.originalPermissions,
    required this.isExpanded,
    required this.isSelected,
    required this.selectionMode,
    required this.changeSummary,
    required this.canEdit,
    required this.isLight,
    required this.onToggleExpand,
    required this.onToggleSelection,
    required this.onTogglePermission,
    required this.onRemove,
    this.canEditPermission,
    required this.cs,
  });

  final Resource resource;
  final List<Action> allActions;
  final Map<String, bool> editPermissions;
  final Map<String, bool> originalPermissions;
  final bool isExpanded;
  final bool isSelected;
  final bool selectionMode;
  final ({int added, int removed}) changeSummary;
  final bool canEdit;
  final bool isLight;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleSelection;
  final void Function(String key) onTogglePermission;
  final VoidCallback onRemove;
  final bool Function(Resource, Action)? canEditPermission;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final activeActions = allActions
        .where((a) => editPermissions['${resource.name}.${a.name}'] == true)
        .toList();
    final hasChanges = changeSummary.added > 0 || changeSummary.removed > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.25)
              : isLight
              ? Colors.white
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
                blurRadius: isExpanded ? 6 : 3,
                offset: const Offset(0, 1),
              ),
            if (!isSelected && isLight)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 1,
              ),
          ],
          border: isSelected
              ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5)
              : null,
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
                onLongPress: canEdit ? onToggleSelection : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      // Selection checkbox (when in selection mode).
                      if (selectionMode) ...[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => onToggleSelection(),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                            side: BorderSide(
                              color: cs.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

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
                          resource.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),

                      // Git-like change indicators for this resource.
                      if (hasChanges) ...[
                        if (changeSummary.added > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '+${changeSummary.added}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF66BB6A),
                              ),
                            ),
                          ),
                        if (changeSummary.removed > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '-${changeSummary.removed}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF5350),
                              ),
                            ),
                          ),
                      ],

                      // Coloured action icons (collapsed summary).
                      ...activeActions.map((action) {
                        final color =
                            kActionColors[action] ?? cs.onSurfaceVariant;
                        final icon =
                            kActionIcons[action] ?? Icons.circle_outlined;
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Tooltip(
                            message: actionLabel(action),
                            child: Icon(
                              icon,
                              size: 15,
                              color: color.withValues(alpha: 0.75),
                            ),
                          ),
                        );
                      }),

                      // Remove button.
                      if (canEdit && !selectionMode) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onRemove,
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Expanded detail ─────────────────────────────────────────
            if (isExpanded)
              _ExpandedPermissions(
                resource: resource,
                allActions: allActions,
                editPermissions: editPermissions,
                originalPermissions: originalPermissions,
                canEdit: canEdit,
                canEditPermission: canEditPermission,
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
    required this.allActions,
    required this.editPermissions,
    required this.originalPermissions,
    required this.canEdit,
    this.canEditPermission,
    required this.isLight,
    required this.onToggle,
    required this.cs,
  });

  final Resource resource;
  final List<Action> allActions;
  final Map<String, bool> editPermissions;
  final Map<String, bool> originalPermissions;
  final bool canEdit;
  final bool Function(Resource, Action)? canEditPermission;
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
          children: allActions.map((action) {
            final key = '${resource.name}.${action.name}';
            final isOn = editPermissions[key] == true;
            final wasOn = originalPermissions[key] == true;
            final changed = isOn != wasOn;
            final color = kActionColors[action] ?? cs.onSurfaceVariant;
            final icon = kActionIcons[action] ?? Icons.circle_outlined;
            // Per-action gate: canEdit gates the whole section (Roles.Update),
            // canEditPermission gates individual actions the user doesn't hold.
            final actionEditable =
                canEdit && (canEditPermission?.call(resource, action) ?? true);

            return Opacity(
              opacity: (canEdit && !actionEditable) ? 0.35 : 1.0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: actionEditable ? () => onToggle(key) : null,
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
                            actionLabel(action),
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
                        if (changed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isOn
                                  ? const Color(
                                      0xFF66BB6A,
                                    ).withValues(alpha: 0.1)
                                  : const Color(
                                      0xFFEF5350,
                                    ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              isOn ? 'added' : 'removed',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isOn
                                    ? const Color(0xFF66BB6A)
                                    : const Color(0xFFEF5350),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (actionEditable)
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
                          )
                        else if (canEdit)
                          Tooltip(
                            message: 'You do not hold this permission',
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                            ),
                          )
                        else
                          Icon(
                            isOn
                                ? Icons.check_circle_rounded
                                : Icons.cancel_outlined,
                            size: 16,
                            color: isOn
                                ? color.withValues(alpha: 0.7)
                                : cs.onSurfaceVariant.withValues(alpha: 0.2),
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

// ═════════════════════════════════════════════════════════════════════════════
// Assigned Tab
// ═════════════════════════════════════════════════════════════════════════════

class _AssignedTab extends StatefulWidget {
  const _AssignedTab({
    required this.role,
    required this.permissions,
    required this.cs,
    required this.horizontalPadding,
  });

  final Role role;
  final SystemPermissions permissions;
  final ColorScheme cs;
  final double horizontalPadding;

  @override
  State<_AssignedTab> createState() => _AssignedTabState();
}

class _AssignedTabState extends State<_AssignedTab> {
  Future<void> _unassign(String userId) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await rolesDao.unassignUserFromRole(
        userId: userId,
        roleId: widget.role.id,
        accountId: accountId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unassign user: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.cs.error,
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isLight = cs.brightness == Brightness.light;
    final canUnassign = widget.permissions.can(Resource.roles, Action.unassign);

    return StreamBuilder<List<({Scope scope, UsersData user})>>(
      stream: rolesDao.watchUsersForRole(widget.role.id),
      builder: (context, snapshot) {
        final assigned = snapshot.data ?? [];

        if (assigned.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              widget.horizontalPadding,
              20,
              widget.horizontalPadding,
              40,
            ),
            children: [_AssignedEmptyState(cs: cs)],
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            16,
            widget.horizontalPadding,
            40,
          ),
          itemCount: assigned.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final entry = assigned[index];

            return _AssignedRow(
              user: entry.user,
              cs: cs,
              isLight: isLight,
              canUnassign: canUnassign,
              onUnassign: () => _unassign(entry.user.id),
            );
          },
        );
      },
    );
  }
}

class _AssignedEmptyState extends StatelessWidget {
  const _AssignedEmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 24,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No users assigned',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the + button to assign system-level users to this role.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedRow extends StatelessWidget {
  const _AssignedRow({
    required this.user,
    required this.cs,
    required this.isLight,
    required this.canUnassign,
    required this.onUnassign,
  });

  final UsersData user;
  final ColorScheme cs;
  final bool isLight;
  final bool canUnassign;
  final Future<void> Function() onUnassign;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (user.status) {
      UserStatus.invited => ('Invited', const Color(0xFF42A5F5)),
      UserStatus.active => ('Active', const Color(0xFF26A69A)),
      UserStatus.suspended => ('Suspended', const Color(0xFFFFB300)),
      UserStatus.deleted => ('Deleted', const Color(0xFFEF5350)),
    };

    final levelLabel = switch (user.level) {
      UserLevel.super_ => 'Super',
      UserLevel.system => 'System',
      UserLevel.normal => null,
    };

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────────────
            FutureBuilder<File?>(
              future: FileCache.get(FileCache.profilePath(user.id)),
              builder: (context, snap) {
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: snap.data != null
                      ? Image.file(snap.data!, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            _initials(user.name),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                );
              },
            ),
            const SizedBox(width: 13),
            // ── Info ────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email ?? user.phone,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ── Level badge ──────────────────────────────────────────
            if (levelLabel != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  levelLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            // ── Status badge ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // ── Unassign button ──────────────────────────────────────
            if (canUnassign) ...[
              const SizedBox(width: 6),
              AnimatedActionButton(
                icon: Icons.person_remove_outlined,
                iconSize: 17,
                color: cs.error.withValues(alpha: 0.6),
                size: 32,
                tooltip: 'Unassign',
                showCheckOnSuccess: false,
                onTap: onUnassign,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Assign User Sheet — bottom sheet listing eligible system-level users
// ═════════════════════════════════════════════════════════════════════════════

class _AssignUserSheet extends StatefulWidget {
  const _AssignUserSheet({required this.roleId, required this.permissions});

  final String roleId;
  final SystemPermissions permissions;

  @override
  State<_AssignUserSheet> createState() => _AssignUserSheetState();
}

class _AssignUserSheetState extends State<_AssignUserSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  final Set<String> _assigningIds = {};

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

  List<UsersData> _filter(List<UsersData> users) {
    if (_searchQuery.isEmpty) return users;
    final q = _searchQuery.toLowerCase();
    return users
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.phone.toLowerCase().contains(q) ||
              (u.email?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  Future<void> _assign(UsersData user) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _assigningIds.add(user.id));

    try {
      await rolesDao.assignUserToRole(
        userId: user.id,
        roleId: widget.roleId,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} assigned.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Padding(
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
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    Icons.person_add_outlined,
                    size: 18,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign User',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        'System-level users not already assigned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Search field ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or email…',
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

          const SizedBox(height: 12),
          Divider(height: 0.5, thickness: 0.5, color: cs.outlineVariant),

          // ── User list ───────────────────────────────────────────────────
          Flexible(
            child: StreamBuilder<List<UsersData>>(
              stream: rolesDao.watchEligibleSystemUsers(widget.roleId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final filtered = _filter(snapshot.data!);

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 32,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.data!.isEmpty
                              ? 'No eligible users'
                              : 'No matching users',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.data!.isEmpty
                              ? 'All system-level users are already assigned to this role.'
                              : 'Try a different search term.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final isAssigning = _assigningIds.contains(user.id);

                    return _EligibleUserRow(
                      user: user,
                      cs: cs,
                      isLight: isLight,
                      isAssigning: isAssigning,
                      onAssign: () => _assign(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibleUserRow extends StatelessWidget {
  const _EligibleUserRow({
    required this.user,
    required this.cs,
    required this.isLight,
    required this.isAssigning,
    required this.onAssign,
  });

  final UsersData user;
  final ColorScheme cs;
  final bool isLight;
  final bool isAssigning;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final levelLabel = switch (user.level) {
      UserLevel.super_ => 'Super',
      UserLevel.system => 'System',
      UserLevel.normal => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAssigning ? null : onAssign,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // ── Avatar ──────────────────────────────────────────────
                FutureBuilder<File?>(
                  future: FileCache.get(FileCache.profilePath(user.id)),
                  builder: (context, snap) {
                    return Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: snap.data != null
                          ? Image.file(snap.data!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                _initials(user.name),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(width: 11),
                // ── Info ────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        user.email ?? user.phone,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Level badge ──────────────────────────────────────────
                if (levelLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      levelLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // ── Assign action ────────────────────────────────────────
                if (isAssigning)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.primary,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
