# TASKS.md

## Feature: Paper Detail Page — AI Marking UX Fixes

### Overview

Four issues on the paper detail page (`lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`) need fixing:

1. AI mark button shows even when all submitted papers are already graded
2. "+Add Sheet" and "+Add Grade" actions are available when paper status is Pending/InProgress (should only be available at Done or beyond)
3. AI marking progress gets stuck at 60% forever — grades arrive via sync but the polling loop doesn't see them because `widget.gradeMap` is stale (the widget instance captured at the start of `runAiMarking` never updates)
4. Cannot re-mark a student whose paper was already graded — replacing answer sheets and re-triggering AI mark is not supported

### Dependency Graph

```
Task 1 (AI button visibility)     — independent
Task 2 (status-gate add actions)  — independent
Task 3 (stuck at 60%)             — independent
Task 4 (re-mark support)          — depends on Task 1 (AI button logic) and Task 3 (marking flow must work)
```

Tasks 1, 2, and 3 can run in **parallel group P1**.
Task 4 runs after P1 completes (sequential).

---

### Task 1: AI Mark Button — Only Show When There Are Unmarked Submissions ✅

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read:** None needed — all info is below.
**Depends on:** None
**Parallel group:** P1

**Problem:**
The AI mark button (indigo wand icon) appears whenever `hasUnmarkedSubmissions` is true AND `schemeFiles` is non-empty (line ~1190–1192 in `_buildActionButton`). The `hasUnmarkedSubmissions` getter (line ~1670 in `_GradeSpreadsheetState`, line ~2517 in `_GradeListState`) checks:

```dart
bool get hasUnmarkedSubmissions {
  return _submissions.entries.any(
    (e) => e.value.isNotEmpty && !widget.gradeMap.containsKey(e.key),
  );
}
```

This is correct in principle — it returns true if any student has answer sheet files but no grade. However, the issue is that after AI marking completes and grades are written, `_hasUnmarkedSubmissions` should become false (since `gradeMap` now contains those students). If it's still showing, the likely cause is that `_submissions` contains stale entries for students who DO have grades, OR the parent `_PaperDetailPageState._hasUnmarkedSubmissions` getter (line ~96–101) is returning a cached value.

**Root cause:** The parent getter delegates to the child widget's state via GlobalKey:

```dart
bool get _hasUnmarkedSubmissions {
  if (_spreadsheetKey.currentState != null) {
    return _spreadsheetKey.currentState?.hasUnmarkedSubmissions ?? false;
  } else {
    return _gradeListKey.currentState?.hasUnmarkedSubmissions ?? false;
  }
}
```

This is read during `build()` but NOT triggered reactively — it's only evaluated when the parent rebuilds. After AI marking completes, the parent might not rebuild because the grade stream update goes to the `StreamBuilder` which rebuilds the child directly, bypassing the parent's `_hasUnmarkedSubmissions` evaluation.

**Specification:**

1. In `_PaperDetailPageState.build()`, the `_hasUnmarkedSubmissions` check is already inside the `StreamBuilder<List<GradeRow>>` (line ~340–375). The `gradeMap` is computed there. Instead of delegating to child state via GlobalKey, compute it directly in the parent using `gradeMap` and child submissions.

2. **Better approach:** Pass `gradeMap` into the `hasUnmarkedSubmissions` computation at the parent level. Change `_PaperDetailPageState` to track submissions from children:

   a. Add a field to `_PaperDetailPageState`:
   ```dart
   Map<int, List<String>> _childSubmissions = {};
   ```

   b. Add an `onSubmissionsMapChanged` callback to both `_GradeSpreadsheet` and `_GradeList` that fires whenever `_submissions` changes, passing the full map.

   c. In the parent, update `_childSubmissions` and call `setState`.

   d. Replace the `_hasUnmarkedSubmissions` getter:
   ```dart
   bool _computeHasUnmarked(Map<int, Grade> gradeMap) {
     return _childSubmissions.entries.any(
       (e) => e.value.isNotEmpty && !gradeMap.containsKey(e.key),
     );
   }
   ```

   e. In the `StreamBuilder<List<GradeRow>>` builder, call `_computeHasUnmarked(gradeMap)` and pass that to `_PaperHeader.hasUnmarkedSubmissions`.

