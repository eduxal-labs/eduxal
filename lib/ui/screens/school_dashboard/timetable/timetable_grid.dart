import 'dart:async';

import 'package:flutter/material.dart' hide Action;

import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/school_config.dart';
import '../../../theme/app_theme.dart';
import 'timetable_shared.dart';

// ═════════════════════════════════════════════════════════════════════════════
// School-wide matrix constants (private to this file)
// ═════════════════════════════════════════════════════════════════════════════

const double _kSwStreamLabelW = 100.0;
const double _kSwTimeColW = 110.0;
const double _kSwBreakColW = 50.0;
const double _kSwColGap = 3.0;

// ── Column descriptors ────────────────────────────────────────────────────────

sealed class _SwColDesc {
  const _SwColDesc();
}

final class _SwTimeCol extends _SwColDesc {
  const _SwTimeCol(this.start, this.end);
  final int start;
  final int end;
}

final class _SwBreakCol extends _SwColDesc {
  const _SwBreakCol();
}

// ── File-level helpers ────────────────────────────────────────────────────────

/// Returns ordered days that have at least one entry, Mon → Sun.
List<DayOfWeek> _swActiveDays(List<SchoolWideTimetableEntry> entries) {
  final daySet = entries.map((e) => e.day).toSet();
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

/// Builds ordered column descriptors (time cols + break cols) from entries.
List<_SwColDesc> _swBuildColumns(List<SchoolWideTimetableEntry> entries) {
  if (entries.isEmpty) return [];
  final starts = entries.map((e) => e.startTime).toSet().toList()..sort();
  final maxEnd = <int, int>{};
  for (final e in entries) {
    final cur = maxEnd[e.startTime] ?? 0;
    if (e.endTime > cur) maxEnd[e.startTime] = e.endTime;
  }
  final result = <_SwColDesc>[];
  for (int i = 0; i < starts.length; i++) {
    final s = starts[i];
    result.add(_SwTimeCol(s, maxEnd[s]!));
    if (i < starts.length - 1 && maxEnd[s]! < starts[i + 1]) {
      result.add(const _SwBreakCol());
    }
  }
  return result;
}

/// Finds the entry for a specific day/grade/stream/startTime combination.
SchoolWideTimetableEntry? _swEntryAt(
  List<SchoolWideTimetableEntry> entries,
  DayOfWeek day,
  int grade,
  int stream,
  int startTime,
) {
  for (final e in entries) {
    if (e.day == day &&
        e.grade == grade &&
        e.stream == stream &&
        e.startTime == startTime) {
      return e;
    }
  }
  return null;
}

/// Total row width for header/grade strips: label col + gap + all time/break cols.
double _swTotalWidth(List<_SwColDesc> cols) {
  double w = _kSwStreamLabelW + _kSwColGap;
  for (int i = 0; i < cols.length; i++) {
    if (i > 0) w += _kSwColGap;
    w += cols[i] is _SwBreakCol ? _kSwBreakColW : _kSwTimeColW;
  }
  return w;
}

// ═════════════════════════════════════════════════════════════════════════════
// SCHOOL-WIDE MATRIX TAB
// ═════════════════════════════════════════════════════════════════════════════

/// School-wide cross-matrix timetable tab (owner / admin view).
///
/// Displays ALL classes (all grades × all streams) in one unified matrix.
/// Row axis: Day → Grade → Stream. Column axis: time slots (with break cols).
class SchoolWideMatrixTab extends StatefulWidget {
  const SchoolWideMatrixTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.timetableDao,
  });

  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final TimetableDao timetableDao;

  @override
  State<SchoolWideMatrixTab> createState() => _SchoolWideMatrixTabState();
}

