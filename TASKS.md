# TASKS.md

---

## Timetable Generation — Full Implementation

### Overview

Replace the two-tab (`Schedule` / `Rules`) timetable screen for owners with a single unified schedule view plus a green FAB that opens a rules dialog/sheet. Implement a full pure-Dart **backtracking CSP solver** with domain-reduction pre-processing, forward-checking propagation, and a soft-scoring post-pass. Add per-teacher and per-subject block-window rules on top of the existing global rules.

**Tracks:**

- **Track A** — Data & Model layer (new model file, DAO additions)
- **Track B** — Solver engine (`lib/services/timetable_generator.dart`)
- **Track C** — UI overhaul (`timetable_screen.dart` refactor + rules sheet)

Track A must complete before Track B. Track B must complete before Track C.

---

## Track A — Data & Model Layer

### Task A1: Create `TimetableRules` model

**Files to create:** `lib/models/timetable_rules.dart`
**Files to modify:** `lib/models/CONTEXT.md`
**Depends on:** nothing
**Parallel group:** A

**Specification:**

Create a pure Dart model `TimetableRules` in `lib/models/timetable_rules.dart`. This replaces the private `_TimetableRules` class currently defined inline inside `timetable_screen.dart`. The new class must be a proper public model, serialisable to/from JSON, so it can be persisted to the local filesystem.

Import only `dart:convert` and `lib/database/tables/enums.dart` (for `DayOfWeek`).

