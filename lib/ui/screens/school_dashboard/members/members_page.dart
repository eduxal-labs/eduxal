import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/departments_dao.dart';
import '../../../../database/daos/members_dao.dart';

import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/curriculum_levels.dart';
import '../../../../models/result.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/animated_action_button.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_data_table.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';
import '../../../../services/member_management.dart';
import '../../../widgets/member_creation/add_guardian_panel.dart';
import 'student_detail_page.dart';
import '../../../widgets/member_creation/add_owner_panel.dart';
import '../../../widgets/member_creation/add_staff_panel.dart';
import '../../../widgets/member_creation/add_student_panel.dart';
import '../../../widgets/member_creation/add_teacher_panel.dart';
import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class MembersPage extends StatelessWidget {
  const MembersPage({super.key, required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return _MembersPageBody(schoolContext: schoolContext);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs enum for clarity
// ─────────────────────────────────────────────────────────────────────────────

enum _MemberTab { departments, owners, teachers, staff, students, guardians }

// ─────────────────────────────────────────────────────────────────────────────
// Page body — TabController host
// ─────────────────────────────────────────────────────────────────────────────

class _MembersPageBody extends StatefulWidget {
  const _MembersPageBody({required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  State<_MembersPageBody> createState() => _MembersPageBodyState();
}

class _MembersPageBodyState extends State<_MembersPageBody>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late MembersDao _dao;
  _MemberTab _currentTab = _MemberTab.departments;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = MembersDao(db);
    _tabController = TabController(
      length: _MemberTab.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final newTab = _MemberTab.values[_tabController.index];
    if (newTab != _currentTab) {
      setState(() => _currentTab = newTab);
    }
  }

  // ── FAB action per tab ──────────────────────────────────────────────────

  Future<void> _onFabPressed() async {
    switch (_currentTab) {
      case _MemberTab.departments:
        _showCreateDepartment();
      case _MemberTab.owners:
        await showAddOwnerPanel(context: context, schoolId: _schoolId);
      case _MemberTab.teachers:
        await showAddTeacherPanel(context: context, schoolId: _schoolId);
      case _MemberTab.staff:
        await showAddStaffPanel(context: context, schoolId: _schoolId);
      case _MemberTab.students:
        await showAddStudentPanel(context: context, schoolId: _schoolId);
      case _MemberTab.guardians:
        // Guardians require a student context — show a student picker first.
        await _pickStudentThenAddGuardian();
    }
  }

  void _showCreateDepartment() {
    showEduSheet(
      context: context,
      builder: (ctx) =>
          _CreateDepartmentSheet(schoolId: _schoolId, dao: DepartmentsDao(db)),
    );
  }

  Future<void> _pickStudentThenAddGuardian() async {
    if (!mounted) return;
    final picked = await showEduSheet<StudentsData>(
      context: context,
      builder: (ctx) => _StudentPickerSheet(schoolId: _schoolId),
    );

    if (picked == null || !mounted) return;

    await showAddGuardianPanel(
      context: context,
      schoolId: _schoolId,
      studentAdm: picked.adm,
      studentName: picked.name,
    );
  }

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _MembersFab(
        tab: _currentTab,
        onPressed: _onFabPressed,
      ),
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────────
          EduTabBar(
            controller: _tabController,
            isScrollable: true,
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            tabs: const [
              EduTab(label: 'Departments'),
              EduTab(label: 'Owners'),
              EduTab(label: 'Teachers'),
              EduTab(label: 'Staff'),
              EduTab(label: 'Students'),
              EduTab(label: 'Guardians'),
            ],
          ),

          // ── Tab content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DepartmentsTab(schoolId: _schoolId),
                _OwnersTab(schoolId: _schoolId, dao: _dao),
                _TeachersTab(schoolId: _schoolId, dao: _dao),
                _StaffTab(schoolId: _schoolId, dao: _dao),
                _StudentsTab(schoolId: _schoolId, dao: _dao),
                _GuardiansTab(schoolId: _schoolId, dao: _dao),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB — context-aware icon + tooltip
// ─────────────────────────────────────────────────────────────────────────────

class _MembersFab extends StatelessWidget {
  const _MembersFab({required this.tab, required this.onPressed});

  final _MemberTab tab;
  final VoidCallback onPressed;

  String get _tooltip => switch (tab) {
    _MemberTab.departments => 'Add Department',
    _MemberTab.owners => 'Add Owner',
    _MemberTab.teachers => 'Add Teacher',
    _MemberTab.staff => 'Add Staff',
    _MemberTab.students => 'Add Student',
    _MemberTab.guardians => 'Add Guardian',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: 'fab_members',
      onPressed: onPressed,
      tooltip: _tooltip,
      elevation: 4,
      highlightElevation: 6,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.add, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Departments tab
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentsTab extends StatefulWidget {
  const _DepartmentsTab({required this.schoolId});
  final String schoolId;

  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab> {
  late final DepartmentsDao _dao;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

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
          return const _EmptyTab(
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

        return EduDataTable<Department>(
          items: depts,
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          searchController: _searchCtrl,
          searchHint: 'Search departments…',
          showSearch: _showSearch,
          onToggleSearch: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchCtrl.clear();
              _query = '';
            }
          }),
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          onItemTap: (dept) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _DepartmentDetailScreen(
                  dept: dept,
                  schoolId: widget.schoolId,
                  dao: _dao,
                ),
              ),
            );
          },
          actions: (dept) => [
            EduDataTableAction<Department>(
              icon: Icons.open_in_new_rounded,
              label: 'View',
              onTap: (d) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _DepartmentDetailScreen(
                      dept: d,
                      schoolId: widget.schoolId,
                      dao: _dao,
                    ),
                  ),
                );
              },
            ),
            EduDataTableAction<Department>(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              isDestructive: true,
              onTap: (d) => _confirmDeleteDepartment(context, d),
            ),
          ],
          rowBuilder: (context, dept, isHovered) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    ),
                    child: Icon(
                      Icons.domain_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dept.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        if (dept.description != null &&
                            dept.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              dept.description!,
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
                ],
              ),
            );
          },
        );
      },
    );
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
        await _dao.deleteDepartment(
          widget.schoolId,
          dept.name,
          accountId: user.id,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owners tab
// ─────────────────────────────────────────────────────────────────────────────

class _OwnersTab extends StatefulWidget {
  const _OwnersTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  State<_OwnersTab> createState() => _OwnersTabState();
}

class _OwnersTabState extends State<_OwnersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Batch-load all users for a list of owner records in one pass.
  Future<Map<String, UsersData>> _batchLoadUsers(
    List<OwnersData> owners,
  ) async {
    final map = <String, UsersData>{};
    final ids = owners.map((o) => o.user).toSet();
    for (final id in ids) {
      final u = await widget.dao.findUserById(id);
      if (u != null) map[id] = u;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OwnersData>>(
      stream: widget.dao.watchOwners(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingIndicator();
        }
        final owners = snapshot.data ?? [];
        if (owners.isEmpty) {
          return const _EmptyTab(
            icon: Icons.shield_outlined,
            label: 'No owners yet',
            hint: 'Tap + to add a school owner.',
          );
        }
        return FutureBuilder<Map<String, UsersData>>(
          future: _batchLoadUsers(owners),
          builder: (context, usersSnap) {
            final userMap = usersSnap.data ?? {};

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

            return _FlatMemberList(
              searchController: _searchCtrl,
              searchHint: 'Search owners…',
              showSearch: _showSearch,
              onToggleSearch: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _query = '';
                }
              }),
              onSearchChanged: (v) => setState(() => _query = v.trim()),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final owner = filtered[i];
                final user = userMap[owner.user];
                return _OwnerRow(
                  schoolId: widget.schoolId,
                  owner: owner,
                  user: user,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({
    required this.schoolId,
    required this.owner,
    required this.user,
  });
  final String schoolId;
  final OwnersData owner;
  final UsersData? user;

  @override
  Widget build(BuildContext context) {
    return _UserDataRow(
      userId: owner.user,
      name: user?.name ?? '…',
      subtitle: user?.phone ?? '',
      status: user?.status,
      level: user?.level,
      onTap: () => _openDetail(context, user),
      actions: user == null
          ? const []
          : [
              _RowAction(
                icon: Icons.open_in_new_rounded,
                label: 'View',
                onTap: () => _openDetail(context, user),
              ),
              _RowAction(
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
      builder: (_) => _OwnerInfoSheet(user: user, schoolId: schoolId),
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
      title: 'Remove "${user.name}"?',
      message: 'This will remove the owner from this school.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final service = MemberManagementService(MembersDao(db));
    final result = await service.removeOwner(
      schoolId: schoolId,
      userId: user.id,
    );
    switch (result) {
      case Err(:final error) when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove owner: $error')),
        );
      default:
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Teachers tab
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersTab extends StatefulWidget {
  const _TeachersTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, UsersData>> _batchLoadUsers(
    List<TeachersData> teachers,
  ) async {
    final map = <String, UsersData>{};
    final ids = teachers.map((t) => t.user).toSet();
    for (final id in ids) {
      final u = await widget.dao.findUserById(id);
      if (u != null) map[id] = u;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeachersData>>(
      stream: widget.dao.watchTeachers(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const _EmptyTab(
            icon: Icons.school_outlined,
            label: 'No teachers yet',
            hint: 'Tap + to add a teacher.',
          );
        }
        return FutureBuilder<Map<String, UsersData>>(
          future: _batchLoadUsers(list),
          builder: (context, usersSnap) {
            final userMap = usersSnap.data ?? {};

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

            return _FlatMemberList(
              searchController: _searchCtrl,
              searchHint: 'Search teachers…',
              showSearch: _showSearch,
              onToggleSearch: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _query = '';
                }
              }),
              onSearchChanged: (v) => setState(() => _query = v.trim()),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final t = filtered[i];
                final user = userMap[t.user];
                return _TeacherRow(
                  schoolId: widget.schoolId,
                  teacher: t,
                  user: user,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({
    required this.schoolId,
    required this.teacher,
    required this.user,
  });
  final String schoolId;
  final TeachersData teacher;
  final UsersData? user;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (teacher.department != null) parts.add(teacher.department!);
    if (teacher.role != null) parts.add(teacher.role!);

    return _UserDataRow(
      userId: teacher.user,
      name: user?.name ?? '…',
      subtitle: parts.isNotEmpty ? parts.join('  ·  ') : (user?.phone ?? ''),
      status: user?.status,
      level: user?.level,
      trailing: teacher.status != TeacherStatus.active
          ? _SmallChip(
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
      actions: user == null
          ? const []
          : [
              _RowAction(
                icon: Icons.open_in_new_rounded,
                label: 'View',
                onTap: () {
                  final w = MediaQuery.sizeOf(context).width;
                  if (w >= 600) {
                    _showTeacherSideSheet(context, user!);
                  } else {
                    _showTeacherBottomSheet(context, user!);
                  }
                },
              ),
              _RowAction(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () {
                  final w = MediaQuery.sizeOf(context).width;
                  if (w >= 600) {
                    _showTeacherSideSheet(context, user!);
                  } else {
                    _showTeacherBottomSheet(context, user!);
                  }
                },
              ),
              _RowAction(
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
      builder: (_) =>
          _TeacherInfoSheet(user: user, teacher: teacher, schoolId: schoolId),
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
    switch (result) {
      case Err(:final error) when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove teacher: $error')),
        );
      default:
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff tab
// ─────────────────────────────────────────────────────────────────────────────

class _StaffTab extends StatefulWidget {
  const _StaffTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, UsersData>> _batchLoadUsers(
    List<StaffData> staffList,
  ) async {
    final map = <String, UsersData>{};
    final ids = staffList.map((s) => s.user).toSet();
    for (final id in ids) {
      final u = await widget.dao.findUserById(id);
      if (u != null) map[id] = u;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffData>>(
      stream: widget.dao.watchStaff(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const _EmptyTab(
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

            return _FlatMemberList(
              searchController: _searchCtrl,
              searchHint: 'Search staff…',
              showSearch: _showSearch,
              onToggleSearch: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _query = '';
                }
              }),
              onSearchChanged: (v) => setState(() => _query = v.trim()),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                final user = userMap[s.user];
                return _StaffRow(
                  schoolId: widget.schoolId,
                  member: s,
                  user: user,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.schoolId,
    required this.member,
    required this.user,
  });
  final String schoolId;
  final StaffData member;
  final UsersData? user;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (member.department != null) parts.add(member.department!);
    if (member.role != null) parts.add(member.role!);

    return _UserDataRow(
      userId: member.user,
      name: user?.name ?? '…',
      subtitle: parts.isNotEmpty ? parts.join('  ·  ') : (user?.phone ?? ''),
      status: user?.status,
      level: user?.level,
      trailing: member.status != StaffStatus.active
          ? _SmallChip(
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
      actions: user == null
          ? const []
          : [
              _RowAction(
                icon: Icons.open_in_new_rounded,
                label: 'View',
                onTap: () {
                  final w = MediaQuery.sizeOf(context).width;
                  if (w >= 600) {
                    _showStaffSideSheet(context, user!);
                  } else {
                    _showStaffBottomSheet(context, user!);
                  }
                },
              ),
              _RowAction(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () {
                  final w = MediaQuery.sizeOf(context).width;
                  if (w >= 600) {
                    _showStaffSideSheet(context, user!);
                  } else {
                    _showStaffBottomSheet(context, user!);
                  }
                },
              ),
              _RowAction(
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
      builder: (_) =>
          _StaffInfoSheet(user: user, member: member, schoolId: schoolId),
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

// ─────────────────────────────────────────────────────────────────────────────
// Students tab
// ─────────────────────────────────────────────────────────────────────────────

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentsData>>(
      stream: widget.dao.watchAllStudents(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const _EmptyTab(
            icon: Icons.groups_outlined,
            label: 'No students yet',
            hint: 'Tap + to add a student.',
          );
        }

        // Apply search filter by name or admission number
        final filtered = _query.isEmpty
            ? list
            : list.where((s) {
                final q = _query.toLowerCase();
                return s.name.toLowerCase().contains(q) ||
                    s.adm.toString().contains(q);
              }).toList();

        return _FlatMemberList(
          searchController: _searchCtrl,
          searchHint: 'Search by name or ADM…',
          showSearch: _showSearch,
          onToggleSearch: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchCtrl.clear();
              _query = '';
            }
          }),
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final s = filtered[i];
            return _StudentRow(schoolId: widget.schoolId, student: s);
          },
        );
      },
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.schoolId, required this.student});
  final String schoolId;
  final StudentsData student;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _FlatRow(
      leading: _StudentAvatar(
        schoolId: schoolId,
        adm: student.adm,
        name: student.name,
        status: student.status,
      ),
      name: student.name,
      subtitle: 'ADM: ${student.adm}',
      trailing: student.status != StudentStatus.active
          ? _SmallChip(label: student.status.name, cs: cs)
          : null,
      onTap: () {
        final w = MediaQuery.sizeOf(context).width;
        if (w >= 600) {
          _showStudentSideSheet(context);
        } else {
          _showStudentBottomSheet(context);
        }
      },
      actions: [
        _RowAction(
          icon: Icons.open_in_new_rounded,
          label: 'View',
          onTap: () {
            final w = MediaQuery.sizeOf(context).width;
            if (w >= 600) {
              _showStudentSideSheet(context);
            } else {
              _showStudentBottomSheet(context);
            }
          },
        ),
        _RowAction(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onTap: () {
            final w = MediaQuery.sizeOf(context).width;
            if (w >= 600) {
              _showStudentSideSheet(context);
            } else {
              _showStudentBottomSheet(context);
            }
          },
        ),
        _RowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          isDestructive: true,
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  void _showStudentBottomSheet(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => StudentDetailSheet(
          initialStudent: student,
          schoolId: schoolId,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  void _showStudentSideSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: StudentDetailSheet(
            initialStudent: student,
            schoolId: schoolId,
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete "${student.name}"?',
      message: 'This will permanently delete the student record.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final service = MemberManagementService(MembersDao(db));
    final result = await service.changeStudentStatus(
      schoolId: schoolId,
      adm: student.adm,
      status: StudentStatus.deleted,
    );
    switch (result) {
      case Err(:final error) when context.mounted:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete student: $error')),
        );
      default:
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardians tab
// ─────────────────────────────────────────────────────────────────────────────

class _GuardiansTab extends StatefulWidget {
  const _GuardiansTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  State<_GuardiansTab> createState() => _GuardiansTabState();
}

class _GuardiansTabState extends State<_GuardiansTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<({UsersData user, int wardCount})>>(
      stream: widget.dao.watchUniqueGuardians(widget.schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingIndicator();
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const _EmptyTab(
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

        return _FlatMemberList(
          searchController: _searchCtrl,
          searchHint: 'Search by name or phone…',
          showSearch: _showSearch,
          onToggleSearch: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchCtrl.clear();
              _query = '';
            }
          }),
          onSearchChanged: (v) => setState(() => _query = v.trim()),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final item = filtered[i];
            return _UniqueGuardianRow(
              schoolId: widget.schoolId,
              user: item.user,
              wardCount: item.wardCount,
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
  });

  final String schoolId;
  final UsersData user;
  final int wardCount;

  @override
  Widget build(BuildContext context) {
    return _UserDataRow(
      userId: user.id,
      name: user.name,
      subtitle: '$wardCount ward${wardCount == 1 ? '' : 's'}',
      status: user.status,
      level: user.level,
      onTap: () => _openDetail(context),
      actions: [
        _RowAction(
          icon: Icons.open_in_new_rounded,
          label: 'View',
          onTap: () => _openDetail(context),
        ),
      ],
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
      builder: (_) => _GuardianWardsSheet(user: user, schoolId: schoolId),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared member tile — user-based rows (Owners, Teachers, Staff, Guardians)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _RowAction — lightweight action descriptor for flat rows
// ─────────────────────────────────────────────────────────────────────────────

class _RowAction {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserDataRow — flat data-table row for user-based members
// (Owners, Teachers, Staff, Guardians)
// ─────────────────────────────────────────────────────────────────────────────

class _UserDataRow extends StatefulWidget {
  const _UserDataRow({
    required this.userId,
    required this.name,
    required this.subtitle,
    this.status,
    this.level,
    this.trailing,
    this.onTap,
    this.actions = const [],
  });

  final String userId;
  final String name;
  final String subtitle;
  final UserStatus? status;
  final UserLevel? level;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<_RowAction> actions;

  @override
  State<_UserDataRow> createState() => _UserDataRowState();
}

class _UserDataRowState extends State<_UserDataRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    Widget avatar = UserAvatar(userId: widget.userId, radius: 16);

    if (widget.status != null && widget.level != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -1,
            right: -1,
            child: StatusIndicator(
              status: widget.status!,
              level: widget.level!,
              backgroundColor: isDark ? const Color(0xFF18222E) : cs.surface,
            ),
          ),
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered
            ? cs.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Avatar
                  avatar,
                  const SizedBox(width: 12),

                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
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
                      ],
                    ),
                  ),

                  // Trailing chip
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FlatRow — flat data-table row for non-user rows (Students)
// ─────────────────────────────────────────────────────────────────────────────

class _FlatRow extends StatefulWidget {
  const _FlatRow({
    required this.leading,
    required this.name,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.actions = const [],
  });

  final Widget leading;
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<_RowAction> actions;

  @override
  State<_FlatRow> createState() => _FlatRowState();
}

class _FlatRowState extends State<_FlatRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered
            ? cs.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Leading (avatar)
                  widget.leading,
                  const SizedBox(width: 12),

                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
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
                      ],
                    ),
                  ),

                  // Trailing chip
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],

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
                ],
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
        : cs.onSurfaceVariant;
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
// _MobileActions — mobile: three-dot → bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MobileActions extends StatelessWidget {
  const _MobileActions({required this.actions});

  final List<_RowAction> actions;

  void _showSheet(BuildContext context) {
    showEduSheet<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...actions.map((action) {
                final color = action.isDestructive ? cs.error : cs.onSurface;
                return ListTile(
                  leading: Icon(action.icon, size: 20, color: color),
                  title: Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: color,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    action.onTap();
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  minLeadingWidth: 20,
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
        tooltip: 'More actions',
        onPressed: () => _showSheet(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student avatar with initials fallback
// ─────────────────────────────────────────────────────────────────────────────

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({
    required this.schoolId,
    required this.adm,
    required this.name,
    required this.status,
  });

  final String schoolId;
  final int adm;
  final String name;
  final StudentStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(name);

    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.studentImagePath(schoolId, adm)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: 16,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        return CircleAvatar(
          radius: 16,
          backgroundColor: cs.surfaceContainerHighest,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small status / role chip
// ─────────────────────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FlatMemberList — flat list separated by thin dividers
// ─────────────────────────────────────────────────────────────────────────────

class _FlatMemberList extends StatelessWidget {
  const _FlatMemberList({
    required this.itemCount,
    required this.itemBuilder,
    this.searchController,
    this.searchHint,
    this.showSearch = false,
    this.onToggleSearch,
    this.onSearchChanged,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final TextEditingController? searchController;
  final String? searchHint;
  final bool showSearch;
  final VoidCallback? onToggleSearch;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search toolbar ─────────────────────────────────────────────
        if (searchController != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                if (showSearch) ...[
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: searchHint ?? 'Search…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? cs.surfaceContainerHighest.withValues(
                                  alpha: 0.3,
                                )
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.kCardRadius,
                            ),
                            borderSide: BorderSide.none,
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
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(
                        Icons.close_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      tooltip: 'Close search',
                      onPressed: onToggleSearch,
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(
                        Icons.search_rounded,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      tooltip: 'Search',
                      onPressed: onToggleSearch,
                    ),
                  ),
                ],
              ],
            ),
          ),

        // ── List content ───────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 80),
            itemCount: itemCount,
            separatorBuilder: (_, _) => AppTheme.tableRowDivider(isDark, cs),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student picker sheet (for guardian creation)
// ─────────────────────────────────────────────────────────────────────────────

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet({required this.schoolId});
  final String schoolId;

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _dao = MembersDao(db);
  List<StudentsData> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await _dao.searchStudents(widget.schoolId, query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select student (ward)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2A3A)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by name or admission number...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
                onChanged: (q) => _search(q),
              ),
            ),
          ),
          const Divider(height: 1),
          // Results list
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'No active students found.'
                            : 'No students match "${_searchCtrl.text}"',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final s = _results[i];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: cs.surfaceContainerHighest,
                          child: Text(
                            _initials(s.name),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${s.adm}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member detail stub — placeholder until full detail pages are built
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Owner info sheet — bottom sheet (mobile) / side sheet (desktop)
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerInfoSheet extends StatelessWidget {
  const _OwnerInfoSheet({
    required this.user,
    required this.schoolId,
    this.isSideSheet = false,
  });

  final UsersData user;
  final String schoolId;
  final bool isSideSheet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF18222E) : cs.surface,
      borderRadius: isSideSheet
          ? const BorderRadius.horizontal(left: Radius.circular(12))
          : const BorderRadius.vertical(top: Radius.circular(16)),
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

                const SizedBox(height: 24),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.15 : 0.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Actions section
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

                // Remove owner action
                _OwnerAction(
                  icon: Icons.person_remove_outlined,
                  label: 'Remove from school',
                  color: cs.error,
                  onTap: () => _confirmRemoveOwner(context),
                ),
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

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active account. Please log in again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final dao = MembersDao(db);
      await dao.removeOwner(
        schoolId: schoolId,
        userId: user.id,
        accountId: accountId,
      );
      if (context.mounted) Navigator.pop(context); // close sheet
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove owner: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Teacher detail page — full profile with edit / status / remove actions
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherInfoSheet extends StatefulWidget {
  const _TeacherInfoSheet({
    required this.user,
    required this.teacher,
    required this.schoolId,
    this.isSideSheet = false,
  });

  final UsersData user;
  final TeachersData teacher;
  final String schoolId;
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
          ? const BorderRadius.horizontal(left: Radius.circular(12))
          : const BorderRadius.vertical(top: Radius.circular(16)),
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
                  _DetailRow(label: 'Role', value: teacher.role!, cs: cs),
                if (teacher.department != null)
                  _DetailRow(
                    label: 'Department',
                    value: teacher.department!,
                    cs: cs,
                  ),
                if (teacher.hired != null)
                  _DetailRow(
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
                    _ActionIconItem(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      color: cs.primary,
                      onTap: () => _showEditSheet(context, _service),
                    ),
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
                    _ActionIconItem(
                      icon: Icons.block_outlined,
                      tooltip: 'Fired',
                      color: cs.error,
                      onTap: () =>
                          _changeStatus(context, _service, TeacherStatus.fired),
                    ),
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
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: hiredDate ?? DateTime.now(),
                      firstDate: DateTime(1970),
                      lastDate: DateTime.now(),
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
                                    hiredDate!.toUtc().millisecondsSinceEpoch ~/
                                        86400000,
                                  )!
                                : 'Hired date',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: hiredDate != null
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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

    await service.removeTeacher(schoolId: schoolId, userId: teacher.user);
    if (context.mounted) Navigator.pop(context); // close sheet
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

// ─────────────────────────────────────────────────────────────────────────────
// Staff detail page — full detail with edit, status change, and remove
// ─────────────────────────────────────────────────────────────────────────────

class _StaffInfoSheet extends StatelessWidget {
  const _StaffInfoSheet({
    required this.user,
    required this.member,
    required this.schoolId,
    this.isSideSheet = false,
  });

  final UsersData user;
  final StaffData member;
  final String schoolId;
  final bool isSideSheet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final service = MemberManagementService(MembersDao(db));

    return Material(
      color: isDark ? const Color(0xFF18222E) : cs.surface,
      borderRadius: isSideSheet
          ? const BorderRadius.horizontal(left: Radius.circular(12))
          : const BorderRadius.vertical(top: Radius.circular(16)),
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
                  _DetailRow(label: 'Role', value: member.role!, cs: cs),
                if (member.department != null)
                  _DetailRow(
                    label: 'Department',
                    value: member.department!,
                    cs: cs,
                  ),
                if (member.idnumber != null)
                  _DetailRow(
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
                    _ActionIconItem(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      color: cs.primary,
                      onTap: () => _showEditSheet(context, service),
                    ),
                    _ActionIconItem(
                      icon: Icons.exit_to_app_outlined,
                      tooltip: 'Resign',
                      color: Colors.orange,
                      onTap: () =>
                          _changeStatus(context, service, StaffStatus.resigned),
                    ),
                    _ActionIconItem(
                      icon: Icons.undo_outlined,
                      tooltip: 'Restore',
                      color: Colors.green,
                      onTap: () =>
                          _changeStatus(context, service, StaffStatus.active),
                    ),
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
                    _ActionIconItem(
                      icon: Icons.block_outlined,
                      tooltip: 'Fired',
                      color: cs.error,
                      onTap: () =>
                          _changeStatus(context, service, StaffStatus.fired),
                    ),
                    _ActionIconItem(
                      icon: Icons.elderly_outlined,
                      tooltip: 'Retired',
                      color: cs.onSurfaceVariant,
                      onTap: () =>
                          _changeStatus(context, service, StaffStatus.retired),
                    ),
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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
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

    await service.removeStaff(schoolId: schoolId, userId: member.user);
    if (context.mounted) Navigator.pop(context); // close sheet
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardian detail page
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianWardsSheet extends StatelessWidget {
  const _GuardianWardsSheet({
    required this.user,
    required this.schoolId,
    this.isSideSheet = false,
  });

  final UsersData user;
  final String schoolId;
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
          ? const BorderRadius.horizontal(left: Radius.circular(12))
          : const BorderRadius.vertical(top: Radius.circular(16)),
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
  });

  final GuardiansData guardian;
  final StudentsData? student;
  final String schoolId;
  final MemberManagementService service;
  final ColorScheme cs;
  final bool isDark;

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
                  child: _StudentAvatar(
                    schoolId: schoolId,
                    adm: student!.adm,
                    name: student!.name,
                    status: student!.status,
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
              // Edit button
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
              const SizedBox(width: 4),
              // Unlink button
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
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    dropdownColor: isDarkLocal
                        ? const Color(0xFF18222E)
                        : cs.surface,
                    items: GuardianRelationship.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.name)),
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
                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    dropdownColor: isDarkLocal
                        ? const Color(0xFF18222E)
                        : cs.surface,
                    items: GuardianRole.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.name)),
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
                      relationship: relChanged ? selectedRelationship : null,
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

    await service.removeGuardian(
      schoolId: schoolId,
      userId: guardian.user,
      studentAdm: guardian.student,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Department Detail Screen — teachers + staff lists
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentDetailScreen extends StatefulWidget {
  const _DepartmentDetailScreen({
    required this.dept,
    required this.schoolId,
    required this.dao,
  });

  final Department dept;
  final String schoolId;
  final DepartmentsDao dao;

  @override
  State<_DepartmentDetailScreen> createState() =>
      _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<_DepartmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

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
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'fab_dept_detail_assign',
        onPressed: () => _showAssignMember(context),
        tooltip: 'Assign member',
        elevation: 4,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.add, size: 20),
      ),
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
            onRemoveTeacher: (userId) => _removeTeacher(userId),
            onRemoveStaff: (userId) => _removeStaff(userId),
          ),
          _DeptMemberList<({TeachersData teacher, UsersData user})>(
            stream: widget.dao.watchTeachersInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            emptyLabel: 'No teachers assigned',
            nameOf: (item) => item.user.name,
            statusOf: (item) => item.teacher.status.name,
            onRemove: (item) => _removeTeacher(item.teacher.user),
          ),
          _DeptMemberList<({StaffData staff, UsersData user})>(
            stream: widget.dao.watchStaffInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            emptyLabel: 'No staff assigned',
            nameOf: (item) => item.user.name,
            statusOf: (item) => item.staff.status.name,
            onRemove: (item) => _removeStaff(item.staff.user),
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
        await widget.dao.deleteDepartment(
          widget.schoolId,
          widget.dept.name,
          accountId: user.id,
        );
      }
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showAssignMember(BuildContext context) {
    showEduSheet(
      context: context,
      builder: (ctx) => _AssignMemberSearchSheet(
        schoolId: widget.schoolId,
        deptName: widget.dept.name,
        dao: widget.dao,
        onDone: () {
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _removeTeacher(String teacherUserId) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await widget.dao.assignTeacherToDepartment(
      widget.schoolId,
      teacherUserId,
      departmentName: null,
      accountId: user.id,
    );
  }

  Future<void> _removeStaff(String staffUserId) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await widget.dao.assignStaffToDepartment(
      widget.schoolId,
      staffUserId,
      departmentName: null,
      accountId: user.id,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dept member list — reusable for teachers + staff
// ─────────────────────────────────────────────────────────────────────────────

class _DeptAllMemberList extends StatelessWidget {
  const _DeptAllMemberList({
    required this.teacherStream,
    required this.staffStream,
    required this.onRemoveTeacher,
    required this.onRemoveStaff,
  });

  final Stream<List<({TeachersData teacher, UsersData user})>> teacherStream;
  final Stream<List<({StaffData staff, UsersData user})>> staffStream;
  final Future<void> Function(String userId) onRemoveTeacher;
  final Future<void> Function(String userId) onRemoveStaff;

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
                  onRemove: () async => onRemoveTeacher(t.teacher.user),
                ),
              ),
              ...staffMembers.map(
                (s) => _DeptAllItem(
                  name: s.user.name,
                  statusLabel: s.staff.status.name,
                  roleTag: 'Staff',
                  onRemove: () async => onRemoveStaff(s.staff.user),
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

class _DeptAllItem extends StatelessWidget {
  const _DeptAllItem({
    required this.name,
    required this.statusLabel,
    required this.roleTag,
    required this.onRemove,
  });

  final String name;
  final String statusLabel;
  final String roleTag;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Role tag chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  roleTag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: cs.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedActionButton(
                icon: Icons.close_rounded,
                iconSize: 15,
                color: cs.error.withValues(alpha: 0.5),
                size: 28,
                tooltip: 'Remove',
                showCheckOnSuccess: false,
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeptMemberList<T> extends StatelessWidget {
  const _DeptMemberList({
    required this.stream,
    required this.emptyLabel,
    required this.nameOf,
    required this.statusOf,
    required this.onRemove,
  });

  final Stream<List<T>> stream;
  final String emptyLabel;
  final String Function(T) nameOf;
  final String Function(T) statusOf;
  final Future<void> Function(T) onRemove;

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
                      onRemove: () async => onRemove(item),
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

class _DeptMemberRow extends StatelessWidget {
  const _DeptMemberRow({
    required this.name,
    required this.statusLabel,
    required this.onRemove,
  });

  final String name;
  final String statusLabel;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                    if (statusLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedActionButton(
                icon: Icons.close_rounded,
                iconSize: 15,
                color: cs.error.withValues(alpha: 0.5),
                size: 28,
                tooltip: 'Remove',
                showCheckOnSuccess: false,
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assign member sheet — picks from unassigned teachers/staff
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

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Assign Member',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // Search field
              TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
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
              Flexible(
                child: _showTeachers
                    ? _buildTeacherList(cs, isDark)
                    : _buildStaffList(cs, isDark),
              ),
            ],
          ),
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
// Create Department Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateDepartmentSheet extends StatefulWidget {
  const _CreateDepartmentSheet({required this.schoolId, required this.dao});
  final String schoolId;
  final DepartmentsDao dao;

  @override
  State<_CreateDepartmentSheet> createState() => _CreateDepartmentSheetState();
}

class _CreateDepartmentSheetState extends State<_CreateDepartmentSheet> {
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

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.createDepartment(
        DepartmentsCompanion(
          school: Value(widget.schoolId),
          name: Value(_nameCtrl.text.trim()),
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Department',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: _deptInputDeco(
                  cs: cs,
                  isDark: isDark,
                  hint: 'Department name',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: _deptInputDeco(
                  cs: cs,
                  isDark: isDark,
                  hint: 'Description (optional)',
                ),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: _saving ? null : _save,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Center(
                        child: _saving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: cs.onPrimary,
                                ),
                              )
                            : Text(
                                'Create',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
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
// Helper — department input decoration
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _deptInputDeco({
  required ColorScheme cs,
  required bool isDark,
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
    ),
    filled: true,
    fillColor: isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
        : cs.surfaceContainerHighest.withValues(alpha: 0.3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.primary, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.error.withValues(alpha: 0.5)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail row (key-value pair)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.cs,
  });

  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