3. This ensures the AI button visibility is reactive to BOTH grade changes (via stream) AND submission changes (via callback).

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: AI mark button reactively hides when all submissions are graded"`

---

### Task 2: Gate Add Sheet / Add Grade Actions Behind Paper Status >= Done ✅

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read:** None needed — all info is below.
**Depends on:** None
**Parallel group:** P1

**Problem:**
The "Submit Answer Sheets" and "Enter Grade" actions (both on desktop's inline icons and mobile's action sheet) are always available regardless of paper status. They should only be interactive when `paper.status == PaperStatus.done || paper.status == PaperStatus.marked`.

**Specification:**

The `PaperStatus` enum (from `lib/database/tables/enums.dart` line 232):
```dart
enum PaperStatus { pending, progress, done, marked }
```

"Done or beyond" means `status.index >= PaperStatus.done.index` (i.e., `done` or `marked`).

**Changes to `_GradeSpreadsheet` / `_SpreadsheetRow` (desktop):**

1. `_SpreadsheetRow` already receives `paperStatus` (line ~2155 in the `itemBuilder`). Locate where `onSubmitTap` is wired (line ~2193–2194):
   ```dart
   onSubmitTap: _aiMarking
       ? () {}
       : () => _openSubmissionSheet(context, student),
   ```
   Change to:
   ```dart
   onSubmitTap: (_aiMarking || widget.paper.status.index < PaperStatus.done.index)
       ? null
       : () => _openSubmissionSheet(context, student),
   ```

2. In `_SpreadsheetRow`, wherever the camera/upload icon button is rendered, check if `onSubmitTap` is null and grey out / hide the icon accordingly. If `onSubmitTap` is null, use `cs.onSurface.withValues(alpha: 0.2)` for the icon color and ignore taps.

3. For the grade text field in `_SpreadsheetRow`: the `canGrade` prop already gates editing. Find where `canGrade` is passed (line ~2187):
   ```dart
   canGrade: widget.canGrade && !_aiMarking,
   ```
   Change to:
   ```dart
   canGrade: widget.canGrade && !_aiMarking && widget.paper.status.index >= PaperStatus.done.index,
   ```

**Changes to `_GradeList` (mobile):**

4. In `_openStudentActionSheet` (line ~2940–2970), gate the "Submit Answer Sheets" action:
   ```dart
   _ActionSheetRow(
     icon: Icons.upload_file_outlined,
     label: 'Submit Answer Sheets',
     cs: cs,
     isDark: isDark,
     onTap: widget.paper.status.index >= PaperStatus.done.index
         ? () {
             Navigator.pop(ctx);
             _openSubmissionSheet(context, student);
           }
         : null,  // greyed out when pending/progress
   ),
   ```

5. Similarly gate "Enter Grade":
   ```dart
   onTap: (widget.canGrade && widget.paper.status.index >= PaperStatus.done.index)
       ? () {
           Navigator.pop(ctx);
           _openGradeEntry(context, student);
         }
       : null,
   ```

6. For the quick-grade tap on list rows (if any), also add the status gate.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: gate add-sheet and add-grade actions behind paper status done or beyond"`

---

### Task 3: Fix AI Marking Progress Stuck at 60% ✅

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read:** None needed — all info is below.
**Depends on:** None
**Parallel group:** P1

**Problem:**
After the `markPaper` gRPC call returns `accepted: true`, the progress is set to 60% (line ~1908 in Spreadsheet, ~2761 in GradeList). Then Phase 5 polls for grades:

