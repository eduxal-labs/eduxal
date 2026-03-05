import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/attendance_dao.dart';
import '../../../../database/daos/enrollments_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level entry point for the Attendance section.
///
/// Mounted from the dashboard shell under the "Attendance" nav label for
/// teachers, students, and guardians.
///
/// Role dispatch:
/// - **Teacher:** Class-based marking UI with date selector and toggle buttons.
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
      TeacherEntry() => _TeacherAttendanceShell(
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
      _ => _TeacherAttendanceShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER ATTENDANCE SHELL
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherAttendanceShell extends StatefulWidget {
  const _TeacherAttendanceShell({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_TeacherAttendanceShell> createState() =>
      _TeacherAttendanceShellState();
}

class _TeacherAttendanceShellState extends State<_TeacherAttendanceShell> {
  late final AttendanceDao _attendanceDao;
  late final EnrollmentsDao _enrollmentsDao;

  SchoolConfig _config = SchoolConfig.defaults();

  // Selected class.
  int? _selectedGrade;
  int? _selectedStream;

  // Selected date — defaults to today.
  late DateTime _selectedDate;
  late int _selectedDateEpochDays;

  // Available classes from enrollments.
  List<({int grade, int stream})> _availableClasses = [];
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _attendanceDao = AttendanceDao(db);
    _enrollmentsDao = EnrollmentsDao(db);
    _selectedDate = DateTime.now();
    _selectedDateEpochDays = _dateToEpochDays(_selectedDate);
    _loadConfig();
    _loadClasses();
  }

  Future<void> _loadConfig() async {
    final schoolId = widget.schoolContext.membership.school.id;
    final row = await settingsDao.getSettings(schoolId);
    if (row == null || !mounted) return;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(row.data) as Map);
      setState(() => _config = SchoolConfig.fromJson(decoded));
    } catch (_) {}
  }

  Future<void> _loadClasses() async {
    final term = widget.termContext.currentTerm;
    if (term == null) return;

    final schoolId = widget.schoolContext.membership.school.id;

    // Subscribe to populated classes stream.
    _enrollmentsDao
        .watchPopulatedClasses(
          schoolId: schoolId,
          year: term.year,
          term: term.term,
        )
        .listen((classes) {
          if (!mounted) return;
          setState(() {
            _availableClasses = classes;
            _loadingClasses = false;

            // Auto-select first class if nothing selected yet.
            if (_selectedGrade == null && classes.isNotEmpty) {
              _selectedGrade = classes.first.grade;
              _selectedStream = classes.first.stream;
            }
          });
        });
  }

  void _selectClass(int grade, int stream) {
    setState(() {
      _selectedGrade = grade;
      _selectedStream = stream;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: cs),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _selectedDateEpochDays = _dateToEpochDays(picked);
      });
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
        // ── Header bar ────────────────────────────────────────────────────
        _AttendanceHeader(
          config: _config,
          availableClasses: _availableClasses,
          selectedGrade: _selectedGrade,
          selectedStream: _selectedStream,
          selectedDate: _selectedDate,
          onClassSelected: _selectClass,
          onDateTap: () => _pickDate(context),
          cs: cs,
        ),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: _loadingClasses
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
              : (_selectedGrade != null && _selectedStream != null)
              ? _AttendanceMarkingList(
                  key: ValueKey(
                    '$_selectedGrade|$_selectedStream|$_selectedDateEpochDays',
                  ),
                  schoolId: widget.schoolContext.membership.school.id,
                  year: term.year,
                  term: term.term,
                  grade: _selectedGrade!,
                  stream: _selectedStream!,
                  date: _selectedDateEpochDays,
                  dao: _attendanceDao,
                  config: _config,
                  cs: cs,
                )
              : _EmptyClassesState(cs: cs),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance header — class selector + date picker
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceHeader extends StatelessWidget {
  const _AttendanceHeader({
    required this.config,
    required this.availableClasses,
    required this.selectedGrade,
    required this.selectedStream,
    required this.selectedDate,
    required this.onClassSelected,
    required this.onDateTap,
    required this.cs,
  });

  final SchoolConfig config;
  final List<({int grade, int stream})> availableClasses;
  final int? selectedGrade;
  final int? selectedStream;
  final DateTime selectedDate;
  final void Function(int grade, int stream) onClassSelected;
  final VoidCallback onDateTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
          // Title row with date picker.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              // Date chip.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDateTap,
                  borderRadius: BorderRadius.circular(AppTheme.kRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? cs.primary.withValues(alpha: 0.08)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: isToday ? cs.primary : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isToday ? 'Today' : _fmtDate(selectedDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isToday ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: isToday ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (availableClasses.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Class selector chips — horizontal scroll.
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableClasses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cls = availableClasses[index];
                  final isSelected =
                      cls.grade == selectedGrade &&
                      cls.stream == selectedStream;
                  final label = _classLabel(cls.grade, cls.stream, config);

                  return _ClassFilterChip(
                    label: label,
                    isSelected: isSelected,
                    cs: cs,
                    onTap: () => onClassSelected(cls.grade, cls.stream),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassFilterChip extends StatelessWidget {
  const _ClassFilterChip({
    required this.label,
    required this.isSelected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.1),
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
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance marking list — the core teacher experience
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceMarkingList extends StatefulWidget {
  const _AttendanceMarkingList({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.date,
    required this.dao,
    required this.config,
    required this.cs,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int date;
  final AttendanceDao dao;
  final SchoolConfig config;
  final ColorScheme cs;

  @override
  State<_AttendanceMarkingList> createState() => _AttendanceMarkingListState();
}

class _AttendanceMarkingListState extends State<_AttendanceMarkingList> {
  // In-memory draft statuses — tracks what the user has toggled before save.
  final Map<int, AttendanceStatus> _drafts = {};
  bool _saving = false;
  bool _hasUnsavedChanges = false;

  String get _accountId => cache.currentUser!.user.id;

  void _markAllPresent(List<StudentAttendanceRow> rows) {
    setState(() {
      for (final row in rows) {
        final serverStatus = row.attendance?.status;
        if (serverStatus != AttendanceStatus.present) {
          _drafts[row.student.adm] = AttendanceStatus.present;
        } else {
          _drafts.remove(row.student.adm);
        }
      }
      _hasUnsavedChanges = _drafts.isNotEmpty;
    });
  }

  Future<void> _saveAll() async {
    if (_drafts.isEmpty || _saving) return;
    setState(() => _saving = true);

    try {
      await widget.dao.markClassAttendance(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        grade: widget.grade,
        stream: widget.stream,
        date: widget.date,
        statuses: Map.from(_drafts),
        accountId: _accountId,
      );

      if (mounted) {
        setState(() {
          _drafts.clear();
          _hasUnsavedChanges = false;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Mark a single student immediately (zero extra taps after toggle).
  Future<void> _markSingle(int studentAdm, AttendanceStatus status) async {
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
    // Remove from drafts since it's now persisted.
    if (mounted) {
      setState(() {
        _drafts.remove(studentAdm);
        _hasUnsavedChanges = _drafts.isNotEmpty;
      });
    }
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
          return const SizedBox.shrink();
        }

        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return _EmptyStudentsState(cs: cs);
        }

        // Compute summary.
        int present = 0, absent = 0, leave = 0, unmarked = 0;
        for (final row in rows) {
          final draft = _drafts[row.student.adm];
          final status = draft ?? row.attendance?.status;
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

            // ── Action bar ────────────────────────────────────────────────
            _ActionBar(
              hasUnsavedChanges: _hasUnsavedChanges,
              saving: _saving,
              onMarkAllPresent: () => _markAllPresent(rows),
              onSave: _saveAll,
              cs: cs,
            ),

            // ── Student list ──────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final draftStatus = _drafts[row.student.adm];
                  final currentStatus = draftStatus ?? row.attendance?.status;
                  final isDirty = draftStatus != null;

                  return _StudentAttendanceTile(
                    student: row.student,
                    currentStatus: currentStatus,
                    isDirty: isDirty,
                    cs: cs,
                    onStatusChanged: (status) {
                      // Instant save for individual toggles.
                      _markSingle(row.student.adm, status);
                    },
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

// ─────────────────────────────────────────────────────────────────────────────
// Summary strip — compact attendance stats
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Action bar — Mark All Present + Save
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.hasUnsavedChanges,
    required this.saving,
    required this.onMarkAllPresent,
    required this.onSave,
    required this.cs,
  });

  final bool hasUnsavedChanges;
  final bool saving;
  final VoidCallback onMarkAllPresent;
  final VoidCallback onSave;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // Mark All Present button.
          _ActionButton(
            icon: Icons.done_all_rounded,
            label: 'Mark All Present',
            color: _kPresentColor,
            cs: cs,
            onTap: onMarkAllPresent,
          ),
          const Spacer(),
          if (hasUnsavedChanges || saving)
            _ActionButton(
              icon: saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              label: saving ? 'Saving…' : 'Save All',
              color: cs.primary,
              cs: cs,
              onTap: saving ? null : onSave,
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

// ─────────────────────────────────────────────────────────────────────────────
// Student attendance tile — the tactile toggle experience
// ─────────────────────────────────────────────────────────────────────────────

class _StudentAttendanceTile extends StatelessWidget {
  const _StudentAttendanceTile({
    required this.student,
    required this.currentStatus,
    required this.isDirty,
    required this.cs,
    required this.onStatusChanged,
  });

  final StudentsData student;
  final AttendanceStatus? currentStatus;
  final bool isDirty;
  final ColorScheme cs;
  final ValueChanged<AttendanceStatus> onStatusChanged;

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

class _StatusToggleGroup extends StatelessWidget {
  const _StatusToggleGroup({
    required this.currentStatus,
    required this.cs,
    required this.onStatusChanged,
  });

  final AttendanceStatus? currentStatus;
  final ColorScheme cs;
  final ValueChanged<AttendanceStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            onTap: () => onStatusChanged(AttendanceStatus.present),
          ),
          const SizedBox(width: 2),
          _ToggleButton(
            label: 'A',
            isActive: currentStatus == AttendanceStatus.absent,
            activeColor: _kAbsentColor,
            cs: cs,
            onTap: () => onStatusChanged(AttendanceStatus.absent),
          ),
          const SizedBox(width: 2),
          _ToggleButton(
            label: 'L',
            isActive: currentStatus == AttendanceStatus.leave,
            activeColor: _kLeaveColor,
            cs: cs,
            onTap: () => onStatusChanged(AttendanceStatus.leave),
          ),
        ],
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
  final VoidCallback onTap;

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
// Guardian summary card
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
        final totalDays = data?.totalDays ?? 0;
        final present = data?.present ?? 0;
        final absent = data?.absent ?? 0;
        final leave = data?.leave ?? 0;
        final rate = totalDays > 0 ? (present / totalDays * 100) : 0.0;

        return Container(
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
          child: Row(
            children: [
              // Attendance rate circle.
              _RateCircle(rate: rate, cs: cs),
              const SizedBox(width: 20),
              // Stats.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Term Overview',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatPill(
                          label: 'Present',
                          count: present,
                          color: _kPresentColor,
                          cs: cs,
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'Absent',
                          count: absent,
                          color: _kAbsentColor,
                          cs: cs,
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          label: 'Leave',
                          count: leave,
                          color: _kLeaveColor,
                          cs: cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$totalDays school days recorded',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
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
    final color = rate >= 90
        ? _kPresentColor
        : rate >= 75
        ? _kLeaveColor
        : _kAbsentColor;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: rate / 100,
              strokeWidth: 4,
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${rate.round()}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w300,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance calendar — month view with colored dots
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
    final now = DateTime.now();
    final canGoNext = DateTime(
      calendarMonth.year,
      calendarMonth.month + 1,
    ).isBefore(DateTime(now.year, now.month + 1));

    return StreamBuilder<List<StudentAttendanceRecord>>(
      stream: dao.watchStudentAttendanceHistory(
        schoolId: schoolId,
        year: year,
        term: term,
        studentAdm: studentAdm,
      ),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        // Build a lookup of epochDays → status.
        final statusMap = <int, AttendanceStatus>{};
        for (final r in records) {
          statusMap[r.date] = r.status;
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
                // Month navigation.
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

                // Day-of-week headers.
                Row(
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
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

                // Calendar grid.
                Expanded(child: _buildCalendarGrid(statusMap)),

                // Legend.
                const SizedBox(height: 12),
                _CalendarLegend(cs: cs),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(Map<int, AttendanceStatus> statusMap) {
    final firstDay = DateTime(calendarMonth.year, calendarMonth.month, 1);
    final daysInMonth = DateTime(
      calendarMonth.year,
      calendarMonth.month + 1,
      0,
    ).day;

    // Monday = 1 in DateTime.weekday. We want Mon as first column.
    final startWeekday = firstDay.weekday; // 1=Mon .. 7=Sun
    final leadingBlanks = startWeekday - 1;

    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

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
              final epochDays = _dateToEpochDays(date);
              final status = statusMap[epochDays];
              final isToday = _isSameDay(date, today);
              final isFuture = date.isAfter(today);

              return Expanded(
                child: _CalendarDayCell(
                  day: day,
                  status: status,
                  isToday: isToday,
                  isFuture: isFuture,
                  cs: cs,
                ),
              );
            }),
          ),
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
    Color? bgColor;
    Color textColor = cs.onSurface;

    if (isFuture) {
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.25);
    } else if (status != null) {
      bgColor = switch (status!) {
        AttendanceStatus.present => _kPresentColor.withValues(alpha: 0.12),
        AttendanceStatus.absent => _kAbsentColor.withValues(alpha: 0.12),
        AttendanceStatus.leave => _kLeaveColor.withValues(alpha: 0.12),
      };
      textColor = switch (status!) {
        AttendanceStatus.present => _kPresentColor,
        AttendanceStatus.absent => _kAbsentColor,
        AttendanceStatus.leave => _kLeaveColor,
      };
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
            if (status != null)
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
// EMPTY / PLACEHOLDER STATES
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
          Icon(
            Icons.event_busy_outlined,
            size: 36,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            'No active term',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create or select a term to begin tracking attendance.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.groups_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No classes with enrolled students',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enroll students into classes to start taking attendance.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStudentsState extends StatelessWidget {
  const _EmptyStudentsState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 36,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            'No students in this class',
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
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

// ── Status colors ────────────────────────────────────────────────────────────
// Muted, brand-aligned colors for attendance states. Slightly desaturated
// to keep the UI feeling composed rather than flashy.

const Color _kPresentColor = Color(0xFF4CAF50); // muted green
const Color _kAbsentColor = Color(0xFFEF5350); // muted red
const Color _kLeaveColor = Color(0xFFFFA726); // muted amber

/// Returns a very subtle tinted background for attendance tiles.
Color _tileBackground(AttendanceStatus? status, ColorScheme cs) {
  if (status == null) return cs.surface;
  return switch (status) {
    AttendanceStatus.present => _kPresentColor.withValues(alpha: 0.04),
    AttendanceStatus.absent => _kAbsentColor.withValues(alpha: 0.04),
    AttendanceStatus.leave => _kLeaveColor.withValues(alpha: 0.04),
  };
}

/// Converts a [DateTime] to days since Unix epoch (matching the schema's
/// `integer` date columns).
int _dateToEpochDays(DateTime dt) {
  return DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/
      (1000 * 60 * 60 * 24);
}

/// Checks if two [DateTime] values represent the same calendar day.
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String _fmtMonth(DateTime d) => '${_monthsFull[d.month - 1]} ${d.year}';

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

/// Returns a compact "Grade X · Stream Y" label for a class.
String _classLabel(int grade, int stream, SchoolConfig config) {
  final gl = _gradeLabel(grade, config);
  final sl = _streamLabel(grade, stream, config);
  return '$gl · $sl';
}

String _gradeLabel(int grade, SchoolConfig config) {
  for (final c in config.curricula) {
    final labels = gradeLabelsFor(c.type);
    if (labels.containsKey(grade)) return labels[grade]!;
  }
  return 'Grade $grade';
}

String _streamLabel(int grade, int streamCode, SchoolConfig config) {
  for (final c in config.curricula) {
    final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
    if (gc != null) {
      final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
      if (s != null) return s.name;
    }
  }
  return 'Stream $streamCode';
}
