import 'dart:async';
import 'package:flutter/material.dart' hide Action;
import '../../../widgets/inline_date_picker_dialog.dart';
import '../../../widgets/permission_denied_handler.dart';

import '../../../../database/database.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/curriculum_levels.dart';
import '../../../../models/school_config.dart';
import '../../../../models/permissions.dart';
import '../../../../models/result.dart';
import '../../../../models/school_context.dart';
import '../../../../services/member_management.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/user_avatar.dart';
import 'members_shared.dart';
import 'teacher_excel_import_sheet.dart';

class TeachersTab extends StatefulWidget {
  const TeachersTab({
    super.key,
    required this.schoolId,
    required this.dao,
    required this.schoolContext,
  });

  final String schoolId;
  final MembersDao dao;
  final SchoolContext schoolContext;

  @override
  State<TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<TeachersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Cached user data — eliminates FutureBuilder flickering on stream emissions.
  Map<String, UsersData> _userMap = {};
  Set<String> _lastUserIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Batch-load all users for a list of teacher records in one pass.
  /// Only re-fetches when the set of user IDs actually changes.
  void _refreshUsers(List<TeachersData> teachers) {
    final currentIds = teachers.map((t) => t.user).toSet();
    if (currentIds.length == _lastUserIds.length &&
        currentIds.containsAll(_lastUserIds)) {
      return; // ID set unchanged — keep cached _userMap
    }
    _lastUserIds = currentIds;
    final userIds = currentIds.toList();
    if (userIds.isEmpty) {
      _userMap = {};
      return;
    }
    // Fire async fetch; stale _userMap is shown until this completes.
    (db.select(db.users)..where((t) => t.id.isIn(userIds))).get().then((users) {
      if (!mounted) return;
      setState(() {
        _userMap = {for (final u in users) u.id: u};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeachersData>>(
      stream: widget.dao.watchTeachers(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const EmptyTab(
            icon: Icons.school_outlined,
            label: 'No teachers yet',
            hint: 'Tap + to add a teacher.',
          );
        }

        // Refresh user cache only when member IDs change.
        _refreshUsers(list);
        final userMap = _userMap;

        final filtered = _query.isEmpty
            ? list
            : list.where((t) {
                final q = _query.toLowerCase();
                final u = userMap[t.user];
                if (u == null) return false;
                return u.name.toLowerCase().contains(q) ||
                    u.phone.toLowerCase().contains(q) ||
                    (t.department?.toLowerCase().contains(q) ?? false) ||
                    (t.role?.toLowerCase().contains(q) ?? false);
              }).toList();

        return FlatMemberList(
          searchController: _searchCtrl,
          searchHint: 'Search teachers…',
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          searchActions: [
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Import from Excel',
              onPressed: () {
                showEduSheet(
                  context: context,
                  builder: (ctx) => TeacherExcelImportSheet(
                    schoolId: widget.schoolId,
                  ),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final t = filtered[i];
            final user = userMap[t.user];
            final row = _TeacherRow(
              schoolId: widget.schoolId,
              teacher: t,
              user: user,
              canDelete: _canDelete,
              canEdit: _canEdit,
            );
            final isMobile = MediaQuery.sizeOf(context).width < 600;
            if (!isMobile || !_canDelete || user == null) return row;
            return Dismissible(
              key: ValueKey('teacher_${t.user}'),
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
                  message: 'This will remove the teacher from this school.',
                  confirmLabel: 'Remove',
                  isDestructive: true,
                );
                if (!confirmed || !context.mounted) return false;
                final service = MemberManagementService(MembersDao(db));
                final result = await service.removeTeacher(
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
                        content: Text('Failed to remove teacher: $error'),
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
    return perms.can(Resource.teachers, Action.delete);
  }

  bool get _canEdit {
    final perms = widget.schoolContext.permissions;
    return perms.can(Resource.teachers, Action.update);
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({
    required this.schoolId,
    required this.teacher,
    required this.user,
    this.canDelete = true,
    this.canEdit = true,
  });
  final String schoolId;
  final TeachersData teacher;
  final UsersData? user;
  final bool canDelete;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (teacher.department != null) parts.add(teacher.department!);
    if (teacher.role != null) parts.add(teacher.role!);

    return UserDataRow(
      userId: teacher.user,
      name: user?.name ?? '…',
      subtitle: parts.isNotEmpty ? parts.join('  ·  ') : (user?.phone ?? ''),
      status: user?.status,
      level: user?.level,
      trailing: teacher.status != TeacherStatus.active
          ? SmallChip(
              label: teacher.status.name,
              cs: Theme.of(context).colorScheme,
            )
          : null,
      onTap: () {
        if (user == null) return;
        final w = MediaQuery.sizeOf(context).width;
        if (w >= 600) {
          _showTeacherSideSheet(context, user!);
        } else {
          _showTeacherBottomSheet(context, user!);
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

  void _showTeacherBottomSheet(BuildContext context, UsersData user) {
    showEduSheet(
      context: context,
      builder: (_) => _TeacherInfoSheet(
        user: user,
        teacher: teacher,
        schoolId: schoolId,
        canEdit: canEdit,
        canDelete: canDelete,
      ),
    );
  }

  void _showTeacherSideSheet(BuildContext context, UsersData user) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: _TeacherInfoSheet(
            user: user,
            teacher: teacher,
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
      message: 'This will remove the teacher from this school.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final service = MemberManagementService(MembersDao(db));
    final result = await service.removeTeacher(
      schoolId: schoolId,
      userId: user.id,
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        break;
      case Err(error: PermissionDenied(:final reason)):
        showPermissionDenied(context, reason);
      case Err(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove teacher: $error')),
        );
    }
  }
}

class _TeacherInfoSheet extends StatefulWidget {
  const _TeacherInfoSheet({
    required this.user,
    required this.teacher,
    required this.schoolId,
    this.canEdit = true,
    this.canDelete = true,
    this.isSideSheet = false,
  });

  final UsersData user;
  final TeachersData teacher;
  final String schoolId;
  final bool canEdit;
  final bool canDelete;
  final bool isSideSheet;

  @override
  State<_TeacherInfoSheet> createState() => _TeacherInfoSheetState();
}

class _TeacherInfoSheetState extends State<_TeacherInfoSheet> {
  late final MembersDao _dao;
  late final MemberManagementService _service;
  CurriculumType? _curriculumType;
  bool _classTeacherExpanded = false;
  bool _subjectsExpanded = false;

  UsersData get user => widget.user;
  TeachersData get teacher => widget.teacher;
  String get schoolId => widget.schoolId;
  bool get isSideSheet => widget.isSideSheet;

  @override
  void initState() {
    super.initState();
    _dao = MembersDao(db);
    _service = MemberManagementService(_dao);
    _loadCurriculum();
  }

  Future<void> _loadCurriculum() async {
    // TODO: reload curriculum from new settings source when available
    return;
  }

  String _subjectName(int subjectIndex) {
    if (_curriculumType == null) return 'Subject $subjectIndex';
    return subjectLabel(_curriculumType!, subjectIndex);
  }

  String _gradeLabel(int grade) {
    if (_curriculumType == null) return 'Grade $grade';
    final labels = gradeLabelsFor(_curriculumType!);
    return labels[grade] ?? 'Grade $grade';
  }

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
                        color: _teacherStatusColor(teacher.status, cs),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      teacher.status.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _teacherStatusColor(teacher.status, cs),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Detail rows
                if (teacher.role != null)
                  DetailRow(label: 'Role', value: teacher.role!, cs: cs),
                if (teacher.department != null)
                  DetailRow(
                    label: 'Department',
                    value: teacher.department!,
                    cs: cs,
                  ),
                if (teacher.hired != null)
                  DetailRow(
                    label: 'Hired',
                    value: _formatHiredDate(teacher.hired) ?? '—',
                    cs: cs,
                  ),

                // ── Class teacher assignments ────────────────────────
                _buildCollapsibleSection(
                  cs: cs,
                  isDark: isDark,
                  icon: Icons.school_outlined,
                  title: 'Class Teacher',
                  expanded: _classTeacherExpanded,
                  onToggle: () => setState(
                    () => _classTeacherExpanded = !_classTeacherExpanded,
                  ),
                  child: StreamBuilder<List<ClassTeacher>>(
                    stream: _dao.watchClassTeacherAssignments(
                      schoolId,
                      teacher.user,
                    ),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'Not assigned as class teacher',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: items.map((ct) {
                          final label =
                              '${_gradeLabel(ct.grade)} · S${ct.stream}'
                              ' (${ct.year} T${ct.term})';
                          return _AssignmentChip(label: label, cs: cs);
                        }).toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),

                // ── Subject assignments ──────────────────────────────
                _buildCollapsibleSection(
                  cs: cs,
                  isDark: isDark,
                  icon: Icons.menu_book_outlined,
                  title: 'Subjects',
                  expanded: _subjectsExpanded,
                  onToggle: () =>
                      setState(() => _subjectsExpanded = !_subjectsExpanded),
                  child: StreamBuilder<List<SubjectTeacher>>(
                    stream: _dao.watchTeacherSubjects(schoolId, teacher.user),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'No subjects assigned',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      // Group subjects by (year, term, grade, stream)
                      final grouped = <String, List<SubjectTeacher>>{};
                      for (final s in items) {
                        final key =
                            '${s.year}|${s.term}|${s.grade}|${s.stream}';
                        grouped.putIfAbsent(key, () => []).add(s);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: grouped.entries.map((entry) {
                          final first = entry.value.first;
                          final header =
                              '${_gradeLabel(first.grade)} · S${first.stream}'
                              ' (${first.year} T${first.term})';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: entry.value.map((s) {
                                    return _AssignmentChip(
                                      label: _subjectName(s.subject),
                                      cs: cs,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
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
                    if (widget.canEdit)
                      _ActionIconItem(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        color: cs.primary,
                        onTap: () => _showEditSheet(context, _service),
                      ),
                    if (widget.canEdit)
                      _ActionIconItem(
                        icon: Icons.exit_to_app_outlined,
                        tooltip: 'Resign',
                        color: Colors.orange,
                        onTap: () => _changeStatus(
                          context,
                          _service,
                          TeacherStatus.resigned,
                        ),
                      ),
                    if (widget.canEdit)
                      _ActionIconItem(
                        icon: Icons.undo_outlined,
                        tooltip: 'Restore',
                        color: Colors.green,
                        onTap: () => _changeStatus(
                          context,
                          _service,
                          TeacherStatus.active,
                        ),
                      ),
                    if (widget.canEdit)
                      _ActionIconItem(
                        icon: Icons.swap_horiz_outlined,
                        tooltip: 'Transfer',
                        color: cs.tertiary,
                        onTap: () => _changeStatus(
                          context,
                          _service,
                          TeacherStatus.transferred,
                        ),
                      ),
                    if (widget.canEdit)
                      _ActionIconItem(
                        icon: Icons.block_outlined,
                        tooltip: 'Fired',
                        color: cs.error,
                        onTap: () => _changeStatus(
                          context,
                          _service,
                          TeacherStatus.fired,
                        ),
                      ),
                    if (widget.canEdit)
                      _ActionIconItem(
                        icon: Icons.elderly_outlined,
                        tooltip: 'Retired',
                        color: cs.onSurfaceVariant,
                        onTap: () => _changeStatus(
                          context,
                          _service,
                          TeacherStatus.retired,
                        ),
                      ),
                    if (widget.canDelete)
                      _ActionIconItem(
                        icon: Icons.person_remove_outlined,
                        tooltip: 'Remove',
                        color: cs.error,
                        onTap: () => _confirmRemove(context, _service),
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

  // ── Collapsible section builder ─────────────────────────────────────────

  Widget _buildCollapsibleSection({
    required ColorScheme cs,
    required bool isDark,
    required IconData icon,
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 23, bottom: 4),
            child: child,
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Color _teacherStatusColor(TeacherStatus status, ColorScheme cs) {
    return switch (status) {
      TeacherStatus.active => Colors.green,
      TeacherStatus.resigned => Colors.orange,
      TeacherStatus.transferred => cs.tertiary,
      TeacherStatus.fired => cs.error,
      TeacherStatus.retired => cs.onSurfaceVariant,
    };
  }

  String? _formatHiredDate(int? daysSinceEpoch) {
    if (daysSinceEpoch == null) return null;
    final date = DateTime.utc(1970).add(Duration(days: daysSinceEpoch));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ── Edit sheet ──────────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, MemberManagementService service) {
    final cs = Theme.of(context).colorScheme;
    final roleCtrl = TextEditingController(text: teacher.role ?? '');
    final deptCtrl = TextEditingController(text: teacher.department ?? '');
    DateTime? hiredDate = teacher.hired != null
        ? DateTime.utc(1970).add(Duration(days: teacher.hired!))
        : null;

    showEduSheet(
      context: context,
      title: 'Edit Teacher',
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

                        // Hired date picker
                        InkWell(
                          onTap: () async {
                            final picked = await showInlineDatePicker(
                              context: ctx,
                              initialDate: hiredDate ?? DateTime.now(),
                              firstDate: DateTime(1970),
                              lastDate: DateTime.now(),
                              title: 'Hire date',
                            );
                            if (picked != null) {
                              setSheetState(() => hiredDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.4),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    hiredDate != null
                                        ? _formatHiredDate(
                                            hiredDate!
                                                    .toUtc()
                                                    .millisecondsSinceEpoch ~/
                                                86400000,
                                          )!
                                        : 'Hired date',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: hiredDate != null
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant.withValues(
                                              alpha: 0.6,
                                            ),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ],
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

                              await service.updateTeacher(
                                schoolId: schoolId,
                                userId: teacher.user,
                                role: role,
                                department: dept,
                                hiredDate: hiredDate,
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

  // ── Status change ───────────────────────────────────────────────────────

  void _changeStatus(
    BuildContext context,
    MemberManagementService service,
    TeacherStatus status,
  ) async {
    await service.changeTeacherStatus(
      schoolId: schoolId,
      userId: teacher.user,
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
      title: 'Remove Teacher',
      message:
          'Remove ${user.name} as a teacher from this school? '
          'This action can be undone by re-adding them.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    final result = await service.removeTeacher(
      schoolId: schoolId,
      userId: teacher.user,
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
            content: Text('Failed to remove teacher: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assignment chip — compact chip for class teacher / subject display
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentChip extends StatelessWidget {
  const _AssignmentChip({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.primary.withValues(alpha: 0.9),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action icon group — shared compact icon button row for detail sheets
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
