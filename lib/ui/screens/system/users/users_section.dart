import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_sheet.dart';
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

  // ── Individual actions ─────────────────────────────────────────────────────

  Future<void> _suspendUser(UsersData user) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Suspend user',
      message: 'Suspend ${user.name}? They will lose access until restored.',
      confirmLabel: 'Suspend',
      isDestructive: true,
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

  Future<void> _promoteUser(UsersData user, UserLevel targetLevel) async {
    final label = targetLevel == UserLevel.system ? 'System' : 'Super';

    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Promote to $label',
      message: 'Promote ${user.name} to $label level?',
      confirmLabel: 'Promote',
    );
    if (!confirmed || !mounted) return;

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

  Future<void> _demoteUser(UsersData user, UserLevel targetLevel) async {
    final label = targetLevel == UserLevel.system ? 'System' : 'Normal';

    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Demote to $label',
      message: 'Demote ${user.name} to $label level?',
      confirmLabel: 'Demote',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

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
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Trash User',
      message:
          'Set ${user.name} to Deleted status? '
          'This is a soft delete — the record can be restored later.',
      confirmLabel: 'Trash',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

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
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Purge User',
      message:
          'Permanently delete ${user.name}?\n\n'
          'This action is irreversible and will permanently remove this record.',
      confirmLabel: 'Purge',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

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

  // ── Detail sheet ───────────────────────────────────────────────────────────

  void _openDetail(UsersData user) {
    showEduSheet(
      context: context,
      builder: (_) =>
          UserDetailSheet(user: user, permissions: widget.permissions),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<UsersData>>(
      stream: usersDao.watchAllUsers(),
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? [];
        final filtered = _applyFilters(allUsers);

        return Column(
          children: [
            // ── Toolbar ────────────────────────────────────────────────────
            _Toolbar(
              searchController: _searchController,
              filterExpanded: _filterExpanded,
              hasActiveFilters: _hasActiveFilters,
              onToggleFilter: () =>
                  setState(() => _filterExpanded = !_filterExpanded),
              cs: cs,
            ),

            // ── Filter panel ──────────────────────────────────────────────
            if (_filterExpanded)
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
                  : SingleChildScrollView(
                      child: EduDataTable<UsersData>(
                        items: filtered,
                        emptyIcon: Icons.person_search_outlined,
                        emptyTitle: 'No users found',
                        emptySubtitle:
                            _searchQuery.isNotEmpty || _hasActiveFilters
                            ? 'No users match your filters.'
                            : 'No users in the system yet.',
                        onItemTap: _openDetail,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        actions: (user) {
                          final isMe = user.id == cache.currentUser?.user.id;
                          if (isMe) return [];

                          final actions = <EduDataTableAction<UsersData>>[];
                          final canSeeDeleted =
                              widget.permissions.canSeeDeleted;

                          // ── Promote to System: only if Normal ──
                          if (user.level == UserLevel.normal) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.shield_outlined,
                                label: 'Promote to System',
                                onTap: (u) => _promoteUser(u, UserLevel.system),
                                color: AppTheme.actionAssign,
                              ),
                            );
                          }

                          // ── Elevate to Super: only if System & viewer is super ──
                          if (user.level == UserLevel.system && canSeeDeleted) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.star_outline_rounded,
                                label: 'Elevate to Super',
                                onTap: (u) => _promoteUser(u, UserLevel.super_),
                                color: AppTheme.actionApprove,
                              ),
                            );
                          }

                          // ── Demote to Normal: only if System ──
                          if (user.level == UserLevel.system) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.arrow_downward_rounded,
                                label: 'Demote to Normal',
                                onTap: (u) => _demoteUser(u, UserLevel.normal),
                                color: AppTheme.actionUpdate,
                              ),
                            );
                          }

                          // ── Demote to System: only if Super & viewer is super ──
                          if (user.level == UserLevel.super_ && canSeeDeleted) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.arrow_downward_rounded,
                                label: 'Demote to System',
                                onTap: (u) => _demoteUser(u, UserLevel.system),
                                color: AppTheme.actionUpdate,
                              ),
                            );
                          }

                          // ── Suspend: only if active or invited ──
                          if (user.status == UserStatus.active ||
                              user.status == UserStatus.invited) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.block_rounded,
                                label: 'Suspend',
                                onTap: (u) => _suspendUser(u),
                                color: AppTheme.statusSuspended,
                                isDestructive: true,
                              ),
                            );
                          }

                          // ── Restore: only if suspended ──
                          if (user.status == UserStatus.suspended) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.restore_rounded,
                                label: 'Restore',
                                onTap: (u) => _restoreUser(u),
                                color: AppTheme.statusActive,
                              ),
                            );
                          }

                          // ── Delete: only if NOT already deleted ──
                          if (user.status != UserStatus.deleted) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                onTap: (u) => _trashUser(u),
                                color: AppTheme.actionDelete,
                                isDestructive: true,
                              ),
                            );
                          }

                          // ── Restore from deleted: only if deleted ──
                          if (user.status == UserStatus.deleted) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.restore_rounded,
                                label: 'Restore',
                                onTap: (u) => _restoreUser(u),
                                color: AppTheme.statusActive,
                              ),
                            );
                          }

                          // ── Purge: super only ──
                          if (canSeeDeleted) {
                            actions.add(
                              EduDataTableAction<UsersData>(
                                icon: Icons.delete_forever_rounded,
                                label: 'Purge',
                                onTap: (u) => _purgeUser(u),
                                color: AppTheme.actionPurge,
                                isDestructive: true,
                              ),
                            );
                          }

                          return actions;
                        },
                        columns: const [
                          EduDataTableColumn(label: 'User', flex: 3),
                          EduDataTableColumn(label: 'Level', flex: 1),
                          EduDataTableColumn(label: 'Status', flex: 1),
                          EduDataTableColumn(label: 'Joined', flex: 1),
                        ],
                        cellBuilder: (context, user, index, isHovered) {
                          final isMe = user.id == cache.currentUser?.user.id;
                          final cs = Theme.of(context).colorScheme;
                          return switch (index) {
                            0 => _UserIdentityCell(user: user, isMe: isMe),
                            1 => _UserLevelBadge(level: user.level),
                            2 => _UserStatusBadge(status: user.status),
                            3 => Text(
                              _formatRelativeDate(user.created.toInt()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
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
// User identity cell — avatar + name + phone
// ─────────────────────────────────────────────────────────────────────────────

class _UserIdentityCell extends StatelessWidget {
  const _UserIdentityCell({required this.user, required this.isMe});

  final UsersData user;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // ── Avatar with status indicator ───────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(userId: user.id, radius: 16),
            Positioned(
              bottom: -1,
              right: -1,
              child: StatusIndicator(
                status: user.status,
                level: user.level,
                backgroundColor: cs.surface,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),

        // ── Name + phone ───────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'YOU',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                user.phone,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User level badge — compact chip
// ─────────────────────────────────────────────────────────────────────────────

class _UserLevelBadge extends StatelessWidget {
  const _UserLevelBadge({required this.level});

  final UserLevel level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final (label, color) = switch (level) {
      UserLevel.normal => ('Normal', cs.onSurfaceVariant),
      UserLevel.system => ('System', cs.primary),
      UserLevel.super_ => ('Super', const Color(0xFFFF7043)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User status badge — compact chip
// ─────────────────────────────────────────────────────────────────────────────

class _UserStatusBadge extends StatelessWidget {
  const _UserStatusBadge({required this.status});

  final UserStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final (label, color) = switch (status) {
      UserStatus.invited => ('Invited', const Color(0xFF42A5F5)),
      UserStatus.active => ('Active', const Color(0xFF26A69A)),
      UserStatus.suspended => ('Suspended', const Color(0xFFFFB300)),
      UserStatus.deleted => ('Deleted', cs.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar — search + filter toggle
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.filterExpanded,
    required this.hasActiveFilters,
    required this.onToggleFilter,
    required this.cs,
  });

  final TextEditingController searchController;
  final bool filterExpanded;
  final bool hasActiveFilters;
  final VoidCallback onToggleFilter;
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
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Formats a Unix-epoch timestamp (seconds) as a relative date string.
String _formatRelativeDate(int? epochSeconds) {
  if (epochSeconds == null || epochSeconds == 0) return '—';
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays < 1) return 'Today';
  if (diff.inDays == 1) return '1d ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
