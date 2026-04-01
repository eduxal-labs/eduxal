# TASKS.md

---

## Bug 1: Exams Page — Grouping by Date Range Instead of Name (Shows 3 Instead of 4)

### Task 1: Change ExamGroup grouping key from date-range to exam name

**Files to create/modify:** `lib/database/daos/exams_grades_dao.dart`, `lib/models/exam_group.dart`
**Context files to read (if needed):** `lib/database/daos/CONTEXT.md`, `lib/models/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

**Problem:** In `exams_grades_dao.dart` at ~L1488, `watchExamGroups()` groups exams by the key `'${exam.type.index}|${exam.start}|${exam.end}'`. This means two exams with the same type and date range but different names are merged into one group. The user has 4 distinct exams but only sees 3 because two share the same type + date range.

**Fix in `exams_grades_dao.dart` — `watchExamGroups()`:**

1. Change the grouping key from:
   ```
   final key = '${exam.type.index}|${exam.start}|${exam.end}';
   ```
   to:
   ```
   final key = exam.name;
   ```
   This makes the exam name the unique identifier for grouping. Exams with different names will always be separate groups, even if they share the same type and date range.

2. When building the `ExamGroup` object (~L1551), pass the exam name:
   ```dart
   result.add(
     ExamGroup(
       name: firstExam.name,      // ← ADD THIS
       school: schoolId,
       year: year,
       term: term,
       type: firstExam.type,
       start: firstExam.start,
       end: firstExam.end,
       personalized: firstExam.personalized,
       teacher: teacherUser,
       grades: gradeEntries,
     ),
   );
   ```

**Fix in `lib/models/exam_group.dart` — `ExamGroup` class:**

1. Add a `name` field to the `ExamGroup` class:
   ```dart
   final String name; // exam display name — the grouping key
   ```

2. Add `required this.name` to the constructor.

3. Update `groupKey` getter to use name instead of type+start+end:
   ```dart
   String get groupKey => '$school|$year|$term|$name';
   ```

**Update after completion:**
- [x] Update `lib/database/daos/CONTEXT.md` — note `watchExamGroups` now groups by name
- [x] Update `lib/models/CONTEXT.md` — note `ExamGroup` now has a `name` field
- [x] Mark this task `[x]`

---

### Task 2: Update ExamGroup consumers to use the new `name` field

**Files to create/modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 1
**Parallel group:** —

**Specification:**

After Task 1 adds `name` to `ExamGroup`, update the consumers:

1. **`_ExamsListViewState._examGroupName()` (~L368):** Currently extracts the name by drilling into `group.grades.first.streams.first.exam.name`. Simplify to:
   ```dart
   String _examGroupName(ExamGroup group) => group.name;
   ```

2. **`_ExamGroupRowState.build()` (~L614):** Currently computes `examName` by drilling into grades/streams/exam.name. Simplify to:
   ```dart
   final examName = widget.group.name;
   ```

3. **`_ExamsShellState.build()` (~L239):** The `_ExamsView.examDetail` branch matches groups by `g.groupKey == _selectedGroupKey`. Since `groupKey` changed format in Task 1 (now `$school|$year|$term|$name` instead of `$school|$year|$term|${type.index}|$start|$end`), verify that `_selectedGroupKey` is always set from `group.groupKey` at tap time. Check `_openExam` (~L180) — it sets `_selectedGroupKey = group.groupKey` which is correct. No change needed here, just verify it works with the new key format.

4. **`_ExamGroupDetailViewState`:** The `_showEditExamName` method (~L1169) updates the exam name. After editing, the group key changes (since it's now name-based). The view should still work because `_ExamsShellState` re-queries the stream and matches by `_selectedGroupKey`. After a name edit, update `_selectedGroupKey` to reflect the new name. In `_showEditExamName`, after the name update completes, call:
   ```dart
   // After successful name update in the onSaved callback:
   setState(() {
     _selectedGroupKey = '${widget.schoolId}|${widget.year}|${widget.term}|$newName';
   });
   ```
   Check the existing `_showEditExamName` implementation to see how it handles the callback. The key point is that renaming an exam changes the group key, so the parent state must be informed. If `_showEditExamName` already has a callback mechanism that rebuilds from the stream, this may work automatically — verify and handle the edge case.

5. **`updateExamGroupDateRange()` (~L1563):** This method updates start/end for all exams in a group. It uses `type`, `start`, `end` to identify the group. Since grouping is now by name, this method should be updated to find exams by name instead. Change the query from filtering by `(type, start, end)` to filtering by `name`:
   ```dart
   // Replace the existing where clause that matches by type+start+end
   // with one that matches by name:
   ..where((e) =>
     e.school.equals(schoolId) &
     e.year.equals(year) &
     e.term.equals(term) &
     e.name.equals(examName))
   ```
   Add a `required String examName` parameter and remove the old `type`/`start`/`end` parameters if they were only used for group identification. Check all call sites of `updateExamGroupDateRange` and update them to pass `examName` (available from `group.name`).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note exam group consumers updated
- [ ] Mark this task `[x]`

---

## Bug 2a: Academics Page — Stream Ranking Uses Wrong Criteria

### Task 3: Fix stream ranking to sort by average marks instead of last exam average

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/tabs/comparisons_tab.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

**Problem:** In `_RankingTableState.build()` at ~L1121, the ranking sorts streams by `lastExamAverage`:
```dart
final ranked = List<StreamStats>.from(widget.stats)
  ..sort((a, b) {
    final aVal = a.lastExamAverage ?? -1;
    final bVal = b.lastExamAverage ?? -1;
    return bVal.compareTo(aVal);
  });
