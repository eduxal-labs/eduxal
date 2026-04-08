import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import '../../../widgets/inline_date_picker_dialog.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/permissions.dart';
import '../../../../models/result.dart';
import '../../../../models/school_context.dart';
import '../../../../services/member_management.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';
import 'members_shared.dart';

class StaffTab extends StatefulWidget {
  const StaffTab({
    super.key,
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
  });

  final String schoolId;
  final MembersDao dao;
  final SchoolContext schoolContext;

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, UsersData>> _batchLoadUsers(
    List<StaffData> staffList,
  ) async {
    final userIds = staffList.map((s) => s.user).toSet().toList();
    if (userIds.isEmpty) return {};
    final users = await (db.select(
      db.users,
    )..where((t) => t.id.isIn(userIds))).get();
    return {for (final u in users) u.id: u};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffData>>(
      stream: widget.dao.watchStaff(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyTab(
            icon: Icons.badge_outlined,
            label: 'No staff yet',
            hint: 'Tap + to add a staff member.',
          );
        }
        return FutureBuilder<Map<String, UsersData>>(
          future: _batchLoadUsers(list),
          builder: (context, usersSnap) {
            final userMap = usersSnap.data ?? {};

            final filtered = _query.isEmpty
                ? list
                : list.where((s) {
                    final q = _query.toLowerCase();
                    final u = userMap[s.user];
                    if (u == null) return false;
                    return u.name.toLowerCase().contains(q) ||
                        u.phone.toLowerCase().contains(q) ||
                        (s.department?.toLowerCase().contains(q) ?? false) ||
                        (s.role?.toLowerCase().contains(q) ?? false);
                  }).toList();

            return FlatMemberList(
              searchController: _searchCtrl,
              searchHint: 'Search staff…',
              onSearchChanged: (v) => setState(() => _query = v.trim()),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                final user = userMap[s.user];
                final row = _StaffRow(
                  schoolId: widget.schoolId,
                  member: s,
                  user: user,
                  canDelete: _canDelete,
                  canEdit: _canEdit,
                );
                final isMobile = MediaQuery.sizeOf(context).width < 600;
                if (!isMobile || !_canDelete || user == null) return row;
                return Dismissible(
                  key: ValueKey('staff_${s.user}'),
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
                      message:
                          'This will remove the staff member from this school.',
                      confirmLabel: 'Remove',
                      isDestructive: true,
                    );
                    if (!confirmed || !context.mounted) return false;
                    final service = MemberManagementService(MembersDao(db));
                    final result = await service.removeStaff(
                      schoolId: widget.schoolId,
                      userId: user.id,
                    );
                    if (result case Err(:final error) when context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to remove staff member: $error',
                          ),
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
      },
    );
  }

  bool get _canDelete {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.staff, Action.delete);
  }

  bool get _canEdit {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.staff, Action.update);
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.schoolId,
    required this.member,
    required this.user,
    this.canDelete = true,
    this.canEdit = true,
  });
  final String schoolId;
  final StaffData member;
  final UsersData? user;
  final bool canDelete;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (member.department != null) parts.add(member.department!);
    if (member.role != null) parts.add(member.role!);

    return UserDataRow(
      userId: member.user,
      name: user?.name ?? '…',
      subtitle: parts.isNotEmpty ? parts.join('  ·  ') : (user?.phone ?? ''),
      status: user?.status,
      level: user?.level,
      trailing: member.status != StaffStatus.active
          ? SmallChip(
              label: member.status.name,
              cs: Theme.of(context).colorScheme,
            )
          : null,
      onTap: () {
        if (user == null) return;
        final w = MediaQuery.sizeOf(context).width;
        if (w >= 600) {
          _showStaffSideSheet(context, user!);
        } else {
          _showStaffBottomSheet(context, user!);
        }
      },
      actions: user == null || !canDelete
          ? const []
          : [
              RowAction(
                icon: Icons.person_remove_outlined,
                label: 'Remove',
                isDestructive: true,
                onTap: () => _confirmRemove(context, user!),
              ),
            ],
    );
  }

  void _showStaffBottomSheet(BuildContext context, UsersData user) {
    showEduSheet(
      context: context,
      builder: (_) => _StaffInfoSheet(
        user: user,
        member: member,
        schoolId: schoolId,
        canEdit: canEdit,
        canDelete: canDelete,
      ),
    );
  }

  void _showStaffSideSheet(BuildContext context, UsersData user) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: _StaffInfoSheet(
            user: user,
            member: member,
            schoolId: schoolId,
            canEdit: canEdit,
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

  Future<void> _confirmRemove(BuildContext context, UsersData user) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove "${user.name}"?',
      message: 'This will remove the staff member from this school.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final service = MemberManagementService(MembersDao(db));
    final result = await service.removeStaff(
      schoolId: schoolId,
      userId: user.id,
    );
    switch (result) {
      case Err(:final error) when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove staff: $error')),
        );
      default:
        break;
    }
  }
}

class _StaffInfoSheet extends StatelessWidget {
  const _StaffInfoSheet({
    required this.user,
    required this.member,
    required this.schoolId,
    this.canEdit = true,
    this.canDelete = true,
    this.isSideSheet = false,
  });

  final UsersData user;
  final StaffData member;
  final String schoolId;
  final bool canEdit;
  final bool canDelete;
  final bool isSideSheet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final service = MemberManagementService(MembersDao(db));

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

                // Email
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

