import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';

import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../../models/timetable_rules.dart';
import '../../../../core/academic_utils.dart';
import '../../../../services/timetable_generator.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_tab_bar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Constants
// ═════════════════════════════════════════════════════════════════════════════

/// School days shown in the timetable grid — Monday through Friday.
const _kSchoolDays = [
  DayOfWeek.monday,
  DayOfWeek.tuesday,
  DayOfWeek.wednesday,
  DayOfWeek.thursday,
  DayOfWeek.friday,
];

const _kDayLabels = {
  DayOfWeek.sunday: 'Sun',
  DayOfWeek.monday: 'Mon',
  DayOfWeek.tuesday: 'Tue',
  DayOfWeek.wednesday: 'Wed',
  DayOfWeek.thursday: 'Thu',
  DayOfWeek.friday: 'Fri',
  DayOfWeek.saturday: 'Sat',
};

const _kDayLabelsFull = {
  DayOfWeek.sunday: 'Sunday',
  DayOfWeek.monday: 'Monday',
  DayOfWeek.tuesday: 'Tuesday',
  DayOfWeek.wednesday: 'Wednesday',
  DayOfWeek.thursday: 'Thursday',
  DayOfWeek.friday: 'Friday',
  DayOfWeek.saturday: 'Saturday',
};

/// Default school day start/end in seconds since midnight.
const _kDefaultDayStart = 8 * 3600; // 08:00
const _kDefaultDayEnd = 16 * 3600; // 16:00

/// Palette for subject colour coding — subtle, muted pastels.
const _kSubjectColors = [
  Color(0xFF6366F1), // indigo
  Color(0xFF06B6D4), // cyan
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFF14B8A6), // teal
  Color(0xFFF97316), // orange
  Color(0xFF3B82F6), // blue
  Color(0xFF84CC16), // lime
  Color(0xFFE11D48), // rose
];

Color _colorForSubject(int subjectCode) {
  return _kSubjectColors[subjectCode.abs() % _kSubjectColors.length];
}

// ═════════════════════════════════════════════════════════════════════════════
// Entry Point
// ═════════════════════════════════════════════════════════════════════════════

