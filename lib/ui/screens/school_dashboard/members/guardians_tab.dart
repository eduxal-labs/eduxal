import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import '../../../../client.dart';
import '../../../widgets/permission_denied_handler.dart';
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
import '../../../widgets/student_avatar.dart';
import '../../../widgets/user_avatar.dart';
import 'student_detail_page.dart';
import 'members_shared.dart';

class GuardiansTab extends StatefulWidget {
  const GuardiansTab({
    super.key,
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
  });

  final String schoolId;
  final MembersDao dao;
  final SchoolContext schoolContext;

  @override
  State<GuardiansTab> createState() => _GuardiansTabState();
}

class _GuardiansTabState extends State<GuardiansTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _canEditGuardian {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.students, Action.update);
  }

  bool get _canUnlinkGuardian {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.students, Action.unassign);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<({UsersData user, int wardCount})>>(
      stream: widget.dao.watchUniqueGuardians(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyTab(
            icon: Icons.family_restroom_outlined,
            label: 'No guardians yet',
            hint: 'Link a guardian from a student\'s profile, or tap +.',
          );
        }

        // Apply search filter by name or phone
        final filtered = _query.isEmpty
            ? list
            : list.where((item) {
                final q = _query.toLowerCase();
                return item.user.name.toLowerCase().contains(q) ||
                    item.user.phone.toLowerCase().contains(q);
              }).toList();

        return FlatMemberList(
          searchController: _searchCtrl,
          searchHint: 'Search by name or phone…',
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final item = filtered[i];
            final row = _UniqueGuardianRow(
              schoolId: widget.schoolId,
              user: item.user,
              wardCount: item.wardCount,
              canEditGuardian: _canEditGuardian,
              canUnlinkGuardian: _canUnlinkGuardian,
            );
            final isMobile = MediaQuery.sizeOf(context).width < 600;
            if (!isMobile || !_canUnlinkGuardian) return row;
            return Dismissible(
              key: ValueKey('guardian_${item.user.id}'),
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
                // For guardians with multiple wards, open the detail sheet
                // instead of dismissing — the user must unlink per-ward.
                if (item.wardCount > 1) {
                  if (context.mounted) {
                    final w = MediaQuery.sizeOf(context).width;
                    if (w >= 600) {
                      // Won't reach here (isMobile guard above), but defensive
                      return false;
                    }
                    showEduSheet(
                      context: context,
                      builder: (_) => _GuardianWardsSheet(
                        user: item.user,
                        schoolId: widget.schoolId,
                        canEditGuardian: _canEditGuardian,
                        canUnlinkGuardian: _canUnlinkGuardian,
                      ),
                    );
                  }
                  return false;
                }
                final confirmed = await showEduConfirmDialog(
                  context: context,
                  title: 'Remove "${item.user.name}"?',
                  message:
                      'This will remove the guardian link from this school.',
                  confirmLabel: 'Remove',
                  isDestructive: true,
                );
                if (!confirmed) return false;
                // For single-ward guardians, open detail to handle unlink
                // (guardian removal requires knowing the specific ward)
                if (context.mounted) {
                  showEduSheet(
                    context: context,
                    builder: (_) => _GuardianWardsSheet(
                      user: item.user,
                      schoolId: widget.schoolId,
                      canEditGuardian: _canEditGuardian,
                      canUnlinkGuardian: _canUnlinkGuardian,
                    ),
                  );
                }
                return false;
              },
              child: row,
            );
          },
        );
      },
    );
  }
}

class _UniqueGuardianRow extends StatelessWidget {
  const _UniqueGuardianRow({
    required this.schoolId,
    required this.user,
    required this.wardCount,
    this.canEditGuardian = true,
    this.canUnlinkGuardian = true,
  });

  final String schoolId;
  final UsersData user;
  final int wardCount;
  final bool canEditGuardian;
  final bool canUnlinkGuardian;

  @override
  Widget build(BuildContext context) {
    return UserDataRow(
      userId: user.id,
      name: user.name,
      subtitle: '$wardCount ward${wardCount == 1 ? '' : 's'}',
      status: user.status,
      level: user.level,
      onTap: () => _openDetail(context),
      actions: const [],
    );
  }

  void _openDetail(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) {
      _showGuardianSideSheet(context);
    } else {
      _showGuardianBottomSheet(context);
    }
  }

  void _showGuardianBottomSheet(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (_) => _GuardianWardsSheet(
        user: user,
        schoolId: schoolId,
        canEditGuardian: canEditGuardian,
        canUnlinkGuardian: canUnlinkGuardian,
      ),
    );
  }

  void _showGuardianSideSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: _GuardianWardsSheet(
            user: user,
            schoolId: schoolId,
            canEditGuardian: canEditGuardian,
            canUnlinkGuardian: canUnlinkGuardian,
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
}