class _SchoolWideMatrixTabState extends State<SchoolWideMatrixTab> {
  late Stream<List<SchoolWideTimetableEntry>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant SchoolWideMatrixTab old) {
    super.didUpdateWidget(old);
    if (old.schoolId != widget.schoolId ||
        old.year != widget.year ||
        old.term != widget.term) {
      setState(() => _stream = _buildStream());
    }
  }

  Stream<List<SchoolWideTimetableEntry>> _buildStream() =>
      widget.timetableDao.watchSchoolWideTimetable(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
      );

  /// Builds a grade code → display label map from config.
  Map<int, String> _gradeLabels() {
    final map = <int, String>{};
    for (final curriculum in widget.config.curricula) {
      final labels = gradeLabelsFor(curriculum.type);
      for (final gc in curriculum.grades) {
        map[gc.grade] = labels[gc.grade] ?? 'Grade ${gc.grade}';
      }
    }
    return map;
  }

  /// Builds a stream code → stream name map from config.
  Map<int, String> _streamNames() {
    final map = <int, String>{};
    for (final curriculum in widget.config.curricula) {
      for (final gc in curriculum.grades) {
        for (final s in gc.streams) {
          map[s.code] = s.name;
        }
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<SchoolWideTimetableEntry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) return EmptyTimetableState(cs: cs);

        final gradeLabels = _gradeLabels();
        final streamNames = _streamNames();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return _SWDesktopMatrix(
                entries: entries,
                gradeLabels: gradeLabels,
                streamNames: streamNames,
              );
            }
            return _SWMobileView(
              entries: entries,
              gradeLabels: gradeLabels,
              streamNames: streamNames,
            );
          },
        );
      },
    );
  }
}

// ── Desktop cross-matrix ──────────────────────────────────────────────────────

/// Desktop: all days visible, left-axis pinned, columns scroll horizontally.
class _SWDesktopMatrix extends StatefulWidget {
  const _SWDesktopMatrix({
    required this.entries,
    required this.gradeLabels,
    required this.streamNames,
  });

  final List<SchoolWideTimetableEntry> entries;
  final Map<int, String> gradeLabels;
  final Map<int, String> streamNames;

  @override
  State<_SWDesktopMatrix> createState() => _SWDesktopMatrixState();
}

class _SWDesktopMatrixState extends State<_SWDesktopMatrix> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final cols = _swBuildColumns(widget.entries);
    final orderedDays = _swActiveDays(widget.entries);
    if (cols.isEmpty || orderedDays.isEmpty) return const SizedBox.shrink();
    final totalW = _swTotalWidth(cols);

    // Group: day → grade (sorted) → sorted stream codes.
    final dayGradeStreamSets = <DayOfWeek, Map<int, Set<int>>>{};
    for (final e in widget.entries) {
      dayGradeStreamSets
          .putIfAbsent(e.day, () => <int, Set<int>>{})
          .putIfAbsent(e.grade, () => <int>{})
          .add(e.stream);
    }
    final dayGroups = <DayOfWeek, Map<int, List<int>>>{};
    for (final day in orderedDays) {
      final gradeStreams = dayGradeStreamSets[day] ?? <int, Set<int>>{};
      final sortedGrades = gradeStreams.keys.toList()..sort();
      dayGroups[day] = {
        for (final g in sortedGrades) g: gradeStreams[g]!.toList()..sort(),
      };
    }

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 0,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(cols, cs),
                  const SizedBox(height: _kSwColGap),
                  for (int di = 0; di < orderedDays.length; di++) ...[
                    if (di > 0) const SizedBox(height: 10),
                    _buildDayGroup(
                      orderedDays[di],
                      dayGroups[orderedDays[di]]!,
                      cols,
                      totalW,
                      cs,
                      isDark,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<_SwColDesc> cols, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: _kSwStreamLabelW),
        const SizedBox(width: _kSwColGap),
        for (int i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSwColGap),
          _buildColHeader(cols[i], cs),
        ],
      ],
    );
  }

  Widget _buildColHeader(_SwColDesc col, ColorScheme cs) {
    if (col is _SwBreakCol) {
      return SizedBox(
        width: _kSwBreakColW,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
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
    final tc = col as _SwTimeCol;
    return SizedBox(
      width: _kSwTimeColW,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          '${fmtTimeSec(tc.start)} – ${fmtTimeSec(tc.end)}',
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
    Map<int, List<int>> gradeStreams,
    List<_SwColDesc> cols,
    double totalW,
    ColorScheme cs,
    bool isDark,
  ) {
    final sortedGrades = gradeStreams.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day section header — full-width strip
        Container(
          width: totalW,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.25 : 0.20,
            ),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          ),
          child: Text(
            kDayLabelsFull[day] ?? '',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.75),
              letterSpacing: 0.2,
            ),
          ),
        ),
        for (int gi = 0; gi < sortedGrades.length; gi++) ...[
          const SizedBox(height: _kSwColGap),
          _buildGradeGroup(
            day,
            sortedGrades[gi],
            gradeStreams[sortedGrades[gi]]!,
            cols,
            totalW,
            cs,
            isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildGradeGroup(
    DayOfWeek day,
    int grade,
    List<int> streams,
    List<_SwColDesc> cols,
    double totalW,
    ColorScheme cs,
    bool isDark,
  ) {
    final label = widget.gradeLabels[grade] ?? 'Grade $grade';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grade sub-header — more subtle than day header
        Container(
          width: totalW,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.12 : 0.10,
            ),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.1,
            ),
          ),
        ),
        for (int si = 0; si < streams.length; si++) ...[
          const SizedBox(height: _kSwColGap),
          _buildStreamRow(day, grade, streams[si], cols, cs, isDark),
        ],
      ],
    );
  }

  Widget _buildStreamRow(
    DayOfWeek day,
    int grade,
    int streamCode,
    List<_SwColDesc> cols,
    ColorScheme cs,
    bool isDark,
  ) {
    final name = widget.streamNames[streamCode] ?? 'Stream $streamCode';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kSwStreamLabelW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: _kSwColGap),
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: _kSwColGap),
            _buildDataCell(cols[i], day, grade, streamCode, cs, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDataCell(
    _SwColDesc col,
    DayOfWeek day,
    int grade,
    int streamCode,
    ColorScheme cs,
    bool isDark,
  ) {
    if (col is _SwBreakCol) {
      return SizedBox(
        width: _kSwBreakColW,
        child: _SWBreakCell(cs: cs, isDark: isDark),
      );
    }
    final tc = col as _SwTimeCol;
    return SizedBox(
      width: _kSwTimeColW,
      child: _SWSlotCell(
        entry: _swEntryAt(widget.entries, day, grade, streamCode, tc.start),
        cs: cs,
        isDark: isDark,
      ),
    );
  }
}