```dart
import 'dart:convert';
import '../database/tables/enums.dart';

/// Global timetable generation rules — applies to the entire school for one term.
///
/// Persisted as JSON in the app documents directory at:
///   {appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json
class TimetableRules {
  TimetableRules({
    this.dayStartSeconds = 8 * 3600,        // 08:00
    this.dayEndSeconds   = 16 * 3600,       // 16:00
    this.lessonDurationMinutes  = 40,
    this.breakDurationMinutes   = 10,
    this.lunchStartSeconds      = 12 * 3600 + 30 * 60, // 12:30
    this.lunchDurationMinutes   = 60,
    this.maxLessonsPerDayTeacher = 6,
    this.maxLessonsPerDayClass   = 8,
    this.allowDoubles = false,
    List<DayOfWeek>? activeDays,
    List<TeacherBlockRule>? teacherBlocks,
    List<SubjectBlockRule>? subjectBlocks,
  })  : activeDays    = activeDays    ?? [DayOfWeek.monday, DayOfWeek.tuesday, DayOfWeek.wednesday, DayOfWeek.thursday, DayOfWeek.friday],
        teacherBlocks = teacherBlocks ?? [],
        subjectBlocks = subjectBlocks ?? [];

  // ── Global time config ───────────────────────────────────────────────────
  int dayStartSeconds;
  int dayEndSeconds;
  int lessonDurationMinutes;
  int breakDurationMinutes;
  int lunchStartSeconds;
  int lunchDurationMinutes;

  // ── Global load constraints ──────────────────────────────────────────────
  int maxLessonsPerDayTeacher;
  int maxLessonsPerDayClass;
  bool allowDoubles;          // allow back-to-back lessons for the same subject in same class

  // ── Active days ──────────────────────────────────────────────────────────
  List<DayOfWeek> activeDays;

  // ── Per-entity block windows ─────────────────────────────────────────────
  List<TeacherBlockRule> teacherBlocks;
  List<SubjectBlockRule> subjectBlocks;

  // ── Derived helpers ──────────────────────────────────────────────────────

  /// Generates the ordered list of (start, end) slot pairs in seconds-since-midnight
  /// for a school day, excluding the lunch window.
  List<({int start, int end})> buildSlots() {
    final slots = <({int start, int end})>[];
    int cursor = dayStartSeconds;
    final slotSecs  = lessonDurationMinutes * 60;
    final breakSecs = breakDurationMinutes  * 60;
    final lunchEnd  = lunchStartSeconds + lunchDurationMinutes * 60;

    while (cursor + slotSecs <= dayEndSeconds) {
      final end = cursor + slotSecs;
      // Skip if this slot overlaps the lunch window.
      final overlapLunch = cursor < lunchEnd && end > lunchStartSeconds;
      if (!overlapLunch) {
        slots.add((start: cursor, end: end));
      }
      // Advance past lunch if needed.
      if (end > lunchStartSeconds && cursor < lunchEnd) {
        cursor = lunchEnd;
      } else {
        cursor = end + breakSecs;
      }
    }
    return slots;
  }

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'day_start':             dayStartSeconds,
        'day_end':               dayEndSeconds,
        'lesson_duration':       lessonDurationMinutes,
        'break_duration':        breakDurationMinutes,
        'lunch_start':           lunchStartSeconds,
        'lunch_duration':        lunchDurationMinutes,
        'max_lessons_teacher':   maxLessonsPerDayTeacher,
        'max_lessons_class':     maxLessonsPerDayClass,
        'allow_doubles':         allowDoubles,
        'active_days':           activeDays.map((d) => d.index).toList(),
        'teacher_blocks':        teacherBlocks.map((b) => b.toJson()).toList(),
        'subject_blocks':        subjectBlocks.map((b) => b.toJson()).toList(),
      };

  factory TimetableRules.fromJson(Map<String, dynamic> json) => TimetableRules(
        dayStartSeconds:          (json['day_start']           as int?) ?? 8 * 3600,
        dayEndSeconds:            (json['day_end']             as int?) ?? 16 * 3600,
        lessonDurationMinutes:    (json['lesson_duration']     as int?) ?? 40,
        breakDurationMinutes:     (json['break_duration']      as int?) ?? 10,
        lunchStartSeconds:        (json['lunch_start']         as int?) ?? (12 * 3600 + 30 * 60),
        lunchDurationMinutes:     (json['lunch_duration']      as int?) ?? 60,
        maxLessonsPerDayTeacher:  (json['max_lessons_teacher'] as int?) ?? 6,
        maxLessonsPerDayClass:    (json['max_lessons_class']   as int?) ?? 8,
        allowDoubles:             (json['allow_doubles']       as bool?) ?? false,
        activeDays: ((json['active_days'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5])
            .map((i) => DayOfWeek.values[i])
            .toList(),
        teacherBlocks: ((json['teacher_blocks'] as List?) ?? [])
            .map((e) => TeacherBlockRule.fromJson(e as Map<String, dynamic>))
            .toList(),
        subjectBlocks: ((json['subject_blocks'] as List?) ?? [])
            .map((e) => SubjectBlockRule.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory TimetableRules.defaults() => TimetableRules();

  String toJsonString() => jsonEncode(toJson());
  factory TimetableRules.fromJsonString(String s) =>
      TimetableRules.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// A time window on specific days during which a teacher must NOT be scheduled.
///
/// Example: "Teacher X is unavailable on Monday and Tuesday between 08:00 and 10:00"
///   → teacherUserId = 'abc', days = [monday, tuesday],
///     startSeconds = 8*3600, endSeconds = 10*3600
class TeacherBlockRule {
  const TeacherBlockRule({
    required this.teacherUserId,
    required this.days,
    required this.startSeconds,  // seconds since midnight — inclusive
    required this.endSeconds,    // seconds since midnight — exclusive
  });

  final String teacherUserId;
  final List<DayOfWeek> days;
  final int startSeconds;
  final int endSeconds;

  /// Returns true if this rule blocks the teacher in the given (day, slotStart, slotEnd).
  bool blocks(DayOfWeek day, int slotStart, int slotEnd) {
    if (!days.contains(day)) return false;
    // Overlap check: slot overlaps the blocked window if slotStart < blockEnd && slotEnd > blockStart
    return slotStart < endSeconds && slotEnd > startSeconds;
  }

  Map<String, dynamic> toJson() => {
        'teacher': teacherUserId,
        'days':    days.map((d) => d.index).toList(),
        'start':   startSeconds,
        'end':     endSeconds,
      };

  factory TeacherBlockRule.fromJson(Map<String, dynamic> json) => TeacherBlockRule(
        teacherUserId: json['teacher'] as String,
        days: ((json['days'] as List).cast<int>()).map((i) => DayOfWeek.values[i]).toList(),
        startSeconds:  json['start'] as int,
        endSeconds:    json['end']   as int,
      );
}

/// A restriction on when a subject (by its global catalog ID) may be scheduled.
///
/// Example: "PE (subject 12) may only appear on Wednesday and Friday"
///   → subjectId = 12, allowedDays = [wednesday, friday], no time restriction
///
/// Example: "Chemistry (subject 5) must not appear after 14:00"
///   → subjectId = 5, blockedAfterSeconds = 14*3600
class SubjectBlockRule {
  const SubjectBlockRule({
    required this.subjectId,
    this.allowedDays,           // null = no day restriction
    this.blockedAfterSeconds,   // null = no time restriction
    this.blockedBeforeSeconds,  // null = no time restriction
  });

  final int subjectId;
  final List<DayOfWeek>? allowedDays;
  final int? blockedAfterSeconds;
  final int? blockedBeforeSeconds;

  /// Returns true if this rule blocks the subject in the given (day, slotStart, slotEnd).
  bool blocks(DayOfWeek day, int slotStart, int slotEnd) {
    if (allowedDays != null && !allowedDays!.contains(day)) return true;
    if (blockedAfterSeconds  != null && slotStart >= blockedAfterSeconds!)  return true;
    if (blockedBeforeSeconds != null && slotEnd   <= blockedBeforeSeconds!) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'subject': subjectId,
        if (allowedDays        != null) 'allowed_days':    allowedDays!.map((d) => d.index).toList(),
        if (blockedAfterSeconds  != null) 'blocked_after':  blockedAfterSeconds,
        if (blockedBeforeSeconds != null) 'blocked_before': blockedBeforeSeconds,
      };

  factory SubjectBlockRule.fromJson(Map<String, dynamic> json) => SubjectBlockRule(
        subjectId: json['subject'] as int,
        allowedDays: (json['allowed_days'] as List?)
            ?.cast<int>()
            .map((i) => DayOfWeek.values[i])
            .toList(),
        blockedAfterSeconds:  json['blocked_after']  as int?,
        blockedBeforeSeconds: json['blocked_before'] as int?,
      );
}
```

