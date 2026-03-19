import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/timetable_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../database/tables/enums.dart';
import '../../../../../models/school_config.dart';
import '../../../../../models/school_context.dart';

// ── Column width constants ──────────────────────────────────────────────────
const double _kDayLabelW = 72;
const double _kStreamLabelW = 80;
const double _kTimeColW = 110;
const double _kBreakColW = 50;
const double _kColGap = 3.0;

// ── Column descriptor sealed class ─────────────────────────────────────────

sealed class _ColDesc {
  const _ColDesc();
}

final class _TimeCol extends _ColDesc {
  const _TimeCol(this.start, this.end);
  final int start;
  final int
  end; // representative end time (max across all entries at this start)
}

final class _BreakCol extends _ColDesc {
  const _BreakCol();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Public widget
// ═══════════════════════════════════════════════════════════════════════════════

/// Weekly timetable view — two layout modes:
///
/// **Single-stream** (when [streamCode] is non-null):
///   Rows = days, columns = time slots (with break columns where gaps exist).
///
/// **All-streams** (when [streamCode] is null AND [streams] is provided):
///   Rows = day-section header + one sub-row per stream, columns = time slots.
///
/// Desktop (≥ 600 px): horizontal-scrollable matrix grid.
/// Mobile (< 600 px): day-chip selector + vertical slot list.
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
    this.streams,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? streamCode;
  final String streamName;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  /// When provided and [streamCode] is null, renders the all-streams
  /// cross-table matrix. Each entry in [streams] becomes a sub-row per day.
  final List<GradeStream>? streams;

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
    // When streamCode is null, watchClassTimetable returns all entries for
    // the grade across every stream — exactly what the all-streams view needs.
    return _dao.watchClassTimetable(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
  }

