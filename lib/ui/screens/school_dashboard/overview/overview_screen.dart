import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/academics_dao.dart';
import '../../../../database/daos/announcements_dao.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/finance_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../../models/grade_analytics.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/student_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Overview Screen — role-dispatched school dashboard landing page
// ─────────────────────────────────────────────────────────────────────────────

/// The Overview screen is the first page a user sees when entering a school
/// dashboard. It adapts its content based on the user's active role.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: schoolContext.currentEntry,
      builder: (context, entry, _) {
        return switch (entry) {
          OwnerEntry() => _OwnerOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          TeacherEntry() => _TeacherOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
          StaffEntry() => _StaffOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
          ),
          StudentEntry() => _StudentOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
          GuardianEntry() => _GuardianOverview(
            schoolContext: schoolContext,
            termContext: termCtx,
            entry: entry,
          ),
        };
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _OwnerOverview extends StatelessWidget {
  const _OwnerOverview({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final school = schoolContext.membership.school;
    final schoolId = school.id;
    final term = termContext.currentTerm;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── School identity ──────────────────────────────────────────────
        _SchoolIdentityCard(school: school),

        const SizedBox(height: 16),

        // ── Quick stats ──────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _OwnerQuickStats(schoolId: schoolId, term: term),
          const SizedBox(height: 20),
        ],

        // ── Current term info ────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Current Term', cs: cs),
          const SizedBox(height: 8),
          _TermInfoCard(term: term, cs: cs),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(label: 'Recent Announcements', cs: cs),
        const SizedBox(height: 8),
        _RecentAnnouncements(schoolId: schoolId, isOwner: true),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _OwnerQuickStats extends StatelessWidget {
  const _OwnerQuickStats({required this.schoolId, required this.term});

  final String schoolId;
  final Term term;

  @override
  Widget build(BuildContext context) {
    final membersDao = MembersDao(db);
    final enrollmentsDao = EnrollmentsDao(db);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<StudentsData>>(
                stream: membersDao.watchStudents(schoolId),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return _StatCard(
                    icon: Icons.groups_outlined,
                    label: 'Students',
                    value: '$count',
                    tint: const Color(0xFF3F51B5),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<List<TeachersData>>(
                stream: membersDao.watchTeachers(schoolId),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return _StatCard(
                    icon: Icons.school_outlined,
                    label: 'Teachers',
                    value: '$count',
                    tint: const Color(0xFF009688),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<StaffData>>(
                stream: membersDao.watchStaff(schoolId),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return _StatCard(
                    icon: Icons.badge_outlined,
                    label: 'Staff',
                    value: '$count',
                    tint: const Color(0xFFFF9800),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<List<({int grade, int stream})>>(
                stream: enrollmentsDao.watchPopulatedClasses(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                ),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return _StatCard(
                    icon: Icons.class_outlined,
                    label: 'Classes',
                    value: '$count',
                    tint: const Color(0xFF7C4DFF),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherOverview extends StatelessWidget {
  const _TeacherOverview({
    required this.schoolContext,
    required this.termContext,
    required this.entry,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final TeacherEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final schoolId = schoolContext.membership.school.id;
    final term = termContext.currentTerm;
    final userName = cache.currentUser?.user.name ?? 'Teacher';
    final userId = cache.currentUser?.user.id ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Welcome ──────────────────────────────────────────────────────
        _WelcomeCard(name: userName, subtitle: 'Teacher', cs: cs),

        const SizedBox(height: 20),

        // ── Today's schedule ─────────────────────────────────────────────
        if (term != null && userId.isNotEmpty) ...[
          _SectionTitle(label: "Today's Schedule", cs: cs),
          const SizedBox(height: 8),
          _TeacherTodaySchedule(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            teacherUserId: userId,
          ),
          const SizedBox(height: 20),
        ],

        // ── Quick stats ──────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _TeacherQuickStats(
            schoolId: schoolId,
            term: term,
            entry: entry,
            userId: userId,
          ),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(label: 'Recent Announcements', cs: cs),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.teachers,
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _TeacherTodaySchedule extends StatelessWidget {
  const _TeacherTodaySchedule({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.teacherUserId,
  });

  final String schoolId;
  final int year;
  final int term;
  final String teacherUserId;

  @override
  Widget build(BuildContext context) {
    final timetableDao = TimetableDao(db);

    return StreamBuilder<List<TimetableData>>(
      stream: timetableDao.watchTeacherTimetable(
        schoolId: schoolId,
        year: year,
        term: term,
        teacherUserId: teacherUserId,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final allSlots = snap.data ?? [];
        final todayDay = _currentDayOfWeek();
        final todaySlots = allSlots.where((s) => s.day == todayDay).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        if (todaySlots.isEmpty) {
          return _EmptyCard(
            icon: Icons.event_available_outlined,
            message: 'No classes scheduled today',
          );
        }

        return Column(
          children: todaySlots
              .map((slot) => _TimetableSlotCard(slot: slot))
              .toList(),
        );
      },
    );
  }
}

class _TimetableSlotCard extends StatelessWidget {
  const _TimetableSlotCard({required this.slot});

  final TimetableData slot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _subjectColor(slot.subject);

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
                      'Grade ${slot.grade} · Stream ${slot.stream}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Subject ${slot.subject}',
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
                '${_fmtTime(slot.start)} – ${_fmtTime(slot.end)}',
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

class _TeacherQuickStats extends StatelessWidget {
  const _TeacherQuickStats({
    required this.schoolId,
    required this.term,
    required this.entry,
    required this.userId,
  });

  final String schoolId;
  final Term term;
  final TeacherEntry entry;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final examsDao = ExamsGradesDao(db);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_outlined,
            label: 'My Subjects',
            value: '${entry.subjectCount}',
            tint: const Color(0xFF3F51B5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StreamBuilder<List<ExamWithPapers>>(
            stream: examsDao.watchExamsForTerm(
              schoolId: schoolId,
              year: term.year,
              term: term.term,
            ),
            builder: (context, snap) {
              final allExams = snap.data ?? [];
              final myExams = allExams
                  .where((e) => e.teacher.id == userId)
                  .length;
              return _StatCard(
                icon: Icons.assignment_outlined,
                label: 'My Exams',
                value: '$myExams',
                tint: const Color(0xFF009688),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAFF OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _StaffOverview extends StatelessWidget {
  const _StaffOverview({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final school = schoolContext.membership.school;
    final schoolId = school.id;
    final term = termContext.currentTerm;
    final userName = cache.currentUser?.user.name ?? 'Staff';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Welcome ──────────────────────────────────────────────────────
        _WelcomeCard(name: userName, subtitle: school.name, cs: cs),

        const SizedBox(height: 20),

        // ── Quick stats ──────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _StaffQuickStats(schoolId: schoolId, term: term),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(label: 'Recent Announcements', cs: cs),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.staff,
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _StaffQuickStats extends StatelessWidget {
  const _StaffQuickStats({required this.schoolId, required this.term});

  final String schoolId;
  final Term term;

  @override
  Widget build(BuildContext context) {
    final membersDao = MembersDao(db);
    final financeDao = FinanceDao(db);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<StudentsData>>(
                stream: membersDao.watchStudents(schoolId),
                builder: (context, snap) {
                  final count = snap.data?.length ?? 0;
                  return _StatCard(
                    icon: Icons.groups_outlined,
                    label: 'Students',
                    value: '$count',
                    tint: const Color(0xFF3F51B5),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<TermFinanceSummary>(
                stream: financeDao.watchTermFinanceSummary(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                ),
                builder: (context, snap) {
                  final summary = snap.data;
                  final count = summary?.invoiceCount ?? 0;
                  return _StatCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Invoices',
                    value: '$count',
                    tint: const Color(0xFFFF9800),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<TermFinanceSummary>(
                stream: financeDao.watchTermFinanceSummary(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                ),
                builder: (context, snap) {
                  final summary = snap.data;
                  final rate = summary?.collectionRate ?? 0.0;
                  return _StatCard(
                    icon: Icons.account_balance_outlined,
                    label: 'Collection',
                    value: '${rate.toStringAsFixed(0)}%',
                    tint: const Color(0xFF4CAF50),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<TermFinanceSummary>(
                stream: financeDao.watchTermFinanceSummary(
                  schoolId: schoolId,
                  year: term.year,
                  term: term.term,
                ),
                builder: (context, snap) {
                  final summary = snap.data;
                  final pending = summary?.pendingCount ?? 0;
                  return _StatCard(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending',
                    value: '$pending',
                    tint: const Color(0xFFF44336),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STUDENT OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _StudentOverview extends StatelessWidget {
  const _StudentOverview({
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Welcome ──────────────────────────────────────────────────────
        _WelcomeCard(name: studentName, subtitle: 'Student', cs: cs),

        const SizedBox(height: 16),

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
        if (term != null) ...[
          _SectionTitle(label: "Today's Schedule", cs: cs),
          const SizedBox(height: 8),
          _StudentTodaySchedule(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 20),
        ],

        // ── Recent grades ────────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Recent Grades', cs: cs),
          const SizedBox(height: 8),
          _StudentRecentGrades(schoolId: schoolId, studentAdm: studentAdm),
          const SizedBox(height: 20),
        ],

        // ── Attendance summary ───────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Attendance', cs: cs),
          const SizedBox(height: 8),
          _StudentAttendanceSummary(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: studentAdm,
          ),
          const SizedBox(height: 20),
        ],

        // ── Recent announcements ─────────────────────────────────────────
        _SectionTitle(label: 'Recent Announcements', cs: cs),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.students,
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _StudentEnrollmentInfo extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enrollmentsDao = EnrollmentsDao(db);

    return StreamBuilder<Enrollment?>(
      stream: enrollmentsDao.watchStudentEnrollment(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snap) {
        final enrollment = snap.data;
        if (enrollment == null) {
          return _EmptyCard(
            icon: Icons.info_outline_rounded,
            message: 'Not enrolled in any class this term',
          );
        }

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
                'Grade ${enrollment.grade} · Stream ${enrollment.stream}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              Text(
                'ADM: $studentAdm',
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
  }
}

class _StudentTodaySchedule extends StatelessWidget {
  const _StudentTodaySchedule({
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
          return _EmptyCard(
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
              return const _LoadingShimmer();
            }

            final allSlots = snap.data ?? [];
            final todayDay = _currentDayOfWeek();
            final todaySlots =
                allSlots.where((e) => e.slot.day == todayDay).toList()
                  ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

            if (todaySlots.isEmpty) {
              return _EmptyCard(
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
    final color = _subjectColor(slot.subject);

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
                      'Subject ${slot.subject}',
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
                '${_fmtTime(slot.start)} – ${_fmtTime(slot.end)}',
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

class _StudentRecentGrades extends StatelessWidget {
  const _StudentRecentGrades({
    required this.schoolId,
    required this.studentAdm,
  });

  final String schoolId;
  final int studentAdm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final examsDao = ExamsGradesDao(db);

    return StreamBuilder<List<Grade>>(
      stream: examsDao.watchStudentGrades(schoolId, studentAdm),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final allGrades = snap.data ?? [];
        if (allGrades.isEmpty) {
          return _EmptyCard(
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
                              '${grades.length} subject${grades.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${totalScore.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}',
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

class _StudentAttendanceSummary extends StatelessWidget {
  const _StudentAttendanceSummary({
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
          return const _LoadingShimmer();
        }

        final data = snap.data;
        if (data == null || data.totalDays == 0) {
          return _EmptyCard(
            icon: Icons.calendar_today_outlined,
            message: 'No attendance records this term',
          );
        }

        final presentPct = data.totalDays > 0
            ? (data.present / data.totalDays * 100)
            : 0.0;

        return _AttendanceBar(
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

// ═════════════════════════════════════════════════════════════════════════════
// GUARDIAN OVERVIEW
// ═════════════════════════════════════════════════════════════════════════════

class _GuardianOverview extends StatelessWidget {
  const _GuardianOverview({
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── 1. Welcome ───────────────────────────────────────────────────
        _WelcomeCard(name: userName, subtitle: 'Guardian', cs: cs),

        const SizedBox(height: 16),

        // ── 2. Ward info (enhanced) ──────────────────────────────────────
        _WardInfoCard(ward: ward, schoolId: schoolId, term: term),

        const SizedBox(height: 16),

        // ── 3. Quick stats (2×2 grid) ────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Quick Stats', cs: cs),
          const SizedBox(height: 8),
          _GuardianQuickStats(
            schoolId: schoolId,
            term: term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 4. Today's schedule ──────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: "Today's Schedule", cs: cs),
          const SizedBox(height: 8),
          _StudentTodaySchedule(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 5. Attendance summary ────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: "Attendance", cs: cs),
          const SizedBox(height: 8),
          _StudentAttendanceSummary(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
            studentAdm: ward.adm,
          ),
          const SizedBox(height: 20),
        ],

        // ── 6. Recent grades ─────────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: "Recent Grades", cs: cs),
          const SizedBox(height: 8),
          _StudentRecentGrades(schoolId: schoolId, studentAdm: ward.adm),
          const SizedBox(height: 20),
        ],

        // ── 7. Finance summary ───────────────────────────────────────────
        if (term != null) ...[
          _SectionTitle(label: 'Finance', cs: cs),
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
        _SectionTitle(label: 'Recent Announcements', cs: cs),
        const SizedBox(height: 8),
        _RecentAnnouncements(
          schoolId: schoolId,
          audienceBit: AudienceBits.guardians,
        ),

        const SizedBox(height: 80),
      ],
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
                      return _StatCard(
                        icon: Icons.calendar_today_outlined,
                        label: 'Attendance',
                        value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
                        tint: pct != null
                            ? _pctColor(pct)
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
                  return _StatCard(
                    icon: Icons.assignment_outlined,
                    label: 'Latest Exam',
                    value: pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
                    tint: pct != null
                        ? _pctColor(pct)
                        : const Color(0xFF607D8B),
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
                    return _StatCard(
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
                      return _StatCard(
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
                  return _StatCard(
                    icon: Icons.psychology_outlined,
                    label: 'Mastery',
                    value: avgPct != null
                        ? '${avgPct.toStringAsFixed(0)}%'
                        : '—',
                    tint: avgPct != null
                        ? _pctColor(avgPct)
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

class _WardInfoCard extends StatelessWidget {
  const _WardInfoCard({
    required this.ward,
    required this.schoolId,
    required this.term,
  });

  final StudentsData ward;
  final String schoolId;
  final Term? term;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          StudentAvatar(
            schoolId: schoolId,
            adm: ward.adm,
            name: ward.name,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ward.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ADM: ${ward.adm}',
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
                studentAdm: ward.adm,
              ),
              builder: (context, snap) {
                final enrollment = snap.data;
                if (enrollment == null) return const SizedBox.shrink();
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
                    'Grade ${enrollment.grade} · Stream ${enrollment.stream}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.primary.withValues(alpha: 0.8),
                    ),
                  ),
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
          return const _LoadingShimmer();
        }

        final data = snap.data;
        if (data == null || data.invoices.isEmpty) {
          return _EmptyCard(
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
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── School Identity Card ─────────────────────────────────────────────────────

class _SchoolIdentityCard extends StatelessWidget {
  const _SchoolIdentityCard({required this.school});

  final SchoolsData school;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.school_outlined,
                  size: 22,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (school.motto != null && school.motto!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        school.motto!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (school.established != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  'Est. ${school.established}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Welcome Card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.name,
    required this.subtitle,
    required this.cs,
  });

  final String name;
  final String subtitle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $firstName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
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

// ── Term Info Card ───────────────────────────────────────────────────────────

class _TermInfoCard extends StatelessWidget {
  const _TermInfoCard({required this.term, required this.cs});

  final Term term;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final start = _fmtDateFromSeconds(term.start);
    final end = _fmtDateFromSeconds(term.end);

    // Compute days remaining
    final nowSeconds = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final remaining = (term.end - nowSeconds).toInt();
    final daysRemaining = remaining > 0 ? (remaining / 86400).ceil() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 16,
                color: cs.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                '${term.year} · Term ${term.term}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (daysRemaining > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$daysRemaining days left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$start  –  $end',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ────────────────────────────────────────────────────────────

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

// ── Stat Card ────────────────────────────────────────────────────────────────

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
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

// ── Attendance Bar ───────────────────────────────────────────────────────────

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
    required this.present,
    required this.absent,
    required this.leave,
    required this.totalDays,
    required this.presentPercent,
    required this.cs,
  });

  final int present;
  final int absent;
  final int leave;
  final int totalDays;
  final double presentPercent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (present > 0)
                    Expanded(
                      flex: present,
                      child: Container(color: const Color(0xFF4CAF50)),
                    ),
                  if (absent > 0)
                    Expanded(
                      flex: absent,
                      child: Container(color: const Color(0xFFF44336)),
                    ),
                  if (leave > 0)
                    Expanded(
                      flex: leave,
                      child: Container(color: const Color(0xFFFFA726)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _AttendanceDot(
                color: const Color(0xFF4CAF50),
                label: 'Present',
                count: present,
                cs: cs,
              ),
              const SizedBox(width: 16),
              _AttendanceDot(
                color: const Color(0xFFF44336),
                label: 'Absent',
                count: absent,
                cs: cs,
              ),
              const SizedBox(width: 16),
              _AttendanceDot(
                color: const Color(0xFFFFA726),
                label: 'Leave',
                count: leave,
                cs: cs,
              ),
              const Spacer(),
              Text(
                '${presentPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _pctColor(presentPercent),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceDot extends StatelessWidget {
  const _AttendanceDot({
    required this.color,
    required this.label,
    required this.count,
    required this.cs,
  });

  final Color color;
  final String label;
  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ── Percent Badge ────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(4),
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

// ── Recent Announcements ─────────────────────────────────────────────────────

class _RecentAnnouncements extends StatelessWidget {
  const _RecentAnnouncements({
    required this.schoolId,
    this.isOwner = false,
    this.audienceBit,
  });

  final String schoolId;
  final bool isOwner;
  final int? audienceBit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final announcementsDao = AnnouncementsDao(db);

    final Stream<List<AnnouncementWithAuthor>> stream;
    if (isOwner) {
      stream = announcementsDao.watchAllAnnouncements(schoolId);
    } else {
      stream = announcementsDao.watchAnnouncementsForAudience(
        schoolId,
        audienceBit: audienceBit ?? AudienceBits.all,
      );
    }

    return StreamBuilder<List<AnnouncementWithAuthor>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingShimmer();
        }

        final all = snap.data ?? [];
        if (all.isEmpty) {
          return _EmptyCard(
            icon: Icons.campaign_outlined,
            message: 'No announcements yet',
          );
        }

        final recent = all.take(3).toList();

        return Column(
          children: recent.map((a) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.campaign_outlined,
                          size: 16,
                          color: cs.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
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
                              a.content,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (a.authorName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '— ${a.authorName}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

// ── Empty Card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Loading Shimmer ──────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
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

/// Returns the current day of the week as a [DayOfWeek] enum value.
DayOfWeek _currentDayOfWeek() {
  // DateTime.weekday: 1 = Monday … 7 = Sunday
  // DayOfWeek enum:  0 = Sunday, 1 = Monday … 6 = Saturday
  final wd = DateTime.now().weekday;
  return DayOfWeek.values[wd == 7 ? 0 : wd];
}

/// Formats seconds since midnight to "HH:MM" 24-hour.
String _fmtTime(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Formats a BigInt seconds-since-epoch to a readable date string.
String _fmtDateFromSeconds(BigInt secondsSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(
    secondsSinceEpoch.toInt() * 1000,
    isUtc: true,
  );
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
}

const _months = [
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

/// Extracts initials (up to 2 characters) from a name.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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

/// Percentage color: green ≥ 70, amber ≥ 40, red < 40.
Color _pctColor(double pct) {
  if (pct >= 70) return const Color(0xFF4CAF50);
  if (pct >= 40) return const Color(0xFFFFC107);
  return const Color(0xFFF44336);
}

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
