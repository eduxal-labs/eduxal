import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'inline_calendar.dart';

/// Shows [InlineCalendar] inside a styled modal dialog.
///
/// This is a drop-in replacement for Flutter's [showDatePicker] that uses
/// the custom [InlineCalendar] widget (with year-picker support) instead of
/// the Material date picker dialog.
///
/// Returns the selected [DateTime], or `null` if the user dismissed without
/// selecting.
///
/// ```dart
/// final picked = await showInlineDatePicker(
///   context: context,
///   initialDate: _selectedDate,
///   firstDate: DateTime(1990),
///   lastDate: DateTime.now(),
/// );
/// if (picked != null) setState(() => _selectedDate = picked);
/// ```
Future<DateTime?> showInlineDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Select date',
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) {
      return _InlineDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
      );
    },
  );
}

class _InlineDatePickerDialog extends StatefulWidget {
  const _InlineDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  @override
  State<_InlineDatePickerDialog> createState() =>
      _InlineDatePickerDialogState();
}

class _InlineDatePickerDialogState extends State<_InlineDatePickerDialog> {
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.modalBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
          boxShadow: AppTheme.modalShadow(isDark),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),

            // Calendar — starts expanded (no trigger row needed inside dialog)
            _InlineCalendarExpanded(
              value: _selected,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onChanged: (d) {
                setState(() => _selected = d);
                // Auto-close with a short delay so the user sees the selection.
                if (d != null) {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (context.mounted) Navigator.of(context).pop(d);
                  });
                }
              },
            ),

            const SizedBox(height: 8),

            // Cancel button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A version of [InlineCalendar] that renders always-expanded (no trigger row,
/// no collapse animation). Used inside the dialog where the calendar should
/// always be visible.
class _InlineCalendarExpanded extends StatefulWidget {
  const _InlineCalendarExpanded({
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<_InlineCalendarExpanded> createState() =>
      _InlineCalendarExpandedState();
}

class _InlineCalendarExpandedState extends State<_InlineCalendarExpanded> {
  late DateTime _viewMonth;
  bool _showYearPicker = false;

  @override
  void initState() {
    super.initState();
    final base = widget.value ?? DateTime.now();
    // Clamp to valid range.
    final clamped = base.isBefore(widget.firstDate)
        ? widget.firstDate
        : base.isAfter(widget.lastDate)
        ? widget.lastDate
        : base;
    _viewMonth = DateTime(clamped.year, clamped.month);
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

  void _toggleYearPicker() {
    setState(() => _showYearPicker = !_showYearPicker);
  }

  void _selectYear(int year) {
    setState(() {
      _showYearPicker = false;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return CalendarGrid(
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
      onDayTap: (d) => widget.onChanged(d),
      onToggleYearPicker: _toggleYearPicker,
      onYearSelected: _selectYear,
    );
  }
}
