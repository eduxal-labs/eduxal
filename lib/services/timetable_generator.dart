import 'dart:math';

import '../database/daos/timetable_dao.dart' show SolverAssignment;
import '../database/tables/enums.dart';
import '../models/timetable_rules.dart';

// ── Public result types ───────────────────────────────────────────────────────

/// One solved timetable slot produced by the generator.
///
/// Renamed from the legacy `TimetableSlot` to avoid collision with the
/// [TimetableSlot] model class in `models/timetable_rules.dart`.
class GeneratedSlot {
  const GeneratedSlot({
    required this.school,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.subjectId,
    required this.teacherUserId,
    required this.day,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String school;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int subjectId;
  final String teacherUserId;
  final DayOfWeek day;
  final int startSeconds;
  final int endSeconds;
}

/// Outcome of a generation run.
sealed class GeneratorResult {}

final class GeneratorSuccess extends GeneratorResult {
  GeneratorSuccess({
    required this.slots,
    required this.softScore,
    required this.iterations,
    required this.elapsed,
  });

  /// The fully solved timetable — one entry per scheduled lesson instance.
  final List<GeneratedSlot> slots;

  /// Soft constraint penalty score. Lower is better; 0 = optimal.
  final int softScore;

  /// Total backtrack iterations across all restarts.
  final int iterations;

  /// Wall-clock time for the generation run.
  final Duration elapsed;
}

final class GeneratorFailure extends GeneratorResult {
  GeneratorFailure({required this.reason, required this.conflicts});

  /// Human-readable explanation for the user.
  final String reason;

  /// Specific unsatisfiable constraints detected during validation (may be empty).
  final List<String> conflicts;
}

// ── Private helper types ──────────────────────────────────────────────────────

/// One CSP variable — a single lesson occurrence that needs exactly one
/// (day, time) slot assignment per week.
///
/// A subject with [lessonsPerWeek] = 4 produces four [_Variable] instances
/// with [instanceIndex] 0–3, all sharing the same (school, year, term, grade,
/// stream, subjectId, teacherUserId) but with distinct identities so the
/// solver treats them as independent placement problems.
class _Variable {
  const _Variable({
    required this.school,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.subjectId,
    required this.teacherUserId,
    this.instanceIndex = 0,
  });

  final String school;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int subjectId;
  final String teacherUserId;

  /// Distinguishes multiple weekly instances of the same subject for the same
  /// class. Index 0 through (lessonsPerWeek - 1).
  final int instanceIndex;

  @override
  bool operator ==(Object other) =>
      other is _Variable &&
      school == other.school &&
      year == other.year &&
      term == other.term &&
      grade == other.grade &&
      stream == other.stream &&
      subjectId == other.subjectId &&
      instanceIndex == other.instanceIndex;

  @override
  int get hashCode =>
      Object.hash(school, year, term, grade, stream, subjectId, instanceIndex);
}

/// One candidate (day, time) pair in a variable's domain.
///
/// [slotIndexInRules] is the 0-based position of this lesson slot in the
/// overall [TimetableRules.slots] list (including breaks). It is used when
/// matching slot-index-based teacher and subject constraints.
class _Slot {
  const _Slot({
    required this.day,
    required this.startSeconds,
    required this.endSeconds,
    required this.slotIndexInRules,
  });

  final DayOfWeek day;
  final int startSeconds;
  final int endSeconds;

  /// 0-based index of this slot in [TimetableRules.slots] (all slot types).
  final int slotIndexInRules;

  @override
  bool operator ==(Object other) =>
      other is _Slot && day == other.day && startSeconds == other.startSeconds;

  @override
  int get hashCode => Object.hash(day, startSeconds);
}

/// One undo record produced during in-place domain propagation.
///
/// When [_propagateInPlace] removes slots from a variable's domain, it
/// records those removals here.  On backtrack, [_solve] iterates over the
/// trail and adds the removed slots back, restoring the domain to the state
/// it was in before the propagation call.
typedef _TrailEntry = ({_Variable variable, List<_Slot> removed});

// ── DayOfWeek ↔ weekday-index helpers ────────────────────────────────────────
//
// [TimetableRules] stores active days and constraint days as weekday INDICES
// (1 = Monday … 7 = Sunday).  The generator's [_Slot] and [_Variable] use
// [DayOfWeek] (an enum with sunday = 0, monday = 1, …, saturday = 6).

/// Convert a weekday index (1=Mon … 7=Sun) to its [DayOfWeek] enum value.
DayOfWeek _weekdayIndexToDay(int index) {
  // DayOfWeek.values: [sunday(0), monday(1), …, saturday(6)]
  // weekday index 7 = Sunday → DayOfWeek.sunday (enum index 0).
  if (index == 7) return DayOfWeek.sunday;
  return DayOfWeek.values[index]; // 1→monday … 6→saturday
}

// ── TimetableGenerator ────────────────────────────────────────────────────────

/// Pure-Dart CSP backtracking solver for weekly timetable generation.
///
/// No Flutter dependencies — safe to run inside `compute()` on a background
/// isolate. All input data is provided via the constructor; no DAO calls are
/// made inside the generator.
///
/// ### Algorithm (v2 — undo-trail)
///
/// The v1 solver used **copy-on-write domain management**: a full deep-copy of
/// all N domain lists was performed before every propagation attempt.  For a
/// problem with 150 variables × 50 domain entries this was ~7 500 slot copies
/// per consistent candidate, yielding billions of copies over a full run and a
/// wall-clock time of >7 minutes for a single grade.
///
/// v2 eliminates the bottleneck with four coordinated improvements:
///
/// **1. Undo-trail backtracking**
/// Domains are modified *in place*.  Every slot removal performed by
/// [_propagateInPlace] is recorded as a [_TrailEntry].  On backtrack, the
/// trail is replayed in reverse to restore removed slots.  Copy cost drops
/// from O(N × D) per candidate to O(k) where k is the number of slots
/// actually pruned (typically ≪ N × D).
///
/// **2. O(1) consistency lookups**
/// Five `HashMap` index tables ([_teacherSlotCount], [_classSlotCount],
/// [_teacherDayCount], [_classDayCount], [_classSubjectDayCount]) replace the
/// O(assignment_size) linear scan that the old `_isConsistent` performed at
/// every candidate.  Tables are updated by [_placeVariable] /
/// [_unplaceVariable] and cleared at the start of each restart.
///
/// **3. No-doubles propagation (Layer 3)**
/// When `allowDoubles = false`, placing subject X on day D immediately removes
/// ALL day-D slots from every other unassigned instance of subject X for the
/// same class.  In v1 this constraint was enforced lazily by `_isConsistent`
/// only *after* wasted backtrack nodes — the key reason propagation never
/// caught any dead-ends (propagFails was always 0).  With Layer 3 the solver
/// prunes the no-doubles constraint eagerly, dramatically shrinking the search
/// space.
///
/// **4. O(n) MRV selection + in-place unassigned management**
/// A linear scan for the minimum-domain variable replaces the O(n log n)
/// `sort()` that ran at every recursive invocation.  The chosen variable is
/// swap-removed from the unassigned list (O(1)) and restored on backtrack,
/// eliminating the per-node `List.from()` allocation.
///
/// ### Diagnostic logging
///
/// All `print()` lines are prefixed with `[TimetableGen +Xs]` and are
/// visible in the Flutter debug console and in the isolate stdout in profile
/// builds.  Logging covers problem scale, per-restart domain statistics,
/// milestone snapshots every [_kLogEveryNIterations] nodes, and a final
/// success/failure summary.
class TimetableGenerator {
  TimetableGenerator({
    required this.assignments,
    required this.rules,
    this.maxRestarts = 8,
    Random? random,
  }) : _random = random ?? Random();

  /// Subject-teacher assignments fetched from `TimetableDao.getSubjectTeachersForTerm()`.
  final List<SolverAssignment> assignments;

  /// School-day configuration and constraint rules.
  final TimetableRules rules;

  /// How many times to restart the search with freshly shuffled domain order
  /// before declaring failure. Each restart is fully independent.
  final int maxRestarts;

  final Random _random;

  // ── Per-restart state ─────────────────────────────────────────────────────

  int _iterations = 0;

  // ── Diagnostic counters (reset per restart) ───────────────────────────────

  int _consistencyChecks = 0;
  int _consistencyPasses = 0;
  int _propagationCalls = 0;
  int _propagationFails = 0;

  /// Total number of individual [_Slot] entries restored from the undo trail
  /// across all backtrack steps in the current restart.
  int _trailEntriesTotal = 0;

  /// How many times the undo trail was replayed (one per backtrack step that
  /// had at least one propagation removal to undo).
  int _trailRestores = 0;

  /// Global stopwatch started at the very beginning of [generate()].
  late final Stopwatch _globalSw;

  /// Backtrack-node interval between milestone progress log lines.
  static const int _kLogEveryNIterations = 5000;

  /// Cached count of lesson-only slots per day, derived from [rules].
  late final int _lessonSlotsPerDay = rules.slots
      .where((s) => s.type == SlotType.lesson)
      .length;

  /// Effective daily lesson cap for teachers — the minimum of the physical
  /// slot count and the configured [TimetableRules.maxLessonsPerDayTeacher].
  ///
  /// Used in [_isConsistentFast] and [_propagateInPlace] instead of the raw
  /// [_lessonSlotsPerDay] so that the user-configured cap is actually
  /// enforced during search.
  late final int _effectiveTeacherDayCap = min(
    _lessonSlotsPerDay,
    rules.maxLessonsPerDayTeacher,
  );

  /// Effective daily lesson cap for classes.
  ///
  /// Currently set to [_lessonSlotsPerDay] because [_computeLessonsPerWeek]
  /// assumes 100% slot utilisation (totalLessons = slotsPerDay × activeDays).
  /// Enforcing [TimetableRules.maxLessonsPerDayClass] as a hard constraint
  /// would require reducing total weekly lessons to
  /// `maxLessonsPerDayClass × activeDays`, which is a separate feature.
  late final int _effectiveClassDayCap = _lessonSlotsPerDay;

  // ── O(1) consistency lookup tables ───────────────────────────────────────
  //
  // All five tables are keyed by Dart record types (structural equality +
  // hashCode guaranteed in Dart 3).  They are updated in-place by
  // [_placeVariable] / [_unplaceVariable] and fully cleared by [_resetState]
  // at the start of every restart.

  /// (teacherId, day, startSeconds) → number of assignments occupying this slot.
  final Map<(String, DayOfWeek, int), int> _teacherSlotCount = {};

  /// (grade, stream, day, startSeconds) → number of assignments occupying this slot.
  final Map<(int, int, DayOfWeek, int), int> _classSlotCount = {};

  /// (teacherId, day) → total lessons assigned on this day.
  final Map<(String, DayOfWeek), int> _teacherDayCount = {};

  /// (grade, stream, day) → total lessons assigned on this day.
  final Map<(int, int, DayOfWeek), int> _classDayCount = {};

  /// (grade, stream, day, subjectId) → number of instances of this subject
  /// already placed on this day.  Used for the no-doubles constraint.
  final Map<(int, int, DayOfWeek, int), int> _classSubjectDayCount = {};

  // ── Day pre-assignment (allowDoubles=false only) ──────────────────────────

  /// Pre-computed forced day per variable.
  ///
  /// Populated by [_computeDayAssignments] at the start of every restart when
  /// [TimetableRules.allowDoubles] is `false`.  [_buildDomains] reads this
  /// map and restricts each variable's candidate slots to the single forced
  /// day, reducing domain size from (lessonSlotsPerDay × activeDays) to just
  /// lessonSlotsPerDay — a 5× reduction for a standard 5-day week.
  ///
  /// Consequence: the no-doubles constraint is satisfied by construction, so
  /// [_propagateInPlace] Layer 3 and [_isConsistentFast] check #5 become
  /// confirmed no-ops for the entire search.  They are kept for correctness
  /// in case [allowDoubles] is `true`, but they will never fire when this map
  /// is populated.
  final Map<_Variable, DayOfWeek> _dayForVariable = {};

  // ── Logging helpers ───────────────────────────────────────────────────────

  void _log(String msg) {
    final ms = _globalSw.elapsedMilliseconds;
    final secs = (ms / 1000).toStringAsFixed(2);
    // ignore: avoid_print
    print('[TimetableGen +${secs}s] $msg');
  }

  String _domainSummary(Map<_Variable, List<_Slot>> domains) {
    if (domains.isEmpty) return 'no domains';
    final sizes = domains.values.map((d) => d.length).toList()..sort();
    final total = sizes.fold(0, (s, e) => s + e);
    final min = sizes.first;
    final max = sizes.last;
    final avg = (total / sizes.length).toStringAsFixed(1);
    final zeros = sizes.where((s) => s == 0).length;
    return 'vars=${sizes.length}  '
        'domainMin=$min  domainMax=$max  domainAvg=$avg  '
        'totalSlotEntries=$total  emptyDomains=$zeros';
  }

  /// Reset all per-restart state: iteration counter, diagnostic counters, and
  /// all five O(1) lookup tables.
  void _resetState() {
    _iterations = 0;
    _consistencyChecks = 0;
    _consistencyPasses = 0;
    _propagationCalls = 0;
    _propagationFails = 0;
    _trailEntriesTotal = 0;
    _trailRestores = 0;
    _teacherSlotCount.clear();
    _classSlotCount.clear();
    _teacherDayCount.clear();
    _classDayCount.clear();
    _classSubjectDayCount.clear();
    _dayForVariable.clear();
  }

  void _logCounters() {
    final passRate = _consistencyChecks == 0
        ? 0.0
        : _consistencyPasses / _consistencyChecks * 100;
    final failRate = _propagationCalls == 0
        ? 0.0
        : _propagationFails / _propagationCalls * 100;
    final avgTrail = _trailRestores == 0
        ? 0.0
        : _trailEntriesTotal / _trailRestores;
    _log(
      'counters: '
      'nodes=$_iterations  '
      'consistencyChecks=$_consistencyChecks (pass=${passRate.toStringAsFixed(1)}%)  '
      'propagCalls=$_propagationCalls (fail=${failRate.toStringAsFixed(1)}%)  '
      'trailRestores=$_trailRestores (avg=${avgTrail.toStringAsFixed(1)} entries/restore)',
    );
  }

  // ── Teacher availability helper ───────────────────────────────────────────

  /// Pre-computes per-teacher availability: which active days are available
  /// and how many lesson slots are available on each day, considering teacher
  /// constraint rules (block / require).
  ///
  /// Returns a map: `teacherId → { dayIndex → availableSlotCount }`.
  /// Days with zero available slots are **omitted** from the inner map, so
  /// `result[t]!.length` gives the number of days the teacher can work.
  Map<String, Map<int, int>> _computeTeacherAvailability(
    List<({int index, int start, int end})> lessonSlots,
  ) {
    final result = <String, Map<int, int>>{};
    final teacherIds = assignments.map((a) => a.teacherUserId).toSet();

    for (final teacherId in teacherIds) {
      final daySlots = <int, int>{};
      for (final dayIndex in rules.activeDays) {
        int count = 0;
        for (final ls in lessonSlots) {
          if (_isSlotAllowedForTeacher(
            teacherId: teacherId,
            slotIndex: ls.index,
            dayIndex: dayIndex,
          )) {
            count++;
          }
        }
        if (count > 0) daySlots[dayIndex] = count;
      }
      result[teacherId] = daySlots;
    }
    return result;
  }

  /// Computes the **effective capacity** of a teacher: the total number of
  /// lessons they can be assigned across all available days, respecting both
  /// blocking constraints and the [_effectiveTeacherDayCap].
  int _teacherEffectiveCapacity(Map<int, int> daySlots) {
    int cap = 0;
    for (final slotCount in daySlots.values) {
      cap += min(slotCount, _effectiveTeacherDayCap);
    }
    return cap;
  }

  // ── Day pre-assignment ────────────────────────────────────────────────────

  /// Pre-assign one specific active day to every lesson instance when
  /// [TimetableRules.allowDoubles] is `false`.
  ///
  /// **Why this helps:** the v2 solver's domains are still 50 entries each
  /// (10 slots/day × 5 days).  Layer 3 propagation removes one full day's
  /// slots (10 entries) from sibling instances of the same subject, but only
  /// for the 3-4 instances in the same (grade, stream, subject) group.  The
  /// remaining ~100 unrelated variables keep full 50-slot domains, making the
  /// search tree enormously wide.  By pre-committing to a day before search,
  /// every domain shrinks to at most [lessonSlotsPerDay] slots (10 here), the
  /// no-doubles constraint is satisfied structurally, and the solver only
  /// needs to find a valid *slot* within each pre-assigned day.
  ///
  /// **v3 algorithm — constraint-aware with MRV ordering:**
  ///
  /// 1. Pre-compute which active days each teacher is actually available on
  ///    (i.e. has at least one non-blocked lesson slot).
  /// 2. Group variables by (grade, stream, subject).  Sort groups by
  ///    **Most-Constrained-First** (MRV): groups whose teacher has fewer
  ///    available days are assigned first, getting priority on scarce days.
  ///    Random tie-breaking ensures restart diversity.
  /// 3. For each group, consider only the teacher's available days as
  ///    candidates.  Sort candidates by combined load (classLoad × 2 +
  ///    teacherLoad) so least-loaded days are preferred.
  /// 4. Assign instances to distinct candidate days.  If the group has more
  ///    instances than candidate days (shouldn't happen after validation, but
  ///    as a safety net), excess instances are left without a forced day —
  ///    they'll get full domains and the solver handles the doubles.
  void _computeDayAssignments(List<_Variable> variables) {
    _dayForVariable.clear();

    // Pre-compute available days per teacher.
    final lessonSlots = rules.buildLessonSlots();
    final teacherAvailability = _computeTeacherAvailability(lessonSlots);

    // Per-class per-day instance count: (grade, stream, dayIndex) → count.
    final classLoad = <(int, int, int), int>{};

    // Per-teacher per-day lesson count: (teacherId, dayIndex) → count.
    final teacherLoad = <(String, int), int>{};

    // Group by (grade, stream, subject).
    final groups = <(int, int, int), List<_Variable>>{};
    for (final v in variables) {
      groups.putIfAbsent((v.grade, v.stream, v.subjectId), () => []).add(v);
    }

    // Shuffle first for random tie-breaking across restarts, then sort by
    // MRV — groups with fewer available teacher days get assigned first.
    final entries = groups.entries.toList()..shuffle(_random);
    entries.sort((a, b) {
      final teacherA = a.value.first.teacherUserId;
      final teacherB = b.value.first.teacherUserId;
      final daysA = teacherAvailability[teacherA]?.length ?? 0;
      final daysB = teacherAvailability[teacherB]?.length ?? 0;
      return daysA.compareTo(daysB); // fewer available days → higher priority
    });

    for (final entry in entries) {
      final (grade, stream, _) = entry.key;
      final vars = entry.value;
      // Stable ordering within the group.
      vars.sort((a, b) => a.instanceIndex.compareTo(b.instanceIndex));
      final teacherId = vars.first.teacherUserId;

      // Use only days where this teacher has at least one available slot.
      final teacherDays = teacherAvailability[teacherId] ?? {};
      final candidateDays = rules.activeDays
          .where((d) => teacherDays.containsKey(d))
          .toList();

      if (candidateDays.isEmpty) {
        // Teacher has no available days at all — skip pre-assignment.
        // Validation will catch this as an error.
        continue;
      }

      // Shuffle for random tie-breaking, then sort by combined load.
      candidateDays.shuffle(_random);
      candidateDays.sort((a, b) {
        final scoreA =
            (classLoad[(grade, stream, a)] ?? 0) * 2 +
            (teacherLoad[(teacherId, a)] ?? 0);
        final scoreB =
            (classLoad[(grade, stream, b)] ?? 0) * 2 +
            (teacherLoad[(teacherId, b)] ?? 0);
        return scoreA.compareTo(scoreB);
      });

      // Assign each instance to a distinct least-loaded available day.
      for (int i = 0; i < vars.length; i++) {
        if (i >= candidateDays.length) {
          // More instances than available days — leave remaining variables
          // without a forced day so _buildDomains gives them full domains.
          // This is a safety fallback; _computeLessonsPerWeek should already
          // have capped instances to available days when allowDoubles=false.
          _log(
            '  ⚠️  group (grade=$grade, stream=$stream, '
            'subject=${vars[i].subjectId}): instance ${vars[i].instanceIndex} '
            'has no available day (teacher $teacherId has '
            '${candidateDays.length} available days but needs '
            '${vars.length} distinct days)',
          );
          break;
        }
        final dayIndex = candidateDays[i];
        _dayForVariable[vars[i]] = _weekdayIndexToDay(dayIndex);
        classLoad[(grade, stream, dayIndex)] =
            (classLoad[(grade, stream, dayIndex)] ?? 0) + 1;
        teacherLoad[(teacherId, dayIndex)] =
            (teacherLoad[(teacherId, dayIndex)] ?? 0) + 1;
      }
    }

    // Log load distribution so the operator can verify balance.
    final cLoads = classLoad.values.toList()..sort();
    final tLoads = teacherLoad.values.toList()..sort();
    if (cLoads.isNotEmpty) {
      final cAvg = cLoads.fold(0, (s, e) => s + e) / cLoads.length;
      final tAvg = tLoads.fold(0, (s, e) => s + e) / tLoads.length;
      _log(
        '  day pre-assignment: '
        'classDay loads min=${cLoads.first} max=${cLoads.last} '
        'avg=${cAvg.toStringAsFixed(1)}  '
        'teacherDay loads min=${tLoads.first} max=${tLoads.last} '
        'avg=${tAvg.toStringAsFixed(1)}',
      );
    }
  }

  // ── Entry point ─────────────────────────────────────────────────────────────

  /// Run the solver synchronously and return a [GeneratorResult].
  ///
  /// Phases:
  /// 1. **Validation** — reject obviously impossible inputs early.
  /// 2. **Variable expansion** — create N instances per assignment.
  /// 3. **Domain construction + backtracking** — O(1) MRV heuristic,
  ///    undo-trail forward-checking with no-doubles propagation,
  ///    up to [maxRestarts] restarts.
  /// 4. **Soft scoring** — penalise teacher gaps and uneven distributions.
  GeneratorResult generate() {
    final stopwatch = Stopwatch()..start();
    _globalSw = stopwatch;

    _log('─── generate() START ───────────────────────────────────────────');
    _log(
      'input: assignments=${assignments.length}  '
      'activeDays=${rules.activeDays.length}  '
      'slotsInDay=${rules.slots.length}  '
      'lessonSlotsPerDay=$_lessonSlotsPerDay  '
      'maxRestarts=$maxRestarts  '
      'allowDoubles=${rules.allowDoubles}  '
      'teacherConstraints=${rules.teacherConstraints.length}  '
      'subjectConstraints=${rules.subjectConstraints.length}',
    );

    // ── Phase 0 — Validate ───────────────────────────────────────────────────
    _log('Phase 0: validation …');
    final conflicts = _validate();
    if (conflicts.isNotEmpty) {
      _log('Phase 0: FAILED — ${conflicts.first}');
      return GeneratorFailure(reason: conflicts.first, conflicts: conflicts);
    }
    _log('Phase 0: OK  [${stopwatch.elapsedMilliseconds}ms]');

    final lessonSlots = rules.buildLessonSlots();
    if (lessonSlots.isEmpty) {
      _log('Phase 0: FAILED — no lesson slots');
      return GeneratorFailure(
        reason:
            'No lesson slots available. Add at least one lesson slot in the '
            'slot builder (Stage 1).',
        conflicts: [],
      );
    }
    _log(
      'lessonSlots: count=${lessonSlots.length}  '
      'first=${lessonSlots.first.start}s–${lessonSlots.first.end}s  '
      'last=${lessonSlots.last.start}s–${lessonSlots.last.end}s',
    );

    // ── Phase 1 — Expand assignments into variables ──────────────────────────
    _log('Phase 1: expanding assignments into variables …');
    final t1 = stopwatch.elapsedMilliseconds;

    final lessonsMap = _computeLessonsPerWeek();
    final variables = <_Variable>[];
    for (final a in assignments) {
      final n = lessonsMap[(a.grade, a.stream, a.subjectId)] ?? 1;
      for (int i = 0; i < n; i++) {
        variables.add(
          _Variable(
            school: a.school,
            year: a.year,
            term: a.term,
            grade: a.grade,
            stream: a.stream,
            subjectId: a.subjectId,
            teacherUserId: a.teacherUserId,
            instanceIndex: i,
          ),
        );
      }
    }

    // Log per-(grade, stream) breakdown.
    final streamGroups = <(int, int), int>{};
    for (final v in variables) {
      streamGroups[(v.grade, v.stream)] =
          (streamGroups[(v.grade, v.stream)] ?? 0) + 1;
    }
    _log(
      'Phase 1: ${variables.length} variables total  '
      '[${stopwatch.elapsedMilliseconds - t1}ms]',
    );
    for (final e in streamGroups.entries) {
      _log(
        '  stream (grade=${e.key.$1}, stream=${e.key.$2}): '
        '${e.value} lesson variables',
      );
    }
    final uniqueTeachers = variables.map((v) => v.teacherUserId).toSet();
    _log('  unique teachers: ${uniqueTeachers.length}');
    final lpwValues = lessonsMap.values.toList()..sort();
    if (lpwValues.isNotEmpty) {
      final lpwMin = lpwValues.first;
      final lpwMax = lpwValues.last;
      final lpwAvg = (lpwValues.fold(0, (s, e) => s + e) / lpwValues.length)
          .toStringAsFixed(1);
      _log(
        '  lessonsPerWeek per subject: min=$lpwMin  max=$lpwMax  avg=$lpwAvg  '
        '(subject-stream pairs: ${lpwValues.length})',
      );
    }

    // ── Adaptive restart budget ──────────────────────────────────────────────
    // Scale restart count based on problem tightness.  When teachers have
    // blocked days, the day pre-assignment has less flexibility and benefits
    // from additional random restarts to explore different orderings.
    final teacherAvailForRestarts = _computeTeacherAvailability(lessonSlots);
    final hasConstrainedTeacher = teacherAvailForRestarts.values.any(
      (daySlots) => daySlots.length < rules.activeDays.length,
    );
    final effectiveMaxRestarts = hasConstrainedTeacher
        ? max(maxRestarts, 20)
        : maxRestarts;
    _log(
      '  effectiveMaxRestarts=$effectiveMaxRestarts '
      '(constrained=${hasConstrainedTeacher ? "yes" : "no"})',
    );

    // ── Phase 2 + 3 — Restarts ───────────────────────────────────────────────
    int totalIterations = 0;

    for (int restart = 0; restart < effectiveMaxRestarts; restart++) {
      _resetState();

      // Pre-assign days before building domains when doubles are disabled.
      // This shrinks every variable's domain from (slotsPerDay × activeDays)
      // to just slotsPerDay, satisfying no-doubles by construction.
      if (!rules.allowDoubles) {
        _computeDayAssignments(variables);
      }

      final restartStart = stopwatch.elapsedMilliseconds;

      _log(
        '─── Restart ${restart + 1}/$effectiveMaxRestarts  '
        '[+${restartStart}ms] ────────────────────────',
      );

      final domains = _buildDomains(variables, lessonSlots);
      _log('  domains built: ${_domainSummary(domains)}');

      // Warn if any variable already has an empty domain before search starts —
      // this indicates a constraint that makes scheduling structurally impossible.
      final emptyDomainVars = domains.entries
          .where((e) => e.value.isEmpty)
          .map((e) => e.key)
          .toList();
      if (emptyDomainVars.isNotEmpty) {
        _log(
          '  ⚠️  ${emptyDomainVars.length} variable(s) have EMPTY domains '
          'before search — constraints may be unsatisfiable.',
        );
        for (final v in emptyDomainVars.take(5)) {
          _log(
            '     → grade=${v.grade}  stream=${v.stream}  '
            'subject=${v.subjectId}  teacher=${v.teacherUserId}  '
            'instance=${v.instanceIndex}',
          );
        }
        if (emptyDomainVars.length > 5) {
          _log('     … and ${emptyDomainVars.length - 5} more.');
        }
      }

      final totalDomainEntries = domains.values.fold(0, (s, e) => s + e.length);
      _log(
        '  initial total domain entries: $totalDomainEntries  '
        '(undo-trail: no copy overhead — O(slots_actually_pruned) per step)',
      );

      for (final domain in domains.values) {
        domain.shuffle(_random);
      }

      _log(
        '  starting search  '
        '[undo-trail · O(1) consistency'
        '${!rules.allowDoubles ? " · day-preassign ($_lessonSlotsPerDay-slot domains)" : " · no-doubles propagation"}] …',
      );

      final unassigned = List<_Variable>.from(variables);
      final assignment = <_Variable, _Slot>{};
      final result = _solve(unassigned, assignment, domains);

      totalIterations += _iterations;

      final restartElapsed = stopwatch.elapsedMilliseconds - restartStart;
      _log(
        '─── Restart ${restart + 1} END: '
        '${result != null ? "SOLUTION FOUND" : "no solution"}  '
        'elapsed=${restartElapsed}ms  nodes=$_iterations',
      );
      _logCounters();

      if (result != null) {
        // ── Phase 4 — Soft score ─────────────────────────────────────────────
        _log('Phase 4: computing soft score …');
        final t4 = stopwatch.elapsedMilliseconds;
        final score = _softScore(result, lessonSlots);
        _log(
          'Phase 4: softScore=$score  [${stopwatch.elapsedMilliseconds - t4}ms]',
        );

        final timetableSlots = result.entries
            .map(
              (e) => GeneratedSlot(
                school: e.key.school,
                year: e.key.year,
                term: e.key.term,
                grade: e.key.grade,
                stream: e.key.stream,
                subjectId: e.key.subjectId,
                teacherUserId: e.key.teacherUserId,
                day: e.value.day,
                startSeconds: e.value.startSeconds,
                endSeconds: e.value.endSeconds,
              ),
            )
            .toList();

        stopwatch.stop();
        _log(
          '─── generate() SUCCESS ─────────────────────────────────────────',
        );
        _log(
          'total: slots=${timetableSlots.length}  '
          'totalNodes=$totalIterations  '
          'softScore=$score  '
          'elapsed=${stopwatch.elapsed.inMilliseconds}ms',
        );
        return GeneratorSuccess(
          slots: timetableSlots,
          softScore: score,
          iterations: totalIterations,
          elapsed: stopwatch.elapsed,
        );
      }
    }

    stopwatch.stop();
    _log('─── generate() FAILURE ─────────────────────────────────────────');
    _log(
      'exhausted $effectiveMaxRestarts restarts  '
      'totalNodes=$totalIterations  '
      'elapsed=${stopwatch.elapsed.inMilliseconds}ms',
    );
    return GeneratorFailure(
      reason:
          'Could not find a valid timetable after $effectiveMaxRestarts '
          'attempts. Try relaxing constraints: fewer lessons per week, more '
          'active days, more lesson slots in the day, a higher daily lesson '
          'cap, or remove some teacher/subject constraint rules.',
      conflicts: [],
    );
  }

  // ── Lessons-per-week computation ─────────────────────────────────────────

  /// Compute lessons-per-week for every (grade, stream, subjectId) triple.
  ///
  /// 1. Counts lesson slots per day from [TimetableRules.slots].
  /// 2. Multiplies by active-day count to get total weekly lessons.
  /// 3. For each (grade, stream) group of assignments, divides total weekly
  ///    lessons by subject count to get the base, computes the remainder, and
  ///    applies the priority order from [TimetableRules.remainderPriority].
  /// 4. **Constraint-aware remainder** (v3): when `allowDoubles=false`, the
  ///    remainder boost (+1 lesson) is only given to subjects whose teacher
  ///    has enough available days for `base + 1` distinct instances.  If the
  ///    teacher is blocked to fewer days than `base + 1`, the boost is
  ///    redistributed to the next eligible subject in priority order.
  Map<(int, int, int), int> _computeLessonsPerWeek() {
    final lessonSlotsPerDay = rules.slots
        .where((s) => s.type == SlotType.lesson)
        .length;
    final totalPerWeek = lessonSlotsPerDay * rules.activeDays.length;

    // Group assignments by (grade, stream).
    final groups = <(int, int), List<SolverAssignment>>{};
    for (final a in assignments) {
      groups.putIfAbsent((a.grade, a.stream), () => []).add(a);
    }

    // Pre-compute teacher availability for constraint-aware remainder
    // allocation.  When allowDoubles=false, subjects whose teacher has fewer
    // available days than (base+1) cannot receive the remainder boost.
    Map<String, Map<int, int>>? teacherAvail;
    if (!rules.allowDoubles) {
      teacherAvail = _computeTeacherAvailability(rules.buildLessonSlots());
    }

    // Subject → teacher lookup.
    final subjectTeacherMap = <(int, int, int), String>{};
    for (final a in assignments) {
      subjectTeacherMap[(a.grade, a.stream, a.subjectId)] = a.teacherUserId;
    }

    final result = <(int, int, int), int>{};
    for (final entry in groups.entries) {
      final (grade, stream) = entry.key;
      final subjects = entry.value.map((a) => a.subjectId).toSet().toList();
      if (subjects.isEmpty) continue;

      final base = totalPerWeek ~/ subjects.length;
      final remainder = totalPerWeek % subjects.length;

      // Determine priority order for this (grade, stream).
      final priorityKey = '${grade}_$stream';
      final priorityOrder =
          rules.remainderPriority[priorityKey] ??
          (List<int>.from(subjects)..sort());

      // Build the ranked list (only subjects in this stream, in priority order).
      final priorityRanked = priorityOrder
          .where((id) => subjects.contains(id))
          .toList();
      // Append any subjects not yet in the ranked list (newly added subjects).
      for (final sid in subjects) {
        if (!priorityRanked.contains(sid)) priorityRanked.add(sid);
      }

      // Determine which subjects receive the remainder boost (+1 lesson).
      final boostSet = <int>{};
      if (!rules.allowDoubles && teacherAvail != null && remainder > 0) {
        // Constraint-aware: only boost subjects whose teacher has enough
        // available days for (base+1) distinct lesson instances.  Ineligible
        // subjects are skipped; their boost goes to the next eligible subject.
        for (final sid in priorityRanked) {
          if (boostSet.length >= remainder) break;
          final teacherId = subjectTeacherMap[(grade, stream, sid)];
          if (teacherId == null) continue;
          final availDays = teacherAvail[teacherId]?.length ?? 0;
          if (availDays >= base + 1) {
            boostSet.add(sid);
          }
        }
      } else {
        // Original behaviour: top `remainder` subjects in priority order.
        for (final sid in priorityRanked) {
          if (boostSet.length >= remainder) break;
          boostSet.add(sid);
        }
      }

      for (final sid in subjects) {
        final lessons = boostSet.contains(sid) ? base + 1 : base;
        result[(grade, stream, sid)] = lessons.clamp(
          1,
          lessonSlotsPerDay * rules.activeDays.length,
        );
      }
    }
    return result;
  }

  // ── Phase 0 — Validation ─────────────────────────────────────────────────

  List<String> _validate() {
    final issues = <String>[];
    final lessonsMap = _computeLessonsPerWeek();

    if (assignments.isEmpty) {
      issues.add(
        'No subjects are assigned for this term. '
        'Assign subjects to classes first.',
      );
      return issues;
    }

    if (rules.activeDays.isEmpty) {
      issues.add('No active school days selected.');
      return issues;
    }

    final lessonSlots = rules.buildLessonSlots();
    if (lessonSlots.isEmpty) {
      issues.add(
        'No lesson slots fit within the configured school day. '
        'Add at least one lesson slot in the slot builder.',
      );
      return issues;
    }

    final slotsPerDay = lessonSlots.length;
    final activeDayCount = rules.activeDays.length;
    final teacherAvail = _computeTeacherAvailability(lessonSlots);

    // ── C1: Teacher capacity ─────────────────────────────────────────────────
    // For each teacher, verify that total assigned lessons fit within their
    // effective capacity: available slots per day (capped by the daily teacher
    // limit) summed across all available days.
    final teacherTotalLessons = <String, int>{};
    for (final a in assignments) {
      final n = lessonsMap[(a.grade, a.stream, a.subjectId)] ?? 1;
      teacherTotalLessons[a.teacherUserId] =
          (teacherTotalLessons[a.teacherUserId] ?? 0) + n;
    }

    for (final entry in teacherTotalLessons.entries) {
      final daySlots = teacherAvail[entry.key] ?? {};
      if (daySlots.isEmpty) {
        issues.add(
          'Teacher ${entry.key} has all slots blocked by constraint rules '
          'and cannot be scheduled.',
        );
        continue;
      }
      final capacity = _teacherEffectiveCapacity(daySlots);
      if (entry.value > capacity) {
        issues.add(
          'Teacher ${entry.key} needs ${entry.value} lessons/week but has '
          'capacity for only $capacity (${daySlots.length} available day(s), '
          'max $_effectiveTeacherDayCap/day). Reduce their teaching load, '
          'remove a blocking constraint, or increase the daily lesson cap.',
        );
      }
    }

    // ── C2: Class total feasibility ──────────────────────────────────────────
    final classTotalLessons = <(int, int), int>{};
    for (final a in assignments) {
      final key = (a.grade, a.stream);
      final n = lessonsMap[(a.grade, a.stream, a.subjectId)] ?? 1;
      classTotalLessons[key] = (classTotalLessons[key] ?? 0) + n;
    }

    final totalSlotsAvailable = slotsPerDay * activeDayCount;
    for (final entry in classTotalLessons.entries) {
      if (entry.value > totalSlotsAvailable) {
        issues.add(
          'Class (grade=${entry.key.$1}, stream=${entry.key.$2}) requires '
          '${entry.value} lessons per week but the school day only has '
          '$totalSlotsAvailable available slots ($slotsPerDay/day × '
          '$activeDayCount days).',
        );
      }
    }

    // ── C3: No-doubles per-subject effective days ────────────────────────────
    // When allowDoubles=false, each lesson instance of a subject must go on a
    // distinct day.  Verify that the teacher+subject combination has enough
    // feasible days (at least one non-blocked slot on that day) for all
    // assigned instances.  This replaces the old check that only compared
    // against activeDays count (which ignored teacher/subject blocking).
    if (!rules.allowDoubles) {
      final subjectTeacherMap = <(int, int, int), String>{};
      for (final a in assignments) {
        subjectTeacherMap[(a.grade, a.stream, a.subjectId)] = a.teacherUserId;
      }

      for (final entry in lessonsMap.entries) {
        final (grade, stream, subjectId) = entry.key;
        final count = entry.value;
        final teacherId = subjectTeacherMap[(grade, stream, subjectId)];
        if (teacherId == null) continue;

        // Count days where this (teacher, subject) combo has at least one
        // feasible lesson slot.
        int feasibleDays = 0;
        for (final dayIndex in rules.activeDays) {
          bool hasFeasibleSlot = false;
          for (final ls in lessonSlots) {
            if (_isSlotAllowedForTeacher(
                  teacherId: teacherId,
                  slotIndex: ls.index,
                  dayIndex: dayIndex,
                ) &&
                _isSlotAllowedForSubject(
                  subjectId: subjectId,
                  slotIndex: ls.index,
                  dayIndex: dayIndex,
                )) {
              hasFeasibleSlot = true;
              break;
            }
          }
          if (hasFeasibleSlot) feasibleDays++;
        }

        if (count > feasibleDays) {
          issues.add(
            'Subject $subjectId for class (grade=$grade, stream=$stream) '
            'needs $count lessons/week on distinct days, but its teacher '
            'is only available on $feasibleDays of $activeDayCount active '
            'days. Remove a blocking constraint, reduce this subject\'s '
            'lessons, or enable "allow doubles".',
          );
        }
      }
    }

    // ── C4: Class-level pigeon-hole per day ──────────────────────────────────
    // When allowDoubles=false and slot utilisation is ~100%, every slot on
    // every day must be filled by a distinct subject.  If too many subjects
    // are blocked on the same day (teacher blocked OR subject blocked), there
    // aren't enough available subjects to fill all slots.
    //
    // Condition: availableSubjects(class, day) >= slotsPerDay.
    if (!rules.allowDoubles) {
      final classAssignments = <(int, int), List<SolverAssignment>>{};
      for (final a in assignments) {
        classAssignments.putIfAbsent((a.grade, a.stream), () => []).add(a);
      }

      for (final classEntry in classAssignments.entries) {
        final (grade, stream) = classEntry.key;
        final classSubjects = classEntry.value;

        for (final dayIndex in rules.activeDays) {
          int availableSubjects = 0;
          for (final a in classSubjects) {
            bool hasFeasibleSlot = false;
            for (final ls in lessonSlots) {
              if (_isSlotAllowedForTeacher(
                    teacherId: a.teacherUserId,
                    slotIndex: ls.index,
                    dayIndex: dayIndex,
                  ) &&
                  _isSlotAllowedForSubject(
                    subjectId: a.subjectId,
                    slotIndex: ls.index,
                    dayIndex: dayIndex,
                  )) {
                hasFeasibleSlot = true;
                break;
              }
            }
            if (hasFeasibleSlot) availableSubjects++;
          }

          if (availableSubjects < slotsPerDay) {
            final blocked = classSubjects.length - availableSubjects;
            final dayName =
                const {
                  1: 'Monday',
                  2: 'Tuesday',
                  3: 'Wednesday',
                  4: 'Thursday',
                  5: 'Friday',
                  6: 'Saturday',
                  7: 'Sunday',
                }[dayIndex] ??
                'day $dayIndex';
            issues.add(
              'Class (grade=$grade, stream=$stream) on $dayName: '
              '$blocked of ${classSubjects.length} subjects are blocked, '
              'leaving only $availableSubjects available — but $slotsPerDay '
              'slots must be filled. Remove a blocking constraint on '
              '$dayName or reduce the number of lesson slots per day.',
            );
          }
        }
      }
    }

    return issues;
  }

  // ── Constraint helpers ────────────────────────────────────────────────────

  bool _isSlotAllowedForTeacher({
    required String teacherId,
    required int slotIndex,
    required int dayIndex,
  }) {
    for (final c in rules.teacherConstraints) {
      if (c.teacherId != teacherId) continue;
      if (!c.days.contains(dayIndex)) continue;
      if (c.isBlock && c.slotIndices.contains(slotIndex)) return false;
      if (!c.isBlock && !c.slotIndices.contains(slotIndex)) return false;
    }
    return true;
  }

  bool _isSlotAllowedForSubject({
    required int subjectId,
    required int slotIndex,
    required int dayIndex,
  }) {
    for (final c in rules.subjectConstraints) {
      if (c.subjectId != subjectId) continue;
      if (!c.days.contains(dayIndex)) continue;
      if (c.isBlock && c.slotIndices.contains(slotIndex)) return false;
      if (!c.isBlock && !c.slotIndices.contains(slotIndex)) return false;
    }
    return true;
  }

  // ── Phase 1 — Domain construction ────────────────────────────────────────

  Map<_Variable, List<_Slot>> _buildDomains(
    List<_Variable> variables,
    List<({int index, int start, int end})> lessonSlots,
  ) {
    final domains = <_Variable, List<_Slot>>{};

    for (final variable in variables) {
      // When day pre-assignment is active, restrict this variable's domain
      // to slots on its forced day only.  null means no restriction (i.e.
      // allowDoubles=true or pre-assignment not computed for this restart).
      final forcedDay = _dayForVariable[variable];

      final domain = <_Slot>[];

      for (final dayIndex in rules.activeDays) {
        final day = _weekdayIndexToDay(dayIndex);

        // Skip days that don't match the pre-assigned day.
        if (forcedDay != null && day != forcedDay) continue;

        for (final ls in lessonSlots) {
          if (!_isSlotAllowedForTeacher(
            teacherId: variable.teacherUserId,
            slotIndex: ls.index,
            dayIndex: dayIndex,
          )) {
            continue;
          }
          if (!_isSlotAllowedForSubject(
            subjectId: variable.subjectId,
            slotIndex: ls.index,
            dayIndex: dayIndex,
          )) {
            continue;
          }

          domain.add(
            _Slot(
              day: day,
              startSeconds: ls.start,
              endSeconds: ls.end,
              slotIndexInRules: ls.index,
            ),
          );
        }
      }

      domains[variable] = domain;
    }

    return domains;
  }

  // ── O(1) index table management ──────────────────────────────────────────

  /// Record a placement in all five O(1) lookup tables.
  ///
  /// Must be called immediately before attempting propagation so that
  /// [_propagateInPlace] reads the post-placement daily counts.
  void _placeVariable(_Variable v, _Slot s) {
    final tk = (v.teacherUserId, s.day, s.startSeconds);
    _teacherSlotCount[tk] = (_teacherSlotCount[tk] ?? 0) + 1;

    final ck = (v.grade, v.stream, s.day, s.startSeconds);
    _classSlotCount[ck] = (_classSlotCount[ck] ?? 0) + 1;

    final tdk = (v.teacherUserId, s.day);
    _teacherDayCount[tdk] = (_teacherDayCount[tdk] ?? 0) + 1;

    final cdk = (v.grade, v.stream, s.day);
    _classDayCount[cdk] = (_classDayCount[cdk] ?? 0) + 1;

    final csk = (v.grade, v.stream, s.day, v.subjectId);
    _classSubjectDayCount[csk] = (_classSubjectDayCount[csk] ?? 0) + 1;
  }

  /// Undo a placement from all five O(1) lookup tables.
  ///
  /// Called on backtrack, after restoring domain removals from the trail.
  void _unplaceVariable(_Variable v, _Slot s) {
    void dec<K>(Map<K, int> map, K key) {
      final c = (map[key] ?? 1) - 1;
      if (c <= 0) {
        map.remove(key);
      } else {
        map[key] = c;
      }
    }

    dec(_teacherSlotCount, (v.teacherUserId, s.day, s.startSeconds));
    dec(_classSlotCount, (v.grade, v.stream, s.day, s.startSeconds));
    dec(_teacherDayCount, (v.teacherUserId, s.day));
    dec(_classDayCount, (v.grade, v.stream, s.day));
    dec(_classSubjectDayCount, (v.grade, v.stream, s.day, v.subjectId));
  }

  // ── Phase 2 — Backtracking search ────────────────────────────────────────

  /// Recursive CSP solver with undo-trail backtracking.
  ///
  /// **Invariant:** when this method returns `null`, [unassigned], [assignment],
  /// and [domains] are in exactly the same state as when it was called.
  /// The caller can therefore safely continue trying other slots for the
  /// variable it placed before the recursive call.
  ///
  /// **On success:** the method returns a *snapshot* of [assignment] taken at
  /// the leaf node (`Map.from(assignment)`).  Neither [unassigned] nor
  /// [domains] are restored — they are discarded by the caller.
  Map<_Variable, _Slot>? _solve(
    List<_Variable> unassigned,
    Map<_Variable, _Slot> assignment,
    Map<_Variable, List<_Slot>> domains,
  ) {
    if (unassigned.isEmpty) {
      // All variables placed — snapshot the assignment and return it.
      return Map<_Variable, _Slot>.from(assignment);
    }

    _iterations++;

    // ── Milestone progress snapshot ───────────────────────────────────────
    if (_iterations % _kLogEveryNIterations == 0) {
      int mrvSize = 999999;
      int unassignedDomainTotal = 0;
      for (final v in unassigned) {
        final sz = domains[v]?.length ?? 0;
        if (sz < mrvSize) mrvSize = sz;
        unassignedDomainTotal += sz;
      }
      final avgDomain = unassigned.isEmpty
          ? 0.0
          : unassignedDomainTotal / unassigned.length;
      final passRate = _consistencyChecks == 0
          ? 0.0
          : _consistencyPasses / _consistencyChecks * 100;
      final failRate = _propagationCalls == 0
          ? 0.0
          : _propagationFails / _propagationCalls * 100;
      final avgTrail = _trailRestores == 0
          ? 0.0
          : _trailEntriesTotal / _trailRestores;
      _log(
        '  ↳ node=$_iterations  '
        'unassigned=${unassigned.length}  assigned=${assignment.length}  '
        'mrvDomain=$mrvSize  avgUnassignedDomain=${avgDomain.toStringAsFixed(1)}  '
        '| consistencyChecks=$_consistencyChecks (pass=${passRate.toStringAsFixed(1)}%)  '
        '| propagFails=$_propagationFails (${failRate.toStringAsFixed(1)}% of calls)  '
        '| trailRestores=$_trailRestores (avg=${avgTrail.toStringAsFixed(1)} entries)',
      );
    }

    // ── MRV: O(n) linear scan — no sort ──────────────────────────────────
    int mrvIdx = 0;
    int mrvSize = domains[unassigned[0]]?.length ?? 0;
    for (int i = 1; i < unassigned.length; i++) {
      final sz = domains[unassigned[i]]?.length ?? 0;
      if (sz < mrvSize) {
        mrvSize = sz;
        mrvIdx = i;
      }
    }

    // Swap-remove chosen variable from the unassigned list in O(1).
    final variable = unassigned[mrvIdx];
    unassigned[mrvIdx] = unassigned[unassigned.length - 1];
    unassigned.removeLast();

    // Snapshot the current domain for iteration.  The domain is not modified
    // by propagation for this variable (it is no longer in `unassigned`), so
    // the snapshot remains stable throughout the for-loop.
    final domainSnapshot = List<_Slot>.from(domains[variable]!);

    for (final slot in domainSnapshot) {
      // ── O(1) consistency check via index tables ───────────────────────
      if (!_isConsistentFast(variable, slot)) continue;

      // ── Place variable in-place ───────────────────────────────────────
      assignment[variable] = slot;
      _placeVariable(variable, slot);

      // ── Propagate: prune domains in-place, collect undo trail ─────────
      final trail = <_TrailEntry>[];
      final pruneOk = _propagateInPlace(
        variable,
        slot,
        unassigned,
        domains,
        trail,
      );

      if (pruneOk) {
        final result = _solve(unassigned, assignment, domains);
        if (result != null) {
          // Success — caller discards unassigned and domains; no cleanup needed.
          return result;
        }
      }

      // ── Undo propagation: restore removed slots from trail ────────────
      if (trail.isNotEmpty) {
        _trailRestores++;
        for (final entry in trail) {
          _trailEntriesTotal += entry.removed.length;
          domains[entry.variable]!.addAll(entry.removed);
        }
      }

      // ── Undo placement ────────────────────────────────────────────────
      assignment.remove(variable);
      _unplaceVariable(variable, slot);
    }

    // All domain values exhausted for this variable — backtrack.
    // Restore the variable to the unassigned list before returning null.
    unassigned.add(variable);
    return null;
  }

  // ── O(1) consistency check ────────────────────────────────────────────────

  /// Check all hard constraints for placing [variable] at [slot].
  ///
  /// Uses the five O(1) lookup tables that are maintained incrementally by
  /// [_placeVariable] and [_unplaceVariable].  Replaces the O(assignment_size)
  /// linear scan of the v1 `_isConsistent` method.
  bool _isConsistentFast(_Variable variable, _Slot slot) {
    _consistencyChecks++;

    // 1. Teacher double-booking — same teacher, same (day, start).
    if ((_teacherSlotCount[(
              variable.teacherUserId,
              slot.day,
              slot.startSeconds,
            )] ??
            0) >
        0) {
      return false;
    }

    // 2. Class double-booking — same (grade, stream), same (day, start).
    if ((_classSlotCount[(
              variable.grade,
              variable.stream,
              slot.day,
              slot.startSeconds,
            )] ??
            0) >
        0) {
      return false;
    }

    // 3. Teacher daily lesson cap — uses the effective cap (the minimum of the
    //    physical slot count and the user-configured maxLessonsPerDayTeacher).
    if ((_teacherDayCount[(variable.teacherUserId, slot.day)] ?? 0) >=
        _effectiveTeacherDayCap) {
      return false;
    }

    // 4. Class daily lesson cap — uses the effective cap (the minimum of the
    //    physical slot count and the user-configured maxLessonsPerDayClass).
    if ((_classDayCount[(variable.grade, variable.stream, slot.day)] ?? 0) >=
        _effectiveClassDayCap) {
      return false;
    }

    // 5. No-doubles — same subject already placed on this day for this class.
    if (!rules.allowDoubles &&
        (_classSubjectDayCount[(
                  variable.grade,
                  variable.stream,
                  slot.day,
                  variable.subjectId,
                )] ??
                0) >
            0) {
      return false;
    }

    _consistencyPasses++;
    return true;
  }

  // ── In-place forward-checking propagation ────────────────────────────────

  /// Prune the domains of [remaining] variables given that [placed] was just
  /// assigned to [slot].  All removals are recorded in [trail].
  ///
  /// Three pruning layers are applied in a single O(domain_size) pass per
  /// affected variable:
  ///
  /// * **Layer 1 — exact slot conflict:** remove the exact (day, startSeconds)
  ///   pair from every variable that shares the same teacher or the same class
  ///   as [placed] — prevents double-booking.
  ///
  /// * **Layer 2 — daily cap:** if the teacher or class has now reached its
  ///   physical daily lesson cap, remove ALL remaining slots on that day from
  ///   affected variables.
  ///
  /// * **Layer 3 — no-doubles:** when `allowDoubles = false`, remove ALL
  ///   remaining slots on that day from every other instance of the same
  ///   subject for the same class.  This was the *missing* propagation rule
  ///   in v1 — its absence caused `propagFails` to be 0 across hundreds of
  ///   thousands of nodes and the solver to thrash indefinitely.
  ///
  /// Returns `false` if any variable's domain becomes empty (dead-end
  /// detected); the caller will then skip this candidate.
  bool _propagateInPlace(
    _Variable placed,
    _Slot slot,
    List<_Variable> remaining,
    Map<_Variable, List<_Slot>> domains,
    List<_TrailEntry> trail,
  ) {
    _propagationCalls++;

    // Read daily counts AFTER _placeVariable updated the index tables.
    final teacherDayCount =
        _teacherDayCount[(placed.teacherUserId, slot.day)] ?? 0;
    final classDayCount =
        _classDayCount[(placed.grade, placed.stream, slot.day)] ?? 0;

    final teacherAtCap = teacherDayCount >= _effectiveTeacherDayCap;
    final classAtCap = classDayCount >= _effectiveClassDayCap;

    for (final v in remaining) {
      final sameTeacher = v.teacherUserId == placed.teacherUserId;
      final sameClass = v.grade == placed.grade && v.stream == placed.stream;

      // Skip variables that share neither teacher nor class — unaffected.
      if (!sameTeacher && !sameClass) continue;

      // True when this variable is another instance of the same subject for
      // the same class — relevant for Layer 3 (no-doubles).
      final sameSubject = sameClass && v.subjectId == placed.subjectId;

      final domain = domains[v]!;

      // Single-pass O(n) partition: accumulate kept and removed in parallel.
      // This is O(n) total vs. O(n²) worst-case for backward removeAt loops.
      final kept = <_Slot>[];
      final removed = <_Slot>[];

      for (final s in domain) {
        // Slots on different days are never affected by this placement.
        if (s.day != slot.day) {
          kept.add(s);
          continue;
        }

        // Evaluate all three layers for same-day slots.
        final shouldRemove =
            // Layer 1: exact (day, start) conflict.
            (s.startSeconds == slot.startSeconds) ||
            // Layer 2a: teacher reached daily cap — block entire day.
            (sameTeacher && teacherAtCap) ||
            // Layer 2b: class reached daily cap — block entire day.
            (sameClass && classAtCap) ||
            // Layer 3: no-doubles — subject already on this day for this class.
            (!rules.allowDoubles && sameSubject);

        if (shouldRemove) {
          removed.add(s);
        } else {
          kept.add(s);
        }
      }

      if (removed.isNotEmpty) {
        // Apply the partition to the domain in-place.
        domain.clear();
        domain.addAll(kept);
        // Record the removal for undo on backtrack.
        trail.add((variable: v, removed: removed));
      }

      if (domain.isEmpty) {
        _propagationFails++;
        return false;
      }
    }

    return true;
  }

  // ── Phase 3 — Soft scoring ────────────────────────────────────────────────

  int _softScore(
    Map<_Variable, _Slot> assignment,
    List<({int index, int start, int end})> lessonSlots,
  ) {
    int score = 0;

    final avgSlotDurSecs = lessonSlots.isEmpty
        ? 2400
        : lessonSlots.map((s) => s.end - s.start).reduce((a, b) => a + b) ~/
              lessonSlots.length;

    final teacherDayStarts = <String, Map<DayOfWeek, List<int>>>{};
    final classDaySubjects =
        <({int grade, int stream}), Map<DayOfWeek, List<int>>>{};

    for (final entry in assignment.entries) {
      final v = entry.key;
      final s = entry.value;

      teacherDayStarts
          .putIfAbsent(v.teacherUserId, () => {})
          .putIfAbsent(s.day, () => [])
          .add(s.startSeconds);

      final classKey = (grade: v.grade, stream: v.stream);
      classDaySubjects
          .putIfAbsent(classKey, () => {})
          .putIfAbsent(s.day, () => [])
          .add(v.subjectId);
    }

    // Penalty: teacher has a free period (gap) between two lessons on the same day.
    for (final dayMap in teacherDayStarts.values) {
      for (final starts in dayMap.values) {
        if (starts.length < 2) continue;
        final sorted = List<int>.from(starts)..sort();
        for (int i = 1; i < sorted.length; i++) {
          final gap = sorted[i] - sorted[i - 1];
          if (gap > avgSlotDurSecs * 2) score += 2;
        }
      }
    }

    // Penalty: same subject more than once on the same day for a class.
    for (final dayMap in classDaySubjects.values) {
      for (final subjects in dayMap.values) {
        final seen = <int>{};
        for (final subj in subjects) {
          if (!seen.add(subj)) score += 1;
        }
      }
    }

    // Penalty: highly uneven lesson distribution across active days for a class.
    for (final dayMap in classDaySubjects.values) {
      final dayCounts = dayMap.values.map((l) => l.length).toList();
      if (dayCounts.length < 2) continue;

      final mean = dayCounts.reduce((a, b) => a + b) / dayCounts.length;
      final variance =
          dayCounts
              .map((c) => (c - mean) * (c - mean))
              .reduce((a, b) => a + b) /
          dayCounts.length;

      if (variance > 2.25) score += 3;
    }

    // Penalty: teacher teaches too many lessons per day (spread burden).
    for (final entry in teacherDayStarts.entries) {
      for (final dayStarts in entry.value.values) {
        if (dayStarts.length > 3) score += 1;
      }
    }

    return score;
  }
}

// ── Top-level compute wrapper ─────────────────────────────────────────────────

/// Input container for [runTimetableGenerator].  All fields are plain Dart
/// types, making this safe to send across isolate boundaries via `compute()`.
class GeneratorInput {
  const GeneratorInput({
    required this.assignments,
    required this.rules,
    this.maxRestarts = 8,
  });

  final List<SolverAssignment> assignments;
  final TimetableRules rules;
  final int maxRestarts;
}

/// Top-level function for use with Flutter's `compute()`.
///
/// Runs [TimetableGenerator.generate()] synchronously on the calling isolate.
/// Flutter's `compute()` automatically spawns a background isolate.
///
/// Example:
/// ```dart
/// final result = await compute(runTimetableGenerator, GeneratorInput(
///   assignments: assignments,
///   rules: rules,
/// ));
/// ```
GeneratorResult runTimetableGenerator(GeneratorInput input) {
  return TimetableGenerator(
    assignments: input.assignments,
    rules: input.rules,
    maxRestarts: input.maxRestarts,
  ).generate();
}
