import 'package:flutter/material.dart';
import '../../../../widgets/inline_date_picker_dialog.dart';
import '../../../../widgets/permission_denied_handler.dart';

import '../../../../../core/formatters.dart';
import '../../../../../client.dart';
import '../../../../../database/database.dart';
import '../../../../../database/daos/attendance_dao.dart';
import '../../../../../database/daos/members_dao.dart';
import '../../../../../database/tables/enums.dart';
import '../../../../../models/membership.dart';
import '../../../../../models/permissions.dart' as perms;
import '../../../../../models/school_context.dart';
import '../../../../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STATUS COLORS
// ═════════════════════════════════════════════════════════════════════════════

const Color _kPresentColor = Color(0xFF4CAF50);
const Color _kAbsentColor = Color(0xFFEF5350);
const Color _kLeaveColor = Color(0xFFFFA726);

/// Returns a very subtle tinted background for attendance tiles.
Color _tileBackground(AttendanceStatus? status, ColorScheme cs) {
  if (status == null) return cs.surface;
  return switch (status) {
    AttendanceStatus.present => _kPresentColor.withValues(alpha: 0.04),
    AttendanceStatus.absent => _kAbsentColor.withValues(alpha: 0.04),
    AttendanceStatus.leave => _kLeaveColor.withValues(alpha: 0.04),
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// DATE HELPERS
// ═════════════════════════════════════════════════════════════════════════════

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmtDate(DateTime d) {
  final dayName = kDayNames[d.weekday - 1];
  return '$dayName, ${d.day} ${kMonthNames[d.month - 1]} ${d.year}';
}

String _fmtMonth(DateTime d) => '${kMonthNamesFull[d.month - 1]} ${d.year}';

/// Returns the Monday of the week containing [date].
DateTime _weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

// ═════════════════════════════════════════════════════════════════════════════
// ATTENDANCE TAB — Main Widget
// ═════════════════════════════════════════════════════════════════════════════

/// Attendance marking tab within the grade detail page.
///
/// Unlike the standalone [AttendanceScreen], this widget does not include a
/// class picker — the grade/stream context is provided by the parent
/// [GradeDetailPage]. It adds a historical calendar toggle for teachers to
/// quickly check which days still need marking.
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final String streamName;
  final dynamic curriculumType; // CurriculumType
  final SchoolContext schoolContext;

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab>
    with AutomaticKeepAliveClientMixin {
  late final AttendanceDao _dao;
  late final MembersDao _membersDao;

  // ── Date state ─────────────────────────────────────────────────────────────

  late DateTime _selectedDate;
  late int _selectedDateEpochDays;

  /// Whether the historical calendar view is shown instead of the marking list.
  bool _showHistory = false;

  /// The month currently being viewed in the calendar history view.
  late DateTime _calendarMonth;

  /// Whether the current user is allowed to mark attendance for this class.
  ///
  /// - Owners: always `true` (bypass all checks).
  /// - Staff with `Resource.attendance, Action.mark` permission: `true`.
  /// - Teachers: only `true` if they are the active class teacher for the
  ///   current grade/stream (row in `class_teachers` with `end IS NULL`).
  /// - Students / Guardians: always `false`.
  bool _canMark = false;

  /// True while the async class-teacher check is in flight.
  bool _loadingCanMark = true;

  // ── Keep-alive ─────────────────────────────────────────────────────────────

  @override
  bool get wantKeepAlive => true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dao = AttendanceDao(db);
    _membersDao = MembersDao(db);
    _selectedDate = DateTime.now();
    _selectedDateEpochDays = daysFromDate(_selectedDate);
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _resolveCanMark();
  }

  @override
  void didUpdateWidget(covariant AttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamCode != widget.streamCode ||
        oldWidget.grade != widget.grade ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term) {
      debugPrint(
        '[AttendanceTab] didUpdateWidget: stream ${oldWidget.streamCode}→${widget.streamCode}, '
        'grade ${oldWidget.grade}→${widget.grade}',
      );
      setState(() {
        _loadingCanMark = true;
        _canMark = false;
      });
      _resolveCanMark();
    }
  }

  /// Determines whether the current user may mark attendance.
  Future<void> _resolveCanMark() async {
    final entry = widget.schoolContext.currentEntry.value;
    bool result;

    switch (entry) {
      case OwnerEntry():
        // Owners bypass all permission checks.
        debugPrint(
          '[AttendanceTab] _resolveCanMark: OwnerEntry → canMark=true',
        );
        result = true;
      case TeacherEntry():
        // First check if the teacher has the attendance.mark permission
        // via an assigned role — if so, they can mark ANY class.
        final hasPermission = widget.schoolContext.permissions.can(
          perms.Resource.attendance,
          perms.Action.mark,
        );
        if (hasPermission) {
          debugPrint(
            '[AttendanceTab] _resolveCanMark: TeacherEntry has attendance.mark permission → canMark=true',
          );
          result = true;
        } else {
          // Fall back: teachers without explicit permission can only mark
          // attendance for classes where they are the active class teacher.
          final userId = cache.currentUser!.user.id;
          result = await _membersDao.isClassTeacherFor(
            schoolId: widget.schoolId,
            year: widget.year,
            term: widget.term,
            grade: widget.grade,
            stream: widget.streamCode,
            teacherUserId: userId,
          );
          debugPrint(
            '[AttendanceTab] _resolveCanMark: TeacherEntry, userId=$userId, '
            'grade=${widget.grade}, stream=${widget.streamCode} → canMark=$result',
          );
        }
      case StaffEntry():
        // Staff with the attendance mark permission can mark any class.
        result = widget.schoolContext.permissions.can(
          perms.Resource.attendance,
          perms.Action.mark,
        );
      case StudentEntry():
      case GuardianEntry():
        result = false;
    }

    if (mounted) {
      setState(() {
        _canMark = result;
        _loadingCanMark = false;
      });
    }
  }

  // ── Date navigation ────────────────────────────────────────────────────────

  void _goToPreviousDay() {
    _setDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    final next = _selectedDate.add(const Duration(days: 1));
    final today = DateTime.now();
    if (!next.isAfter(DateTime(today.year, today.month, today.day))) {
      _setDate(next);
    }
  }

  void _goToToday() {
    _setDate(DateTime.now());
  }

  void _setDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedDateEpochDays = daysFromDate(date);
    });
  }

  /// Select a day from the history calendar — switches to marking mode for
  /// that date.
  void _selectHistoryDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedDateEpochDays = daysFromDate(date);
      _showHistory = false;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showInlineDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      title: 'Select date',
    );
    if (picked != null && mounted) {
      _setDate(picked);
    }
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
      if (_showHistory) {
        _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month);
      }
    });
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Date Selector Row ─────────────────────────────────────────────
        _DateSelectorRow(
          selectedDate: _selectedDate,
          onPrevious: _goToPreviousDay,
          onNext: _goToNextDay,
          onToday: _goToToday,
          onDateTap: () => _pickDate(context),
          onHistoryToggle: _toggleHistory,
          showingHistory: _showHistory,
          cs: cs,
        ),

        // ── Weekly Mini Strip ─────────────────────────────────────────────
        if (!_showHistory)
          _WeeklyMiniStrip(
            selectedDate: _selectedDate,
            schoolId: widget.schoolId,
            year: widget.year,
            term: widget.term,
            grade: widget.grade,
            stream: widget.streamCode,
            dao: _dao,
            cs: cs,
            onDaySelected: _setDate,
          ),

        // ── Divider ──────────────────────────────────────────────────────
        Container(height: 1, color: cs.outline.withValues(alpha: 0.06)),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: _showHistory
              ? _HistoryCalendar(
                  schoolId: widget.schoolId,
                  year: widget.year,
                  term: widget.term,
                  grade: widget.grade,
                  stream: widget.streamCode,
                  calendarMonth: _calendarMonth,
                  dao: _dao,
                  cs: cs,
                  onPreviousMonth: _previousMonth,
                  onNextMonth: _nextMonth,
                  onDaySelected: _selectHistoryDate,
                )
              : _AttendanceMarkingBody(
                  key: ValueKey(
                    '${widget.schoolId}|${widget.year}|${widget.term}|'
                    '${widget.grade}|${widget.streamCode}|$_selectedDateEpochDays',
                  ),
                  schoolId: widget.schoolId,
                  year: widget.year,
                  term: widget.term,
                  grade: widget.grade,
                  stream: widget.streamCode,
                  date: _selectedDateEpochDays,
                  dao: _dao,
                  cs: cs,
                  canMark: !_loadingCanMark && _canMark,
                ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DATE SELECTOR ROW
// ═════════════════════════════════════════════════════════════════════════════

class _DateSelectorRow extends StatelessWidget {
  const _DateSelectorRow({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onDateTap,
    required this.onHistoryToggle,
    required this.showingHistory,
    required this.cs,
  });

  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onDateTap;
  final VoidCallback onHistoryToggle;
  final bool showingHistory;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = _isSameDay(selectedDate, today);
    final isFutureLimited = selectedDate.isAfter(
      today.subtract(const Duration(days: 1)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      color: cs.surface,
      child: Row(
        children: [
          // ── Left arrow ───────────────────────────────────────────────────
          _NavIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
            cs: cs,
          ),

          // ── Date label (tappable) ────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onDateTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmtDate(selectedDate),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isToday)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: cs.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Right arrow ──────────────────────────────────────────────────
          _NavIconButton(
            icon: Icons.chevron_right_rounded,
            onTap: isFutureLimited ? null : onNext,
            cs: cs,
          ),

          // ── Today chip ───────────────────────────────────────────────────
          if (!isToday) ...[
            const SizedBox(width: 4),
            _CompactChip(label: 'Today', onTap: onToday, cs: cs),
          ],

          // ── History toggle ───────────────────────────────────────────────
          const SizedBox(width: 4),
          _NavIconButton(
            icon: showingHistory
                ? Icons.list_rounded
                : Icons.calendar_month_rounded,
            onTap: onHistoryToggle,
            cs: cs,
            isActive: showingHistory,
          ),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.onTap,
    required this.cs,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: isActive
              ? BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? cs.primary
                : enabled
                ? cs.onSurfaceVariant
                : cs.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WEEKLY MINI STRIP
// ═════════════════════════════════════════════════════════════════════════════

/// Compact Mon–Fri strip showing the current week with colored dots
/// indicating marking status for each day.
class _WeeklyMiniStrip extends StatelessWidget {
  const _WeeklyMiniStrip({
    required this.selectedDate,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.dao,
    required this.cs,
    required this.onDaySelected,
  });

  final DateTime selectedDate;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final AttendanceDao dao;
  final ColorScheme cs;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final monday = _weekStart(selectedDate);
    // Show Mon–Fri (5 days) plus Sat–Sun if they exist.
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();

    return StreamBuilder<List<DailyAttendanceSummary>>(
      stream: dao.watchDailyAttendanceSummaries(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
      ),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? [];
        // Build a lookup of epochDays → summary.
        final summaryMap = <int, DailyAttendanceSummary>{};
        for (final s in summaries) {
          summaryMap[s.date] = s;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          color: cs.surface,
          child: Row(
            children: days.map((day) {
              final isSelected = _isSameDay(day, selectedDate);
              final isDayToday = _isSameDay(day, today);
              final isFuture = day.isAfter(today);
              final epochDays = daysFromDate(day);
              final summary = summaryMap[epochDays];

              // Determine dot color.
              Color? dotColor;
              if (!isFuture && summary != null) {
                if (summary.isFullyMarked) {
                  dotColor = _kPresentColor;
                } else if (summary.markedCount > 0) {
                  dotColor = _kLeaveColor; // amber — partially marked
                } else {
                  dotColor = cs.onSurfaceVariant.withValues(alpha: 0.25);
                }
              }

              return Expanded(
                child: GestureDetector(
                  onTap: isFuture ? null : () => onDaySelected(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isDayToday && !isSelected
                          ? Border.all(
                              color: cs.primary.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kDayNames[day.weekday - 1],
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w400,
                            color: isFuture
                                ? cs.onSurfaceVariant.withValues(alpha: 0.2)
                                : isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isFuture
                                ? cs.onSurfaceVariant.withValues(alpha: 0.2)
                                : isSelected
                                ? cs.primary
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Status dot.
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: dotColor ?? Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ATTENDANCE MARKING BODY
// ═════════════════════════════════════════════════════════════════════════════

/// The core marking body — summary strip + action bar + student list.
/// Uses the instant-save pattern: each toggle immediately persists.
class _AttendanceMarkingBody extends StatefulWidget {
  const _AttendanceMarkingBody({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.date,
    required this.dao,
    required this.cs,
    this.canMark = true,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int date;
  final AttendanceDao dao;
  final ColorScheme cs;

  /// Whether the current user is allowed to mark attendance.
  /// When `false`, the action bar and per-student toggle buttons are hidden
  /// and the view is read-only.
  final bool canMark;

  @override
  State<_AttendanceMarkingBody> createState() => _AttendanceMarkingBodyState();
}

class _AttendanceMarkingBodyState extends State<_AttendanceMarkingBody> {
  bool _markingAllPresent = false;

  String get _accountId => cache.currentUser!.user.id;

  /// Mark all students as present using instant-save via markClassAttendance.
  Future<void> _markAllPresent(List<StudentAttendanceRow> rows) async {
    if (_markingAllPresent) return;
    setState(() => _markingAllPresent = true);

    try {
      final statuses = <int, AttendanceStatus>{};
      for (final row in rows) {
        if (row.attendance?.status != AttendanceStatus.present) {
          statuses[row.student.adm] = AttendanceStatus.present;
        }
      }

      if (statuses.isNotEmpty) {
        await guardedAction(context, () async {
          await widget.dao.markClassAttendance(
            schoolId: widget.schoolId,
            year: widget.year,
            term: widget.term,
            grade: widget.grade,
            stream: widget.stream,
            date: widget.date,
            statuses: statuses,
            accountId: _accountId,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _markingAllPresent = false);
    }
  }

  /// Instant-save a single student's attendance status.
  Future<void> _markSingle(int studentAdm, AttendanceStatus status) async {
    await guardedAction(context, () async {
      await widget.dao.markAttendance(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
        stream: widget.stream,
        studentAdm: studentAdm,
        date: widget.date,
        status: status,
        accountId: _accountId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return StreamBuilder<List<StudentAttendanceRow>>(
      stream: widget.dao.watchClassAttendance(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
        stream: widget.stream,
        date: widget.date,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
          );
        }

        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return _EmptyState(cs: cs);
        }

        // Compute summary.
        int present = 0, absent = 0, leave = 0, unmarked = 0;
        for (final row in rows) {
          final status = row.attendance?.status;
          if (status == null) {
            unmarked++;
          } else {
            switch (status) {
              case AttendanceStatus.present:
                present++;
              case AttendanceStatus.absent:
                absent++;
              case AttendanceStatus.leave:
                leave++;
            }
          }
        }

        return Column(
          children: [
            // ── Summary strip ─────────────────────────────────────────────
            _SummaryStrip(
              total: rows.length,
              present: present,
              absent: absent,
              leave: leave,
              unmarked: unmarked,
              cs: cs,
            ),

            // ── Action bar (only when user can mark) ──────────────────────
            if (widget.canMark)
              _ActionBar(
                markingAll: _markingAllPresent,
                onMarkAllPresent: () => _markAllPresent(rows),
                cs: cs,
              ),

            // ── Student list ──────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final currentStatus = row.attendance?.status;

                  return _StudentAttendanceTile(
                    student: row.student,
                    currentStatus: currentStatus,
                    cs: cs,
                    onStatusChanged: widget.canMark
                        ? (status) {
                            _markSingle(row.student.adm, status);
                          }
                        : null,
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

// ═════════════════════════════════════════════════════════════════════════════
// SUMMARY STRIP
// ═════════════════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.present,
    required this.absent,
    required this.leave,
    required this.unmarked,
    required this.cs,
  });

  final int total;
  final int present;
  final int absent;
  final int leave;
  final int unmarked;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Total',
            count: total,
            color: cs.onSurfaceVariant,
            cs: cs,
          ),
          const SizedBox(width: 16),
          _SummaryChip(
            label: 'Present',
            count: present,
            color: _kPresentColor,
            cs: cs,
          ),
          const SizedBox(width: 16),
          _SummaryChip(
            label: 'Absent',
            count: absent,
            color: _kAbsentColor,
            cs: cs,
          ),
          const SizedBox(width: 16),
          _SummaryChip(
            label: 'Leave',
            count: leave,
            color: _kLeaveColor,
            cs: cs,
          ),
          if (unmarked > 0) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$unmarked unmarked',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onErrorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
        const SizedBox(width: 5),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w300,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ACTION BAR
// ═════════════════════════════════════════════════════════════════════════════

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.markingAll,
    required this.onMarkAllPresent,
    required this.cs,
  });

  final bool markingAll;
  final VoidCallback onMarkAllPresent;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _ActionButton(
            icon: markingAll
                ? Icons.hourglass_top_rounded
                : Icons.done_all_rounded,
            label: markingAll ? 'Marking…' : 'Mark All Present',
            color: _kPresentColor,
            cs: cs,
            onTap: markingAll ? null : onMarkAllPresent,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.cs,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STUDENT ATTENDANCE TILE
// ═════════════════════════════════════════════════════════════════════════════

class _StudentAttendanceTile extends StatelessWidget {
  const _StudentAttendanceTile({
    required this.student,
    required this.currentStatus,
    required this.cs,
    required this.onStatusChanged,
  });

  final StudentsData student;
  final AttendanceStatus? currentStatus;
  final ColorScheme cs;

  /// Callback when a status button is tapped. `null` = read-only mode.
  final ValueChanged<AttendanceStatus>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final bgColor = _tileBackground(currentStatus, cs);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Student info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Adm: ${student.adm}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Status toggle buttons.
            _StatusToggleGroup(
              currentStatus: currentStatus,
              cs: cs,
              onStatusChanged: onStatusChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STATUS TOGGLE GROUP
// ═════════════════════════════════════════════════════════════════════════════

class _StatusToggleGroup extends StatelessWidget {
  const _StatusToggleGroup({
    required this.currentStatus,
    required this.cs,
    this.onStatusChanged,
  });

  final AttendanceStatus? currentStatus;
  final ColorScheme cs;

  /// Callback when a status button is tapped. `null` = read-only mode
  /// (buttons are visually disabled and non-interactive).
  final ValueChanged<AttendanceStatus>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onStatusChanged != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleButton(
              label: 'P',
              isActive: currentStatus == AttendanceStatus.present,
              activeColor: _kPresentColor,
              cs: cs,
              onTap: enabled
                  ? () => onStatusChanged!(AttendanceStatus.present)
                  : null,
            ),
            const SizedBox(width: 2),
            _ToggleButton(
              label: 'A',
              isActive: currentStatus == AttendanceStatus.absent,
              activeColor: _kAbsentColor,
              cs: cs,
              onTap: enabled
                  ? () => onStatusChanged!(AttendanceStatus.absent)
                  : null,
            ),
            const SizedBox(width: 2),
            _ToggleButton(
              label: 'L',
              isActive: currentStatus == AttendanceStatus.leave,
              activeColor: _kLeaveColor,
              cs: cs,
              onTap: enabled
                  ? () => onStatusChanged!(AttendanceStatus.leave)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color activeColor;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            color: isActive
                ? Colors.white
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HISTORY CALENDAR
// ═════════════════════════════════════════════════════════════════════════════

/// A monthly calendar view showing which days have been marked, partially
/// marked, or not marked at all. Tapping a day switches back to marking mode
/// for that date.
class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.calendarMonth,
    required this.dao,
    required this.cs,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final DateTime calendarMonth;
  final AttendanceDao dao;
  final ColorScheme cs;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoNext = DateTime(
      calendarMonth.year,
      calendarMonth.month + 1,
    ).isBefore(DateTime(now.year, now.month + 1));

    return StreamBuilder<List<DailyAttendanceSummary>>(
      stream: dao.watchDailyAttendanceSummaries(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
      ),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? [];

        // Build lookup of epochDays → summary.
        final summaryMap = <int, DailyAttendanceSummary>{};
        for (final s in summaries) {
          summaryMap[s.date] = s;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Month navigation ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: onPreviousMonth,
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    Text(
                      _fmtMonth(calendarMonth),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: canGoNext ? onNextMonth : null,
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: canGoNext
                            ? cs.onSurfaceVariant
                            : cs.onSurfaceVariant.withValues(alpha: 0.2),
                        size: 20,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Day-of-week headers ────────────────────────────────────
                Row(
                  children: kDayNames
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),

                // ── Calendar grid ──────────────────────────────────────────
                Expanded(child: _buildCalendarGrid(summaryMap, now)),

                // ── Legend ──────────────────────────────────────────────────
                const SizedBox(height: 12),
                _CalendarLegend(cs: cs),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    Map<int, DailyAttendanceSummary> summaryMap,
    DateTime today,
  ) {
    final firstDay = DateTime(calendarMonth.year, calendarMonth.month, 1);
    final daysInMonth = DateTime(
      calendarMonth.year,
      calendarMonth.month + 1,
      0,
    ).day;

    // Monday = 1 in DateTime.weekday.
    final startWeekday = firstDay.weekday;
    final leadingBlanks = startWeekday - 1;

    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (rowIdx) {
        return Expanded(
          child: Row(
            children: List.generate(7, (colIdx) {
              final cellIndex = rowIdx * 7 + colIdx;
              if (cellIndex < leadingBlanks ||
                  cellIndex >= leadingBlanks + daysInMonth) {
                return const Expanded(child: SizedBox.shrink());
              }

              final day = cellIndex - leadingBlanks + 1;
              final date = DateTime(
                calendarMonth.year,
                calendarMonth.month,
                day,
              );
              final epochDays = daysFromDate(date);
              final summary = summaryMap[epochDays];
              final isToday = _isSameDay(date, today);
              final isFuture = date.isAfter(today);
              final isWeekend = date.weekday == 6 || date.weekday == 7;

              // Determine marking status color.
              _MarkingStatus markingStatus;
              if (isFuture || isWeekend) {
                markingStatus = _MarkingStatus.none;
              } else if (summary == null) {
                markingStatus = _MarkingStatus.notMarked;
              } else if (summary.isFullyMarked) {
                markingStatus = _MarkingStatus.fullyMarked;
              } else {
                markingStatus = _MarkingStatus.partiallyMarked;
              }

              return Expanded(
                child: GestureDetector(
                  onTap: (isFuture || isWeekend)
                      ? null
                      : () => onDaySelected(date),
                  child: _CalendarDayCell(
                    day: day,
                    markingStatus: markingStatus,
                    isToday: isToday,
                    isFuture: isFuture || isWeekend,
                    attendanceRate: summary?.attendanceRate,
                    cs: cs,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

enum _MarkingStatus { none, notMarked, partiallyMarked, fullyMarked }

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.markingStatus,
    required this.isToday,
    required this.isFuture,
    this.attendanceRate,
    required this.cs,
  });

  final int day;
  final _MarkingStatus markingStatus;
  final bool isToday;
  final bool isFuture;
  final double? attendanceRate;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color textColor = cs.onSurface;

    if (isFuture) {
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.2);
    } else {
      switch (markingStatus) {
        case _MarkingStatus.fullyMarked:
          bgColor = _kPresentColor.withValues(alpha: 0.12);
          textColor = _kPresentColor;
        case _MarkingStatus.partiallyMarked:
          bgColor = _kLeaveColor.withValues(alpha: 0.12);
          textColor = _kLeaveColor;
        case _MarkingStatus.notMarked:
          bgColor = _kAbsentColor.withValues(alpha: 0.08);
          textColor = _kAbsentColor.withValues(alpha: 0.6);
        case _MarkingStatus.none:
          break;
      }
    }

    return Center(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
                color: textColor,
              ),
            ),
            if (markingStatus != _MarkingStatus.none &&
                markingStatus != _MarkingStatus.notMarked &&
                !isFuture)
              Container(
                margin: const EdgeInsets.only(top: 1),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CALENDAR LEGEND
// ═════════════════════════════════════════════════════════════════════════════

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(label: 'Fully marked', color: _kPresentColor, cs: cs),
        const SizedBox(width: 14),
        _LegendItem(label: 'Partial', color: _kLeaveColor, cs: cs),
        const SizedBox(width: 14),
        _LegendItem(
          label: 'Not marked',
          color: _kAbsentColor.withValues(alpha: 0.6),
          cs: cs,
        ),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w300,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'No students enrolled',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Enroll students to start marking attendance',
              style: TextStyle(
                fontSize: 12,
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