class _GuardianWardsSheet extends StatelessWidget {
  const _GuardianWardsSheet({
    required this.user,
    required this.schoolId,
    this.canEditGuardian = true,
    this.canUnlinkGuardian = true,
    this.isSideSheet = false,
  });

  final UsersData user;
  final String schoolId;
  final bool canEditGuardian;
  final bool canUnlinkGuardian;
  final bool isSideSheet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final dao = MembersDao(db);
    final service = MemberManagementService(dao);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSideSheet) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: 36,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
              // Guardian header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    UserAvatar(userId: user.id, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          if (user.email != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              user.email!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status indicator
                    StatusIndicator(
                      status: user.status,
                      level: user.level,
                      backgroundColor: isDark
                          ? const Color(0xFF18222E)
                          : cs.surface,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.3),
              ),
              // Ward list header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Wards',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              // Reactive ward list
              Flexible(
                child:
                    StreamBuilder<
                      List<({GuardiansData guardian, StudentsData? student})>
                    >(
                      stream: dao.watchGuardianWards(schoolId, user.id),
                      builder: (context, snap) {
                        final wards = snap.data ?? [];
                        if (wards.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No wards linked.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: wards.length,
                          itemBuilder: (context, i) {
                            final ward = wards[i];
                            return _WardItem(
                              guardian: ward.guardian,
                              student: ward.student,
                              schoolId: schoolId,
                              service: service,
                              cs: cs,
                              isDark: isDark,
                              canEdit: canEditGuardian,
                              canUnlink: canUnlinkGuardian,
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ward item (inside guardian ward sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _WardItem extends StatelessWidget {
  const _WardItem({
    required this.guardian,
    required this.student,
    required this.schoolId,
    required this.service,
    required this.cs,
    required this.isDark,
    this.canEdit = true,
    this.canUnlink = true,
  });

  final GuardiansData guardian;
  final StudentsData? student;
  final String schoolId;
  final MemberManagementService service;
  final ColorScheme cs;
  final bool isDark;
  final bool canEdit;
  final bool canUnlink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Student (ward) avatar
              if (student != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: StudentAvatar(
                    schoolId: schoolId,
                    adm: student!.adm,
                    name: student!.name,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student?.name ?? 'Unknown Student',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${guardian.relationship.name}  ·  ${guardian.role.name}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button (permission-gated)
              if (canEdit)
                InkWell(
                  onTap: () => _editGuardianLink(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: cs.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              if (canEdit) const SizedBox(width: 4),
              // Unlink button (permission-gated)
              if (canUnlink)
                InkWell(
                  onTap: () => _unlinkGuardian(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.link_off_outlined,
                      size: 15,
                      color: cs.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _editGuardianLink(BuildContext context) {
    final isDarkLocal = cs.brightness == Brightness.dark;

    var selectedRelationship = guardian.relationship;
    var selectedRole = guardian.role;

    showEduSheet(
      context: context,
      title: 'Edit Guardian',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
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
                        // Relationship dropdown
                        Text(
                          'Relationship',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<GuardianRelationship>(
                              value: selectedRelationship,
                              isExpanded: true,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: cs.onSurface,
                              ),
                              dropdownColor: isDarkLocal
                                  ? const Color(0xFF18222E)
                                  : cs.surface,
                              items: GuardianRelationship.values
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setSheetState(() => selectedRelationship = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Role dropdown
                        Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<GuardianRole>(
                              value: selectedRole,
                              isExpanded: true,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: cs.onSurface,
                              ),
                              dropdownColor: isDarkLocal
                                  ? const Color(0xFF18222E)
                                  : cs.surface,
                              items: GuardianRole.values
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setSheetState(() => selectedRole = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              final relChanged =
                                  selectedRelationship != guardian.relationship;
                              final roleChanged = selectedRole != guardian.role;

                              if (!relChanged && !roleChanged) {
                                Navigator.pop(ctx);
                                return;
                              }

                              await service.updateGuardian(
                                schoolId: schoolId,
                                userId: guardian.user,
                                studentAdm: guardian.student,
                                relationship: relChanged
                                    ? selectedRelationship
                                    : null,
                                role: roleChanged ? selectedRole : null,
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
      ),
    );
  }

  void _unlinkGuardian(BuildContext context) async {
    final wardName = student?.name ?? 'this student';
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Unlink Guardian',
      message: 'Remove guardian link to $wardName?',
      confirmLabel: 'Unlink',
      isDestructive: true,
    );
    if (!confirmed) return;

    final result = await service.removeGuardian(
      schoolId: schoolId,
      userId: guardian.user,
      studentAdm: guardian.student,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        break;
      case Err(error: PermissionDenied(:final reason)):
        showPermissionDenied(context, reason);
      case Err(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlink guardian: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
