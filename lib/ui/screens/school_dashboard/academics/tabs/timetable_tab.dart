import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/timetable_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../database/tables/enums.dart';

import '../../../../../models/school_context.dart';

/// Timetable tab — displays the weekly schedule for a specific stream within
/// a grade.
///
/// **Desktop (≥ 600px):** Weekly grid with Mon–Fri columns and time-slot rows.
/// **Mobile (< 600px):** Horizontal day selector + vertical slot list.
///
/// Each slot shows the subject name (resolved via [CurriculumType]) and the
/// teacher's name. Empty slots are rendered as dashed/muted placeholders.
class TimetableTab extends StatefulWidget {
  const TimetableTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.streamCode,
    required this.streamName,
    required this.curriculumType,
    required this.schoolContext,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? streamCode;
  final String streamName;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab>
    with AutomaticKeepAliveClientMixin {
  late final TimetableDao _dao;
  late Stream<List<TimetableEntry>> _stream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dao = TimetableDao(db);
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant TimetableTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term ||
        oldWidget.grade != widget.grade ||
        oldWidget.streamCode != widget.streamCode) {
      setState(() => _stream = _buildStream());
    }
  }

  Stream<List<TimetableEntry>> _buildStream() {
    return _dao.watchClassTimetable(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<TimetableEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoading(cs);
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return _buildEmpty(cs);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return _DesktopGrid(
                entries: entries,
                curriculumType: widget.curriculumType,
              );
            }
            return _MobileDayPager(
              entries: entries,
              curriculumType: widget.curriculumType,
            );
          },
        );
      },
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

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
                Icons.calendar_view_week_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No timetable configured',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'No timetable configured for ${widget.streamName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════════

const _dayLabels = {
  DayOfWeek.monday: 'Mon',
  DayOfWeek.tuesday: 'Tue',
  DayOfWeek.wednesday: 'Wed',
  DayOfWeek.thursday: 'Thu',
  DayOfWeek.friday: 'Fri',
  DayOfWeek.saturday: 'Sat',
  DayOfWeek.sunday: 'Sun',
};

const _dayFullLabels = {
  DayOfWeek.monday: 'Monday',
  DayOfWeek.tuesday: 'Tuesday',
  DayOfWeek.wednesday: 'Wednesday',
  DayOfWeek.thursday: 'Thursday',
  DayOfWeek.friday: 'Friday',
  DayOfWeek.saturday: 'Saturday',
  DayOfWeek.sunday: 'Sunday',
};

/// Format seconds since midnight → "HH:MM" (24-hour).
String _fmtTime(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Deterministic subject color based on subject index.
Color _subjectColor(int subjectIndex) {
  const palette = [
    Color(0xFF5C6BC0), // indigo
    Color(0xFF26A69A), // teal
    Color(0xFFEF5350), // red
    Color(0xFFAB47BC), // purple
    Color(0xFF42A5F5), // blue
    Color(0xFFFF7043), // deep orange
    Color(0xFF66BB6A), // green
    Color(0xFFFFA726), // orange
    Color(0xFF78909C), // blue grey
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF29B6F6), // light blue
    Color(0xFFD4E157), // lime
    Color(0xFF7E57C2), // deep purple
    Color(0xFF26C6DA), // cyan
  ];
  return palette[subjectIndex % palette.length];
}

/// Groups entries by a unique time-slot start value, returning ordered unique
/// start times present in the data.
List<int> _uniqueStartTimes(List<TimetableEntry> entries) {
  final starts = entries.map((e) => e.slot.start).toSet().toList()..sort();
  return starts;
}

/// Returns all unique days present in the entries, ordered Mon–Fri
/// (or including Sat/Sun if they appear).
List<DayOfWeek> _activeDays(List<TimetableEntry> entries) {
  final daySet = entries.map((e) => e.slot.day).toSet();
  // Order: Mon–Sun (index 1–6, then 0)
  final ordered = <DayOfWeek>[
    DayOfWeek.monday,
    DayOfWeek.tuesday,
    DayOfWeek.wednesday,
    DayOfWeek.thursday,
    DayOfWeek.friday,
    DayOfWeek.saturday,
    DayOfWeek.sunday,
  ];
  return ordered.where(daySet.contains).toList();
}

/// Find entry for a given day and start time.
TimetableEntry? _entryAt(
  List<TimetableEntry> entries,
  DayOfWeek day,
  int startTime,
) {
  for (final e in entries) {
    if (e.slot.day == day && e.slot.start == startTime) return e;
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Desktop: Weekly grid view
// ═══════════════════════════════════════════════════════════════════════════════

class _DesktopGrid extends StatelessWidget {
  const _DesktopGrid({required this.entries, required this.curriculumType});

  final List<TimetableEntry> entries;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final days = _activeDays(entries);
    final starts = _uniqueStartTimes(entries);

    if (days.isEmpty || starts.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ──────────────────────────────────────────────
          _GridRow(
            timeCell: const SizedBox(width: 72),
            dayCells: [
              for (final day in days)
                _HeaderCell(label: _dayLabels[day] ?? '', cs: cs),
            ],
          ),
          const SizedBox(height: 4),

          // ── Slot rows ───────────────────────────────────────────────
          for (final start in starts) ...[
            _GridRow(
              timeCell: _TimeLabel(time: _fmtTime(start), cs: cs),
              dayCells: [
                for (final day in days)
                  _SlotCell(
                    entry: _entryAt(entries, day, start),
                    curriculumType: curriculumType,
                    cs: cs,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// A single row in the grid: time label + one cell per day.
class _GridRow extends StatelessWidget {
  const _GridRow({required this.timeCell, required this.dayCells});

  final Widget timeCell;
  final List<Widget> dayCells;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 72, child: timeCell),
          const SizedBox(width: 4),
          for (int i = 0; i < dayCells.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: dayCells[i]),
          ],
        ],
      ),
    );
  }
}

/// Column header cell showing the day abbreviation.
class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Time label at the left edge of each row.
class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.time, required this.cs});

  final String time;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
        child: Text(
          time,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A single grid cell — either a filled subject slot or an empty placeholder.
class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.entry,
    required this.curriculumType,
    required this.cs,
    required this.isDark,
  });

  final TimetableEntry? entry;
  final CurriculumType curriculumType;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return _EmptyCell(cs: cs, isDark: isDark);
    }

    final subjectName = entry!.subjectName;
    final teacherName = entry!.teacher.name;
    final color = _subjectColor(entry!.slot.subject);

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.6), width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subjectName,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            teacherName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Empty grid cell with a dashed-style appearance.
class _EmptyCell extends StatelessWidget {
  const _EmptyCell({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
          width: 1,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Mobile: Day pager
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileDayPager extends StatefulWidget {
  const _MobileDayPager({required this.entries, required this.curriculumType});

  final List<TimetableEntry> entries;
  final CurriculumType curriculumType;

  @override
  State<_MobileDayPager> createState() => _MobileDayPagerState();
}

class _MobileDayPagerState extends State<_MobileDayPager> {
  late List<DayOfWeek> _days;
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _days = _activeDays(widget.entries);
    _selectedDayIndex = 0;
  }

  @override
  void didUpdateWidget(covariant _MobileDayPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    _days = _activeDays(widget.entries);
    if (_selectedDayIndex >= _days.length) {
      _selectedDayIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_days.isEmpty) return const SizedBox.shrink();

    final selectedDay = _days[_selectedDayIndex];

    // Filter entries for the selected day, sorted by start time.
    final dayEntries =
        widget.entries.where((e) => e.slot.day == selectedDay).toList()
          ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Day selector chips ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _DayChip(
                    label: _dayLabels[_days[i]] ?? '',
                    selected: i == _selectedDayIndex,
                    cs: cs,
                    onTap: () => setState(() => _selectedDayIndex = i),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Day heading ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            _dayFullLabels[selectedDay] ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // ── Slots list ────────────────────────────────────────────────
        Expanded(
          child: dayEntries.isEmpty
              ? _buildEmptyDay(cs)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: dayEntries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    return _MobileSlotCard(
                      entry: dayEntries[index],
                      curriculumType: widget.curriculumType,
                      cs: cs,
                      isDark: isDark,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyDay(ColorScheme cs) {
    return Center(
      child: Text(
        'No lessons scheduled',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Compact day selector chip.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.35)
                : cs.outline.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.65),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Mobile slot card showing time range, subject name, and teacher name.
class _MobileSlotCard extends StatelessWidget {
  const _MobileSlotCard({
    required this.entry,
    required this.curriculumType,
    required this.cs,
    required this.isDark,
  });

  final TimetableEntry entry;
  final CurriculumType curriculumType;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subjectName = entry.subjectName;
    final teacherName = entry.teacher.name;
    final timeRange =
        '${_fmtTime(entry.slot.start)} – ${_fmtTime(entry.slot.end)}';
    final color = _subjectColor(entry.slot.subject);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.6), width: 3),
        ),
      ),
      child: Row(
        children: [
          // ── Time column ─────────────────────────────────────────────
          SizedBox(
            width: 88,
            child: Text(
              timeRange,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Subject + Teacher ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  teacherName,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
