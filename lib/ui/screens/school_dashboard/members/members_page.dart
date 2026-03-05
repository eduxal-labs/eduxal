import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/status_indicator.dart';
import '../../../widgets/user_avatar.dart';
import '../../../widgets/member_creation/add_guardian_panel.dart';
import '../../../widgets/member_creation/add_owner_panel.dart';
import '../../../widgets/member_creation/add_staff_panel.dart';
import '../../../widgets/member_creation/add_student_panel.dart';
import '../../../widgets/member_creation/add_teacher_panel.dart';

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

enum _MemberTab { owners, teachers, staff, students, guardians }

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
  _MemberTab _currentTab = _MemberTab.owners;

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

  Future<void> _pickStudentThenAddGuardian() async {
    final students =
        await (db.select(db.students)
              ..where(
                (t) =>
                    t.school.equals(_schoolId) &
                    t.status.equals(StudentStatus.active.index),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.adm)]))
            .get();

    if (students.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a student first before linking a guardian.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    final picked = await showModalBottomSheet<StudentsData>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StudentPickerSheet(students: students),
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
            tabs: const [
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
    _MemberTab.owners => 'Add Owner',
    _MemberTab.teachers => 'Add Teacher',
    _MemberTab.staff => 'Add Staff',
    _MemberTab.students => 'Add Student',
    _MemberTab.guardians => 'Add Guardian',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: _tooltip,
      elevation: isDark ? 4 : 2,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.add, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owners tab
// ─────────────────────────────────────────────────────────────────────────────

class _OwnersTab extends StatelessWidget {
  const _OwnersTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OwnersData>>(
      stream: dao.watchOwners(schoolId),
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
        return _MemberListView(
          itemCount: owners.length,
          itemBuilder: (context, i) {
            final owner = owners[i];
            return _OwnerRow(schoolId: schoolId, owner: owner);
          },
        );
      },
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({required this.schoolId, required this.owner});
  final String schoolId;
  final OwnersData owner;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsersData?>(
      future: MembersDao(db).findUserById(owner.user),
      builder: (context, snap) {
        final user = snap.data;
        return _MemberTile(
          userId: owner.user,
          name: user?.name ?? '…',
          subtitle: user?.phone ?? '',
          status: user?.status,
          level: user?.level,
          onTap: () => _openDetail(context, user),
        );
      },
    );
  }

  void _openDetail(BuildContext context, UsersData? user) {
    if (user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MemberDetailStub(
          user: user,
          roleLabel: 'Owner',
          schoolId: schoolId,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Teachers tab
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersTab extends StatelessWidget {
  const _TeachersTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeachersData>>(
      stream: dao.watchTeachers(schoolId),
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
        return _MemberListView(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            return _TeacherRow(schoolId: schoolId, teacher: t);
          },
        );
      },
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({required this.schoolId, required this.teacher});
  final String schoolId;
  final TeachersData teacher;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsersData?>(
      future: MembersDao(db).findUserById(teacher.user),
      builder: (context, snap) {
        final user = snap.data;
        final parts = <String>[];
        if (user?.phone != null) parts.add(user!.phone);
        if (teacher.department != null) parts.add(teacher.department!);
        if (teacher.role != null) parts.add(teacher.role!);

        return _MemberTile(
          userId: teacher.user,
          name: user?.name ?? '…',
          subtitle: parts.join('  ·  '),
          status: user?.status,
          level: user?.level,
          trailing: _statusChip(context, teacher.status),
          onTap: () {
            if (user == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _MemberDetailStub(
                  user: user,
                  roleLabel: 'Teacher',
                  schoolId: schoolId,
                  extra: {
                    if (teacher.role != null) 'Role': teacher.role!,
                    if (teacher.department != null)
                      'Department': teacher.department!,
                    'Status': teacher.status.name,
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget? _statusChip(BuildContext context, TeacherStatus status) {
    if (status == TeacherStatus.active) return null;
    final cs = Theme.of(context).colorScheme;
    return _SmallChip(label: status.name, cs: cs);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff tab
// ─────────────────────────────────────────────────────────────────────────────

class _StaffTab extends StatelessWidget {
  const _StaffTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffData>>(
      stream: dao.watchStaff(schoolId),
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
        return _MemberListView(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final s = list[i];
            return _StaffRow(schoolId: schoolId, member: s);
          },
        );
      },
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.schoolId, required this.member});
  final String schoolId;
  final StaffData member;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsersData?>(
      future: MembersDao(db).findUserById(member.user),
      builder: (context, snap) {
        final user = snap.data;
        final parts = <String>[];
        if (user?.phone != null) parts.add(user!.phone);
        if (member.department != null) parts.add(member.department!);
        if (member.role != null) parts.add(member.role!);

        return _MemberTile(
          userId: member.user,
          name: user?.name ?? '…',
          subtitle: parts.join('  ·  '),
          status: user?.status,
          level: user?.level,
          trailing: _statusChip(context, member.status),
          onTap: () {
            if (user == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _MemberDetailStub(
                  user: user,
                  roleLabel: 'Staff',
                  schoolId: schoolId,
                  extra: {
                    if (member.role != null) 'Role': member.role!,
                    if (member.department != null)
                      'Department': member.department!,
                    'Status': member.status.name,
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget? _statusChip(BuildContext context, StaffStatus status) {
    if (status == StaffStatus.active) return null;
    final cs = Theme.of(context).colorScheme;
    return _SmallChip(label: status.name, cs: cs);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Students tab
// ─────────────────────────────────────────────────────────────────────────────

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentsData>>(
      stream: dao.watchStudents(schoolId),
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
        return _MemberListView(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final s = list[i];
            return _StudentRow(schoolId: schoolId, student: s);
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

    final subtitle = 'Adm #${student.adm}';

    return _BaseTile(
      leading: _StudentAvatar(
        schoolId: schoolId,
        adm: student.adm,
        name: student.name,
        status: student.status,
      ),
      name: student.name,
      subtitle: subtitle,
      trailing: student.status != StudentStatus.active
          ? _SmallChip(label: student.status.name, cs: cs)
          : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                _StudentDetailStub(student: student, schoolId: schoolId),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardians tab
// ─────────────────────────────────────────────────────────────────────────────

class _GuardiansTab extends StatelessWidget {
  const _GuardiansTab({required this.schoolId, required this.dao});

  final String schoolId;
  final MembersDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GuardiansData>>(
      stream: dao.watchAllGuardians(schoolId),
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
        return _MemberListView(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final g = list[i];
            return _GuardianRow(schoolId: schoolId, guardian: g);
          },
        );
      },
    );
  }
}

class _GuardianRow extends StatelessWidget {
  const _GuardianRow({required this.schoolId, required this.guardian});
  final String schoolId;
  final GuardiansData guardian;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GuardianResolved?>(
      future: _resolve(),
      builder: (context, snap) {
        final resolved = snap.data;
        final user = resolved?.user;
        final ward = resolved?.ward;

        final parts = <String>[];
        if (user?.phone != null) parts.add(user!.phone);
        if (ward != null) parts.add('Ward: ${ward.name}');
        parts.add(guardian.relationship.name);

        return _MemberTile(
          userId: guardian.user,
          name: user?.name ?? '…',
          subtitle: parts.join('  ·  '),
          status: user?.status,
          level: user?.level,
          trailing: _roleChip(context, guardian.role),
          onTap: () {
            if (user == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _MemberDetailStub(
                  user: user,
                  roleLabel: 'Guardian',
                  schoolId: schoolId,
                  extra: {
                    'Relationship': guardian.relationship.name,
                    'Role': guardian.role.name,
                    if (ward != null) 'Ward': ward.name,
                    if (ward != null) 'Ward Adm': '${ward.adm}',
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_GuardianResolved?> _resolve() async {
    final membersDao = MembersDao(db);
    final user = await membersDao.findUserById(guardian.user);
    final ward = await membersDao.getStudent(schoolId, guardian.student);
    if (user == null) return null;
    return _GuardianResolved(user: user, ward: ward);
  }

  Widget? _roleChip(BuildContext context, GuardianRole role) {
    if (role == GuardianRole.primary) return null;
    final cs = Theme.of(context).colorScheme;
    return _SmallChip(label: role.name, cs: cs);
  }
}

class _GuardianResolved {
  const _GuardianResolved({required this.user, this.ward});
  final UsersData user;
  final StudentsData? ward;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared member tile — user-based rows (Owners, Teachers, Staff, Guardians)
// ─────────────────────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.userId,
    required this.name,
    required this.subtitle,
    this.status,
    this.level,
    this.trailing,
    this.onTap,
  });

  final String userId;
  final String name;
  final String subtitle;
  final UserStatus? status;
  final UserLevel? level;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    Widget avatar = UserAvatar(userId: userId, radius: 20);

    // Overlay status indicator on avatar if available.
    if (status != null && level != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -1,
            right: -1,
            child: StatusIndicator(
              status: status!,
              level: level!,
              backgroundColor: isDark ? const Color(0xFF18222E) : cs.surface,
            ),
          ),
        ],
      );
    }

    return _BaseTile(
      leading: avatar,
      name: name,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Base tile — shared layout for user & student rows
// ─────────────────────────────────────────────────────────────────────────────

class _BaseTile extends StatelessWidget {
  const _BaseTile({
    required this.leading,
    required this.name,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              leading,
              const SizedBox(width: 14),

              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: 0.05,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing widget (chip or nothing)
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
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

    return CircleAvatar(
      radius: 20,
      backgroundColor: cs.surfaceContainerHighest,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
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
// Reusable list view wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _MemberListView extends StatelessWidget {
  const _MemberListView({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
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

class _StudentPickerSheet extends StatelessWidget {
  const _StudentPickerSheet({required this.students});

  final List<StudentsData> students;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
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
          const Divider(height: 1),
          // List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              itemCount: students.length,
              itemBuilder: (context, i) {
                final s = students[i];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Text(
                      _StudentAvatar._initials(s.name),
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
                    'Adm #${s.adm}',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Member detail stub — placeholder until full detail pages are built
// ─────────────────────────────────────────────────────────────────────────────

class _MemberDetailStub extends StatelessWidget {
  const _MemberDetailStub({
    required this.user,
    required this.roleLabel,
    required this.schoolId,
    this.extra = const {},
  });

  final UsersData user;
  final String roleLabel;
  final String schoolId;
  final Map<String, String> extra;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1720) : cs.surface,
      appBar: AppBar(
        title: Text(
          roleLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            UserAvatar(userId: user.id, radius: 40),
            const SizedBox(height: 16),

            // Name
            Text(
              user.name,
              style: TextStyle(
                fontSize: 18,
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

            // Status + level row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusIndicator(
                  status: user.status,
                  level: user.level,
                  backgroundColor: isDark
                      ? const Color(0xFF0F1720)
                      : cs.surface,
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

            // Extra info
            if (extra.isNotEmpty) ...[
              ...extra.entries.map(
                (e) => _DetailRow(label: e.key, value: e.value, cs: cs),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentDetailStub extends StatelessWidget {
  const _StudentDetailStub({required this.student, required this.schoolId});

  final StudentsData student;
  final String schoolId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1720) : cs.surface,
      appBar: AppBar(
        title: Text(
          'Student',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _StudentAvatar(
              schoolId: schoolId,
              adm: student.adm,
              name: student.name,
              status: student.status,
            ),
            const SizedBox(height: 16),

            Text(
              student.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Adm #${student.adm}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            _SmallChip(label: student.status.name, cs: cs),

            const SizedBox(height: 24),

            if (student.gender != null)
              _DetailRow(label: 'Gender', value: student.gender!.name, cs: cs),
            _DetailRow(label: 'Status', value: student.status.name, cs: cs),
          ],
        ),
      ),
    );
  }
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
