import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/departments_dao.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_action_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../widgets/pressable_row.dart';
import 'members_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DepartmentsTab — list of departments for the school
// ─────────────────────────────────────────────────────────────────────────────

class DepartmentsTab extends StatefulWidget {
  const DepartmentsTab({
    super.key,
    required this.schoolId,
    required this.schoolContext,
  });
  final String schoolId;
  final SchoolContext schoolContext;

  @override
  State<DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<DepartmentsTab> {
  late final DepartmentsDao _dao;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _dao = DepartmentsDao(db);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Department>>(
      stream: _dao.watchDepartments(widget.schoolId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
        }
        final allDepts = snap.data!;
        if (allDepts.isEmpty) {
          return const EmptyTab(
            icon: Icons.domain_outlined,
            label: 'No departments',
            hint: 'Create one to organise teachers and staff.',
          );
        }

        // Apply search filter
        final depts = _query.isEmpty
            ? allDepts
            : allDepts.where((d) {
                final q = _query.toLowerCase();
                return d.name.toLowerCase().contains(q) ||
                    (d.description?.toLowerCase().contains(q) ?? false);
              }).toList();

        return Column(
          children: [
            // ── Search bar — consistent with other tabs ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SizedBox(
                height: 38,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search departments…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          child: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.2 : 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Department list ──────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 4, bottom: 80),
                itemCount: depts.length,
                separatorBuilder: (_, _) =>
                    AppTheme.tableRowDivider(isDark, cs),
                itemBuilder: (context, index) {
                  final dept = depts[index];
                  return _DepartmentRow(
                    dept: dept,
                    schoolId: widget.schoolId,
                    dao: _dao,
                    isDark: isDark,
                    cs: cs,
                    schoolContext: widget.schoolContext,
                    onDelete: _canDelete
                        ? () => _confirmDeleteDepartment(context, dept)
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _canDelete {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.departments, Action.delete);
  }

  Future<void> _confirmDeleteDepartment(
    BuildContext context,
    Department dept,
  ) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete "${dept.name}"?',
      message: 'This department will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final user = cache.currentUser?.user;
      if (user != null) {
        await guardedAction(context, () async {
          await _dao.deleteDepartment(
            widget.schoolId,
            dept.name,
            accountId: user.id,
          );
        });
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DepartmentRow — polished list item for departments tab
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentRow extends StatefulWidget {
  const _DepartmentRow({
    required this.dept,
    required this.schoolId,
    required this.dao,
    required this.isDark,
    required this.cs,
    required this.schoolContext,
    this.onDelete,
  });

  final Department dept;
  final String schoolId;
  final DepartmentsDao dao;
  final bool isDark;
  final ColorScheme cs;
  final SchoolContext schoolContext;
  final VoidCallback? onDelete;

  @override
  State<_DepartmentRow> createState() => _DepartmentRowState();
}

class _DepartmentRowState extends State<_DepartmentRow>
    with TickerProviderStateMixin, PressableRowMixin {
  bool _isHovered = false;

  void _navigate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DepartmentDetailScreen(
          dept: widget.dept,
          schoolId: widget.schoolId,
          dao: widget.dao,
          schoolContext: widget.schoolContext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final accentColor = cs.primary;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: buildPressable(
        onTap: () => _navigate(context),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered
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
                    // ── Accent bar ──────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHovered ? 4 : 3,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: _isHovered ? 1.0 : 0.5,
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
                            // ── Icon container ──────────────────
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _isHovered
                                    ? accentColor.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      )
                                    : isDark
                                    ? cs.surfaceContainerHighest.withValues(
                                        alpha: 0.5,
                                      )
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Icon(
                                Icons.domain_outlined,
                                size: 16,
                                color: _isHovered
                                    ? accentColor
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.55,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // ── Name + description ──────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.dept.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (widget.dept.description != null &&
                                      widget.dept.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        widget.dept.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: cs.onSurfaceVariant.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ── Delete action (desktop: inline; mobile: icon) ─
                            if (widget.onDelete != null && isDesktop)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 120),
                                opacity: _isHovered ? 1.0 : 0.0,
                                child: Tooltip(
                                  message: 'Delete',
                                  waitDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                  child: GestureDetector(
                                    onTap: widget.onDelete,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: cs.error,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (widget.onDelete != null && !isDesktop)
                              _DeptMobileMenu(onDelete: widget.onDelete!),

                            const SizedBox(width: 4),

                            // ── Chevron ─────────────────────────────
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              offset: Offset(_isHovered ? 0.15 : 0.0, 0),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isHovered ? 0.8 : 0.3,
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
    );
  }
}

/// Mobile three-dot menu for a department row — single delete action rendered
/// as a direct icon button (no bottom sheet, no extra wrapping).
class _DeptMobileMenu extends StatelessWidget {
  const _DeptMobileMenu({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(
          Icons.delete_outline_rounded,
          size: 16,
          color: cs.error.withValues(alpha: 0.7),
        ),
        tooltip: 'Delete',
        onPressed: onDelete,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DepartmentDetailScreen — detail view for a single department
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentDetailScreen extends StatefulWidget {
  const _DepartmentDetailScreen({
    required this.dept,
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
  });

  final Department dept;
  final String schoolId;
  final DepartmentsDao dao;
  final SchoolContext schoolContext;

  @override
  State<_DepartmentDetailScreen> createState() =>
      _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<_DepartmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  bool get _canDeleteDept {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.departments, Action.delete);
  }

  bool get _canUpdateDept {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.departments, Action.update);
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 26),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.dept.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        actions: [
          if (_canDeleteDept)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: cs.error.withValues(alpha: 0.7),
              ),
              tooltip: 'Delete department',
              onPressed: () => _confirmDelete(context),
            ),
          const SizedBox(width: 4),
        ],
        bottom: EduTabBarBottom(
          controller: _tab,
          isScrollable: true,
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 10),
          tabs: const [
            EduTab(label: 'All'),
            EduTab(label: 'Teachers'),
            EduTab(label: 'Staff'),
          ],
        ),
      ),
      floatingActionButton: _canUpdateDept
          ? FloatingActionButton.small(
              heroTag: 'fab_dept_detail_assign',
              onPressed: () => _showAssignMember(context),
              tooltip: 'Assign member',
              elevation: 4,
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, size: 20),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DeptAllMemberList(
            teacherStream: widget.dao.watchTeachersInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            staffStream: widget.dao.watchStaffInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            onRemoveTeacher: _canUpdateDept
                ? (userId) => _removeTeacher(userId)
                : null,
            onRemoveStaff: _canUpdateDept
                ? (userId) => _removeStaff(userId)
                : null,
          ),
          _DeptMemberList<({TeachersData teacher, UsersData user})>(
            stream: widget.dao.watchTeachersInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            emptyLabel: 'No teachers assigned',
            nameOf: (item) => item.user.name,
            statusOf: (item) => item.teacher.status.name,
            onRemove: _canUpdateDept
                ? (item) => _removeTeacher(item.teacher.user)
                : null,
          ),
          _DeptMemberList<({StaffData staff, UsersData user})>(
            stream: widget.dao.watchStaffInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            emptyLabel: 'No staff assigned',
            nameOf: (item) => item.user.name,
            statusOf: (item) => item.staff.status.name,
            onRemove: _canUpdateDept
                ? (item) => _removeStaff(item.staff.user)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete "${widget.dept.name}"?',
      message: 'This department will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final user = cache.currentUser?.user;
      if (user != null) {
        bool deleted = false;
        await guardedAction(context, () async {
          await widget.dao.deleteDepartment(
            widget.schoolId,
            widget.dept.name,
            accountId: user.id,
          );
          deleted = true;
        });
        if (deleted && context.mounted) Navigator.pop(context);
      }
    }
  }

  void _showAssignMember(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeCtx) => _AssignMemberSearchSheet(
          schoolId: widget.schoolId,
          deptName: widget.dept.name,
          dao: widget.dao,
          onDone: () => Navigator.of(routeCtx).pop(),
        ),
      ),
    );
  }

