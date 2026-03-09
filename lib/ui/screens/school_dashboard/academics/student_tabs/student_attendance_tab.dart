import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/attendance_dao.dart';
import '../../../../../database/tables/enums.dart';

/// Attendance tab for the Student Grade Page — shows the student's attendance
/// record for the current term with a summary bar, month-grouped calendar
/// heatmap, and a detailed list of records.
///
/// Data source: [AttendanceDao.watchStudentAttendanceHistory] for individual
/// records and [AttendanceDao.watchStudentAttendanceSummary] for aggregate
/// counts.
class StudentAttendanceTab extends StatefulWidget {
  const StudentAttendanceTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.studentAdm,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final int studentAdm;

  @override
  State<StudentAttendanceTab> createState() => _StudentAttendanceTabState();
}

class _StudentAttendanceTabState extends State<StudentAttendanceTab>
    with AutomaticKeepAliveClientMixin {
  late final AttendanceDao _attendanceDao;

  late Stream<List<StudentAttendanceRecord>> _historyStream;
  late Stream<({int totalDays, int present, int absent, int leave})>
  _summaryStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _attendanceDao = AttendanceDao(db);
    _buildStreams();
  }

  @override
  void didUpdateWidget(covariant StudentAttendanceTab oldWidget) {
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
    _historyStream = _attendanceDao.watchStudentAttendanceHistory(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      studentAdm: widget.studentAdm,
    );
    _summaryStream = _attendanceDao.watchStudentAttendanceSummary(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      studentAdm: widget.studentAdm,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<({int totalDays, int present, int absent, int leave})>(
      stream: _summaryStream,
      builder: (context, summarySnap) {
        return StreamBuilder<List<StudentAttendanceRecord>>(
          stream: _historyStream,
          builder: (context, historySnap) {
            final summary = summarySnap.data;
            final records = historySnap.data;

            // Loading state.
            if (!summarySnap.hasData || !historySnap.hasData) {
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              );
            }

            // Empty state.
            if (summary == null ||
                summary.totalDays == 0 ||
                records == null ||
                records.isEmpty) {
              return _buildEmpty(cs);
            }

            // Build month groups from records (records are ordered asc).
            final monthGroups = _groupByMonth(records);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // ── Summary bar ──────────────────────────────────────────
                _SummaryBar(cs: cs, isDark: isDark, summary: summary),

                const SizedBox(height: 18),

                // ── Calendar heatmap per month ───────────────────────────
                ...monthGroups.entries.expand(
                  (entry) => [
                    _MonthCalendar(
                      cs: cs,
                      isDark: isDark,
                      year: entry.key.year,
                      month: entry.key.month,
                      records: entry.value,
                    ),
                    const SizedBox(height: 14),
                  ],
                ),

                const SizedBox(height: 4),

                // ── Section header ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'All Records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // ── Detailed list grouped by month ───────────────────────
                ...monthGroups.entries.expand(
                  (entry) => [
                    // Month header.
                    _MonthHeader(
                      cs: cs,
                      year: entry.key.year,
                      month: entry.key.month,
                      count: entry.value.length,
                    ),
                    const SizedBox(height: 4),
                    // Records in this month — most recent first.
                    ...entry.value.reversed.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _RecordRow(cs: cs, isDark: isDark, record: r),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
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
                Icons.calendar_today_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No attendance records',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Records will appear here once attendance is marked',
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

  /// Groups records by (year, month) preserving ascending order within each
  /// group. Returns a [LinkedHashMap] ordered by month ascending so that the
  /// most recent months appear last.
  Map<({int year, int month}), List<StudentAttendanceRecord>> _groupByMonth(
    List<StudentAttendanceRecord> records,
  ) {
    final groups = <({int year, int month}), List<StudentAttendanceRecord>>{};
    for (final r in records) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        r.date * Duration.millisecondsPerDay,
        isUtc: true,
      );
      final key = (year: dt.year, month: dt.month);
      (groups[key] ??= []).add(r);
    }
    // Sort keys so the most recent month comes first (reverse chronological).
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final cmp = b.year.compareTo(a.year);
        return cmp != 0 ? cmp : b.month.compareTo(a.month);
      });
    return {for (final k in sortedKeys) k: groups[k]!};
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Summary bar — 3 stat chips
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.cs,
    required this.isDark,
    required this.summary,
  });

  final ColorScheme cs;
  final bool isDark;
  final ({int totalDays, int present, int absent, int leave}) summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalDays;
    final presentPct = total > 0 ? (summary.present / total * 100) : 0.0;
    final absentPct = total > 0 ? (summary.absent / total * 100) : 0.0;
    final leavePct = total > 0 ? (summary.leave / total * 100) : 0.0;

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
          // Stacked proportion bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (summary.present > 0)
                    Expanded(
                      flex: summary.present,
                      child: Container(color: const Color(0xFF4CAF50)),
                    ),
                  if (summary.absent > 0)
                    Expanded(
                      flex: summary.absent,
                      child: Container(color: const Color(0xFFF44336)),
                    ),
                  if (summary.leave > 0)
                    Expanded(
                      flex: summary.leave,
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
              _SummaryStat(
                cs: cs,
                label: 'Present',
                count: summary.present,
                percent: presentPct,
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 16),
              _SummaryStat(
                cs: cs,
                label: 'Absent',
                count: summary.absent,
                percent: absentPct,
                color: const Color(0xFFF44336),
              ),
              const SizedBox(width: 16),
              _SummaryStat(
                cs: cs,
                label: 'Leave',
                count: summary.leave,
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
                    '$total',
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
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
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
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
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
          '$count (${percent.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Month calendar heatmap
// ═══════════════════════════════════════════════════════════════════════════════

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.cs,
    required this.isDark,
    required this.year,
    required this.month,
    required this.records,
  });

  final ColorScheme cs;
  final bool isDark;
  final int year;
  final int month;
  final List<StudentAttendanceRecord> records;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthNames = [
    '',
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

  @override
  Widget build(BuildContext context) {
    // Build a lookup: day-of-month → status.
    final statusMap = <int, AttendanceStatus>{};
    for (final r in records) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        r.date * Duration.millisecondsPerDay,
        isUtc: true,
      );
      statusMap[dt.day] = r.status;
    }

    final firstDay = DateTime.utc(year, month, 1);
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    // Monday = 1, Sunday = 7.
    final startWeekday = firstDay.weekday; // 1 = Mon

    // Build grid cells.
    // Offset is the number of empty cells before the 1st of the month.
    final offset = startWeekday - 1; // Monday-based
    final cellCount = offset + daysInMonth;
    final rowCount = (cellCount / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month title.
          Text(
            '${_monthNames[month]} $year',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),

          // Day-of-week header.
          Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // Calendar grid.
          ...List.generate(rowCount, (row) {
            return Padding(
              padding: EdgeInsets.only(bottom: row < rowCount - 1 ? 3 : 0),
              child: Row(
                children: List.generate(7, (col) {
                  final index = row * 7 + col;
                  final day = index - offset + 1;
                  if (day < 1 || day > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 26));
                  }

                  final status = statusMap[day];
                  final isWeekend = col >= 5; // Sat = 5, Sun = 6 (0-indexed)

                  return Expanded(
                    child: _DayCell(
                      cs: cs,
                      isDark: isDark,
                      day: day,
                      status: status,
                      isWeekend: isWeekend,
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.cs,
    required this.isDark,
    required this.day,
    required this.status,
    required this.isWeekend,
  });

  final ColorScheme cs;
  final bool isDark;
  final int day;
  final AttendanceStatus? status;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;

    if (status != null) {
      final statusColor = switch (status!) {
        AttendanceStatus.present => const Color(0xFF4CAF50),
        AttendanceStatus.absent => const Color(0xFFF44336),
        AttendanceStatus.leave => const Color(0xFFFFA726),
      };
      bgColor = statusColor.withValues(alpha: isDark ? 0.25 : 0.15);
      textColor = statusColor;
    } else if (isWeekend) {
      bgColor = Colors.transparent;
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.2);
    } else {
      bgColor = Colors.transparent;
      textColor = cs.onSurfaceVariant.withValues(alpha: 0.3);
    }

    return SizedBox(
      height: 26,
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 10,
              fontWeight: status != null ? FontWeight.w500 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Month header
// ═══════════════════════════════════════════════════════════════════════════════

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.cs,
    required this.year,
    required this.month,
    required this.count,
  });

  final ColorScheme cs;
  final int year;
  final int month;
  final int count;

  static const _monthNames = [
    '',
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            '${_monthNames[month]} $year',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Record row
// ═══════════════════════════════════════════════════════════════════════════════

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.cs,
    required this.isDark,
    required this.record,
  });

  final ColorScheme cs;
  final bool isDark;
  final StudentAttendanceRecord record;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    '',
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

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      record.date * Duration.millisecondsPerDay,
      isUtc: true,
    );
    final dayName = _weekdays[dt.weekday - 1];
    final dateStr = '$dayName, ${dt.day} ${_months[dt.month]}';

    final (label, color) = switch (record.status) {
      AttendanceStatus.present => ('Present', const Color(0xFF4CAF50)),
      AttendanceStatus.absent => ('Absent', const Color(0xFFF44336)),
      AttendanceStatus.leave => ('Leave', const Color(0xFFFFA726)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.04 : 0.03),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Date.
          Expanded(
            child: Text(
              dateStr,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),

          // Status chip.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
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
                    fontWeight: FontWeight.w500,
                    color: color,
                    letterSpacing: 0.1,
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
