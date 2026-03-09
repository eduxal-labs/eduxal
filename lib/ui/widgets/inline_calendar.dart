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
            child: _CalendarGrid(
              viewMonth: _viewMonth,
              selected: widget.value,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              accent: accent,
              cs: cs,
              isDark: isDark,
              onPrevMonth: _prevMonth,
              onNextMonth: _nextMonth,
              onDayTap: _selectDay,
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

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
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
                _NavArrow(
                  icon: Icons.chevron_left,
                  enabled: canPrev,
                  cs: cs,
                  onTap: onPrevMonth,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_kMonthNames[viewMonth.month - 1]} ${viewMonth.year}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                _NavArrow(
                  icon: Icons.chevron_right,
                  enabled: canNext,
                  cs: cs,
                  onTap: onNextMonth,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── Day-of-week header ───────────────────────────────────────
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

          // ── Day grid ─────────────────────────────────────────────────
          // Compute rows needed (always render exactly as many as required).
          ..._buildWeekRows(
            daysInMonth: daysInMonth,
            startWeekday: startWeekday,
            today: today,
          ),
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
            _DayCell(
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
            _DayCell(
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
            _DayCell(
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

class _DayCell extends StatelessWidget {
  const _DayCell({
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

class _NavArrow extends StatelessWidget {
  const _NavArrow({
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
