import 'package:flutter/material.dart' hide Action;

import '../../../../database/database.dart';
import '../../../../database/daos/departments_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/member_creation/add_guardian_panel.dart';
import '../../../widgets/member_creation/add_owner_panel.dart';
import '../../../widgets/member_creation/add_staff_panel.dart';
import '../../../widgets/member_creation/add_student_panel.dart';
import '../../../widgets/member_creation/add_teacher_panel.dart';
import 'departments_tab.dart';
import 'guardians_tab.dart';
import 'owners_tab.dart';
import 'staff_tab.dart';
import 'students_tab.dart';
import 'teachers_tab.dart';

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
  TabController? _tabController;
  late MembersDao _dao;
  late List<_MemberTab> _visibleTabs;
  _MemberTab? _currentTab;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _dao = MembersDao(db);
    _visibleTabs = _computeVisibleTabs();
    _setupTabController();
    widget.schoolContext.currentEntry.addListener(_onEntryChanged);
  }

  List<_MemberTab> _computeVisibleTabs() {
    final entry = widget.schoolContext.currentEntry.value;
    if (entry is OwnerEntry) {
      return _MemberTab.values; // Owners see all member tabs
    }
    final perms = widget.schoolContext.permissions;
    return [
      if (perms.can(Resource.departments, Action.read)) _MemberTab.departments,
      if (perms.can(Resource.owners, Action.read)) _MemberTab.owners,
      if (perms.can(Resource.teachers, Action.read)) _MemberTab.teachers,
      if (perms.can(Resource.staff, Action.read)) _MemberTab.staff,
      if (perms.can(Resource.students, Action.read)) _MemberTab.students,
      if (perms.can(Resource.students, Action.read)) _MemberTab.guardians,
    ];
  }

  void _setupTabController() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    if (_visibleTabs.isNotEmpty) {
      // Try to preserve current tab selection across rebuilds.
      final preservedIndex = _currentTab != null
          ? _visibleTabs.indexOf(_currentTab!)
          : -1;
      _currentTab = preservedIndex >= 0
          ? _visibleTabs[preservedIndex]
          : _visibleTabs.first;
      _tabController = TabController(
        length: _visibleTabs.length,
        initialIndex: preservedIndex >= 0 ? preservedIndex : 0,
        vsync: this,
      )..addListener(_onTabChanged);
    } else {
      _currentTab = null;
      _tabController = null;
    }
  }

  void _onEntryChanged() {
    final newTabs = _computeVisibleTabs();
    final tabsChanged =
        newTabs.length != _visibleTabs.length ||
        !_tabsEqual(newTabs, _visibleTabs);
    if (tabsChanged) {
      _visibleTabs = newTabs;
      _setupTabController();
    }
    // Always rebuild — entry change may affect FAB visibility, etc.
    setState(() {});
  }

  static bool _tabsEqual(List<_MemberTab> a, List<_MemberTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    widget.schoolContext.currentEntry.removeListener(_onEntryChanged);
    _tabController
      ?..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final tc = _tabController;
    if (tc == null || tc.indexIsChanging) return;
    final newTab = _visibleTabs[tc.index];
    if (newTab != _currentTab) {
      setState(() => _currentTab = newTab);
    }
  }

  bool _canCreateForCurrentTab() {
    final ct = _currentTab;
    if (ct == null) return false;

    final entry = widget.schoolContext.currentEntry.value;
    if (entry is OwnerEntry) return true;

    final perms = widget.schoolContext.permissions;

    return switch (ct) {
      _MemberTab.departments => perms.can(Resource.departments, Action.create),
      _MemberTab.owners => perms.can(Resource.owners, Action.create),
      _MemberTab.teachers => perms.can(Resource.teachers, Action.create),
      _MemberTab.staff => perms.can(Resource.staff, Action.create),
      _MemberTab.students => perms.can(Resource.students, Action.create),
      _MemberTab.guardians => perms.can(Resource.students, Action.assign),
    };
  }

  String _tabLabel(_MemberTab tab) => switch (tab) {
    _MemberTab.departments => 'Departments',
    _MemberTab.owners => 'Owners',
    _MemberTab.teachers => 'Teachers',
    _MemberTab.staff => 'Staff',
    _MemberTab.students => 'Students',
    _MemberTab.guardians => 'Guardians',
  };

  Widget _buildTabContent(_MemberTab tab) => switch (tab) {
    _MemberTab.departments => DepartmentsTab(
      schoolId: _schoolId,
      schoolContext: widget.schoolContext,
    ),
    _MemberTab.owners => OwnersTab(
      schoolId: _schoolId,
      dao: _dao,
      schoolContext: widget.schoolContext,
    ),
    _MemberTab.teachers => TeachersTab(
      schoolId: _schoolId,
      dao: _dao,
      schoolContext: widget.schoolContext,
    ),
    _MemberTab.staff => StaffTab(
      schoolId: _schoolId,
      dao: _dao,
      schoolContext: widget.schoolContext,
    ),
    _MemberTab.students => StudentsTab(
      schoolId: _schoolId,
      dao: _dao,
      schoolContext: widget.schoolContext,
    ),
    _MemberTab.guardians => GuardiansTab(
      schoolId: _schoolId,
      dao: _dao,
      schoolContext: widget.schoolContext,
    ),
  };

  // ── FAB action per tab ──────────────────────────────────────────────────

  Future<void> _onFabPressed() async {
    final ct = _currentTab;
    if (ct == null) return;
    switch (ct) {
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
      title: 'New Department',
      builder: (ctx) =>
          CreateDepartmentSheet(schoolId: _schoolId, dao: DepartmentsDao(db)),
    );
  }

  Future<void> _pickStudentThenAddGuardian() async {
    if (!mounted) return;
    final picked = await showEduSheet<StudentsData>(
      context: context,
      builder: (ctx) => StudentPickerSheet(schoolId: _schoolId),
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
    final cs = Theme.of(context).colorScheme;

    if (_visibleTabs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outlined,
                size: 48,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No member access',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your role does not include permissions to view members.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canCreateForCurrentTab()
          ? _MembersFab(tab: _currentTab!, onPressed: _onFabPressed)
          : null,
      body: Column(
        children: [
          // ── Tab bar ────────────────────────────────────────────────────
          EduTabBar(
            controller: _tabController!,
            isScrollable: true,
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            tabs: [
              for (final tab in _visibleTabs) EduTab(label: _tabLabel(tab)),
            ],
          ),

          // ── Tab content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: [for (final tab in _visibleTabs) _buildTabContent(tab)],
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
    return FloatingActionButton.small(
      heroTag: 'fab_members',
      onPressed: onPressed,
      tooltip: _tooltip,
      elevation: 4,
      highlightElevation: 6,
      backgroundColor: Colors.green.shade600,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.add, size: 20),
    );
  }
}
