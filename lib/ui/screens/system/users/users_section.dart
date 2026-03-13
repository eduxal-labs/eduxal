import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';
import 'user_detail_sheet.dart';

/// The Users data section of the system dashboard.
///
/// Shows a reactive list of all users from [UsersDao.watchAllUsers], with
/// client-side search (name / phone) and status / level filters.
///
/// On **mobile** this is the body of the Users tab.
/// On **desktop** this is the content inside the Users tab of the data area.
/// [onCreateTap] is provided on desktop only — on mobile the FAB handles it.
class UsersSection extends StatefulWidget {
  const UsersSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  // ── Filter state ───────────────────────────────────────────────────────────

  final _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<UserStatus> _statusFilter = {};
  final Set<UserLevel> _levelFilter = {};

  bool _filterExpanded = false;
  final Set<String> _selectedIds = {};

  // Snapshot of all users — kept in sync with the stream so bulk actions
  // can look up user objects by id without an extra async read.
  List<UsersData> _allUsers = [];

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

  // ── Filtering logic ────────────────────────────────────────────────────────

  List<UsersData> _applyFilters(List<UsersData> all) {
    var list = all;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        return u.name.toLowerCase().contains(q) ||
            u.phone.toLowerCase().contains(q);
      }).toList();
    }

    if (_statusFilter.isNotEmpty) {
      list = list.where((u) => _statusFilter.contains(u.status)).toList();
    }

    if (_levelFilter.isNotEmpty) {
      list = list.where((u) => _levelFilter.contains(u.level)).toList();
    }

    return list;
  }

  bool get _hasActiveFilters =>
      _statusFilter.isNotEmpty || _levelFilter.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _statusFilter.clear();
      _levelFilter.clear();
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  // ── Individual ─────────────────────────────────────────────────────────────

  Future<void> _suspendUser(UsersData user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Suspend user'),
        content: Text(
          'Suspend ${user.name}? They will lose access until restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.updateUserStatus(
        user.id,
        UserStatus.suspended,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${user.name} suspended')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to suspend user: $e')));
      }
    }
  }

  Future<void> _restoreUser(UsersData user) async {
    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.updateUserStatus(
        user.id,
        UserStatus.active,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} restored to active')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to restore user: $e')));
      }
    }
  }

  Future<void> _promoteUser(UsersData user) async {
    final targetLevel = user.level == UserLevel.normal
        ? UserLevel.system
        : UserLevel.super_;
    final label = targetLevel == UserLevel.system ? 'System' : 'Super';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Promote to $label'),
        content: Text('Promote ${user.name} to $label level?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(user.id, targetLevel, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} promoted to $label')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to promote user: $e')));
      }
    }
  }

  Future<void> _demoteUser(UsersData user) async {
    final targetLevel = user.level == UserLevel.super_
        ? UserLevel.system
        : UserLevel.normal;
    final label = targetLevel == UserLevel.system ? 'System' : 'Normal';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Demote to $label'),
        content: Text('Demote ${user.name} to $label level?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Demote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(user.id, targetLevel, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} demoted to $label')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to demote user: $e')));
      }
    }
  }

  Future<void> _trashUser(UsersData user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trash User'),
        content: Text(
          'Set ${user.name} to Deleted status? '
          'This is a soft delete — the record can be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.updateUserStatus(
        user.id,
        UserStatus.deleted,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${user.name} moved to trash')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to trash user: $e')));
      }
    }
  }

  Future<void> _purgeUser(UsersData user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purge User'),
        content: Text(
          'Permanently delete ${user.name}?\n\n'
          'This action is irreversible and will permanently remove this record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Purge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.purgeUser(user.id, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} permanently deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to purge user: $e')));
      }
    }
  }

  // ── Bulk actions ────────────────────────────────────────────────────────────

  /// Resolves the [UsersData] objects for the currently selected IDs,
  /// using the cached snapshot so no async DB read is needed.
  List<UsersData> get _selectedUsers =>
      _allUsers.where((u) => _selectedIds.contains(u.id)).toList();

  Future<void> _bulkSuspend() async {
    final selected = _selectedUsers;
    final eligible = selected
        .where((u) => u.status != UserStatus.suspended)
        .toList();
    if (eligible.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Suspend users'),
        content: Text('Suspend ${eligible.length} user(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.bulkUpdateStatus(
        eligible.map((u) => u.id).toList(),
        UserStatus.suspended,
        accountId: accountId,
      );
      if (mounted) {
        setState(() => _selectedIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${eligible.length} user(s) suspended')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to suspend users: $e')));
      }
    }
  }

  Future<void> _bulkTrash() async {
    final selected = _selectedUsers;
    final eligible = selected
        .where((u) => u.status != UserStatus.deleted)
        .toList();
    if (eligible.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Trash users'),
        content: Text(
          'Move ${eligible.length} user(s) to trash? '
          'This is a soft delete — records can be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.bulkUpdateStatus(
        eligible.map((u) => u.id).toList(),
        UserStatus.deleted,
        accountId: accountId,
      );
      if (mounted) {
        setState(() => _selectedIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${eligible.length} user(s) moved to trash')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to trash users: $e')));
      }
    }
  }

  Future<void> _bulkPromote() async {
    final selected = _selectedUsers;
    if (selected.isEmpty) return;
    final level = selected.first.level;
    if (!selected.every((u) => u.level == level)) return;

    final targetLevel = level == UserLevel.normal
        ? UserLevel.system
        : UserLevel.super_;
    final label = targetLevel == UserLevel.system ? 'System' : 'Super';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Promote to $label'),
        content: Text('Promote ${selected.length} user(s) to $label level?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.bulkUpdateLevel(
        selected.map((u) => u.id).toList(),
        targetLevel,
        accountId: accountId,
      );
      if (mounted) {
        setState(() => _selectedIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} user(s) promoted to $label'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to promote users: $e')));
      }
    }
  }

  Future<void> _bulkDemote() async {
    final selected = _selectedUsers;
    if (selected.isEmpty) return;
    final level = selected.first.level;
    if (!selected.every((u) => u.level == level)) return;

    final targetLevel = level == UserLevel.super_
        ? UserLevel.system
        : UserLevel.normal;
    final label = targetLevel == UserLevel.system ? 'System' : 'Normal';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Demote to $label'),
        content: Text('Demote ${selected.length} user(s) to $label level?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Demote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.bulkUpdateLevel(
        selected.map((u) => u.id).toList(),
        targetLevel,
        accountId: accountId,
      );
      if (mounted) {
        setState(() => _selectedIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} user(s) demoted to $label'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to demote users: $e')));
      }
    }
  }

  Future<void> _bulkPurge() async {
    final selected = _selectedUsers;
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PurgeDialog(users: selected),
    );
    if (confirmed != true || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.bulkPurge(
        selected.map((u) => u.id).toList(),
        accountId: accountId,
      );
      if (mounted) {
        setState(() => _selectedIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} user(s) permanently deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to purge users: $e')));
      }
    }
  }

  void _openDetail(UsersData user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          UserDetailSheet(user: user, permissions: widget.permissions),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<UsersData>>(
      stream: usersDao.watchAllUsers(),
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? [];
        // Keep the cached snapshot in sync for bulk action lookups.
        _allUsers = allUsers;
        final filtered = _applyFilters(allUsers);

        // ── Compute bulk-action visibility ─────────────────────────────────
        final selected = _selectedUsers;
        final isSuper = widget.permissions.level == UserLevel.super_;

        final showSuspend = selected.any(
          (u) => u.status != UserStatus.suspended,
        );
        final showTrash = selected.any((u) => u.status != UserStatus.deleted);

        // Promote/Demote only when ALL selected users share the same level.
        final allSameLevel =
            selected.isNotEmpty &&
            selected.every((u) => u.level == selected.first.level);
        final commonLevel = allSameLevel ? selected.first.level : null;
        final showPromote =
            allSameLevel &&
            commonLevel != UserLevel.super_ &&
            // Promoting to super_ requires super_ permissions.
            (commonLevel != UserLevel.system || isSuper);
        final showDemote =
            allSameLevel &&
            commonLevel != UserLevel.normal &&
            // Demoting from super_ requires super_ permissions.
            (commonLevel != UserLevel.super_ || isSuper);

        return Column(
          children: [
            // ── Toolbar ────────────────────────────────────────────────────
            if (_selectedIds.isNotEmpty)
              _BulkActionBar(
                cs: cs,
                count: _selectedIds.length,
                filteredCount: filtered.length,
                allSelected:
                    filtered.isNotEmpty &&
                    filtered.every((u) => _selectedIds.contains(u.id)),
                onSelectAll: () {
                  setState(() {
                    final filteredIds = filtered.map((u) => u.id).toSet();
                    final allCurrentlySelected = filteredIds.every(
                      (id) => _selectedIds.contains(id),
                    );
                    if (allCurrentlySelected) {
                      _selectedIds.removeAll(filteredIds);
                    } else {
                      _selectedIds.addAll(filteredIds);
                    }
                  });
                },
                onClear: () => setState(() => _selectedIds.clear()),
                showSuspend: showSuspend,
                showTrash: showTrash,
                showPromote: showPromote,
                showDemote: showDemote,
                showPurge: isSuper,
                onSuspend: _bulkSuspend,
                onTrash: _bulkTrash,
                onPromote: _bulkPromote,
                onDemote: _bulkDemote,
                onPurge: _bulkPurge,
              )
            else
              _Toolbar(
                searchController: _searchController,
                filterExpanded: _filterExpanded,
                hasActiveFilters: _hasActiveFilters,
                hasUsers: filtered.isNotEmpty,
                onToggleFilter: () =>
                    setState(() => _filterExpanded = !_filterExpanded),
                onSelectAll: () {
                  setState(() {
                    _selectedIds.addAll(filtered.map((u) => u.id));
                  });
                },
                cs: cs,
              ),

            // ── Filter panel ──────────────────────────────────────────────
            if (_filterExpanded && _selectedIds.isEmpty)
              _FilterPanel(
                statusFilter: _statusFilter,
                levelFilter: _levelFilter,
                showDeleted: widget.permissions.canSeeDeleted,
                hasActiveFilters: _hasActiveFilters,
                onStatusToggle: (s) => setState(
                  () => _statusFilter.contains(s)
                      ? _statusFilter.remove(s)
                      : _statusFilter.add(s),
                ),
                onLevelToggle: (l) => setState(
                  () => _levelFilter.contains(l)
                      ? _levelFilter.remove(l)
                      : _levelFilter.add(l),
                ),
                onClear: _clearFilters,
                cs: cs,
              ),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : filtered.isEmpty
                  ? _EmptyState(
                      hasQuery: _searchQuery.isNotEmpty || _hasActiveFilters,
                      cs: cs,
                    )
                  : _UserList(
                      users: filtered,
                      permissions: widget.permissions,
                      selectedIds: _selectedIds,
                      currentUserId: cache.currentUser?.user.id,
                      onTap: (u) {
                        if (_selectedIds.isNotEmpty) {
                          setState(() {
                            if (_selectedIds.contains(u.id)) {
                              _selectedIds.remove(u.id);
                            } else {
                              _selectedIds.add(u.id);
                            }
                          });
                        } else {
                          _openDetail(u);
                        }
                      },
                      onLongPress: (u) {
                        setState(() {
                          _selectedIds.add(u.id);
                        });
                      },
                      onToggleSelection: (u) {
                        setState(() {
                          if (_selectedIds.contains(u.id)) {
                            _selectedIds.remove(u.id);
                          } else {
                            _selectedIds.add(u.id);
                          }
                        });
                      },
                      onTrash: (u) => _trashUser(u),
                      onPurge: (u) => _purgeUser(u),
                      onSuspend: (u) => _suspendUser(u),
                      onRestore: (u) => _restoreUser(u),
                      onPromote: (u) => _promoteUser(u),
                      onDemote: (u) => _demoteUser(u),
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

// ─────────────────────────────────────────────────────────────────────────────
// Bulk action bar
// ─────────────────────────────────────────────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.cs,
    required this.count,
    required this.filteredCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onClear,
    required this.showSuspend,
    required this.showTrash,
    required this.showPromote,
    required this.showDemote,
    required this.showPurge,
    required this.onSuspend,
    required this.onTrash,
    required this.onPromote,
    required this.onDemote,
    required this.onPurge,
  });

  final ColorScheme cs;
  final int count;
  final int filteredCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final bool showSuspend;
  final bool showTrash;
  final bool showPromote;
  final bool showDemote;
  final bool showPurge;
  final VoidCallback onSuspend;
  final VoidCallback onTrash;
  final VoidCallback onPromote;
  final VoidCallback onDemote;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: cs.primaryContainer.withValues(alpha: isDark ? 0.2 : 0.3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onClear,
            color: cs.onSurfaceVariant,
            tooltip: 'Clear selection',
          ),
          Checkbox(
            value: allSelected ? true : null,
            tristate: true,
            onChanged: (_) => onSelectAll(),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count selected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          if (showSuspend)
            IconButton(
              icon: const Icon(Icons.block_outlined, size: 20),
              onPressed: onSuspend,
              color: const Color(0xFFFFB300),
              tooltip: 'Suspend',
            ),
          if (showPromote)
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              onPressed: onPromote,
              color: cs.primary,
              tooltip: 'Promote',
            ),
          if (showDemote)
            IconButton(
              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              onPressed: onDemote,
              color: cs.onSurfaceVariant,
              tooltip: 'Demote',
            ),
          if (showTrash)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: onTrash,
              color: cs.error,
              tooltip: 'Trash',
            ),
          if (showPurge)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              onPressed: onPurge,
              color: cs.error,
              tooltip: 'Purge permanently',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Purge confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────

class _PurgeDialog extends StatefulWidget {
  const _PurgeDialog({required this.users});

  final List<UsersData> users;

  @override
  State<_PurgeDialog> createState() => _PurgeDialogState();
}

class _PurgeDialogState extends State<_PurgeDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.users.length;
    // Show up to 5 names; append "and N more…" if there are more.
    final names = widget.users.take(5).map((u) => u.name).toList();
    final remainder = count - names.length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: cs.surface,
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Permanently delete $count user(s)?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action CANNOT be undone. The following records will be '
              'permanently removed from the database with no possibility of '
              'recovery:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            ...names.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (remainder > 0) ...[
              const SizedBox(height: 2),
              Text(
                'and $remainder more…',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Type "DELETE" to confirm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onErrorContainer,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: cs.error),
                ),
              ),
              onChanged: (v) {
                setState(() => _confirmed = v == 'DELETE');
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error),
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text(
            'Purge permanently',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar (search + filter toggle)
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.filterExpanded,
    required this.hasActiveFilters,
    required this.hasUsers,
    required this.onToggleFilter,
    required this.onSelectAll,
    required this.cs,
  });

  final TextEditingController searchController;
  final bool filterExpanded;
  final bool hasActiveFilters;
  final bool hasUsers;
  final VoidCallback onToggleFilter;
  final VoidCallback onSelectAll;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Search field.
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
                  hintText: 'Search by name or phone…',
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

          const SizedBox(width: 8),

          // Select all toggle.
          if (hasUsers) ...[
            _ToolbarIcon(
              icon: Icons.checklist_rounded,
              active: false,
              onTap: onSelectAll,
              cs: cs,
            ),
            const SizedBox(width: 4),
          ],

          // Filter toggle.
          _ToolbarIcon(
            icon: hasActiveFilters
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            active: filterExpanded || hasActiveFilters,
            onTap: onToggleFilter,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.10)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(
              color: active
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.statusFilter,
    required this.levelFilter,
    required this.showDeleted,
    required this.hasActiveFilters,
    required this.onStatusToggle,
    required this.onLevelToggle,
    required this.onClear,
    required this.cs,
  });

  final Set<UserStatus> statusFilter;
  final Set<UserLevel> levelFilter;
  final bool showDeleted;
  final bool hasActiveFilters;
  final void Function(UserStatus) onStatusToggle;
  final void Function(UserLevel) onLevelToggle;
  final VoidCallback onClear;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      (UserStatus.invited, 'Invited'),
      (UserStatus.active, 'Active'),
      (UserStatus.suspended, 'Suspended'),
      if (showDeleted) (UserStatus.deleted, 'Deleted'),
    ];
    final levels = [
      (UserLevel.normal, 'Normal'),
      (UserLevel.system, 'System'),
      (UserLevel.super_, 'Super'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chips.
          _FilterRow(
            label: 'Status',
            chips: statuses.map((e) {
              final selected = statusFilter.contains(e.$1);
              return _FilterChip(
                label: e.$2,
                selected: selected,
                onTap: () => onStatusToggle(e.$1),
                cs: cs,
              );
            }).toList(),
            cs: cs,
          ),
          const SizedBox(height: 6),
          // Level chips.
          _FilterRow(
            label: 'Level',
            chips: levels.map((e) {
              final selected = levelFilter.contains(e.$1);
              return _FilterChip(
                label: e.$2,
                selected: selected,
                onTap: () => onLevelToggle(e.$1),
                cs: cs,
              );
            }).toList(),
            cs: cs,
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onClear,
              child: Text(
                'Clear filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.chips,
    required this.cs,
  });

  final String label;
  final List<Widget> chips;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Wrap(spacing: 6, children: chips),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(
                    alpha: cs.brightness == Brightness.dark ? 0.18 : 0.12,
                  )
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(
                      alpha: cs.brightness == Brightness.dark ? 0.55 : 0.4,
                    )
                  : cs.brightness == Brightness.dark
                  ? cs.outline.withValues(alpha: 0.5)
                  : cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User list
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
                  // Circle avatar placeholder.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
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
                        _shimmerBar(120, 12, baseColor, highlightColor),
                        const SizedBox(height: 6),
                        _shimmerBar(80, 10, baseColor, highlightColor),
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

class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.permissions,
    required this.selectedIds,
    required this.currentUserId,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onTrash,
    required this.onPurge,
    required this.onSuspend,
    required this.onRestore,
    required this.onPromote,
    required this.onDemote,
    required this.cs,
  });

  final List<UsersData> users;
  final SystemPermissions permissions;
  final Set<String> selectedIds;
  final String? currentUserId;
  final void Function(UsersData) onTap;
  final void Function(UsersData) onLongPress;
  final void Function(UsersData) onToggleSelection;
  final void Function(UsersData) onTrash;
  final void Function(UsersData) onPurge;
  final void Function(UsersData) onSuspend;
  final void Function(UsersData) onRestore;
  final void Function(UsersData) onPromote;
  final void Function(UsersData) onDemote;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final selectionMode = selectedIds.isNotEmpty;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final u = users[index];
        final isSelected = selectedIds.contains(u.id);

        return _UserRow(
          user: u,
          permissions: permissions,
          isSelected: isSelected,
          selectionMode: selectionMode,
          isMe: u.id == currentUserId,
          onTap: () => onTap(u),
          onLongPress: () => onLongPress(u),
          onToggleSelection: () => onToggleSelection(u),
          onTrash: () => onTrash(u),
          onPurge: () => onPurge(u),
          onSuspend: () => onSuspend(u),
          onRestore: () => onRestore(u),
          onPromote: () => onPromote(u),
          onDemote: () => onDemote(u),
          cs: cs,
        );
      },
    );
  }
}

