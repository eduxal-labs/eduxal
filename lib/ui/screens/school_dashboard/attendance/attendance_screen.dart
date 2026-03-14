import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';

import '../../../widgets/active_term_provider.dart';
import '../academics/grade_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level entry point for the Attendance section.
///
/// Mounted from the dashboard shell under the "Attendance" nav label for
/// teachers, students, and guardians.
///
/// Role dispatch:
/// - **Teacher / Owner:** Class picker list. Each card shows grade + stream +
///   today's marking status. Tapping navigates to [GradeDetailPage] with the
///   Attendance content tab pre-selected.
/// - **Guardian:** Calendar-based read-only history for their ward.
/// - **Student:** Calendar-based read-only history for themselves.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
    }

    final entry = schoolContext.currentEntry.value;

    return switch (entry) {
      TeacherEntry() => _ClassPickerShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      GuardianEntry(:final ward) => _GuardianAttendanceView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: ward.adm,
        studentName: ward.name,
      ),
      StudentEntry(:final student) => _GuardianAttendanceView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: student.adm,
        studentName: student.name,
      ),
      _ => _ClassPickerShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CLASS PICKER — Teacher / Owner flow
// ═════════════════════════════════════════════════════════════════════════════

/// Shows a list of classes (grade + stream) with today's marking status.
/// Tapping a class navigates to [GradeDetailPage] with the Attendance content
/// tab pre-selected (index 3) and the correct stream tab.
class _ClassPickerShell extends StatefulWidget {
  const _ClassPickerShell({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_ClassPickerShell> createState() => _ClassPickerShellState();
}

class _ClassPickerShellState extends State<_ClassPickerShell> {
  late final AttendanceDao _attendanceDao;
  late final EnrollmentsDao _enrollmentsDao;

  SchoolConfig? _config;
  bool _loadingConfig = true;

  /// Available classes from enrollments.
  List<({int grade, int stream})> _availableClasses = [];
  bool _loadingClasses = true;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _attendanceDao = AttendanceDao(db);
    _enrollmentsDao = EnrollmentsDao(db);
    _loadConfig();
    _loadClasses();
  }

  Future<void> _loadConfig() async {
    if (mounted) setState(() => _loadingConfig = false);
  }

  void _loadClasses() {
    final term = widget.termContext.currentTerm;
    if (term == null) return;

    _enrollmentsDao
        .watchPopulatedClasses(
          schoolId: _schoolId,
          year: term.year,
          term: term.term,
        )
        .listen((classes) {
          if (!mounted) return;
          setState(() {
            _availableClasses = classes;
            _loadingClasses = false;
          });
        });
  }

  /// Resolves the [GradeConfig] and [CurriculumType] for a given grade integer,
  /// plus the stream index within that grade's stream list.
  ({GradeConfig gradeConfig, CurriculumType type, int streamIndex})?
  _resolveClass(int grade, int stream) {
    final config = _config;
    if (config == null) return null;

    for (final curriculum in config.curricula) {
      for (final gc in curriculum.grades) {
        if (gc.grade == grade) {
          final streamIdx = gc.streams.indexWhere((s) => s.code == stream);
          if (streamIdx >= 0) {
            return (
              gradeConfig: gc,
              type: curriculum.type,
              streamIndex: streamIdx,
            );
          }
        }
      }
    }
    return null;
  }

  void _navigateToClass(int grade, int stream) {
    final resolved = _resolveClass(grade, stream);
    if (resolved == null) return;

    final label =
        gradeLabelsFor(resolved.type)[resolved.gradeConfig.grade] ??
        'Grade ${resolved.gradeConfig.grade}';

    // Stream tab index: 0 = Comparisons, so stream tabs start at 1.
    final streamTabIndex = resolved.streamIndex + 1;

    // Attendance is content tab index 3 (Students=0, Exams=1, Subjects=2,
    // Attendance=3).
    const attendanceTabIndex = 3;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTermProvider(
          termContext: ActiveTermProvider.read(context),
          child: GradeDetailPage(
            schoolContext: widget.schoolContext,
            curriculumType: resolved.type,
            grade: resolved.gradeConfig,
            gradeLabel: label,
            initialStreamIndex: streamTabIndex,
            initialContentTabIndex: attendanceTabIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (term == null) return const _NoTermState();

    final isLoading = _loadingClasses || _loadingConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a class to mark attendance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                )
              : _availableClasses.isEmpty
              ? _EmptyClassesState(cs: cs)
              : _ClassList(
                  classes: _availableClasses,
                  config: _config,
                  schoolId: _schoolId,
                  year: term.year,
                  term: term.term,
                  attendanceDao: _attendanceDao,
                  cs: cs,
                  onClassTap: _navigateToClass,
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Class list — each card shows grade + stream + today's marking status
// ─────────────────────────────────────────────────────────────────────────────

class _ClassList extends StatelessWidget {
  const _ClassList({
    required this.classes,
    required this.config,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.attendanceDao,
    required this.cs,
    required this.onClassTap,
  });

  final List<({int grade, int stream})> classes;
  final SchoolConfig? config;
  final String schoolId;
  final int year;
  final int term;
  final AttendanceDao attendanceDao;
  final ColorScheme cs;
  final void Function(int grade, int stream) onClassTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final cls = classes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ClassCard(
            grade: cls.grade,
            stream: cls.stream,
            config: config,
            schoolId: schoolId,
            year: year,
            term: term,
            attendanceDao: attendanceDao,
            cs: cs,
            onTap: () => onClassTap(cls.grade, cls.stream),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Class card — grade label + stream name + today's marking status badge
// ─────────────────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.grade,
    required this.stream,
    required this.config,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.attendanceDao,
    required this.cs,
    required this.onTap,
  });

  final int grade;
  final int stream;
  final SchoolConfig? config;
  final String schoolId;
  final int year;
  final int term;
  final AttendanceDao attendanceDao;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradeLabel = _gradeLabel(grade, config);
    final streamLabel = _streamLabel(grade, stream, config);
    final today = _dateToEpochDays(DateTime.now());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              // ── Class icon ─────────────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.class_outlined,
                  size: 20,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 14),

              // ── Labels ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gradeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streamLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Today's marking status ─────────────────────────────────
              _TodayStatusBadge(
                schoolId: schoolId,
                year: year,
                term: term,
                grade: grade,
                stream: stream,
                date: today,
                attendanceDao: attendanceDao,
                cs: cs,
              ),

              const SizedBox(width: 8),

              // ── Chevron ────────────────────────────────────────────────
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's marking status badge — reactive via stream
// ─────────────────────────────────────────────────────────────────────────────

class _TodayStatusBadge extends StatelessWidget {
  const _TodayStatusBadge({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.date,
    required this.attendanceDao,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int date;
  final AttendanceDao attendanceDao;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentAttendanceRow>>(
      stream: attendanceDao.watchClassAttendance(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
        date: date,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return _buildBadge(
            label: 'No students',
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            bgColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          );
        }

        final total = rows.length;
        final marked = rows.where((r) => r.isMarked).length;

        if (marked == 0) {
          return _buildBadge(
            label: 'Not marked',
            color: _kAbsentColor,
            bgColor: _kAbsentColor.withValues(alpha: 0.08),
          );
        }

        if (marked == total) {
          return _buildBadge(
            label: 'Fully marked',
            color: _kPresentColor,
            bgColor: _kPresentColor.withValues(alpha: 0.08),
          );
        }

        return _buildBadge(
          label: '$marked / $total marked',
          color: _kLeaveColor,
          bgColor: _kLeaveColor.withValues(alpha: 0.08),
        );
      },
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
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

// ═════════════════════════════════════════════════════════════════════════════
// GUARDIAN / STUDENT ATTENDANCE VIEW
// ═════════════════════════════════════════════════════════════════════════════

class _GuardianAttendanceView extends StatefulWidget {
  const _GuardianAttendanceView({
    required this.schoolContext,
    required this.termContext,
    required this.studentAdm,
    required this.studentName,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final int studentAdm;
  final String studentName;

  @override
  State<_GuardianAttendanceView> createState() =>
      _GuardianAttendanceViewState();
}

class _GuardianAttendanceViewState extends State<_GuardianAttendanceView> {
  late final AttendanceDao _dao;

  // Current month being displayed in the calendar.
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

    if (term == null) return const _NoTermState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.studentName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // ── Summary card ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _GuardianSummaryCard(
            schoolId: widget.schoolContext.membership.school.id,
            year: term.year,
            term: term.term,
            studentAdm: widget.studentAdm,
            dao: _dao,
            cs: cs,
          ),
        ),

        // ── Calendar ──────────────────────────────────────────────────────
        Expanded(
          child: _AttendanceCalendar(
            schoolId: widget.schoolContext.membership.school.id,
            year: term.year,
            term: term.term,
            studentAdm: widget.studentAdm,
            calendarMonth: _calendarMonth,
            dao: _dao,
            cs: cs,
            onPreviousMonth: _previousMonth,
            onNextMonth: _nextMonth,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardian summary card — term-wide stats
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianSummaryCard extends StatelessWidget {
  const _GuardianSummaryCard({
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              // Attendance rate circle.
              _RateCircle(rate: rate, cs: cs),
              const SizedBox(width: 20),

              // Stat pills.
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
      width: 56,
      height: 56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: rate / 100,
            strokeWidth: 4,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            color: color,
          ),
          Center(
            child: Text(
              '${rate.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 13,
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
        borderRadius: BorderRadius.circular(4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Guardian calendar — monthly calendar with attendance heatmap
// ─────────────────────────────────────────────────────────────────────────────

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

        // Build a map of date → status for fast lookup.
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
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
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
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Day-of-week headers ───────────────────────────────────────
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
    // Monday-based offset (Monday = 0, Sunday = 6).
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
// Empty / Error states
// ═════════════════════════════════════════════════════════════════════════════

class _NoTermState extends StatelessWidget {
  const _NoTermState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
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
              Icons.calendar_today_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No terms configured',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create a term to start taking attendance',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyClassesState extends StatelessWidget {
  const _EmptyClassesState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icons.people_outline_rounded,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No classes found',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Enroll students into classes to mark attendance',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═════════════════════════════════════════════════════════════════════════════

const Color _kPresentColor = Color(0xFF4CAF50); // muted green
const Color _kAbsentColor = Color(0xFFEF5350); // muted red
const Color _kLeaveColor = Color(0xFFFFA726); // muted amber

/// Converts a [DateTime] to days since Unix epoch (matching the schema's
/// `integer` date columns).
int _dateToEpochDays(DateTime dt) {
  return DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/
      (1000 * 60 * 60 * 24);
}

/// Checks if two [DateTime] values represent the same calendar day.
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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

String _gradeLabel(int grade, SchoolConfig? config) {
  if (config == null) return 'Grade $grade';
  for (final c in config.curricula) {
    final labels = gradeLabelsFor(c.type);
    if (labels.containsKey(grade)) return labels[grade]!;
  }
  return 'Grade $grade';
}

String _streamLabel(int grade, int streamCode, SchoolConfig? config) {
  if (config == null) return 'Stream $streamCode';
  for (final c in config.curricula) {
    final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
    if (gc != null) {
      final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
      if (s != null) return s.name;
    }
  }
  return 'Stream $streamCode';
}
