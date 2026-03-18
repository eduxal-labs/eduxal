import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/plans_dao.dart';

import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/curriculum_levels.dart';

import '../../../../services/member_management.dart';
import '../../../../services/members.dart';
import '../../../widgets/edu_confirm_dialog.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/inline_calendar.dart';
import '../../../widgets/member_creation/add_guardian_panel.dart';
import '../../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Student Detail Page — thin wrapper that opens StudentDetailSheet
// ─────────────────────────────────────────────────────────────────────────────

class StudentDetailPage extends StatefulWidget {
  const StudentDetailPage({
    super.key,
    required this.initialStudent,
    required this.schoolId,
  });

  final StudentsData initialStudent;
  final String schoolId;

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1720) : cs.surface,
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: StudentDetailSheet(
            initialStudent: widget.initialStudent,
            schoolId: widget.schoolId,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Detail Sheet — works as bottom-sheet, side-sheet, or embedded
// ─────────────────────────────────────────────────────────────────────────────

class StudentDetailSheet extends StatefulWidget {
  const StudentDetailSheet({
    super.key,
    required this.initialStudent,
    required this.schoolId,
    this.scrollController,
    this.isSideSheet = false,
  });

  final StudentsData initialStudent;
  final String schoolId;
  final ScrollController? scrollController;
  final bool isSideSheet;

  @override
  State<StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<StudentDetailSheet>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final MembersDao _membersDao;
  late final ExamsGradesDao _gradesDao;
  late final PlansDao _plansDao;

  late final MemberManagementService _service;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _membersDao = MembersDao(db);
    _gradesDao = ExamsGradesDao(db);
    _plansDao = PlansDao(db);

    _service = MemberManagementService(_membersDao);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _formatDaysSinceEpoch(int? days) {
    if (days == null) return null;
    final date = DateTime.utc(1970).add(Duration(days: days));
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<StudentsData?>(
      stream: _membersDao.watchStudent(
        widget.schoolId,
        widget.initialStudent.adm,
      ),
      builder: (context, snap) {
        final student = snap.data ?? widget.initialStudent;

        final body = Column(
          children: [
            // ── Drag handle (bottom-sheet only) ─────────────────────
            if (!widget.isSideSheet && widget.scrollController != null)
              Center(
                child: Container(
                  width: 36,
                  height: 3.5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // ── Compact header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  _StudentAvatarLarge(
                    schoolId: widget.schoolId,
                    adm: student.adm,
                    name: student.name,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ADM: ${student.adm}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: student.status, cs: cs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionIcon(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        color: cs.onSurfaceVariant,
                        onTap: () => _showEditSheet(student),
                      ),
                      if (student.status == StudentStatus.active)
                        _ActionIcon(
                          icon: Icons.swap_horiz_rounded,
                          tooltip: 'Change Status',
                          color: cs.onSurfaceVariant,
                          onTap: () => _showStatusSheet(student),
                        ),
                      _ActionIcon(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        color: cs.error.withValues(alpha: 0.7),
                        onTap: () => _confirmDelete(student),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tab bar (left-aligned) ──────────────────────────────
            EduTabBar(
              controller: _tabController,
              isScrollable: true,
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              tabs: const [
                EduTab(label: 'Info'),
                EduTab(label: 'Performance'),
                EduTab(label: 'Guardians'),
                EduTab(label: 'Subscriptions'),
              ],
            ),

            // ── Tab content ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InfoTab(
                    student: student,
                    membersDao: _membersDao,
                    formatDate: _formatDaysSinceEpoch,
                  ),
                  _PerformanceTab(
                    schoolId: widget.schoolId,
                    studentAdm: student.adm,
                    gradesDao: _gradesDao,
                  ),
                  _GuardiansTab(
                    schoolId: widget.schoolId,
                    studentAdm: student.adm,
                    studentName: student.name,
                    membersDao: _membersDao,
                    service: _service,
                  ),
                  _PlansTab(
                    schoolId: widget.schoolId,
                    studentAdm: student.adm,
                    plansDao: _plansDao,
                  ),
                ],
              ),
            ),
          ],
        );

        return Material(
          color: isDark ? const Color(0xFF18222E) : cs.surface,
          borderRadius: widget.isSideSheet
              ? const BorderRadius.horizontal(left: Radius.circular(12))
              : widget.scrollController != null
              ? const BorderRadius.vertical(top: Radius.circular(16))
              : BorderRadius.zero,
          child: SafeArea(
            top: widget.isSideSheet,
            child: SizedBox(
              width: widget.isSideSheet ? 420 : double.infinity,
              child: body,
            ),
          ),
        );
      },
    );
  }

  // ── Edit sheet ────────────────────────────────────────────────────────────

  void _showEditSheet(StudentsData student) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: student.name);
    Gender? gender = student.gender;
    DateTime? dob = student.dob != null
        ? DateTime.utc(1970).add(Duration(days: student.dob!))
        : null;
    File? imageFile;

    showEduSheet(
      context: context,
      title: 'Edit Student',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo section
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                          maxWidth: 800,
                        );
                        if (picked != null) {
                          setSheetState(() => imageFile = File(picked.path));
                        }
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: imageFile != null
                                ? FileImage(imageFile!) as ImageProvider
                                : null,
                            backgroundColor: cs.surfaceContainerHighest,
                            child: imageFile == null
                                ? FutureBuilder<File?>(
                                    future: FileCache.get(
                                      FileCache.studentImagePath(
                                        widget.schoolId,
                                        student.adm,
                                      ),
                                    ),
                                    builder: (context, snap) {
                                      final file = snap.data;
                                      if (file != null && file.existsSync()) {
                                        return CircleAvatar(
                                          radius: 36,
                                          backgroundImage: FileImage(file),
                                        );
                                      }
                                      return Icon(
                                        Icons.person,
                                        size: 32,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                      );
                                    },
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.surface, width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 12,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name field
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Name',
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

                  // DOB — inline calendar
                  InlineCalendar(
                    value: dob,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                    hint: 'Date of Birth',
                    icon: Icons.cake_outlined,
                    onChanged: (picked) {
                      setSheetState(() => dob = picked);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Gender selector
                  Row(
                    children: Gender.values.map((g) {
                      final selected = g == gender;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g.name),
                          selected: selected,
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                          selectedColor: cs.primary,
                          backgroundColor: isDark
                              ? const Color(0xFF1E2A38)
                              : cs.surfaceContainerLow,
                          side: BorderSide(
                            color: selected
                                ? cs.primary
                                : cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onSelected: (sel) {
                            if (sel) setSheetState(() => gender = g);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Save — compact, right-aligned
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim().isEmpty
                            ? null
                            : nameCtrl.text.trim();

                        await _service.updateStudent(
                          schoolId: widget.schoolId,
                          adm: student.adm,
                          name: name,
                          dob: dob,
                          gender: gender,
                        );

                        if (imageFile != null) {
                          final accountId = cache.currentUser?.user.id;
                          if (accountId != null) {
                            final creationService = MemberCreationService(
                              _membersDao,
                            );
                            await creationService.saveStudentImage(
                              schoolId: widget.schoolId,
                              adm: student.adm,
                              sourceFile: imageFile!,
                              accountId: accountId,
                            );
                          }
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Status sheet ──────────────────────────────────────────────────────────

  void _showStatusSheet(StudentsData student) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    showEduSheet(
      context: context,
      title: 'Change Status',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StudentStatus.values
                  .where((s) => s != StudentStatus.deleted)
                  .map((s) {
                    final isSelected = s == student.status;
                    return ChoiceChip(
                      label: Text(s.name),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                      selectedColor: cs.primary,
                      backgroundColor: isDark
                          ? const Color(0xFF1E2A38)
                          : cs.surfaceContainerLow,
                      side: BorderSide(
                        color: isSelected
                            ? cs.primary
                            : cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onSelected: (selected) async {
                        if (!selected || isSelected) return;
                        await _service.changeStudentStatus(
                          schoolId: widget.schoolId,
                          adm: student.adm,
                          status: s,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  })
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────

  void _confirmDelete(StudentsData student) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete Student',
      message:
          'Delete ${student.name} (Adm ${student.adm})? '
          'This will mark the student as deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    await _service.changeStudentStatus(
      schoolId: widget.schoolId,
      adm: student.adm,
      status: StudentStatus.deleted,
    );
    if (mounted) Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1: Info
// ═══════════════════════════════════════════════════════════════════════════════

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.student,
    required this.membersDao,
    required this.formatDate,
  });

  final StudentsData student;
  final MembersDao membersDao;
  final String? Function(int?) formatDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (student.gender != null)
            _DetailRow(label: 'Gender', value: student.gender!.name, cs: cs),
          if (student.dob != null)
            _DetailRow(
              label: 'Date of Birth',
              value: formatDate(student.dob) ?? '—',
              cs: cs,
            ),
          if (student.admitted != null)
            _DetailRow(
              label: 'Admitted',
              value: formatDate(student.admitted) ?? '—',
              cs: cs,
            ),
          _DetailRow(label: 'Status', value: student.status.name, cs: cs),

          // Linked user
          if (student.user != null) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'LINKED USER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<UsersData?>(
              future: membersDao.findUserById(student.user!),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  );
                }
                final user = snap.data;
                if (user == null) {
                  return _DetailRow(
                    label: 'User ID',
                    value: student.user!,
                    cs: cs,
                  );
                }
                return Column(
                  children: [
                    _DetailRow(label: 'Name', value: user.name, cs: cs),
                    _DetailRow(label: 'Phone', value: user.phone, cs: cs),
                    if (user.email != null)
                      _DetailRow(label: 'Email', value: user.email!, cs: cs),
                  ],
                );
              },
            ),
          ],

          // Documents
          if (student.documents != null && student.documents!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'DOCUMENTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Ref', value: student.documents!, cs: cs),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2: Performance
// ═══════════════════════════════════════════════════════════════════════════════

class _PerformanceTab extends StatefulWidget {
  const _PerformanceTab({
    required this.schoolId,
    required this.studentAdm,
    required this.gradesDao,
  });

  final String schoolId;
  final int studentAdm;
  final ExamsGradesDao gradesDao;

  @override
  State<_PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<_PerformanceTab>
    with AutomaticKeepAliveClientMixin {
  CurriculumType? _curriculumType;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        // ── Grades section ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'GRADES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        StreamBuilder<List<Grade>>(
          stream: widget.gradesDao.watchStudentGrades(
            widget.schoolId,
            widget.studentAdm,
          ),
          builder: (context, snap) {
            final grades = snap.data ?? [];
            if (grades.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptySection(
                  icon: Icons.assessment_outlined,
                  label: 'No grades yet',
                  cs: cs,
                ),
              );
            }

            // Group grades by exam
            final byExam = <String, List<Grade>>{};
            for (final g in grades) {
              byExam.putIfAbsent(g.exam, () => []).add(g);
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final examId = byExam.keys.elementAt(index);
                final examGrades = byExam[examId]!;

                return _ExamGradeGroup(
                  examId: examId,
                  grades: examGrades,
                  gradesDao: widget.gradesDao,
                  subjectName: _subjectName,
                  cs: cs,
                  isDark: isDark,
                );
              }, childCount: byExam.length),
            );
          },
        ),

        // ── Mastery section ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'MASTERY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        StreamBuilder<List<MasteryData>>(
          stream: widget.gradesDao.watchMasteryForStudent(
            schoolId: widget.schoolId,
            studentAdm: widget.studentAdm,
          ),
          builder: (context, snap) {
            final mastery = snap.data ?? [];
            if (mastery.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptySection(
                  icon: Icons.psychology_outlined,
                  label: 'No mastery data yet',
                  cs: cs,
                ),
              );
            }

            // Group by subject
            final bySubject = <int, List<MasteryData>>{};
            for (final m in mastery) {
              bySubject.putIfAbsent(m.subject, () => []).add(m);
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final subject = bySubject.keys.elementAt(index);
                final topics = bySubject[subject]!;

                return _MasterySubjectGroup(
                  subjectIndex: subject,
                  topics: topics,
                  subjectName: _subjectName,
                  cs: cs,
                  isDark: isDark,
                );
              }, childCount: bySubject.length),
            );
          },
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

