import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inline Calendar — compact, embeddable date picker
// ─────────────────────────────────────────────────────────────────────────────
//
// Inspired by dashboard-style calendars: tight grid, no dialog, no overlay.
// Meant to be embedded directly inside a form column.
//
// Usage:
//   InlineCalendar(
//     value: _selectedDate,
//     firstDate: DateTime(1990),
//     lastDate: DateTime.now(),
//     onChanged: (d) => setState(() => _selectedDate = d),
//   )
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kDayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

const List<String> _kMonthNames = [
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

class InlineCalendar extends StatefulWidget {
  const InlineCalendar({
    super.key,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.hint = 'Select a date',
    this.icon = Icons.calendar_today_outlined,
  });

  /// Currently selected date, or null if nothing selected yet.
  final DateTime? value;

  /// Earliest selectable date.
  final DateTime firstDate;

  /// Latest selectable date.
  final DateTime lastDate;

  /// Called when the user taps a day cell (or clears the selection).
  final ValueChanged<DateTime?> onChanged;

  /// Placeholder text shown in the trigger row when [value] is null.
  final String hint;

  /// Leading icon for the trigger row.
  final IconData icon;

  @override
  State<InlineCalendar> createState() => _InlineCalendarState();
}

class _InlineCalendarState extends State<InlineCalendar>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late DateTime _viewMonth; // first day of the month currently shown
  bool _showYearPicker = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _viewMonth = _toMonth(widget.value ?? DateTime.now());
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant InlineCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the external value changed to a date in a different month, snap view.
    if (widget.value != null && oldWidget.value != widget.value) {
      final m = _toMonth(widget.value!);
      if (m != _viewMonth) setState(() => _viewMonth = m);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  void _prevMonth() {
    final prev = DateTime(_viewMonth.year, _viewMonth.month - 1);
    if (!prev.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    )) {
      setState(() => _viewMonth = prev);
    }
  }

  void _nextMonth() {
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    if (!next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month))) {
      setState(() => _viewMonth = next);
    }
  }

  void _selectDay(DateTime day) {
    widget.onChanged(day);
    // Auto-collapse after selection.
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted && _expanded) _toggle();
    });
  }

  void _toggleYearPicker() {
    setState(() => _showYearPicker = !_showYearPicker);
  }

  void _selectYear(int year) {
    setState(() {
      _showYearPicker = false;
      // Clamp the month to firstDate/lastDate bounds in the selected year.
      int month = _viewMonth.month;
      if (year == widget.firstDate.year && month < widget.firstDate.month) {
        month = widget.firstDate.month;
      }
      if (year == widget.lastDate.year && month > widget.lastDate.month) {
        month = widget.lastDate.month;
      }
      _viewMonth = DateTime(year, month);
    });
  }

  static DateTime _toMonth(DateTime d) => DateTime(d.year, d.month);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.2 : 0.35,
    );
    final display = widget.value != null ? _fmtDate(widget.value!) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Trigger row ──────────────────────────────────────────────────
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLow,
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(8))
                  : BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 17,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    display ?? widget.hint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: display != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                if (widget.value != null)
                  GestureDetector(
                    onTap: () => widget.onChanged(null),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.close,
                        size: 15,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Calendar body ────────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              border: Border(
                left: BorderSide(color: borderColor),
                right: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: CalendarGrid(
              viewMonth: _viewMonth,
              selected: widget.value,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              accent: accent,
              cs: cs,
              isDark: isDark,
              showYearPicker: _showYearPicker,
              onPrevMonth: _prevMonth,
              onNextMonth: _nextMonth,
              onDayTap: _selectDay,
              onToggleYearPicker: _toggleYearPicker,
              onYearSelected: _selectYear,
            ),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar grid — stateless, pure rendering
// ─────────────────────────────────────────────────────────────────────────────

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.viewMonth,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.accent,
    required this.cs,
    required this.isDark,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDayTap,
    required this.showYearPicker,
    required this.onToggleYearPicker,
    required this.onYearSelected,
  });

  final DateTime viewMonth;
  final DateTime? selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color accent;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDayTap;
  final bool showYearPicker;
  final VoidCallback onToggleYearPicker;
  final ValueChanged<int> onYearSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Can navigate?
    final canPrev = !DateTime(
      viewMonth.year,
      viewMonth.month - 1,
    ).isBefore(DateTime(firstDate.year, firstDate.month));
    final canNext = !DateTime(
      viewMonth.year,
      viewMonth.month + 1,
    ).isAfter(DateTime(lastDate.year, lastDate.month));

    // Build the 6-row grid of day cells.
    final firstOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday % 7; // 0 = Sunday

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin separator from the trigger row.
          Container(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.25),
          ),
          const SizedBox(height: 8),

          // ── Month / year header ──────────────────────────────────────
          SizedBox(
            height: 32,
            child: Row(
              children: [
                // Left nav arrow — hidden when year picker is open
                if (showYearPicker)
                  const SizedBox(width: 32)
                else
                  NavArrow(
                    icon: Icons.chevron_left,
                    enabled: canPrev,
                    cs: cs,
                    onTap: onPrevMonth,
                  ),

                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: onToggleYearPicker,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            showYearPicker
                                ? '${viewMonth.year}'
                                : '${_kMonthNames[viewMonth.month - 1]} ${viewMonth.year}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: showYearPicker ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right nav arrow — hidden when year picker is open
                if (showYearPicker)
                  const SizedBox(width: 32)
                else
                  NavArrow(
                    icon: Icons.chevron_right,
                    enabled: canNext,
                    cs: cs,
                    onTap: onNextMonth,
                  ),
              ],
            ),
          ),

          // ── Body: year picker OR day grid ────────────────────────────
          if (showYearPicker)
            YearGrid(
              firstYear: firstDate.year,
              lastYear: lastDate.year,
              currentYear: viewMonth.year,
              accent: accent,
              cs: cs,
              isDark: isDark,
              onYearSelected: onYearSelected,
            )
          else ...[
            const SizedBox(height: 6),

            // ── Day-of-week header ─────────────────────────────────────
            Row(
              children: [
                for (final label in _kDayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // ── Day grid ───────────────────────────────────────────────
            ..._buildWeekRows(
              daysInMonth: daysInMonth,
              startWeekday: startWeekday,
              today: today,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildWeekRows({
    required int daysInMonth,
    required int startWeekday,
    required DateTime today,
  }) {
    final rows = <Widget>[];
    var dayCounter = 1;

    // Previous month's trailing days.
    final prevMonthDays = DateTime(viewMonth.year, viewMonth.month, 0).day;

    // Number of rows needed.
    final totalCells = startWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    for (var row = 0; row < rowCount; row++) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;

        if (cellIndex < startWeekday) {
          // Leading days from previous month.
          final prevDay = prevMonthDays - startWeekday + cellIndex + 1;
          cells.add(
            DayCell(
              day: prevDay,
              isOutside: true,
              isToday: false,
              isSelected: false,
              isDisabled: true,
              accent: accent,
              cs: cs,
              isDark: isDark,
              onTap: null,
            ),
          );
        } else if (dayCounter <= daysInMonth) {
          final d = dayCounter;
          final date = DateTime(viewMonth.year, viewMonth.month, d);
          final dateOnly = DateTime(date.year, date.month, date.day);
          final firstOnly = DateTime(
            firstDate.year,
            firstDate.month,
            firstDate.day,
          );
          final lastOnly = DateTime(
            lastDate.year,
            lastDate.month,
            lastDate.day,
          );
          final isDisabled =
              dateOnly.isBefore(firstOnly) || dateOnly.isAfter(lastOnly);
          final isToday = dateOnly == today;
          final isSelected =
              selected != null &&
              selected!.year == date.year &&
              selected!.month == date.month &&
              selected!.day == date.day;

          cells.add(
            DayCell(
              day: d,
              isOutside: false,
              isToday: isToday,
              isSelected: isSelected,
              isDisabled: isDisabled,
              accent: accent,
              cs: cs,
              isDark: isDark,
              onTap: isDisabled ? null : () => onDayTap(date),
            ),
          );
          dayCounter++;
        } else {
          // Trailing days from next month.
          final nextDay = dayCounter - daysInMonth;
          cells.add(
            DayCell(
              day: nextDay,
              isOutside: true,
              isToday: false,
              isSelected: false,
              isDisabled: true,
              accent: accent,
              cs: cs,
              isDark: isDark,
              onTap: null,
            ),
          );
          dayCounter++;
        }
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : 2),
          child: Row(children: cells),
        ),
      );
    }
    return rows;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day cell
// ─────────────────────────────────────────────────────────────────────────────

class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.isOutside,
    required this.isToday,
    required this.isSelected,
    required this.isDisabled,
    required this.accent,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final int day;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;
  final bool isDisabled;
  final Color accent;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Sizing: each cell is an Expanded in a 7-col Row.
    // Inner content is a small square with optional accent fill.
    final Color textColor;
    final Color? bgColor;
    final BoxBorder? border;
    final FontWeight weight;

    if (isSelected) {
      textColor = Colors.white;
      bgColor = accent;
      border = null;
      weight = FontWeight.w500;
    } else if (isToday) {
      textColor = accent;
      bgColor = null;
      border = Border.all(color: accent, width: 1);
      weight = FontWeight.w500;
    } else if (isOutside || isDisabled) {
      textColor = cs.onSurface.withValues(alpha: 0.3);
      bgColor = null;
      border = null;
      weight = FontWeight.w400;
    } else {
      textColor = cs.onSurface;
      bgColor = null;
      border = null;
      weight = FontWeight.w400;
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: border,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: weight,
                color: textColor,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation arrow
// ─────────────────────────────────────────────────────────────────────────────

class NavArrow extends StatelessWidget {
  const NavArrow({
    super.key,
    required this.icon,
    required this.enabled,
    required this.cs,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? cs.onSurface.withValues(alpha: 0.85)
                : cs.onSurface.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year grid — scrollable 3-column grid of year cells
// ─────────────────────────────────────────────────────────────────────────────

class YearGrid extends StatefulWidget {
  const YearGrid({
    super.key,
    required this.firstYear,
    required this.lastYear,
    required this.currentYear,
    required this.accent,
    required this.cs,
    required this.isDark,
    required this.onYearSelected,
  });

  final int firstYear;
  final int lastYear;
  final int currentYear;
  final Color accent;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<int> onYearSelected;

  @override
  State<YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<YearGrid> {
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    // Pre-scroll so the current year is roughly centred.
    final totalYears = widget.lastYear - widget.firstYear + 1;
    final currentIndex = widget.currentYear - widget.firstYear;
    // 3 columns, each row ~40px tall.
    final rowIndex = currentIndex ~/ 3;
    final totalRows = (totalYears / 3).ceil();
    // Show ~4 rows (160px). Offset so current row is in the middle.
    const visibleRows = 4.0;
    const rowHeight = 40.0;
    final maxScroll = ((totalRows - visibleRows) * rowHeight).clamp(
      0.0,
      double.maxFinite,
    );
    final targetScroll = ((rowIndex - visibleRows / 2) * rowHeight).clamp(
      0.0,
      maxScroll,
    );
    _scrollCtrl = ScrollController(initialScrollOffset: targetScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      widget.lastYear - widget.firstYear + 1,
      (i) => widget.firstYear + i,
    );

    // Build rows of 3.
    final rows = <Widget>[];
    for (var i = 0; i < years.length; i += 3) {
      final rowYears = years.skip(i).take(3).toList();
      rows.add(
        Row(
          children: [
            for (final year in rowYears)
              Expanded(
                child: YearCell(
                  year: year,
                  isSelected: year == widget.currentYear,
                  accent: widget.accent,
                  cs: widget.cs,
                  onTap: () => widget.onYearSelected(year),
                ),
              ),
            // Pad incomplete last row.
            for (var p = rowYears.length; p < 3; p++)
              const Expanded(child: SizedBox()),
          ],
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: rows,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year cell
// ─────────────────────────────────────────────────────────────────────────────

class YearCell extends StatelessWidget {
  const YearCell({
    super.key,
    required this.year,
    required this.isSelected,
    required this.accent,
    required this.cs,
    required this.onTap,
  });

  final int year;
  final bool isSelected;
  final Color accent;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accent : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$year',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? Colors.white : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