**After creating the file:**
- [ ] Update `lib/models/CONTEXT.md` — add `timetable_rules.dart` entry to the Files table with key exports `TimetableRules`, `TeacherBlockRule`, `SubjectBlockRule` and status ✅ Complete.
- [ ] Mark this task `[x]`.

---

### [x] Task A2: Add `TimetableRulesPersistence` to `FileCache`

**Files to modify:** `lib/cache/file_cache.dart`, `lib/cache/CONTEXT.md`
**Depends on:** Task A1
**Parallel group:** A (serial after A1)

**Specification:**

`FileCache` already manages paths for profile images, student images, and school logos. Extend it with two new methods for loading and saving `TimetableRules` JSON to the local filesystem.

The path convention (consistent with §8 of AGENT.md):
```
{appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json
```

Add the following two static methods to the `FileCache` class:

```dart
import '../models/timetable_rules.dart'; // add to imports at top of file_cache.dart

/// Loads persisted [TimetableRules] for a school term from the local filesystem.
/// Returns [TimetableRules.defaults()] if no file exists yet.
static Future<TimetableRules> loadTimetableRules({
  required String schoolId,
  required int year,
  required int term,
}) async {
  final dir  = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/schools/$schoolId/timetable_rules_${year}_$term.json');
  if (!await file.exists()) return TimetableRules.defaults();
  try {
    final contents = await file.readAsString();
    return TimetableRules.fromJsonString(contents);
  } catch (_) {
    return TimetableRules.defaults();
  }
}

/// Persists [TimetableRules] for a school term to the local filesystem.
static Future<void> saveTimetableRules({
  required String schoolId,
  required int year,
  required int term,
  required TimetableRules rules,
}) async {
  final dir  = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/schools/$schoolId/timetable_rules_${year}_$term.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(rules.toJsonString());
}
```

Make sure `dart:io` and `path_provider` are already imported in `file_cache.dart` (they should be — check first and only add if missing).

**After modifying the file:**
- [x] Update `lib/cache/CONTEXT.md` — add `loadTimetableRules` and `saveTimetableRules` to the `FileCache` methods list.
- [x] Mark this task `[x]`.

---

### Task A3: Add `getSubjectTeachersForTerm` to `TimetableDao`

**Files to modify:** `lib/database/daos/timetable_dao.dart`, `lib/database/daos/CONTEXT.md`
**Depends on:** nothing
**Parallel group:** A

**Specification:**

The solver needs a one-shot read of all `subject_teachers` rows for a term, enriched with the subject name. This is a non-reactive read — the solver calls it once before running.

Add the following import at the top of `timetable_dao.dart` (it may already be present — check first):
```dart
import '../tables/subject_teachers.dart';
```

Add this data class near the bottom of `timetable_dao.dart` (after `LessonEntry`):

```dart
/// One subject-teacher assignment — input record for the timetable solver.
class SolverAssignment {
  const SolverAssignment({
    required this.school,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.subjectId,
    required this.subjectName,
    required this.teacherUserId,
  });

  final String school;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final int subjectId;
  final String subjectName;
  final String teacherUserId;
}
```

Add this method to `TimetableDao` (inside the class body, after `hasTimetable`):

```dart
/// Returns all subject-teacher assignments for a term, enriched with the subject name.
///
/// This is the primary input to the timetable solver.
Future<List<SolverAssignment>> getSubjectTeachersForTerm({
  required String schoolId,
  required int year,
  required int term,
}) async {
  final query = select(subjectTeachers).join([
    leftOuterJoin(subjects, subjects.id.equalsExp(subjectTeachers.subject)),
  ])
    ..where(
      subjectTeachers.school.equals(schoolId) &
      subjectTeachers.year.equals(year) &
      subjectTeachers.term.equals(term),
    )
    ..orderBy([
      OrderingTerm.asc(subjectTeachers.grade),
      OrderingTerm.asc(subjectTeachers.stream),
      OrderingTerm.asc(subjectTeachers.subject),
    ]);

  final rows = await query.get();
  return rows.map((r) {
    final st  = r.readTable(subjectTeachers);
    final sub = r.readTableOrNull(subjects);
    return SolverAssignment(
      school:         st.school,
      year:           st.year,
      term:           st.term,
      grade:          st.grade,
      stream:         st.stream,
      subjectId:      st.subject,
      subjectName:    sub?.name ?? 'Subject ${st.subject}',
      teacherUserId:  st.teacher,
    );
  }).toList();
}
```

`TimetableDao` is already annotated with `@DriftAccessor(tables: [Timetable, Lessons, Subjects, Users, Logs])`. Add `SubjectTeachers` to that list:

```dart
@DriftAccessor(tables: [Timetable, Lessons, Subjects, SubjectTeachers, Users, Logs])
```

Then run code generation:
```
cd eduxal && dart run build_runner build --delete-conflicting-outputs
```