// ── Grade group per exam ──────────────────────────────────────────────────

class _ExamGradeGroup extends StatelessWidget {
  const _ExamGradeGroup({
    required this.examId,
    required this.grades,
    required this.gradesDao,
    required this.subjectName,
    required this.cs,
    required this.isDark,
  });

  final String examId;
  final List<Grade> grades;
  final ExamsGradesDao gradesDao;
  final String Function(int) subjectName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Exam?>(
      future: gradesDao.getExam(examId),
      builder: (context, snap) {
        final exam = snap.data;
        final examLabel = exam != null
            ? '${exam.type.name.toUpperCase()} — Y${exam.year} T${exam.term}'
            : examId;

        // Only show subject-level totals (paper == null) if available,
        // otherwise show all grades.
        final subjectTotals = grades.where((g) => g.paper == null).toList();
        final displayGrades = subjectTotals.isNotEmpty ? subjectTotals : grades;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                examLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              ...displayGrades.map(
                (g) => _GradeRow(
                  label: subjectName(g.subject),
                  score: g.score,
                  total: g.total,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.label,
    required this.score,
    required this.total,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final double score;
  final int total;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (score / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1)}/$total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 4,
                backgroundColor: cs.onSurfaceVariant.withValues(
                  alpha: isDark ? 0.1 : 0.08,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _percentColor(percent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _percentColor(double p) {
    if (p >= 0.75) return Colors.green;
    if (p >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

// ── Mastery subject group ─────────────────────────────────────────────────

class _MasterySubjectGroup extends StatelessWidget {
  const _MasterySubjectGroup({
    required this.subjectIndex,
    required this.topics,
    required this.subjectName,
    required this.cs,
    required this.isDark,
  });

  final int subjectIndex;
  final List<MasteryData> topics;
  final String Function(int) subjectName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subjectName(subjectIndex),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...topics.map((m) {
            final score = m.score.clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Topic ${m.topic}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${(score * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: score,
                        minHeight: 4,
                        backgroundColor: cs.onSurfaceVariant.withValues(
                          alpha: isDark ? 0.1 : 0.08,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          score >= 0.75
                              ? Colors.green
                              : score >= 0.5
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 3: Guardians
// ═══════════════════════════════════════════════════════════════════════════════

class _GuardiansTab extends StatelessWidget {
  const _GuardiansTab({
    required this.schoolId,
    required this.studentAdm,
    required this.studentName,
    required this.membersDao,
    required this.service,
  });

  final String schoolId;
  final int studentAdm;
  final String studentName;
  final MembersDao membersDao;
  final MemberManagementService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<GuardiansData>>(
            stream: membersDao.watchGuardians(schoolId, studentAdm),
            builder: (context, snap) {
              final guardians = snap.data ?? [];

              if (guardians.isEmpty &&
                  snap.connectionState != ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.family_restroom_outlined,
                        size: 40,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No guardians linked',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                itemCount: guardians.length,
                itemBuilder: (context, index) {
                  final g = guardians[index];
                  return _GuardianRow(
                    guardian: g,
                    membersDao: membersDao,
                    cs: cs,
                    isDark: isDark,
                    onRemove: () => _confirmRemoveGuardian(context, g),
                  );
                },
              );
            },
          ),
        ),

        // Add Guardian button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showAddGuardianPanel(
                context: context,
                schoolId: schoolId,
                studentAdm: studentAdm,
                studentName: studentName,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Guardian',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRemoveGuardian(BuildContext context, GuardiansData g) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove Guardian',
      message:
          'Remove this guardian link from the student? '
          'The guardian\'s user account is not affected.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    await service.removeGuardian(
      schoolId: schoolId,
      userId: g.user,
      studentAdm: g.student,
    );
  }
}

class _GuardianRow extends StatelessWidget {
  const _GuardianRow({
    required this.guardian,
    required this.membersDao,
    required this.cs,
    required this.isDark,
    required this.onRemove,
  });

  final GuardiansData guardian;
  final MembersDao membersDao;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsersData?>(
      future: membersDao.findUserById(guardian.user),
      builder: (context, snap) {
        final user = snap.data;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.2),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              UserAvatar(userId: guardian.user, radius: 18),
              const SizedBox(width: 12),

              // Name + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '…',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          guardian.relationship.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        Text(
                          guardian.role.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        if (user != null) ...[
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          Text(
                            user.phone,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Remove button
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: cs.error.withValues(alpha: 0.7),
                ),
                splashRadius: 18,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 4: Plans (Subscriptions)
// ═══════════════════════════════════════════════════════════════════════════════

class _PlansTab extends StatelessWidget {
  const _PlansTab({
    required this.schoolId,
    required this.studentAdm,
    required this.plansDao,
  });

  final String schoolId;
  final int studentAdm;
  final PlansDao plansDao;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Subscription>>(
            stream: plansDao.watchStudentSubscriptions(schoolId, studentAdm),
            builder: (context, snap) {
              final subs = snap.data ?? [];

              if (subs.isEmpty &&
                  snap.connectionState != ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.card_membership_outlined,
                        size: 40,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No subscriptions yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  return _SubscriptionRow(
                    sub: subs[index],
                    plansDao: plansDao,
                    schoolId: schoolId,
                    studentAdm: studentAdm,
                    cs: cs,
                    isDark: isDark,
                  );
                },
              );
            },
          ),
        ),

        // Subscribe to Plan button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showSubscribeSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Subscribe to Plan',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSubscribeSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    showEduSheet(
      context: context,
      builder: (ctx) => _SubscribeSheet(
        schoolId: schoolId,
        studentAdm: studentAdm,
        plansDao: plansDao,
        cs: cs,
        isDark: isDark,
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.sub,
    required this.plansDao,
    required this.schoolId,
    required this.studentAdm,
    required this.cs,
    required this.isDark,
  });

  final Subscription sub;
  final PlansDao plansDao;
  final String schoolId;
  final int studentAdm;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Plan>>(
      future: plansDao.getActivePlans(),
      builder: (context, snap) {
        final plans = snap.data ?? [];
        final plan = plans.where((p) => p.id == sub.plan).firstOrNull;
        final planName = plan?.name ?? sub.plan;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.2),
            ),
          ),
          child: Row(
            children: [
              // Plan icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.card_membership_outlined,
                  size: 18,
                  color: cs.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Y${sub.year} T${sub.term}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        if (sub.discount > 0) ...[
                          Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          Text(
                            '${sub.discount.toStringAsFixed(sub.discount.truncateToDouble() == sub.discount ? 0 : 1)}% off',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.green.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status chip + tap to change
              InkWell(
                onTap: () => _showStatusPicker(context),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      sub.status,
                    ).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _statusColor(
                        sub.status,
                      ).withValues(alpha: isDark ? 0.25 : 0.2),
                    ),
                  ),
                  child: Text(
                    sub.status.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _statusColor(sub.status),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(SubscriptionStatus status) {
    return switch (status) {
      SubscriptionStatus.active => Colors.green,
      SubscriptionStatus.pending => Colors.orange,
      SubscriptionStatus.cancelled => Colors.red,
      SubscriptionStatus.deleted => Colors.grey,
    };
  }

  void _showStatusPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    showEduSheet(
      context: context,
      title: 'Change Status',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SubscriptionStatus.values.map((s) {
                final isSelected = s == sub.status;
                return ChoiceChip(
                  label: Text(s.name),
                  selected: isSelected,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  selectedColor: cs.primary,
                  backgroundColor: isDark
                      ? const Color(0xFF1E2A38)
                      : cs.surfaceContainerLow,
                  side: BorderSide(
                    color: isSelected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onSelected: (selected) async {
                    if (!selected || isSelected) return;
                    final accountId = cache.currentUser?.user.id;
                    if (accountId == null) return;
                    await plansDao.updateSubscriptionStatus(
                      schoolId: schoolId,
                      planId: sub.plan,
                      year: sub.year,
                      term: sub.term,
                      studentAdm: studentAdm,
                      status: s,
                      accountId: accountId,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subscribe sheet ─────────────────────────────────────────────────────────

class _SubscribeSheet extends StatefulWidget {
  const _SubscribeSheet({
    required this.schoolId,
    required this.studentAdm,
    required this.plansDao,
    required this.cs,
    required this.isDark,
  });

  final String schoolId;
  final int studentAdm;
  final PlansDao plansDao;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_SubscribeSheet> createState() => _SubscribeSheetState();
}

class _SubscribeSheetState extends State<_SubscribeSheet> {
  List<Plan> _plans = [];
  Plan? _selectedPlan;
  final _yearCtrl = TextEditingController();
  final _termCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await widget.plansDao.getActivePlans();
    if (mounted) setState(() => _plans = plans);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _termCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18222E) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 3.5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Subscribe to Plan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Plan selector
          if (_plans.isEmpty)
            Text(
              'No active plans available.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            )
          else ...[
            Text(
              'Select Plan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plans.map((p) {
                final selected = _selectedPlan?.id == p.id;
                return ChoiceChip(
                  label: Text(p.name),
                  selected: selected,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  selectedColor: cs.primary,
                  backgroundColor: isDark
                      ? const Color(0xFF1E2A38)
                      : cs.surfaceContainerLow,
                  side: BorderSide(
                    color: selected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedPlan = p);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Year + Term row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Year',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _termCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Term',
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
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Discount field
            TextField(
              controller: _discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(fontSize: 13.5, color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Discount %',
                hintText: '0',
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

            // Subscribe button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_selectedPlan == null || _saving)
                    ? null
                    : _subscribe,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Subscribe',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _subscribe() async {
    final plan = _selectedPlan;
    if (plan == null) return;
    final year = int.tryParse(_yearCtrl.text.trim());
    final term = int.tryParse(_termCtrl.text.trim());
    if (year == null || term == null) return;

    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving = true);

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.plansDao.createSubscription(
        sub: SubscriptionsCompanion(
          school: Value(widget.schoolId),
          plan: Value(plan.id),
          year: Value(year),
          term: Value(term),
          student: Value(widget.studentAdm),
          discount: Value(discount.clamp(0, 100)),
          status: const Value(SubscriptionStatus.pending),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        accountId: accountId,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared helper widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StudentAvatarLarge extends StatefulWidget {
  const _StudentAvatarLarge({
    required this.schoolId,
    required this.adm,
    required this.name,
  });

  final String schoolId;
  final int adm;
  final String name;

  @override
  State<_StudentAvatarLarge> createState() => _StudentAvatarLargeState();
}

class _StudentAvatarLargeState extends State<_StudentAvatarLarge> {
  late Future<File?> _future;
  late String _path;

  @override
  void initState() {
    super.initState();
    _path = FileCache.studentImagePath(widget.schoolId, widget.adm);
    _future = FileCache.get(_path);
    FileCacheNotifier.of(_path).addListener(_onFileChanged);
  }

  @override
  void didUpdateWidget(_StudentAvatarLarge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPath = FileCache.studentImagePath(widget.schoolId, widget.adm);
    if (newPath != _path) {
      FileCacheNotifier.of(_path).removeListener(_onFileChanged);
      _path = newPath;
      _future = FileCache.get(_path);
      FileCacheNotifier.of(_path).addListener(_onFileChanged);
    }
  }

  @override
  void dispose() {
    FileCacheNotifier.of(_path).removeListener(_onFileChanged);
    super.dispose();
  }

  void _onFileChanged() {
    setState(() {
      _future = FileCache.get(_path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initials(widget.name);

    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: 28,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        return CircleAvatar(
          radius: 28,
          backgroundColor: cs.surfaceContainerHighest,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 15,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs});

  final StudentStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final color = _statusColor(status, cs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            status.name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(StudentStatus status, ColorScheme cs) {
    return switch (status) {
      StudentStatus.active => Colors.green,
      StudentStatus.expelled => cs.error,
      StudentStatus.graduated => cs.tertiary,
      StudentStatus.transferred => Colors.orange,
      StudentStatus.withdrawn => Colors.deepOrange,
      StudentStatus.deleted => cs.onSurfaceVariant,
    };
  }
}

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

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action icon button ────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