class _UserRow extends StatefulWidget {
  const _UserRow({
    required this.user,
    required this.permissions,
    required this.isSelected,
    required this.selectionMode,
    required this.isMe,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onTrash,
    required this.onPurge,
    required this.onSuspend,
    required this.onRestore,
    required this.onPromote,
    required this.onDemote,
    required this.cs,
  });

  final UsersData user;
  final SystemPermissions permissions;
  final bool isSelected;
  final bool selectionMode;
  final bool isMe;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;
  final VoidCallback onTrash;
  final VoidCallback onPurge;
  final VoidCallback onSuspend;
  final VoidCallback onRestore;
  final VoidCallback onPromote;
  final VoidCallback onDemote;
  final ColorScheme cs;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(userId: widget.user.id, radius: 20),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: StatusIndicator(
                        status: widget.user.status,
                        level: widget.user.level,
                        backgroundColor: widget.isSelected
                            ? cs.primaryContainer.withValues(
                                alpha: cs.brightness == Brightness.dark
                                    ? 0.2
                                    : 0.3,
                              )
                            : _isHovering && !widget.selectionMode
                            ? cs.surfaceContainerHighest.withValues(
                                alpha: cs.brightness == Brightness.dark
                                    ? 0.5
                                    : 0.3,
                              )
                            : cs.brightness == Brightness.dark
                            ? cs.surface
                            : cs.surfaceContainerLowest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.user.phone,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (!widget.selectionMode) ...[
                  const SizedBox(width: 8),
                  if (isDesktop)
                    _buildDesktopActions(cs)
                  else
                    _buildMobileMenu(cs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopActions(ColorScheme cs) {
    final user = widget.user;
    final isSuper = widget.permissions.level == UserLevel.super_;
    final canSuspend =
        user.status != UserStatus.suspended &&
        user.status != UserStatus.deleted;
    final canRestore =
        user.status == UserStatus.suspended ||
        user.status == UserStatus.deleted;
    final canPromote =
        user.level != UserLevel.super_ &&
        (user.level != UserLevel.system || isSuper);
    final canDemote =
        user.level != UserLevel.normal &&
        (user.level != UserLevel.super_ || isSuper);

    return IgnorePointer(
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
            if (canSuspend)
              IconButton(
                icon: const Icon(Icons.block_outlined),
                iconSize: 18,
                color: const Color(0xFFFFB300),
                onPressed: widget.onSuspend,
                tooltip: 'Suspend',
              ),
            if (canRestore)
              IconButton(
                icon: const Icon(Icons.restore_rounded),
                iconSize: 18,
                color: Colors.teal,
                onPressed: widget.onRestore,
                tooltip: 'Restore',
              ),
            if (canPromote)
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                iconSize: 18,
                color: cs.primary,
                onPressed: widget.onPromote,
                tooltip: 'Promote',
              ),
            if (canDemote)
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded),
                iconSize: 18,
                color: cs.onSurfaceVariant,
                onPressed: widget.onDemote,
                tooltip: 'Demote',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              iconSize: 18,
              color: cs.onSurfaceVariant,
              onPressed: widget.onTrash,
              tooltip: 'Trash',
            ),
            if (isSuper)
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                iconSize: 18,
                color: cs.error,
                onPressed: widget.onPurge,
                tooltip: 'Purge',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMenu(ColorScheme cs) {
    final user = widget.user;
    final isSuper = widget.permissions.level == UserLevel.super_;
    final canSuspend =
        user.status != UserStatus.suspended &&
        user.status != UserStatus.deleted;
    final canRestore =
        user.status == UserStatus.suspended ||
        user.status == UserStatus.deleted;
    final canPromote =
        user.level != UserLevel.super_ &&
        (user.level != UserLevel.system || isSuper);
    final canDemote =
        user.level != UserLevel.normal &&
        (user.level != UserLevel.super_ || isSuper);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
      padding: EdgeInsets.zero,
      color: cs.surfaceContainerHighest,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      position: PopupMenuPosition.under,
      onSelected: (val) {
        switch (val) {
          case 'edit':
            widget.onTap();
          case 'suspend':
            widget.onSuspend();
          case 'restore':
            widget.onRestore();
          case 'promote':
            widget.onPromote();
          case 'demote':
            widget.onDemote();
          case 'trash':
            widget.onTrash();
          case 'purge':
            widget.onPurge();
        }
      },
      itemBuilder: (context) => [
        _menuItem('edit', Icons.edit_outlined, 'Edit', cs.onSurface, cs),
        if (canSuspend)
          _menuItem(
            'suspend',
            Icons.block_outlined,
            'Suspend',
            const Color(0xFFFFB300),
            cs,
          ),
        if (canRestore)
          _menuItem(
            'restore',
            Icons.restore_rounded,
            'Restore',
            Colors.teal,
            cs,
          ),
        if (canPromote)
          _menuItem(
            'promote',
            Icons.arrow_upward_rounded,
            'Promote',
            cs.primary,
            cs,
          ),
        if (canDemote)
          _menuItem(
            'demote',
            Icons.arrow_downward_rounded,
            'Demote',
            cs.onSurfaceVariant,
            cs,
          ),
        _menuItem(
          'trash',
          Icons.delete_outline_rounded,
          'Trash',
          cs.onSurfaceVariant,
          cs,
        ),
        if (isSuper)
          _menuItem(
            'purge',
            Icons.delete_forever_rounded,
            'Purge',
            cs.error,
            cs,
          ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
    ColorScheme cs,
  ) {
    return PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
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
              Icons.person_search_outlined,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'No users match your search.' : 'No users yet.',
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