```
The user has Blue=96.7, Green=97.3, Yellow=96.3 average marks, but Blue was ranked #1. Blue has attendance data while others don't, which suggests `lastExamAverage` may be influenced by or correlated with attendance in an unexpected way, or the last exam average differs from the overall average.

The user explicitly says: "when it comes to ranking, we should be using the average marks of the streams."

**Fix in `_RankingTableState.build()` (~L1121):**

Change the sort from `lastExamAverage` to `averageScore`:
```dart
final ranked = List<StreamStats>.from(widget.stats)
  ..sort((a, b) {
    return b.averageScore.compareTo(a.averageScore);
  });
```

**Also fix `_PodiumSection` (~L899):**

In `_PodiumSection._buildPodiumItem()` (~L976), the display score currently uses:
```dart
final displayScore = stats.lastExamAverage ?? stats.averageScore;
```

Change to:
```dart
final displayScore = stats.averageScore;
```

This ensures the podium items show the same metric used for ranking — the overall average score.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note ranking now uses `averageScore`
- [ ] Mark this task `[x]`

---

## Bug 2b: Academics Page — Exam Names Missing in Exams Tab

### Task 4: Show exam name in the `_ExamRow` widget under the academics grade exams tab

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

**Problem:** The `_ExamRow` widget in `exams_tab.dart` (used under the Academics > Grade > Exams tab, for both the "All" tab and individual stream tabs) only shows the exam type badge and date range. The exam name (`exam.name`) is not displayed. The `ExamWithPapers` typedef is `({Exam exam, List<Paper> papers, UsersData teacher})` and `Exam` has a `name` field (text column in the table).

**Fix in `_ExamRowState.build()` (~L535):**

Currently the content area shows:
- Type badge (e.g. "Exam", "Assignment")
- Date range (e.g. "01 Jan 2025 – 05 Jan 2025")

Add the exam name as the primary text above the date range. Restructure the left content column to show:

```dart
// Inside the Expanded > Column after the type badge row:
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // ── Exam name (NEW) ──
      Text(
        exam.name,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 3),
      // ── Date range (existing, but now secondary) ──
      Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 11,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 3),
          Text(
            '${_fmtDate(startDate)} – ${_fmtDate(endDate)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    ],
  ),
),
```

The type badge should remain to the left of this column as it currently is. The date range font size is reduced from 13 to 11 and color is dimmed since the name is now the primary identifier. This matches the pattern already used by `_ExamGroupRow` in `exams_grades_screen.dart` (~L700-730).

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note `_ExamRow` now shows exam name
- [x] Mark this task `[x]`

---

## Bug 3a: Paper Detail Mobile — Percentage Should Be Bigger Than Score

### Task 5: Swap prominence of percentage and score in mobile grade list

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P3

**Specification:**

**Problem:** In `_GradeListState.build()` (~L3226), the grade badge for each student shows:
- `${_fmtScore(grade.score)}/${grade.total}` at fontSize 12.5, fontWeight w500 (big, primary)
- `${pct.toStringAsFixed(1)}%` at fontSize 10, fontWeight w400 (small, secondary)

The user wants the percentage to be bigger and more visible, and the actual score to be secondary.

**Fix in `_GradeListState.build()` (~L3316-3340):**

Find the grade badge `Container` with the `Column` containing the score and percentage text widgets. Swap their styling:

**Before:**
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      '${_fmtScore(grade.score)}/${grade.total}',
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppTheme.brandGreen,
      ),
    ),
    if (pct != null)
      Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: AppTheme.brandGreen.withValues(alpha: 0.8),
        ),
      ),
  ],
),
```