/// Top-level entry point for the Timetable section.
///
/// Role dispatch:
/// - **Owner:** Full management — rules config, generation CTA, and grid view
///   with class selector.
/// - **Teacher:** Personal weekly schedule across all assigned classes.
/// - **Student:** Class timetable for the student's enrolled class.
/// - **Guardian:** Ward's class timetable (read-only).
/// - **Staff:** School-wide timetable overview (read-only).
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
    }

    final entry = schoolContext.currentEntry.value;

    return switch (entry) {
      OwnerEntry() => _OwnerTimetableShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      TeacherEntry() => _TeacherTimetableView(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
      StudentEntry(:final student) => _ClassTimetableView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: student.adm,
      ),
      GuardianEntry(:final ward) => _ClassTimetableView(
        schoolContext: schoolContext,
        termContext: termCtx,
        studentAdm: ward.adm,
      ),
      StaffEntry() => _OwnerTimetableShell(
        schoolContext: schoolContext,
        termContext: termCtx,
      ),
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER / ADMIN SHELL — Rules + Grid with class selector
// ═════════════════════════════════════════════════════════════════════════════

class _OwnerTimetableShell extends StatefulWidget {
  const _OwnerTimetableShell({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_OwnerTimetableShell> createState() => _OwnerTimetableShellState();
}

class _OwnerTimetableShellState extends State<_OwnerTimetableShell>
    with TickerProviderStateMixin {
  final _timetableDao = TimetableDao(db);

  SchoolConfig? _config;
  TimetableRules? _rules;
  bool _generating = false;
  bool _deleting = false;
  bool _hasTimetable = false;

  late TabController _tabController;
  int _currentTabIndex = 0;

  StreamSubscription<bool>? _hasTimetableSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _currentTabIndex = _tabController.index);
        }
      });
    _loadConfig();
    _subscribeHasTimetable();
  }

  void _subscribeHasTimetable() {
    final term = widget.termContext.currentTerm;
    if (term == null) return;
    final schoolId = widget.schoolContext.membership.school.id;
    _hasTimetableSub = _timetableDao
        .watchHasTimetable(schoolId: schoolId, year: term.year, term: term.term)
        .listen((has) {
          if (mounted) setState(() => _hasTimetable = has);
        });
  }

  Future<void> _loadConfig() async {
    final term = widget.termContext.currentTerm;
    final schoolId = widget.schoolContext.membership.school.id;
    final rules = term != null
        ? await FileCache.loadTimetableRules(
            schoolId: schoolId,
            year: term.year,
            term: term.term,
          )
        : TimetableRules.defaults();
    if (mounted) {
      setState(() {
        _config = SchoolConfig.defaults();
        _rules = rules;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hasTimetableSub?.cancel();
    super.dispose();
  }

  Future<void> _openRulesSheet() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _rules == null) return;

    final result = await Navigator.of(context).push<_RulesSheetResult>(
      MaterialPageRoute(
        builder: (_) => _TimetableRulesPage(
          initialRules: _rules!,
          schoolContext: widget.schoolContext,
          termContext: widget.termContext,
        ),
      ),
    );

    if (result == null || !mounted) return;

    await FileCache.saveTimetableRules(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      rules: result.rules,
    );
    if (mounted) setState(() => _rules = result.rules);

    if (result.shouldGenerate) {
      await _runGeneration(result.rules);
    }
  }

  Future<void> _deleteTimetable() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _deleting || _generating) return;

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete Timetable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All timetable entries for this term will be permanently '
                  'removed. This cannot be undone.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final account = cache.currentUser;
      if (account == null) return;
      await _timetableDao.clearTermTimetable(
        schoolId: widget.schoolContext.membership.school.id,
        year: term.year,
        term: term.term,
        accountId: account.user.id,
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _runGeneration(TimetableRules rules) async {
    final term = widget.termContext.currentTerm;
    if (term == null || _generating) return;

    setState(() => _generating = true);

    try {
      final schoolId = widget.schoolContext.membership.school.id;

      final assignments = await _timetableDao.getSubjectTeachersForTerm(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
      );

      if (assignments.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No subjects assigned for this term. Assign subjects to classes first.',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      final input = GeneratorInput(assignments: assignments, rules: rules);
      final result = await compute(runTimetableGenerator, input);

      if (!mounted) return;

      if (result is GeneratorFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate timetable: ${result.reason}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      final success = result as GeneratorSuccess;
      final account = cache.currentUser;
      if (account == null || !mounted) return;

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

      final companions = success.slots
          .map(
            (s) => TimetableCompanion(
              school: Value(s.school),
              year: Value(s.year),
              term: Value(s.term),
              grade: Value(s.grade),
              stream: Value(s.stream),
              subject: Value(s.subjectId),
              teacher: Value(s.teacherUserId),
              day: Value(s.day),
              start: Value(s.startSeconds),
              end: Value(s.endSeconds),
              created: Value(now),
              updated: Value(now),
            ),
          )
          .toList();

      // Clear ALL existing entries for this term — not just the classes present
      // in the new output.  If a previous generation included classes that are
      // no longer in the subject assignments, those stale rows would otherwise
      // remain and cause phantom teacher conflicts in the displayed timetable.
      await _timetableDao.clearTermTimetable(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        accountId: account.user.id,
      );

      await _timetableDao.insertSlots(
        slots: companions,
        accountId: account.user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timetable generated — ${success.slots.length} slots '
              '(${success.iterations} iterations, ${success.elapsed.inMilliseconds}ms)',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (_config == null || _rules == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    final schoolId = widget.schoolContext.membership.school.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EduTabBar(
            controller: _tabController,
            tabs: const [
              EduTab(label: 'Timetable'),
              EduTab(label: 'Lessons'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 0: School-wide cross-matrix timetable ────────────
                if (term == null)
                  const _NoTermState()
                else if (_config!.isEmpty)
                  _EmptyConfigState(cs: cs)
                else
                  _SchoolWideMatrixTab(
                    schoolId: schoolId,
                    year: term.year,
                    term: term.term,
                    config: _config!,
                    timetableDao: _timetableDao,
                  ),
                // ── Tab 1: All lessons for the school this term ──────────
                if (term != null)
                  _LessonsTab(
                    schoolId: schoolId,
                    year: term.year,
                    term: term.term,
                    timetableDao: _timetableDao,
                  )
                else
                  const _NoTermState(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_hasTimetable) ...[
                  FloatingActionButton.small(
                    heroTag: 'timetable_delete',
                    onPressed: (_deleting || _generating)
                        ? null
                        : _deleteTimetable,
                    backgroundColor: _deleting
                        ? cs.errorContainer.withValues(alpha: 0.5)
                        : cs.errorContainer,
                    foregroundColor: cs.onErrorContainer,
                    elevation: 2,
                    tooltip: 'Delete timetable',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                    child: _deleting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.onErrorContainer,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                  const SizedBox(height: 12),
                ],
                _GenerateFab(
                  heroTag: 'timetable_generate',
                  onTap: _openRulesSheet,
                  generating: _generating,
                  cs: cs,
                ),
              ],
            )
          : null,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER — School-Wide Cross-Matrix Timetable
// ═════════════════════════════════════════════════════════════════════════════

// ── Layout constants ──────────────────────────────────────────────────────────
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
        e.startTime == startTime)
      return e;
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

// ── Main tab widget ───────────────────────────────────────────────────────────

/// School-wide cross-matrix timetable tab (owner / admin view).
///
/// Displays ALL classes (all grades × all streams) in one unified matrix.
/// Row axis: Day → Grade → Stream. Column axis: time slots (with break cols).
class _SchoolWideMatrixTab extends StatefulWidget {
  const _SchoolWideMatrixTab({
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
  State<_SchoolWideMatrixTab> createState() => _SchoolWideMatrixTabState();
}

class _SchoolWideMatrixTabState extends State<_SchoolWideMatrixTab> {
  late Stream<List<SchoolWideTimetableEntry>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant _SchoolWideMatrixTab old) {
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
        if (entries.isEmpty) return _EmptyTimetableState(cs: cs);

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
class _SWDesktopMatrix extends StatelessWidget {
  const _SWDesktopMatrix({
    required this.entries,
    required this.gradeLabels,
    required this.streamNames,
  });

  final List<SchoolWideTimetableEntry> entries;
  final Map<int, String> gradeLabels;
  final Map<int, String> streamNames;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final cols = _swBuildColumns(entries);
    final orderedDays = _swActiveDays(entries);
    if (cols.isEmpty || orderedDays.isEmpty) return const SizedBox.shrink();
    final totalW = _swTotalWidth(cols);

    // Group: day → grade (sorted) → sorted stream codes.
    final dayGradeStreamSets = <DayOfWeek, Map<int, Set<int>>>{};
    for (final e in entries) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
            _kDayLabelsFull[day] ?? '',
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
    final label = gradeLabels[grade] ?? 'Grade $grade';
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
    final name = streamNames[streamCode] ?? 'Stream $streamCode';
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
        entry: _swEntryAt(entries, day, grade, streamCode, tc.start),
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
                    label: _kDayLabels[_days[i]] ?? '',
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
            _kDayLabelsFull[selectedDay] ?? '',
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
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
/// Uses `_colorForSubject` (deterministic by subject ID) from `_kSubjectColors`.
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

    final color = _colorForSubject(entry!.subjectId);
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
// RULES TAB — Timetable constraints for GA
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// Rules sub-components
// ─────────────────────────────────────────────────────────────────────────────

class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.title,
    required this.cs,
    required this.isDark,
    required this.children,
  });

  final String title;
  final ColorScheme cs;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.cs, required this.child});

  final String label;
  final ColorScheme cs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.seconds,
    required this.cs,
    required this.onChanged,
  });

  final int seconds;
  final ColorScheme cs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final label =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: h, minute: m),
        );
        if (picked != null) {
          onChanged(picked.hour * 3600 + picked.minute * 60);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.suffix,
    required this.min,
    required this.max,
    required this.step,
    required this.cs,
    required this.onChanged,
  });

  final int value;
  final String suffix;
  final int min;
  final int max;
  final int step;
  final ColorScheme cs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            enabled: value > min,
            cs: cs,
            onTap: () {
              if (value - step >= min) onChanged(value - step);
            },
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              suffix.isNotEmpty ? '$value $suffix' : '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: value < max,
            cs: cs,
            onTap: () {
              if (value + step <= max) onChanged(value + step);
            },
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
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
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? cs.onSurface.withValues(alpha: 0.7)
              : cs.onSurfaceVariant.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.day,
    required this.isActive,
    required this.cs,
    required this.onToggle,
  });

  final DayOfWeek day;
  final bool isActive;
  final ColorScheme cs;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _kDayLabelsFull[day]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          Switch.adaptive(
            value: isActive,
            activeTrackColor: cs.primary,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FAB
// ═══════════════════════════════════════════════════════════════════════════

class _GenerateFab extends StatelessWidget {
  const _GenerateFab({
    required this.onTap,
    required this.generating,
    required this.cs,
    this.heroTag,
  });

  final VoidCallback onTap;
  final bool generating;
  final ColorScheme cs;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: generating ? null : onTap,
      backgroundColor: AppTheme.brandGreen,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      tooltip: 'Configure rules & generate timetable',
      child: generating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_rounded, size: 20),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OWNER — Lessons Tab (all lessons for the school this term)
// ═════════════════════════════════════════════════════════════════════════════

/// Shows all lessons recorded for the active school term across all classes,
/// grouped by date (most recent first). Each row shows the subject name,
/// teacher name, and a grade/stream badge.
class _LessonsTab extends StatelessWidget {
  const _LessonsTab({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.timetableDao,
  });

  final String schoolId;
  final int year;
  final int term;
  final TimetableDao timetableDao;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<LessonEntry>>(
      stream: timetableDao.watchAllLessons(
        schoolId: schoolId,
        year: year,
        term: term,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
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

        final allLessons = snap.data ?? [];

        if (allLessons.isEmpty) {
          return _EmptyLessonsState(cs: cs);
        }

        // Group by date — already ordered desc by date from the stream.
        final grouped = <int, List<LessonEntry>>{};
        for (final entry in allLessons) {
          grouped.putIfAbsent(entry.lesson.date, () => []).add(entry);
        }
        final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        // Build a flat list: date header + lesson rows per group.
        final items = <Widget>[];
        for (final date in dates) {
          final dayLessons = grouped[date]!;
          items.add(_LessonDateHeader(date: date, cs: cs));
          for (int i = 0; i < dayLessons.length; i++) {
            items.add(_LessonRow(entry: dayLessons[i], cs: cs, isDark: isDark));
            if (i < dayLessons.length - 1) {
              items.add(AppTheme.tableRowDivider(isDark, cs));
            }
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        );
      },
    );
  }
}

class _LessonDateHeader extends StatelessWidget {
  const _LessonDateHeader({required this.date, required this.cs});

  final int date;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        formatDateFromDays(date),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.entry,
    required this.cs,
    required this.isDark,
  });

  final LessonEntry entry;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final lesson = entry.lesson;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Subject colour dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorForSubject(lesson.subject),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.teacher.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Grade / stream badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.6 : 0.55,
              ),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              'G${lesson.grade} · S${lesson.stream}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLessonsState extends StatelessWidget {
  const _EmptyLessonsState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icons.menu_book_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No lessons recorded',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Lessons will appear here as they are logged',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Timetable Rules Page