// ── Mobile view ───────────────────────────────────────────────────────────────

/// Mobile: day-chip selector + horizontally-scrollable matrix for one day.
class _SWMobileView extends StatefulWidget {
  const _SWMobileView({
    required this.entries,
    required this.gradeLabels,
    required this.streamNames,
  });

  final List<SchoolWideTimetableEntry> entries;
  final Map<int, String> gradeLabels;
  final Map<int, String> streamNames;

  @override
  State<_SWMobileView> createState() => _SWMobileViewState();
}

class _SWMobileViewState extends State<_SWMobileView> {
  late List<DayOfWeek> _days;
  int _selectedDayIndex = 0;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _days = _swActiveDays(widget.entries);
  }

  @override
  void didUpdateWidget(covariant _SWMobileView old) {
    super.didUpdateWidget(old);
    _days = _swActiveDays(widget.entries);
    if (_selectedDayIndex >= _days.length) _selectedDayIndex = 0;
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    if (_days.isEmpty) return const SizedBox.shrink();

    final selectedDay = _days[_selectedDayIndex];
    final dayEntries = widget.entries
        .where((e) => e.day == selectedDay)
        .toList();
    final cols = _swBuildColumns(dayEntries);
    final totalW = _swTotalWidth(cols);

    // Group by grade → sorted streams for selected day.
    final gradeStreamSets = <int, Set<int>>{};
    for (final e in dayEntries) {
      gradeStreamSets.putIfAbsent(e.grade, () => <int>{}).add(e.stream);
    }
    final sortedGrades = gradeStreamSets.keys.toList()..sort();
    final gradeStreams = {
      for (final g in sortedGrades) g: gradeStreamSets[g]!.toList()..sort(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Day selector chips ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _SWDayChip(
                    label: kDayLabels[_days[i]] ?? '',
                    selected: i == _selectedDayIndex,
                    cs: cs,
                    onTap: () => setState(() => _selectedDayIndex = i),
                  ),
                ],
              ],
            ),
          ),
        ),
        // ── Day heading ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            kDayLabelsFull[selectedDay] ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
        ),
        // ── Matrix for selected day ───────────────────────────────────────
        Expanded(
          child: dayEntries.isEmpty
              ? Center(
                  child: Text(
                    'No lessons scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 0,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMobileHeaderRow(cols, cs),
                              const SizedBox(height: _kSwColGap),
                              for (int gi = 0; gi < sortedGrades.length; gi++) ...[
                                if (gi > 0) const SizedBox(height: 8),
                                _buildMobileGradeGroup(
                                  selectedDay,
                                  sortedGrades[gi],
                                  gradeStreams[sortedGrades[gi]]!,
                                  dayEntries,
                                  cols,
                                  totalW,
                                  cs,
                                  isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMobileHeaderRow(List<_SwColDesc> cols, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: _kSwStreamLabelW),
        const SizedBox(width: _kSwColGap),
        for (int i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: _kSwColGap),
          _buildMobileColHeader(cols[i], cs),
        ],
      ],
    );
  }

  Widget _buildMobileColHeader(_SwColDesc col, ColorScheme cs) {
    if (col is _SwBreakCol) {
      return SizedBox(
        width: _kSwBreakColW,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
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
    final tc = col as _SwTimeCol;
    return SizedBox(
      width: _kSwTimeColW,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          '${fmtTimeSec(tc.start)} – ${fmtTimeSec(tc.end)}',
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

  Widget _buildMobileGradeGroup(
    DayOfWeek day,
    int grade,
    List<int> streams,
    List<SchoolWideTimetableEntry> dayEntries,
    List<_SwColDesc> cols,
    double totalW,
    ColorScheme cs,
    bool isDark,
  ) {
    final label = widget.gradeLabels[grade] ?? 'Grade $grade';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: totalW,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.12 : 0.10,
            ),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.1,
            ),
          ),
        ),
        for (int si = 0; si < streams.length; si++) ...[
          const SizedBox(height: _kSwColGap),
          _buildMobileStreamRow(
            day,
            grade,
            streams[si],
            dayEntries,
            cols,
            cs,
            isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildMobileStreamRow(
    DayOfWeek day,
    int grade,
    int streamCode,
    List<SchoolWideTimetableEntry> dayEntries,
    List<_SwColDesc> cols,
    ColorScheme cs,
    bool isDark,
  ) {
    final name = widget.streamNames[streamCode] ?? 'Stream $streamCode';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kSwStreamLabelW,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: _kSwColGap),
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: _kSwColGap),
            _buildMobileDataCell(
              cols[i],
              day,
              grade,
              streamCode,
              dayEntries,
              cs,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileDataCell(
    _SwColDesc col,
    DayOfWeek day,
    int grade,
    int streamCode,
    List<SchoolWideTimetableEntry> dayEntries,
    ColorScheme cs,
    bool isDark,
  ) {
    if (col is _SwBreakCol) {
      return SizedBox(
        width: _kSwBreakColW,
        child: _SWBreakCell(cs: cs, isDark: isDark),
      );
    }
    final tc = col as _SwTimeCol;
    return SizedBox(
      width: _kSwTimeColW,
      child: _SWSlotCell(
        entry: _swEntryAt(dayEntries, day, grade, streamCode, tc.start),
        cs: cs,
        isDark: isDark,
      ),
    );
  }
}

// ── Day chip ──────────────────────────────────────────────────────────────────

class _SWDayChip extends StatelessWidget {
  const _SWDayChip({
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
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
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

// ── Slot cell widgets ─────────────────────────────────────────────────────────

/// Filled slot cell — subject name + teacher name with a coloured left-accent border.
/// Uses `colorForSubject` (deterministic by subject ID) from shared helpers.
class _SWSlotCell extends StatelessWidget {
  const _SWSlotCell({
    required this.entry,
    required this.cs,
    required this.isDark,
  });

  final SchoolWideTimetableEntry? entry;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (entry == null) return _SWEmptyCell(cs: cs, isDark: isDark);

    final color = colorForSubject(entry!.subjectId);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.6), width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry!.subjectName,
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
            entry!.teacherName,
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

/// Empty grid cell — subtle placeholder with thin border.
class _SWEmptyCell extends StatelessWidget {
  const _SWEmptyCell({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
          width: 1,
        ),
      ),
    );
  }
}

/// Break-period cell — muted filler between consecutive lesson slots.
class _SWBreakCell extends StatelessWidget {
  const _SWBreakCell({required this.cs, required this.isDark});

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
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
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

// ═════════════════════════════════════════════════════════════════════════════
// TIMETABLE GRID VIEW (per-class)
// ═════════════════════════════════════════════════════════════════════════════

class TimetableGridView extends StatelessWidget {
  const TimetableGridView({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.config,
    required this.dao,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? stream;
  final SchoolConfig config;
  final TimetableDao dao;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TimetableEntry>>(
      stream: dao.watchClassTimetable(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
      ),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > AppTheme.kMobileBreakpoint) {
              return _DesktopGrid(entries: entries, config: config);
            }
            return _MobileDayPager(entries: entries, config: config);
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DESKTOP GRID — Classic weekly grid
// ═════════════════════════════════════════════════════════════════════════════

class _DesktopGrid extends StatelessWidget {
  const _DesktopGrid({required this.entries, required this.config});

  final List<TimetableEntry> entries;
  final SchoolConfig config;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (entries.isEmpty) {
      return EmptyTimetableState(cs: cs);
    }

    // Group by day
    final byDay = <DayOfWeek, List<TimetableEntry>>{};
    for (final entry in entries) {
      byDay.putIfAbsent(entry.slot.day, () => []).add(entry);
    }

    // Find the time range
    int minStart = kDefaultDayStart;
    int maxEnd = kDefaultDayEnd;
    for (final entry in entries) {
      if (entry.slot.start < minStart) minStart = entry.slot.start;
      if (entry.slot.end > maxEnd) maxEnd = entry.slot.end;
    }

    // Generate time labels (every hour)
    final timeLabels = <int>[];
    int t = (minStart ~/ 3600) * 3600;
    while (t <= maxEnd) {
      timeLabels.add(t);
      t += 3600;
    }

    final totalSeconds = maxEnd - minStart;
    final availableHeight = (timeLabels.length) * 64.0;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Day headers
            _GridHeader(cs: cs),
            // Grid body
            SizedBox(
              height: availableHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Time gutter
                  SizedBox(
                    width: 56,
                    child: _TimeGutter(
                      timeLabels: timeLabels,
                      minStart: minStart,
                      totalSeconds: totalSeconds,
                      height: availableHeight,
                      cs: cs,
                    ),
                  ),
                  // Day columns
                  ...kSchoolDays.map((day) {
                    final dayEntries = byDay[day] ?? [];
                    return Expanded(
                      child: _DayColumn(
                        entries: dayEntries,
                        minStart: minStart,
                        totalSeconds: totalSeconds,
                        height: availableHeight,
                        config: config,
                        cs: cs,
                        isDark: isDark,
                        isLast: day == kSchoolDays.last,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 56), // time gutter space
          ...kSchoolDays.map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  kDayLabels[day]!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({
    required this.timeLabels,
    required this.minStart,
    required this.totalSeconds,
    required this.height,
    required this.cs,
  });

  final List<int> timeLabels;
  final int minStart;
  final int totalSeconds;
  final double height;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: timeLabels.map((t) {
        final fraction = totalSeconds > 0 ? (t - minStart) / totalSeconds : 0.0;
        final top = fraction * height;
        final h = t ~/ 3600;
        final m = (t % 3600) ~/ 60;
        return Positioned(
          top: top - 7,
          left: 0,
          right: 4,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.entries,
    required this.minStart,
    required this.totalSeconds,
    required this.height,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.isLast,
  });

  final List<TimetableEntry> entries;
  final int minStart;
  final int totalSeconds;
  final double height;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        children: entries.map((entry) {
          final topFrac = totalSeconds > 0
              ? (entry.slot.start - minStart) / totalSeconds
              : 0.0;
          final bottomFrac = totalSeconds > 0
              ? (entry.slot.end - minStart) / totalSeconds
              : 0.0;
          final top = topFrac * height;
          final slotHeight = (bottomFrac - topFrac) * height;

          final color = colorForSubject(entry.slot.subject);

          return Positioned(
            top: top + 1,
            left: 2,
            right: 2,
            height: slotHeight - 2,
            child: _SlotBlock(
              entry: entry,
              color: color,
              config: config,
              cs: cs,
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SlotBlock extends StatelessWidget {
  const _SlotBlock({
    required this.entry,
    required this.color,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final TimetableEntry entry;
  final Color color;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = subjectLabel(entry.slot.subject, config);
    final timeLabel =
        '${fmtTimeSec(entry.slot.start)} – ${fmtTimeSec(entry.slot.end)}';

    return Tooltip(
      message: '$label\n${entry.teacher.name}\n$timeLabel',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showTeacher = constraints.maxHeight > 40;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? color.withValues(alpha: 0.9) : color,
                    height: 1.2,
                  ),
                ),
                if (showTeacher) ...[
                  const SizedBox(height: 1),
                  Text(
                    entry.teacher.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MOBILE DAY PAGER — Vertical timeline per day
// ═════════════════════════════════════════════════════════════════════════════

class _MobileDayPager extends StatefulWidget {
  const _MobileDayPager({required this.entries, required this.config});

  final List<TimetableEntry> entries;
  final SchoolConfig config;

  @override
  State<_MobileDayPager> createState() => _MobileDayPagerState();
}

class _MobileDayPagerState extends State<_MobileDayPager> {
  late final PageController _pageController;
  int _currentPage = 0; // Monday = 0

  @override
  void initState() {
    super.initState();
    // Start on current weekday if it's a school day, else Monday
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon..7=Sun
    _currentPage = weekday >= 1 && weekday <= 5 ? weekday - 1 : 0;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (widget.entries.isEmpty) {
      return EmptyTimetableState(cs: cs);
    }

    // Group by day
    final byDay = <DayOfWeek, List<TimetableEntry>>{};
    for (final entry in widget.entries) {
      byDay.putIfAbsent(entry.slot.day, () => []).add(entry);
    }

    return Column(
      children: [
        // Day selector strip
        _MobileDayStrip(
          currentIndex: _currentPage,
          cs: cs,
          isDark: isDark,
          onDaySelected: (index) {
            setState(() => _currentPage = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          },
        ),
        // Day pages
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: kSchoolDays.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final day = kSchoolDays[index];
              final dayEntries = byDay[day] ?? [];
              return _MobileDayTimeline(
                day: day,
                entries: dayEntries,
                config: widget.config,
                cs: cs,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobileDayStrip extends StatelessWidget {
  const _MobileDayStrip({
    required this.currentIndex,
    required this.cs,
    required this.isDark,
    required this.onDaySelected,
  });

  final int currentIndex;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: List.generate(kSchoolDays.length, (index) {
          final isSelected = index == currentIndex;
          final day = kSchoolDays[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected ? cs.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.16 : 0.07,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    kDayLabels[day]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MobileDayTimeline extends StatelessWidget {
  const _MobileDayTimeline({
    required this.day,
    required this.entries,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final DayOfWeek day;
  final List<TimetableEntry> entries;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny_outlined,
              size: 28,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 10),
            Text(
              'No lessons on ${kDayLabelsFull[day]}',
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

    // Sort by start time
    final sorted = List.of(entries)
      ..sort((a, b) => a.slot.start.compareTo(b.slot.start));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _MobileLessonCard(
          entry: sorted[index],
          config: config,
          cs: cs,
          isDark: isDark,
          index: index,
        );
      },
    );
  }
}

class _MobileLessonCard extends StatelessWidget {
  const _MobileLessonCard({
    required this.entry,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.index,
  });

  final TimetableEntry entry;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = colorForSubject(entry.slot.subject);
    final label = subjectLabel(entry.slot.subject, config);
    final startLabel = fmtTimeSec(entry.slot.start);
    final endLabel = fmtTimeSec(entry.slot.end);
    final durationMin = (entry.slot.end - entry.slot.start) ~/ 60;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Colour accent bar
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          // Time column
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  endLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 40,
            color: cs.outlineVariant.withValues(alpha: 0.15),
          ),
          // Subject info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.teacher.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Duration badge
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${durationMin}m',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER DESKTOP GRID
// ═════════════════════════════════════════════════════════════════════════════

class TeacherDesktopGrid extends StatelessWidget {
  const TeacherDesktopGrid({
    super.key,
    required this.entries,
    required this.config,
    required this.cs,
  });

  final List<TimetableEntry> entries;
  final SchoolConfig config;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return EmptyTimetableState(cs: cs);
    }

    // For teacher grid we show class info instead of teacher name
    return _DesktopGrid(entries: entries, config: config);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEACHER MOBILE PAGER — public wrapper around _MobileDayPager
// ═════════════════════════════════════════════════════════════════════════════

class TeacherMobilePager extends StatelessWidget {
  const TeacherMobilePager({
    super.key,
    required this.entries,
    required this.config,
  });

  final List<TimetableEntry> entries;
  final SchoolConfig config;

  @override
  Widget build(BuildContext context) {
    return _MobileDayPager(entries: entries, config: config);
  }
}