**After:**
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [
    if (pct != null)
      Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.brandGreen,
        ),
      ),
    Text(
      '${_fmtScore(grade.score)}/${grade.total}',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppTheme.brandGreen.withValues(alpha: 0.7),
      ),
    ),
  ],
),
```

The percentage is now on top, at fontSize 13 with w500 weight (primary). The score is below, at fontSize 10 with w400 weight and slightly more transparent (secondary).

**Update after completion:**
- [x] Mark this task `[x]`

---

## Bug 3b: Paper Detail Mobile — Remove 3-Dot Button, Move Action Sheet to Row Tap

### Task 6: Replace grade entry on row tap with action sheet; remove 3-dot button

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 7 (for pending/in-progress behavior)
**Parallel group:** —

**Specification:**

**Problem:** In `_GradeListState.build()` (~L3226), each student row has:
- An `InkWell` `onTap` that opens `_openGradeEntry` (the grade input modal)
- A 3-dot `Icons.more_vert` `InkWell` that opens `_openStudentActionSheet` (with "Submit Answer Sheets" and "Enter Grade" buttons)

The user wants:
1. Remove the 3-dot button entirely
2. Make clicking the student row open the action sheet (currently `_openStudentActionSheet`) instead of the grade entry modal
3. When the paper is pending or in-progress, show an informative message instead (handled by Task 7)

**Fix in `_GradeListState.build()` (~L3256-3268 — the `InkWell` wrapping the row):**

Change the `onTap` callback from `_openGradeEntry` to `_openStudentActionSheet`:

```dart
Widget cardContent = InkWell(
  onTap: !_aiMarking
      ? () => _openStudentActionSheet(context, student)
      : null,
  child: SizedBox(
    // ... existing row content
  ),
);
```

Note: Removed the `widget.canGrade` and `widget.paper.status.index >= PaperStatus.done.index` conditions from the `onTap` guard. The action sheet (or the pending/in-progress message from Task 7) should always be reachable. Permission/status gating is handled inside `_openStudentActionSheet` itself (the action buttons are already individually gated).

**Remove the 3-dot button:** Delete the entire block (~L3358-3370):
```dart
// DELETE THIS ENTIRE BLOCK:
const SizedBox(width: 4),
InkWell(
  onTap: _aiMarking
      ? null
      : () => _openStudentActionSheet(context, student),
  borderRadius: BorderRadius.circular(4),
  child: Padding(
    padding: const EdgeInsets.all(6),
    child: Icon(
      Icons.more_vert,
      size: 18,
      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
    ),
  ),
),
```

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Bug 3c: Paper Detail Mobile — Show Message When Paper Is Pending/In-Progress

### Task 7: Show informative message instead of action sheet when paper is not done

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P3

**Specification:**

**Problem:** When a paper's status is `PaperStatus.pending` or `PaperStatus.inProgress`, clicking a student row opens `_openStudentActionSheet` which shows the action sheet with disabled buttons (the `onTap` callbacks are null because `widget.paper.status.index >= PaperStatus.done.index` is false). The user tried directing someone to use it and they couldn't figure out why the buttons weren't working. Instead of showing disabled buttons, show a clear message explaining the paper's current status.

**Fix in `_GradeListState._openStudentActionSheet()` (~L3176):**

Add a status check at the beginning of the method. If the paper is not yet done, show a snackbar/toast with an informative message and return early instead of showing the action sheet:

```dart
void _openStudentActionSheet(BuildContext context, StudentsData student) {
  final cs = widget.cs;
  final isDark = cs.brightness == Brightness.dark;

  // If paper is not yet done, show informative message instead of action sheet
  if (widget.paper.status.index < PaperStatus.done.index) {
    final statusLabel = widget.paper.status == PaperStatus.pending
        ? 'pending'
        : 'in progress';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'This paper is still $statusLabel. Answer sheets and grading will be available once the paper is marked as done.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    return;
  }

  // ... existing action sheet code continues unchanged
  showEduSheet(
    context: context,
    builder: (ctx) => EduSheet(
      title: student.name,
      child: SafeArea(
        // ... existing content
      ),
    ),
  );
}
```

Key points:
- Use `..clearSnackBars()` before `..showSnackBar()` to prevent stacking of multiple identical messages if the user taps repeatedly.
- The message is clear and actionable — tells the user the paper status and what needs to happen before grading is possible.
- The `PaperStatus` enum values are ordered: `pending` (0), `inProgress` (1), `done` (2), `published` (3). The check `status.index < PaperStatus.done.index` catches both pending and in-progress.

**Update after completion:**
- [x] Mark this task `[x]`

---

## Bug 4: Finance Page — Fee Creation Grade Validation Error Delayed and Shown as Outside Toast

### Task 8: Replace SnackBar validation with inline error for grade selection in fee creation modal

**Files to create/modify:** `lib/ui/screens/school_dashboard/finance/finance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