**After modifying:**
- [x] Update `lib/database/daos/CONTEXT.md` — add `getSubjectTeachersForTerm` to the `TimetableDao` section and note `SolverAssignment` data class.
- [x] Mark this task `[x]`.

---

## Track B — Solver Engine

### [x] Task B1: Implement `TimetableGenerator` (CSP backtracking solver)

**Files to create:** `lib/services/timetable_generator.dart`
**Files to modify:** `lib/services/CONTEXT.md`
**Depends on:** Task A1 (for `TimetableRules`), Task A3 (for `SolverAssignment`)
**Parallel group:** B

**Specification:**

Create `lib/services/timetable_generator.dart`. This is the pure-Dart backtracking CSP solver. It has **no Flutter dependency** — only `dart:math` and project model/DAO imports.

The file must be self-contained. Do NOT import any UI package. Do NOT call any DAO inside the generator — all input data is passed via constructor.

#### Key types (defined in this file)

```dart
/// One solved assignment — maps a (class, subject) pair to a specific time slot.
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
  final List<TimetableSlot> slots;
  final int softScore;          // lower is better; 0 = optimal
  final int iterations;         // how many backtracks occurred
  final Duration elapsed;
  GeneratorSuccess({required this.slots, required this.softScore, required this.iterations, required this.elapsed});
}

final class GeneratorFailure extends GeneratorResult {
  final String reason;          // human-readable explanation for the user
  final List<String> conflicts; // specific unsatisfiable constraints, if detected
  GeneratorFailure({required this.reason, required this.conflicts});
}
```

#### Algorithm — Three Phases

**Phase 0 — Input validation**

Before solving, check:
1. `assignments` list is not empty.
2. `rules.activeDays` is not empty.
3. `rules.buildSlots()` returns at least 1 slot.
4. No teacher has ALL their slots blocked by `teacherBlocks` rules. If one does, return `GeneratorFailure` immediately with a human-readable message identifying the teacher.

**Phase 1 — Domain construction**

Build the **variable** list and the **domain** for each variable.

A _variable_ is one `(grade, stream, subjectId)` tuple. Each variable needs exactly one slot assignment per scheduled occurrence. Since subjects are weekly recurring, each variable needs N slots total, where N is computed as `ceil(assignments_for_class.length / slots_per_day * days_active)` — but more practically, assign **exactly 1 slot per week per assignment** (one row in `subject_teachers` = one lesson per week).

So: one variable = one (grade, stream, subjectId) = one required slot per week.

The domain for a variable is the Cartesian product of `activeDays × buildSlots()`, filtered by:
1. **Teacher block rules:** Remove any (day, slot) where `TeacherBlockRule.blocks(day, slotStart, slotEnd)` is true for this variable's teacher.
2. **Subject block rules:** Remove any (day, slot) where `SubjectBlockRule.blocks(day, slotStart, slotEnd)` is true for this variable's subject.
3. **Double-lesson rule:** If `allowDoubles == false`, the domain values are not yet filtered here — doubles are checked during propagation.

Shuffle each variable's domain randomly (using `dart:math` `Random`) before solving. This ensures different runs produce different schedules and avoids always picking the same slots.

**MRV heuristic:** Sort the variables list so that variables with the smallest domain come first. Re-apply MRV dynamically during search by always picking the unassigned variable with the fewest remaining domain values.

**Phase 2 — Backtracking search with forward checking**

Implement recursive backtracking with forward checking:

```
solve(unassigned, assignment, remainingDomains):
  if unassigned is empty → return assignment (success)

  // MRV: pick variable with fewest remaining domain values
  variable = argmin(unassigned, key: remainingDomains[v].length)

  if remainingDomains[variable].isEmpty → return null (backtrack)

  for each (day, slot) in remainingDomains[variable]:
    if isConsistent(variable, day, slot, assignment):
      assignment[variable] = (day, slot)
      savedDomains = deepCopy(remainingDomains)

      // Forward checking: eliminate this (day, slot) from peers
      pruned = propagate(variable, day, slot, unassigned, remainingDomains)

      if pruned:  // no peer domain was wiped out
        result = solve(unassigned - {variable}, assignment, remainingDomains)
        if result != null → return result

      // Backtrack: restore domains
      remainingDomains = savedDomains
      assignment.remove(variable)

  return null  // all values exhausted — backtrack further
```

**`isConsistent` checks (hard constraints):**
1. **Teacher double-booking:** No other variable already assigned to this teacher has the same `(day, slot.start)`.
2. **Class double-booking:** No other variable for the same `(grade, stream)` has the same `(day, slot.start)`.
3. **Max lessons per day (teacher):** Count existing assignments for this teacher on `day`. Must be `< maxLessonsPerDayTeacher`.
4. **Max lessons per day (class):** Count existing assignments for `(grade, stream)` on `day`. Must be `< maxLessonsPerDayClass`.
5. **Double-lesson rule:** If `allowDoubles == false`, no other variable for the same `(grade, stream, subjectId)` is already assigned immediately before or after this slot on the same day.

