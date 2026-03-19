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

  /// The fully solved timetable — one entry per scheduled lesson instance.
  final List<TimetableSlot> slots;

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
/// ### Key behaviours
///
/// * Each [SolverAssignment] produces N [_Variable] instances where
///   N = [TimetableRules.lessonsPerWeekForSubject]. This fills the timetable
///   with appropriately repeated lessons instead of placing each subject only
///   once per week.
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

    final slots = rules.buildSlots();
    if (slots.isEmpty) {
      return GeneratorFailure(
        reason:
            'No time slots available. Check day start/end and lesson duration.',
        conflicts: [],
      );
    }

    // ── Phase 1 — Expand assignments into variables ──────────────────────────
    //
    // Each SolverAssignment produces N _Variable instances (one per weekly
    // lesson occurrence).  The instanceIndex makes them distinct so the domain
    // map and assignment map treat them as independent CSP variables.
    final variables = <_Variable>[];
    for (final a in assignments) {
      final n = rules.lessonsPerWeekForSubject(a.subjectId);
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

      // Build domains for this restart and shuffle for variety.
      final domains = _buildDomains(variables, slots);
      for (final domain in domains.values) {
        domain.shuffle(_random);
      }

      final result = _solve(List<_Variable>.from(variables), {}, domains);

      totalIterations += _iterations;

      if (result != null) {
        // ── Phase 4 — Soft score ─────────────────────────────────────────────
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
          'Try relaxing constraints: fewer lessons per week, more active days, '
          'a longer school day, a higher daily lesson cap, or remove some '
          'teacher/subject block rules.',
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

    final slotsPerDay = slots.length;
    final activeDayCount = rules.activeDays.length;

    // ── Teacher feasibility ──────────────────────────────────────────────────
    // Total lessons each teacher must deliver per week.
    final teacherTotalLessons = <String, int>{};
    for (final a in assignments) {
      final n = rules.lessonsPerWeekForSubject(a.subjectId);
      teacherTotalLessons[a.teacherUserId] =
          (teacherTotalLessons[a.teacherUserId] ?? 0) + n;
    }

    final teacherMaxPerWeek = rules.maxLessonsPerDayTeacher * activeDayCount;

    for (final entry in teacherTotalLessons.entries) {
      // Check that they aren't fully blocked.
      var hasAnySlot = false;
      outer:
      for (final day in rules.activeDays) {
        for (final slot in slots) {
          final blocked = rules.teacherBlocks.any(
            (r) =>
                r.teacherUserId == entry.key &&
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
          'Teacher ${entry.key} has all slots blocked by block rules and '
          'cannot be scheduled.',
        );
        continue;
      }

      // Check that the weekly lesson count fits within the daily cap.
      if (entry.value > teacherMaxPerWeek) {
        issues.add(
          'Teacher ${entry.key} must deliver ${entry.value} lessons per week '
          'but the cap allows at most $teacherMaxPerWeek '
          '(${rules.maxLessonsPerDayTeacher}/day × $activeDayCount days). '
          'Reduce their subject load, increase the daily teacher cap, or '
          'add more active days.',
        );
      }
    }

    // ── Class feasibility ────────────────────────────────────────────────────
    // Total lessons each class (grade+stream) must receive per week.
    final classTotalLessons = <(int, int), int>{}; // (grade, stream) → count
    for (final a in assignments) {
      final key = (a.grade, a.stream);
      final n = rules.lessonsPerWeekForSubject(a.subjectId);
      classTotalLessons[key] = (classTotalLessons[key] ?? 0) + n;
    }

    final classMaxPerWeek = rules.maxLessonsPerDayClass * activeDayCount;
    final totalSlotsAvailable = slotsPerDay * activeDayCount;

    for (final entry in classTotalLessons.entries) {
      if (entry.value > classMaxPerWeek) {
        issues.add(
          'Class (grade=${entry.key.$1}, stream=${entry.key.$2}) requires '
          '${entry.value} lessons per week but the cap allows at most '
          '$classMaxPerWeek (${rules.maxLessonsPerDayClass}/day × '
          '$activeDayCount days). Reduce subjects or lessons per week, or '
          'increase the daily class cap.',
        );
      }

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

    // MRV heuristic — pick the variable with the fewest remaining domain
    // values.  Tie-break by degree (most constraints with unassigned peers)
    // could be added later; for now the shuffle in generate() provides enough
    // variety across restarts.
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

      // Deep-copy domains for forward checking.
      final newDomains = <_Variable, List<_Slot>>{};
      for (final entry in domains.entries) {
        newDomains[entry.key] = List<_Slot>.from(entry.value);
      }

      // Forward checking: propagate constraints to peers.
      // Pass newAssignment so _propagate can enforce daily-cap pruning.
      final pruneOk = _propagate(
        variable,
        slot,
        remaining,
        newDomains,
        newAssignment,
      );
      if (!pruneOk) continue; // wipe-out detected — skip this value.

      final result = _solve(remaining, newAssignment, newDomains);
      if (result != null) return result;
    }

    return null;
  }

  // ── Consistency check ─────────────────────────────────────────────────────

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

      if (s.day != slot.day) continue;

      // 1. Teacher double-booking: same teacher, same time, same day.
      if (v.teacherUserId == variable.teacherUserId &&
          s.startSeconds == slot.startSeconds) {
        return false;
      }

      // 2. Class double-booking: same grade+stream, same time, same day.
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

      // 5. Double-lesson check: same subject, same class, same day →
      //    disallow when allowDoubles is false.  Comparing by subjectId only
      //    (not instanceIndex) is intentional — we want to spread all N
      //    instances of the same subject across different days.
      if (!rules.allowDoubles &&
          v.grade == variable.grade &&
          v.stream == variable.stream &&
          v.subjectId == variable.subjectId) {
        return false;
      }
    }

    // 6. Teacher daily load cap.
    if (teacherDayCount >= rules.maxLessonsPerDayTeacher) return false;

    // 7. Class daily load cap.
    if (classDayCount >= rules.maxLessonsPerDayClass) return false;

    return true;
  }

  // ── Forward-checking propagation ──────────────────────────────────────────

  /// Propagates constraints after placing [placed] at [slot].
  ///
  /// Two layers of pruning:
  ///
  /// **Layer 1 — Exact slot removal.**
  /// Removes the exact (day, startSeconds) pair from every peer that shares
  /// the same teacher or the same (grade, stream).
  ///
  /// **Layer 2 — Daily-cap pruning.**
  /// Counts how many lessons the teacher / class already has on [slot.day]
  /// in [assignment] (including the just-placed variable).  If the count
  /// reaches the configured cap, ALL remaining slots on that day are pruned
  /// from teacher/class peers.  This prevents the solver from wasting
  /// thousands of iterations on branches that are doomed to fail the cap
  /// check in [_isConsistent].
  ///
  /// Returns `false` if any peer's domain becomes empty (wipe-out), signalling
  /// that this branch cannot lead to a solution.
  bool _propagate(
    _Variable placed,
    _Slot slot,
    List<_Variable> remaining,
    Map<_Variable, List<_Slot>> domains,
    Map<_Variable, _Slot> assignment,
  ) {
    // ── Pre-compute daily counts from the full assignment ─────────────────
    // The assignment already includes the just-placed variable (newAssignment
    // in _solve), so we count all lessons for this teacher / class on this day
    // including the one we just placed.
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

    final teacherAtCap = teacherDayCount >= rules.maxLessonsPerDayTeacher;
    final classAtCap = classDayCount >= rules.maxLessonsPerDayClass;

    // ── Prune peer domains ────────────────────────────────────────────────
    for (final v in remaining) {
      final sameTeacher = v.teacherUserId == placed.teacherUserId;
      final sameClass = v.grade == placed.grade && v.stream == placed.stream;

      if (!sameTeacher && !sameClass) continue;

      final domain = domains[v];
      if (domain == null) continue;

      // Layer 1: remove the exact placed (day, startSeconds).
      domain.removeWhere(
        (s) => s.day == slot.day && s.startSeconds == slot.startSeconds,
      );

      // Layer 2: if the teacher or class has hit their daily cap, prune ALL
      // remaining slots on this day for this peer.
      if (sameTeacher && teacherAtCap) {
        domain.removeWhere((s) => s.day == slot.day);
      }
      if (sameClass && classAtCap) {
        domain.removeWhere((s) => s.day == slot.day);
      }

      if (domain.isEmpty) return false; // wipe-out detected
    }

    return true;
  }

  // ── Phase 3 — Soft scoring ────────────────────────────────────────────────

  /// Compute a soft penalty score for the complete [assignment].
  /// Lower is better; 0 is optimal.  The score is informational — the first
  /// valid solution found per restart is returned regardless of score.
  int _softScore(Map<_Variable, _Slot> assignment) {
    int score = 0;

    // Gather per-teacher and per-class day statistics.
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

    // Penalty: teacher has a free period (gap) between two lessons on the same
    // day.  A "gap" is any interval larger than one regular slot+break.
    final slotDurSecs =
        (rules.lessonDurationMinutes + rules.breakDurationMinutes) * 60;
    for (final dayMap in teacherDayStarts.values) {
      for (final starts in dayMap.values) {
        if (starts.length < 2) continue;
        final sorted = List<int>.from(starts)..sort();
        for (int i = 1; i < sorted.length; i++) {
          final gap = sorted[i] - sorted[i - 1];
          if (gap > slotDurSecs) score += 2;
        }
      }
    }

    // Penalty: same subject appears more than once on the same day for a class
    // (only relevant when allowDoubles is true, but we score it regardless).
    for (final dayMap in classDaySubjects.values) {
      for (final subjects in dayMap.values) {
        final seen = <int>{};
        for (final subj in subjects) {
          if (!seen.add(subj)) score += 1;
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

      if (variance > 2.25) score += 3;
    }

    // Penalty: teacher teaches the same subject to multiple classes on the
    // same day at different times — increases travel/prep burden.
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
