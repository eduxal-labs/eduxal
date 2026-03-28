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
import '../roles/role_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Members Section — system dashboard tab
// ─────────────────────────────────────────────────────────────────────────────

/// Displays all users with `level = UserLevel.system` or `super_` in a
/// reactive list.
///
/// Features:
/// - Search toolbar (name / phone, debounced 200ms)
/// - Status dot indicator on each avatar
/// - Row actions: Roles, Promote, Suspend/Restore, Demote, Purge (super only)
/// - Add Member modal (promote Normal → System)
class MembersSection extends StatefulWidget {
  const MembersSection({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<MembersSection> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
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

  List<UsersData> _applySearch(List<UsersData> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _removeMember(UsersData user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Remove member',
      message:
          'Remove "${user.name}" from system level? '
          'They will be set to Normal.',
      actionLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(
        user.id,
        UserLevel.normal,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} removed from members')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
      }
    }
  }

  Future<void> _purgeMember(UsersData user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Permanently delete',
      message:
          'Permanently delete "${user.name}"?\n\n'
          'This action is irreversible and will permanently remove '
          'this record from the local database.',
      actionLabel: 'Purge',
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
        ).showSnackBar(SnackBar(content: Text('Failed to purge member: $e')));
      }
    }
  }

  Future<void> _promoteMember(UsersData user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Promote to Super',
      message:
          'Promote "${user.name}" to Super level? '
          'They will have full access and bypass all permission checks.',
      actionLabel: 'Promote',
    );
    if (!confirmed || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(
        user.id,
        UserLevel.super_,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} promoted to Super')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to promote member: $e')));
      }
    }
  }

  Future<void> _updateStatus(
    UsersData user,
    UserStatus status,
    String label, {
    bool confirm = false,
    String? confirmTitle,
    String? confirmMessage,
  }) async {
    if (confirm) {
      final ok = await _showConfirmDialog(
        title: confirmTitle ?? 'Update status',
        message: confirmMessage ?? 'Set "${user.name}" status to $label?',
        actionLabel: label[0].toUpperCase() + label.substring(1),
        isDestructive:
            status == UserStatus.suspended || status == UserStatus.deleted,
      );
      if (!ok || !mounted) return;
    }

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.updateUserStatus(user.id, status, accountId: accountId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${user.name} $label')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    bool isDestructive = false,
  }) async {
    return showEduConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: actionLabel,
      isDestructive: isDestructive,
    );
  }

  void openAddMemberModal() {
    showEduSheet(
      context: context,
      builder: (_) => AddMemberSheet(permissions: widget.permissions),
      maxWidth: 480,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<UsersData>>(
      stream: usersDao.watchSystemMembers(),
      builder: (context, snapshot) {
        final allMembers = snapshot.data ?? [];
        final filtered = _applySearch(allMembers);

        return Column(
          children: [
            // ── Toolbar ──────────────────────────────────────────────────
            _Toolbar(searchController: _searchController, cs: cs),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: !snapshot.hasData
                  ? const _ListShimmer()
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No system members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No members match your search.'
                                : 'Promote a user to System level to add them here.',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final isMe = user.id == cache.currentUser?.user.id;
                        final isSuper =
                            widget.permissions.level == UserLevel.super_;

                        final actions = <_RowAction>[
                          _RowAction(
                            icon: Icons.assignment_ind_outlined,
                            label: 'Roles',
                            onTap: () => _openRolesSheet(context, user),
                          ),
                        ];

                        if (!isMe) {
                          if (isSuper && user.level == UserLevel.system) {
                            actions.add(
                              _RowAction(
                                icon: Icons.arrow_upward_rounded,
                                label: 'Promote',
                                color: const Color(0xFFFF7043),
                                onTap: () => _promoteMember(user),
                              ),
                            );
                          }

                          if (user.status == UserStatus.active ||
                              user.status == UserStatus.invited) {
                            actions.add(
                              _RowAction(
                                icon: Icons.block_rounded,
                                label: 'Suspend',
                                color: const Color(0xFFFFB300),
                                onTap: () => _updateStatus(
                                  user,
                                  UserStatus.suspended,
                                  'suspended',
                                  confirm: true,
                                  confirmTitle: 'Suspend member',
                                  confirmMessage:
                                      'Suspend "${user.name}"? They will lose access until restored.',
                                ),
                              ),
                            );
                          }

                          if (user.status == UserStatus.suspended ||
                              user.status == UserStatus.deleted) {
                            actions.add(
                              _RowAction(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Restore',
                                color: const Color(0xFF26A69A),
                                onTap: () => _updateStatus(
                                  user,
                                  UserStatus.active,
                                  'restored',
                                ),
                              ),
                            );
                          }

                          if (user.status == UserStatus.active ||
                              user.status == UserStatus.invited) {
                            actions.add(
                              _RowAction(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                isDestructive: true,
                                onTap: () => _updateStatus(
                                  user,
                                  UserStatus.deleted,
                                  'deleted',
                                  confirm: true,
                                  confirmTitle: 'Delete member',
                                  confirmMessage:
                                      'Mark "${user.name}" as deleted? They can be restored later.',
                                ),
                              ),
                            );
                          }

                          actions.add(
                            _RowAction(
                              icon: Icons.arrow_downward_rounded,
                              label: 'Demote',
                              onTap: () => _removeMember(user),
                            ),
                          );

                          if (isSuper) {
                            actions.add(
                              _RowAction(
                                icon: Icons.delete_forever_rounded,
                                label: 'Purge',
                                isDestructive: true,
                                onTap: () => _purgeMember(user),
                              ),
                            );
                          }
                        }

                        return _MemberRow(
                          user: user,
                          isMe: isMe,
                          onTap: () => _openRolesSheet(context, user),
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

  void _openRolesSheet(BuildContext context, UsersData user) {
    showEduSheet(
      context: context,
      builder: (_) =>
          _MemberRolesSheet(user: user, permissions: widget.permissions),
      maxWidth: 480,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row action model
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
// _MemberRow — flat data-table row with status tinting
// ─────────────────────────────────────────────────────────────────────────────

class _MemberRow extends StatefulWidget {
  const _MemberRow({
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
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow>
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

  /// Accent colour: super active → amber/gold, system active → indigo,
  /// non-active statuses → status colour.
  Color _accentColor(bool isDark) {
    if (widget.user.status == UserStatus.active ||
        widget.user.status == UserStatus.invited) {
      if (widget.user.level == UserLevel.super_) {
        return isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);
      }
      return isDark ? const Color(0xFF7986CB) : const Color(0xFF3F51B5);
    }
    switch (widget.user.status) {
      case UserStatus.suspended:
        return AppTheme.statusSuspended;
      case UserStatus.deleted:
        return AppTheme.statusDeleted;
      default:
        return AppTheme.statusInvited;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
    final accentColor = _accentColor(isDark);

    // ── Background states ──────────────────────────────────────────────
    final idleBg = accentColor.withValues(alpha: isDark ? 0.06 : 0.04);
    final hoverBg = accentColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final pressBg = accentColor.withValues(alpha: isDark ? 0.18 : 0.12);

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

    // ── Level label ────────────────────────────────────────────────────
    final levelLabel = widget.user.level == UserLevel.super_
        ? 'Super'
        : 'System';

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
                                              letterSpacing: 0.1,
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

                              // Level label
                              const SizedBox(width: 8),
                              Text(
                                levelLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                  letterSpacing: 0.3,
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
    final baseColor = widget.action.isDestructive
        ? cs.error
        : widget.action.color ?? cs.onSurfaceVariant;
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
// _MobileActions — mobile: three-dot → positioned popup menu
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

    // Single action — render directly as icon button
    if (actions.length == 1) {
      final action = actions.first;
      final color = action.isDestructive
          ? cs.error
          : action.color ?? cs.onSurfaceVariant;
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

    // Multiple actions — three-dot → compact positioned popup
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
            hintText: 'Search members...',
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
// Member Roles sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Modal that shows the system-level roles assigned to a member, with an
/// optional "Assign role" button (guarded by `permissions.can(Resource.roles, Action.assign)`).
///
/// On mobile: shown as a bottom sheet (max 75 % of screen height).
/// On desktop: shown as a centred Dialog with width 480 px.
class _MemberRolesSheet extends StatefulWidget {
  const _MemberRolesSheet({required this.user, required this.permissions});

  final UsersData user;
  final SystemPermissions permissions;

  @override
  State<_MemberRolesSheet> createState() => _MemberRolesSheetState();
}

class _MemberRolesSheetState extends State<_MemberRolesSheet> {
  void _openAssignRoleSheet(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (_) =>
          _AssignRoleSheet(user: widget.user, permissions: widget.permissions),
      maxWidth: 480,
    );
  }

  void _navigateToRole(BuildContext context, Role role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RoleDetailScreen(role: role, permissions: widget.permissions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
    final canAssign =
        widget.permissions.can(Resource.roles, Action.assign) ||
        widget.permissions.level != UserLevel.normal;

    // Desktop Dialog has a fixed height; bottom sheet is constrained by max %.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Handle (mobile only) ─────────────────────────────────────────
        if (!isDesktop)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, isDesktop ? 20 : 10, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(userId: widget.user.id, radius: 20),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: StatusIndicator(
                      status: widget.user.status,
                      level: UserLevel.system,
                      backgroundColor: cs.surface,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: TextStyle(
                        fontSize: 15,
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
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Assign button
              if (canAssign) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _openAssignRoleSheet(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: cs.primary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.primary,
                    ),
                  ),
                  child: Text(
                    'Assign role',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Divider(height: 0.5, thickness: 0.5, color: cs.outlineVariant),

        // ── Section label ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Text(
            'ASSIGNED ROLES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              letterSpacing: 1.1,
            ),
          ),
        ),

        // ── Roles list (reactive) ────────────────────────────────────────
        Flexible(
          child: StreamBuilder<List<({Scope scope, Role role})>>(
            stream: rolesDao.watchRolesForUser(widget.user.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final entries = snapshot.data!;

              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      Icon(
                        Icons.assignment_ind_outlined,
                        size: 36,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No roles assigned',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This member has no system-level roles.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (canAssign) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _openAssignRoleSheet(context),
                          child: Text(
                            'Assign a role',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final role = entries[index].role;
                  return _RoleCard(
                    role: role,
                    isDark: isDark,
                    cs: cs,
                    onTap: () => _navigateToRole(context, role),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (isDesktop) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          color: cs.surface,
          child: content,
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role card (inside Member Roles sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final Role role;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surface : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? cs.outline.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon container
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
                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assign Role sheet (role picker — inverted: pick a role for a known user)
// ─────────────────────────────────────────────────────────────────────────────

class _AssignRoleSheet extends StatefulWidget {
  const _AssignRoleSheet({required this.user, required this.permissions});

  final UsersData user;
  final SystemPermissions permissions;

  @override
  State<_AssignRoleSheet> createState() => _AssignRoleSheetState();
}

class _AssignRoleSheetState extends State<_AssignRoleSheet> {
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

  List<Role> _filter(List<Role> roles) {
    if (_searchQuery.isEmpty) return roles;
    final q = _searchQuery.toLowerCase();
    return roles.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _assign(Role role) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _assigningIds.add(role.id));

    try {
      await rolesDao.assignUserToRole(
        userId: widget.user.id,
        roleId: role.id,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${role.name}" assigned to ${widget.user.name}.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign role: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningIds.remove(role.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final isDark = !isLight;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Handle (mobile only) ─────────────────────────────────────────
        if (!isDesktop)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, isDesktop ? 20 : 10, 20, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  Icons.assignment_ind_outlined,
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
                      'Assign Role',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Roles not yet assigned to ${widget.user.name}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                hintText: 'Search roles…',
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

        // ── Role list ───────────────────────────────────────────────────
        Flexible(
          child: StreamBuilder<List<Role>>(
            stream: rolesDao.watchEligibleRolesForUser(widget.user.id),
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
                            ? 'All roles assigned'
                            : 'No matching roles',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.data!.isEmpty
                            ? 'This member already holds all system-level roles.'
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final role = filtered[index];
                  final isAssigning = _assigningIds.contains(role.id);
                  return _EligibleRoleRow(
                    role: role,
                    isDark: isDark,
                    cs: cs,
                    isAssigning: isAssigning,
                    onAssign: () => _assign(role),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (isDesktop) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          color: cs.surface,
          child: inner,
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: inner,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Eligible role row (Assign Role sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _EligibleRoleRow extends StatelessWidget {
  const _EligibleRoleRow({
    required this.role,
    required this.isDark,
    required this.cs,
    required this.isAssigning,
    required this.onAssign,
  });

  final Role role;
  final bool isDark;
  final ColorScheme cs;
  final bool isAssigning;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surface : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? cs.outline.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon container
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
            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: 0.1,
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
            // Assign button
            SizedBox(
              width: 64,
              height: 30,
              child: isAssigning
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onAssign,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: cs.primary.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(64, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Assign',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.primary,
                        ),
                      ),
                    ),
            ),
          ],
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
          separatorBuilder: (_, _) => const SizedBox(height: 8),
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
// Add Member sheet / modal
// ─────────────────────────────────────────────────────────────────────────────

/// Modal sheet for promoting a Normal-level user to System level.
///
/// Shows a searchable list of Normal-level users. Tapping "Add" on a user
/// promotes them to System and shows a success snackbar.
class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
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

  List<UsersData> _applySearch(List<UsersData> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _promote(UsersData user) async {
    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(
        user.id,
        UserLevel.system,
        accountId: accountId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} added as system member')),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.80,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Member',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Promote a user to system level',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 20, thickness: 0.5, color: cs.outlineVariant),

          // ── Search ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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

          // ── User list ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<UsersData>>(
              stream: usersDao.watchNormalUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }

                final filtered = _applySearch(snapshot.data!);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No users match your search.'
                          : 'No eligible users.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 68,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return _EligibleUserRow(
                      user: user,
                      onAdd: () => _promote(user),
                      cs: cs,
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

// ─────────────────────────────────────────────────────────────────────────────
// Eligible user row (Add Member modal)
// ─────────────────────────────────────────────────────────────────────────────

class _EligibleUserRow extends StatelessWidget {
  const _EligibleUserRow({
    required this.user,
    required this.onAdd,
    required this.cs,
  });

  final UsersData user;
  final VoidCallback onAdd;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Avatar with status dot.
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(userId: user.id, radius: 18),
              Positioned(
                bottom: -1,
                right: -1,
                child: StatusIndicator(
                  status: user.status,
                  level: UserLevel.normal,
                  backgroundColor: cs.surface,
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
                const SizedBox(height: 1),
                Text(
                  user.phone,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