**`propagate` (forward checking):**
After placing variable V at `(day, slot)`, for every other unassigned variable U:
- If U shares the same teacher as V → remove `(day, slot.start)` from `remainingDomains[U]`.
- If U shares the same `(grade, stream)` as V → remove `(day, slot.start)` from `remainingDomains[U]`.
- If any `remainingDomains[U]` becomes empty → return `false` (wipe-out detected, prune this branch).

Return `true` if propagation succeeded (no wipe-out).

**Restart strategy:**
The solver runs the backtracking search up to `maxRestarts = 5` times, each time with a freshly shuffled domain order. On each restart, the teacher blocks and subject blocks are re-applied to the original full domain, then re-shuffled. If any restart produces a solution, return immediately. If all restarts fail, return `GeneratorFailure`.

**Phase 3 — Soft scoring**

After a valid solution is found, compute a soft score (lower = better):

| Soft penalty | Points |
|---|---|
| Teacher has a free period between two lessons on the same day | +2 per gap |
| A class has the same subject twice on the same day (doubles allowed but non-ideal) | +1 per pair |
| Active days have very uneven lesson counts for a class (stddev > 1.5) | +3 |

The score is returned in `GeneratorSuccess.softScore` for informational display. No re-solving is done based on soft score in the MVP.

#### `TimetableGenerator` class

```dart
class TimetableGenerator {
  TimetableGenerator({
    required this.assignments,   // from TimetableDao.getSubjectTeachersForTerm()
    required this.rules,         // from FileCache.loadTimetableRules() or UI input
    this.maxRestarts = 5,
  });

  final List<SolverAssignment> assignments;
  final TimetableRules rules;
  final int maxRestarts;

  // Entry point — runs on an isolate-friendly synchronous call.
  // The UI should call this inside `compute()` to avoid blocking the main thread.
  GeneratorResult generate();

  // Internal helpers (private):
  // _buildDomains() → Map<_Variable, List<_Slot>>
  // _solve(...) → Map<_Variable, _Slot>?
  // _isConsistent(...) → bool
  // _propagate(...) → bool
  // _softScore(...) → int
  // _validate() → List<String>  (returns conflict messages; empty = valid)
}
```

`_Variable` and `_Slot` are private helper value types:
```dart
// Private — only used inside the solver
class _Variable {
  const _Variable({required this.grade, required this.stream, required this.subjectId, required this.teacherUserId});
  final int grade;
  final int stream;
  final int subjectId;
  final String teacherUserId;

  @override bool operator ==(Object other) => other is _Variable && grade == other.grade && stream == other.stream && subjectId == other.subjectId;
  @override int get hashCode => Object.hash(grade, stream, subjectId);
}

class _Slot {
  const _Slot({required this.day, required this.startSeconds, required this.endSeconds});
  final DayOfWeek day;
  final int startSeconds;
  final int endSeconds;

  @override bool operator ==(Object other) => other is _Slot && day == other.day && startSeconds == other.startSeconds;
  @override int get hashCode => Object.hash(day, startSeconds);
}
```

#### `compute` wrapper

Add a top-level function (outside the class) for use with Flutter's `compute()`:

```dart
/// Top-level function for use with Flutter `compute()`.
/// Runs [TimetableGenerator.generate()] on a background isolate.
///
/// Usage:
///   final result = await compute(runTimetableGenerator, GeneratorInput(...));
GeneratorResult runTimetableGenerator(GeneratorInput input) {
  return TimetableGenerator(
    assignments: input.assignments,
    rules: input.rules,
    maxRestarts: input.maxRestarts,
  ).generate();
}

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
```

**Imports required:**
```dart
import 'dart:math';
import '../database/tables/enums.dart';
import '../database/daos/timetable_dao.dart' show SolverAssignment;
import '../models/timetable_rules.dart';
```

**After creating the file:**
- [x] Update `lib/services/CONTEXT.md` — add `timetable_generator.dart` entry with key exports: `TimetableGenerator`, `TimetableSlot`, `GeneratorResult`, `GeneratorSuccess`, `GeneratorFailure`, `GeneratorInput`, `runTimetableGenerator`. Status: ✅ Complete.
- [x] Mark this task `[x]`.

---

## Track C — UI Overhaul

### Task C1: Refactor `_OwnerTimetableShell` — remove tabs, add FAB

**Files to modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Files to modify:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task A1 (TimetableRules model), Task A2 (FileCache persistence), Task B1 (solver)
**Parallel group:** C (serial — this is the main file)

**Specification:**

This is the largest task. It involves removing the two-tab layout from `_OwnerTimetableShell` and restructuring the entire owner flow. Read the existing file carefully (all 2,455 lines) before making changes.

#### Step 1 — Remove tab infrastructure

In `_OwnerTimetableShellState`:
- Remove `late final TabController _tabController`.
- Remove `SingleTickerProviderStateMixin`.
- Remove `_tabController.dispose()` from `dispose()`.
- Remove `TabController(length: 2, vsync: this)` from `initState()`.