**Problem:** In `_CreateFeeSheetState._save()` (~L2371), when no grades are selected, the method uses `ScaffoldMessenger.of(context).showSnackBar(...)` to display the error. This has two issues:
1. **Delayed display:** `SnackBar` messages are queued by `ScaffoldMessenger`. If the user taps the save button N times, N snackbars queue up and display one after another with delays, appearing long after the user has stopped tapping.
2. **Wrong location:** The toast appears at the bottom of the screen, outside the modal. The user may be looking at the modal content and not notice the toast. When they navigate away, the toast appears on a different page entirely.

**Fix — Add `_gradeError` state variable and show inline error:**

1. Add a state variable to `_CreateFeeSheetState`:
   ```dart
   String? _gradeError;
   ```

2. In `_save()`, replace the `SnackBar` with inline error state:
   ```dart
   Future<void> _save() async {
     if (!_formKey.currentState!.validate()) return;
     if (_selectedGrades.isEmpty) {
       setState(() => _gradeError = 'Please select at least one grade');
       return;
     }
     // Clear error if grades are now selected
     setState(() => _gradeError = null);

     // ... rest of save logic unchanged
   }
   ```

3. Clear `_gradeError` whenever a grade is toggled. In the `onTap` of each grade chip (~L2583):
   ```dart
   onTap: () {
     setState(() {
       if (isSelected) {
         _selectedGrades.remove(entry.key);
       } else {
         _selectedGrades.add(entry.key);
       }
       // Clear error when user interacts with grade selection
       if (_gradeError != null) _gradeError = null;
     });
   },
   ```

4. Display the inline error below the grade chips wrap, right after the "X grades selected" text. Find the spot after the `Wrap` widget and the selected count `Padding` (~L2620). Add:
   ```dart
   if (_gradeError != null)
     Padding(
       padding: const EdgeInsets.only(top: 6),
       child: Text(
         _gradeError!,
         style: TextStyle(
           fontSize: 11.5,
           fontWeight: FontWeight.w400,
           color: cs.error,
         ),
       ),
     ),
   ```

   This follows the standard Flutter form validation pattern — errors appear inline directly below the relevant input.

5. Also remove the SnackBar entirely from the `catch` block at the end of `_save()` (~L2420). Replace with inline error:
   ```dart
   } catch (e) {
     if (mounted) {
       setState(() {
         _saving = false;
         _gradeError = 'Error creating fee: $e';
       });
     }
   }
   ```
   
   Actually, the catch block error is different — it's a general save error, not a grade error. Keep the existing catch block but use `clearSnackBars()` before showing the error snackbar to prevent stacking:
   ```dart
   } catch (e) {
     if (mounted) {
       setState(() => _saving = false);
       ScaffoldMessenger.of(context)
         ..clearSnackBars()
         ..showSnackBar(
           SnackBar(
             content: Text('Error: $e'),
             behavior: SnackBarBehavior.floating,
           ),
         );
     }
   }
   ```

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note fee creation uses inline validation
- [x] Mark this task `[x]`

---

## Summary

| Task | Bug | Description | Parallel Group | Depends On |
|------|-----|-------------|---------------|------------|
| 1 | Bug 1 | Change ExamGroup grouping key from date-range to name | P1 | — |
| 2 | Bug 1 | Update ExamGroup consumers for new `name` field | — | Task 1 |
| 3 | Bug 2a | Fix stream ranking to use averageScore | P2 | — |
| 4 | Bug 2b | Show exam name in `_ExamRow` (academics exams tab) | P2 | — |
| 5 | Bug 3a | Swap percentage/score prominence in mobile grade list | P3 | — |
| 6 | Bug 3b | Remove 3-dot button, move action sheet to row tap | — | Task 7 |
| 7 | Bug 3c | Show message when paper is pending/in-progress | P3 | — |
| 8 | Bug 4 | Replace SnackBar with inline grade validation error | P2 | — |

**Execution order:**
- **Batch 1 (parallel):** Tasks 1, 3, 4, 5, 7, 8 (P1 + P2 + P3 — all independent)
- **Batch 2 (sequential):** Task 2 (depends on Task 1)
- **Batch 3 (sequential):** Task 6 (depends on Task 7)