                // Status dot + label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _staffStatusColor(member.status, cs),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      member.status.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _staffStatusColor(member.status, cs),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Detail rows
                if (member.role != null)
                  DetailRow(label: 'Role', value: member.role!, cs: cs),
                if (member.department != null)
                  DetailRow(
                    label: 'Department',
                    value: member.department!,
                    cs: cs,
                  ),
                if (member.idnumber != null)
                  DetailRow(
                    label: 'ID Number',
                    value: member.idnumber!,
                    cs: cs,
                  ),

                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.15 : 0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Grouped icon action buttons ──────────────────────
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                _ActionIconGroup(
                  actions: [
                    if (canEdit)
                      _ActionIconItem(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        color: cs.primary,
                        onTap: () => _showEditSheet(context, service),
                      ),
                    if (canEdit)
                      _ActionIconItem(
                        icon: Icons.exit_to_app_outlined,
                        tooltip: 'Resign',
                        color: Colors.orange,
                        onTap: () => _changeStatus(
                          context,
                          service,
                          StaffStatus.resigned,
                        ),
                      ),
                    if (canEdit)
                      _ActionIconItem(
                        icon: Icons.undo_outlined,
                        tooltip: 'Restore',
                        color: Colors.green,
                        onTap: () =>
                            _changeStatus(context, service, StaffStatus.active),
                      ),
                    if (canEdit)
                      _ActionIconItem(
                        icon: Icons.swap_horiz_outlined,
                        tooltip: 'Transfer',
                        color: cs.tertiary,
                        onTap: () => _changeStatus(
                          context,
                          service,
                          StaffStatus.transferred,
                        ),
                      ),
                    if (canEdit)
                      _ActionIconItem(
                        icon: Icons.block_outlined,
                        tooltip: 'Fired',
                        color: cs.error,
                        onTap: () =>
                            _changeStatus(context, service, StaffStatus.fired),
                      ),
                    if (canEdit)
                      _ActionIconItem(
                        icon: Icons.elderly_outlined,
                        tooltip: 'Retired',
                        color: cs.onSurfaceVariant,
                        onTap: () => _changeStatus(
                          context,
                          service,
                          StaffStatus.retired,
                        ),
                      ),
                    if (canDelete)
                      _ActionIconItem(
                        icon: Icons.person_remove_outlined,
                        tooltip: 'Remove',
                        color: cs.error,
                        onTap: () => _confirmRemove(context, service),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Color _staffStatusColor(StaffStatus status, ColorScheme cs) {
    return switch (status) {
      StaffStatus.active => Colors.green,
      StaffStatus.resigned => Colors.orange,
      StaffStatus.transferred => cs.tertiary,
      StaffStatus.fired => cs.error,
      StaffStatus.retired => cs.onSurfaceVariant,
    };
  }

  // ── Edit sheet ──────────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, MemberManagementService service) {
    final cs = Theme.of(context).colorScheme;
    final roleCtrl = TextEditingController(text: member.role ?? '');
    final deptCtrl = TextEditingController(text: member.department ?? '');
    final idCtrl = TextEditingController(text: member.idnumber ?? '');

    showEduSheet(
      context: context,
      title: 'Edit Staff',
      builder: (ctx) {
        final sheetCs = Theme.of(ctx).colorScheme;
        final sheetIsDark = sheetCs.brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(sheetIsDark, sheetCs),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kModalRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetCs.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    MediaQuery.viewInsetsOf(ctx).bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role field
                      TextField(
                        controller: roleCtrl,
                        style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Role',
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Department field
                      TextField(
                        controller: deptCtrl,
                        style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Department',
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ID Number field
                      TextField(
                        controller: idCtrl,
                        style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'ID Number',
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final role = roleCtrl.text.trim().isEmpty
                                ? null
                                : roleCtrl.text.trim();
                            final dept = deptCtrl.text.trim().isEmpty
                                ? null
                                : deptCtrl.text.trim();
                            final idNum = idCtrl.text.trim().isEmpty
                                ? null
                                : idCtrl.text.trim();

                            await service.updateStaff(
                              schoolId: schoolId,
                              userId: member.user,
                              role: role,
                              department: dept,
                              idNumber: idNum,
                            );

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Status change ───────────────────────────────────────────────────────

  void _changeStatus(
    BuildContext context,
    MemberManagementService service,
    StaffStatus status,
  ) async {
    await service.changeStaffStatus(
      schoolId: schoolId,
      userId: member.user,
      status: status,
    );
    if (context.mounted) Navigator.pop(context); // close sheet
  }

  // ── Remove confirmation ─────────────────────────────────────────────────

  void _confirmRemove(
    BuildContext context,
    MemberManagementService service,
  ) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove Staff',
      message:
          'Remove ${user.name} as staff from this school? '
          'This action can be undone by re-adding them.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    final result = await service.removeStaff(
      schoolId: schoolId,
      userId: member.user,
    );
    switch (result) {
      case Ok():
        if (context.mounted) Navigator.pop(context); // close sheet
      case Err(:final error):
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove staff member: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action icon widgets (local copies matching teachers_tab.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionIconItem {
  const _ActionIconItem({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
}

class _ActionIconGroup extends StatelessWidget {
  const _ActionIconGroup({required this.actions});
  final List<_ActionIconItem> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: actions.map((a) {
          return Tooltip(
            message: a.tooltip,
            child: InkWell(
              onTap: a.onTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: a.color.withValues(alpha: isDark ? 0.25 : 0.18),
                  ),
                ),
                child: Icon(
                  a.icon,
                  size: 16,
                  color: a.color.withValues(alpha: 0.75),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