In `_OwnerTimetableShell.build`:
- Remove the `EduTabBar(...)` widget with `['Schedule', 'Rules']`.
- Remove the `TabBarView(...)` wrapper.
- The owner shell now renders only the schedule view directly (i.e. `_OwnerScheduleTab`), plus a `Scaffold` with a `floatingActionButton`.

The new `build` structure for `_OwnerTimetableShellState`:

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  if (_config == null || _rules == null) {
    return Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)));
  }

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: _OwnerScheduleTab(
      schoolContext: widget.schoolContext,
      termContext: widget.termContext,
      config: _config!,
      timetableDao: _timetableDao,
      selectedGrade: _selectedGrade,
      selectedStream: _selectedStream,
      onClassSelected: (grade, stream) => setState(() { _selectedGrade = grade; _selectedStream = stream; }),
    ),
    floatingActionButton: _GenerateFab(
      onTap: _openRulesSheet,
      generating: _generating,
      cs: cs,
    ),
  );
}
```

#### Step 2 — Add state fields for rules and generation

In `_OwnerTimetableShellState`, add:

```dart
TimetableRules? _rules;
bool _generating = false;
```

Update `_loadConfig()` to also load rules via `FileCache.loadTimetableRules`:

```dart
Future<void> _loadConfig() async {
  final term = widget.termContext.currentTerm;
  final schoolId = widget.schoolContext.membership.school.id;
  final rules = term != null
      ? await FileCache.loadTimetableRules(schoolId: schoolId, year: term.year, term: term.term)
      : TimetableRules.defaults();
  if (mounted) setState(() {
    _config = SchoolConfig.defaults();
    _rules = rules;
  });
}
```

Add `_openRulesSheet()`:

```dart
Future<void> _openRulesSheet() async {
  final term = widget.termContext.currentTerm;
  if (term == null || _rules == null) return;

  final result = await showEduSheet<_RulesSheetResult>(
    context: context,
    child: _RulesSheet(
      initialRules: _rules!,
      schoolContext: widget.schoolContext,
      termContext: widget.termContext,
    ),
  );

  if (result == null || !mounted) return;

  // Persist the rules.
  await FileCache.saveTimetableRules(
    schoolId: widget.schoolContext.membership.school.id,
    year: term.year,
    term: term.term,
    rules: result.rules,
  );
  setState(() => _rules = result.rules);

  if (result.shouldGenerate) {
    await _runGeneration(result.rules);
  }
}
```

Add `_runGeneration()`:

```dart
Future<void> _runGeneration(TimetableRules rules) async {
  final term = widget.termContext.currentTerm;
  if (term == null || _generating) return;

  setState(() => _generating = true);

  try {
    final schoolId = widget.schoolContext.membership.school.id;

    // 1. Load all subject-teacher assignments for this term.
    final assignments = await _timetableDao.getSubjectTeachersForTerm(
      schoolId: schoolId,
      year: term.year,
      term: term.term,
    );

    if (assignments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No subjects assigned for this term. Assign subjects first.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ));
      }
      return;
    }

    // 2. Run solver on a background isolate.
    final input = GeneratorInput(assignments: assignments, rules: rules);
    final result = await compute(runTimetableGenerator, input);

    if (!mounted) return;

    if (result is GeneratorFailure) {
      // Show failure with conflict details.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not generate timetable: ${result.reason}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
      ));
      return;
    }

    final success = result as GeneratorSuccess;

    // 3. Get active account id.
    final account = cache.currentUser;
    if (account == null) return;

    // 4. Convert GeneratorSuccess.slots → TimetableCompanion list.
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
    final companions = success.slots.map((s) => TimetableCompanion(
      school:  Value(s.school),
      year:    Value(s.year),
      term:    Value(s.term),
      grade:   Value(s.grade),
      stream:  Value(s.stream),
      subject: Value(s.subjectId),
      teacher: Value(s.teacherUserId),
      day:     Value(s.day),
      start:   Value(s.startSeconds),
      end:     Value(s.endSeconds),
      created: Value(now),
      updated: Value(now),
    )).toList();

    // 5. Clear existing timetable for the term, then bulk-insert new slots.
    //    Clear is done class-by-class to write per-class delete logs.
    //    Group slots by (grade, stream) first.
    final byClass = <({int grade, int stream}), List<TimetableCompanion>>{};
    for (final c in companions) {
      final key = (grade: c.grade.value, stream: c.stream.value);
      byClass.putIfAbsent(key, () => []).add(c);
    }

    for (final entry in byClass.entries) {
      await _timetableDao.clearClassTimetable(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        grade: entry.key.grade,
        stream: entry.key.stream,
        accountId: account.user.id,
      );
    }

    await _timetableDao.insertSlots(
      slots: companions,
      accountId: account.user.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Timetable generated — ${success.slots.length} slots (${success.iterations} iterations, ${success.elapsed.inMilliseconds}ms)'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ));
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Generation error: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ));
    }
  } finally {
    if (mounted) setState(() => _generating = false);
  }
}
```

#### Step 3 — Replace `_RulesTab` with `_RulesSheet`

Delete the following classes entirely from `timetable_screen.dart`:
- `_RulesTab` (StatefulWidget)
- `_RulesTabState` (State)
- `_RulesActionBar`
- `_ActionButton`
- `_GenerateButton` (old version — will be replaced by `_GenerateFab`)

Keep all the rule sub-component widgets — they are reused inside the new sheet:
- `_TimetableRules` → **delete** (replaced by `lib/models/timetable_rules.dart`)
- `_RulesSection` — **keep**
- `_RuleRow` — **keep**
- `_TimePickerButton` — **keep**
- `_StepperControl` — **keep**
- `_StepBtn` — **keep**
- `_DayToggle` — **keep**

Add the result class:

```dart
class _RulesSheetResult {
  const _RulesSheetResult({required this.rules, required this.shouldGenerate});
  final TimetableRules rules;
  final bool shouldGenerate;
}
```

Add `_RulesSheet` as a new StatefulWidget:

```dart
/// Bottom sheet / dialog that lets an owner configure timetable rules and
/// then optionally trigger generation.
///
/// Returns a [_RulesSheetResult] via Navigator.pop when the user taps
/// "Save" or "Generate". Returns null if the user dismisses.
class _RulesSheet extends StatefulWidget {
  const _RulesSheet({
    required this.initialRules,
    required this.schoolContext,
    required this.termContext,
  });

