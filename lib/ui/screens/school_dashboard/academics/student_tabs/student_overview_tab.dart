import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/attendance_dao.dart';
import '../../../../../database/daos/exams_grades_dao.dart';
import '../../../../../database/daos/subjects_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../models/curriculum_levels.dart';

/// Overview tab for the Student Grade Page — an "at a glance" view of the
/// student's academic standing within a specific grade/stream context.
///
/// Shows:
/// 1. Quick Stats Row — subjects count, exams taken, average score, mastery
/// 2. Recent Exam Performance — last 3 exams with scores and progress bars
/// 3. Subject Mastery Summary — compact list with mastery bars
/// 4. Attendance Summary — present/absent/leave donut-style stats
class StudentOverviewTab extends StatefulWidget {
  const StudentOverviewTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.studentAdm,
    required this.curriculumType,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final int studentAdm;
  final CurriculumType curriculumType;

  @override
  State<StudentOverviewTab> createState() => _StudentOverviewTabState();
}

class _StudentOverviewTabState extends State<StudentOverviewTab>
    with AutomaticKeepAliveClientMixin {
  late final ExamsGradesDao _examsGradesDao;
  late final AttendanceDao _attendanceDao;
  late final SubjectsDao _subjectsDao;

  late Stream<List<Grade>> _gradesStream;
  late Stream<List<MasteryData>> _masteryStream;
  late Stream<({int totalDays, int present, int absent, int leave})>
  _attendanceStream;
  late Stream<List<({SubjectTeacher subject, UsersData teacher})>>
  _subjectsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _examsGradesDao = ExamsGradesDao(db);
    _attendanceDao = AttendanceDao(db);
    _subjectsDao = SubjectsDao(db);
    _buildStreams();
  }

  @override
  void didUpdateWidget(covariant StudentOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode ||
        oldWidget.studentAdm != widget.studentAdm) {
      setState(_buildStreams);
    }
  }

  void _buildStreams() {
    _gradesStream = _examsGradesDao.watchStudentGrades(
      widget.schoolId,
      widget.studentAdm,
    );
    _masteryStream = _examsGradesDao.watchMasteryForStudent(
      schoolId: widget.schoolId,
      studentAdm: widget.studentAdm,
    );
    _attendanceStream = _attendanceDao.watchStudentAttendanceSummary(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      studentAdm: widget.studentAdm,
    );
    _subjectsStream = _subjectsDao.watchSubjectsForClass(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // We nest multiple StreamBuilders. The outermost two (grades + subjects)
    // drive the Quick Stats row and Recent Exam Performance. Mastery and
    // attendance are independent sections further down.
    return StreamBuilder<List<({SubjectTeacher subject, UsersData teacher})>>(
      stream: _subjectsStream,
      builder: (context, subjectsSnap) {
        return StreamBuilder<List<Grade>>(
          stream: _gradesStream,
          builder: (context, gradesSnap) {
            final subjects = subjectsSnap.data ?? [];
            final grades = gradesSnap.data ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // ── 1. Quick Stats Row ────────────────────────────────────
                _QuickStatsRow(
                  cs: cs,
                  isDark: isDark,
                  subjectCount: subjects.length,
                  grades: grades,
                  masteryStream: _masteryStream,
                  currentGrade: widget.grade,
                ),

                const SizedBox(height: 20),

                // ── 2. Recent Exam Performance ────────────────────────────
                _SectionTitle(cs: cs, title: 'Recent Exams'),
                const SizedBox(height: 8),
                _RecentExamsSection(
                  cs: cs,
                  isDark: isDark,
                  grades: grades,
                  curriculumType: widget.curriculumType,
                ),

                const SizedBox(height: 20),

                // ── 3. Subject Mastery Summary ────────────────────────────
                _SectionTitle(cs: cs, title: 'Subject Mastery'),
                const SizedBox(height: 8),
                StreamBuilder<List<MasteryData>>(
                  stream: _masteryStream,
                  builder: (context, masterySnap) {
                    return _SubjectMasterySection(
                      cs: cs,
                      isDark: isDark,
                      mastery: masterySnap.data ?? [],
                      currentGrade: widget.grade,
                      curriculumType: widget.curriculumType,
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ── 4. Attendance Summary ─────────────────────────────────
                _SectionTitle(cs: cs, title: 'Attendance'),
                const SizedBox(height: 8),
                StreamBuilder<
                  ({int totalDays, int present, int absent, int leave})
                >(
                  stream: _attendanceStream,
                  builder: (context, attendanceSnap) {
                    return _AttendanceSummarySection(
                      cs: cs,
                      isDark: isDark,
                      data: attendanceSnap.data,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Section Title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.cs, required this.title});

  final ColorScheme cs;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        letterSpacing: 0.3,
      ),
    );
  }
}

// ─── 1. Quick Stats Row ──────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.cs,
    required this.isDark,
    required this.subjectCount,
    required this.grades,
    required this.masteryStream,
    required this.currentGrade,
  });

  final ColorScheme cs;
  final bool isDark;
  final int subjectCount;
  final List<Grade> grades;
  final Stream<List<MasteryData>> masteryStream;
  final int currentGrade;

  @override
  Widget build(BuildContext context) {
    // Compute grades stats.
    final examIds = <String>{};
    double totalPct = 0;
    int gradeCount = 0;
    for (final g in grades) {
      // Only count subject-level totals (paper == null) for unique exam count
      // and averaging.
      if (g.paper == null) {
        examIds.add(g.exam);
        if (g.total > 0) {
          totalPct += (g.score / g.total) * 100;
          gradeCount++;
        }
      }
    }
    // If no subject-level totals, fall back to all grades for stats.
    if (gradeCount == 0) {
      for (final g in grades) {
        examIds.add(g.exam);
        if (g.total > 0) {
          totalPct += (g.score / g.total) * 100;
          gradeCount++;
        }
      }
    }

    final avgScore = gradeCount > 0 ? totalPct / gradeCount : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatCard(
            cs: cs,
            isDark: isDark,
            icon: Icons.menu_book_outlined,
            label: 'Subjects',
            value: '$subjectCount',
            color: const Color(0xFF5C6BC0),
          ),
          const SizedBox(width: 8),
          _StatCard(
            cs: cs,
            isDark: isDark,
            icon: Icons.assignment_outlined,
            label: 'Exams Taken',
            value: '${examIds.length}',
            color: const Color(0xFF26A69A),
          ),
          const SizedBox(width: 8),
          _StatCard(
            cs: cs,
            isDark: isDark,
            icon: Icons.insights_outlined,
            label: 'Average',
            value: avgScore != null ? '${avgScore.round()}%' : '—',
            color: avgScore != null
                ? _percentColor(avgScore)
                : cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          // Mastery card needs its own stream.
          StreamBuilder<List<MasteryData>>(
            stream: masteryStream,
            builder: (context, snap) {
              final mastery = snap.data ?? [];
              // Filter to current grade only.
              final gradeFiltered = mastery;
              double? masteryAvg;
              if (gradeFiltered.isNotEmpty) {
                double total = 0;
                for (final m in gradeFiltered) {
                  total += m.score;
                }
                masteryAvg = (total / gradeFiltered.length) * 100;
              }
              return _StatCard(
                cs: cs,
                isDark: isDark,
                icon: Icons.psychology_outlined,
                label: 'Mastery',
                value: masteryAvg != null ? '${masteryAvg.round()}%' : '—',
                color: masteryAvg != null
                    ? _masteryColor(masteryAvg)
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.cs,
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final ColorScheme cs;
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 2. Recent Exams Section ─────────────────────────────────────────────────

class _RecentExamsSection extends StatelessWidget {
  const _RecentExamsSection({
    required this.cs,
    required this.isDark,
    required this.grades,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final List<Grade> grades;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return _buildEmpty('No exam results yet');
    }

    // Group grades by exam — prefer subject-level totals (paper == null).
    final byExam = <String, List<Grade>>{};
    for (final g in grades) {
      if (g.paper == null) {
        byExam.putIfAbsent(g.exam, () => []).add(g);
      }
    }
    // Fallback: if no subject-level totals, use all grades.
    if (byExam.isEmpty) {
      for (final g in grades) {
        byExam.putIfAbsent(g.exam, () => []).add(g);
      }
    }

    if (byExam.isEmpty) {
      return _buildEmpty('No exam results yet');
    }

    // Determine exam order by most recent grade created date.
    final examOrder = byExam.keys.toList()
      ..sort((a, b) {
        final aMax = byExam[a]!
            .map((g) => g.created.toInt())
            .reduce((v, e) => v > e ? v : e);
        final bMax = byExam[b]!
            .map((g) => g.created.toInt())
            .reduce((v, e) => v > e ? v : e);
        return bMax.compareTo(aMax); // descending
      });

    // Take last 3 exams.
    final recentExams = examOrder.take(3).toList();

    return Column(
      children: [
        for (int i = 0; i < recentExams.length; i++) ...[
          _ExamRow(
            cs: cs,
            isDark: isDark,
            examId: recentExams[i],
            grades: byExam[recentExams[i]]!,
            curriculumType: curriculumType,
          ),
          if (i < recentExams.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Exam Row ────────────────────────────────────────────────────────────────

class _ExamRow extends StatelessWidget {
  const _ExamRow({
    required this.cs,
    required this.isDark,
    required this.examId,
    required this.grades,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final String examId;
  final List<Grade> grades;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    // Compute totals across all subjects.
    double totalScore = 0;
    int totalPossible = 0;
    for (final g in grades) {
      totalScore += g.score;
      totalPossible += g.total;
    }
    final percent = totalPossible > 0
        ? (totalScore / totalPossible) * 100
        : 0.0;
    final color = _percentColor(percent);

    // Build a compact subject summary.
    final subjectLabels = grades.map((g) {
      return subjectLabel(curriculumType, g.subject);
    }).toList();
    final subjectSummary = subjectLabels.length <= 3
        ? subjectLabels.join(', ')
        : '${subjectLabels.take(3).join(', ')} +${subjectLabels.length - 3}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: subjects summary + score.
          Row(
            children: [
              Expanded(
                child: Text(
                  subjectSummary,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${totalScore.toStringAsFixed(0)}/${totalPossible}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${percent.round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar.
          _ThinProgressBar(
            percent: percent / 100,
            color: color,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            height: 3,
          ),
        ],
      ),
    );
  }
}

// ─── 3. Subject Mastery Section ──────────────────────────────────────────────

class _SubjectMasterySection extends StatelessWidget {
  const _SubjectMasterySection({
    required this.cs,
    required this.isDark,
    required this.mastery,
    required this.currentGrade,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final List<MasteryData> mastery;
  final int currentGrade;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    // Filter mastery to current grade.
    final gradeFiltered = mastery;

    if (gradeFiltered.isEmpty) {
      return _buildEmpty();
    }

    // Group by subject and compute average mastery per subject.
    final bySubject = <int, List<double>>{};
    for (final m in gradeFiltered) {
      bySubject.putIfAbsent(m.subject, () => []).add(m.score);
    }

    // Sort by subject index.
    final sortedKeys = bySubject.keys.toList()..sort();

    return Column(
      children: [
        for (int i = 0; i < sortedKeys.length; i++) ...[
          _MasteryRow(
            cs: cs,
            isDark: isDark,
            subjectIndex: sortedKeys[i],
            scores: bySubject[sortedKeys[i]]!,
            curriculumType: curriculumType,
          ),
          if (i < sortedKeys.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            'No mastery data recorded yet',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mastery Row ─────────────────────────────────────────────────────────────

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.cs,
    required this.isDark,
    required this.subjectIndex,
    required this.scores,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final int subjectIndex;
  final List<double> scores;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final pct = avg * 100; // scores are 0.0–1.0
    final color = _masteryColor(pct);
    final label = subjectLabel(curriculumType, subjectIndex);

    return Tooltip(
      message: 'See Mastery tab for details',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: _ThinProgressBar(
                percent: avg.clamp(0.0, 1.0),
                color: color,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                height: 3,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '${pct.round()}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 4. Attendance Summary Section ───────────────────────────────────────────

class _AttendanceSummarySection extends StatelessWidget {
  const _AttendanceSummarySection({
    required this.cs,
    required this.isDark,
    this.data,
  });

  final ColorScheme cs;
  final bool isDark;
  final ({int totalDays, int present, int absent, int leave})? data;

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.totalDays == 0) {
      return _buildEmpty();
    }

    final d = data!;
    final presentPct = d.totalDays > 0 ? (d.present / d.totalDays) * 100 : 0.0;
    final absentPct = d.totalDays > 0 ? (d.absent / d.totalDays) * 100 : 0.0;
    final leavePct = d.totalDays > 0 ? (d.leave / d.totalDays) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stacked bar showing proportion.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (d.present > 0)
                    Expanded(
                      flex: d.present,
                      child: Container(color: const Color(0xFF4CAF50)),
                    ),
                  if (d.absent > 0)
                    Expanded(
                      flex: d.absent,
                      child: Container(color: const Color(0xFFF44336)),
                    ),
                  if (d.leave > 0)
                    Expanded(
                      flex: d.leave,
                      child: Container(color: const Color(0xFFFFA726)),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Stats row.
          Row(
            children: [
              _AttendanceStat(
                cs: cs,
                label: 'Present',
                count: d.present,
                percent: presentPct,
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 16),
              _AttendanceStat(
                cs: cs,
                label: 'Absent',
                count: d.absent,
                percent: absentPct,
                color: const Color(0xFFF44336),
              ),
              const SizedBox(width: 16),
              _AttendanceStat(
                cs: cs,
                label: 'Leave',
                count: d.leave,
                percent: leavePct,
                color: const Color(0xFFFFA726),
              ),
              const Spacer(),
              // Total days.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${d.totalDays}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'days',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            'No attendance records this term',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attendance Stat ─────────────────────────────────────────────────────────

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.cs,
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  final ColorScheme cs;
  final String label;
  final int count;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${percent.round()}%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Thin Progress Bar ───────────────────────────────────────────────────────

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.percent,
    required this.color,
    required this.backgroundColor,
    this.height = 3,
  });

  /// 0.0 – 1.0
  final double percent;
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: backgroundColor),
            FractionallySizedBox(
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Color Helpers ───────────────────────────────────────────────────────────

Color _percentColor(double p) {
  if (p >= 70) return const Color(0xFF4CAF50);
  if (p >= 40) return const Color(0xFFFFA726);
  return const Color(0xFFF44336);
}

Color _masteryColor(double p) {
  if (p >= 80) return const Color(0xFF4CAF50);
  if (p >= 60) return const Color(0xFFFFC107);
  if (p >= 40) return const Color(0xFFFF9800);
  return const Color(0xFFF44336);
}