  Future<void> _removeTeacher(String teacherUserId) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await guardedAction(context, () async {
      await widget.dao.assignTeacherToDepartment(
        widget.schoolId,
        teacherUserId,
        departmentName: null,
        accountId: user.id,
      );
    });
  }

  Future<void> _removeStaff(String staffUserId) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await guardedAction(context, () async {
      await widget.dao.assignStaffToDepartment(
        widget.schoolId,
        staffUserId,
        departmentName: null,
        accountId: user.id,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DeptAllMemberList — combined teachers + staff list
// ─────────────────────────────────────────────────────────────────────────────

class _DeptAllMemberList extends StatelessWidget {
  const _DeptAllMemberList({
    required this.teacherStream,
    required this.staffStream,
    this.onRemoveTeacher,
    this.onRemoveStaff,
  });

  final Stream<List<({TeachersData teacher, UsersData user})>> teacherStream;
  final Stream<List<({StaffData staff, UsersData user})>> staffStream;
  final Future<void> Function(String userId)? onRemoveTeacher;
  final Future<void> Function(String userId)? onRemoveStaff;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<({TeachersData teacher, UsersData user})>>(
      stream: teacherStream,
      builder: (context, teacherSnap) {
        return StreamBuilder<List<({StaffData staff, UsersData user})>>(
          stream: staffStream,
          builder: (context, staffSnap) {
            final teachers = teacherSnap.data ?? [];
            final staffMembers = staffSnap.data ?? [];

            // Build combined list with role tag
            final List<_DeptAllItem> combined = [
              ...teachers.map(
                (t) => _DeptAllItem(
                  name: t.user.name,
                  statusLabel: t.teacher.status.name,
                  roleTag: 'Teacher',
                  onRemove: onRemoveTeacher != null
                      ? () async => onRemoveTeacher!(t.teacher.user)
                      : null,
                ),
              ),
              ...staffMembers.map(
                (s) => _DeptAllItem(
                  name: s.user.name,
                  statusLabel: s.staff.status.name,
                  roleTag: 'Staff',
                  onRemove: onRemoveStaff != null
                      ? () async => onRemoveStaff!(s.staff.user)
                      : null,
                ),
              ),
            ];

            if (combined.isEmpty) {
              return Center(
                child: Text(
                  'No members assigned',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: combined.length,
              itemBuilder: (_, i) => combined[i],
            );
          },
        );
      },
    );
  }
}

class _DeptAllItem extends StatefulWidget {
  const _DeptAllItem({
    required this.name,
    required this.statusLabel,
    required this.roleTag,
    this.onRemove,
  });

  final String name;
  final String statusLabel;
  final String roleTag;
  final Future<void> Function()? onRemove;

  @override
  State<_DeptAllItem> createState() => _DeptAllItemState();
}

class _DeptAllItemState extends State<_DeptAllItem>
    with TickerProviderStateMixin, PressableRowMixin {
  bool _isHovered = false;

  Color _roleColor(ColorScheme cs) {
    return widget.roleTag == 'Teacher' ? cs.primary : cs.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final roleClr = _roleColor(cs);

    final idleBg = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
        : cs.surfaceContainerHighest.withValues(alpha: 0.25);
    final hoverBg = isDark
        ? roleClr.withValues(alpha: 0.10)
        : roleClr.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: buildPressable(
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered
                    ? roleClr.withValues(alpha: isDark ? 0.30 : 0.20)
                    : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Accent bar ──────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHovered ? 4 : 3,
                      decoration: BoxDecoration(
                        color: roleClr.withValues(
                          alpha: _isHovered ? 1.0 : 0.5,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),

                    // ── Content ─────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Row(
                          children: [
                            // ── Person icon ─────────────────────
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: roleClr.withValues(
                                  alpha: isDark ? 0.15 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: roleClr.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // ── Name + status ───────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      widget.statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // ── Role tag chip ───────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleClr.withValues(
                                  alpha: isDark ? 0.15 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Text(
                                widget.roleTag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: roleClr,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // ── Remove button (permission-gated) ─
                            if (widget.onRemove != null)
                              AnimatedActionButton(
                                icon: Icons.close_rounded,
                                iconSize: 15,
                                color: _isHovered
                                    ? cs.error.withValues(alpha: 0.7)
                                    : cs.error.withValues(alpha: 0.4),
                                size: 28,
                                tooltip: 'Remove',
                                showCheckOnSuccess: false,
                                onTap: widget.onRemove!,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DeptMemberList — generic single-role member list (Teachers or Staff tab)
// ─────────────────────────────────────────────────────────────────────────────

class _DeptMemberList<T> extends StatelessWidget {
  const _DeptMemberList({
    required this.stream,
    required this.emptyLabel,
    required this.nameOf,
    required this.statusOf,
    this.onRemove,
  });

  final Stream<List<T>> stream;
  final String emptyLabel;
  final String Function(T) nameOf;
  final String Function(T) statusOf;
  final Future<void> Function(T)? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Text(
                '${items.length} member${items.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    emptyLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _DeptMemberRow(
                      name: nameOf(item),
                      statusLabel: statusOf(item),
                      onRemove: onRemove != null
                          ? () async => onRemove!(item)
                          : null,
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
// _DeptMemberRow — individual member row inside department detail
// ─────────────────────────────────────────────────────────────────────────────

class _DeptMemberRow extends StatefulWidget {
  const _DeptMemberRow({
    required this.name,
    required this.statusLabel,
    this.onRemove,
  });

  final String name;
  final String statusLabel;
  final Future<void> Function()? onRemove;

  @override
  State<_DeptMemberRow> createState() => _DeptMemberRowState();
}

class _DeptMemberRowState extends State<_DeptMemberRow>
    with TickerProviderStateMixin, PressableRowMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accentColor = cs.primary;

    final idleBg = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
        : cs.surfaceContainerHighest.withValues(alpha: 0.25);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.10)
        : accentColor.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: buildPressable(
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered
                    ? accentColor.withValues(alpha: isDark ? 0.30 : 0.20)
                    : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Accent bar ──────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHovered ? 4 : 3,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: _isHovered ? 1.0 : 0.5,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),

                    // ── Content ─────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Row(
                          children: [
                            // ── Person icon ─────────────────────
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _isHovered
                                    ? accentColor.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      )
                                    : accentColor.withValues(
                                        alpha: isDark ? 0.12 : 0.06,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: _isHovered
                                    ? accentColor
                                    : accentColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // ── Name + status ───────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.statusLabel.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text(
                                        widget.statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                          color: cs.onSurfaceVariant.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // ── Remove button (permission-gated) ─
                            if (widget.onRemove != null)
                              AnimatedActionButton(
                                icon: Icons.close_rounded,
                                iconSize: 15,
                                color: _isHovered
                                    ? cs.error.withValues(alpha: 0.7)
                                    : cs.error.withValues(alpha: 0.4),
                                size: 28,
                                tooltip: 'Remove',
                                showCheckOnSuccess: false,
                                onTap: widget.onRemove!,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AssignMemberSearchSheet — picks from unassigned teachers/staff
// ─────────────────────────────────────────────────────────────────────────────

class _AssignMemberSearchSheet extends StatefulWidget {
  const _AssignMemberSearchSheet({
    required this.schoolId,
    required this.deptName,
    required this.dao,
    required this.onDone,
  });

  final String schoolId;
  final String deptName;
  final DepartmentsDao dao;
  final VoidCallback onDone;

  @override
  State<_AssignMemberSearchSheet> createState() =>
      _AssignMemberSearchSheetState();
}

class _AssignMemberSearchSheetState extends State<_AssignMemberSearchSheet> {
  final _searchCtrl = TextEditingController();
  bool _showTeachers = true; // true = teachers, false = staff
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Assign Member',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: TextStyle(fontSize: 13.5, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            // Toggle: Teachers / Staff
            Row(
              children: [
                _DeptFilterChip(
                  label: 'Teachers',
                  selected: _showTeachers,
                  onTap: () => setState(() => _showTeachers = true),
                ),
                const SizedBox(width: 6),
                _DeptFilterChip(
                  label: 'Staff',
                  selected: !_showTeachers,
                  onTap: () => setState(() => _showTeachers = false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // List
            Expanded(
              child: _showTeachers
                  ? _buildTeacherList(cs, isDark)
                  : _buildStaffList(cs, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherList(ColorScheme cs, bool isDark) {
    return StreamBuilder<List<({TeachersData teacher, UsersData user})>>(
      stream: widget.dao.watchUnassignedTeachers(widget.schoolId),
      builder: (context, snap) {
        final items = (snap.data ?? []).where((item) {
          if (_query.isEmpty) return true;
          return item.user.name.toLowerCase().contains(_query) ||
              item.user.phone.toLowerCase().contains(_query);
        }).toList();
        return _buildItemList(
          items: items,
          nameOf: (item) => item.user.name,
          phoneOf: (item) => item.user.phone,
          onTap: (item) async {
            final user = cache.currentUser?.user;
            if (user == null) return;
            await widget.dao.assignTeacherToDepartment(
              widget.schoolId,
              item.teacher.user,
              departmentName: widget.deptName,
              accountId: user.id,
            );
            widget.onDone();
          },
          cs: cs,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildStaffList(ColorScheme cs, bool isDark) {
    return StreamBuilder<List<({StaffData staff, UsersData user})>>(
      stream: widget.dao.watchUnassignedStaff(widget.schoolId),
      builder: (context, snap) {
        final items = (snap.data ?? []).where((item) {
          if (_query.isEmpty) return true;
          return item.user.name.toLowerCase().contains(_query) ||
              item.user.phone.toLowerCase().contains(_query);
        }).toList();
        return _buildItemList(
          items: items,
          nameOf: (item) => item.user.name,
          phoneOf: (item) => item.user.phone,
          onTap: (item) async {
            final user = cache.currentUser?.user;
            if (user == null) return;
            await widget.dao.assignStaffToDepartment(
              widget.schoolId,
              item.staff.user,
              departmentName: widget.deptName,
              accountId: user.id,
            );
            widget.onDone();
          },
          cs: cs,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildItemList<T>({
    required List<T> items,
    required String Function(T) nameOf,
    required String Function(T) phoneOf,
    required Future<void> Function(T) onTap,
    required ColorScheme cs,
    required bool isDark,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No unassigned members found.',
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                : cs.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: () => onTap(item),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameOf(item),
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                    Text(
                      phoneOf(item),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Small filter chip for Teachers/Staff toggle in assign sheet
class _DeptFilterChip extends StatelessWidget {
  const _DeptFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.10)
              : isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
              : cs.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: isDark ? 0.5 : 0.4)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CreateDepartmentSheet — bottom sheet for creating a new department
// ─────────────────────────────────────────────────────────────────────────────

class CreateDepartmentSheet extends StatefulWidget {
  const CreateDepartmentSheet({
    super.key,
    required this.schoolId,
    required this.dao,
  });
  final String schoolId;
  final DepartmentsDao dao;

  @override
  State<CreateDepartmentSheet> createState() => _CreateDepartmentSheetState();
}

class _CreateDepartmentSheetState extends State<CreateDepartmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = cache.currentUser?.user;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    // Check for duplicate department name before creating.
    final trimmedName = _nameCtrl.text.trim();
    final existing = await widget.dao.getDepartment(
      widget.schoolId,
      trimmedName,
    );
    if (existing != null) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A department named "$trimmedName" already exists.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.createDepartment(
        DepartmentsCompanion(
          school: Value(widget.schoolId),
          name: Value(trimmedName),
          description: Value(
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          ),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        accountId: user.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create department: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Scrollable form content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EduFormField(
                      controller: _nameCtrl,
                      label: 'Department name',
                      hint: 'e.g. Mathematics',
                      autofocus: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    EduFormField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Optional',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // ── Cancel ──────────────────────────────────────────
                        Tooltip(
                          message: 'Cancel',
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // ── Save ────────────────────────────────────────────
                        Tooltip(
                          message: 'Save',
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                              style: IconButton.styleFrom(
                                backgroundColor: _saving
                                    ? Colors.green.shade600.withValues(
                                        alpha: 0.6,
                                      )
                                    : Colors.green.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.kCardRadius,
                                  ),
                                ),
                              ),
                              onPressed: _saving ? null : _save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