  final TimetableRules initialRules;
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_RulesSheet> createState() => _RulesSheetState();
}

class _RulesSheetState extends State<_RulesSheet> {
  late TimetableRules _rules;
  bool _dirty = false;
  // Active tab index: 0=Global, 1=Teachers, 2=Subjects
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Deep-copy the initial rules so the original is not mutated until saved.
    _rules = TimetableRules.fromJson(widget.initialRules.toJson());
  }

  void _markDirty() { if (!_dirty) setState(() => _dirty = true); }

  void _save() => Navigator.of(context).pop(_RulesSheetResult(rules: _rules, shouldGenerate: false));
  void _generate() => Navigator.of(context).pop(_RulesSheetResult(rules: _rules, shouldGenerate: true));

  @override
  Widget build(BuildContext context) { ... }
  // Internal build helpers — see layout specification below.
}
```

**`_RulesSheet` layout:**

The sheet has three sections exposed via a small segmented tab strip at the top (not `EduTabBar` — use a simple `Row` of `_SheetTab` chips since this is inside a sheet, not a full page):

```
[ Global ] [ Teachers ] [ Subjects ]     ← simple chip row, 3 options
────────────────────────────────────────
  (scrollable content for selected tab)
────────────────────────────────────────
  [ Save ]          [ ▶ Generate ]       ← bottom action row
```

**Tab 0 — Global rules:**
Render the same content as the old `_RulesTabState._buildTimeRules`, `_buildTeacherRules`, and `_buildDayRules` (in a single scrollable column), but now using `_rules` (a `TimetableRules` instead of `_TimetableRules`). Field names changed:
- `dayStartSeconds` → same
- `dayEndSeconds` → same
- `lessonDurationMinutes` → same
- `breakDurationMinutes` → same
- `maxLessonsPerDayTeacher` → same
- `allowDoubles` → same
- `lunchStartSeconds` → same
- `lunchDurationMinutes` → same
- `activeDays` → same (List<DayOfWeek>)
- Add `maxLessonsPerDayClass` → `_StepperControl(value: _rules.maxLessonsPerDayClass, suffix: '', min: 1, max: 12, step: 1, ...)`

**Tab 1 — Teacher blocks:**

Shows a list of existing `_rules.teacherBlocks` entries. Each entry shows:
- Teacher user ID (resolved to name via a `FutureBuilder` or an inline lookup, but for MVP just show the truncated ID with a note — the teacher name lookup is **not required** for this task; a `TODO` comment is sufficient)
- Blocked days (chips)
- Blocked window (start–end time)
- Delete button (red trash icon)

Plus an "Add Rule" row at the bottom that opens `_TeacherBlockRuleSheet` (see below).

**Tab 2 — Subject blocks:**

Shows a list of existing `_rules.subjectBlocks`. Each entry shows:
- Subject ID (show as-is for MVP — subject name lookup is a TODO)
- Allowed days or blocked time range
- Delete button

Plus an "Add Rule" row at the bottom that opens `_SubjectBlockRuleSheet` (see below).

**Bottom action row (always visible):**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
    const SizedBox(width: 8),
    // Save button — only saves rules, does not generate
    OutlinedButton.icon(
      onPressed: _save,
      icon: const Icon(Icons.save_outlined, size: 16),
      label: const Text('Save'),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.kCardRadius)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    const SizedBox(width: 8),
    // Generate button — saves AND runs generation
    FilledButton.icon(
      onPressed: _generate,
      icon: const Icon(Icons.play_arrow_rounded, size: 16),
      label: const Text('Generate'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.kCardRadius)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    const SizedBox(width: 16),
  ],
)
```

#### Step 4 — Add `_GenerateFab` widget

