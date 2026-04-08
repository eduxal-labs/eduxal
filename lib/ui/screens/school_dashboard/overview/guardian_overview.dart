import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../models/grade_analytics.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/academics_dao.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../core/extensions.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/student_avatar.dart';
import '../../../widgets/today_status_card.dart';
import '../school_dashboard_screen.dart';
import 'overview_shared.dart';
import 'student_overview.dart';

// ═════════════════════════════════════════════════════════════════════════════
// GUARDIAN OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class GuardianOverview extends StatelessWidget {
  const GuardianOverview({
    super.key,
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final GuardianEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final ward = entry.ward;
    final userName = cache.currentUser?.user.name ?? 'Guardian';

    return RefreshIndicator(
      onRefresh: () async {
        sync.pushNow();
        await Future.delayed(const Duration(milliseconds: 800));
      },
      color: cs.primary,
      child: StaggeredList(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── 1. Welcome ───────────────────────────────────────────────────
          WelcomeCard(name: userName, subtitle: 'Guardian', cs: cs),

          const SizedBox(height: 16),

          // ── 1b. Ward attendance status ───────────────────────────────────
          if (term != null && termContext.isCurrentTermActive)
            StreamBuilder<Enrollment?>(
              stream: EnrollmentsDao(db).watchStudentEnrollment(
                schoolId: schoolId,
                year: term.year,
                term: term.term,
                studentAdm: ward.adm,
              ),
              builder: (context, enrollSnap) {
                if (!enrollSnap.hasData || enrollSnap.data == null) {
                  return const SizedBox.shrink();
                }
                final enrollment = enrollSnap.data!;
                final todayDays = DateTime.now()
                    .toUtc()
                    .difference(DateTime.utc(1970, 1, 1))
                    .inDays;

                return StreamBuilder<List<StudentAttendanceRow>>(
                  stream: AttendanceDao(db).watchClassAttendance(
                    schoolId: schoolId,
                    year: term.year,
                    term: term.term,
                    grade: enrollment.grade,
                    stream: enrollment.stream,
                    date: todayDays,
                  ),
                  builder: (context, attSnap) {
                    if (!attSnap.hasData) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TodayStatusCard(
                          type: TodayStatusType.neutral,
                          icon: Icons.schedule_rounded,
                          title: 'Checking attendance...',
                        ),
                      );
                    }

                    final wardRecord = attSnap.data!
                        .where((r) => r.student.adm == ward.adm)
                        .firstOrNull;

                    if (wardRecord == null || !wardRecord.isMarked) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TodayStatusCard(
                          type: TodayStatusType.neutral,
                          icon: Icons.hourglass_empty_rounded,
                          title: 'Attendance not yet taken',
                          subtitle:
                              '${ward.name}\'s class hasn\'t been marked today',
                        ),
                      );
                    }

                    final status = wardRecord.effectiveStatus;
                    final isPresent = status == AttendanceStatus.present;
                    final isAbsent = status == AttendanceStatus.absent;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TodayStatusCard(
                        type: isPresent
                            ? TodayStatusType.positive
                            : isAbsent
                            ? TodayStatusType.negative
                            : TodayStatusType.warning,
                        icon: isPresent
                            ? Icons.check_circle_rounded
                            : isAbsent
                            ? Icons.cancel_rounded
                            : Icons.info_rounded,
                        title: isPresent
                            ? '${ward.name} is present today'
                            : isAbsent
                            ? '${ward.name} is absent today'
                            : '${ward.name} is on leave today',
                      ),
                    );
                  },
                );
              },
            ),

          // ── 2. Ward info (enhanced) ──────────────────────────────────────
          _WardInfoCard(ward: ward, schoolId: schoolId, term: term),

          const SizedBox(height: 16),

          // ── Unenrolled ward banner ───────────────────────────────────────
          if (term != null)
            StreamBuilder<Enrollment?>(
              stream: EnrollmentsDao(db).watchStudentEnrollment(
                schoolId: schoolId,
                year: term.year,
                term: term.term,
                studentAdm: ward.adm,
              ),
              builder: (context, snap) {
                // Don't show banner while loading or if enrollment exists.
                if (snap.connectionState == ConnectionState.waiting ||
                    snap.data != null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ward.name} is not enrolled this term',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Please contact the school for enrollment details.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // ── 3. Quick stats (2×2 grid) ────────────────────────────────────
          if (term != null) ...[
            SectionTitle(label: 'Quick Stats', cs: cs),
            const SizedBox(height: 8),
            _GuardianQuickStats(
              schoolId: schoolId,
              term: term,
              studentAdm: ward.adm,
            ),
            const SizedBox(height: 20),
          ],

          // ── 4. Today's schedule ──────────────────────────────────────────
          if (term != null && termContext.isCurrentTermActive) ...[
            SectionTitle(
              label: "Today's Schedule",
              cs: cs,
              onViewAll: () =>
                  DashboardNavigation.goToTab(context, 'Timetable'),
            ),
            const SizedBox(height: 8),
            StudentTodaySchedule(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: ward.adm,
            ),
            const SizedBox(height: 20),
          ],

          // ── 5. Attendance summary ────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(
              label: 'Attendance',
              cs: cs,
              onViewAll: () =>
                  DashboardNavigation.goToTab(context, 'Attendance'),
            ),
            const SizedBox(height: 8),
            StudentAttendanceSummary(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: ward.adm,
            ),
            const SizedBox(height: 20),
          ],

          // ── 6. Recent grades ─────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(
              label: 'Recent Grades',
              cs: cs,
              onViewAll: () => DashboardNavigation.goToTab(context, 'Progress'),
            ),
            const SizedBox(height: 8),
            StudentRecentGrades(schoolId: schoolId, studentAdm: ward.adm),
            const SizedBox(height: 20),
          ],

          // ── 7. Finance summary ───────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(
              label: 'Finance',
              cs: cs,
              onViewAll: () => DashboardNavigation.goToTab(context, 'Finance'),
            ),
            const SizedBox(height: 8),
            _GuardianFinanceSummary(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: ward.adm,
            ),
            const SizedBox(height: 20),
          ],

          // ── 8. Recent announcements ──────────────────────────────────────
          SectionTitle(
            label: 'Recent Announcements',
            cs: cs,
            onViewAll: () =>
                DashboardNavigation.goToTab(context, 'Announcements'),
          ),
          const SizedBox(height: 8),
          RecentAnnouncements(
            schoolId: schoolId,
            audienceBit: AudienceBits.guardians,
            studentAdm: ward.adm,
            termYear: term?.year,
            termNum: term?.term,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _GuardianQuickStats extends StatelessWidget {
  const _GuardianQuickStats({
    required this.schoolId,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final Term term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final attendanceDao = AttendanceDao(db);
    final examsDao = ExamsGradesDao(db);
    final enrollmentsDao = EnrollmentsDao(db);
    final academicsDao = AcademicsDao(db);

    return LayoutBuilder(
      builder: (context, constraints) {
        final statWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // ── Attendance % ─────────────────────────────────────────────
            SizedBox(
              width: statWidth,
              child:
                  StreamBuilder<
                    ({int totalDays, int present, int absent, int leave})
                  >(
                    stream: attendanceDao.watchStudentAttendanceSummary(
                      schoolId: schoolId,
                      year: term.year,
                      term: term.term,
                      studentAdm: studentAdm,
                    ),
                    builder: (context, snap) {
                      final data = snap.data;
                      final pct = (data != null && data.totalDays > 0)
                          ? (data.present / data.totalDays * 100)
                          : null;
                      return StatCard(
                        icon: Icons.calendar_today_outlined,
                        label: 'Attendance',
                        value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
                        tint: pct != null
                            ? pctColor(pct)
                            : const Color(0xFF607D8B),
                      );
                    },
                  ),
            ),

            // ── Latest exam average ──────────────────────────────────────
            SizedBox(
              width: statWidth,
              child: StreamBuilder<List<Grade>>(
                stream: examsDao.watchStudentGrades(schoolId, studentAdm),
                builder: (context, snap) {
                  final allGrades = snap.data ?? [];
                  final byExam = <String, List<Grade>>{};
                  for (final g in allGrades) {
                    if (g.paper != null) continue;
                    (byExam[g.exam] ??= []).add(g);
                  }
                  double? pct;
                  if (byExam.isNotEmpty) {
                    final latestExamId = byExam.keys.reduce((a, b) {
                      final aMax = byExam[a]!
                          .map((g) => g.created)
                          .reduce((v, e) => v > e ? v : e);
                      final bMax = byExam[b]!
                          .map((g) => g.created)
                          .reduce((v, e) => v > e ? v : e);
                      return aMax > bMax ? a : b;
                    });
                    final grades = byExam[latestExamId]!;
                    final totalScore = grades.fold<double>(
                      0,
                      (s, g) => s + g.score,
                    );
                    final totalMax = grades.fold<double>(
                      0,
                      (s, g) => s + g.total,
                    );
                    if (totalMax > 0) pct = totalScore / totalMax * 100;
                  }
                  return StatCard(
                    icon: Icons.assignment_outlined,
                    label: 'Latest Exam',
                    value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
                    tint: pct != null ? pctColor(pct) : const Color(0xFF607D8B),
                  );
                },
              ),
            ),

            // ── Subjects count ───────────────────────────────────────────
            SizedBox(
              width: statWidth,
              child: StreamBuilder<Enrollment?>(
                stream: enrollmentsDao.watchStudentEnrollment(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                  studentAdm: studentAdm,
                ),
                builder: (context, enrollSnap) {
                  final enrollment = enrollSnap.data;
                  if (enrollment == null) {
                    return StatCard(
                      icon: Icons.menu_book_outlined,
                      label: 'Subjects',
                      value: '—',
                      tint: const Color(0xFF7C4DFF),
                    );
                  }
                  return StreamBuilder<List<SubjectTeacherEntry>>(
                    stream: academicsDao.watchSubjectsForGrade(
                      schoolId: schoolId,
                      year: term.year,
                      term: term.term,
                      grade: enrollment.grade,
                      stream: enrollment.stream,
                    ),
                    builder: (context, subSnap) {
                      final count = subSnap.data?.length ?? 0;
                      return StatCard(
                        icon: Icons.menu_book_outlined,
                        label: 'Subjects',
                        value: '$count',
                        tint: const Color(0xFF7C4DFF),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Mastery % ───────────────────────────────────────────────
            SizedBox(
              width: statWidth,
              child: StreamBuilder<List<MasteryData>>(
                stream: examsDao.watchMasteryForStudent(
                  schoolId: schoolId,
                  studentAdm: studentAdm,
                ),
                builder: (context, snap) {
                  final masteryRows = snap.data ?? [];
                  double? avgPct;
                  if (masteryRows.isNotEmpty) {
                    final totalScore = masteryRows.fold<double>(
                      0,
                      (s, m) => s + m.score,
                    );
                    avgPct = totalScore / masteryRows.length;
                  }
                  return StatCard(
                    icon: Icons.psychology_outlined,
                    label: 'Mastery',
                    value: avgPct != null
                        ? '${avgPct.toStringAsFixed(0)}%'
                        : '—',
                    tint: avgPct != null
                        ? pctColor(avgPct)
                        : const Color(0xFF607D8B),
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

class _WardInfoCard extends StatefulWidget {
  const _WardInfoCard({
    required this.ward,
    required this.schoolId,
    required this.term,
  });

  final StudentsData ward;
  final String schoolId;
  final Term? term;

  @override
  State<_WardInfoCard> createState() => _WardInfoCardState();
}

class _WardInfoCardState extends State<_WardInfoCard> {
  late Future<List<SchoolStream>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }

  @override
  void didUpdateWidget(covariant _WardInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          StudentAvatar(
            schoolId: widget.schoolId,
            adm: widget.ward.adm,
            name: widget.ward.name,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ward.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ADM: ${widget.ward.adm}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          if (widget.term != null)
            StreamBuilder<Enrollment?>(
              stream: EnrollmentsDao(db).watchStudentEnrollment(
                schoolId: widget.schoolId,
                year: widget.term!.year,
                term: widget.term!.term,
                studentAdm: widget.ward.adm,
              ),
              builder: (context, snap) {
                final enrollment = snap.data;
                if (enrollment == null) return const SizedBox.shrink();
                return FutureBuilder<List<SchoolStream>>(
                  future: _streamsFuture,
                  builder: (context, strSnap) {
                    final streamMap = <(int, int), String>{};
                    for (final s in strSnap.data ?? []) {
                      streamMap[(s.grade, s.stream)] = s.name;
                    }
                    final streamName =
                        streamMap[(enrollment.grade, enrollment.stream)];
                    final label = gradeStreamLabel(
                      enrollment.grade,
                      streamName: streamName,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
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

class _GuardianFinanceSummary extends StatelessWidget {
  const _GuardianFinanceSummary({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final financeDao = FinanceDao(db);

    return StreamBuilder<StudentFinanceSummary>(
      stream: financeDao.watchStudentFinanceSummary(
        schoolId: schoolId,
        studentAdm: studentAdm,
        year: year,
        term: term,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingShimmer();
        }

        final data = snap.data;
        if (data == null || data.invoices.isEmpty) {
          return EmptyCard(
            icon: Icons.receipt_long_outlined,
            message: 'No invoices this term',
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _FinanceRow(
                label: 'Total Invoiced',
                value: _fmtCurrency(data.totalInvoiced),
                cs: cs,
              ),
              const SizedBox(height: 8),
              _FinanceRow(
                label: 'Total Paid',
                value: _fmtCurrency(data.totalPaid),
                cs: cs,
                valueColor: const Color(0xFF4CAF50),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              _FinanceRow(
                label: 'Balance',
                value: _fmtCurrency(data.totalBalance),
                cs: cs,
                valueColor: data.totalBalance > 0
                    ? const Color(0xFFF44336)
                    : const Color(0xFF4CAF50),
                bold: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.label,
    required this.value,
    required this.cs,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: bold ? 0.8 : 0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

/// Formats a double amount as currency string.
String _fmtCurrency(double amount) {
  // Simple comma-separated formatting
  final wholePart = amount.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < wholePart.length; i++) {
    if (i > 0 && (wholePart.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(wholePart[i]);
  }
  return buf.toString();
}
