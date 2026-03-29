import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/school_scopes_dao.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Resource groupings — uses the typed Resource enum from models/permissions.dart
// ─────────────────────────────────────────────────────────────────────────────

class _ResourceGroup {
  const _ResourceGroup(this.label, this.resources);
  final String label;
  final List<Resource> resources;
}

List<_ResourceGroup> _buildResourceGroups() => const [
  _ResourceGroup('People', [
    Resource.users,
    Resource.students,
    Resource.teachers,
    Resource.staff,
    Resource.owners,
  ]),
  _ResourceGroup('Academic', [
    Resource.subjects,
    Resource.lessons,
    Resource.exams,
    Resource.grades,
    Resource.attendance,
    Resource.classes,
    Resource.departments,
  ]),
  _ResourceGroup('Finance', [Resource.fees, Resource.payments, Resource.plans]),
  _ResourceGroup('School Admin', [
    Resource.schools,
    Resource.announcements,
    Resource.ai,
  ]),
  _ResourceGroup('System', [Resource.roles]),
];

// ─────────────────────────────────────────────────────────────────────────────
// Action colour / icon mapping
// ─────────────────────────────────────────────────────────────────────────────

const _kActionColors = <Action, Color>{
  Action.read: Color(0xFF42A5F5),
  Action.create: Color(0xFF66BB6A),
  Action.update: Color(0xFFFFA726),
  Action.delete: Color(0xFFEF5350),
  Action.purge: Color(0xFFB71C1C),
  Action.assign: Color(0xFF26C6DA),
  Action.unassign: Color(0xFF78909C),
  Action.mark: Color(0xFF7E57C2),
  Action.approve: Color(0xFF26A69A),
};