// ═══════════════════════════════════════════════════════════════════════════

/// Adaptive launcher for sub-sheets opened from within [_TimetableRulesPage]
/// (teacher block rules and subject block rules entry forms).
///
/// On desktop (>= kMobileBreakpoint): shows a compact dialog with explicit
/// tight width constraints so buttons never receive infinite width.
/// On mobile: shows a modal bottom sheet with tight screen-width constraints.
Future<T?> _showRulesSubSheet<T>({
  required BuildContext context,
  required Widget child,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final isDesktop = screenWidth >= AppTheme.kMobileBreakpoint;

  if (isDesktop) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = cs.brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 60,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.modalBg(isDark, cs),
                borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
                border: Border.all(color: AppTheme.borderColor(isDark, cs)),
                boxShadow: AppTheme.modalShadow(isDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = cs.brightness == Brightness.dark;
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.kModalRadius),
              topRight: Radius.circular(AppTheme.kModalRadius),
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppTheme.borderColor(isDark, cs)
                    : cs.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(child: child),
        ),
      );
    },
  );
}

class _RulesSheetResult {
  const _RulesSheetResult({required this.rules, required this.shouldGenerate});
  final TimetableRules rules;
  final bool shouldGenerate;
}

class _TimetableRulesPage extends StatefulWidget {
  const _TimetableRulesPage({
    required this.initialRules,
    required this.schoolContext,
    required this.termContext,
  });

