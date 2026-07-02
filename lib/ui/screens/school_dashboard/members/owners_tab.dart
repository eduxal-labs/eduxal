import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';

import '../../../../models/result.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';
import '../../../../services/member_management.dart';
import 'members_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Owners Tab
// ─────────────────────────────────────────────────────────────────────────────

class OwnersTab extends StatefulWidget {
  const OwnersTab({
    super.key,
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
  });

  final String schoolId;
  final MembersDao dao;
  final SchoolContext schoolContext;

  @override
  State<OwnersTab> createState() => _OwnersTabState();
}

class _OwnersTabState extends State<OwnersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Cached user map — stale-while-revalidate pattern to avoid FutureBuilder flicker.
  Map<String, UsersData>? _userMap;
  Set<String>? _lastUserIds;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Batch-load all users for a list of owner records in one pass.
  /// Updates [_userMap] via setState when complete.
  void _refreshUsersIfNeeded(List<OwnersData> owners) {
    final currentIds = owners.map((o) => o.user).toSet();
    if (_lastUserIds != null && _setEquals(currentIds, _lastUserIds!)) return;
    _lastUserIds = currentIds;
    if (currentIds.isEmpty) {
      _userMap = {};
      return;
    }
    (db.select(
      db.users,
    )..where((t) => t.id.isIn(currentIds.toList()))).get().then((users) {
      if (!mounted) return;
      setState(() {
        _userMap = {for (final u in users) u.id: u};
      });
    });
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OwnersData>>(
      stream: widget.dao.watchOwners(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LoadingIndicator();
        }
        final owners = snapshot.data ?? [];
        if (owners.isEmpty) {
          return const EmptyTab(
            icon: Icons.shield_outlined,
            label: 'No owners yet',
            hint: 'Tap + to add a school owner.',
          );
        }

        // Refresh user map only when member IDs change; show stale data while loading.
        _refreshUsersIfNeeded(owners);
        final userMap = _userMap ?? {};

        // Apply search filter using resolved user data
        final filtered = _query.isEmpty
            ? owners
            : owners.where((o) {
                final q = _query.toLowerCase();
                final u = userMap[o.user];
                if (u == null) return false;
                return u.name.toLowerCase().contains(q) ||
                    u.phone.toLowerCase().contains(q);
              }).toList();

        return FlatMemberList(
          searchController: _searchCtrl,
          searchHint: 'Search owners…',
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final owner = filtered[i];
            final user = userMap[owner.user];
            final currentUserId = cache.currentUser?.user.id;
            final isSelf = owner.user == currentUserId;
            final row = _OwnerRow(
              schoolId: widget.schoolId,
              owner: owner,
              user: user,
              canDelete: _canDelete && !isSelf,
            );
            final isMobile = MediaQuery.sizeOf(context).width < 600;
            if (!isMobile || !_canDelete || user == null || isSelf) return row;
            return Dismissible(
              key: ValueKey('owner_${owner.user}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Colors.red.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              confirmDismiss: (_) async {
                final confirmed = await showEduConfirmDialog(
                  context: context,
                  title: 'Remove "${user.name}"?',
                  message: 'This will remove the owner from this school.',
                  confirmLabel: 'Remove',
                  isDestructive: true,
                );
                if (!confirmed || !context.mounted) return false;
                final service = MemberManagementService(MembersDao(db));
                final result = await service.removeOwner(
                  schoolId: widget.schoolId,
                  userId: user.id,
                );
                if (!context.mounted) return false;
                switch (result) {
                  case Ok():
                    break;
                  case Err(error: PermissionDenied(:final reason)):
                    showPermissionDenied(context, reason);
                  case Err(:final error):
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to remove owner: $error'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                }
                return false; // Stream rebuild handles visual removal
              },
              child: row,
            );
          },
        );
      },
    );
  }

  bool get _canDelete {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.owners, Action.delete);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner Row
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({
    required this.schoolId,
    required this.owner,
    required this.user,
    this.canDelete = true,
  });
  final String schoolId;
  final OwnersData owner;
  final UsersData? user;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return UserDataRow(
      userId: owner.user,
      name: user?.name ?? '…',
      subtitle: user?.phone ?? '',
      status: user?.status,
      level: user?.level,
      onTap: () => _openDetail(context, user),
      actions: user == null || !canDelete
          ? const []
          : [
              RowAction(
                icon: Icons.person_remove_outlined,
                label: 'Remove',
                isDestructive: true,
                onTap: () => _confirmRemoveOwner(context, user!),
              ),
            ],
    );
  }

  void _openDetail(BuildContext context, UsersData? user) {
    if (user == null) return;
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) {
      _showOwnerSideSheet(context, user);
    } else {
      _showOwnerBottomSheet(context, user);
    }
  }

  void _showOwnerBottomSheet(BuildContext context, UsersData user) {
    showEduSheet(
      context: context,
      builder: (_) =>
          _OwnerInfoSheet(user: user, schoolId: schoolId, canDelete: canDelete),
    );
  }

  void _showOwnerSideSheet(BuildContext context, UsersData user) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: _OwnerInfoSheet(
            user: user,
            schoolId: schoolId,
            canDelete: canDelete,
            isSideSheet: true,
          ),
        );
      },
      transitionBuilder: (ctx, anim, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Future<void> _confirmRemoveOwner(BuildContext context, UsersData user) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove Owner',
      message:
          'Remove ${user.name} as an owner of this school? This action can be undone by re-adding them.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final service = MemberManagementService(MembersDao(db));
    final result = await service.removeOwner(
      schoolId: schoolId,
      userId: user.id,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${user.name}" removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Err(error: PermissionDenied(:final reason)):
        showPermissionDenied(context, reason);
      case Err(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove owner: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner Info Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerInfoSheet extends StatelessWidget {
  const _OwnerInfoSheet({
    required this.user,
    required this.schoolId,
    this.canDelete = true,
    this.isSideSheet = false,
  });

  final UsersData user;
  final String schoolId;
  final bool canDelete;
  final bool isSideSheet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF18222E) : cs.surface,
      borderRadius: isSideSheet
          ? const BorderRadius.horizontal(
              left: Radius.circular(AppTheme.kModalRadius),
            )
          : const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kModalRadius),
            ),
      child: SafeArea(
        top: isSideSheet,
        child: SizedBox(
          width: isSideSheet ? 380 : double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle (mobile only)
                if (!isSideSheet) ...[
                  Container(
                    width: 36,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],

                // Avatar
                UserAvatar(userId: user.id, radius: 36),
                const SizedBox(height: 14),

                // Name
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                // Phone
                Text(
                  user.phone,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),

                // Email (if available)
                if (user.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // Status only (NO level)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StatusIndicator.colorFor(user.status),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.status.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: StatusIndicator.colorFor(user.status),
                      ),
                    ),
                  ],
                ),

                if (canDelete) ...[
                  const SizedBox(height: 24),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.15 : 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OwnerAction(
                    icon: Icons.person_remove_outlined,
                    label: 'Remove from school',
                    color: cs.error,
                    onTap: () => _confirmRemoveOwner(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveOwner(BuildContext context) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove Owner',
      message:
          'Remove ${user.name} as an owner of this school? This action can be undone by re-adding them.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final service = MemberManagementService(MembersDao(db));
    final result = await service.removeOwner(
      schoolId: schoolId,
      userId: user.id,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context); // close sheet
      case Err(error: PermissionDenied(:final reason)):
        showPermissionDenied(context, reason);
      case Err(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove owner: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerAction extends StatelessWidget {
  const _OwnerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.25 : 0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