  bool get _isAllStreams => widget.streamCode == null && widget.streams != null;

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
              // Desktop — matrix grid
              if (_isAllStreams) {
                return _AllStreamsMatrix(
                  entries: entries,
                  streams: widget.streams!,
                  curriculumType: widget.curriculumType,
                );
              }
              return _SingleStreamMatrix(
                entries: entries,
                curriculumType: widget.curriculumType,
              );
            }
            // Mobile — day-chip pager
            if (_isAllStreams) {
              return _MobileAllStreamsPager(
                entries: entries,
                streams: widget.streams!,
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

/// Deterministic subject color from a 15-color palette indexed by subject ID.
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

/// Returns sorted unique start times present in [entries].
List<int> _uniqueStartTimes(List<TimetableEntry> entries) {
  final starts = entries.map((e) => e.slot.start).toSet().toList()..sort();
  return starts;
}

/// Returns all unique days present in [entries], ordered Mon → Sun.
List<DayOfWeek> _activeDays(List<TimetableEntry> entries) {
  final daySet = entries.map((e) => e.slot.day).toSet();
  const ordered = [
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

/// Finds the first entry matching [day] + [startTime] in a single-stream list.
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

/// Finds an entry for a specific [streamCode] + [day] + [startTime] in an
/// all-streams list.
TimetableEntry? _entryForStream(
  List<TimetableEntry> entries,
  int streamCode,
  DayOfWeek day,
  int startTime,
) {
  for (final e in entries) {
    if (e.slot.stream == streamCode &&
        e.slot.day == day &&
        e.slot.start == startTime)
      return e;
  }
  return null;
}

/// Builds the ordered list of column descriptors from [entries].
///
/// Each unique start time becomes a [_TimeCol]. Where there is a gap between
/// `maxEnd[start[i]]` and `start[i+1]`, a [_BreakCol] is inserted to
/// represent a break period between consecutive lesson slots.
List<_ColDesc> _buildColumns(List<TimetableEntry> entries) {
  if (entries.isEmpty) return [];

  final starts = _uniqueStartTimes(entries);

  // Find the maximum end time per start time (representative end for header).
  final maxEnd = <int, int>{};
  for (final e in entries) {
    final cur = maxEnd[e.slot.start] ?? 0;
    if (e.slot.end > cur) maxEnd[e.slot.start] = e.slot.end;
  }

  final result = <_ColDesc>[];
  for (int i = 0; i < starts.length; i++) {
    final s = starts[i];
    result.add(_TimeCol(s, maxEnd[s]!));
    if (i < starts.length - 1) {
      // Gap between end of this column and start of the next → break period.
      if (maxEnd[s]! < starts[i + 1]) {
        result.add(const _BreakCol());
      }
    }
  }
  return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Desktop: Single-stream matrix  (rows = days,  cols = time slots)
// ═══════════════════════════════════════════════════════════════════════════════

class _SingleStreamMatrix extends StatelessWidget {
  const _SingleStreamMatrix({
    required this.entries,
    required this.curriculumType,
  });

  final List<TimetableEntry> entries;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final cols = _buildColumns(entries);
    final days = _activeDays(entries);

    if (cols.isEmpty || days.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (time column labels) ─────────────────────────
            _buildHeaderRow(cols, cs),
            const SizedBox(height: _kColGap),

            // ── One row per active day ───────────────────────────────────
            for (int di = 0; di < days.length; di++) ...[
              if (di > 0) const SizedBox(height: _kColGap),
              _buildDayRow(days[di], cols, cs, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<_ColDesc> cols, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Corner — day label area
        const SizedBox(width: _kDayLabelW),
        const SizedBox(width: _kColGap),
        for (int i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kColGap),
          _buildColHeader(cols[i], cs),
        ],
      ],
    );
  }

  Widget _buildColHeader(_ColDesc col, ColorScheme cs) {
    if (col is _BreakCol) {
      return SizedBox(
        width: _kBreakColW,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            'Break',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }
    final tc = col as _TimeCol;
    return SizedBox(
      width: _kTimeColW,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          '${_fmtTime(tc.start)} – ${_fmtTime(tc.end)}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDayRow(
    DayOfWeek day,
    List<_ColDesc> cols,
    ColorScheme cs,
    bool isDark,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day label
          SizedBox(
            width: _kDayLabelW,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _dayLabels[day] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _kColGap),
          // Slot cells
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: _kColGap),
            _buildDataCell(cols[i], day, cs, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDataCell(
    _ColDesc col,
    DayOfWeek day,
    ColorScheme cs,
    bool isDark,
  ) {
    if (col is _BreakCol) {
      return SizedBox(
        width: _kBreakColW,
        child: _BreakCell(cs: cs, isDark: isDark),
      );
    }
    final tc = col as _TimeCol;
    return SizedBox(
      width: _kTimeColW,
      child: _SlotCell(
        entry: _entryAt(entries, day, tc.start),
        curriculumType: curriculumType,
        cs: cs,
        isDark: isDark,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Desktop: All-streams matrix
// (rows = day-section header + one sub-row per stream,  cols = time slots)
// ═══════════════════════════════════════════════════════════════════════════════

class _AllStreamsMatrix extends StatelessWidget {
  const _AllStreamsMatrix({
    required this.entries,
    required this.streams,
    required this.curriculumType,
  });

  final List<TimetableEntry> entries;
  final List<GradeStream> streams;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final cols = _buildColumns(entries);
    final days = _activeDays(entries);

    if (cols.isEmpty || days.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (time column labels) ─────────────────────────
            _buildHeaderRow(cols, cs),
            const SizedBox(height: _kColGap),

            // ── Day groups ───────────────────────────────────────────────
            for (int di = 0; di < days.length; di++) ...[
              if (di > 0) const SizedBox(height: 8),
              _buildDayGroup(days[di], cols, cs, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<_ColDesc> cols, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Corner — stream label area
        const SizedBox(width: _kStreamLabelW),
        const SizedBox(width: _kColGap),
        for (int i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kColGap),
          _buildColHeader(cols[i], cs),
        ],
      ],
    );
  }

  Widget _buildColHeader(_ColDesc col, ColorScheme cs) {
    if (col is _BreakCol) {
      return SizedBox(
        width: _kBreakColW,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            'Break',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }
    final tc = col as _TimeCol;
    return SizedBox(
      width: _kTimeColW,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          '${_fmtTime(tc.start)} – ${_fmtTime(tc.end)}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDayGroup(
    DayOfWeek day,
    List<_ColDesc> cols,
    ColorScheme cs,
    bool isDark,
  ) {
    // Compute total width for the day strip so it spans all columns.
    double totalW = _kStreamLabelW + _kColGap;
    for (int i = 0; i < cols.length; i++) {
      if (i > 0) totalW += _kColGap;
      totalW += cols[i] is _BreakCol ? _kBreakColW : _kTimeColW;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day section header strip — spans full row width
        Container(
          width: totalW,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.22 : 0.18,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _dayFullLabels[day] ?? '',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              letterSpacing: 0.15,
            ),
          ),
        ),

        // One sub-row per stream
        for (int si = 0; si < streams.length; si++) ...[
          const SizedBox(height: _kColGap),
          _buildStreamRow(day, streams[si], cols, cs, isDark),
        ],
      ],
    );
  }

  Widget _buildStreamRow(
    DayOfWeek day,
    GradeStream stream,
    List<_ColDesc> cols,
    ColorScheme cs,
    bool isDark,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stream label
          SizedBox(
            width: _kStreamLabelW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  stream.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: _kColGap),
          // Slot cells
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: _kColGap),
            _buildStreamDataCell(cols[i], day, stream.code, cs, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamDataCell(
    _ColDesc col,
    DayOfWeek day,
    int streamCode,
    ColorScheme cs,
    bool isDark,
  ) {
    if (col is _BreakCol) {
      return SizedBox(
        width: _kBreakColW,
        child: _BreakCell(cs: cs, isDark: isDark),
      );
    }
    final tc = col as _TimeCol;
    return SizedBox(
      width: _kTimeColW,
      child: _SlotCell(
        entry: _entryForStream(entries, streamCode, day, tc.start),
        curriculumType: curriculumType,
        cs: cs,
        isDark: isDark,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Mobile: Single-stream day pager
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

// ═══════════════════════════════════════════════════════════════════════════════
// Mobile: All-streams day pager
// ═══════════════════════════════════════════════════════════════════════════════

class _MobileAllStreamsPager extends StatefulWidget {
  const _MobileAllStreamsPager({
    required this.entries,
    required this.streams,
    required this.curriculumType,
  });

  final List<TimetableEntry> entries;
  final List<GradeStream> streams;
  final CurriculumType curriculumType;

  @override
  State<_MobileAllStreamsPager> createState() => _MobileAllStreamsPagerState();
}

class _MobileAllStreamsPagerState extends State<_MobileAllStreamsPager> {
  late List<DayOfWeek> _days;
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _days = _activeDays(widget.entries);
    _selectedDayIndex = 0;
  }

  @override
  void didUpdateWidget(covariant _MobileAllStreamsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    _days = _activeDays(widget.entries);
    if (_selectedDayIndex >= _days.length) _selectedDayIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_days.isEmpty) return const SizedBox.shrink();

    final selectedDay = _days[_selectedDayIndex];

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

        // ── Per-stream sections ───────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: widget.streams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, si) {
              final stream = widget.streams[si];
              final streamDayEntries =
                  widget.entries
                      .where(
                        (e) =>
                            e.slot.day == selectedDay &&
                            e.slot.stream == stream.code,
                      )
                      .toList()
                    ..sort((a, b) => a.slot.start.compareTo(b.slot.start));
              return _buildStreamSection(stream, streamDayEntries, cs, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStreamSection(
    GradeStream stream,
    List<TimetableEntry> streamDayEntries,
    ColorScheme cs,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stream label
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            stream.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.25,
            ),
          ),
        ),

        if (streamDayEntries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
                width: 1,
              ),
            ),
            child: Text(
              'No lessons',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          )
        else
          ...streamDayEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _MobileSlotCard(
                entry: entry,
                curriculumType: widget.curriculumType,
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared cell widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// A filled timetable slot — subject name + teacher name with a color accent.
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

/// An empty grid cell — subtle placeholder with thin border.
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

/// A break-period cell — muted filler for the gap between lesson slots.
class _BreakCell extends StatelessWidget {
  const _BreakCell({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.07 : 0.05,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '· · ·',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 2,
          color: cs.onSurfaceVariant.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared mobile sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Compact animated day-selector chip.
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

/// Mobile slot card — time range + subject name + teacher name.
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
          // ── Time ─────────────────────────────────────────────────────
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

          // ── Subject + Teacher ─────────────────────────────────────────
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
