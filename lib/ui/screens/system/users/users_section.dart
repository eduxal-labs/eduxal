import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';

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
    final isDark = cs.brightness == Brightness.dark;

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
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty || _hasActiveFilters
                                ? 'No users match your filters.'
                                : 'No users in the system yet.',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final isMe = user.id == cache.currentUser?.user.id;

                        final actions = <_RowAction>[];
                        if (!isMe) {
                          final canSeeDeleted =
                              widget.permissions.canSeeDeleted;
                          final canUpdate = widget.permissions.can(
                            Resource.users,
                            Action.update,
                          );
                          final canDelete = widget.permissions.can(
                            Resource.users,
                            Action.delete,
                          );

                          if (canUpdate && user.level == UserLevel.normal) {
                            actions.add(
                              _RowAction(
                                icon: Icons.shield_outlined,
                                label: 'Promote to System',
                                onTap: () =>
                                    _promoteUser(user, UserLevel.system),
                                color: AppTheme.actionAssign,
                              ),
                            );
                          }
                          if (canUpdate &&
                              user.level == UserLevel.system &&
                              canSeeDeleted) {
                            actions.add(
                              _RowAction(
                                icon: Icons.star_outline_rounded,
                                label: 'Elevate to Super',
                                onTap: () =>
                                    _promoteUser(user, UserLevel.super_),
                                color: AppTheme.actionApprove,
                              ),
                            );
                          }
                          if (canUpdate && user.level == UserLevel.system) {
                            actions.add(
                              _RowAction(
                                icon: Icons.arrow_downward_rounded,
                                label: 'Demote to Normal',
                                onTap: () =>
                                    _demoteUser(user, UserLevel.normal),
                                color: AppTheme.actionUpdate,
                              ),
                            );
                          }
                          if (canUpdate &&
                              user.level == UserLevel.super_ &&
                              canSeeDeleted) {
                            actions.add(
                              _RowAction(
                                icon: Icons.arrow_downward_rounded,
                                label: 'Demote to System',
                                onTap: () =>
                                    _demoteUser(user, UserLevel.system),
                                color: AppTheme.actionUpdate,
                              ),
                            );
                          }
                          if (canUpdate &&
                              (user.status == UserStatus.active ||
                                  user.status == UserStatus.invited)) {
                            actions.add(
                              _RowAction(
                                icon: Icons.block_rounded,
                                label: 'Suspend',
                                onTap: () => _suspendUser(user),
                                color: AppTheme.statusSuspended,
                                isDestructive: true,
                              ),
                            );
                          }
                          if (canUpdate &&
                              user.status == UserStatus.suspended) {
                            actions.add(
                              _RowAction(
                                icon: Icons.restore_rounded,
                                label: 'Restore',
                                onTap: () => _restoreUser(user),
                                color: AppTheme.statusActive,
                              ),
                            );
                          }
                          if (canDelete && user.status != UserStatus.deleted) {
                            actions.add(
                              _RowAction(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                onTap: () => _trashUser(user),
                                color: AppTheme.actionDelete,
                                isDestructive: true,
                              ),
                            );
                          }
                          if (canUpdate && user.status == UserStatus.deleted) {
                            actions.add(
                              _RowAction(
                                icon: Icons.restore_rounded,
                                label: 'Restore',
                                onTap: () => _restoreUser(user),
                                color: AppTheme.statusActive,
                              ),
                            );
                          }
                          if (canSeeDeleted) {
                            actions.add(
                              _RowAction(
                                icon: Icons.delete_forever_rounded,
                                label: 'Purge',
                                onTap: () => _purgeUser(user),
                                color: AppTheme.actionPurge,
                                isDestructive: true,
                              ),
                            );
                          }
                        }

                        return _UserRow(
                          user: user,
                          isMe: isMe,
                          onTap: () => _openDetail(user),
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
// _RowAction — lightweight action descriptor for row buttons
// ─────────────────────────────────────────────────────────────────────────────

class _RowAction {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDestructive;
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserRow — flat data-table row with status-tinted background
// ─────────────────────────────────────────────────────────────────────────────

class _UserRow extends StatefulWidget {
  const _UserRow({
    required this.user,
    required this.isMe,
    required this.onTap,
    required this.actions,
  });

  final UsersData user;
  final bool isMe;
  final VoidCallback onTap;
  final List<_RowAction> actions;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  Color _statusColor() {
    switch (widget.user.status) {
      case UserStatus.active:
        return AppTheme.statusActive;
      case UserStatus.invited:
        return AppTheme.statusInvited;
      case UserStatus.suspended:
        return AppTheme.statusSuspended;
      case UserStatus.deleted:
        return AppTheme.statusDeleted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final accentColor = _statusColor();

    // ── Background states ──────────────────────────────────────────────
    final idleBg = isDark
        ? accentColor.withValues(alpha: 0.06)
        : accentColor.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.12);

    // ── Avatar with status ring ────────────────────────────────────────
    Widget avatar = Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(
            alpha: _isHovered || _isPressed ? 0.7 : 0.35,
          ),
          width: 1.5,
        ),
      ),
      child: UserAvatar(userId: widget.user.id, radius: 15),
    );

    avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -1,
          right: -1,
          child: StatusIndicator(
            status: widget.user.status,
            level: widget.user.level,
            backgroundColor: _isPressed
                ? pressBg
                : _isHovered
                ? hoverBg
                : idleBg,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _isPressed
                    ? pressBg
                    : _isHovered
                    ? hoverBg
                    : idleBg,
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: _isHovered || _isPressed
                      ? accentColor.withValues(alpha: isDark ? 0.35 : 0.25)
                      : cs.outline.withValues(alpha: isDark ? 0.10 : 0.08),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Status accent bar ───────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isHovered || _isPressed ? 4 : 3,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),

                      // ── Content ─────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              // Avatar
                              avatar,
                              const SizedBox(width: 12),

                              // Name + phone
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.user.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (widget.isMe) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.primary.withValues(
                                                alpha: 0.07,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.kChipRadius,
                                                  ),
                                              border: Border.all(
                                                color: cs.primary.withValues(
                                                  alpha: 0.5,
                                                ),
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
                                      widget.user.phone,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Joined date
                              const SizedBox(width: 8),
                              Text(
                                _formatRelativeDate(
                                  widget.user.created.toInt(),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),

                              // Actions
                              if (widget.actions.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                isDesktop
                                    ? _InlineActions(
                                        actions: widget.actions,
                                        isHovered: _isHovered,
                                      )
                                    : _MobileActions(actions: widget.actions),
                              ],

                              const SizedBox(width: 4),

                              // ── Animated chevron ────────────────────
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                offset: Offset(_isHovered ? 0.15 : 0.0, 0),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isHovered ? 0.8 : 0.35,
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _isHovered
                                        ? accentColor
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InlineActions — desktop: icon buttons that fade in on row hover
// ─────────────────────────────────────────────────────────────────────────────

class _InlineActions extends StatelessWidget {
  const _InlineActions({required this.actions, required this.isHovered});

  final List<_RowAction> actions;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map((a) => _InlineActionButton(action: a, isRowHovered: isHovered))
            .toList(),
      ),
    );
  }
}