```dart
// Phase 5: Wait for grades via Drift stream (60% → 100%)
final expectedAdms = studentsWithSubmissions.map((s) => s.adm).toSet();
final expectedCount = expectedAdms.length;
final gradedAdms = <int>[];

for (int tick = 0; tick < 60; tick++) {
  await Future.delayed(const Duration(seconds: 2));
  if (!mounted) return;

  int received = 0;
  for (final adm in expectedAdms) {
    if (widget.gradeMap.containsKey(adm)) {
      if (!gradedAdms.contains(adm)) gradedAdms.add(adm);
      received++;
    }
  }
  // ...update progress...
  if (received >= expectedCount) break;
}
```

**Root cause:** `widget.gradeMap` is passed into the widget constructor. But `runAiMarking()` is an async method that runs across many awaits. During the polling loop, `widget.gradeMap` refers to the map from the LAST widget rebuild. The Drift `StreamBuilder` in the parent (`_PaperDetailPageState.build`) rebuilds the parent tree, which creates new `_GradeSpreadsheet` / `_GradeList` widgets with updated `gradeMap`. But the RUNNING async method still references `widget.gradeMap` from the widget instance it started with — or more precisely, `widget` always points to the current widget (Flutter updates it in `didUpdateWidget`), BUT the problem is that the `_GradeSpreadsheet`/`_GradeList` is rebuilt by the StreamBuilder with a new `gradeMap`, and `widget.gradeMap` DOES update... so why doesn't it work?

**Actual root cause:** The `StreamBuilder<List<GradeRow>>` in the parent rebuilds the child widget tree, causing `didUpdateWidget` on `_GradeSpreadsheetState` / `_GradeListState`. In Flutter, `widget` always refers to the latest widget instance, so `widget.gradeMap` should be up-to-date. BUT — the grades arrive via the sync delta stream, which writes to the local Drift DB, which triggers the `watchGradesForPaper` stream. The issue is likely that **the sync stream is not connected** during AI marking, or the grades are written by the server but the delta never arrives on the client because:

1. The sync `watchChanges` stream may not be active, OR
2. The grade write on the server happens in the background `tokio::spawn` task, and the changelog append (which triggers the sync delta to connected clients) may not reach this client.

**More likely root cause:** The server marks papers in a background task AFTER returning `accepted: true`. The client gets the accepted response and starts polling. But the server's background task takes 30-60+ seconds (download images, call Gemini, write to DB). During this time, the polling loop checks `widget.gradeMap` every 2 seconds. If the server finishes marking AFTER the 120-second timeout (60 ticks × 2s), the polling loop exits and progress stays at 60%.

But the user says "even if the server sends back the grading results" — implying the server has finished. So the issue is: **how do grades get from server DB to the client's Drift DB?** The answer is: via the `watchChanges` sync stream. The server appends changelog records, and the sync stream pushes `SyncDelta` messages to connected clients. The client's `DeltaWriter` writes to local Drift tables, which triggers the `watchGradesForPaper` stream.

If this pipeline works, `widget.gradeMap` would update and the polling loop would detect it. If it doesn't work, grades only appear when the user pops and comes back (triggering a fresh stream subscription or a full sync).

**The fix must address both scenarios:**

1. **If sync deltas work:** The polling loop should work. Add logging to verify `widget.gradeMap` is actually updating during the loop. The issue might be that `didUpdateWidget` is never called because the `StreamBuilder` uses the same `Key` and the widget is considered the same — but `gradeMap` IS a different map object. Actually, `widget.gradeMap` should always be current because Flutter updates the widget reference. Add debug prints inside the loop to verify.

2. **If sync deltas DON'T work (more likely):** The polling loop will never see grades. Instead of polling `widget.gradeMap`, **actively query the database** inside the loop:

**Specification:**

In BOTH `_GradeSpreadsheetState.runAiMarking()` (around line 1915-1945) and `_GradeListState.runAiMarking()` (around line 2768-2800), replace the Phase 5 polling loop with one that queries the DAO directly:

