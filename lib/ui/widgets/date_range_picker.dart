import 'package:flutter/material.dart';

/// Band position for range calendar day cells.
enum _BandPos { none, start, mid, end, single }

// ═════════════════════════════════════════════════════════════════════════════
//  DATE RANGE TRIGGER — tappable button that opens/closes the calendar
// ═════════════════════════════════════════════════════════════════════════════

class DateRangeTrigger extends StatelessWidget {
  const DateRangeTrigger({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.isOpen,
    required this.hasError,
    required this.enabled,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.onTap,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final bool isOpen;
  final bool hasError;
  final bool enabled;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final VoidCallback? onTap;

  bool get _hasRange => startDate != null && endDate != null;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);

    final borderColor = hasError
        ? cs.error.withValues(alpha: 0.65)
        : _hasRange
            ? indigo.withValues(alpha: isDark ? 0.55 : 0.45)
            : isOpen
                ? indigo.withValues(alpha: isDark ? 0.45 : 0.35)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4);

    final iconBg = _hasRange
        ? indigo.withValues(alpha: isDark ? 0.18 : 0.10)
        : isOpen
            ? indigo.withValues(alpha: isDark ? 0.12 : 0.07)
            : cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.25);

    final iconColor =
        _hasRange || isOpen ? indigo : cs.onSurfaceVariant.withValues(alpha: enabled ? 0.45 : 0.25);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: _hasRange || isOpen ? 1.5 : 1,
        ),
        boxShadow: _hasRange && !hasError
            ? [
                BoxShadow(
                  color: indigo.withValues(alpha: isDark ? 0.10 : 0.06),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return indigo.withValues(alpha: 0.05);
            }
            return Colors.transparent;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                // Icon badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    _hasRange
                        ? Icons.date_range_outlined
                        : Icons.calendar_today_outlined,
                    size: 12,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 9),

                // Label
                Expanded(
                  child: _hasRange
                      ? Row(
                          children: [
                            Text(
                              _fmt(startDate!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 10,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _fmt(endDate!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          startDate != null
                              ? '${_fmt(startDate!)}  →  …'
                              : 'Pick date range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: startDate != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: startDate != null
                                ? cs.onSurface.withValues(alpha: 0.75)
                                : cs.onSurfaceVariant
                                    .withValues(alpha: enabled ? 0.40 : 0.22),
                          ),
                        ),
                ),

                // Chevron
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: cs.onSurfaceVariant
                        .withValues(alpha: enabled ? 0.40 : 0.18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  INLINE RANGE CALENDAR — compact single-month grid, chevron navigation
// ═════════════════════════════════════════════════════════════════════════════

class DateRangeCalendar extends StatefulWidget {
  const DateRangeCalendar({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDayTapped,
    required this.isDark,
    required this.cs,
    required this.indigo,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime>? onDayTapped;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;

  @override
  State<DateRangeCalendar> createState() => _DateRangeCalendarState();
}

class _DateRangeCalendarState extends State<DateRangeCalendar> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    final seed = widget.startDate ?? DateTime.now();
    _viewMonth = DateTime(seed.year, seed.month);
  }

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fill =
        widget.isDark ? const Color(0xFF141E2A) : widget.cs.surfaceContainer.withValues(alpha: 0.60);
    final border = widget.cs.outlineVariant
        .withValues(alpha: widget.isDark ? 0.20 : 0.35);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthHeader(
            viewMonth: _viewMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
            isDark: widget.isDark,
            cs: widget.cs,
          ),
          const SizedBox(height: 6),
          _WeekdayRow(isDark: widget.isDark, cs: widget.cs),
          const SizedBox(height: 2),
          _DayGrid(
            viewMonth: _viewMonth,
            startDate: widget.startDate,
            endDate: widget.endDate,
            onDayTapped: widget.onDayTapped,
            isDark: widget.isDark,
            cs: widget.cs,
            indigo: widget.indigo,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month header with chevrons
// ─────────────────────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.viewMonth,
    required this.onPrev,
    required this.onNext,
    required this.isDark,
    required this.cs,
  });

  final DateTime viewMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isDark;
  final ColorScheme cs;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final chevronColor = cs.onSurfaceVariant.withValues(alpha: 0.50);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ChevronBtn(
          icon: Icons.chevron_left,
          onTap: onPrev,
          color: chevronColor,
        ),
        Text(
          '${_monthNames[viewMonth.month - 1]} ${viewMonth.year}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            letterSpacing: 0.1,
          ),
        ),
        _ChevronBtn(
          icon: Icons.chevron_right,
          onTap: onNext,
          color: chevronColor,
        ),
      ],
    );
  }
}