class _InlineActionButton extends StatefulWidget {
  const _InlineActionButton({required this.action, required this.isRowHovered});

  final _RowAction action;
  final bool isRowHovered;

  @override
  State<_InlineActionButton> createState() => _InlineActionButtonState();
}

class _InlineActionButtonState extends State<_InlineActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor =
        widget.action.color ??
        (widget.action.isDestructive ? cs.error : cs.onSurfaceVariant);
    final effectiveAlpha = (_isHovered || widget.isRowHovered) ? 1.0 : 0.0;

    return Tooltip(
      message: widget.action.label,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.action.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered
                  ? baseColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: effectiveAlpha,
              child: Icon(widget.action.icon, size: 16, color: baseColor),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MobileActions — mobile: three-dot → compact positioned popup menu
// ─────────────────────────────────────────────────────────────────────────────

class _MobileActions extends StatelessWidget {
  const _MobileActions({required this.actions});

  final List<_RowAction> actions;

  Future<void> _showPopupMenu(BuildContext context, GlobalKey key) async {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonRect =
        renderBox.localToGlobal(Offset.zero, ancestor: overlay) &
        renderBox.size;
    final screenSize = MediaQuery.sizeOf(context);
    final screenRect = Offset.zero & screenSize;
    final position = RelativeRect.fromRect(buttonRect, screenRect);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showMenu<int>(
      context: context,
      position: position,
      color: AppTheme.overlayBg(isDark, cs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
        side: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      items: [
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  actions[i].icon,
                  size: 16,
                  color: actions[i].isDestructive
                      ? cs.error
                      : actions[i].color ?? cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  actions[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: actions[i].isDestructive ? cs.error : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).then((index) {
      if (index != null) actions[index].onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Single action — render it directly as an icon button
    if (actions.length == 1) {
      final action = actions.first;
      final color =
          action.color ??
          (action.isDestructive ? cs.error : cs.onSurfaceVariant);
      return Tooltip(
        message: action.label,
        waitDuration: const Duration(milliseconds: 400),
        child: SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: Icon(action.icon, size: 18, color: color),
            onPressed: action.onTap,
          ),
        ),
      );
    }

    // Multiple actions — three-dot → compact positioned popup menu
    final key = GlobalKey();
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: key,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
        tooltip: 'More actions',
        onPressed: () => _showPopupMenu(context, key),
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
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
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
                  hintText: 'Search users...',
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
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active ? cs.primary.withValues(alpha: 0.10) : cs.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: active
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
            border: Border.all(
              color: active
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.5),
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