```dart
// Phase 5: Wait for grades via direct DB query (60% → 100%)
final expectedAdms = studentsWithSubmissions.map((s) => s.adm).toSet();
final expectedCount = expectedAdms.length;
final gradedAdms = <int>[];

for (int tick = 0; tick < 120; tick++) {
  // 120 × 1s = 120s timeout (more responsive than 60 × 2s)
  await Future.delayed(const Duration(seconds: 1));
  if (!mounted) return;

  // Query the DB directly — don't rely on widget.gradeMap which may be stale
  final currentGrades = await widget.dao.getGradesForPaper(
    schoolId: widget.schoolId,
    examId: widget.exam.id,
    subject: widget.paper.subject,
    paper: widget.paper.paper,
  );
  final gradedSet = {for (final g in currentGrades) g.student};

  int received = 0;
  for (final adm in expectedAdms) {
    if (gradedSet.contains(adm)) {
      if (!gradedAdms.contains(adm)) gradedAdms.add(adm);
      received++;
    }
  }

  final progress = 0.6 + (received / expectedCount) * 0.4;
  setState(() => _aiMarkedCount = received);
  widget.onAiMarkedCountChanged?.call(received);
  widget.onAiProgressChanged?.call(progress);

  print('[AI-POLL] tick=$tick received=$received/$expectedCount progress=${(progress * 100).toInt()}%');

  if (received >= expectedCount) break;
}
```

**DAO method needed:** Check if `ExamsGradesDao` already has a `getGradesForPaper` method that returns a `Future<List<Grade>>` (not a stream). If not, add one:

```dart
Future<List<Grade>> getGradesForPaper({
  required String schoolId,
  required String examId,
  required int subject,
  int? paper,
}) async {
  final query = select(grades)
    ..where((g) =>
      g.school.equals(schoolId) &
      g.exam.equals(examId) &
      g.subject.equals(subject));
  if (paper != null) {
    query.where((g) => g.paper.equals(paper));
  }
  return query.get();
}
```

Check the existing DAO file (`lib/database/daos/exams_grades_dao.dart`) for the exact table name and column names — it might be `gradesTable` or `grades`. The `Grade` type is the Drift-generated data class for the grades table.

Also add a `GradeRow`-style return if needed — the key field is `student` (the ADM number as `int`). We only need to check which ADMs have grades, so even a simpler query returning just ADM numbers would work.

**Important:** Also increase the timeout from 120s to 180s (180 ticks × 1s) to account for slow Gemini responses, especially with the new queue-based server architecture where requests might wait in line.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: AI marking progress polls DB directly instead of relying on stale widget.gradeMap"`

---

### Task 4: Support Re-Marking — Replace Answer Sheets and Re-Trigger AI

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read:** None needed — all info is below.
**Depends on:** Task 1 (AI button visibility logic), Task 3 (marking flow must complete correctly)
**Parallel group:** None (sequential after P1)

**Problem:**
If a student already has a grade (i.e., `gradeMap.containsKey(adm)` is true), and the user replaces their answer sheet files in `_AnswerSubmissionSheet`, the AI mark button does NOT appear because `hasUnmarkedSubmissions` returns false — the student has a grade, so they're considered "marked."

