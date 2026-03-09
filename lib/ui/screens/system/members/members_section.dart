import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';
import '../roles/role_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Members Section — system dashboard tab
// ─────────────────────────────────────────────────────────────────────────────

/// Displays all users with `level = UserLevel.system` in a reactive list.
///
/// Features:
/// - Search toolbar (name / phone, debounced 200ms)
/// - Status dot indicator on each avatar
/// - Row actions: Remove, Elevate, Suspend, Trash, Purge (super only)
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

  Future<void> _elevateMember(UsersData user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Elevate to Super',
      message:
          'Elevate "${user.name}" to Super level? '
          'This grants unrestricted access.',
      actionLabel: 'Elevate',
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
          SnackBar(content: Text('${user.name} elevated to Super')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to elevate member: $e')));
      }
    }
  }

  Future<void> _suspendMember(UsersData user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Suspend member',
      message:
          'Suspend "${user.name}"? '
          'They will be set to Suspended status and Normal level.',
      actionLabel: 'Suspend',
    );
    if (!confirmed || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(
        user.id,
        UserLevel.normal,
        accountId: accountId,
        status: UserStatus.suspended,
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
        ).showSnackBar(SnackBar(content: Text('Failed to suspend member: $e')));
      }
    }
  }

  Future<void> _trashMember(UsersData user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Trash member',
      message:
          'Move "${user.name}" to trash? '
          'They will be marked as Deleted and set to Normal level.',
      actionLabel: 'Trash',
    );
    if (!confirmed || !mounted) return;

    try {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) return;
      await usersDao.setUserLevel(
        user.id,
        UserLevel.normal,
        accountId: accountId,
        status: UserStatus.deleted,
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
        ).showSnackBar(SnackBar(content: Text('Failed to trash member: $e')));
      }
    }
  }

  Future<void> _demoteMember(UsersData user) async {
    // Members shown here are system-level. Demoting always goes to normal.
    final confirmed = await _showConfirmDialog(
      title: 'Demote to Normal',
      message:
          'Demote "${user.name}" to Normal level? '
          'They will be removed from the Members list.',
      actionLabel: 'Demote',
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
          SnackBar(content: Text('${user.name} demoted to Normal')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to demote member: $e')));
      }
    }
  }

  Future<void> _restoreMember(UsersData user) async {
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
        ).showSnackBar(SnackBar(content: Text('Failed to restore member: $e')));
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

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    bool isDestructive = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: cs.surface,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDestructive ? cs.error : cs.onSurface,
            letterSpacing: 0.1,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDestructive ? cs.error : cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void openAddMemberModal() {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 480,
            child: AddMemberSheet(permissions: widget.permissions),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddMemberSheet(permissions: widget.permissions),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                  ? _EmptyState(hasQuery: _searchQuery.isNotEmpty, cs: cs)
                  : _MemberList(
                      members: filtered,
                      permissions: widget.permissions,
                      currentUserId: cache.currentUser?.user.id,
                      onRemove: _removeMember,
                      onElevate: _elevateMember,
                      onSuspend: _suspendMember,
                      onDemote: _demoteMember,
                      onRestore: _restoreMember,
                      onTrash: _trashMember,
                      onPurge: _purgeMember,
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
            hintText: 'Search members by name or phone…',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member list
// ─────────────────────────────────────────────────────────────────────────────

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.permissions,
    required this.currentUserId,
    required this.onRemove,
    required this.onElevate,
    required this.onSuspend,
    required this.onDemote,
    required this.onRestore,
    required this.onTrash,
    required this.onPurge,
    required this.cs,
  });

  final List<UsersData> members;
  final SystemPermissions permissions;
  final String? currentUserId;
  final Future<void> Function(UsersData) onRemove;
  final Future<void> Function(UsersData) onElevate;
  final Future<void> Function(UsersData) onSuspend;
  final Future<void> Function(UsersData) onDemote;
  final Future<void> Function(UsersData) onRestore;
  final Future<void> Function(UsersData) onTrash;
  final Future<void> Function(UsersData) onPurge;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = members[index];
        return _MemberRow(
          user: m,
          permissions: permissions,
          isMe: m.id == currentUserId,
          onRemove: () => onRemove(m),
          onElevate: () => onElevate(m),
          onSuspend: () => onSuspend(m),
          onDemote: () => onDemote(m),
          onRestore: () => onRestore(m),
          onTrash: () => onTrash(m),
          onPurge: () => onPurge(m),
          cs: cs,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member row
// ─────────────────────────────────────────────────────────────────────────────

class _MemberRow extends StatefulWidget {
  const _MemberRow({
    required this.user,
    required this.permissions,
    required this.isMe,
    required this.onRemove,
    required this.onElevate,
    required this.onSuspend,
    required this.onDemote,
    required this.onRestore,
    required this.onTrash,
    required this.onPurge,
    required this.cs,
  });

  final UsersData user;
  final SystemPermissions permissions;
  final bool isMe;
  final VoidCallback onRemove;
  final VoidCallback onElevate;
  final VoidCallback onSuspend;
  final VoidCallback onDemote;
  final VoidCallback onRestore;
  final VoidCallback onTrash;
  final VoidCallback onPurge;
  final ColorScheme cs;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
    final isDark = cs.brightness == Brightness.dark;

    final rowBg = _isHovering
        ? cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.3)
        : isDark
        ? cs.surface
        : cs.surfaceContainerLowest;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? cs.outline.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onHover: (hovering) {
            if (isDesktop) setState(() => _isHovering = hovering);
          },
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openRolesSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── Avatar with status dot ───────────────────────────────
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
                        backgroundColor: rowBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // ── Name & phone ─────────────────────────────────────────
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

                const SizedBox(width: 8),

                // ── Actions ──────────────────────────────────────────────
                if (isDesktop)
                  _buildDesktopActions(cs)
                else
                  _buildMobileMenu(cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRolesSheet(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 480,
            child: _MemberRolesSheet(
              user: widget.user,
              permissions: widget.permissions,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MemberRolesSheet(
          user: widget.user,
          permissions: widget.permissions,
        ),
      );
    }
  }

  Widget _buildDesktopActions(ColorScheme cs) {
    final isSuper = widget.permissions.level == UserLevel.super_;
    final user = widget.user;
    final canSuspend =
        user.status != UserStatus.suspended &&
        user.status != UserStatus.deleted;
    final canRestore =
        user.status == UserStatus.suspended ||
        user.status == UserStatus.deleted;

    return IgnorePointer(
      ignoring: !_isHovering,
      child: AnimatedOpacity(
        opacity: _isHovering ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionIcon(
              icon: Icons.assignment_ind_outlined,
              tooltip: 'View roles',
              color: cs.onSurfaceVariant,
              onPressed: () => _openRolesSheet(context),
            ),
            _ActionIcon(
              icon: Icons.person_remove_outlined,
              tooltip: 'Remove from system',
              color: cs.onSurfaceVariant,
              onPressed: widget.onRemove,
            ),
            _ActionIcon(
              icon: Icons.arrow_upward_rounded,
              tooltip: 'Promote',
              color: cs.primary,
              onPressed: widget.onElevate,
            ),
            _ActionIcon(
              icon: Icons.arrow_downward_rounded,
              tooltip: 'Demote',
              color: cs.onSurfaceVariant,
              onPressed: widget.onDemote,
            ),
            if (canSuspend)
              _ActionIcon(
                icon: Icons.block_outlined,
                tooltip: 'Suspend',
                color: const Color(0xFFFFB300),
                onPressed: widget.onSuspend,
              ),
            if (canRestore)
              _ActionIcon(
                icon: Icons.restore_rounded,
                tooltip: 'Restore',
                color: Colors.teal,
                onPressed: widget.onRestore,
              ),
            _ActionIcon(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Trash',
              color: cs.onSurfaceVariant,
              onPressed: widget.onTrash,
            ),
            if (isSuper)
              _ActionIcon(
                icon: Icons.delete_forever_rounded,
                tooltip: 'Purge',
                color: cs.error,
                onPressed: widget.onPurge,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMenu(ColorScheme cs) {
    final isSuper = widget.permissions.level == UserLevel.super_;
    final user = widget.user;
    final canSuspend =
        user.status != UserStatus.suspended &&
        user.status != UserStatus.deleted;
    final canRestore =
        user.status == UserStatus.suspended ||
        user.status == UserStatus.deleted;

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
          case 'roles':
            _openRolesSheet(context);
          case 'remove':
            widget.onRemove();
          case 'elevate':
            widget.onElevate();
          case 'demote':
            widget.onDemote();
          case 'suspend':
            widget.onSuspend();
          case 'restore':
            widget.onRestore();
          case 'trash':
            widget.onTrash();
          case 'purge':
            widget.onPurge();
        }
      },
      itemBuilder: (context) => [
        _popupItem(
          'roles',
          Icons.assignment_ind_outlined,
          'View roles',
          cs.onSurface,
          cs,
        ),
        _popupItem(
          'remove',
          Icons.person_remove_outlined,
          'Remove',
          cs.onSurface,
          cs,
        ),
        _popupItem(
          'elevate',
          Icons.arrow_upward_rounded,
          'Promote',
          cs.primary,
          cs,
        ),
        _popupItem(
          'demote',
          Icons.arrow_downward_rounded,
          'Demote',
          cs.onSurfaceVariant,
          cs,
        ),
        if (canSuspend)
          _popupItem(
            'suspend',
            Icons.block_outlined,
            'Suspend',
            const Color(0xFFFFB300),
            cs,
          ),
        if (canRestore)
          _popupItem(
            'restore',
            Icons.restore_rounded,
            'Restore',
            Colors.teal,
            cs,
          ),
        _popupItem(
          'trash',
          Icons.delete_outline_rounded,
          'Trash',
          cs.onSurfaceVariant,
          cs,
        ),
        if (isSuper)
          _popupItem(
            'purge',
            Icons.delete_forever_rounded,
            'Purge',
            cs.error,
            cs,
          ),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
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
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 480,
            child: _AssignRoleSheet(
              user: widget.user,
              permissions: widget.permissions,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AssignRoleSheet(
          user: widget.user,
          permissions: widget.permissions,
        ),
      );
    }
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
// Action icon button (desktop hover)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 18,
      color: color,
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
              Icons.shield_outlined,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery
                  ? 'No members match your search.'
                  : 'No system members yet.',
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  padding: const EdgeInsets.only(bottom: 24),
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
