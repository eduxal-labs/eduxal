import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/grade_analytics.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/edu_tab_bar.dart';
import 'student_tabs/student_attendance_tab.dart';
import 'student_tabs/student_exams_tab.dart';
import 'student_tabs/student_mastery_tab.dart';
import 'student_tabs/student_overview_tab.dart';

/// Detail page for a single student within a grade/stream context.
///
/// Shows a compact header card (avatar + name + ADM + status), a slim
/// trajectory banner computed from the last two exams, and four content
/// tabs: Overview, Mastery, Exams, Attendance.
///
/// Opened from [StudentsTab] when a student row is tapped.
class StudentGradePage extends StatefulWidget {
  const StudentGradePage({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.studentAdm,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final int studentAdm;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  @override
  State<StudentGradePage> createState() => _StudentGradePageState();
}

class _StudentGradePageState extends State<StudentGradePage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final MembersDao _membersDao;
  late final ExamsGradesDao _examsGradesDao;

  late Stream<StudentsData?> _studentStream;
  late Stream<Trajectory> _trajectoryStream;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  static const _tabs = <EduTab>[
    EduTab(label: 'Overview'),
    EduTab(label: 'Mastery'),
    EduTab(label: 'Exams'),
    EduTab(label: 'Attendance'),
  ];

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

    _tabController = TabController(length: _tabs.length, vsync: this);
    _membersDao = MembersDao(db);
    _examsGradesDao = ExamsGradesDao(db);
    _studentStream = _membersDao.watchStudent(
      widget.schoolId,
      widget.studentAdm,
    );
    _trajectoryStream = _buildTrajectoryStream();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Computes trajectory from the student's grades by comparing the last two
  /// exam averages. Emits a new [Trajectory] whenever grades change.
  Stream<Trajectory> _buildTrajectoryStream() {
    return _examsGradesDao
        .watchStudentGrades(widget.schoolId, widget.studentAdm)
        .map(_computeTrajectory);
  }

  Trajectory _computeTrajectory(List<Grade> grades) {
    if (grades.length < 2) return Trajectory.insufficientData;

    // grades are ordered desc by created — index 0 is the most recent.
    // Group grades by exam and compute per-exam averages.
    final byExam = <String, List<double>>{};
    for (final g in grades) {
      byExam.putIfAbsent(g.exam, () => []).add(g.score);
    }

    if (byExam.length < 2) return Trajectory.insufficientData;

    // We need the two most recent exams. Since grades are ordered desc by
    // created, the first exam id we encounter is the most recent.
    final examIds = <String>[];
    final seen = <String>{};
    for (final g in grades) {
      if (seen.add(g.exam)) examIds.add(g.exam);
      if (examIds.length == 2) break;
    }

    final latestAvg =
        byExam[examIds[0]]!.reduce((a, b) => a + b) /
        byExam[examIds[0]]!.length;
    final previousAvg =
        byExam[examIds[1]]!.reduce((a, b) => a + b) /
        byExam[examIds[1]]!.length;

    final delta = latestAvg - previousAvg;
    if (delta > 1.0) return Trajectory.improving;
    if (delta < -1.0) return Trajectory.declining;
    return Trajectory.stable;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: StreamBuilder<StudentsData?>(
          stream: _studentStream,
          builder: (context, snapshot) {
            final name = snapshot.data?.name;
            return Text(
              name ?? 'Student',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Student header card ──────────────────────────────────────────
              Container(
                color: cs.surface,
                child: StreamBuilder<StudentsData?>(
                  stream: _studentStream,
                  builder: (context, snapshot) {
                    final student = snapshot.data;
                    if (student == null) {
                      return const SizedBox(height: 60);
                    }
                    return _buildHeaderCard(cs, isDark, student);
                  },
                ),
              ),

              // ── Trajectory banner ────────────────────────────────────────────
              StreamBuilder<Trajectory>(
                stream: _trajectoryStream,
                builder: (context, snapshot) {
                  final trajectory =
                      snapshot.data ?? Trajectory.insufficientData;
                  return _buildTrajectoryBanner(cs, isDark, trajectory);
                },
              ),

              // ── Content tabs ─────────────────────────────────────────────────
              Container(
                color: cs.surface,
                child: EduTabBar(
                  controller: _tabController,
                  tabs: _tabs,
                  isScrollable: true,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────────
              Container(
                height: 1,
                color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
              ),

              // ── Tab content ──────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    StudentOverviewTab(
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: widget.grade,
                      streamCode: widget.streamCode,
                      studentAdm: widget.studentAdm,
                      curriculumType: widget.curriculumType,
                    ),
                    StudentMasteryTab(
                      schoolId: widget.schoolId,
                      studentAdm: widget.studentAdm,
                      grade: widget.grade,
                      curriculumType: widget.curriculumType,
                    ),
                    StudentExamsTab(
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: widget.grade,
                      streamCode: widget.streamCode,
                      studentAdm: widget.studentAdm,
                      curriculumType: widget.curriculumType,
                    ),
                    StudentAttendanceTab(
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: widget.grade,
                      streamCode: widget.streamCode,
                      studentAdm: widget.studentAdm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header card ────────────────────────────────────────────────────────────

  Widget _buildHeaderCard(ColorScheme cs, bool isDark, StudentsData student) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // ── Avatar ─────────────────────────────────────────────────────
          _StudentAvatar(schoolId: widget.schoolId, adm: student.adm, cs: cs),

          const SizedBox(width: 12),

          // ── Name + ADM ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ADM: ${student.adm} · ${widget.streamName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Status chip ────────────────────────────────────────────────
          _StatusChip(status: student.status, cs: cs, isDark: isDark),
        ],
      ),
    );
  }

  // ── Trajectory banner ──────────────────────────────────────────────────────

  Widget _buildTrajectoryBanner(
    ColorScheme cs,
    bool isDark,
    Trajectory trajectory,
  ) {
    final (icon, label, color) = switch (trajectory) {
      Trajectory.improving => (
        Icons.trending_up_rounded,
        'Improving',
        const Color(0xFF4CAF50),
      ),
      Trajectory.declining => (
        Icons.trending_down_rounded,
        'Declining',
        const Color(0xFFF44336),
      ),
      Trajectory.stable => (
        Icons.trending_flat_rounded,
        'Stable',
        const Color(0xFFFFA726),
      ),
      Trajectory.insufficientData => (
        Icons.show_chart_rounded,
        'Insufficient exam data',
        cs.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    };

    return Container(
      color: color.withValues(alpha: isDark ? 0.10 : 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Student Avatar (cached file-based) ──────────────────────────────────────

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({
    required this.schoolId,
    required this.adm,
    required this.cs,
  });

  final String schoolId;
  final int adm;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.studentImagePath(schoolId, adm)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: 24,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        return CircleAvatar(
          radius: 24,
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        );
      },
    );
  }
}

// ─── Status chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.cs,
    required this.isDark,
  });

  final StudentStatus status;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      StudentStatus.active => ('Active', const Color(0xFF4CAF50)),
      StudentStatus.expelled => ('Expelled', const Color(0xFFF44336)),
      StudentStatus.graduated => ('Graduated', const Color(0xFF7E57C2)),
      StudentStatus.transferred => ('Transferred', const Color(0xFF42A5F5)),
      StudentStatus.withdrawn => ('Withdrawn', const Color(0xFFFFA726)),
      StudentStatus.deleted => (
        'Deleted',
        cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