The user wants to be able to:
1. Open a student's answer submission sheet
2. Replace/update the files (e.g., they uploaded the wrong student's paper)
3. Have the AI mark button appear for that student
4. Click AI mark, which re-grades that student (server upserts the grade)

**Specification:**

The concept is: when a user modifies answer sheets for a student who already has a grade, that student should be considered "dirty" — needing re-marking. The `_dirtySubmissions` set already exists in both `_GradeSpreadsheetState` and `_GradeListState` (line ~1581, ~2497) and is populated when new submissions are added:

```dart
// In _openSubmissionSheet's onUpdated callback:
setState(() {
  _submissions[adm] = paths;
  if (paths.isNotEmpty) _dirtySubmissions.add(adm);
});
```

But `_dirtySubmissions` is only used to clear after AI marking completes — it's never checked in `hasUnmarkedSubmissions`.

**Changes:**

1. **Update `hasUnmarkedSubmissions` in BOTH `_GradeSpreadsheetState` and `_GradeListState`:**

   Old:
   ```dart
   bool get hasUnmarkedSubmissions {
     return _submissions.entries.any(
       (e) => e.value.isNotEmpty && !widget.gradeMap.containsKey(e.key),
     );
   }
   ```

   New:
   ```dart
   bool get hasUnmarkedSubmissions {
     return _submissions.entries.any(
       (e) => e.value.isNotEmpty && (
         !widget.gradeMap.containsKey(e.key) || _dirtySubmissions.contains(e.key)
       ),
     );
   }
   ```

   A student needs marking if they have submissions AND (no grade OR their submissions were modified).

2. **Update the `_openSubmissionSheet` `onUpdated` callback in BOTH widgets:**

   Currently (line ~2072–2082 Spreadsheet, ~2839–2849 GradeList):
   ```dart
   onUpdated: (paths) {
     if (mounted) {
       setState(() {
         _submissions[adm] = paths;
         if (paths.isNotEmpty) _dirtySubmissions.add(adm);
       });
       widget.onSubmissionsChanged?.call();
     }
   },
   ```

   This is already correct — it adds to `_dirtySubmissions` when new paths are set. But we need to also handle the case where files are REPLACED (not just added). The current logic adds to `_dirtySubmissions` only when `paths.isNotEmpty`, which covers the replace case (old files removed, new files added = non-empty list). Good.

   BUT: we also need to notify the parent so it re-evaluates `_hasUnmarkedSubmissions` for the header button. The `widget.onSubmissionsChanged?.call()` does this. If Task 1's `onSubmissionsMapChanged` callback is implemented, also fire that:
   ```dart
   onUpdated: (paths) {
     if (mounted) {
       setState(() {
         _submissions[adm] = paths;
         if (paths.isNotEmpty) _dirtySubmissions.add(adm);
       });
       widget.onSubmissionsChanged?.call();
       widget.onSubmissionsMapChanged?.call(Map.from(_submissions));
     }
   },
   ```

3. **Update `runAiMarking()` in BOTH widgets to include dirty students:**

   Currently, `studentsWithSubmissions` is computed as:
   ```dart
   final studentsWithSubmissions = widget.students.where((s) {
     final paths = _submissions[s.adm] ?? [];
     return paths.isNotEmpty && !widget.gradeMap.containsKey(s.adm);
   }).toList();
   ```

   (Find the exact location by searching for `studentsWithSubmissions` — it should be in the early phases of `runAiMarking()`.)

   Change to include dirty students:
   ```dart
   final studentsWithSubmissions = widget.students.where((s) {
     final paths = _submissions[s.adm] ?? [];
     if (paths.isEmpty) return false;
     // Include if: no grade yet, OR submissions were modified since last mark
     return !widget.gradeMap.containsKey(s.adm) || _dirtySubmissions.contains(s.adm);
   }).toList();
   ```

4. **Clear `_dirtySubmissions` for marked students after AI marking completes:**

   This already happens at line ~1963 (Spreadsheet) and ~2812 (GradeList):
   ```dart
   _dirtySubmissions.clear();
   ```

   This is correct — after marking completes, all dirty flags are cleared.

5. **Visual indicator for re-markable students:**

   In the spreadsheet/list row, if a student has a grade AND is in `_dirtySubmissions`, show a small amber dot or icon next to their submission count to indicate "modified, needs re-marking." This is optional but improves UX — the user can see which students will be re-marked.

   In `_SpreadsheetRow`, add a prop `isDirtySubmission: bool` and render a small amber dot (4px circle) next to the camera icon when true.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: support re-marking students by replacing answer sheets and re-triggering AI"`