const _kActionIcons = <Action, IconData>{
  Action.create: Icons.add_rounded,
  Action.read: Icons.visibility_outlined,
  Action.update: Icons.edit_outlined,
  Action.delete: Icons.delete_outline_rounded,
  Action.purge: Icons.delete_forever_outlined,
  Action.assign: Icons.link_rounded,
  Action.unassign: Icons.link_off_rounded,
  Action.mark: Icons.check_box_outline_blank_rounded,
  Action.approve: Icons.thumb_up_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Permission helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Parses the JSON string stored in `roles.permissions` into a mutable
/// `Map<Resource, int>` bitmask map.  Handles null, empty string, empty
/// JSON array `"[]"`, and both legacy JSON shapes via [Permissions.fromJson].
/// Never throws — always returns an empty map on bad input.
Map<Resource, int> _parsePermissions(String? jsonStr) {
  if (jsonStr == null ||
      jsonStr.isEmpty ||
      jsonStr == '[]' ||
      jsonStr == '{}') {
    return {};
  }
  try {
    final decoded = jsonDecode(jsonStr);
    final perms = Permissions.fromJson(decoded);
    return Map<Resource, int>.from(perms.map);
  } catch (_) {
    return {};
  }
}

/// Serialises a `Map<Resource, int>` bitmask map back to the JSON string
/// format stored in `roles.permissions`.
///
/// Output shape: `[{"resource": "users", "actions": ["read", "create"]}, …]`
String _serialisePermissions(Map<Resource, int> perms) {
  final list = <Map<String, dynamic>>[];
  for (final entry in perms.entries) {
    if (entry.value == 0) continue;
    final actions = Action.values
        .where((a) => entry.value & a.mask != 0)
        .map((a) => a.name)
        .toList();
    if (actions.isNotEmpty) {
      list.add({'resource': entry.key.name, 'actions': actions});
    }
  }
  return jsonEncode(list);
}

/// Returns the total count of granted permissions across all resources.
int _countPermissions(Map<Resource, int> perms) {
  var count = 0;
  for (final mask in perms.values) {
    count += _popcount(mask);
  }
  return count;
}

/// Count set bits in a 16-bit integer (Hamming weight / popcount).
int _popcount(int v) {
  var n = v & 0xFFFF;
  n = n - ((n >> 1) & 0x5555);
  n = (n & 0x3333) + ((n >> 2) & 0x3333);
  return (((n + (n >> 4)) & 0x0F0F) * 0x0101) & 0xFF;
}

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
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete role?',
      message:
          'Are you sure you want to delete "${role.name}"? '
          'All users assigned to this role will lose its permissions. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

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
    showEduSheet(
      context: context,
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
    final totalPerms = _countPermissions(perms);
    final totalResources = perms.entries.where((e) => e.value != 0).length;

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
  late Map<Resource, int> _editPermissions;

  /// Snapshot of permissions from the role at the start of editing.
  late Map<Resource, int> _originalPermissions;

  /// Resources selected for bulk removal.
  final Set<Resource> _selectedResources = {};

  /// Resources that are expanded to show action details.
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
    final allResources = <Resource>{
      ..._originalPermissions.keys,
      ..._editPermissions.keys,
      ...Resource.values,
    };
    for (final r in allResources) {
      final orig = _originalPermissions[r] ?? 0;
      final curr = _editPermissions[r] ?? 0;
      if (orig != curr) return true;
    }
    return false;
  }

  ({int added, int removed}) get _changeSummary {
    int added = 0;
    int removed = 0;
    for (final r in Resource.values) {
      final orig = _originalPermissions[r] ?? 0;
      final curr = _editPermissions[r] ?? 0;
      final addedBits = curr & ~orig;
      final removedBits = orig & ~curr;
      added += _popcount(addedBits);
      removed += _popcount(removedBits);
    }
    return (added: added, removed: removed);
  }

  ({int added, int removed}) _resourceChangeSummary(Resource resource) {
    final orig = _originalPermissions[resource] ?? 0;
    final curr = _editPermissions[resource] ?? 0;
    final addedBits = curr & ~orig;
    final removedBits = orig & ~curr;
    return (added: _popcount(addedBits), removed: _popcount(removedBits));
  }

  void _togglePermission(Resource resource, Action action) {
    setState(() {
      final current = (_editPermissions[resource] ?? 0) & action.mask != 0;
      if (current) {
        _editPermissions[resource] =
            ((_editPermissions[resource] ?? 0) & ~action.mask) & 0xFFFF;
        if (_editPermissions[resource] == 0) _editPermissions.remove(resource);
      } else {
        _editPermissions[resource] =
            ((_editPermissions[resource] ?? 0) | action.mask) & 0xFFFF;
      }
    });
  }

  void _clearResource(Resource resource) {
    setState(() {
      _editPermissions.remove(resource);
      _expandedResources.remove(resource);
      _selectedResources.remove(resource);
    });
  }

  void _removeSelectedResources() {
    setState(() {
      for (final resource in _selectedResources) {
        _editPermissions.remove(resource);
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

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Filter out zero-mask entries before serialising
      final cleaned = Map.fromEntries(
        _editPermissions.entries.where((e) => e.value != 0),
      );

      await widget.dao.updateRole(
        widget.role.id,
        RolesCompanion(
          permissions: Value(_serialisePermissions(cleaned)),
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

    final hasAnyPermissions = _editPermissions.values.any((m) => m != 0);
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

        // ── Resource list — always shows all resources ────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              widget.horizontalPadding,
              16,
              widget.horizontalPadding,
              40,
            ),
            itemCount: groups.length + 1, // +1 for the optional info banner
            itemBuilder: (context, i) {
              // First item: informational banner when no permissions set
              if (i == 0) {
                if (hasAnyPermissions) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No permissions configured. '
                            'Expand a resource to add permissions.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final gi = i - 1;
              final group = groups[gi];

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
                          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...group.resources.map((resource) {
                      return _ResourceRow(
                        resource: resource,
                        editPermissions: _editPermissions,
                        originalPermissions: _originalPermissions,
                        isExpanded: _expandedResources.contains(resource),
                        isSelected: _selectedResources.contains(resource),
                        selectionMode: selectionMode,
                        changeSummary: _resourceChangeSummary(resource),
                        isLight: isLight,
                        onToggleExpand: () => _toggleExpand(resource),
                        onToggleSelection: () =>
                            _toggleResourceSelection(resource),
                        onTogglePermission: _togglePermission,
                        onClear: () => _clearResource(resource),
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
// Resource row — elevated card, expandable, selectable
// ─────────────────────────────────────────────────────────────────────────────

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
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
    required this.onClear,
    required this.cs,
  });

  final Resource resource;
  final Map<Resource, int> editPermissions;
  final Map<Resource, int> originalPermissions;
  final bool isExpanded;
  final bool isSelected;
  final bool selectionMode;
  final ({int added, int removed}) changeSummary;
  final bool isLight;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleSelection;
  final void Function(Resource resource, Action action) onTogglePermission;
  final VoidCallback onClear;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final applicableActions = resource.applicableActions;
    final currentMask = editPermissions[resource] ?? 0;
    final activeActions = applicableActions
        .where((a) => currentMask & a.mask != 0)
        .toList();
    final activeCount = activeActions.length;
    final totalCount = applicableActions.length;
    final hasAnyActive = activeCount > 0;
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
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      // ── Resource name + icon dots ─────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              resource.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                letterSpacing: 0.1,
                              ),
                            ),
                            // Compact icon dots when some permissions active
                            if (hasAnyActive && !isExpanded) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: activeActions.map((action) {
                                  final color =
                                      _kActionColors[action] ??
                                      cs.onSurfaceVariant;
                                  final icon =
                                      _kActionIcons[action] ??
                                      Icons.circle_outlined;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Tooltip(
                                      message: action.label,
                                      child: Icon(
                                        icon,
                                        size: 13,
                                        color: color.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // ── Change indicators ─────────────────────────────
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
                            padding: const EdgeInsets.only(right: 6),
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
                      // ── Count badge: "3 / 5" ──────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasAnyActive
                              ? cs.primary.withValues(alpha: 0.08)
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$activeCount\u202F/\u202F$totalCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: hasAnyActive
                                ? cs.primary.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant.withValues(alpha: 0.4),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      // ── Clear / selection-mode buttons ─────────────────
                      if (!selectionMode) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: hasAnyActive ? onClear : null,
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: hasAnyActive
                                ? cs.onSurfaceVariant.withValues(alpha: 0.45)
                                : cs.onSurfaceVariant.withValues(alpha: 0.15),
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
    required this.editPermissions,
    required this.originalPermissions,
    required this.isLight,
    required this.onToggle,
    required this.cs,
  });

  final Resource resource;
  final Map<Resource, int> editPermissions;
  final Map<Resource, int> originalPermissions;
  final bool isLight;
  final void Function(Resource resource, Action action) onToggle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final applicableActions = resource.applicableActions;
    final currentMask = editPermissions[resource] ?? 0;
    final originalMask = originalPermissions[resource] ?? 0;

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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: applicableActions.map((action) {
            final isOn = currentMask & action.mask != 0;
            final wasOn = originalMask & action.mask != 0;
            final changed = isOn != wasOn;
            final color = _kActionColors[action] ?? cs.onSurfaceVariant;
            final icon = _kActionIcons[action] ?? Icons.circle_outlined;

            return Tooltip(
              message: action.label,
              child: GestureDetector(
                onTap: () => onToggle(resource, action),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isOn
                            ? color.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOn
                              ? color.withValues(alpha: 0.35)
                              : cs.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isOn
                                ? color
                                : cs.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                          // Changed indicator dot (top-right corner)
                          if (changed)
                            Positioned(
                              top: 3,
                              right: 3,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isOn
                                      ? const Color(0xFF66BB6A)
                                      : const Color(0xFFEF5350),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: isOn
                            ? cs.onSurface.withValues(alpha: 0.75)
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
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
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
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
