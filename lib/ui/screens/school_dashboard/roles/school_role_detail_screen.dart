import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/school_scopes_dao.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Resource groupings — identical to the system dashboard's role_detail_screen
// ─────────────────────────────────────────────────────────────────────────────

const _kBaseActions = ['read', 'create', 'update', 'delete'];

List<_ResourceGroup> _buildResourceGroups() {
  List<String> a([List<String> actions = _kBaseActions]) => actions;

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
// Action colour / icon mapping
// ─────────────────────────────────────────────────────────────────────────────

const _kActionColors = <String, Color>{
  'read': Color(0xFF42A5F5),
  'create': Color(0xFF66BB6A),
  'update': Color(0xFFFFA726),
  'delete': Color(0xFFEF5350),
};

const _kActionIcons = <String, IconData>{
  'read': Icons.visibility_outlined,
  'create': Icons.add_circle_outline,
  'update': Icons.edit_outlined,
  'delete': Icons.delete_outline_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
// Permission helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, bool> _parsePermissions(String json) {
  try {
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
    // Fallback: flat map of { "resource.action": true } (legacy / raw JSON)
    if (decoded is Map) {
      return decoded.map(
        (k, v) => MapEntry(k.toString(), v == true || v == 'true'),
      );
    }
  } catch (_) {}
  return {};
}

String _serialisePermissions(Map<String, bool> perms) {
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

String _capitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ═════════════════════════════════════════════════════════════════════════════
// SchoolRoleDetailScreen
// ═════════════════════════════════════════════════════════════════════════════

/// Full-page role detail screen for a school-scoped role, pushed from the
/// school dashboard's Roles page when the user taps a role card.
///
/// Contains:
/// - Header: role icon + name + description + metadata chips
/// - Tabs: Permissions | Assigned Users
class SchoolRoleDetailScreen extends StatefulWidget {
  const SchoolRoleDetailScreen({
    super.key,
    required this.role,
    required this.schoolContext,
    required this.dao,
  });

  /// The role to display — serves as the initial snapshot; the screen watches
  /// for live updates via the DAO stream.
  final Role role;

  /// The current school context — provides schoolId and permissions.
  final SchoolContext schoolContext;

  /// The school-scoped DAO instance for roles and scopes.
  final SchoolScopesDao dao;

  @override
  State<SchoolRoleDetailScreen> createState() => _SchoolRoleDetailScreenState();
}

class _SchoolRoleDetailScreenState extends State<SchoolRoleDetailScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final TabController _tabController;

  String get _schoolId => widget.schoolContext.membership.school.id;

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

  // ── Delete confirmation ──────────────────────────────────────────────────

  void _confirmDelete(Role role) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
          ),
          title: Text(
            'Delete role?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${role.name}"? '
            'All users assigned to this role will lose its permissions. '
            'This cannot be undone.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: cs.error,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await widget.dao.deleteRole(role.id, accountId: accountId);
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

  // ── Assign user sheet ────────────────────────────────────────────────────

  void _openAssignSheet(Role role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignUserSheet(
        schoolId: _schoolId,
        roleId: role.id,
        dao: widget.dao,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
          stream: widget.dao.watchSchoolRoles(_schoolId),
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: cs.error.withValues(alpha: 0.7),
              ),
              onPressed: () => _confirmDelete(widget.role),
              tooltip: 'Delete role',
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: StreamBuilder<List<Role>>(
            stream: widget.dao.watchSchoolRoles(_schoolId),
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
                            onAssign: () => _openAssignSheet(role),
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _PermissionsTab(
                          role: role,
                          dao: widget.dao,
                          cs: cs,
                          horizontalPadding: horizontalPadding,
                        ),
                        _AssignedTab(
                          role: role,
                          schoolId: _schoolId,
                          dao: widget.dao,
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
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                label: '$totalPerms permission${totalPerms == 1 ? '' : 's'}',
                cs: cs,
              ),
              _DetailChip(
                icon: Icons.category_outlined,
                label:
                    '$totalResources resource${totalResources == 1 ? '' : 's'}',
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
    required this.onAssign,
  });

  final TabController tabController;
  final ColorScheme cs;
  final bool isLight;
  final double horizontalPadding;
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
        boxShadow: hasScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isLight ? 0.03 : 0.08,
                      ),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
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

          // + assign button — only visible on the Assigned tab.
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: tabController,
            builder: (context, child) {
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
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),
          ),
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
    required this.role,
    required this.dao,
    required this.cs,
    required this.horizontalPadding,
  });

  final Role role;
  final SchoolScopesDao dao;
  final ColorScheme cs;
  final double horizontalPadding;

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  /// Working copy of permissions — mutated during editing.
  late Map<String, bool> _editPermissions;

  /// Snapshot of permissions from the role at the start of editing.
  late Map<String, bool> _originalPermissions;

  /// Resources selected for bulk removal.
  final Set<String> _selectedResources = {};

  /// Resources that are expanded to show action details.
  final Set<String> _expandedResources = {};

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

  ({int added, int removed}) _resourceChangeSummary(String resource) {
    int added = 0;
    int removed = 0;
    final allKeys = <String>{
      ..._originalPermissions.keys,
      ..._editPermissions.keys,
    };
    for (final k in allKeys) {
      if (!k.startsWith('$resource.')) continue;
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

  void _removeResource(String resource) {
    setState(() {
      final keysToRemove = _editPermissions.keys
          .where((k) => k.startsWith('$resource.'))
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
            .where((k) => k.startsWith('$resource.'))
            .toList();
        for (final k in keysToRemove) {
          _editPermissions[k] = false;
        }
        _expandedResources.remove(resource);
      }
      _selectedResources.clear();
    });
  }

  void _toggleResourceSelection(String resource) {
    setState(() {
      if (_selectedResources.contains(resource)) {
        _selectedResources.remove(resource);
      } else {
        _selectedResources.add(resource);
      }
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

  Future<void> _save() async {
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

      await widget.dao.updateRole(
        widget.role.id,
        RolesCompanion(
          permissions: Value(_serialisePermissions(_editPermissions)),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      if (mounted) {
        setState(() {
          _originalPermissions = Map.of(_editPermissions);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions saved.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Failed to save: $e');
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
    final groups = _buildResourceGroups();

    final activeGrouped = _groupByResource(_editPermissions);
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
          child: activeGrouped.isEmpty
              ? _PermissionsEmptyState(cs: cs)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    widget.horizontalPadding,
                    16,
                    widget.horizontalPadding,
                    40,
                  ),
                  itemCount: groups.length,
                  itemBuilder: (context, gi) {
                    final group = groups[gi];
                    final activeResources = group.resources.entries
                        .where(
                          (e) => e.value.any(
                            (a) => _editPermissions['${e.key}.$a'] == true,
                          ),
                        )
                        .toList();

                    if (activeResources.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: gi < groups.length - 1 ? 20 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          ...activeResources.map((entry) {
                            return _ResourceRow(
                              resource: entry.key,
                              allActions: entry.value,
                              editPermissions: _editPermissions,
                              originalPermissions: _originalPermissions,
                              isExpanded: _expandedResources.contains(
                                entry.key,
                              ),
                              isSelected: _selectedResources.contains(
                                entry.key,
                              ),
                              selectionMode: selectionMode,
                              changeSummary: _resourceChangeSummary(entry.key),
                              isLight: isLight,
                              onToggleExpand: () => _toggleExpand(entry.key),
                              onToggleSelection: () =>
                                  _toggleResourceSelection(entry.key),
                              onTogglePermission: _togglePermission,
                              onRemove: () => _removeResource(entry.key),
                              cs: cs,
                            );
                          }),
                        ],
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
      decoration: BoxDecoration(color: cs.surfaceContainer),
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
// Resource row — elevated card, expandable, selectable
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
    required this.isLight,
    required this.onToggleExpand,
    required this.onToggleSelection,
    required this.onTogglePermission,
    required this.onRemove,
    required this.cs,
  });

  final String resource;
  final List<String> allActions;
  final Map<String, bool> editPermissions;
  final Map<String, bool> originalPermissions;
  final bool isExpanded;
  final bool isSelected;
  final bool selectionMode;
  final ({int added, int removed}) changeSummary;
  final bool isLight;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleSelection;
  final void Function(String key) onTogglePermission;
  final VoidCallback onRemove;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final activeActions = allActions
        .where((a) => editPermissions['$resource.$a'] == true)
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
                onLongPress: onToggleSelection,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
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
                          _capitalise(resource),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
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
                      if (!selectionMode) ...[
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
            if (isExpanded)
              _ExpandedPermissions(
                resource: resource,
                allActions: allActions,
                editPermissions: editPermissions,
                originalPermissions: originalPermissions,
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
    required this.isLight,
    required this.onToggle,
    required this.cs,
  });

  final String resource;
  final List<String> allActions;
  final Map<String, bool> editPermissions;
  final Map<String, bool> originalPermissions;
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
            final key = '$resource.$action';
            final isOn = editPermissions[key] == true;
            final wasOn = originalPermissions[key] == true;
            final changed = isOn != wasOn;
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
                      if (changed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isOn
                                ? const Color(0xFF66BB6A).withValues(alpha: 0.1)
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
// Empty state — no permissions
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionsEmptyState extends StatelessWidget {
  const _PermissionsEmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                Icons.shield_outlined,
                size: 24,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No permissions assigned',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This role has no permissions. Edit the role to add '
              'resource permissions.',
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
    required this.schoolId,
    required this.dao,
    required this.cs,
    required this.horizontalPadding,
  });

  final Role role;
  final String schoolId;
  final SchoolScopesDao dao;
  final ColorScheme cs;
  final double horizontalPadding;

  @override
  State<_AssignedTab> createState() => _AssignedTabState();
}

class _AssignedTabState extends State<_AssignedTab> {
  final Set<String> _unassigningIds = {};

  Future<void> _unassign(UsersData user) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _unassigningIds.add(user.id));

    try {
      await widget.dao.unassignRole(
        schoolId: widget.schoolId,
        userId: user.id,
        roleId: widget.role.id,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} unassigned.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
    } finally {
      if (mounted) setState(() => _unassigningIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isLight = cs.brightness == Brightness.light;

    return StreamBuilder<List<({Scope scope, UsersData user})>>(
      stream: widget.dao.watchUsersForRole(widget.schoolId, widget.role.id),
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
            final isUnassigning = _unassigningIds.contains(entry.user.id);

            return _AssignedRow(
              user: entry.user,
              cs: cs,
              isLight: isLight,
              isUnassigning: isUnassigning,
              onUnassign: () => _unassign(entry.user),
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
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            'Use the + button to assign school members to this role.',
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
    required this.isUnassigning,
    required this.onUnassign,
  });

  final UsersData user;
  final ColorScheme cs;
  final bool isLight;
  final bool isUnassigning;
  final VoidCallback onUnassign;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(width: 6),
            // ── Unassign button ──────────────────────────────────────
            isUnassigning
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.error.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: onUnassign,
                    icon: Icon(
                      Icons.person_remove_outlined,
                      size: 17,
                      color: cs.error.withValues(alpha: 0.6),
                    ),
                    tooltip: 'Unassign',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Assign User Sheet — bottom sheet listing eligible school members
// ═════════════════════════════════════════════════════════════════════════════

class _AssignUserSheet extends StatefulWidget {
  const _AssignUserSheet({
    required this.schoolId,
    required this.roleId,
    required this.dao,
  });

  final String schoolId;
  final String roleId;
  final SchoolScopesDao dao;

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
      await widget.dao.assignRole(
        schoolId: widget.schoolId,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                        'School members not already assigned',
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
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide.none,
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
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),

          // ── User list ───────────────────────────────────────────────────
          Flexible(
            child: StreamBuilder<List<UsersData>>(
              stream: widget.dao.watchEligibleSchoolUsers(
                widget.schoolId,
                widget.roleId,
              ),
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
                              ? 'No eligible members'
                              : 'No matching members',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.data!.isEmpty
                              ? 'All school members are already assigned to this role.'
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