  final TimetableRules initialRules;
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_TimetableRulesPage> createState() => _TimetableRulesPageState();
}

class _TimetableRulesPageState extends State<_TimetableRulesPage> {
  late TimetableRules _rules;
  int _tab = 0; // 0=Global, 1=Teachers, 2=Subjects

  @override
  void initState() {
    super.initState();
    _rules = TimetableRules.fromJson(widget.initialRules.toJson());
  }

  void _save() => Navigator.of(
    context,
  ).pop(_RulesSheetResult(rules: _rules, shouldGenerate: false));

  void _generate() => Navigator.of(
    context,
  ).pop(_RulesSheetResult(rules: _rules, shouldGenerate: true));

  Widget _ruleDivider(ColorScheme cs) => Divider(
    height: 1,
    thickness: 0.5,
    color: cs.outlineVariant.withValues(alpha: 0.2),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.modalBg(isDark, cs),
      appBar: AppBar(
        backgroundColor: AppTheme.modalBg(isDark, cs),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          tooltip: 'Back',
        ),
        title: const Text(
          'Timetable Rules',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: cs.onSurface),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Generate'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab strip
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor(isDark, cs),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _SheetTab(
                  label: 'Global',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _SheetTab(
                  label: 'Teachers',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _SheetTab(
                  label: 'Subjects',
                  selected: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                  cs: cs,
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(cs, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(ColorScheme cs, bool isDark) {
    return switch (_tab) {
      0 => _buildGlobalTab(cs, isDark),
      1 => _buildTeachersTab(cs, isDark),
      2 => _buildSubjectsTab(cs, isDark),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildGlobalTab(ColorScheme cs, bool isDark) {
    return Column(
      children: [
        _RulesSection(
          title: 'Time Configuration',
          cs: cs,
          isDark: isDark,
          children: [
            _RuleRow(
              label: 'Day starts at',
              cs: cs,
              child: _TimePickerButton(
                seconds: _rules.dayStartSeconds,
                cs: cs,
                onChanged: (v) => setState(() => _rules.dayStartSeconds = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Day ends at',
              cs: cs,
              child: _TimePickerButton(
                seconds: _rules.dayEndSeconds,
                cs: cs,
                onChanged: (v) => setState(() => _rules.dayEndSeconds = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Lesson duration',
              cs: cs,
              child: _StepperControl(
                value: _rules.lessonDurationMinutes,
                suffix: 'min',
                min: 20,
                max: 90,
                step: 5,
                cs: cs,
                onChanged: (v) =>
                    setState(() => _rules.lessonDurationMinutes = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Break between lessons',
              cs: cs,
              child: _StepperControl(
                value: _rules.breakDurationMinutes,
                suffix: 'min',
                min: 0,
                max: 30,
                step: 5,
                cs: cs,
                onChanged: (v) =>
                    setState(() => _rules.breakDurationMinutes = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Lunch break starts at',
              cs: cs,
              child: _TimePickerButton(
                seconds: _rules.lunchStartSeconds,
                cs: cs,
                onChanged: (v) => setState(() => _rules.lunchStartSeconds = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Lunch break duration',
              cs: cs,
              child: _StepperControl(
                value: _rules.lunchDurationMinutes,
                suffix: 'min',
                min: 15,
                max: 90,
                step: 5,
                cs: cs,
                onChanged: (v) =>
                    setState(() => _rules.lunchDurationMinutes = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RulesSection(
          title: 'Load Constraints',
          cs: cs,
          isDark: isDark,
          children: [
            _RuleRow(
              label: 'Lessons per week (default)',
              cs: cs,
              child: _StepperControl(
                value: _rules.defaultLessonsPerWeek,
                suffix: '',
                min: 1,
                max: 8,
                step: 1,
                cs: cs,
                onChanged: (v) =>
                    setState(() => _rules.defaultLessonsPerWeek = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Max lessons per day (teacher)',
              cs: cs,
              child: _StepperControl(
                value: _rules.maxLessonsPerDayTeacher,
                suffix: '',
                min: 1,
                max: 10,
                step: 1,
                cs: cs,
                onChanged: (v) =>
                    setState(() => _rules.maxLessonsPerDayTeacher = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Max lessons per day (class)',
              cs: cs,
              child: _StepperControl(
                value: _rules.maxLessonsPerDayClass,
                suffix: '',
                min: 1,
                max: 12,
                step: 1,
                cs: cs,
                onChanged: (v) =>
                    setState(() => _rules.maxLessonsPerDayClass = v),
              ),
            ),
            _ruleDivider(cs),
            _RuleRow(
              label: 'Allow double lessons',
              cs: cs,
              child: Switch.adaptive(
                value: _rules.allowDoubles,
                activeTrackColor: cs.primary,
                onChanged: (v) => setState(() => _rules.allowDoubles = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RulesSection(
          title: 'Active Days',
          cs: cs,
          isDark: isDark,
          children: DayOfWeek.values.map((day) {
            final isActive = _rules.activeDays.contains(day);
            return _DayToggle(
              day: day,
              isActive: isActive,
              cs: cs,
              onToggle: (active) {
                setState(() {
                  if (active) {
                    if (!_rules.activeDays.contains(day)) {
                      _rules.activeDays.add(day);
                    }
                  } else {
                    _rules.activeDays.remove(day);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTeachersTab(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rules.teacherBlocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No teacher block rules defined.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          )
        else
          ..._rules.teacherBlocks.asMap().entries.map((entry) {
            final i = entry.key;
            final rule = entry.value;
            return _TeacherBlockRuleTile(
              rule: rule,
              cs: cs,
              isDark: isDark,
              onDelete: () => setState(() => _rules.teacherBlocks.removeAt(i)),
            );
          }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final rule = await _showRulesSubSheet<TeacherBlockRule>(
              context: context,
              child: _TeacherBlockRuleSheet(cs: cs),
            );
            if (rule != null) {
              setState(() => _rules.teacherBlocks.add(rule));
            }
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Teacher Rule'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSubjectsTab(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rules.subjectBlocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No subject block rules defined.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          )
        else
          ..._rules.subjectBlocks.asMap().entries.map((entry) {
            final i = entry.key;
            final rule = entry.value;
            return _SubjectBlockRuleTile(
              rule: rule,
              cs: cs,
              isDark: isDark,
              onDelete: () => setState(() => _rules.subjectBlocks.removeAt(i)),
            );
          }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final rule = await _showRulesSubSheet<SubjectBlockRule>(
              context: context,
              child: _SubjectBlockRuleSheet(cs: cs),
            );
            if (rule != null) {
              setState(() => _rules.subjectBlocks.add(rule));
            }
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Subject Rule'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Sheet tab chip ─────────────────────────────────────────────────────────

class _SheetTab extends StatelessWidget {
  const _SheetTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Teacher block rule tile (display) ─────────────────────────────────────

class _TeacherBlockRuleTile extends StatelessWidget {
  const _TeacherBlockRuleTile({
    required this.rule,
    required this.cs,
    required this.isDark,
    required this.onDelete,
  });

  final TeacherBlockRule rule;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dayLabels = rule.days.map((d) => _kDayLabels[d] ?? d.name).join(', ');
    final startStr = _fmtTime(rule.startSeconds);
    final endStr = _fmtTime(rule.endSeconds);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // TODO: resolve teacher name from DB
                  'Teacher: ${rule.teacherUserId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dayLabels · $startStr – $endStr',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: cs.error.withValues(alpha: 0.7),
            ),
            onPressed: onDelete,
            tooltip: 'Remove rule',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Subject block rule tile (display) ─────────────────────────────────────

class _SubjectBlockRuleTile extends StatelessWidget {
  const _SubjectBlockRuleTile({
    required this.rule,
    required this.cs,
    required this.isDark,
    required this.onDelete,
  });

  final SubjectBlockRule rule;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (rule.allowedDays != null) {
      parts.add(
        'Only on: ${rule.allowedDays!.map((d) => _kDayLabels[d] ?? d.name).join(', ')}',
      );
    }
    if (rule.blockedAfterSeconds != null) {
      parts.add('Not after ${_fmtTime(rule.blockedAfterSeconds!)}');
    }
    if (rule.blockedBeforeSeconds != null) {
      parts.add('Not before ${_fmtTime(rule.blockedBeforeSeconds!)}');
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // TODO: resolve subject name from DB
                  'Subject ID: ${rule.subjectId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (parts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: cs.error.withValues(alpha: 0.7),
            ),
            onPressed: onDelete,
            tooltip: 'Remove rule',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Teacher block rule entry sheet
// ═══════════════════════════════════════════════════════════════════════════

class _TeacherBlockRuleSheet extends StatefulWidget {
  const _TeacherBlockRuleSheet({required this.cs});
  final ColorScheme cs;
  @override
  State<_TeacherBlockRuleSheet> createState() => _TeacherBlockRuleSheetState();
}

class _TeacherBlockRuleSheetState extends State<_TeacherBlockRuleSheet> {
  final _teacherCtrl = TextEditingController();
  List<DayOfWeek> _days = [];
  int _start = 8 * 3600;
  int _end = 10 * 3600;
  String? _error;

  @override
  void dispose() {
    _teacherCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final teacherId = _teacherCtrl.text.trim();
    if (teacherId.isEmpty) {
      setState(() => _error = 'Teacher user ID is required.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Select at least one day.');
      return;
    }
    if (_end <= _start) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    Navigator.of(context).pop(
      TeacherBlockRule(
        teacherUserId: teacherId,
        days: List.from(_days),
        startSeconds: _start,
        endSeconds: _end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Teacher Block Rule',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Teacher ID field
          Text(
            'Teacher User ID',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.nestedBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            ),
            child: TextField(
              controller: _teacherCtrl,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. usr_abc123',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TODO: Replace with a searchable teacher picker in a future update.',
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          // Day selector
          Text(
            'Blocked Days',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: DayOfWeek.values.map((day) {
              final selected = _days.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected)
                    _days.remove(day);
                  else
                    _days.add(day);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    border: Border.all(
                      color: selected
                          ? cs.primary.withValues(alpha: 0.5)
                          : cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _kDayLabels[day] ?? day.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Time range
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Block from',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _TimePickerButton(
                      seconds: _start,
                      cs: cs,
                      onChanged: (v) => setState(() => _start = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Block until',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _TimePickerButton(
                      seconds: _end,
                      cs: cs,
                      onChanged: (v) => setState(() => _end = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: cs.error)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                ),
                child: const Text('Add Rule', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Subject block rule entry sheet
// ═══════════════════════════════════════════════════════════════════════════

class _SubjectBlockRuleSheet extends StatefulWidget {
  const _SubjectBlockRuleSheet({required this.cs});
  final ColorScheme cs;
  @override
  State<_SubjectBlockRuleSheet> createState() => _SubjectBlockRuleSheetState();
}

class _SubjectBlockRuleSheetState extends State<_SubjectBlockRuleSheet> {
  final _subjectCtrl = TextEditingController();
  bool _useAllowedDays = false;
  bool _useBlockedAfter = false;
  bool _useBlockedBefore = false;
  List<DayOfWeek> _allowedDays = [];
  int _blockedAfter = 14 * 3600;
  int _blockedBefore = 8 * 3600;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final idStr = _subjectCtrl.text.trim();
    final subjectId = int.tryParse(idStr);
    if (subjectId == null) {
      setState(() => _error = 'Enter a valid numeric subject ID.');
      return;
    }
    if (_useAllowedDays && _allowedDays.isEmpty) {
      setState(() => _error = 'Select at least one allowed day.');
      return;
    }
    Navigator.of(context).pop(
      SubjectBlockRule(
        subjectId: subjectId,
        allowedDays: _useAllowedDays ? List.from(_allowedDays) : null,
        blockedAfterSeconds: _useBlockedAfter ? _blockedAfter : null,
        blockedBeforeSeconds: _useBlockedBefore ? _blockedBefore : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Subject Block Rule',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Subject ID field
          Text(
            'Subject ID',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.nestedBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            ),
            child: TextField(
              controller: _subjectCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. 12',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TODO: Replace with a searchable subject picker in a future update.',
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          // Allowed days toggle
          Row(
            children: [
              Switch.adaptive(
                value: _useAllowedDays,
                activeTrackColor: cs.primary,
                onChanged: (v) => setState(() => _useAllowedDays = v),
              ),
              const SizedBox(width: 8),
              Text(
                'Restrict to specific days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (_useAllowedDays) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: DayOfWeek.values.map((day) {
                final sel = _allowedDays.contains(day);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel)
                      _allowedDays.remove(day);
                    else
                      _allowedDays.add(day);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                      border: Border.all(
                        color: sel
                            ? cs.primary.withValues(alpha: 0.5)
                            : cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _kDayLabels[day] ?? day.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w500 : FontWeight.w400,
                        color: sel ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          // Blocked after toggle
          Row(
            children: [
              Switch.adaptive(
                value: _useBlockedAfter,
                activeTrackColor: cs.primary,
                onChanged: (v) => setState(() => _useBlockedAfter = v),
              ),
              const SizedBox(width: 8),
              Text(
                'Not after a certain time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (_useBlockedAfter) ...[
            const SizedBox(height: 8),
            _TimePickerButton(
              seconds: _blockedAfter,
              cs: cs,
              onChanged: (v) => setState(() => _blockedAfter = v),
            ),
          ],
          const SizedBox(height: 8),
          // Blocked before toggle
          Row(
            children: [
              Switch.adaptive(
                value: _useBlockedBefore,
                activeTrackColor: cs.primary,
                onChanged: (v) => setState(() => _useBlockedBefore = v),
              ),
              const SizedBox(width: 8),
              Text(
                'Not before a certain time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (_useBlockedBefore) ...[
            const SizedBox(height: 8),
            _TimePickerButton(
              seconds: _blockedBefore,
              cs: cs,
              onChanged: (v) => setState(() => _blockedBefore = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: cs.error)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                ),
                child: const Text('Add Rule', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TIMETABLE GRID VIEW — Responsive: Desktop grid / Mobile day pager
// ═════════════════════════════════════════════════════════════════════════════

class _TimetableGridView extends StatelessWidget {
  const _TimetableGridView({
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
  final int stream;
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
      return _EmptyTimetableState(cs: cs);
    }

    // Group by day
    final byDay = <DayOfWeek, List<TimetableEntry>>{};
    for (final entry in entries) {
      byDay.putIfAbsent(entry.slot.day, () => []).add(entry);
    }

    // Find the time range
    int minStart = _kDefaultDayStart;
    int maxEnd = _kDefaultDayEnd;
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
                  ..._kSchoolDays.map((day) {
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
                        isLast: day == _kSchoolDays.last,
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
          ..._kSchoolDays.map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  _kDayLabels[day]!,
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

          final color = _colorForSubject(entry.slot.subject);

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
    final subjectLabel = _subjectLabel(entry.slot.subject, config);
    final timeLabel =
        '${_fmtTime(entry.slot.start)} – ${_fmtTime(entry.slot.end)}';

    return Tooltip(
      message: '$subjectLabel\n${entry.teacher.name}\n$timeLabel',
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
                  subjectLabel,
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
      return _EmptyTimetableState(cs: cs);
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
            itemCount: _kSchoolDays.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final day = _kSchoolDays[index];
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
        children: List.generate(_kSchoolDays.length, (index) {
          final isSelected = index == currentIndex;
          final day = _kSchoolDays[index];
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
                    _kDayLabels[day]!,
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
              'No lessons on ${_kDayLabelsFull[day]}',
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
    final color = _colorForSubject(entry.slot.subject);
    final subjectLabel = _subjectLabel(entry.slot.subject, config);
    final startLabel = _fmtTime(entry.slot.start);
    final endLabel = _fmtTime(entry.slot.end);
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
                    subjectLabel,
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
// TEACHER VIEW — Personal weekly schedule
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherTimetableView extends StatefulWidget {
  const _TeacherTimetableView({
    required this.schoolContext,
    required this.termContext,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_TeacherTimetableView> createState() => _TeacherTimetableViewState();
}

class _TeacherTimetableViewState extends State<_TeacherTimetableView> {
  final _timetableDao = TimetableDao(db);
  SchoolConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // TODO: reload config from new settings source when available
    if (mounted) setState(() => _config = SchoolConfig.defaults());
  }

  String get _teacherUserId {
    final entry = widget.schoolContext.currentEntry.value;
    if (entry is TeacherEntry) return entry.teacher.user;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (term == null || _config == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    final schoolId = widget.schoolContext.membership.school.id;

    return StreamBuilder<List<TimetableData>>(
      stream: _timetableDao.watchTeacherTimetable(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        teacherUserId: _teacherUserId,
      ),
      builder: (context, snapshot) {
        final slots = snapshot.data ?? [];

        // Convert TimetableData to TimetableEntry with a "self" teacher user
        // We create a pseudo-user for display (teacher name comes from the
        // account data already visible in the dashboard).
        final teacherName = cache.currentUser?.user.name ?? 'You';
        final pseudoUser = UsersData(
          id: _teacherUserId,
          phone: '',
          name: teacherName,
          level: UserLevel.normal,
          status: UserStatus.active,
          created: BigInt.zero,
          updated: BigInt.zero,
        );

        final entries = slots
            .map(
              (s) => TimetableEntry(
                slot: s,
                teacher: pseudoUser,
                subjectName: _subjectLabel(s.subject, _config!),
              ),
            )
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > AppTheme.kMobileBreakpoint) {
              return _TeacherDesktopGrid(
                entries: entries,
                config: _config!,
                cs: cs,
              );
            }
            return _MobileDayPager(entries: entries, config: _config!);
          },
        );
      },
    );
  }
}

class _TeacherDesktopGrid extends StatelessWidget {
  const _TeacherDesktopGrid({
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
      return _EmptyTimetableState(cs: cs);
    }

    // For teacher grid we show class info instead of teacher name
    return _DesktopGrid(entries: entries, config: config);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STUDENT / GUARDIAN VIEW — Class timetable (read-only)
// ═════════════════════════════════════════════════════════════════════════════

class _ClassTimetableView extends StatefulWidget {
  const _ClassTimetableView({
    required this.schoolContext,
    required this.termContext,
    required this.studentAdm,
  });

  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final int studentAdm;

  @override
  State<_ClassTimetableView> createState() => _ClassTimetableViewState();
}

class _ClassTimetableViewState extends State<_ClassTimetableView> {
  final _timetableDao = TimetableDao(db);
  SchoolConfig? _config;

  // Student enrollment info for current term
  int? _grade;
  int? _stream;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_ClassTimetableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentAdm != widget.studentAdm) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final schoolId = widget.schoolContext.membership.school.id;
    final term = widget.termContext.currentTerm;

    // TODO: reload config from new settings source when available
    _config ??= SchoolConfig.defaults();

    // Find student enrollment for current term
    if (term != null) {
      final enrollment =
          await (db.select(db.enrollments)..where(
                (t) =>
                    t.school.equals(schoolId) &
                    t.year.equals(term.year) &
                    t.term.equals(term.term) &
                    t.student.equals(widget.studentAdm),
              ))
              .getSingleOrNull();

      if (enrollment != null) {
        _grade = enrollment.grade;
        _stream = enrollment.stream;
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = widget.termContext.currentTerm;

    if (_loading || term == null) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    if (_grade == null || _stream == null) {
      return _NotEnrolledState(cs: cs);
    }

    return _TimetableGridView(
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      grade: _grade!,
      stream: _stream!,
      config: _config!,
      dao: _timetableDao,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BLANK / EMPTY STATES
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.event_busy_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No term selected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create a term to manage the timetable',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimetableState extends StatelessWidget {
  const _EmptyTimetableState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_view_week_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No timetable yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Configure rules and generate a schedule',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConfigState extends StatelessWidget {
  const _EmptyConfigState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No classes configured',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Set up grades and streams in Academics first',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEnrolledState extends StatelessWidget {
  const _NotEnrolledState({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_off_outlined,
              size: 22,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Not enrolled',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Student is not enrolled in a class this term',
            style: TextStyle(
              fontSize: 12.5,
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
// UTILITIES
// ═════════════════════════════════════════════════════════════════════════════

/// Formats seconds-since-midnight to HH:MM string.
String _fmtTime(int secondsSinceMidnight) {
  final h = secondsSinceMidnight ~/ 3600;
  final m = (secondsSinceMidnight % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _subjectLabel(int subjectCode, SchoolConfig config) {
  // Try CBC first, then 8-4-4
  try {
    final cbcSubject = CbcSubject.values.firstWhere(
      (s) => s.index_ == subjectCode,
    );
    return cbcSubject.label;
  } catch (_) {}
  try {
    final subject844 = EightFourFourSubject.values.firstWhere(
      (s) => s.index_ == subjectCode,
    );
    return subject844.label;
  } catch (_) {}
  return 'Subject $subjectCode';
}
