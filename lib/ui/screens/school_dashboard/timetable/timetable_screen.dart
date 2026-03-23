import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Action;

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';

import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_context.dart';
import '../../../../database/daos/catalog_dao.dart';
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
      TeacherEntry() =>
        schoolContext.permissions.canAny(Resource.classes, [
              Action.create,
              Action.update,
              Action.delete,
            ])
            ? _OwnerTimetableShell(
                schoolContext: schoolContext,
                termContext: termCtx,
              )
            : _TeacherTimetableView(
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
  final _catalogDao = CatalogDao(db);

  SchoolConfig? _config;
  TimetableRules? _rules;
  bool _generating = false;
  bool _deleting = false;
  bool _hasTimetable = false;

  late TabController _tabController;
  int _currentTabIndex = 0;

  StreamSubscription<bool>? _hasTimetableSub;
  StreamSubscription<List<SchoolStream>>? _configSub;

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
    if (!mounted) return;
    setState(() => _rules = rules);

    // Reactively build SchoolConfig from the school's streams table.
    // This mirrors the pattern used by _ExamsTabState._loadConfig().
    _configSub?.cancel();
    _configSub = _catalogDao.watchAllStreamsForSchool(schoolId).listen((
      allStreams,
    ) {
      if (!mounted) return;
      setState(() => _config = _buildConfigFromStreams(allStreams));
    });
  }

  /// Builds a [SchoolConfig] from raw [SchoolStream] rows, grouping by
  /// curriculum type and grade. Mirrors the identical helper in
  /// [_ExamsTabState] and [_ExamsShellState].
  SchoolConfig _buildConfigFromStreams(List<SchoolStream> allStreams) {
    if (allStreams.isEmpty) return SchoolConfig.defaults();

    final allGrades = allStreams.map((s) => s.grade).toSet();
    final byGrade = <int, List<SchoolStream>>{};
    for (final s in allStreams) {
      byGrade.putIfAbsent(s.grade, () => []).add(s);
    }

    CurriculumType curriculumForGrade(int grade) {
      if (grade >= 41) return CurriculumType.eightFourFour;
      if (grade >= 9) return CurriculumType.cbc;
      if (allGrades.any((g) => g >= 41)) return CurriculumType.eightFourFour;
      return CurriculumType.cbc;
    }

    final cbcGrades = <GradeConfig>[];
    final eftGrades = <GradeConfig>[];

    for (final entry in byGrade.entries) {
      final gradeNum = entry.key;
      final streamRows = entry.value
        ..sort((a, b) => a.stream.compareTo(b.stream));
      final gradeStreams = streamRows
          .map((s) => GradeStream(name: s.name, code: s.stream))
          .toList();
      final gc = GradeConfig(grade: gradeNum, streams: gradeStreams);
      if (curriculumForGrade(gradeNum) == CurriculumType.cbc) {
        cbcGrades.add(gc);
      } else {
        eftGrades.add(gc);
      }
    }

    cbcGrades.sort((a, b) => a.grade.compareTo(b.grade));
    eftGrades.sort((a, b) => a.grade.compareTo(b.grade));

    final curricula = <CurriculumConfig>[];
    if (cbcGrades.isNotEmpty) {
      curricula.add(
        CurriculumConfig(type: CurriculumType.cbc, grades: cbcGrades),
      );
    }
    if (eftGrades.isNotEmpty) {
      curricula.add(
        CurriculumConfig(type: CurriculumType.eightFourFour, grades: eftGrades),
      );
    }

    return SchoolConfig(curricula: curricula);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hasTimetableSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }

  Future<void> _openRulesSheet() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _rules == null) return;

    final result = await showTimetableWizardDialog(
      context: context,
      initialRules: _rules!,
      schoolContext: widget.schoolContext,
      termContext: widget.termContext,
    );

    if (result == null || !mounted) return;

    // Rules were already saved to disk inside the dialog (_save).
    // Only reload the in-memory copy and optionally re-run generation.
    if (mounted) setState(() => _rules = result.rules);

    if (result.shouldGenerate) {
      await _runGeneration(result.rules);
    }
  }

  Future<void> _openGenerateLessonsDialog() async {
    final term = widget.termContext.currentTerm;
    if (term == null) return;
    await showGenerateLessonsDialog(
      context,
      schoolId: widget.schoolContext.membership.school.id,
      year: term.year,
      term: term.term,
      timetableDao: _timetableDao,
      config: _config ?? SchoolConfig.defaults(),
    );
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
              borderRadius: BorderRadius.circular(8),
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

    final entry = widget.schoolContext.currentEntry.value;
    final canManage =
        entry is OwnerEntry ||
        widget.schoolContext.permissions.can(Resource.classes, Action.create);
    final canDelete =
        entry is OwnerEntry ||
        widget.schoolContext.permissions.can(Resource.classes, Action.delete);

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
                    config: _config ?? SchoolConfig.defaults(),
                  )
                else
                  const _NoTermState(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0 && (canManage || canDelete)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Delete FAB — shown only when a timetable exists and user can delete
                if (_hasTimetable) ...[
                  if (canDelete)
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
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
                  if (canDelete) const SizedBox(height: 12),
                  // Generate Lessons FAB — replaces the wizard "+" when timetable exists
                  if (canManage)
                    _GenerateLessonsFab(
                      heroTag: 'timetable_gen_lessons',
                      onTap: _openGenerateLessonsDialog,
                      cs: cs,
                    ),
                ] else ...[
                  // No timetable yet — show the wizard FAB
                  if (canManage)
                    _GenerateFab(
                      heroTag: 'timetable_generate',
                      onTap: _openRulesSheet,
                      generating: _generating,
                      cs: cs,
                    ),
                ],
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
// Generate Lessons — FAB, dialog, preview, substitution picker
// ═════════════════════════════════════════════════════════════════════════════

/// FAB shown when a timetable already exists — opens the lesson generation dialog.
class _GenerateLessonsFab extends StatelessWidget {
  const _GenerateLessonsFab({
    required this.onTap,
    required this.cs,
    this.heroTag,
  });

  final VoidCallback onTap;
  final ColorScheme cs;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      onPressed: onTap,
      backgroundColor: AppTheme.brandGreen,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      tooltip: 'Generate lessons from timetable',
      child: const Icon(Icons.auto_awesome_rounded, size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// An in-memory lesson generated from a timetable slot — not yet saved to DB.
class _GeneratedLesson {
  _GeneratedLesson({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.date,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int date;
  final int subjectId;
  final String subjectName;
  String teacherId;
  String teacherName;
  final int startTime;
  final int endTime;

  LessonsCompanion toCompanion() {
    final nowMs = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    return LessonsCompanion(
      school: Value(schoolId),
      year: Value(year),
      term: Value(term),
      grade: Value(grade),
      stream: Value(stream),
      date: Value(date),
      subject: Value(subjectId),
      teacher: Value(teacherId),
      created: Value(nowMs),
      updated: Value(nowMs),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Shows the Generate Lessons dialog.
///
/// Desktop (≥ kMobileBreakpoint): centred [Dialog] with max width 480.
/// Mobile (< kMobileBreakpoint): modal bottom sheet (88 % height, top-rounded).
Future<void> showGenerateLessonsDialog(
  BuildContext context, {
  required String schoolId,
  required int year,
  required int term,
  required TimetableDao timetableDao,
  required SchoolConfig config,
}) {
  final isDesktop =
      MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
  if (isDesktop) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _GenerateLessonsDialog(
            schoolId: schoolId,
            year: year,
            term: term,
            timetableDao: timetableDao,
            config: config,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: _GenerateLessonsDialog(
          schoolId: schoolId,
          year: year,
          term: term,
          timetableDao: timetableDao,
          config: config,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _GenerateLessonsDialog extends StatefulWidget {
  const _GenerateLessonsDialog({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.timetableDao,
    required this.config,
  });

  final String schoolId;
  final int year;
  final int term;
  final TimetableDao timetableDao;
  final SchoolConfig config;

  @override
  State<_GenerateLessonsDialog> createState() => _GenerateLessonsDialogState();
}

class _GenerateLessonsDialogState extends State<_GenerateLessonsDialog> {
  // ── State ─────────────────────────────────────────────────────────────────

  int _step = 0; // 0 = scope picker, 1 = preview

  /// null = no selection, 0 = Today, 1 = This Week
  int? _selectedScope;

  bool _loading = false; // true while loading timetable from DB
  bool _saving = false; // true while writing to DB

  List<_GeneratedLesson> _preview = [];

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Days since Unix epoch for a [DateTime].
  static int _epochDays(DateTime d) =>
      d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// Map Dart weekday (1=Mon … 7=Sun) to [DayOfWeek].
  static DayOfWeek _dartToDayOfWeek(int dartWeekday) {
    // Dart: Mon=1,Tue=2,...,Sat=6,Sun=7
    // DayOfWeek: sun=0,mon=1,...,sat=6
    return dartWeekday == 7 ? DayOfWeek.sunday : DayOfWeek.values[dartWeekday];
  }

  /// Returns (date: DateTime, dayOfWeek: DayOfWeek) pairs to generate.
  ///
  /// For scope 0 (Today): one entry — today.
  /// For scope 1 (This Week): Monday through Friday of the current calendar week.
  List<({DateTime date, DayOfWeek dow})> _datesForScope(int scope) {
    final now = DateTime.now();
    if (scope == 0) {
      return [
        (
          date: DateTime(now.year, now.month, now.day),
          dow: _dartToDayOfWeek(now.weekday),
        ),
      ];
    }
    // This week Mon–Fri
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(5, (i) {
      final d = monday.add(Duration(days: i));
      return (
        date: DateTime(d.year, d.month, d.day),
        dow: _dartToDayOfWeek(d.weekday),
      );
    });
  }

  Future<void> _generate() async {
    if (_selectedScope == null || _loading) return;
    setState(() => _loading = true);
    try {
      final datePairs = _datesForScope(_selectedScope!);
      final days = datePairs.map((p) => p.dow).toSet().toList();

      final entries = await widget.timetableDao.getTermTimetableForDays(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        days: days,
      );

      // Map timetable entries → _GeneratedLesson per (date, slot)
      final generated = <_GeneratedLesson>[];
      for (final pair in datePairs) {
        final dayEntries = entries
            .where((e) => e.slot.day == pair.dow)
            .toList();
        for (final e in dayEntries) {
          generated.add(
            _GeneratedLesson(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: e.slot.grade,
              stream: e.slot.stream,
              date: _epochDays(pair.date),
              subjectId: e.slot.subject,
              subjectName: e.subjectName,
              teacherId: e.teacher.id,
              teacherName: e.teacher.name,
              startTime: e.slot.start,
              endTime: e.slot.end,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _preview = generated;
          _step = 1;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final account = cache.currentUser;
    if (account == null) return;
    setState(() => _saving = true);
    try {
      final companions = _preview.map((l) => l.toCompanion()).toList();
      await widget.timetableDao.saveLessons(
        lessonsList: companions,
        accountId: account.user.id,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${companions.length} lesson${companions.length == 1 ? '' : 's'} saved.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save lessons: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    final radius = isDesktop
        ? BorderRadius.circular(AppTheme.kModalRadius)
        : const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: radius,
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(cs, isDark, isDesktop),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderColor(isDark, cs),
            ),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _step == 0
                    ? _buildScopeStep(cs, isDark)
                    : _buildPreviewStep(cs, isDark),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderColor(isDark, cs),
            ),
            _buildFooter(cs, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark, bool isDesktop) {
    final title = _step == 0 ? 'Generate Lessons' : 'Preview Lessons';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          if (!isDesktop)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (_step == 1) ...[
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
          if (_step == 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.brandGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              ),
              child: Text(
                '${_preview.length} lesson${_preview.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.brandGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Scope Picker ───────────────────────────────────────────────────

  Widget _buildScopeStep(ColorScheme cs, bool isDark) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final friday = monday.add(const Duration(days: 4));

    String todayLabel() {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
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
      return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
    }

    String weekLabel() {
      const months = [
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
      final m1 = months[monday.month - 1];
      final m2 = months[friday.month - 1];
      if (monday.month == friday.month) {
        return '${monday.day} – ${friday.day} $m1';
      }
      return '${monday.day} $m1 – ${friday.day} $m2';
    }

    return SingleChildScrollView(
      key: const ValueKey('scope'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose how many lessons to generate',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ScopeOptionCard(
                  icon: Icons.today_rounded,
                  title: 'Today',
                  subtitle: todayLabel(),
                  selected: _selectedScope == 0,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedScope = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScopeOptionCard(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'This Week',
                  subtitle: weekLabel(),
                  selected: _selectedScope == 1,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedScope = 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Preview ────────────────────────────────────────────────────────

  Widget _buildPreviewStep(ColorScheme cs, bool isDark) {
    if (_preview.isEmpty) {
      return Padding(
        key: const ValueKey('preview_empty'),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 32,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedScope == 0
                  ? 'No timetable entries for today'
                  : 'No timetable entries for this week',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group preview lessons by date (epoch days)
    final grouped = <int, List<_GeneratedLesson>>{};
    for (final l in _preview) {
      grouped.putIfAbsent(l.date, () => []).add(l);
    }
    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      key: const ValueKey('preview_list'),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: () {
        int count = 0;
        for (final date in dates) {
          count += 1 + grouped[date]!.length; // header + rows
        }
        return count;
      }(),
      itemBuilder: (context, index) {
        int cursor = 0;
        for (final date in dates) {
          if (index == cursor) {
            return _PreviewDateHeader(date: date, cs: cs);
          }
          cursor++;
          final dayLessons = grouped[date]!;
          for (int i = 0; i < dayLessons.length; i++) {
            if (index == cursor) {
              return _PreviewLessonItem(
                lesson: dayLessons[i],
                allLessons: _preview,
                cs: cs,
                isDark: isDark,
                timetableDao: widget.timetableDao,
                schoolId: widget.schoolId,
                year: widget.year,
                term: widget.term,
                config: widget.config,
                onChanged: () => setState(() {}),
              );
            }
            cursor++;
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, bool isDark) {
    if (_step == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.5),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: (_selectedScope == null || _loading)
                  ? null
                  : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Generate'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.brandGreen.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                minimumSize: const Size(0, 38),
              ),
            ),
          ],
        ),
      );
    }

    // Step 1 footer: Discard + Save
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface.withValues(alpha: 0.5),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: const Text('Discard'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: (_saving || _preview.isEmpty) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text(
              'Save ${_preview.length} lesson${_preview.length == 1 ? '' : 's'}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.brandGreen.withValues(
                alpha: 0.35,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              minimumSize: const Size(0, 38),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScopeOptionCard extends StatefulWidget {
  const _ScopeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_ScopeOptionCard> createState() => _ScopeOptionCardState();
}

class _ScopeOptionCardState extends State<_ScopeOptionCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg {
    if (widget.selected) {
      return widget.cs.primary.withValues(alpha: 0.08);
    }
    if (_pressed) return AppTheme.nestedBg(widget.isDark, widget.cs);
    if (_hovered) {
      return widget.cs.primary.withValues(alpha: 0.04);
    }
    return AppTheme.nestedBg(widget.isDark, widget.cs);
  }

  Color get _borderColor {
    if (widget.selected) return widget.cs.primary;
    if (_hovered) return widget.cs.primary.withValues(alpha: 0.4);
    return AppTheme.borderColor(widget.isDark, widget.cs);
  }

  double get _borderWidth => widget.selected ? 1.5 : 1.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: _borderColor, width: _borderWidth),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? widget.cs.primary.withValues(alpha: 0.12)
                        : AppTheme.borderColor(
                            widget.isDark,
                            widget.cs,
                          ).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: widget.selected
                        ? widget.cs.primary
                        : widget.cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.selected
                        ? widget.cs.primary
                        : widget.cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: widget.cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PreviewDateHeader extends StatelessWidget {
  const _PreviewDateHeader({required this.date, required this.cs});

  final int date; // days since epoch
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

// ─────────────────────────────────────────────────────────────────────────────

class _PreviewLessonItem extends StatelessWidget {
  const _PreviewLessonItem({
    required this.lesson,
    required this.allLessons,
    required this.cs,
    required this.isDark,
    required this.timetableDao,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.onChanged,
  });

  final _GeneratedLesson lesson;
  final List<_GeneratedLesson> allLessons;
  final ColorScheme cs;
  final bool isDark;
  final TimetableDao timetableDao;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final VoidCallback onChanged;

  String _gradeStreamLabel() {
    // Grade label
    String gradeLabel = 'Grade ${lesson.grade}';
    for (final cur in config.curricula) {
      final labels = gradeLabelsFor(cur.type);
      final l = labels[lesson.grade];
      if (l != null) {
        gradeLabel = l;
        break;
      }
    }
    // Stream label
    String streamLabel = '';
    outer:
    for (final cur in config.curricula) {
      for (final gc in cur.grades) {
        if (gc.grade == lesson.grade) {
          for (final s in gc.streams) {
            if (s.code == lesson.stream) {
              streamLabel = s.name;
              break outer;
            }
          }
        }
      }
    }
    return streamLabel.isNotEmpty ? '$gradeLabel · $streamLabel' : gradeLabel;
  }

  @override
  Widget build(BuildContext context) {
    final timeRange =
        '${_fmtTime(lesson.startTime)} – ${_fmtTime(lesson.endTime)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colour dot
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colorForSubject(lesson.subjectId),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.teacherName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Grade/stream badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.nestedBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              _gradeStreamLabel(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Edit icon
          GestureDetector(
            onTap: () => _showSubstitutePickerDialog(
              context,
              lesson: lesson,
              allLessons: allLessons,
              timetableDao: timetableDao,
              schoolId: schoolId,
              year: year,
              term: term,
              cs: cs,
              isDark: isDark,
              onChanged: onChanged,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.edit_outlined,
                size: 15,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showSubstitutePickerDialog(
  BuildContext context, {
  required _GeneratedLesson lesson,
  required List<_GeneratedLesson> allLessons,
  required TimetableDao timetableDao,
  required String schoolId,
  required int year,
  required int term,
  required ColorScheme cs,
  required bool isDark,
  required VoidCallback onChanged,
}) async {
  final isDesktop =
      MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;
  if (isDesktop) {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _SubstitutePickerDialog(
            lesson: lesson,
            allLessons: allLessons,
            timetableDao: timetableDao,
            schoolId: schoolId,
            year: year,
            term: term,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.70,
        ),
        child: _SubstitutePickerDialog(
          lesson: lesson,
          allLessons: allLessons,
          timetableDao: timetableDao,
          schoolId: schoolId,
          year: year,
          term: term,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SubstitutePickerDialog extends StatefulWidget {
  const _SubstitutePickerDialog({
    required this.lesson,
    required this.allLessons,
    required this.timetableDao,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.onChanged,
  });

  final _GeneratedLesson lesson;
  final List<_GeneratedLesson> allLessons;
  final TimetableDao timetableDao;
  final String schoolId;
  final int year;
  final int term;
  final VoidCallback onChanged;

  @override
  State<_SubstitutePickerDialog> createState() =>
      _SubstitutePickerDialogState();
}

class _SubstitutePickerDialogState extends State<_SubstitutePickerDialog> {
  bool _loading = true;

  /// (id, name, hasConflict)
  List<({String id, String name, bool hasConflict})> _candidates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Collect all teachers from the preview that teach this subject.
    final seen = <String>{};
    final candidates = <({String id, String name, bool hasConflict})>[];
    for (final l in widget.allLessons) {
      if (l.subjectId != widget.lesson.subjectId) continue;
      if (!seen.add(l.teacherId)) continue;
      final conflict = widget.allLessons.any(
        (other) =>
            other != widget.lesson &&
            other.teacherId == l.teacherId &&
            other.date == widget.lesson.date &&
            other.startTime < widget.lesson.endTime &&
            other.endTime > widget.lesson.startTime,
      );
      candidates.add((
        id: l.teacherId,
        name: l.teacherName,
        hasConflict: conflict,
      ));
    }
    if (mounted) {
      setState(() {
        _candidates = candidates;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppTheme.kMobileBreakpoint;

    final radius = isDesktop
        ? BorderRadius.circular(AppTheme.kModalRadius)
        : const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.kModalRadius),
            topRight: Radius.circular(AppTheme.kModalRadius),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: radius,
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
        boxShadow: AppTheme.modalShadow(isDark),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Change Teacher',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.lesson.subjectName} · '
                    '${_fmtTime(widget.lesson.startTime)}–'
                    '${_fmtTime(widget.lesson.endTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderColor(isDark, cs),
            ),
            // Teacher list
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _candidates.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No other teachers assigned to this subject.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _candidates.length,
                      separatorBuilder: (_, __) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (_, i) {
                        final c = _candidates[i];
                        final isSelected = c.id == widget.lesson.teacherId;
                        return InkWell(
                          onTap: c.hasConflict
                              ? null
                              : () {
                                  widget.lesson.teacherId = c.id;
                                  widget.lesson.teacherName = c.name;
                                  widget.onChanged();
                                  Navigator.of(context).pop();
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.07)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Avatar initial
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? cs.primary.withValues(alpha: 0.15)
                                        : cs.surfaceContainerHighest.withValues(
                                            alpha: 0.5,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    c.name.isNotEmpty
                                        ? c.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? cs.primary
                                          : cs.onSurfaceVariant.withValues(
                                              alpha: 0.6,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: c.hasConflict
                                          ? cs.onSurface.withValues(alpha: 0.35)
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status badge
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.kChipRadius,
                                      ),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: cs.primary,
                                      ),
                                    ),
                                  )
                                else if (c.hasConflict)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.error.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.kChipRadius,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 11,
                                          color: cs.error.withValues(
                                            alpha: 0.75,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Conflict',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: cs.error.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandGreen.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.kChipRadius,
                                      ),
                                    ),
                                    child: Text(
                                      'Available',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.brandGreen.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OWNER — Lessons Tab  (Log · Teachers · Coverage)
// ═══════════════════════════════════════════════════════════════════════════

enum _LessonView { log, teachers, coverage }

class _LessonsTab extends StatefulWidget {
  const _LessonsTab({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.timetableDao,
    required this.config,
  });

  final String schoolId;
  final int year;
  final int term;
  final TimetableDao timetableDao;
  final SchoolConfig config;

  @override
  State<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<_LessonsTab> {
  _LessonView _view = _LessonView.log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<LessonEntry>>(
      stream: widget.timetableDao.watchAllLessons(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
      ),
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

        final lessons = snapshot.data ?? [];

        if (lessons.isEmpty) {
          return _LessonsEmptyState(cs: cs);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LessonStatsBar(lessons: lessons, cs: cs, isDark: isDark),
            _LessonViewSwitcher(
              view: _view,
              cs: cs,
              isDark: isDark,
              onChanged: (v) => setState(() => _view = v),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: switch (_view) {
                  _LessonView.log => _LessonLogView(
                    key: const ValueKey('log'),
                    lessons: lessons,
                    config: widget.config,
                    cs: cs,
                    isDark: isDark,
                  ),
                  _LessonView.teachers => _LessonTeachersView(
                    key: const ValueKey('teachers'),
                    lessons: lessons,
                    config: widget.config,
                    cs: cs,
                    isDark: isDark,
                  ),
                  _LessonView.coverage => _LessonCoverageView(
                    key: const ValueKey('coverage'),
                    lessons: lessons,
                    cs: cs,
                    isDark: isDark,
                  ),
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stats bar ────────────────────────────────────────────────────────────────

class _LessonStatsBar extends StatelessWidget {
  const _LessonStatsBar({
    required this.lessons,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final teacherCount = lessons.map((e) => e.teacher.id).toSet().length;
    final subjectCount = lessons.map((e) => e.lesson.subject).toSet().length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _LessonStatChip(
              value: '${lessons.length}',
              label: 'Lessons',
              cs: cs,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LessonStatChip(
              value: '$teacherCount',
              label: teacherCount == 1 ? 'Teacher' : 'Teachers',
              cs: cs,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LessonStatChip(
              value: '$subjectCount',
              label: subjectCount == 1 ? 'Subject' : 'Subjects',
              cs: cs,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonStatChip extends StatelessWidget {
  const _LessonStatChip({
    required this.value,
    required this.label,
    required this.cs,
    required this.isDark,
  });

  final String value;
  final String label;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── View switcher ─────────────────────────────────────────────────────────────

class _LessonViewSwitcher extends StatelessWidget {
  const _LessonViewSwitcher({
    required this.view,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final _LessonView view;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<_LessonView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _LessonViewChip(
            label: 'Log',
            selected: view == _LessonView.log,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(_LessonView.log),
          ),
          const SizedBox(width: 6),
          _LessonViewChip(
            label: 'Teachers',
            selected: view == _LessonView.teachers,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(_LessonView.teachers),
          ),
          const SizedBox(width: 6),
          _LessonViewChip(
            label: 'Coverage',
            selected: view == _LessonView.coverage,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(_LessonView.coverage),
          ),
        ],
      ),
    );
  }
}

class _LessonViewChip extends StatelessWidget {
  const _LessonViewChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.4)
                : AppTheme.borderColor(isDark, cs),
            width: selected ? 1.0 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ── Log view ──────────────────────────────────────────────────────────────────

class _LessonLogView extends StatelessWidget {
  const _LessonLogView({
    super.key,
    required this.lessons,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<LessonEntry>>{};
    for (final e in lessons) {
      grouped.putIfAbsent(e.lesson.date, () => []).add(e);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final items = <Widget>[];
    for (final date in dates) {
      final dayLessons = grouped[date]!;
      items.add(
        _LessonDayHeader(
          date: date,
          count: dayLessons.length,
          cs: cs,
          isDark: isDark,
        ),
      );
      for (int i = 0; i < dayLessons.length; i++) {
        items.add(
          _LessonLogRow(
            entry: dayLessons[i],
            config: config,
            cs: cs,
            isDark: isDark,
          ),
        );
        if (i < dayLessons.length - 1) {
          items.add(AppTheme.tableRowDivider(isDark, cs));
        }
      }
      items.add(const SizedBox(height: 8));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _LessonDayHeader extends StatelessWidget {
  const _LessonDayHeader({
    required this.date,
    required this.count,
    required this.cs,
    required this.isDark,
  });

  final int date;
  final int count;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            _lessonDayLabel(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.75),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.5,
              ),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonLogRow extends StatelessWidget {
  const _LessonLogRow({
    required this.entry,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final LessonEntry entry;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subjectColor = _colorForSubject(entry.lesson.subject);
    final classLabel = _lessonClassLabel(
      entry.lesson.grade,
      entry.lesson.stream,
      config,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: subjectColor.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
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
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.55 : 0.5,
                ),
                borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
              ),
              child: Text(
                classLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Teachers view ─────────────────────────────────────────────────────────────

class _LessonTeachersView extends StatefulWidget {
  const _LessonTeachersView({
    super.key,
    required this.lessons,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_LessonTeachersView> createState() => _LessonTeachersViewState();
}

class _LessonTeachersViewState extends State<_LessonTeachersView> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    final map = <String, ({String name, List<LessonEntry> lessons})>{};
    for (final e in widget.lessons) {
      final id = e.teacher.id;
      final existing = map[id];
      if (existing == null) {
        map[id] = (name: e.teacher.name, lessons: [e]);
      } else {
        existing.lessons.add(e);
      }
    }

    final teachers = map.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.lessons.length.compareTo(a.value.lessons.length);
        return cmp != 0 ? cmp : a.value.name.compareTo(b.value.name);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: teachers.length,
      itemBuilder: (context, i) {
        final tid = teachers[i].key;
        final tdata = teachers[i].value;
        final isExpanded = _expanded.contains(tid);

        final allSubjects = tdata.lessons
            .map((e) => e.subjectName)
            .toSet()
            .toList();
        final previewSubjects = allSubjects.take(3).join(', ');
        final extraCount = allSubjects.length - 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expanded.remove(tid);
                } else {
                  _expanded.add(tid);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tdata.name.isNotEmpty
                            ? tdata.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tdata.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            extraCount > 0
                                ? '$previewSubjects +$extraCount more'
                                : previewSubjects,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.5 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        '${tdata.lessons.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeInOut,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  color: AppTheme.nestedBg(isDark, cs),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: () {
                    final sorted = [...tdata.lessons]
                      ..sort((a, b) => b.lesson.date.compareTo(a.lesson.date));
                    final rows = <Widget>[];
                    for (int j = 0; j < sorted.length; j++) {
                      rows.add(
                        _TeacherLessonSubRow(
                          entry: sorted[j],
                          config: widget.config,
                          cs: cs,
                          isDark: isDark,
                        ),
                      );
                      if (j < sorted.length - 1) {
                        rows.add(AppTheme.tableRowDivider(isDark, cs));
                      }
                    }
                    return rows;
                  }(),
                ),
              ),
            ),
            AppTheme.tableRowDivider(isDark, cs),
          ],
        );
      },
    );
  }
}

class _TeacherLessonSubRow extends StatelessWidget {
  const _TeacherLessonSubRow({
    required this.entry,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final LessonEntry entry;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subjectColor = _colorForSubject(entry.lesson.subject);
    final classLabel = _lessonClassLabel(
      entry.lesson.grade,
      entry.lesson.stream,
      config,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: subjectColor.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.subjectName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.35,
              ),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              classLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatDateFromDays(entry.lesson.date),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coverage view ─────────────────────────────────────────────────────────────

class _LessonCoverageView extends StatelessWidget {
  const _LessonCoverageView({
    super.key,
    required this.lessons,
    required this.cs,
    required this.isDark,
  });

  final List<LessonEntry> lessons;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final map = <int, ({String name, int count})>{};
    for (final e in lessons) {
      final id = e.lesson.subject;
      final existing = map[id];
      map[id] = (name: e.subjectName, count: (existing?.count ?? 0) + 1);
    }

    final subjects = map.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    final maxCount = subjects.isEmpty ? 1 : subjects.first.value.count;

    return ListView.separated(
      padding: const EdgeInsets.only(top: 10, bottom: 80),
      itemCount: subjects.length,
      separatorBuilder: (_, __) => AppTheme.tableRowDivider(isDark, cs),
      itemBuilder: (context, i) {
        final subjectId = subjects[i].key;
        final data = subjects[i].value;
        final fraction = data.count / maxCount;
        final subjectColor = _colorForSubject(subjectId);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: subjectColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 4,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: subjectColor.withValues(
                                  alpha: isDark ? 0.12 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              height: 4,
                              width: constraints.maxWidth * fraction,
                              decoration: BoxDecoration(
                                color: subjectColor.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${data.count}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.8),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                data.count == 1 ? 'lesson' : 'lessons',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _LessonsEmptyState extends StatelessWidget {
  const _LessonsEmptyState({required this.cs});

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
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Generate lessons from the Timetable tab',
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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats days-since-epoch to "Mon, 15 Jan".
String _lessonDayLabel(int daysSinceEpoch) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const months = [
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
  final d = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  // DateTime.weekday: 1=Mon … 7=Sun.  % 7 maps Sun→0, Mon→1 … Sat→6.
  return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]}';
}

/// Returns "Form 4 · Blue" or "Grade 3" etc., using config for label lookup.
String _lessonClassLabel(int grade, int stream, SchoolConfig config) {
  String gradeLabel = 'Grade $grade';
  String streamLabel = '';
  outer:
  for (final cur in config.curricula) {
    final labels = gradeLabelsFor(cur.type);
    if (labels.containsKey(grade)) gradeLabel = labels[grade]!;
    for (final gc in cur.grades) {
      if (gc.grade == grade) {
        for (final s in gc.streams) {
          if (s.code == stream) {
            streamLabel = s.name;
            break outer;
          }
        }
      }
    }
  }
  return streamLabel.isNotEmpty ? '$gradeLabel · $streamLabel' : gradeLabel;
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMETABLE GENERATION WIZARD
// 5-stage wizard: Slots → Days → Teacher Constraints → Subject Constraints
//                → Conflict Resolution & Generation
// TT-03: Full wizard UI is implemented in the stage widgets below.
// ═══════════════════════════════════════════════════════════════════════════

// ── Result returned to _OwnerTimetableShellState ─────────────────────────────

class _RulesSheetResult {
  const _RulesSheetResult({required this.rules, required this.shouldGenerate});
  final TimetableRules rules;
  final bool shouldGenerate;
}

// ── Wizard data classes ───────────────────────────────────────────────────────

class _WizardTeacher {
  const _WizardTeacher({required this.id, required this.name});
  final String id;
  final String name;
}

class _WizardSubject {
  const _WizardSubject({required this.id, required this.name});
  final int id;
  final String name;
}

/// A detected incompatibility between a [TeacherConstraintEntry] and a
/// [SubjectConstraintEntry] when applied to the same class assignment.
class _ConflictPair {
  _ConflictPair({required this.teacherEntry, required this.subjectEntry});
  final TeacherConstraintEntry teacherEntry;
  final SubjectConstraintEntry subjectEntry;

  /// When `true` the teacher constraint is preserved and the subject
  /// constraint is dropped at generation time.
  bool teacherWins = true;
}

// ── Wizard entry point ────────────────────────────────────────────────────────

Future<_RulesSheetResult?> showTimetableWizardDialog({
  required BuildContext context,
  required TimetableRules initialRules,
  required SchoolContext schoolContext,
  required ActiveTermContext termContext,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<_RulesSheetResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _TimetableWizard(
                initialRules: initialRules,
                schoolContext: schoolContext,
                termContext: termContext,
              ),
            ),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<_RulesSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.kModalRadius),
              topRight: Radius.circular(AppTheme.kModalRadius),
            ),
            border: Border(
              top: BorderSide(color: AppTheme.borderColor(isDark, cs)),
            ),
          ),
          child: _TimetableWizard(
            initialRules: initialRules,
            schoolContext: schoolContext,
            termContext: termContext,
          ),
        ),
      );
    },
  );
}

// ── Wizard widget ─────────────────────────────────────────────────────────────

class _TimetableWizard extends StatefulWidget {
  const _TimetableWizard({
    required this.initialRules,
    required this.schoolContext,
    required this.termContext,
  });

  final TimetableRules initialRules;
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_TimetableWizard> createState() => _TimetableWizardState();
}

class _TimetableWizardState extends State<_TimetableWizard> {
  int _stage =
      0; // 0=Days+Slots, 1=Teachers, 2=Subjects, 3=Remainder Slots, 4=Generate
  late TimetableRules _rules;

  List<_WizardTeacher> _teachers = [];
  List<_WizardSubject> _subjects = [];
  List<SolverAssignment> _assignments = [];
  bool _loaded = false;
  bool _saving = false;

  // Stage-3 state
  List<_ConflictPair> _conflicts = [];
  bool _generating = false;
  GeneratorResult? _generationResult;

  @override
  void initState() {
    super.initState();
    _rules = TimetableRules.fromJson(widget.initialRules.toJson());
    _loadData();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final term = widget.termContext.currentTerm;
    if (term == null || !mounted) return;

    final schoolId = widget.schoolContext.membership.school.id;
    final timetableDao = TimetableDao(db);

    // Load subject-teacher assignments for this term.
    final assignments = await timetableDao.getSubjectTeachersForTerm(
      schoolId: schoolId,
      year: term.year,
      term: term.term,
    );

    // Resolve teacher names from the users table.
    final teacherIds = assignments.map((a) => a.teacherUserId).toSet().toList();
    final users = teacherIds.isEmpty
        ? <UsersData>[]
        : await (db.select(
            db.users,
          )..where((u) => u.id.isIn(teacherIds))).get();
    final userNameMap = <String, String>{for (final u in users) u.id: u.name};
    final teachers =
        teacherIds
            .map((id) => _WizardTeacher(id: id, name: userNameMap[id] ?? id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    // Resolve subject names from the global catalog.
    final subjectIds = assignments.map((a) => a.subjectId).toSet();
    final allSubjects = await CatalogDao(db).getSubjects();
    final subjects =
        allSubjects
            .where((s) => subjectIds.contains(s.id))
            .map((s) => _WizardSubject(id: s.id, name: s.name))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (mounted) {
      setState(() {
        _teachers = teachers;
        _subjects = subjects;
        _assignments = assignments;
        _loaded = true;
      });
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goNext() {
    if (_stage == 3) _computeConflicts();
    if (_stage < 4) setState(() => _stage++);
  }

  void _goBack() {
    if (_stage > 0) {
      setState(() => _stage--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FileCache.saveTimetableRules(
        schoolId: widget.schoolContext.membership.school.id,
        year: term.year,
        term: term.term,
        rules: _rules,
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pop(_RulesSheetResult(rules: _rules, shouldGenerate: false));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _completeWithGeneration() => Navigator.of(
    context,
  ).pop(_RulesSheetResult(rules: _rules, shouldGenerate: true));

  // ── Conflict detection ──────────────────────────────────────────────────

  void _computeConflicts() {
    final conflicts = <_ConflictPair>[];
    for (final tc in _rules.teacherConstraints) {
      for (final sc in _rules.subjectConstraints) {
        // Only relevant when both constraints target the same class assignment.
        final hasAssignment = _assignments.any(
          (a) => a.teacherUserId == tc.teacherId && a.subjectId == sc.subjectId,
        );
        if (!hasAssignment) continue;

        final sharedDays = tc.days.where((d) => sc.days.contains(d)).toList();
        if (sharedDays.isEmpty) continue;

        bool incompatible = false;
        if (!tc.isBlock && !sc.isBlock) {
          // Both requirements: intersection of allowed slots must be non-empty.
          final intersection = tc.slotIndices
              .where((s) => sc.slotIndices.contains(s))
              .toList();
          if (intersection.isEmpty) incompatible = true;
        } else if (tc.isBlock && !sc.isBlock) {
          // Teacher blocks the exact slots the subject requires.
          final requiresAll =
              sc.slotIndices.isNotEmpty &&
              sc.slotIndices.every((s) => tc.slotIndices.contains(s));
          if (requiresAll) incompatible = true;
        } else if (!tc.isBlock && sc.isBlock) {
          // Teacher requires the exact slots the subject blocks.
          final requiresAll =
              tc.slotIndices.isNotEmpty &&
              tc.slotIndices.every((s) => sc.slotIndices.contains(s));
          if (requiresAll) incompatible = true;
        }

        if (incompatible) {
          conflicts.add(_ConflictPair(teacherEntry: tc, subjectEntry: sc));
        }
      }
    }
    setState(() => _conflicts = conflicts);
  }

  // ── Generation ──────────────────────────────────────────────────────────

  Future<void> _runGeneration() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _generating) return;
    setState(() {
      _generating = true;
      _generationResult = null;
    });

    try {
      // Drop lower-priority constraints from each detected conflict pair.
      final resolvedTeacher = List<TeacherConstraintEntry>.from(
        _rules.teacherConstraints,
      );
      final resolvedSubject = List<SubjectConstraintEntry>.from(
        _rules.subjectConstraints,
      );
      for (final cp in _conflicts) {
        if (cp.teacherWins) {
          resolvedSubject.remove(cp.subjectEntry);
        } else {
          resolvedTeacher.remove(cp.teacherEntry);
        }
      }

      final resolvedRules = _rules.copyWith(
        teacherConstraints: resolvedTeacher,
        subjectConstraints: resolvedSubject,
      );

      final input = GeneratorInput(
        assignments: _assignments,
        rules: resolvedRules,
      );
      final result = await compute(runTimetableGenerator, input);
      if (mounted) setState(() => _generationResult = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _generationResult = GeneratorFailure(
            reason: e.toString(),
            conflicts: [],
          );
        });
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - 80,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs, isDark, isMobile),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_stage),
                child: _buildStage(cs, isDark),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          _buildFooter(cs, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark, bool isMobile) {
    const stageLabels = [
      'Day & Slot Setup',
      'Teacher Constraints',
      'Subject Constraints',
      'Remainder Slots',
      'Review & Generate',
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 4 : 16, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMobile)
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stageLabels[_stage],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${_stage + 1} of 5',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _WizardStepDots(currentStep: _stage, totalSteps: 5, cs: cs),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStage(ColorScheme cs, bool isDark) {
    if (!_loaded && _stage >= 1) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }
    return switch (_stage) {
      0 => _Stage0DaysSlots(
        rules: _rules,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      1 => _Stage1TeacherConstraints(
        rules: _rules,
        teachers: _teachers,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      2 => _Stage2SubjectConstraints(
        rules: _rules,
        subjects: _subjects,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      3 => _Stage3RemainderSlots(
        rules: _rules,
        assignments: _assignments,
        subjects: _subjects,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      4 => _Stage3Generate(
        rules: _rules,
        conflicts: _conflicts,
        teachers: _teachers,
        subjects: _subjects,
        generating: _generating,
        result: _generationResult,
        cs: cs,
        isDark: isDark,
        onConflictResolved: (cp, teacherWins) =>
            setState(() => cp.teacherWins = teacherWins),
        onGenerate: _runGeneration,
        onComplete: _completeWithGeneration,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildFooter(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          if (_stage > 0)
            _WizardTextButton(label: 'Back', onTap: _goBack, cs: cs),
          const Spacer(),
          _WizardTextButton(
            label: 'Save',
            onTap: _saving ? null : _save,
            loading: _saving,
            cs: cs,
          ),
          if (_stage < 4) ...[
            const SizedBox(width: 8),
            _WizardFilledButton(
              label: _stage == 3 ? 'Review' : 'Next',
              onTap: _goNext,
              cs: cs,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wizard button helpers
// ─────────────────────────────────────────────────────────────────────────────

class _WizardTextButton extends StatelessWidget {
  const _WizardTextButton({
    required this.label,
    required this.onTap,
    required this.cs,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: onTap != null
                    ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                    : cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardFilledButton extends StatelessWidget {
  const _WizardFilledButton({
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────

class _WizardStepDots extends StatelessWidget {
  const _WizardStepDots({
    required this.currentStep,
    required this.totalSteps,
    required this.cs,
  });

  final int currentStep;
  final int totalSteps;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final active = i == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: active ? 16 : 5,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drum time picker
// ─────────────────────────────────────────────────────────────────────────────

Future<TimeOfDay?> showDrumTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _DrumTimePicker(initialTime: initialTime),
          ),
        ),
      ),
    ),
  );
}

class _DrumTimePicker extends StatefulWidget {
  const _DrumTimePicker({required this.initialTime});
  final TimeOfDay initialTime;
  @override
  State<_DrumTimePicker> createState() => _DrumTimePickerState();
}

class _DrumTimePickerState extends State<_DrumTimePicker> {
  late int _hour; // 1–12
  late int _minute; // 0–59
  late bool _isPm;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialTime.hour;
    _isPm = h24 >= 12;
    _hour = h24 % 12 == 0 ? 12 : h24 % 12;
    _minute = widget.initialTime.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _toTimeOfDay() {
    final h = _hour % 12 + (_isPm ? 12 : 0);
    return TimeOfDay(hour: h, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Start Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppTheme.borderColor(isDark, cs),
        ),
        // Drums
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour drum
              SizedBox(
                width: 72,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center highlight
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: _hourCtrl,
                      itemExtent: 40,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) =>
                          setState(() => _hour = i + 1),
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(12, (i) {
                          final n = i + 1;
                          final selected = n == _hour;
                          return Center(
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              // Colon separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // Minute drum
              SizedBox(
                width: 72,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: _minuteCtrl,
                      itemExtent: 40,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) => setState(() => _minute = i),
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(60, (m) {
                          final selected = m == _minute;
                          return Center(
                            child: Text(
                              m.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // AM/PM toggle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AmPmChip(
                    label: 'AM',
                    selected: !_isPm,
                    onTap: () => setState(() => _isPm = false),
                    cs: cs,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 4),
                  _AmPmChip(
                    label: 'PM',
                    selected: _isPm,
                    onTap: () => setState(() => _isPm = true),
                    cs: cs,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppTheme.borderColor(isDark, cs),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _WizardTextButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
                cs: cs,
              ),
              const SizedBox(width: 8),
              _WizardFilledButton(
                label: 'Confirm',
                onTap: () => Navigator.of(context).pop(_toTimeOfDay()),
                cs: cs,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmPmChip extends StatelessWidget {
  const _AmPmChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 32,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 1.0)
                : AppTheme.borderColor(isDark, cs),
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 0 — Day & Slot Setup
// ─────────────────────────────────────────────────────────────────────────────

const _kWizDayShort = <int, String>{
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

class _Stage0DaysSlots extends StatefulWidget {
  const _Stage0DaysSlots({
    required this.rules,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage0DaysSlots> createState() => _Stage0DaysSlotsState();
}

class _Stage0DaysSlotsState extends State<_Stage0DaysSlots> {
  late List<int> _activeDays;
  late List<TimetableSlot> _slots;
  late TimeOfDay _dayStart;

  @override
  void initState() {
    super.initState();
    _activeDays = List<int>.from(widget.rules.activeDays);
    _slots = List<TimetableSlot>.from(widget.rules.slots);
    _dayStart = widget.rules.dayStartTime;
  }

  void _toggleDay(int d) {
    setState(() {
      if (_activeDays.contains(d)) {
        if (_activeDays.length > 1) {
          _activeDays = List.from(_activeDays)..remove(d);
        }
      } else {
        _activeDays = List.from(_activeDays)
          ..add(d)
          ..sort();
      }
    });
    _notify();
  }

  void _removeSlot(int index) {
    setState(() => _slots = List<TimetableSlot>.from(_slots)..removeAt(index));
    _notify();
  }

  void _notify() {
    widget.onChanged(
      widget.rules.copyWith(
        activeDays: List<int>.from(_activeDays),
        dayStartTime: _dayStart,
        slots: List<TimetableSlot>.from(_slots),
      ),
    );
  }

  Future<void> _pickDayStart() async {
    final picked = await showDrumTimePicker(
      context: context,
      initialTime: _dayStart,
    );
    if (picked != null)
      setState(() {
        _dayStart = picked;
        _notify();
      });
  }

  Future<void> _promptAdd(SlotType type, BuildContext ctx) async {
    final label = type == SlotType.lesson ? 'Lesson' : 'Break';
    final defaultMins = type == SlotType.lesson ? 40 : 10;
    final result = await showDialog<int>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) =>
          _DurationPickerDialog(slotLabel: label, initialMinutes: defaultMins),
    );
    if (result == null || result < 5 || result > 240) return;
    setState(
      () => _slots = [
        ..._slots,
        TimetableSlot(type: type, durationMinutes: result),
      ],
    );
    _notify();
  }

  List<({int i, String range, int dur, SlotType type})> _rows() {
    final result = <({int i, String range, int dur, SlotType type})>[];
    int cursor = _dayStart.hour * 3600 + _dayStart.minute * 60;
    for (int i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      final end = cursor + s.durationMinutes * 60;
      result.add((
        i: i,
        range: '${_fmtTime(cursor)}–${_fmtTime(end)}',
        dur: s.durationMinutes,
        type: s.type,
      ));
      cursor = end;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final rows = _rows();
    final lessonCount = _slots.where((s) => s.type == SlotType.lesson).length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            // \u2500\u2500 Section A: Day selector \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                const _SectionLabel('School Days'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ToggleButtons(
                    isSelected: [
                      _activeDays.contains(1),
                      _activeDays.contains(2),
                      _activeDays.contains(3),
                      _activeDays.contains(4),
                      _activeDays.contains(5),
                      _activeDays.contains(6),
                      _activeDays.contains(7),
                    ],
                    onPressed: (i) => _toggleDay(i + 1),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    borderColor: AppTheme.borderColor(isDark, cs),
                    selectedBorderColor: cs.primary.withValues(alpha: 0.55),
                    selectedColor: cs.primary,
                    fillColor: cs.primary.withValues(
                      alpha: isDark ? 0.15 : 0.10,
                    ),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 36,
                    ),
                    children: const [
                      Text('Mon'),
                      Text('Tue'),
                      Text('Wed'),
                      Text('Thu'),
                      Text('Fri'),
                      Text('Sat'),
                      Text('Sun'),
                    ],
                  ),
                ),
              ],
            ),

            // \u2500\u2500 Section B: Day-start time \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
            InkWell(
              onTap: _pickDayStart,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              splashFactory: NoSplash.splashFactory,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.nestedBg(isDark, cs),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(color: AppTheme.borderColor(isDark, cs)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Starts at',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        _dayStart.format(context),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // \u2500\u2500 Section C: Slot list \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 0,
              children: [
                _SectionLabel(
                  'Slot Sequence',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    ),
                    child: Text(
                      '$lessonCount lesson${lessonCount == 1 ? "" : "s"}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.nestedBg(isDark, cs),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: AppTheme.borderColor(isDark, cs),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.view_timeline_outlined,
                          size: 28,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No slots yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add lesson and break slots below.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.modalBg(isDark, cs),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: AppTheme.borderColor(isDark, cs),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (_, idx) {
                        final r = rows[idx];
                        return _SlotRowTile(
                          index: r.i,
                          timeRange: r.range,
                          duration: r.dur,
                          isBreak: r.type == SlotType.breakSlot,
                          cs: cs,
                          isDark: isDark,
                          onDelete: () => _removeSlot(r.i),
                        );
                      },
                    ),
                  ),
              ],
            ),

            // \u2500\u2500 Section D: Add-slot actions \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
            Row(
              children: [
                Expanded(
                  child: _AddSlotButton(
                    label: '+ Add Lesson',
                    color: AppTheme.brandGreen,
                    onTap: () => _promptAdd(SlotType.lesson, context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AddSlotButton(
                    label: '+ Add Break',
                    color: const Color(0xFFFFA726),
                    onTap: () => _promptAdd(SlotType.breakSlot, context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
// ─────────────────────────────────────────────────────────────────────────────
// Stage 0 helpers — slot tile, add-slot button, duration dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SlotRowTile extends StatefulWidget {
  const _SlotRowTile({
    required this.index,
    required this.timeRange,
    required this.duration,
    required this.isBreak,
    required this.cs,
    required this.isDark,
    required this.onDelete,
  });

  final int index;
  final String timeRange;
  final int duration;
  final bool isBreak;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  State<_SlotRowTile> createState() => _SlotRowTileState();
}

class _SlotRowTileState extends State<_SlotRowTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color _bg() {
    final cs = widget.cs;
    final isDark = widget.isDark;
    if (_isPressed) return cs.primary.withValues(alpha: 0.13);
    if (_isHovered) return cs.primary.withValues(alpha: 0.08);
    return AppTheme.nestedBg(isDark, cs);
  }

  Color _borderColor() {
    final cs = widget.cs;
    if (_isHovered || _isPressed) return cs.primary.withValues(alpha: 0.3);
    return AppTheme.borderColor(widget.isDark, cs);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    const breakColor = Color(0xFFFFA726);
    final accentColor = widget.isBreak
        ? breakColor.withValues(alpha: 0.7)
        : AppTheme.brandGreen.withValues(alpha: 0.7);
    final accentWidth = (_isHovered || _isPressed) ? 4.0 : 3.0;

    return ScaleTransition(
      scale: _scaleAnim,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _pressCtrl.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _pressCtrl.reverse();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _pressCtrl.reverse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _bg(),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: _borderColor(), width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: accentWidth,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppTheme.kCardRadius),
                          bottomLeft: Radius.circular(AppTheme.kCardRadius),
                        ),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            // Number badge
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Text(
                                '${widget.index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Type chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isBreak
                                    ? breakColor.withValues(alpha: 0.12)
                                    : AppTheme.brandGreen.withValues(
                                        alpha: 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Text(
                                widget.isBreak ? 'Break' : 'Lesson',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isBreak
                                      ? breakColor
                                      : AppTheme.brandGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Time range
                            Expanded(
                              child: Text(
                                widget.timeRange,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            // Duration
                            Text(
                              '${widget.duration} min',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Delete button
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: Center(
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSlotButton extends StatelessWidget {
  const _AddSlotButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DurationPickerDialog extends StatefulWidget {
  const _DurationPickerDialog({
    required this.slotLabel,
    required this.initialMinutes,
  });

  final String slotLabel;
  final int initialMinutes;

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _minutes;
  late TextEditingController _ctrl;

  List<int> get _presets =>
      widget.slotLabel == 'Lesson' ? [30, 40, 45, 60] : [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _ctrl = TextEditingController(text: '$_minutes');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add ${widget.slotLabel} Slot',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderColor(isDark, cs),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    // Preset chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _presets.map((p) {
                        final sel = _minutes == p;
                        return InkWell(
                          onTap: () => setState(() {
                            _minutes = p;
                            _ctrl.text = '$p';
                          }),
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          splashFactory: NoSplash.splashFactory,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? cs.primary.withValues(
                                      alpha: isDark ? 0.15 : 0.08,
                                    )
                                  : AppTheme.nestedBg(isDark, cs),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kCardRadius,
                              ),
                              border: Border.all(
                                color: sel
                                    ? cs.primary.withValues(alpha: 0.55)
                                    : AppTheme.borderColor(isDark, cs),
                              ),
                            ),
                            child: Text(
                              '$p min',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: sel
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Custom text field
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Custom (minutes)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) setState(() => _minutes = n);
                      },
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderColor(isDark, cs),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_minutes),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: Colors.white,
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
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 1 — Teacher Constraints
// ─────────────────────────────────────────────────────────────────────────────

class _Stage1TeacherConstraints extends StatefulWidget {
  const _Stage1TeacherConstraints({
    required this.rules,
    required this.teachers,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final List<_WizardTeacher> teachers;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage1TeacherConstraints> createState() =>
      _Stage1TeacherConstraintsState();
}

class _Stage1TeacherConstraintsState extends State<_Stage1TeacherConstraints> {
  String _search = '';
  String? _expandedId;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_WizardTeacher> get _filtered {
    if (_search.isEmpty) return widget.teachers;
    final q = _search.toLowerCase();
    return widget.teachers
        .where((t) => t.name.toLowerCase().contains(q))
        .toList();
  }

  List<TeacherConstraintEntry> _constraintsFor(String id) =>
      widget.rules.teacherConstraints.where((c) => c.teacherId == id).toList();

  void _remove(TeacherConstraintEntry entry) {
    final updated = List<TeacherConstraintEntry>.from(
      widget.rules.teacherConstraints,
    )..remove(entry);
    widget.onChanged(widget.rules.copyWith(teacherConstraints: updated));
  }

  void _add(
    String teacherId,
    List<int> days,
    List<int> slotIndices,
    bool isBlock,
  ) {
    final entry = TeacherConstraintEntry(
      teacherId: teacherId,
      days: days,
      slotIndices: slotIndices,
      isBlock: isBlock,
    );
    final updated = [...widget.rules.teacherConstraints, entry];
    widget.onChanged(widget.rules.copyWith(teacherConstraints: updated));
  }

  Future<void> _showConstraintEntry(String entityId, String entityName) async {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final result = await showDialog<_ConstraintResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _ConstraintEntryForm(
                entityName: entityName,
                rules: widget.rules,
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    _add(entityId, result.days, result.slotIndices, result.isBlock);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final filtered = _filtered;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 38,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v.trim()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search teachers…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          child: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.2 : 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    widget.teachers.isEmpty
                        ? 'No teachers found for this term.'
                        : 'No results for "$_search".',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final teacher = filtered[i];
                  final constraints = _constraintsFor(teacher.id);
                  final expanded = _expandedId == teacher.id;
                  final blocks = constraints.where((c) => c.isBlock).length;
                  final requires = constraints.where((c) => !c.isBlock).length;
                  Widget? subtitleTrailing;
                  if (blocks > 0 || requires > 0) {
                    subtitleTrailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (blocks > 0)
                          _DiffBadge(label: '+$blocks', color: cs.error),
                        if (blocks > 0 && requires > 0)
                          const SizedBox(width: 4),
                        if (requires > 0)
                          _DiffBadge(
                            label: '+$requires',
                            color: AppTheme.brandGreen,
                          ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WizardEntityRow(
                      name: teacher.name,
                      subtitle: constraints.isEmpty ? 'No constraints' : '',
                      subtitleTrailing: subtitleTrailing,
                      icon: Icons.person_outline_rounded,
                      isExpanded: expanded,
                      cs: cs,
                      isDark: isDark,
                      onTap: () => setState(
                        () => _expandedId = expanded ? null : teacher.id,
                      ),
                      expandedContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (constraints.isNotEmpty) ...[
                            ...constraints.expand(
                              (c) => [
                                _ConstraintChipRow(
                                  days: c.days,
                                  slotIndices: c.slotIndices,
                                  isBlock: c.isBlock,
                                  rules: widget.rules,
                                  cs: cs,
                                  isDark: isDark,
                                  onDelete: () => _remove(c),
                                ),
                                AppTheme.tableRowDivider(isDark, cs),
                              ],
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: OutlinedButton.icon(
                              onPressed: () => _showConstraintEntry(
                                teacher.id,
                                teacher.name,
                              ),
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Add Constraint'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.primary,
                                side: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.kCardRadius,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 2 — Subject Constraints
// ─────────────────────────────────────────────────────────────────────────────

class _Stage2SubjectConstraints extends StatefulWidget {
  const _Stage2SubjectConstraints({
    required this.rules,
    required this.subjects,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final List<_WizardSubject> subjects;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage2SubjectConstraints> createState() =>
      _Stage2SubjectConstraintsState();
}

class _Stage2SubjectConstraintsState extends State<_Stage2SubjectConstraints> {
  String _search = '';
  int? _expandedId;

  List<_WizardSubject> get _filtered {
    if (_search.isEmpty) return widget.subjects;
    final q = _search.toLowerCase();
    return widget.subjects
        .where((s) => s.name.toLowerCase().contains(q))
        .toList();
  }

  List<SubjectConstraintEntry> _constraintsFor(int id) =>
      widget.rules.subjectConstraints.where((c) => c.subjectId == id).toList();

  void _remove(SubjectConstraintEntry entry) {
    final updated = List<SubjectConstraintEntry>.from(
      widget.rules.subjectConstraints,
    )..remove(entry);
    widget.onChanged(widget.rules.copyWith(subjectConstraints: updated));
  }

  void _add(
    int subjectId,
    List<int> days,
    List<int> slotIndices,
    bool isBlock,
  ) {
    final entry = SubjectConstraintEntry(
      subjectId: subjectId,
      days: days,
      slotIndices: slotIndices,
      isBlock: isBlock,
    );
    final updated = [...widget.rules.subjectConstraints, entry];
    widget.onChanged(widget.rules.copyWith(subjectConstraints: updated));
  }

  Future<void> _showConstraintEntry(String entityId, String entityName) async {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final result = await showDialog<_ConstraintResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _ConstraintEntryForm(
                entityName: entityName,
                rules: widget.rules,
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    _add(int.parse(entityId), result.days, result.slotIndices, result.isBlock);
  }

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final filtered = _filtered;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 38,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v.trim()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search subjects…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          child: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.2 : 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    widget.subjects.isEmpty
                        ? 'No subjects found for this term.'
                        : 'No results for "$_search".',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final subj = filtered[i];
                  final constraints = _constraintsFor(subj.id);
                  final expanded = _expandedId == subj.id;
                  final blocks = constraints.where((c) => c.isBlock).length;
                  final requires = constraints.where((c) => !c.isBlock).length;
                  Widget? subtitleTrailing;
                  if (blocks > 0 || requires > 0) {
                    subtitleTrailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (blocks > 0)
                          _DiffBadge(label: '+$blocks', color: cs.error),
                        if (blocks > 0 && requires > 0)
                          const SizedBox(width: 4),
                        if (requires > 0)
                          _DiffBadge(
                            label: '+$requires',
                            color: AppTheme.brandGreen,
                          ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WizardEntityRow(
                      name: subj.name,
                      subtitle: constraints.isEmpty ? 'No constraints' : '',
                      subtitleTrailing: subtitleTrailing,
                      icon: Icons.book_outlined,
                      isExpanded: expanded,
                      cs: cs,
                      isDark: isDark,
                      onTap: () => setState(
                        () => _expandedId = expanded ? null : subj.id,
                      ),
                      expandedContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (constraints.isNotEmpty) ...[
                            ...constraints.expand(
                              (c) => [
                                _ConstraintChipRow(
                                  days: c.days,
                                  slotIndices: c.slotIndices,
                                  isBlock: c.isBlock,
                                  rules: widget.rules,
                                  cs: cs,
                                  isDark: isDark,
                                  onDelete: () => _remove(c),
                                ),
                                AppTheme.tableRowDivider(isDark, cs),
                              ],
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showConstraintEntry('${subj.id}', subj.name),
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Add Constraint'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.primary,
                                side: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.kCardRadius,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — entity row with hover/press animations and inline expansion
// ─────────────────────────────────────────────────────────────────────────────

class _WizardEntityRow extends StatefulWidget {
  const _WizardEntityRow({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.cs,
    required this.isDark,
    required this.onTap,
    required this.expandedContent,
    this.subtitleTrailing,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;
  final Widget expandedContent;
  final Widget? subtitleTrailing;

  @override
  State<_WizardEntityRow> createState() => _WizardEntityRowState();
}

class _WizardEntityRowState extends State<_WizardEntityRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? cs.primary.withValues(alpha: 0.12)
        : cs.primary.withValues(alpha: 0.08);
    final pressBg = isDark
        ? cs.primary.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.13);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ─────────────────────────────────────────────
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _isPressed = true);
                _pressCtrl.forward();
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _pressCtrl.reverse();
                widget.onTap();
              },
              onTapCancel: () {
                setState(() => _isPressed = false);
                _pressCtrl.reverse();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? pressBg
                      : _isHovered
                      ? hoverBg
                      : idleBg,
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(
                    color: _isHovered || _isPressed
                        ? cs.primary.withValues(alpha: 0.25)
                        : cs.outline.withValues(alpha: isDark ? 0.08 : 0.08),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Accent bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isHovered || _isPressed ? 4 : 3,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(
                              alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(AppTheme.kCardRadius),
                              bottomLeft: Radius.circular(AppTheme.kCardRadius),
                            ),
                          ),
                        ),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Row(
                              children: [
                                // Leading icon container
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isHovered || _isPressed
                                        ? cs.primary.withValues(alpha: 0.12)
                                        : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.kChipRadius,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: 14,
                                    color: _isHovered || _isPressed
                                        ? cs.primary
                                        : cs.onSurfaceVariant.withValues(
                                            alpha: 0.55,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Name + subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.subtitle,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w400,
                                                color: cs.onSurfaceVariant
                                                    .withValues(alpha: 0.55),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (widget.subtitleTrailing !=
                                              null) ...[
                                            const SizedBox(width: 6),
                                            widget.subtitleTrailing!,
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Chevron
                                AnimatedRotation(
                                  turns: widget.isExpanded ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Expanded content ────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: AppTheme.nestedBg(isDark, cs),
                border: Border(
                  left: BorderSide(
                    color: cs.primary.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
              ),
              child: widget.expandedContent,
            ),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — compact constraint chip row
// ─────────────────────────────────────────────────────────────────────────────

class _ConstraintChipRow extends StatelessWidget {
  const _ConstraintChipRow({
    required this.days,
    required this.slotIndices,
    required this.isBlock,
    required this.rules,
    required this.cs,
    required this.isDark,
    required this.onDelete,
  });

  final List<int> days;
  final List<int> slotIndices;
  final bool isBlock;
  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeColor = isBlock ? cs.error : cs.primary;
    final allLessonSlots = rules.buildLessonSlots();

    final slotLabels = slotIndices.map((idx) {
      final match = allLessonSlots.where((s) => s.index == idx).firstOrNull;
      if (match == null) return 'Slot $idx';
      return '${_fmtTime(match.start)}–${_fmtTime(match.end)}';
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBlock
            ? cs.error.withValues(alpha: isDark ? 0.07 : 0.04)
            : cs.primary.withValues(alpha: isDark ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: typeColor, width: 3)),
      ),
      child: Row(
        children: [
          // Type label
          Text(
            isBlock ? 'Block' : 'Require',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 10),
          // Day + slot mini-chips
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...days.map(
                  (d) => _MiniChip(label: _kWizDayShort[d] ?? 'D$d', cs: cs),
                ),
                const _MiniSep(),
                ...slotLabels.map((l) => _MiniChip(label: l, cs: cs)),
              ],
            ),
          ),
          // Delete
          GestureDetector(
            onTap: onDelete,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _MiniSep extends StatelessWidget {
  const _MiniSep();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — type tab strip, diff badge
// ─────────────────────────────────────────────────────────────────────────────

class _TypeTabStrip extends StatelessWidget {
  const _TypeTabStrip({
    required this.isBlock,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });
  final bool isBlock;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      child: Row(
        children: [
          _TypeTab(
            label: 'Block',
            selected: isBlock,
            selectedColor: cs.error,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(true),
          ),
          _TypeTab(
            label: 'Require',
            selected: !isBlock,
            selectedColor: cs.primary,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.16 : 0.07,
                      ),
                      blurRadius: 5,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? selectedColor
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — constraint entry dialog
// ─────────────────────────────────────────────────────────────────────────────

typedef _ConstraintResult = ({
  List<int> days,
  List<int> slotIndices,
  bool isBlock,
});

class _ConstraintEntryForm extends StatefulWidget {
  const _ConstraintEntryForm({
    required this.entityName,
    required this.rules,
    required this.cs,
    required this.isDark,
  });

  final String entityName;
  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_ConstraintEntryForm> createState() => _ConstraintEntryFormState();
}

class _ConstraintEntryFormState extends State<_ConstraintEntryForm> {
  final Set<int> _selectedDays = {};
  final Set<int> _selectedSlots = {};
  bool _isBlock = true;

  bool get _canSubmit => _selectedDays.isNotEmpty && _selectedSlots.isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop<_ConstraintResult>((
      days: _selectedDays.toList()..sort(),
      slotIndices: _selectedSlots.toList()..sort(),
      isBlock: _isBlock,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final lessonSlots = widget.rules.buildLessonSlots();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Constraint',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.entityName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selector
                const _SectionLabel('Type'),
                const SizedBox(height: 8),
                _TypeTabStrip(
                  isBlock: _isBlock,
                  onChanged: (v) => setState(() => _isBlock = v),
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                // Days selector
                const _SectionLabel('Days'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Builder(
                    builder: (ctx) {
                      final daysToShow = widget.rules.activeDays.toList()
                        ..sort();
                      return ToggleButtons(
                        isSelected: daysToShow
                            .map((d) => _selectedDays.contains(d))
                            .toList(),
                        onPressed: (i) {
                          final d = daysToShow[i];
                          setState(() {
                            if (_selectedDays.contains(d)) {
                              _selectedDays.remove(d);
                            } else {
                              _selectedDays.add(d);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                        borderColor: AppTheme.borderColor(isDark, cs),
                        selectedBorderColor: cs.primary.withValues(alpha: 0.55),
                        selectedColor: cs.primary,
                        fillColor: cs.primary.withValues(
                          alpha: isDark ? 0.15 : 0.10,
                        ),
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
                        children: daysToShow
                            .map((d) => Text(_kWizDayShort[d] ?? 'D$d'))
                            .toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Slots selector
                const _SectionLabel('Slots'),
                const SizedBox(height: 8),
                if (lessonSlots.isEmpty)
                  Text(
                    'No lesson slots configured.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ToggleButtons(
                      isSelected: lessonSlots
                          .map((s) => _selectedSlots.contains(s.index))
                          .toList(),
                      onPressed: (i) {
                        final idx = lessonSlots[i].index;
                        setState(() {
                          if (_selectedSlots.contains(idx)) {
                            _selectedSlots.remove(idx);
                          } else {
                            _selectedSlots.add(idx);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      borderColor: AppTheme.borderColor(isDark, cs),
                      selectedBorderColor: cs.primary.withValues(alpha: 0.55),
                      selectedColor: cs.primary,
                      fillColor: cs.primary.withValues(
                        alpha: isDark ? 0.15 : 0.10,
                      ),
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      constraints: const BoxConstraints(minHeight: 36),
                      children: lessonSlots
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '${_fmtTime(s.start)}–${_fmtTime(s.end)}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _canSubmit ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _canSubmit
                          ? AppTheme.brandGreen
                          : AppTheme.brandGreen.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(
                          alpha: _canSubmit ? 1.0 : 0.6,
                        ),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Stage 3 — Remainder Slots
// ─────────────────────────────────────────────────────────────────────────────

/// Computes base + remainder lessons per week for a given (grade, stream) group.
({int base, int remainder, int totalPerWeek}) _computeRemainder({
  required TimetableRules rules,
  required int subjectCount,
}) {
  final slotsPerDay = rules.slots
      .where((s) => s.type == SlotType.lesson)
      .length;
  final total = slotsPerDay * rules.activeDays.length;
  if (subjectCount == 0) return (base: 0, remainder: 0, totalPerWeek: total);
  return (
    base: total ~/ subjectCount,
    remainder: total % subjectCount,
    totalPerWeek: total,
  );
}

class _Stage3RemainderSlots extends StatefulWidget {
  const _Stage3RemainderSlots({
    required this.rules,
    required this.assignments,
    required this.subjects,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final List<SolverAssignment> assignments;
  final List<_WizardSubject> subjects;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage3RemainderSlots> createState() => _Stage3RemainderSlotsState();
}

class _Stage3RemainderSlotsState extends State<_Stage3RemainderSlots> {
  // Expanded state keyed by grade int as string for grade rows,
  // and "${grade}_${stream ?? 'null'}" for stream rows.
  final Map<String, bool> _expandedGrades = {};
  final Map<String, bool> _expandedStreams = {};

  String _subjectName(int sid) {
    try {
      return widget.subjects.firstWhere((s) => s.id == sid).name;
    } catch (_) {
      return 'Subject $sid';
    }
  }

  void _onReorder(String streamKey, List<int> newOrder) {
    final updated = Map<String, List<int>>.from(widget.rules.remainderPriority);
    updated[streamKey] = newOrder;
    widget.onChanged(widget.rules.copyWith(remainderPriority: updated));
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final rules = widget.rules;

    // Group assignments by grade, then by stream.
    final gradeGroups = <int, Map<int?, List<SolverAssignment>>>{};
    for (final a in widget.assignments) {
      gradeGroups
          .putIfAbsent(a.grade, () => {})
          .putIfAbsent(a.stream, () => [])
          .add(a);
    }

    if (gradeGroups.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('Remainder Slots'),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No subject assignments found for this term.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedGrades = gradeGroups.keys.toList()..sort();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const _SectionLabel('Remainder Slots'),
            const SizedBox(height: 0),
            Text(
              'Subjects with remainder lessons appear first. Drag to reprioritise.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            for (final grade in sortedGrades)
              _buildGradeSection(grade, gradeGroups[grade]!, cs, isDark, rules),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSection(
    int grade,
    Map<int?, List<SolverAssignment>> streamGroups,
    ColorScheme cs,
    bool isDark,
    TimetableRules rules,
  ) {
    final gradeKey = '$grade';
    final isExpanded = _expandedGrades[gradeKey] ?? false;
    final streamCount = streamGroups.length;

    return _WizardEntityRow(
      name: 'Grade $grade',
      subtitle: '$streamCount stream${streamCount == 1 ? '' : 's'}',
      icon: Icons.school_outlined,
      isExpanded: isExpanded,
      cs: cs,
      isDark: isDark,
      onTap: () => setState(() => _expandedGrades[gradeKey] = !isExpanded),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stream
              in (streamGroups.keys.toList()
                ..sort((a, b) => (a ?? 0).compareTo(b ?? 0))))
            _buildStreamSection(
              grade,
              stream,
              streamGroups[stream]!,
              cs,
              isDark,
              rules,
            ),
        ],
      ),
    );
  }

  Widget _buildStreamSection(
    int grade,
    int? stream,
    List<SolverAssignment> streamAssignments,
    ColorScheme cs,
    bool isDark,
    TimetableRules rules,
  ) {
    final streamKey = '${grade}_${stream ?? 'null'}';
    final isExpanded = _expandedStreams[streamKey] ?? false;
    final subjects = streamAssignments.map((a) => a.subjectId).toSet().toList();
    final r = _computeRemainder(rules: rules, subjectCount: subjects.length);

    // Build priority order (from rules or default ascending).
    final savedOrder = rules.remainderPriority[streamKey];
    final orderedSubjects = savedOrder != null
        ? savedOrder.where((sid) => subjects.contains(sid)).toList()
        : (List<int>.from(subjects)..sort());
    // Append any subjects not yet in the ordered list (newly added).
    for (final sid in subjects) {
      if (!orderedSubjects.contains(sid)) orderedSubjects.add(sid);
    }

    final streamLabel = stream == null ? 'All' : 'Stream $stream';

    return _WizardEntityRow(
      name: streamLabel,
      subtitle:
          '${r.totalPerWeek} lessons · ${subjects.length} subjects'
          ' · ${r.base} base + ${r.remainder} extra',
      icon: Icons.group_outlined,
      isExpanded: isExpanded,
      cs: cs,
      isDark: isDark,
      onTap: () => setState(() => _expandedStreams[streamKey] = !isExpanded),
      expandedContent: Container(
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          border: Border(
            left: BorderSide(
              color: cs.primary.withValues(alpha: 0.2),
              width: 3,
            ),
          ),
        ),
        child: orderedSubjects.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No subjects assigned.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              )
            : ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final newOrder = List<int>.from(orderedSubjects);
                  final item = newOrder.removeAt(oldIndex);
                  newOrder.insert(newIndex, item);
                  _onReorder(streamKey, newOrder);
                },
                itemCount: orderedSubjects.length,
                itemBuilder: (ctx, i) {
                  final sid = orderedSubjects[i];
                  final isExtra = i < r.remainder;
                  return _RemainderSubjectTile(
                    key: ValueKey(sid),
                    index: i,
                    name: _subjectName(sid),
                    isExtra: isExtra,
                    cs: cs,
                    isDark: isDark,
                  );
                },
              ),
      ),
    );
  }
}

class _RemainderSubjectTile extends StatelessWidget {
  const _RemainderSubjectTile({
    super.key,
    required this.index,
    required this.name,
    required this.isExtra,
    required this.cs,
    required this.isDark,
  });

  final int index;
  final String name;
  final bool isExtra;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.nestedBg(isDark, cs),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_handle_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isExtra) _DiffBadge(label: '+1', color: AppTheme.brandGreen),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 4 — Review & Generate
// ─────────────────────────────────────────────────────────────────────────────

class _Stage3Generate extends StatefulWidget {
  const _Stage3Generate({
    required this.rules,
    required this.conflicts,
    required this.teachers,
    required this.subjects,
    required this.generating,
    required this.result,
    required this.cs,
    required this.isDark,
    required this.onConflictResolved,
    required this.onGenerate,
    required this.onComplete,
  });

  final TimetableRules rules;
  final List<_ConflictPair> conflicts;
  final List<_WizardTeacher> teachers;
  final List<_WizardSubject> subjects;
  final bool generating;
  final GeneratorResult? result;
  final ColorScheme cs;
  final bool isDark;
  final void Function(_ConflictPair, bool teacherWins) onConflictResolved;
  final Future<void> Function() onGenerate;
  final VoidCallback onComplete;

  @override
  State<_Stage3Generate> createState() => _Stage3GenerateState();
}

class _Stage3GenerateState extends State<_Stage3Generate> {
  Timer? _statusTimer;
  int _statusIndex = 0;
  static const _statusMessages = [
    'Analysing subjects…',
    'Building slot matrix…',
    'Resolving constraints…',
    'Optimising schedule…',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_Stage3Generate old) {
    super.didUpdateWidget(old);
    if (widget.generating && !old.generating) {
      _statusIndex = 0;
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (mounted) {
          setState(
            () => _statusIndex = (_statusIndex + 1) % _statusMessages.length,
          );
        }
      });
    }
    if (!widget.generating && old.generating) {
      _statusTimer?.cancel();
      _statusTimer = null;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  String _teacherName(String id) =>
      widget.teachers.where((t) => t.id == id).map((t) => t.name).firstOrNull ??
      id;

  String _subjectName(int id) =>
      widget.subjects.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
      'Subject $id';

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final hasConflicts = widget.conflicts.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (hasConflicts)
            _ConflictSection(
              conflicts: widget.conflicts,
              teacherNameOf: _teacherName,
              subjectNameOf: _subjectName,
              cs: cs,
              isDark: isDark,
              onConflictResolved: widget.onConflictResolved,
            )
          else
            _SummarySection(rules: widget.rules, cs: cs, isDark: isDark),
          _GenerateSection(
            generating: widget.generating,
            result: widget.result,
            statusMessage: _statusMessages[_statusIndex],
            cs: cs,
            isDark: isDark,
            onGenerate: widget.onGenerate,
            onComplete: widget.onComplete,
          ),
        ],
      ),
    );
  }
}

// ── Summary section ───────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.rules,
    required this.cs,
    required this.isDark,
  });

  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final slotCount = rules.buildLessonSlots().length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'Days',
          value: '${rules.activeDays.length}',
          cs: cs,
          isDark: isDark,
        ),
        _StatChip(
          label: 'Slots/Day',
          value: '$slotCount',
          cs: cs,
          isDark: isDark,
        ),
        _StatChip(
          label: 'Teacher rules',
          value: '${rules.teacherConstraints.length}',
          cs: cs,
          isDark: isDark,
        ),
        _StatChip(
          label: 'Subject rules',
          value: '${rules.subjectConstraints.length}',
          cs: cs,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Conflict section ──────────────────────────────────────────────────────────

class _ConflictSection extends StatelessWidget {
  const _ConflictSection({
    required this.conflicts,
    required this.teacherNameOf,
    required this.subjectNameOf,
    required this.cs,
    required this.isDark,
    required this.onConflictResolved,
  });

  final List<_ConflictPair> conflicts;
  final String Function(String) teacherNameOf;
  final String Function(int) subjectNameOf;
  final ColorScheme cs;
  final bool isDark;
  final void Function(_ConflictPair, bool teacherWins) onConflictResolved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          'Conflicts Detected',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              '${conflicts.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: conflicts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final cp = conflicts[i];
            return _ConflictCard(
              conflict: cp,
              teacherName: teacherNameOf(cp.teacherEntry.teacherId),
              subjectName: subjectNameOf(cp.subjectEntry.subjectId),
              cs: cs,
              isDark: isDark,
              onChanged: (v) => onConflictResolved(cp, v),
            );
          },
        ),
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.teacherName,
    required this.subjectName,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final _ConflictPair conflict;
  final String teacherName;
  final String subjectName;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<bool> onChanged; // true = teacher wins

  @override
  Widget build(BuildContext context) {
    final tc = conflict.teacherEntry;
    final sc = conflict.subjectEntry;
    final tcLabel = tc.isBlock ? 'Block' : 'Require';
    final scLabel = sc.isBlock ? 'Block' : 'Require';
    final muted = cs.onSurfaceVariant.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher row
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Teacher: $teacherName',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _ConstraintTypeBadge(label: tcLabel, isBlock: tc.isBlock, cs: cs),
            ],
          ),
          const SizedBox(height: 4),
          // Subject row
          Row(
            children: [
              Icon(Icons.book_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Subject: $subjectName',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _ConstraintTypeBadge(label: scLabel, isBlock: sc.isBlock, cs: cs),
            ],
          ),
          const SizedBox(height: 10),
          // Priority picker
          const _SectionLabel('Which takes priority?'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PriorityChip(
                  label: teacherName,
                  selected: conflict.teacherWins,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriorityChip(
                  label: subjectName,
                  selected: !conflict.teacherWins,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConstraintTypeBadge extends StatelessWidget {
  const _ConstraintTypeBadge({
    required this.label,
    required this.isBlock,
    required this.cs,
  });

  final String label;
  final bool isBlock;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isBlock
            ? cs.error.withValues(alpha: 0.10)
            : cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: isBlock ? cs.error : cs.primary,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.45)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Generate section ──────────────────────────────────────────────────────────

class _GenerateSection extends StatelessWidget {
  const _GenerateSection({
    required this.generating,
    required this.result,
    required this.statusMessage,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
    required this.onComplete,
  });

  final bool generating;
  final GeneratorResult? result;
  final String statusMessage;
  final ColorScheme cs;
  final bool isDark;
  final Future<void> Function() onGenerate;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (result == null && !generating)
          _GenerateButton(onGenerate: onGenerate)
        else if (generating)
          _GeneratingIndicator(statusMessage: statusMessage, cs: cs)
        else if (result is GeneratorSuccess)
          _SuccessPanel(
            result: result! as GeneratorSuccess,
            cs: cs,
            isDark: isDark,
            onGenerate: onGenerate,
            onComplete: onComplete,
          )
        else if (result is GeneratorFailure)
          _FailurePanel(
            result: result! as GeneratorFailure,
            cs: cs,
            isDark: isDark,
            onGenerate: onGenerate,
          ),
      ],
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onGenerate});

  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onGenerate,
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text('Generate Timetable'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.brandGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator({required this.statusMessage, required this.cs});

  final String statusMessage;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            statusMessage,
            key: ValueKey(statusMessage),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.result,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
    required this.onComplete,
  });

  final GeneratorSuccess result;
  final ColorScheme cs;
  final bool isDark;
  final Future<void> Function() onGenerate;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final dayCount = result.slots.map((s) => s.day).toSet().length;
    final ms = result.elapsed.inMilliseconds;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.brandGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: AppTheme.brandGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Timetable ready!',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.slots.length} slots across $dayCount days  ·  ${ms}ms',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onGenerate,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                child: const Text('Regenerate'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onComplete,
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
                child: const Text('Apply Timetable →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({
    required this.result,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
  });

  final GeneratorFailure result;
  final ColorScheme cs;
  final bool isDark;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Text(
                'Could not generate',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.reason,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onGenerate,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Try Again'),
            ),
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
