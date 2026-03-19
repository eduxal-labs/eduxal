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
  /// Used to resolve [TeacherConstraintEntry.slotIndices] /
  /// [SubjectConstraintEntry.slotIndices].
  final int slotIndexInRules;

  @override
  bool operator ==(Object other) =>
      other is _Slot && day == other.day && startSeconds == other.startSeconds;

  @override
  int get hashCode => Object.hash(day, startSeconds);
}

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

/// Convert a [DayOfWeek] enum value to its weekday index (1=Mon … 7=Sun).
int _dayToWeekdayIndex(DayOfWeek day) {
  if (day == DayOfWeek.sunday) return 7;
  return day.index; // monday(1) … saturday(6)
}

// ── TimetableGenerator ────────────────────────────────────────────────────────

/// Pure-Dart CSP backtracking solver for weekly timetable generation.
///
/// No Flutter dependencies — safe to run inside `compute()` on a background
/// isolate. All input data is provided via the constructor; no DAO calls are
/// made inside the generator.
///
/// ### Key behaviours
///
/// * Each [SolverAssignment] produces N [_Variable] instances where
///   N = `_computeLessonsPerWeek()[(grade, stream, subjectId)]`. This fills
///   the timetable with appropriately repeated lessons instead of placing each
///   subject only once per week.
///
/// * [_isConsistent] enforces hard constraints: no teacher double-booking,
///   no class double-booking, no subject repeating on the same day when
///   doubles are disabled, and daily lesson caps.
///
/// * [_propagate] prunes peer domains after each placement. In addition to
///   removing the exact (day, startSeconds) pair, it also prunes all
///   remaining same-day slots for a teacher/class that has just hit its
///   daily cap — dramatically reducing wasted backtrack iterations.
///
/// * Up to [maxRestarts] restarts with freshly shuffled domains are attempted
///   before the generator declares failure.
///
/// ### Slot-index constraint model (v2)
///
/// Teacher and subject constraints are now expressed as lists of **slot
/// indices** (0-based positions in [TimetableRules.slots], the OVERALL list
/// including breaks) rather than time-range overlap checks.  The generator
/// calls [TimetableRules.buildLessonSlots] to obtain the schedulable lesson
/// slots together with their overall slot index, then enforces constraints
/// during domain construction by comparing each slot's [_Slot.slotIndexInRules]
/// against the constraint's [TeacherConstraintEntry.slotIndices] /
/// [SubjectConstraintEntry.slotIndices].
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

  int _iterations = 0;

  /// Cached count of lesson-only slots per day, derived from [rules].
  /// Used as the physical daily cap in the solver — replaces the old
  /// `maxLessonsPerDayTeacher` / `maxLessonsPerDayClass` arbitrary defaults.
  late final int _lessonSlotsPerDay = rules.slots
      .where((s) => s.type == SlotType.lesson)
      .length;

  // ── Entry point ─────────────────────────────────────────────────────────────

  /// Run the solver synchronously and return a [GeneratorResult].
  ///
  /// Phases:
  /// 1. **Validation** — reject obviously impossible inputs early.
  /// 2. **Variable expansion** — create N instances per assignment.
  /// 3. **Domain construction + backtracking** — MRV heuristic, forward-checking
  ///    propagation with daily-cap pruning, up to [maxRestarts] restarts.
  /// 4. **Soft scoring** — penalise teacher gaps and uneven distributions.
  GeneratorResult generate() {
    final stopwatch = Stopwatch()..start();

    // ── Phase 0 — Validate ───────────────────────────────────────────────────
    final conflicts = _validate();
    if (conflicts.isNotEmpty) {
      return GeneratorFailure(reason: conflicts.first, conflicts: conflicts);
    }

    final lessonSlots = rules.buildLessonSlots();
    if (lessonSlots.isEmpty) {
      return GeneratorFailure(
        reason:
            'No lesson slots available. Add at least one lesson slot in the '
            'slot builder (Stage 1).',
        conflicts: [],
      );
    }

    // ── Phase 1 — Expand assignments into variables ──────────────────────────
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

    // ── Phase 2 + 3 — Restarts ───────────────────────────────────────────────
    int totalIterations = 0;

    for (int restart = 0; restart < maxRestarts; restart++) {
      _iterations = 0;

      final domains = _buildDomains(variables, lessonSlots);
      for (final domain in domains.values) {
        domain.shuffle(_random);
      }

      final result = _solve(List<_Variable>.from(variables), {}, domains);

      totalIterations += _iterations;

      if (result != null) {
        // ── Phase 4 — Soft score ─────────────────────────────────────────────
        final score = _softScore(result, lessonSlots);

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
        return GeneratorSuccess(
          slots: timetableSlots,
          softScore: score,
          iterations: totalIterations,
          elapsed: stopwatch.elapsed,
        );
      }
    }

    stopwatch.stop();
    return GeneratorFailure(
      reason:
          'Could not find a valid timetable after $maxRestarts attempts. '
          'Try relaxing constraints: fewer lessons per week, more active days, '
          'more lesson slots in the day, a higher daily lesson cap, or remove '
          'some teacher/subject constraint rules.',
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

      for (final sid in subjects) {
        final priorityRank = priorityRanked.indexOf(sid);
        final lessons = (priorityRank >= 0 && priorityRank < remainder)
            ? base + 1
            : base;
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
        'No subjects are assigned for this term. Assign subjects to classes first.',
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

    // ── Teacher feasibility ──────────────────────────────────────────────────
    final teacherTotalLessons = <String, int>{};
    for (final a in assignments) {
      final n = lessonsMap[(a.grade, a.stream, a.subjectId)] ?? 1;
      teacherTotalLessons[a.teacherUserId] =
          (teacherTotalLessons[a.teacherUserId] ?? 0) + n;
    }

    for (final entry in teacherTotalLessons.entries) {
      // Check that the teacher has at least one open slot after constraints.
      var hasAnySlot = false;
      outer:
      for (final dayIndex in rules.activeDays) {
        for (final ls in lessonSlots) {
          if (_isSlotAllowedForTeacher(
            teacherId: entry.key,
            slotIndex: ls.index,
            dayIndex: dayIndex,
          )) {
            hasAnySlot = true;
            break outer;
          }
        }
      }
      if (!hasAnySlot) {
        issues.add(
          'Teacher ${entry.key} has all slots blocked by constraint rules and '
          'cannot be scheduled.',
        );
        continue;
      }
    }

    // ── Class feasibility ────────────────────────────────────────────────────
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

    return issues;
  }

  // ── Constraint helpers ────────────────────────────────────────────────────

  /// Returns `true` if no teacher constraint blocks [teacherId] from
  /// [slotIndex] on the day identified by [dayIndex] (1=Mon…7=Sun).
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

  /// Returns `true` if no subject constraint blocks [subjectId] from
  /// [slotIndex] on the day identified by [dayIndex].
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
      final domain = <_Slot>[];

      for (final dayIndex in rules.activeDays) {
        final day = _weekdayIndexToDay(dayIndex);

        for (final ls in lessonSlots) {
          // Apply teacher constraints.
          if (!_isSlotAllowedForTeacher(
            teacherId: variable.teacherUserId,
            slotIndex: ls.index,
            dayIndex: dayIndex,
          )) {
            continue;
          }

          // Apply subject constraints.
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

  // ── Phase 2 — Backtracking search ────────────────────────────────────────

  Map<_Variable, _Slot>? _solve(
    List<_Variable> unassigned,
    Map<_Variable, _Slot> assignment,
    Map<_Variable, List<_Slot>> domains,
  ) {
    if (unassigned.isEmpty) return assignment;

    _iterations++;

    // MRV heuristic — pick the variable with the fewest remaining domain values.
    unassigned.sort(
      (a, b) => (domains[a]?.length ?? 0).compareTo(domains[b]?.length ?? 0),
    );
    final variable = unassigned.first;
    final remaining = List<_Variable>.from(unassigned)..remove(variable);

    final domainValues = List<_Slot>.from(domains[variable] ?? []);

    for (final slot in domainValues) {
      if (!_isConsistent(variable, slot, assignment)) continue;

      final newAssignment = Map<_Variable, _Slot>.from(assignment)
        ..[variable] = slot;

      final newDomains = <_Variable, List<_Slot>>{};
      for (final entry in domains.entries) {
        newDomains[entry.key] = List<_Slot>.from(entry.value);
      }

      final pruneOk = _propagate(
        variable,
        slot,
        remaining,
        newDomains,
        newAssignment,
      );
      if (!pruneOk) continue;

      final result = _solve(remaining, newAssignment, newDomains);
      if (result != null) return result;
    }

    return null;
  }

  // ── Consistency check ─────────────────────────────────────────────────────

  bool _isConsistent(
    _Variable variable,
    _Slot slot,
    Map<_Variable, _Slot> assignment,
  ) {
    int teacherDayCount = 0;
    int classDayCount = 0;

    for (final entry in assignment.entries) {
      final v = entry.key;
      final s = entry.value;

      if (s.day != slot.day) continue;

      // 1. Teacher double-booking.
      if (v.teacherUserId == variable.teacherUserId &&
          s.startSeconds == slot.startSeconds) {
        return false;
      }

      // 2. Class double-booking.
      if (v.grade == variable.grade &&
          v.stream == variable.stream &&
          s.startSeconds == slot.startSeconds) {
        return false;
      }

      // 3. Accumulate teacher day count.
      if (v.teacherUserId == variable.teacherUserId) {
        teacherDayCount++;
      }

      // 4. Accumulate class day count.
      if (v.grade == variable.grade && v.stream == variable.stream) {
        classDayCount++;
      }

      // 5. Double-lesson check.
      if (!rules.allowDoubles &&
          v.grade == variable.grade &&
          v.stream == variable.stream &&
          v.subjectId == variable.subjectId) {
        return false;
      }
    }

    // 6. Teacher daily load cap — physical maximum is the number of lesson slots.
    if (teacherDayCount >= _lessonSlotsPerDay) return false;

    // 7. Class daily load cap — physical maximum is the number of lesson slots.
    if (classDayCount >= _lessonSlotsPerDay) return false;

    return true;
  }

  // ── Forward-checking propagation ──────────────────────────────────────────

  bool _propagate(
    _Variable placed,
    _Slot slot,
    List<_Variable> remaining,
    Map<_Variable, List<_Slot>> domains,
    Map<_Variable, _Slot> assignment,
  ) {
    int teacherDayCount = 0;
    int classDayCount = 0;

    for (final entry in assignment.entries) {
      if (entry.value.day != slot.day) continue;
      if (entry.key.teacherUserId == placed.teacherUserId) teacherDayCount++;
      if (entry.key.grade == placed.grade &&
          entry.key.stream == placed.stream) {
        classDayCount++;
      }
    }

    final teacherAtCap = teacherDayCount >= _lessonSlotsPerDay;
    final classAtCap = classDayCount >= _lessonSlotsPerDay;

    for (final v in remaining) {
      final sameTeacher = v.teacherUserId == placed.teacherUserId;
      final sameClass = v.grade == placed.grade && v.stream == placed.stream;

      if (!sameTeacher && !sameClass) continue;

      final domain = domains[v];
      if (domain == null) continue;

      // Layer 1: remove exact placed (day, startSeconds).
      domain.removeWhere(
        (s) => s.day == slot.day && s.startSeconds == slot.startSeconds,
      );

      // Layer 2: daily-cap pruning.
      if (sameTeacher && teacherAtCap) {
        domain.removeWhere((s) => s.day == slot.day);
      }
      if (sameClass && classAtCap) {
        domain.removeWhere((s) => s.day == slot.day);
      }

      if (domain.isEmpty) return false;
    }

    return true;
  }

  // ── Phase 3 — Soft scoring ────────────────────────────────────────────────

  int _softScore(
    Map<_Variable, _Slot> assignment,
    List<({int index, int start, int end})> lessonSlots,
  ) {
    int score = 0;

    // Compute approximate slot duration (average of all lesson slot durations)
    // for gap detection.
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
