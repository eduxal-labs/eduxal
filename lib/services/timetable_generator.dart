import 'dart:math';

import '../database/daos/timetable_dao.dart' show SolverAssignment;
import '../database/tables/enums.dart';
import '../models/timetable_rules.dart';

// ── Public result types ───────────────────────────────────────────────────────

/// One solved timetable slot produced by the generator.
class TimetableSlot {
  const TimetableSlot({
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

  /// The fully solved timetable — one entry per (grade, stream, subject).
  final List<TimetableSlot> slots;

  /// Soft constraint penalty score. Lower is better; 0 = optimal.
  final int softScore;

  /// Total backtrack iterations across all phases.
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

/// One CSP variable — a (school, year, term, grade, stream, subject) that needs
/// exactly one slot assignment per week.
class _Variable {
  const _Variable({
    required this.school,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.subjectId,
    required this.teacherUserId,
  });

  final String school;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int subjectId;
  final String teacherUserId;

  @override
  bool operator ==(Object other) =>
      other is _Variable &&
      grade == other.grade &&
      stream == other.stream &&
      subjectId == other.subjectId &&
      school == other.school &&
      year == other.year &&
      term == other.term;

  @override
  int get hashCode => Object.hash(school, year, term, grade, stream, subjectId);
}

/// One candidate (day, time) pair in a variable's domain.
class _Slot {
  const _Slot({
    required this.day,
    required this.startSeconds,
    required this.endSeconds,
  });

  final DayOfWeek day;
  final int startSeconds;
  final int endSeconds;

  @override
  bool operator ==(Object other) =>
      other is _Slot && day == other.day && startSeconds == other.startSeconds;

  @override
  int get hashCode => Object.hash(day, startSeconds);
}

// ── TimetableGenerator ────────────────────────────────────────────────────────

/// Pure-Dart CSP backtracking solver for weekly timetable generation.
///
/// No Flutter dependencies — safe to run inside `compute()` on a background
/// isolate. All input data is provided via the constructor; no DAO calls are
/// made inside the generator.
///
/// Usage:
/// ```dart
/// final result = await compute(runTimetableGenerator, GeneratorInput(
///   assignments: assignments,
///   rules: rules,
/// ));
/// ```
class TimetableGenerator {
  TimetableGenerator({
    required this.assignments,
    required this.rules,
    this.maxRestarts = 5,
    Random? random,
  }) : _random = random ?? Random();

  /// Subject-teacher assignments fetched from `TimetableDao.getSubjectTeachersForTerm()`.
  final List<SolverAssignment> assignments;

  /// School-day configuration and constraint rules.
  final TimetableRules rules;

  /// How many times to restart the search with a freshly shuffled domain order
  /// before declaring failure. Each restart is independent.
  final int maxRestarts;

  final Random _random;

  int _iterations = 0;

  // ── Entry point ─────────────────────────────────────────────────────────────

  /// Run the solver synchronously and return a [GeneratorResult].
  ///
  /// Phases:
  /// 1. **Validation** — reject obviously impossible inputs early.
  /// 2. **Domain construction + backtracking** — MRV heuristic, forward-checking
  ///    propagation, up to [maxRestarts] restarts with shuffled domain order.
  /// 3. **Soft scoring** — penalise teacher gaps, doubles, uneven distributions.
  GeneratorResult generate() {
    final stopwatch = Stopwatch()..start();

    // ── Phase 0 — Validate ───────────────────────────────────────────────────
    final conflicts = _validate();
    if (conflicts.isNotEmpty) {
      return GeneratorFailure(reason: conflicts.first, conflicts: conflicts);
    }

    final slots = rules.buildSlots();
    if (slots.isEmpty) {
      return GeneratorFailure(
        reason:
            'No time slots available. Check day start/end and lesson duration.',
        conflicts: [],
      );
    }

    // Build CSP variables from the assignment list.
    final variables = assignments
        .map(
          (a) => _Variable(
            school: a.school,
            year: a.year,
            term: a.term,
            grade: a.grade,
            stream: a.stream,
            subjectId: a.subjectId,
            teacherUserId: a.teacherUserId,
          ),
        )
        .toList();

    // ── Phase 1 + 2 — Restarts ───────────────────────────────────────────────
    int totalIterations = 0;

    for (int restart = 0; restart < maxRestarts; restart++) {
      _iterations = 0;

      // Build domains for this restart and shuffle for variety.
      final domains = _buildDomains(variables, slots);
      for (final domain in domains.values) {
        domain.shuffle(_random);
      }

      final result = _solve(List<_Variable>.from(variables), {}, domains);

      totalIterations += _iterations;

      if (result != null) {
        // ── Phase 3 — Soft score ─────────────────────────────────────────────
        final score = _softScore(result);

        final timetableSlots = result.entries
            .map(
              (e) => TimetableSlot(
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
          'Try relaxing constraints (fewer subjects, more active days, longer school day, '
          'or remove some teacher/subject block rules).',
      conflicts: [],
    );
  }

  // ── Phase 0 — Validation ─────────────────────────────────────────────────

  List<String> _validate() {
    final issues = <String>[];

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

    final slots = rules.buildSlots();
    if (slots.isEmpty) {
      issues.add('No lesson slots fit within the configured school day.');
      return issues;
    }

    // Ensure every teacher has at least one unblocked slot across all active days.
    final teacherIds = assignments.map((a) => a.teacherUserId).toSet();
    for (final teacherId in teacherIds) {
      var hasAnySlot = false;
      outer:
      for (final day in rules.activeDays) {
        for (final slot in slots) {
          final blocked = rules.teacherBlocks.any(
            (r) =>
                r.teacherUserId == teacherId &&
                r.blocks(day, slot.start, slot.end),
          );
          if (!blocked) {
            hasAnySlot = true;
            break outer;
          }
        }
      }
      if (!hasAnySlot) {
        issues.add(
          'Teacher $teacherId has all slots blocked by block rules and cannot be scheduled.',
        );
      }
    }

    return issues;
  }

  // ── Phase 1 — Domain construction ────────────────────────────────────────

  Map<_Variable, List<_Slot>> _buildDomains(
    List<_Variable> variables,
    List<({int start, int end})> slots,
  ) {
    final domains = <_Variable, List<_Slot>>{};

    for (final variable in variables) {
      final domain = <_Slot>[];

      for (final day in rules.activeDays) {
        for (final slot in slots) {
          // Check teacher block rules.
          final teacherBlocked = rules.teacherBlocks.any(
            (r) =>
                r.teacherUserId == variable.teacherUserId &&
                r.blocks(day, slot.start, slot.end),
          );
          if (teacherBlocked) continue;

          // Check subject block rules.
          final subjectBlocked = rules.subjectBlocks.any(
            (r) =>
                r.subjectId == variable.subjectId &&
                r.blocks(day, slot.start, slot.end),
          );
          if (subjectBlocked) continue;

          domain.add(
            _Slot(day: day, startSeconds: slot.start, endSeconds: slot.end),
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

    // MRV heuristic: pick the variable with the fewest remaining domain values.
    unassigned.sort(
      (a, b) => (domains[a]?.length ?? 0).compareTo(domains[b]?.length ?? 0),
    );
    final variable = unassigned.first;
    final remaining = List<_Variable>.from(unassigned)..remove(variable);

    final domainValues = List<_Slot>.from(domains[variable] ?? []);

    for (final slot in domainValues) {
      if (!_isConsistent(variable, slot, assignment)) continue;

      // Place this assignment.
      final newAssignment = Map<_Variable, _Slot>.from(assignment)
        ..[variable] = slot;

      // Deep-copy domains for forward checking (we may need to restore them).
      final newDomains = <_Variable, List<_Slot>>{};
      for (final entry in domains.entries) {
        newDomains[entry.key] = List<_Slot>.from(entry.value);
      }

      // Forward checking: propagate constraints to peers.
      final pruneOk = _propagate(variable, slot, remaining, newDomains);
      if (!pruneOk) continue; // wipe-out detected — skip this value.

      final result = _solve(remaining, newAssignment, newDomains);
      if (result != null) return result;

      // Backtrack: domains were already copied per iteration, nothing to restore.
    }

    return null; // all values exhausted — signal caller to backtrack.
  }

  /// Returns `true` if placing [variable] at [slot] is consistent with the
  /// current partial [assignment] (hard constraints only).
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

      if (s.day == slot.day) {
        // 1. Teacher double-booking: same teacher, same start time, same day.
        if (v.teacherUserId == variable.teacherUserId &&
            s.startSeconds == slot.startSeconds) {
          return false;
        }

        // 2. Class double-booking: same grade+stream, same start time, same day.
        if (v.grade == variable.grade &&
            v.stream == variable.stream &&
            s.startSeconds == slot.startSeconds) {
          return false;
        }

        // 3. Accumulate teacher lesson count for this day.
        if (v.teacherUserId == variable.teacherUserId) {
          teacherDayCount++;
        }

        // 4. Accumulate class lesson count for this day.
        if (v.grade == variable.grade && v.stream == variable.stream) {
          classDayCount++;
        }

        // 5. Double-lesson check: same subject, same class, same day → disallow
        //    when allowDoubles is false.
        if (!rules.allowDoubles &&
            v.grade == variable.grade &&
            v.stream == variable.stream &&
            v.subjectId == variable.subjectId) {
          return false;
        }
      }
    }

    // 6. Teacher daily load cap.
    if (teacherDayCount >= rules.maxLessonsPerDayTeacher) return false;

    // 7. Class daily load cap.
    if (classDayCount >= rules.maxLessonsPerDayClass) return false;

    return true;
  }

  /// Forward-checking propagation. After placing [placed] at [slot], prune that
  /// exact (day, startSeconds) pair from every peer variable that shares the same
  /// teacher or the same (grade, stream).
  ///
  /// Returns `false` if any peer's domain becomes empty (wipe-out), signalling
  /// that this branch cannot lead to a solution.
  bool _propagate(
    _Variable placed,
    _Slot slot,
    List<_Variable> remaining,
    Map<_Variable, List<_Slot>> domains,
  ) {
    for (final v in remaining) {
      final sameTeacher = v.teacherUserId == placed.teacherUserId;
      final sameClass = v.grade == placed.grade && v.stream == placed.stream;

      if (!sameTeacher && !sameClass) continue;

      domains[v]?.removeWhere(
        (s) => s.day == slot.day && s.startSeconds == slot.startSeconds,
      );

      if (domains[v]?.isEmpty ?? false) return false; // wipe-out detected
    }
    return true;
  }

  // ── Phase 3 — Soft scoring ────────────────────────────────────────────────

  /// Compute a soft penalty score for the complete [assignment].
  /// Lower is better; 0 is optimal. The score is purely informational in the
  /// MVP — the first valid solution found is returned regardless of score.
  int _softScore(Map<_Variable, _Slot> assignment) {
    int score = 0;

    // Gather (startSeconds per day) per teacher and per class.
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

    // Penalty: teacher has a free period between two lessons on the same day.
    // A "gap" is any interval larger than one regular slot+break duration.
    final slotDurSecs =
        (rules.lessonDurationMinutes + rules.breakDurationMinutes) * 60;
    for (final dayMap in teacherDayStarts.values) {
      for (final starts in dayMap.values) {
        if (starts.length < 2) continue;
        final sorted = List<int>.from(starts)..sort();
        for (int i = 1; i < sorted.length; i++) {
          final gap = sorted[i] - sorted[i - 1];
          if (gap > slotDurSecs) score += 2; // free period between lessons
        }
      }
    }

    // Penalty: same subject appears more than once on the same day for a class.
    for (final dayMap in classDaySubjects.values) {
      for (final subjects in dayMap.values) {
        final seen = <int>{};
        for (final subj in subjects) {
          if (!seen.add(subj)) score += 1; // duplicate subject on same day
        }
      }
    }

    // Penalty: highly uneven lesson distribution across active days for a class
    // (variance > 1.5² = 2.25).
    for (final dayMap in classDaySubjects.values) {
      final dayCounts = dayMap.values.map((l) => l.length).toList();
      if (dayCounts.length < 2) continue;

      final mean = dayCounts.reduce((a, b) => a + b) / dayCounts.length;
      final variance =
          dayCounts
              .map((c) => (c - mean) * (c - mean))
              .reduce((a, b) => a + b) /
          dayCounts.length;

      // Compare variance against threshold 1.5² = 2.25.
      if (variance > 2.25) score += 3;
    }

    return score;
  }
}

// ── Top-level compute wrapper ─────────────────────────────────────────────────

/// Input container for [runTimetableGenerator] — all fields are plain Dart
/// types, making this safe to send across isolate boundaries with `compute()`.
class GeneratorInput {
  const GeneratorInput({
    required this.assignments,
    required this.rules,
    this.maxRestarts = 5,
  });

  final List<SolverAssignment> assignments;
  final TimetableRules rules;
  final int maxRestarts;
}

/// Top-level function for use with Flutter's `compute()`.
///
/// Runs [TimetableGenerator.generate()] synchronously on the calling isolate.
/// The Flutter `compute()` helper automatically spawns a background isolate.
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
