import 'package:flutter/material.dart';

import '../../../../core/extensions.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_empty_state.dart';
import '../../../widgets/student_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Progress Screen
//
// Shows a student's academic progress across 4 tabs:
//   1. Overview  — identity header, 2×2 stats grid, recent exam results
//   2. Exams     — exam list with per-paper scores for the student
//   3. Mastery   — subject-by-subject mastery progress bars
//   4. Attendance — monthly calendar with summary stats
//
// Supports both:
//   • GuardianEntry — scoped by ward.adm (guardian viewing ward's progress)
//   • StudentEntry  — scoped by student.adm (student viewing own progress)
// ─────────────────────────────────────────────────────────────────────────────

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: widget.schoolContext.currentEntry,
      builder: (context, entry, _) {
        // Extract the student data from either a GuardianEntry or StudentEntry.
        final StudentsData? student;
        if (entry is GuardianEntry) {
          student = entry.ward;
        } else if (entry is StudentEntry) {
          student = entry.student;
        } else {
          student = null;
        }

        if (student == null) {
          return const Center(
            child: Text(
              'This screen is only available for students and guardians.',
            ),
          );
        }

        final schoolId = widget.schoolContext.membership.school.id;

        return Column(
          children: [
            // ── Tab bar ────────────────────────────────────────────────────
            _ProgressTabBar(controller: _tabController),

            // ── Tab content ────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(
                    schoolId: schoolId,
                    student: student,
                    termContext: termCtx,
                  ),
                  _ExamsTab(
                    schoolId: schoolId,
                    student: student,
                    termContext: termCtx,
                  ),
                  _MasteryTab(schoolId: schoolId, student: student),
                  _AttendanceTab(
                    key: ValueKey('attendance_${student.adm}'),
                    schoolId: schoolId,
                    student: student,
                    termContext: termCtx,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB BAR — uses the same elevated-shadow style as EduTabBar
// ═════════════════════════════════════════════════════════════════════════════

class _ProgressTabBar extends StatelessWidget {
  const _ProgressTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.nestedBg(isDark, cs),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            splashBorderRadius: BorderRadius.circular(8),
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
                  blurRadius: 5,
                  offset: const Offset(0, 1.5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
                  blurRadius: 1,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
            labelColor: cs.onSurface,
            unselectedLabelColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.15,
            ),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            tabs: const [
              Tab(height: 30, text: 'Overview'),
              Tab(height: 30, text: 'Exams'),
              Tab(height: 30, text: 'Mastery'),
              Tab(height: 30, text: 'Attendance'),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.schoolId,
    required this.student,
    required this.termContext,
  });

  final String schoolId;
  final StudentsData student;
  final ActiveTermContext termContext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = termContext.currentTerm;

    if (term == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _StudentIdentityHeader(
                student: student,
                schoolId: schoolId,
                term: term,
              ),
              const SizedBox(height: 16),
              const EduEmptyState(
                icon: Icons.calendar_today_outlined,
                title: 'No terms configured',
                subtitle: 'Progress data will appear once a term is set up.',
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      );
    }

    // Single grades stream shared by all stat widgets and recent results
    return StreamBuilder<List<Grade>>(
      stream: ExamsGradesDao(db).watchStudentGrades(schoolId, student.adm),
      builder: (context, gradeSnap) {
        final grades = gradeSnap.data ?? [];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Student identity header ──────────────────────────────────
                _StudentIdentityHeader(
                  student: student,
                  schoolId: schoolId,
                  term: term,
                ),
                const SizedBox(height: 16),

                // ── 2×2 Stats grid ───────────────────────────────────────────
                _StatsGrid(
                  schoolId: schoolId,
                  student: student,
                  year: term.year,
                  term: term.term,
                  grades: grades,
                ),
                const SizedBox(height: 12),

                // ── Recent exam results ──────────────────────────────────────
                _SectionTitle(label: 'Recent Exam Results', cs: cs),
                const SizedBox(height: 8),
                _RecentExamResults(grades: grades),

                const SizedBox(height: 56),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Student Identity Header ──────────────────────────────────────────────────

class _StudentIdentityHeader extends StatelessWidget {
  const _StudentIdentityHeader({
    required this.student,
    required this.schoolId,
    required this.term,
  });

  final StudentsData student;
  final String schoolId;
  final Term? term;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Row(
        children: [
          StudentAvatar(
            schoolId: schoolId,
            adm: student.adm,
            name: student.name,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 14,
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
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (term != null)
            StreamBuilder<Enrollment?>(
              stream: EnrollmentsDao(db).watchStudentEnrollment(
                schoolId: schoolId,
                year: term!.year,
                term: term!.term,
                studentAdm: student.adm,
              ),
              builder: (context, snap) {
                final enrollment = snap.data;
                if (enrollment == null) return const SizedBox.shrink();
                return StreamBuilder<List<SchoolStream>>(
                  stream: CatalogDao(db).watchStreamsBySchoolAndGrade(
                    schoolId: schoolId,
                    grade: enrollment.grade,
                  ),
                  builder: (context, streamSnap) {
                    final streamName = streamSnap.data
                        ?.where((s) => s.stream == enrollment.stream)
                        .map((s) => s.name)
                        .firstOrNull;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        gradeStreamLabel(
                          enrollment.grade,
                          streamName: streamName,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── 2×2 Stats Grid ──────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.schoolId,
    required this.student,
    required this.year,
    required this.term,
    required this.grades,
  });

  final String schoolId;
  final StudentsData student;
  final int year;
  final int term;
  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AttendanceStat(
                schoolId: schoolId,
                studentAdm: student.adm,
                year: year,
                term: term,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _LatestExamAvgStat(grades: grades)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SubjectsCountStat(grades: grades)),
            const SizedBox(width: 8),
            Expanded(
              child: _ClassRankStat(
                schoolId: schoolId,
                studentAdm: student.adm,
                year: year,
                term: term,
                grades: grades,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StreamRankStat(
                schoolId: schoolId,
                studentAdm: student.adm,
                year: year,
                term: term,
                grades: grades,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.schoolId,
    required this.studentAdm,
    required this.year,
    required this.term,
  });

  final String schoolId;
  final int studentAdm;
  final int year;
  final int term;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({int totalDays, int present, int absent, int leave})>(
      stream: AttendanceDao(db).watchStudentAttendanceSummary(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snap) {
        final data = snap.data;
        final pct = (data != null && data.totalDays > 0)
            ? (data.present / data.totalDays * 100)
            : 0.0;
        return _StatCard(
          icon: Icons.calendar_today_outlined,
          label: 'Attendance',
          value: '${pct.toStringAsFixed(0)}%',
          tint: _pctColor(pct),
        );
      },
    );
  }
}

class _LatestExamAvgStat extends StatelessWidget {
  const _LatestExamAvgStat({required this.grades});

  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return const _StatCard(
        icon: Icons.assessment_outlined,
        label: 'Exam Average',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    // Group by exam, pick the latest exam, compute avg %
    final byExam = <String, List<Grade>>{};
    for (final g in grades) {
      if (g.paper != null) continue; // subject-level totals only
      (byExam[g.exam] ??= []).add(g);
    }

    // If no subject-level totals, fall back to all grades
    if (byExam.isEmpty) {
      for (final g in grades) {
        (byExam[g.exam] ??= []).add(g);
      }
    }

    if (byExam.isEmpty) {
      return const _StatCard(
        icon: Icons.assessment_outlined,
        label: 'Exam Average',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    // Find the latest exam by most recent grade created date
    String? latestExam;
    BigInt latestTime = BigInt.zero;
    for (final entry in byExam.entries) {
      final maxCreated = entry.value
          .map((g) => g.created)
          .reduce((a, b) => a > b ? a : b);
      if (maxCreated > latestTime) {
        latestTime = maxCreated;
        latestExam = entry.key;
      }
    }

    if (latestExam == null) {
      return const _StatCard(
        icon: Icons.assessment_outlined,
        label: 'Exam Average',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    final latestGrades = byExam[latestExam]!;
    final totalScore = latestGrades.fold<double>(0, (s, g) => s + g.score);
    final totalMax = latestGrades.fold<double>(0, (s, g) => s + g.total);
    final pct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

    return _StatCard(
      icon: Icons.assessment_outlined,
      label: 'Exam Average',
      value: '${pct.toStringAsFixed(0)}%',
      tint: _pctColor(pct),
    );
  }
}

class _SubjectsCountStat extends StatelessWidget {
  const _SubjectsCountStat({required this.grades});

  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    final subjectIds = grades.map((g) => g.subject).toSet();
    return _StatCard(
      icon: Icons.menu_book_outlined,
      label: 'Subjects',
      value: '${subjectIds.length}',
      tint: const Color(0xFF5C6BC0),
    );
  }
}

class _ClassRankStat extends StatelessWidget {
  const _ClassRankStat({
    required this.schoolId,
    required this.studentAdm,
    required this.year,
    required this.term,
    required this.grades,
  });

  final String schoolId;
  final int studentAdm;
  final int year;
  final int term;
  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    // Rank is computed from the latest exam: compare this student's total
    // to all other students in the same grade (across all streams).
    if (grades.isEmpty) {
      return const _StatCard(
        icon: Icons.leaderboard_outlined,
        label: 'Grade Rank',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    // Find latest exam by created date (subject-level grades only — paper == null)
    final byExam = <String, List<Grade>>{};
    for (final g in grades) {
      if (g.paper != null) continue;
      (byExam[g.exam] ??= []).add(g);
    }
    if (byExam.isEmpty) {
      for (final g in grades) {
        (byExam[g.exam] ??= []).add(g);
      }
    }
    if (byExam.isEmpty) {
      return const _StatCard(
        icon: Icons.leaderboard_outlined,
        label: 'Grade Rank',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    String? latestExam;
    BigInt latestTime = BigInt.zero;
    for (final entry in byExam.entries) {
      final maxCreated = entry.value
          .map((g) => g.created)
          .reduce((a, b) => a > b ? a : b);
      if (maxCreated > latestTime) {
        latestTime = maxCreated;
        latestExam = entry.key;
      }
    }

    if (latestExam == null) {
      return const _StatCard(
        icon: Icons.leaderboard_outlined,
        label: 'Grade Rank',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    // 1. Look up student's enrollment to determine their grade level
    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        final enrollment = enrollSnap.data;
        if (enrollment == null) {
          // Not enrolled — can't determine grade for ranking
          return const _StatCard(
            icon: Icons.leaderboard_outlined,
            label: 'Grade Rank',
            value: '—',
            tint: Color(0xFF607D8B),
          );
        }

        // 2. Get all grades for the latest exam
        return StreamBuilder<List<Grade>>(
          stream: ExamsGradesDao(
            db,
          ).watchClassGrades(schoolId: schoolId, examId: latestExam!),
          builder: (context, classSnap) {
            final classGrades = classSnap.data ?? [];
            if (classGrades.isEmpty) {
              return const _StatCard(
                icon: Icons.leaderboard_outlined,
                label: 'Grade Rank',
                value: '—',
                tint: Color(0xFF607D8B),
              );
            }

            // 3. Get enrolled students in the same grade (all streams)
            //    to scope ranking to the student's grade level
            return FutureBuilder<List<StudentsData>>(
              future: ExamsGradesDao(db).getEnrolledStudents(
                schoolId: schoolId,
                year: year,
                term: term,
                grade: enrollment.grade,
                // No stream filter — grade rank includes ALL streams
              ),
              builder: (context, enrolledSnap) {
                if (!enrolledSnap.hasData) {
                  return const _StatCard(
                    icon: Icons.leaderboard_outlined,
                    label: 'Grade Rank',
                    value: '…',
                    tint: Color(0xFF607D8B),
                  );
                }

                final enrolledAdms = {
                  for (final s in enrolledSnap.data!) s.adm,
                };

                // Sum scores per student (subject-level only — paper == null),
                // filtered to only students enrolled in the same grade.
                final studentTotals = <int, double>{};
                for (final g in classGrades) {
                  if (g.paper != null) continue;
                  if (!enrolledAdms.contains(g.student)) continue;
                  studentTotals[g.student] =
                      (studentTotals[g.student] ?? 0) + g.score;
                }

                // If no subject-level totals, fall back to all grades
                if (studentTotals.isEmpty) {
                  for (final g in classGrades) {
                    if (!enrolledAdms.contains(g.student)) continue;
                    studentTotals[g.student] =
                        (studentTotals[g.student] ?? 0) + g.score;
                  }
                }

                if (!studentTotals.containsKey(studentAdm)) {
                  return const _StatCard(
                    icon: Icons.leaderboard_outlined,
                    label: 'Grade Rank',
                    value: '—',
                    tint: Color(0xFF607D8B),
                  );
                }

                // 4. Tie-aware ranking (competition ranking — RANK() style):
                // Count how many students scored strictly higher, then add 1.
                // If 3 students tie at #1, all get rank 1; next gets rank 4.
                final targetScore = studentTotals[studentAdm]!;
                final rank =
                    studentTotals.values.where((s) => s > targetScore).length +
                    1;
                final total = studentTotals.length;

                return _StatCard(
                  icon: Icons.leaderboard_outlined,
                  label: 'Grade Rank',
                  value: '$rank / $total',
                  tint: const Color(0xFF26A69A),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Recent Exam Results ──────────────────────────────────────────────────────

class _StreamRankStat extends StatelessWidget {
  const _StreamRankStat({
    required this.schoolId,
    required this.studentAdm,
    required this.year,
    required this.term,
    required this.grades,
  });

  final String schoolId;
  final int studentAdm;
  final int year;
  final int term;
  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    // Stream rank: same logic as _ClassRankStat but filtered to the
    // student's specific stream, not the whole grade.
    if (grades.isEmpty) {
      return const _StatCard(
        icon: Icons.leaderboard_outlined,
        label: 'Stream Rank',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    // Find latest exam by created date (subject-level grades only — paper == null)
    final byExam = <String, List<Grade>>{};
    for (final g in grades) {
      if (g.paper != null) continue;
      (byExam[g.exam] ??= []).add(g);
    }
    if (byExam.isEmpty) {
      for (final g in grades) {
        (byExam[g.exam] ??= []).add(g);
      }
    }
    if (byExam.isEmpty) {
      return const _StatCard(
        icon: Icons.leaderboard_outlined,
        label: 'Stream Rank',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    String? latestExam;
    BigInt latestTime = BigInt.zero;
    for (final entry in byExam.entries) {
      final maxCreated = entry.value
          .map((g) => g.created)
          .reduce((a, b) => a > b ? a : b);
      if (maxCreated > latestTime) {
        latestTime = maxCreated;
        latestExam = entry.key;
      }
    }

    if (latestExam == null) {
      return const _StatCard(
        icon: Icons.leaderboard_outlined,
        label: 'Stream Rank',
        value: '—',
        tint: Color(0xFF607D8B),
      );
    }

    // 1. Look up student's enrollment to determine their grade and stream
    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        final enrollment = enrollSnap.data;
        if (enrollment == null) {
          // Not enrolled — can't determine stream for ranking
          return const _StatCard(
            icon: Icons.leaderboard_outlined,
            label: 'Stream Rank',
            value: '—',
            tint: Color(0xFF607D8B),
          );
        }

        // 2. Get all grades for the latest exam
        return StreamBuilder<List<Grade>>(
          stream: ExamsGradesDao(
            db,
          ).watchClassGrades(schoolId: schoolId, examId: latestExam!),
          builder: (context, classSnap) {
            final classGrades = classSnap.data ?? [];
            if (classGrades.isEmpty) {
              return const _StatCard(
                icon: Icons.leaderboard_outlined,
                label: 'Stream Rank',
                value: '—',
                tint: Color(0xFF607D8B),
              );
            }

            // 3. Get enrolled students in the same stream
            return FutureBuilder<List<StudentsData>>(
              future: ExamsGradesDao(db).getEnrolledStudents(
                schoolId: schoolId,
                year: year,
                term: term,
                grade: enrollment.grade,
                stream: enrollment.stream, // stream filter — unlike grade rank
              ),
              builder: (context, enrolledSnap) {
                if (!enrolledSnap.hasData) {
                  return const _StatCard(
                    icon: Icons.leaderboard_outlined,
                    label: 'Stream Rank',
                    value: '…',
                    tint: Color(0xFF607D8B),
                  );
                }

                final enrolledAdms = {
                  for (final s in enrolledSnap.data!) s.adm,
                };

                // Stream rank is only meaningful with multiple students
                if (enrolledAdms.length <= 1) {
                  return const _StatCard(
                    icon: Icons.leaderboard_outlined,
                    label: 'Stream Rank',
                    value: '—',
                    tint: Color(0xFF607D8B),
                  );
                }

                // Sum scores per student (subject-level only — paper == null),
                // filtered to only students enrolled in the same stream.
                final studentTotals = <int, double>{};
                for (final g in classGrades) {
                  if (g.paper != null) continue;
                  if (!enrolledAdms.contains(g.student)) continue;
                  studentTotals[g.student] =
                      (studentTotals[g.student] ?? 0) + g.score;
                }

                // If no subject-level totals, fall back to all grades
                if (studentTotals.isEmpty) {
                  for (final g in classGrades) {
                    if (!enrolledAdms.contains(g.student)) continue;
                    studentTotals[g.student] =
                        (studentTotals[g.student] ?? 0) + g.score;
                  }
                }

                if (!studentTotals.containsKey(studentAdm)) {
                  return const _StatCard(
                    icon: Icons.leaderboard_outlined,
                    label: 'Stream Rank',
                    value: '—',
                    tint: Color(0xFF607D8B),
                  );
                }

                // 4. Tie-aware ranking (competition ranking — RANK() style)
                final targetScore = studentTotals[studentAdm]!;
                final rank =
                    studentTotals.values.where((s) => s > targetScore).length +
                    1;
                final total = studentTotals.length;

                return _StatCard(
                  icon: Icons.leaderboard_outlined,
                  label: 'Stream Rank',
                  value: '$rank / $total',
                  tint: const Color(0xFF607D8B),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RecentExamResults extends StatefulWidget {
  const _RecentExamResults({required this.grades});

  final List<Grade> grades;

  @override
  State<_RecentExamResults> createState() => _RecentExamResultsState();
}

class _RecentExamResultsState extends State<_RecentExamResults> {
  late final ExamsGradesDao _examsDao;
  final Map<String, Exam?> _examCache = {};

  @override
  void initState() {
    super.initState();
    _examsDao = ExamsGradesDao(db);
  }

  Future<Exam?> _getExam(String examId) async {
    if (_examCache.containsKey(examId)) return _examCache[examId];
    final exam = await _examsDao.getExam(examId);
    _examCache[examId] = exam;
    return exam;
  }

  Future<Map<String, Exam?>> _resolveExams(List<String> examIds) async {
    final result = <String, Exam?>{};
    for (final id in examIds) {
      result[id] = await _getExam(id);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (widget.grades.isEmpty) {
      return const EduEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No exam results yet',
      );
    }

    // Subject-level totals (paper == null), grouped by exam
    final byExam = <String, List<Grade>>{};
    for (final g in widget.grades) {
      if (g.paper != null) continue;
      (byExam[g.exam] ??= []).add(g);
    }

    if (byExam.isEmpty) {
      for (final g in widget.grades) {
        (byExam[g.exam] ??= []).add(g);
      }
    }

    if (byExam.isEmpty) {
      return const EduEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No exam results yet',
      );
    }

    final examIds = byExam.keys.toList();
    examIds.sort((a, b) {
      final aMax = byExam[a]!
          .map((g) => g.created)
          .reduce((v, e) => v > e ? v : e);
      final bMax = byExam[b]!
          .map((g) => g.created)
          .reduce((v, e) => v > e ? v : e);
      return bMax.compareTo(aMax);
    });

    final recentExamIds = examIds.take(3).toList();

    return FutureBuilder<Map<String, Exam?>>(
      future: _resolveExams(recentExamIds),
      builder: (context, examSnap) {
        final examMap = examSnap.data ?? {};

        return Column(
          children: recentExamIds.map((examId) {
            final examGrades = byExam[examId]!;
            final totalScore = examGrades.fold<double>(
              0,
              (sum, g) => sum + g.score,
            );
            final totalMax = examGrades.fold<double>(
              0,
              (sum, g) => sum + g.total,
            );
            final pct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;
            final examName = examMap[examId]?.name ?? 'Exam';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: AppTheme.nestedBg(isDark, cs),
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              examName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${examGrades.length} subject${examGrades.length == 1 ? '' : 's'} · ${totalScore.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PercentBadge(percent: pct, cs: cs),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — EXAMS
// ═════════════════════════════════════════════════════════════════════════════

class _ExamsTab extends StatefulWidget {
  const _ExamsTab({
    required this.schoolId,
    required this.student,
    required this.termContext,
  });

  final String schoolId;
  final StudentsData student;
  final ActiveTermContext termContext;

  @override
  State<_ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<_ExamsTab> {
  late final ExamsGradesDao _examsDao;
  final Map<String, Exam?> _examCache = {};

  @override
  void initState() {
    super.initState();
    _examsDao = ExamsGradesDao(db);
  }

  @override
  void didUpdateWidget(covariant _ExamsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.student.adm != widget.student.adm) {
      _examCache.clear();
    }
  }

  Future<Exam?> _getExam(String examId) async {
    if (_examCache.containsKey(examId)) return _examCache[examId];
    final exam = await _examsDao.getExam(examId);
    _examCache[examId] = exam;
    return exam;
  }

  Future<Map<String, Exam?>> _resolveExams(List<String> examIds) async {
    final result = <String, Exam?>{};
    for (final id in examIds) {
      result[id] = await _getExam(id);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final term = widget.termContext.currentTerm;

    if (term == null) {
      return const EduEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No terms configured',
        subtitle: 'Progress data will appear once a term is set up.',
      );
    }

    // Watch grades for the student, then group by exam
    return StreamBuilder<List<Grade>>(
      stream: _examsDao.watchStudentGrades(widget.schoolId, widget.student.adm),
      builder: (context, gradesSnap) {
        if (gradesSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        }

        final allGrades = gradesSnap.data ?? [];
        if (allGrades.isEmpty) {
          return const Center(
            child: EduEmptyState(
              icon: Icons.quiz_outlined,
              title: 'No exam results available',
            ),
          );
        }

        // Group grades by exam
        final byExam = <String, List<Grade>>{};
        for (final g in allGrades) {
          (byExam[g.exam] ??= []).add(g);
        }

        // Sort exams by most recent first
        final examIds = byExam.keys.toList();
        examIds.sort((a, b) {
          final aMax = byExam[a]!
              .map((g) => g.created)
              .reduce((v, e) => v > e ? v : e);
          final bMax = byExam[b]!
              .map((g) => g.created)
              .reduce((v, e) => v > e ? v : e);
          return bMax.compareTo(aMax);
        });

        // Hoist subject names to avoid N+1 streams in exam cards
        return StreamBuilder<List<Subject>>(
          stream: CatalogDao(db).watchSubjects(),
          builder: (context, subSnap) {
            final Map<int, String> subjectNames = {
              for (final s in subSnap.data ?? []) s.id: s.name,
            };

            // Resolve exam metadata (names, types) using cache
            return FutureBuilder<Map<String, Exam?>>(
              future: _resolveExams(examIds),
              builder: (context, examSnap) {
                final examMap = examSnap.data ?? {};

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: examIds.length,
                      itemBuilder: (context, index) {
                        final examId = examIds[index];
                        final grades = byExam[examId]!;

                        return _ExamCard(
                          examId: examId,
                          schoolId: widget.schoolId,
                          exam: examMap[examId],
                          grades: grades,
                          subjectNames: subjectNames,
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ExamCard extends StatefulWidget {
  const _ExamCard({
    required this.examId,
    required this.schoolId,
    required this.grades,
    this.exam,
    required this.subjectNames,
  });

  final String examId;
  final String schoolId;
  final Exam? exam;
  final List<Grade> grades;
  final Map<int, String> subjectNames;

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Separate subject-level totals vs per-paper grades
    final subjectTotals = widget.grades.where((g) => g.paper == null).toList();
    final paperGrades = widget.grades.where((g) => g.paper != null).toList();

    // Use subject totals for display if available, otherwise paper grades
    final displayGrades = subjectTotals.isNotEmpty
        ? subjectTotals
        : paperGrades;

    // Compute overall percentage
    final totalScore = displayGrades.fold<double>(0, (s, g) => s + g.score);
    final totalMax = displayGrades.fold<double>(0, (s, g) => s + g.total);
    final overallPct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

    final examName = widget.exam?.name ?? 'Exam';
    final examType = widget.exam?.type;
    final subjectCount = displayGrades.length;

    return GestureDetector(
      onTap: displayGrades.isNotEmpty
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(color: AppTheme.borderColor(isDark, cs)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Exam header ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.quiz_outlined,
                    size: 16,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (examType != null) ...[
                            Text(
                              examType.name[0].toUpperCase() +
                                  examType.name.substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            Text(
                              '  ·  ',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ],
                          Text(
                            '$subjectCount subject${subjectCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _PercentBadge(percent: overallPct, cs: cs),
                if (displayGrades.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),

            // ── Expandable subject/paper rows ────────────────────────────
            if (_expanded && displayGrades.isNotEmpty) ...[
              const SizedBox(height: 12),

              ...displayGrades.asMap().entries.map((entry) {
                final idx = entry.key;
                final g = entry.value;
                final pct = g.total > 0 ? (g.score / g.total * 100) : 0.0;
                final name =
                    widget.subjectNames[g.subject] ?? 'Subject ${g.subject}';

                return Column(
                  children: [
                    if (idx > 0) AppTheme.tableRowDivider(isDark, cs),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.paper != null ? '$name (P${g.paper})' : name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${g.score.toStringAsFixed(0)} / ${g.total.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            child: _PercentBadge(percent: pct, cs: cs),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — MASTERY
// ═════════════════════════════════════════════════════════════════════════════

class _MasteryTab extends StatelessWidget {
  const _MasteryTab({required this.schoolId, required this.student});

  final String schoolId;
  final StudentsData student;

  /// Determines the curriculum type from a grade number.
  /// Grades ≥ 41 (Form 1–4) are unambiguously 8-4-4.
  /// Grades ≥ 9 (Grade 9–12) are unambiguously CBC.
  /// Grades 1–8 are ambiguous — default to CBC (the newer curriculum).
  static CurriculumType _curriculumForGrade(int grade) {
    if (grade >= 41) return CurriculumType.eightFourFour;
    if (grade >= 9) return CurriculumType.cbc;
    return CurriculumType.cbc;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examsDao = ExamsGradesDao(db);
    final catalogDao = CatalogDao(db);
    final enrollDao = EnrollmentsDao(db);

    // Step 1: Watch the student's enrollments to derive the curriculum type
    // from their most recent enrolled grade.
    return StreamBuilder<List<Enrollment>>(
      stream: enrollDao.watchAllEnrollmentsForStudent(
        schoolId: schoolId,
        studentAdm: student.adm,
      ),
      builder: (context, enrollSnap) {
        final enrollments = enrollSnap.data ?? [];
        final curriculum = enrollments.isNotEmpty
            ? _curriculumForGrade(enrollments.first.grade)
            : CurriculumType.cbc;

        // Step 2: Watch mastery data (already school + student scoped)
        return StreamBuilder<List<MasteryData>>(
          stream: examsDao.watchMasteryForStudent(
            schoolId: schoolId,
            studentAdm: student.adm,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              );
            }

            final allMastery = snap.data ?? [];
            if (allMastery.isEmpty) {
              return const Center(
                child: EduEmptyState(
                  icon: Icons.psychology_outlined,
                  title: 'No mastery data available yet',
                ),
              );
            }

            // Group by subject, then compute average score per subject
            final bySubject = <int, List<MasteryData>>{};
            for (final m in allMastery) {
              (bySubject[m.subject] ??= []).add(m);
            }

            final subjectIds = bySubject.keys.toList()..sort();

            // Step 3: Watch subjects filtered by the school's curriculum
            return StreamBuilder<List<Subject>>(
              stream: catalogDao.watchSubjectsByCurriculum(curriculum),
              builder: (context, subSnap) {
                final subjects = subSnap.data ?? [];

                // Step 4: Watch topics filtered by curriculum (joined with
                // subjects) instead of loading the entire global catalog.
                return StreamBuilder<List<Topic>>(
                  stream: catalogDao.watchTopicsByCurriculum(curriculum),
                  builder: (context, topicSnap) {
                    final Map<int, String> topicNames = {
                      for (final t in topicSnap.data ?? []) t.id: t.name,
                    };

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: subjectIds.length,
                          itemBuilder: (context, index) {
                            final subjectId = subjectIds[index];
                            final entries = bySubject[subjectId]!;
                            final subjectMatch = subjects
                                .where((s) => s.id == subjectId)
                                .firstOrNull;
                            final subjectName =
                                subjectMatch?.name ?? 'Subject $subjectId';

                            // Average mastery across all topics for this subject
                            final avgScore = entries.isEmpty
                                ? 0.0
                                : entries.fold<double>(
                                        0,
                                        (s, m) => s + m.score,
                                      ) /
                                      entries.length;
                            final pct = (avgScore * 100).clamp(0.0, 100.0);

                            return _MasterySubjectCard(
                              subjectName: subjectName,
                              pct: pct,
                              topicEntries: entries,
                              cs: cs,
                              subjectIndex: index,
                              topicNames: topicNames,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MasterySubjectCard extends StatelessWidget {
  const _MasterySubjectCard({
    required this.subjectName,
    required this.pct,
    required this.topicEntries,
    required this.cs,
    required this.subjectIndex,
    required this.topicNames,
  });

  final String subjectName;
  final double pct;
  final List<MasteryData> topicEntries;
  final ColorScheme cs;
  final int subjectIndex;
  final Map<int, String> topicNames;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final color = _pctColor(pct);
    final tint = _subjectColor(subjectIndex);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Subject header with overall progress ───────────────────────
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: tint.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Overall progress bar ───────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),

          // ── Per-topic breakdown ────────────────────────────────────────
          if (topicEntries.length > 1) ...[
            const SizedBox(height: 10),
            ...topicEntries.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              final topicPct = (m.score * 100).clamp(0.0, 100.0);
              final topicColor = _pctColor(topicPct);

              return Column(
                children: [
                  if (idx > 0) AppTheme.tableRowDivider(isDark, cs),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _MasteryTopicRow(
                      topicName: topicNames[m.topic] ?? 'Topic ${m.topic}',
                      pct: topicPct,
                      color: topicColor,
                      cs: cs,
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MasteryTopicRow extends StatelessWidget {
  const _MasteryTopicRow({
    required this.topicName,
    required this.pct,
    required this.color,
    required this.cs,
  });

  final String topicName;
  final double pct;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            topicName,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${pct.toStringAsFixed(0)}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — ATTENDANCE
// ═════════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({
    super.key,
    required this.schoolId,
    required this.student,
    required this.termContext,
  });

  final String schoolId;
  final StudentsData student;
  final ActiveTermContext termContext;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  late final AttendanceDao _dao;
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(db);
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
    if (nextMonth.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _calendarMonth = nextMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (term == null) {
      return const EduEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No terms configured',
        subtitle: 'Progress data will appear once a term is set up.',
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AttendanceSummaryBar(
                schoolId: widget.schoolId,
                year: term.year,
                term: term.term,
                studentAdm: widget.student.adm,
                dao: _dao,
                cs: cs,
              ),
            ),

            // ── Calendar ──────────────────────────────────────────────────────
            Expanded(
              child: _AttendanceCalendar(
                schoolId: widget.schoolId,
                year: term.year,
                term: term.term,
                studentAdm: widget.student.adm,
                calendarMonth: _calendarMonth,
                dao: _dao,
                cs: cs,
                onPreviousMonth: _previousMonth,
                onNextMonth: _nextMonth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attendance Summary Bar ───────────────────────────────────────────────────

class _AttendanceSummaryBar extends StatelessWidget {
  const _AttendanceSummaryBar({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
    required this.dao,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;
  final AttendanceDao dao;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<({int totalDays, int present, int absent, int leave})>(
      stream: dao.watchStudentAttendanceSummary(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final present = data?.present ?? 0;
        final absent = data?.absent ?? 0;
        final leave = data?.leave ?? 0;
        final total = present + absent + leave;
        final rate = total > 0 ? (present / total * 100) : 0.0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.nestedBg(isDark, cs),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
          ),
          child: Row(
            children: [
              // Attendance rate circle
              _RateCircle(rate: rate, cs: cs),
              const SizedBox(width: 16),

              // Stat pills
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _StatPill(
                      label: 'Present',
                      count: present,
                      color: _kPresentColor,
                      cs: cs,
                    ),
                    _StatPill(
                      label: 'Absent',
                      count: absent,
                      color: _kAbsentColor,
                      cs: cs,
                    ),
                    _StatPill(
                      label: 'Leave',
                      count: leave,
                      color: _kLeaveColor,
                      cs: cs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RateCircle extends StatelessWidget {
  const _RateCircle({required this.rate, required this.cs});

  final double rate;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = rate >= 80
        ? _kPresentColor
        : rate >= 60
        ? _kLeaveColor
        : _kAbsentColor;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: rate / 100,
            strokeWidth: 3.5,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            color: color,
          ),
          Center(
            child: Text(
              '${rate.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.count,
    required this.color,
    required this.cs,
  });

  final String label;
  final int count;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Attendance Calendar ──────────────────────────────────────────────────────

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
    required this.calendarMonth,
    required this.dao,
    required this.cs,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;
  final DateTime calendarMonth;
  final AttendanceDao dao;
  final ColorScheme cs;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentAttendanceRecord>>(
      stream: dao.watchStudentAttendanceHistory(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        final statusByDate = <int, AttendanceStatus>{};
        for (final r in records) {
          statusByDate[r.date] = r.status;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ── Month navigation ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: onPreviousMonth,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _fmtMonth(calendarMonth),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: onNextMonth,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Day-of-week headers ──────────────────────────────────────
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),

            // ── Calendar grid ─────────────────────────────────────────────
            _buildCalendarGrid(statusByDate),

            const SizedBox(height: 16),

            // ── Legend ─────────────────────────────────────────────────────
            _CalendarLegend(cs: cs),
          ],
        );
      },
    );
  }

  Widget _buildCalendarGrid(Map<int, AttendanceStatus> statusByDate) {
    final now = DateTime.now();
    final firstDay = DateTime(calendarMonth.year, calendarMonth.month, 1);
    final daysInMonth = DateTime(
      calendarMonth.year,
      calendarMonth.month + 1,
      0,
    ).day;
    final offset = (firstDay.weekday - 1) % 7;

    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - offset + 1;

            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 36));
            }

            final date = DateTime(
              calendarMonth.year,
              calendarMonth.month,
              dayNum,
            );
            final epochDays = _dateToEpochDays(date);
            final status = statusByDate[epochDays];
            final isToday = _isSameDay(date, now);
            final isFuture = date.isAfter(now);

            return Expanded(
              child: _CalendarDayCell(
                day: dayNum,
                status: status,
                isToday: isToday,
                isFuture: isFuture,
                cs: cs,
              ),
            );
          }),
        );
      }),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.status,
    required this.isToday,
    required this.isFuture,
    required this.cs,
  });

  final int day;
  final AttendanceStatus? status;
  final bool isToday;
  final bool isFuture;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    Color bgColor;
    Color textColor;

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.2);
    } else if (status != null) {
      switch (status!) {
        case AttendanceStatus.present:
          bgColor = _kPresentColor.withValues(alpha: isDark ? 0.25 : 0.15);
          textColor = _kPresentColor;
        case AttendanceStatus.absent:
          bgColor = _kAbsentColor.withValues(alpha: isDark ? 0.25 : 0.15);
          textColor = _kAbsentColor;
        case AttendanceStatus.leave:
          bgColor = _kLeaveColor.withValues(alpha: isDark ? 0.25 : 0.15);
          textColor = _kLeaveColor;
      }
    } else {
      bgColor = Colors.transparent;
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
    }

    return Container(
      height: 36,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
        border: isToday
            ? Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
            color: isToday ? cs.primary : textColor,
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(label: 'Present', color: _kPresentColor, cs: cs),
        const SizedBox(width: 16),
        _LegendItem(label: 'Absent', color: _kAbsentColor, cs: cs),
        const SizedBox(width: 16),
        _LegendItem(label: 'Leave', color: _kLeaveColor, cs: cs),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    required this.cs,
  });

  final String label;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: tint.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.percent, required this.cs});

  final double percent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = _pctColor(percent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        '${percent.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: cs.onSurface.withValues(alpha: 0.7),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: cs.onSurfaceVariant.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Attendance status colors — consistent with the main attendance screen.
const Color _kPresentColor = Color(0xFF4CAF50);
const Color _kAbsentColor = Color(0xFFEF5350);
const Color _kLeaveColor = Color(0xFFFFA726);

/// Percentage color: green >= 70, amber >= 40, red < 40.
Color _pctColor(double pct) {
  if (pct >= 70) return const Color(0xFF4CAF50);
  if (pct >= 40) return const Color(0xFFFFC107);
  return const Color(0xFFF44336);
}

/// Deterministic subject color from a 15-color palette.
Color _subjectColor(int subjectIndex) {
  const palette = [
    Color(0xFF3F51B5),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFF7C4DFF),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
    Color(0xFF795548),
    Color(0xFF9C27B0),
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFF2196F3),
    Color(0xFFCDDC39),
  ];
  return palette[subjectIndex % palette.length];
}

/// Converts a [DateTime] to days since Unix epoch.
int _dateToEpochDays(DateTime dt) {
  return DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/
      (1000 * 60 * 60 * 24);
}

/// Checks if two [DateTime] values represent the same calendar day.
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Formats a DateTime as "January 2025" full month name.
String _fmtMonth(DateTime d) => '${_monthsFull[d.month - 1]} ${d.year}';

const _monthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
