import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../core/extensions.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/countdown_chip.dart';
import '../../../widgets/today_status_card.dart';
import '../school_dashboard_screen.dart';
import 'overview_shared.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STUDENT OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class StudentOverview extends StatelessWidget {
  const StudentOverview({
    super.key,
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final StudentEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final studentAdm = entry.student.adm;
    final studentName = entry.student.name;

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
          // ── Welcome ──────────────────────────────────────────────────────
          WelcomeCard(name: studentName, subtitle: 'Student', cs: cs),

          const SizedBox(height: 16),

          // ── Today's attendance status ────────────────────────────────────
          if (term != null && termContext.isCurrentTermActive) ...[
            _StudentTodayAttendance(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: studentAdm,
              studentName: studentName,
            ),
            const SizedBox(height: 12),
          ],

          // ── Next class countdown ─────────────────────────────────────────
          if (term != null && termContext.isCurrentTermActive) ...[
            _StudentNextClass(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: studentAdm,
            ),
            const SizedBox(height: 16),
          ],

          // ── Enrollment info ──────────────────────────────────────────────
          if (term != null) ...[
            _StudentEnrollmentInfo(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: studentAdm,
            ),
            const SizedBox(height: 16),
          ],

          // ── Today's schedule ─────────────────────────────────────────────
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
              studentAdm: studentAdm,
            ),
            const SizedBox(height: 20),
          ],

          // ── Recent grades ────────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(
              label: 'Recent Grades',
              cs: cs,
              onViewAll: () => DashboardNavigation.goToTab(context, 'Grades'),
            ),
            const SizedBox(height: 8),
            StudentRecentGrades(schoolId: schoolId, studentAdm: studentAdm),
            const SizedBox(height: 20),
          ],

          // ── Upcoming exams ───────────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(
              label: 'Upcoming Exams',
              cs: cs,
              onViewAll: () => DashboardNavigation.goToTab(context, 'Grades'),
            ),
            const SizedBox(height: 8),
            _StudentUpcomingExams(
              schoolId: schoolId,
              term: term,
              studentAdm: studentAdm,
            ),
            const SizedBox(height: 20),
          ],

          // ── Attendance summary ───────────────────────────────────────────
          if (term != null) ...[
            SectionTitle(
              label: 'Attendance',
              cs: cs,
              onViewAll: () => DashboardNavigation.goToTab(context, 'Grades'),
            ),
            const SizedBox(height: 8),
            StudentAttendanceSummary(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
              studentAdm: studentAdm,
            ),
            const SizedBox(height: 20),
          ],

          // ── Recent announcements ─────────────────────────────────────────
          SectionTitle(
            label: 'Recent Announcements',
            cs: cs,
            onViewAll: () =>
                DashboardNavigation.goToTab(context, 'Announcements'),
          ),
          const SizedBox(height: 8),
          RecentAnnouncements(
            schoolId: schoolId,
            audienceBit: AudienceBits.students,
            studentAdm: studentAdm,
            termYear: term?.year,
            termNum: term?.term,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _StudentNextClass extends StatelessWidget {
  const _StudentNextClass({
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
    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        if (!enrollSnap.hasData || enrollSnap.data == null) {
          return const SizedBox.shrink();
        }
        final enrollment = enrollSnap.data!;

        return StreamBuilder<List<TimetableEntry>>(
          stream: TimetableDao(db).watchClassTimetable(
            schoolId: schoolId,
            year: year,
            term: term,
            grade: enrollment.grade,
            stream: enrollment.stream,
          ),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();

            final todayDay = currentDayOfWeek();
            final now = DateTime.now();
            final nowSec = now.hour * 3600 + now.minute * 60 + now.second;

            final todaySlots =
                snap.data!
                    .where((e) => e.slot.day == todayDay && e.slot.end > nowSec)
                    .toList()
                  ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

            if (todaySlots.isEmpty) return const SizedBox.shrink();

            final next = todaySlots.firstWhere(
              (e) => e.slot.start > nowSec,
              orElse: () => todaySlots.first,
            );

            final isInProgress =
                next.slot.start <= nowSec && next.slot.end > nowSec;

            if (isInProgress) {
              return TodayStatusCard(
                type: TodayStatusType.positive,
                icon: Icons.play_circle_rounded,
                title: '${next.subjectName} in progress',
                subtitle:
                    '${fmtTime(next.slot.start)} – ${fmtTime(next.slot.end)}',
                trailing: CountdownChip(
                  label: 'Ends',
                  targetTime: todayAtSeconds(next.slot.end),
                  icon: Icons.timer_outlined,
                  compact: true,
                ),
              );
            }

            return TodayStatusCard(
              type: TodayStatusType.neutral,
              icon: Icons.schedule_rounded,
              title: 'Next: ${next.subjectName}',
              subtitle:
                  '${fmtTime(next.slot.start)} – ${fmtTime(next.slot.end)}',
              trailing: CountdownChip(
                label: 'Starts',
                targetTime: todayAtSeconds(next.slot.start),
                icon: Icons.timer_outlined,
                compact: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentTodayAttendance extends StatelessWidget {
  const _StudentTodayAttendance({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.studentAdm,
    required this.studentName,
  });

  final String schoolId;
  final int year;
  final int term;
  final int studentAdm;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
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
            year: year,
            term: term,
            grade: enrollment.grade,
            stream: enrollment.stream,
            date: todayDays,
          ),
          builder: (context, attSnap) {
            if (!attSnap.hasData) {
              return TodayStatusCard(
                type: TodayStatusType.neutral,
                icon: Icons.schedule_rounded,
                title: 'Checking attendance...',
              );
            }

            final myRecord = attSnap.data!
                .where((r) => r.student.adm == studentAdm)
                .firstOrNull;

            if (myRecord == null || !myRecord.isMarked) {
              return TodayStatusCard(
                type: TodayStatusType.neutral,
                icon: Icons.hourglass_empty_rounded,
                title: 'Attendance not yet taken',
                subtitle: 'Your class hasn\'t been marked today',
              );
            }

            final status = myRecord.effectiveStatus;
            final isPresent = status == AttendanceStatus.present;
            final isAbsent = status == AttendanceStatus.absent;

            return TodayStatusCard(
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
                  ? 'You are marked present today'
                  : isAbsent
                  ? 'You are marked absent today'
                  : 'You are on leave today',
            );
          },
        );
      },
    );
  }
}

class _StudentUpcomingExams extends StatefulWidget {
  const _StudentUpcomingExams({
    required this.schoolId,
    required this.term,
    required this.studentAdm,
  });

  final String schoolId;
  final Term term;
  final int studentAdm;

  @override
  State<_StudentUpcomingExams> createState() => _StudentUpcomingExamsState();
}

class _StudentUpcomingExamsState extends State<_StudentUpcomingExams> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = CatalogDao(db).getSubjects();
  }

  @override
  void didUpdateWidget(covariant _StudentUpcomingExams oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      setState(() {
        _subjectsFuture = CatalogDao(db).getSubjects();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    return StreamBuilder<Enrollment?>(
      stream: EnrollmentsDao(db).watchStudentEnrollment(
        schoolId: widget.schoolId,
        year: widget.term.year,
        term: widget.term.term,
        studentAdm: widget.studentAdm,
      ),
      builder: (context, enrollSnap) {
        if (!enrollSnap.hasData || enrollSnap.data == null) {
          return EmptyCard(
            icon: Icons.assignment_outlined,
            message: 'No upcoming exams',
          );
        }
        final enrollment = enrollSnap.data!;

        return StreamBuilder<List<ExamWithPapers>>(
          stream: ExamsGradesDao(db).watchExamsForClass(
            schoolId: widget.schoolId,
            year: widget.term.year,
            term: widget.term.term,
            grade: enrollment.grade,
            stream: enrollment.stream,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingShimmer();
            }

            final allExams = snap.data ?? [];
            final upcoming = <({Exam exam, Paper paper})>[];
            for (final e in allExams) {
              for (final p in e.papers) {
                if (p.start > nowSeconds &&
                    p.grade == enrollment.grade &&
                    (p.stream == null || p.stream == enrollment.stream)) {
                  upcoming.add((exam: e.exam, paper: p));
                }
              }
            }

            upcoming.sort((a, b) => a.paper.start.compareTo(b.paper.start));

            if (upcoming.isEmpty) {
              return EmptyCard(
                icon: Icons.assignment_outlined,
                message: 'No upcoming exams',
              );
            }

            final display = upcoming.take(3).toList();

            return FutureBuilder<List<Subject>>(
              future: _subjectsFuture,
              builder: (context, subSnap) {
                final subjectMap = <int, String>{};
                for (final s in subSnap.data ?? []) {
                  subjectMap[s.id] = s.name;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < display.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: cs.outline.withValues(alpha: 0.06),
                          ),
                        _buildExamRow(
                          examName: display[i].exam.name,
                          subjectName:
                              subjectMap[display[i].paper.subject] ??
                              'Subject ${display[i].paper.subject}',
                          paperStart: display[i].paper.start,
                          cs: cs,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExamRow({
    required String examName,
    required String subjectName,
    required BigInt paperStart,
    required ColorScheme cs,
  }) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paperStart.toInt() * 1000,
      isUtc: true,
    ).toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  '$subjectName · ${fmtDateFromSeconds(paperStart)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          CountdownChip(
            label: subjectName,
            targetTime: startDt,
            icon: Icons.access_time_rounded,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _StudentEnrollmentInfo extends StatefulWidget {
  const _StudentEnrollmentInfo({
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
  State<_StudentEnrollmentInfo> createState() => _StudentEnrollmentInfoState();
}

class _StudentEnrollmentInfoState extends State<_StudentEnrollmentInfo> {
  late Future<List<SchoolStream>> _streamsFuture;

  @override
  void initState() {
    super.initState();
    _streamsFuture = CatalogDao(db).getStreamsForSchool(widget.schoolId);
  }

  @override
  void didUpdateWidget(covariant _StudentEnrollmentInfo oldWidget) {
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
    final enrollmentsDao = EnrollmentsDao(db);

    return StreamBuilder<Enrollment?>(
      stream: enrollmentsDao.watchStudentEnrollment(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        studentAdm: widget.studentAdm,
      ),
      builder: (context, snap) {
        final enrollment = snap.data;
        if (enrollment == null) {
          return EmptyCard(
            icon: Icons.info_outline_rounded,
            message: 'Not enrolled in any class this term',
          );
        }

        return FutureBuilder<List<SchoolStream>>(
          future: _streamsFuture,
          builder: (context, strSnap) {
            final streamMap = <(int, int), String>{};
            for (final s in strSnap.data ?? []) {
              streamMap[(s.grade, s.stream)] = s.name;
            }
            final streamName = streamMap[(enrollment.grade, enrollment.stream)];
            final label = gradeStreamLabel(
              enrollment.grade,
              streamName: streamName,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 18,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ADM: ${widget.studentAdm}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
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
}

// ── PUBLIC: Reused by GuardianOverview ────────────────────────────────────────

class StudentTodaySchedule extends StatelessWidget {
  const StudentTodaySchedule({
    super.key,
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
    final enrollmentsDao = EnrollmentsDao(db);

    return StreamBuilder<Enrollment?>(
      stream: enrollmentsDao.watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, enrollSnap) {
        final enrollment = enrollSnap.data;
        if (enrollment == null) {
          return EmptyCard(
            icon: Icons.event_available_outlined,
            message: 'No class enrollment found',
          );
        }

        final timetableDao = TimetableDao(db);
        return StreamBuilder<List<TimetableEntry>>(
          stream: timetableDao.watchClassTimetable(
            schoolId: schoolId,
            year: year,
            term: term,
            grade: enrollment.grade,
            stream: enrollment.stream,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingShimmer();
            }

            final allSlots = snap.data ?? [];
            final todayDay = currentDayOfWeek();
            final todaySlots =
                allSlots.where((e) => e.slot.day == todayDay).toList()
                  ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

            if (todaySlots.isEmpty) {
              return EmptyCard(
                icon: Icons.event_available_outlined,
                message: 'No classes scheduled today',
              );
            }

            return Column(
              children: todaySlots.map((e) {
                return _StudentTimetableSlotCard(entry: e);
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _StudentTimetableSlotCard extends StatelessWidget {
  const _StudentTimetableSlotCard({required this.entry});

  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final slot = entry.slot;
    final teacher = entry.teacher;
    final color = subjectColor(slot.subject);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.subjectName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teacher.name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${fmtTime(slot.start)} – ${fmtTime(slot.end)}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PUBLIC: Reused by GuardianOverview ────────────────────────────────────────

class StudentRecentGrades extends StatefulWidget {
  const StudentRecentGrades({
    super.key,
    required this.schoolId,
    required this.studentAdm,
  });

  final String schoolId;
  final int studentAdm;

  @override
  State<StudentRecentGrades> createState() => _StudentRecentGradesState();
}

class _StudentRecentGradesState extends State<StudentRecentGrades> {
  final Map<String, Future<Exam?>> _examCache = {};

  Future<Exam?> _getExam(String examId) {
    return _examCache.putIfAbsent(
      examId,
      () => ExamsGradesDao(db).getExam(examId),
    );
  }

  @override
  void didUpdateWidget(covariant StudentRecentGrades oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.studentAdm != widget.studentAdm) {
      _examCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examsDao = ExamsGradesDao(db);

    return StreamBuilder<List<Grade>>(
      stream: examsDao.watchStudentGrades(widget.schoolId, widget.studentAdm),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingShimmer();
        }

        final allGrades = snap.data ?? [];
        if (allGrades.isEmpty) {
          return EmptyCard(
            icon: Icons.assignment_outlined,
            message: 'No exam results yet',
          );
        }

        // Get subject-level totals (paper == null) grouped by exam, take last 3 exams
        final byExam = <String, List<Grade>>{};
        for (final g in allGrades) {
          if (g.paper != null) continue; // only subject-level totals
          (byExam[g.exam] ??= []).add(g);
        }

        // If no subject-level totals, fall back to all grades
        if (byExam.isEmpty) {
          for (final g in allGrades) {
            (byExam[g.exam] ??= []).add(g);
          }
        }

        final examIds = byExam.keys.toList();
        // Sort by the latest grade created date in each group (desc)
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

        return Column(
          children: recentExamIds.map((examId) {
            final grades = byExam[examId]!;
            final totalScore = grades.fold<double>(
              0,
              (sum, g) => sum + g.score,
            );
            final totalMax = grades.fold<double>(0, (sum, g) => sum + g.total);
            final pct = totalMax > 0 ? (totalScore / totalMax * 100) : 0.0;

            return FutureBuilder<Exam?>(
              future: _getExam(examId),
              builder: (context, examSnap) {
                final examName = examSnap.data?.name ?? 'Exam';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
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
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${grades.length} subject${grades.length == 1 ? '' : 's'} · ${totalScore.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}',
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
                          PercentBadge(percent: pct, cs: cs),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

// ── PUBLIC: Reused by GuardianOverview ────────────────────────────────────────

class StudentAttendanceSummary extends StatelessWidget {
  const StudentAttendanceSummary({
    super.key,
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
    final attendanceDao = AttendanceDao(db);

    return StreamBuilder<({int totalDays, int present, int absent, int leave})>(
      stream: attendanceDao.watchStudentAttendanceSummary(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingShimmer();
        }

        final data = snap.data;
        if (data == null || data.totalDays == 0) {
          return EmptyCard(
            icon: Icons.calendar_today_outlined,
            message: 'No attendance records this term',
          );
        }

        final presentPct = data.totalDays > 0
            ? (data.present / data.totalDays * 100)
            : 0.0;

        return AttendanceBar(
          present: data.present,
          absent: data.absent,
          leave: data.leave,
          totalDays: data.totalDays,
          presentPercent: presentPct,
          cs: cs,
        );
      },
    );
  }
}