class _ChevronBtn extends StatelessWidget {
  const _ChevronBtn({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekday labels row
// ─────────────────────────────────────────────────────────────────────────────

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.isDark, required this.cs});

  final bool isDark;
  final ColorScheme cs;

  static const _labels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels.map((label) {
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day grid
// ─────────────────────────────────────────────────────────────────────────────

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.viewMonth,
    required this.startDate,
    required this.endDate,
    required this.onDayTapped,
    required this.isDark,
    required this.cs,
    required this.indigo,
  });

  final DateTime viewMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime>? onDayTapped;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday % 7; // Sun=0

    final totalCells = startWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rowCount, (row) {
        return SizedBox(
          height: 28,
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - startWeekday + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return Expanded(
                  child: _OverflowCell(
                    viewMonth: viewMonth,
                    dayNum: dayNum,
                    daysInMonth: daysInMonth,
                    isDark: isDark,
                    cs: cs,
                  ),
                );
              }

              final date = DateTime(viewMonth.year, viewMonth.month, dayNum);
              final isToday = date == todayDate;
              final isStart = _sameDay(date, startDate);
              final isEnd = _sameDay(date, endDate);
              final isEndpoint = isStart || isEnd;

              final inRange = startDate != null &&
                  endDate != null &&
                  date.isAfter(startDate!) &&
                  date.isBefore(endDate!);

              _BandPos bandPos = _BandPos.none;
              if (isStart && endDate != null && !isEnd) {
                bandPos = _BandPos.start;
              } else if (isEnd && startDate != null && !isStart) {
                bandPos = _BandPos.end;
              } else if (inRange) {
                bandPos = _BandPos.mid;
              } else if (isStart && isEnd) {
                bandPos = _BandPos.single;
              }

              return Expanded(
                child: _DayCell(
                  day: dayNum,
                  isToday: isToday,
                  isEndpoint: isEndpoint,
                  bandPos: bandPos,
                  isDark: isDark,
                  cs: cs,
                  indigo: indigo,
                  onTap: onDayTapped != null ? () => onDayTapped!(date) : null,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  bool _sameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overflow cell
// ─────────────────────────────────────────────────────────────────────────────

class _OverflowCell extends StatelessWidget {
  const _OverflowCell({
    required this.viewMonth,
    required this.dayNum,
    required this.daysInMonth,
    required this.isDark,
    required this.cs,
  });

  final DateTime viewMonth;
  final int dayNum;
  final int daysInMonth;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    int display;
    if (dayNum < 1) {
      final prevMonth = DateTime(viewMonth.year, viewMonth.month, 0);
      display = prevMonth.day + dayNum;
    } else {
      display = dayNum - daysInMonth;
    }
    return Center(
      child: Text(
        '$display',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: isDark ? 0.18 : 0.22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day cell
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isEndpoint,
    required this.bandPos,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isEndpoint;
  final _BandPos bandPos;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bandColor = indigo.withValues(alpha: isDark ? 0.16 : 0.11);
    final hasBand = bandPos != _BandPos.none && bandPos != _BandPos.single;

    const double circleDia = 24;
    const double halfCircle = circleDia / 2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Range band background ─────────────────────────────────────
          if (hasBand)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.only(
                  left: bandPos == _BandPos.start ? halfCircle : 0,
                  right: bandPos == _BandPos.end ? halfCircle : 0,
                ),
                decoration: BoxDecoration(
                  color: bandColor,
                  borderRadius: BorderRadius.horizontal(
                    left: bandPos == _BandPos.start
                        ? Radius.circular(halfCircle)
                        : Radius.zero,
                    right: bandPos == _BandPos.end
                        ? Radius.circular(halfCircle)
                        : Radius.zero,
                  ),
                ),
              ),
            ),

          // ── Circle / ring ─────────────────────────────────────────────
          Container(
            width: circleDia,
            height: circleDia,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEndpoint ? indigo : Colors.transparent,
              border: isToday && !isEndpoint
                  ? Border.all(color: indigo, width: 1.2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isEndpoint || isToday ? FontWeight.w600 : FontWeight.w400,
                color: isEndpoint
                    ? Colors.white
                    : isToday
                        ? indigo
                        : cs.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