The FAB replaces the old "Generate" button. It is a green circular FAB that either shows a spinner (when `_generating == true`) or the ⚡/add icon:

```dart
class _GenerateFab extends StatelessWidget {
  const _GenerateFab({required this.onTap, required this.generating, required this.cs});
  final VoidCallback onTap;
  final bool generating;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: generating ? null : onTap,
      backgroundColor: AppTheme.brandGreen,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      tooltip: 'Configure rules & generate timetable',
      child: generating
          ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.add_rounded, size: 26),
    );
  }
}
```

#### Step 5 — Add `_TeacherBlockRuleSheet` and `_SubjectBlockRuleSheet`

These are small nested sheets opened from within `_RulesSheet`.

**`_TeacherBlockRuleSheet`:**

Fields:
- Teacher user ID text field (label: "Teacher User ID" — for MVP; TODO: replace with a searchable teacher picker)
- Day selector (multi-select `_DayToggle` row — reuse existing widget)
- Start time picker (`_TimePickerButton` — reuse existing widget)
- End time picker (`_TimePickerButton` — reuse existing widget)

Validates: `endSeconds > startSeconds`, at least one day selected, teacher ID non-empty.

Returns a `TeacherBlockRule` via `Navigator.pop`.

**`_SubjectBlockRuleSheet`:**

Fields:
- Subject ID integer field (label: "Subject ID" — for MVP; TODO: replace with searchable subject picker)
- Allowed days (optional): multi-select `_DayToggle` row, with a toggle to enable/disable the restriction
- Blocked before time (optional): `_TimePickerButton` with enable/disable toggle
- Blocked after time (optional): `_TimePickerButton` with enable/disable toggle

Returns a `SubjectBlockRule` via `Navigator.pop`.

Both sheets use `EduSheet` / `showEduSheet` wrapper for consistent styling.

#### Step 6 — Add `_SheetTab` widget (chip-style tab for use inside sheets)

```dart
class _SheetTab extends StatelessWidget {
  const _SheetTab({required this.label, required this.selected, required this.onTap, required this.cs});
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
            color: selected ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.3),
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
```

#### Step 7 — Update imports

At the top of `timetable_screen.dart`, add or verify these imports are present:

```dart
import 'dart:math' show Random;  // only if needed at this file level; solver uses its own
import 'package:flutter/foundation.dart' show compute;
import '../../../../cache/file_cache.dart';
import '../../../../models/timetable_rules.dart';
import '../../../../services/timetable_generator.dart';
import '../../../widgets/edu_sheet.dart';
```

Remove the import of `edu_tab_bar.dart` only if it is no longer used in this file (check — it may still be used by teacher/student/staff views).

#### Step 8 — Remove `_TimetableRules` private class

Delete the entire `_TimetableRules` private class (lines 416–466 in current file). All references to `_TimetableRules` in `_OwnerTimetableShellState` now use `TimetableRules` from `lib/models/timetable_rules.dart`.

**After modifying:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update the `timetable/` section: remove "Rules tab" references, add "Green FAB opens `_RulesSheet`", note `TimetableRules` model used, note generation runs via `compute(runTimetableGenerator, ...)`.
- [ ] Mark this task `[x]`.

---

### [x] Task C2: Wire `AppTheme.brandGreen` (if not already present)

**Files to modify:** `lib/ui/theme/app_theme.dart`
**Depends on:** nothing
**Parallel group:** C-pre (can run before C1)

**Specification:**

Check whether `AppTheme.brandGreen` already exists in `lib/ui/theme/app_theme.dart`. If it does, this task is a no-op — mark it complete immediately.

If it does NOT exist, add the following static constant to the `AppTheme` class:

```dart
static const Color brandGreen = Color(0xFF22C55E); // Tailwind green-500
```

Place it alongside the other brand color constants (e.g. `brandIndigo`, `brandIndigoDark`).

**After checking/modifying:**
- [x] Mark this task `[x]`.

---

## Completion Checklist

After all tasks are marked `[x]`, verify:

- [ ] `dart run build_runner build --delete-conflicting-outputs` passes with no errors (Task A3 requires codegen).
- [ ] `timetable_screen.dart` no longer contains any `TabController`, `EduTabBar` (for the owner shell — may still be present elsewhere in the file if used by other views), `_RulesTab`, or `_TimetableRules` references.
- [ ] `_OwnerTimetableShell` renders a single `Scaffold` with `body` = schedule and `floatingActionButton` = green FAB.
- [ ] Tapping the FAB opens `_RulesSheet` with three tabs: Global, Teachers, Subjects.
- [ ] "Generate" button in the sheet runs the solver via `compute()` and inserts results via `TimetableDao.insertSlots()`.
- [ ] `TimetableRules` JSON is persisted to `{appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json`.
- [ ] No Flutter imports in `lib/services/timetable_generator.dart`.
- [ ] All BUG.md entries reviewed — no regressions introduced (especially BUG-001/002 papers table, BUG-004/005 delta writer — none of the files modified here touch those).
- [ ] All CONTEXT.md files updated.
- [ ] Git committed after each track completes.