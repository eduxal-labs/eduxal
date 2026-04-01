# TASKS.md

---

## Bug Group 1: Attendance Tab — Remove from Teacher Dashboard + Fix Display for Students/Guardians

### Task 1: Remove the Attendance nav item from the teacher role in the school dashboard

**Files to modify:** `lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

**Problem:** The school dashboard shows an "Attendance" tab for teachers (permission-gated). This tab is a class picker that navigates into the academic grade detail page's attendance subtab — it's redundant because the same attendance functionality is already accessible inside the Academics tab when drilling into a grade/stream. Worse, the attendance screen has a broken `_loadConfig()` stub that never loads `SchoolConfig`, so it displays raw integer values like "Grade 44 Stream 2" instead of "Form 4 Green".

The user explicitly requests: "This tab should be completely removed."

**Fix in `_itemsForRole()` (~L270):**

Find the `MembershipRole.teacher` branch. Remove the attendance nav item entirely:

```dart
// DELETE these two lines from the teacher branch:
if (perms.canAny(Resource.attendance, [Action.read, Action.mark]))
  const _NavItem(label: 'Attendance', icon: Icons.fact_check_outlined),
```

The `MembershipRole.staff` branch also has a similar attendance nav item (~L339–340). **Keep it** — staff with attendance permissions should still see the attendance screen. But also keep the student and guardian attendance tabs unchanged.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note Attendance nav item removed for teachers
- [ ] Mark this task `[x]`

---

### Task 2: Fix `_loadConfig()` stub in `AttendanceScreen` to actually load SchoolConfig

**Files to modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

**Problem:** In `_ClassPickerShellState._loadConfig()` (~L112), the method is a stub that just sets `_loadingConfig = false` without actually loading any school config data:

```dart
Future<void> _loadConfig() async {
  if (mounted) setState(() => _loadingConfig = false);
}
```

This means `_config` stays `null` forever, causing:
1. `_gradeLabel()` falls back to `'Grade $grade'` — e.g. "Grade 44" instead of "Form 4"
2. `_streamLabel()` falls back to `'Stream $streamCode'` — e.g. "Stream 2" instead of "Green"
3. `_resolveClass()` returns `null` because `config == null` — making `_navigateToClass()` silently fail (clicking a class card does nothing)

The attendance screen is still used by students, guardians, and staff — only teachers lost the tab (Task 1).

**Fix — Replace `_loadConfig()` with a real implementation:**

Follow the same pattern used by `_ExamsShellState._loadConfig()` in `exams_grades_screen.dart` (~L105–115):

1. Add a `StreamSubscription? _configSub;` field to `_ClassPickerShellState`:
   ```dart
   StreamSubscription? _configSub;
   ```

2. Add `import '../../../../database/daos/catalog_dao.dart';` at the top of the file (if not already imported).

3. Add a `late final CatalogDao _catalogDao;` field and initialize in `initState`:
   ```dart
   _catalogDao = CatalogDao(db);
   ```

4. Replace `_loadConfig()`:
   ```dart
   Future<void> _loadConfig() async {
     _configSub = _catalogDao.watchAllStreamsForSchool(_schoolId).listen((allStreams) {
       if (!mounted) return;
       setState(() {
         _config = _buildConfigFromStreams(allStreams);
         _loadingConfig = false;
       });
     });
   }
   ```

5. Add the `_buildConfigFromStreams` method (copy the same logic used in `_ExamsShellState._buildConfigFromStreams()` at `exams_grades_screen.dart` ~L125–170). The method groups `SchoolStream` rows by grade, determines the curriculum type for each grade (grades ≥ 41 → 8-4-4, otherwise CBC), and builds a `SchoolConfig`:

   ```dart
   SchoolConfig _buildConfigFromStreams(List<SchoolStream> allStreams) {
     if (allStreams.isEmpty) return SchoolConfig.defaults();

     final allGrades = allStreams.map((s) => s.grade).toSet();

     final byGrade = <int, List<SchoolStream>>{};
     for (final s in allStreams) {
       byGrade.putIfAbsent(s.grade, () => []).add(s);
     }

     CurriculumType curriculumForGrade(int grade) {
       if (grade >= 41) return CurriculumType.eightFourFour;
       if (grade > 14) return CurriculumType.eightFourFour;
       if (allGrades.any((g) => g >= 41)) {
         // School has 8-4-4 grades — ambiguous range 1-8 goes to 8-4-4
         if (grade <= 8) return CurriculumType.eightFourFour;
       }
       return CurriculumType.cbc;
     }

     final cbcGrades = <GradeConfig>[];
     final eftGrades = <GradeConfig>[];

     for (final entry in byGrade.entries) {
       final gradeNum = entry.key;
       final streams = entry.value..sort((a, b) => a.stream.compareTo(b.stream));
       final type = curriculumForGrade(gradeNum);

       final gc = GradeConfig(
         grade: gradeNum,
         streams: streams
             .map((s) => GradeStream(code: s.stream, name: s.name))
             .toList(),
       );

       if (type == CurriculumType.cbc) {
         cbcGrades.add(gc);
       } else {
         eftGrades.add(gc);
       }
     }

     final curricula = <CurriculumConfig>[];
     if (cbcGrades.isNotEmpty) {
       cbcGrades.sort((a, b) => a.grade.compareTo(b.grade));
       curricula.add(CurriculumConfig(type: CurriculumType.cbc, grades: cbcGrades));
     }
     if (eftGrades.isNotEmpty) {
       eftGrades.sort((a, b) => a.grade.compareTo(b.grade));
       curricula.add(CurriculumConfig(type: CurriculumType.eightFourFour, grades: eftGrades));
     }

     return SchoolConfig(curricula: curricula);
   }
   ```

6. Cancel the subscription in `dispose()`:
   ```dart
   @override
   void dispose() {
     _configSub?.cancel();
     super.dispose();
   }
   ```
   Check if there's already a `dispose()` override — if so, add `_configSub?.cancel();` to it.

7. Make sure the necessary imports are present:
   - `dart:async` (for `StreamSubscription`)
   - `'../../../../database/daos/catalog_dao.dart'`
   - The `SchoolConfig`, `CurriculumConfig`, `GradeConfig`, `GradeStream`, `CurriculumType` types should already be imported from `school_config.dart`.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note AttendanceScreen now loads SchoolConfig
- [ ] Mark this task `[x]`

---

### Task 3: Replace raw-integer fallback strings in attendance_screen.dart with centralized gradeLabel()

**Files to modify:** `lib/ui/screens/school_dashboard/attendance/attendance_screen.dart`
**Context files to read (if needed):** None
**Depends on:** Task 2 (config is now loaded, but fallbacks should still be safe)
**Parallel group:** —

**Specification:**

**Problem:** Even after Task 2 fixes `_loadConfig()`, the `_gradeLabel()` and `_streamLabel()` helper functions at the bottom of the file (~L1292–1311) have fallbacks that show raw integers:
- `'Grade $grade'` (e.g. "Grade 44")
- `'Stream $streamCode'` (e.g. "Stream 2")

These should use the centralized `gradeLabel()` function from `lib/core/extensions.dart` which never returns a raw integer (falls back to `'Level $grade'` for truly unknown values and uses a dual-lookup across both CBC and 8-4-4 label maps).

**Fix 1 — Replace `_gradeLabel()` (~L1292–1298):**

```dart
// BEFORE:
String _gradeLabel(int grade, SchoolConfig? config) {
  if (config == null) return 'Grade $grade';
  for (final c in config.curricula) {
    final labels = gradeLabelsFor(c.type);
    if (labels.containsKey(grade)) return labels[grade]!;
  }
  return 'Grade $grade';
}

// AFTER:
String _gradeLabel(int grade, SchoolConfig? config) {
  return gradeLabel(grade, config: config);
}
```

The centralized `gradeLabel()` (from `lib/core/extensions.dart`) already handles the null-config case with a dual-lookup fallback. Add the import at the top of the file if not already present:
```dart
import '../../../../core/extensions.dart';
```

**Fix 2 — Replace `_streamLabel()` fallback (~L1301–1311):**

```dart
// BEFORE:
String _streamLabel(int grade, int streamCode, SchoolConfig? config) {
  if (config == null) return 'Stream $streamCode';
  for (final c in config.curricula) {
    final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
    if (gc != null) {
      final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
      if (s != null) return s.name;
    }
  }
  return 'Stream $streamCode';
}

// AFTER:
String _streamLabel(int grade, int streamCode, SchoolConfig? config) {
  if (config != null) {
    for (final c in config.curricula) {
      final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
      if (gc != null) {
        final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
        if (s != null) return s.name;
      }
    }
  }
  // Never show raw stream code — return the grade label alone
  return gradeLabel(grade, config: config);
}
```

The key change: when stream name cannot be resolved, return just the grade label (e.g. "Form 4") instead of "Stream 2". Raw stream codes are internal integers that are meaningless to users.

**Update after completion:**
- [ ] Mark this task `[x]`

---

### Task 4: Audit and fix raw-integer fallbacks in other UI files

**Files to modify:**
- `lib/ui/screens/school_dashboard/my_classes/my_classes_screen.dart`
- `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

**Problem:** Several UI files have `'Stream $streamCode'` or `'Stream ${ct.stream}'` fallbacks that leak raw integer stream codes to the user. These should never appear in the UI.

**Fix 1 — `my_classes_screen.dart` (~L270 and ~L301):**

Two places build `_ClassAssignment` with a fallback `'Stream ${ct.stream}'` / `'Stream $stream'`:

```dart
// ~L270 (class teacher branch):
streamName: streamNames[key] ?? 'Stream ${ct.stream}',
// ~L301 (subject teacher branch):
streamName: streamNames[key] ?? 'Stream $stream',
```

Change both to empty string fallback — the UI should just show the grade label without a stream name if the stream name can't be resolved, rather than leaking a raw integer:

```dart
// ~L270:
streamName: streamNames[key] ?? '',
// ~L301:
streamName: streamNames[key] ?? '',
```

Read the file to understand how `streamName` is displayed downstream. If the display widget concatenates `"$gradeLabel · $streamName"`, an empty string will just show the grade label without a separator. Verify this works correctly.

**Fix 2 — `exam_detail_page.dart` (~L3009–3010):**

```dart
// BEFORE:
? (streamNames[key.stream] ?? 'Stream ${key.stream}')
// AFTER:
? (streamNames[key.stream] ?? '')
```

Same rationale — never show raw stream code. The surrounding code should handle empty strings gracefully (it's just a label).

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Bug Group 2: Attendance Marking — Permission Re-evaluation on Stream Change

### Task 5: Add `didUpdateWidget` to `_AttendanceTabState` to re-resolve `_canMark` on prop changes

**Files to modify:** `lib/ui/screens/school_dashboard/academics/tabs/attendance_tab.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

**Problem:** In `_AttendanceTabState` (~L125), `_resolveCanMark()` is called only once in `initState()` (~L168). There is **no `didUpdateWidget` override** in the class (confirmed by grep). The class uses `AutomaticKeepAliveClientMixin`, so the state is kept alive across parent rebuilds.

When the user switches stream tabs in `GradeDetailPage`, the `AttendanceTab` widget receives a new `streamCode` prop. Without `didUpdateWidget`, `_canMark` retains its stale value from the original `initState`:

- **Teacher lands on stream A (not class teacher):** `_canMark = false`. Switches to stream B (IS class teacher) → `_canMark` stays `false` → **cannot mark attendance despite being class teacher** ← reported bug.
- **Inverse:** Teacher lands on stream where they ARE class teacher → `_canMark = true`. Switches to a stream they're NOT class teacher for → `_canMark` stays `true` → **unauthorized marking possible**.

For owners, `_canMark = true` unconditionally from `initState`, so the stale value doesn't cause functional issues. However, the user reported that marking "does not work" for owners as well — this may be a separate UI issue (e.g. landing on the attendance content tab before a specific stream is selected, so `_selectedStreamCode` is null and falls back to the first stream which might have no enrollments). Include diagnostic logging to help debug.

**Fix — Add `didUpdateWidget` override:**

Add after `initState()` (~L170):

```dart
@override
void didUpdateWidget(covariant AttendanceTab oldWidget) {
  super.didUpdateWidget(oldWidget);
  // Re-resolve marking permission when the stream, grade, year, or term changes.
  if (oldWidget.streamCode != widget.streamCode ||
      oldWidget.grade != widget.grade ||
      oldWidget.year != widget.year ||
      oldWidget.term != widget.term) {
    debugPrint(
      '[AttendanceTab] didUpdateWidget: stream ${oldWidget.streamCode}→${widget.streamCode}, '
      'grade ${oldWidget.grade}→${widget.grade}',
    );
    // Reset to loading state to prevent stale canMark leaking to children.
    setState(() {
      _loadingCanMark = true;
      _canMark = false;
    });
    _resolveCanMark();
  }
}
```

**Also update the date state on stream change.** The `_selectedDateEpochDays` and `_calendarMonth` don't need resetting, but verify that the `_AttendanceMarkingBody`'s `ValueKey` already includes `widget.streamCode` (it does, at ~L349). This means the body widget IS recreated on stream change — it just received the stale `_canMark` value before this fix.

**Diagnostic logging for owners:** Add a `debugPrint` inside the `OwnerEntry` branch of `_resolveCanMark()`:

```dart
case OwnerEntry():
  debugPrint('[AttendanceTab] _resolveCanMark: OwnerEntry → canMark=true');
  result = true;
```

And for TeacherEntry:

```dart
case TeacherEntry():
  final userId = cache.currentUser!.user.id;
  result = await _membersDao.isClassTeacherFor(
    schoolId: widget.schoolId,
    year: widget.year,
    term: widget.term,
    grade: widget.grade,
    stream: widget.streamCode,
    teacherUserId: userId,
  );
  debugPrint(
    '[AttendanceTab] _resolveCanMark: TeacherEntry, userId=$userId, '
    'grade=${widget.grade}, stream=${widget.streamCode} → canMark=$result',
  );
```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note `_AttendanceTabState` now re-resolves `_canMark` on stream change
- [ ] Mark this task `[x]`

---

## Bug Group 3: Paper Status Progression — Split canManage into canProgress and canGrade

### Task 6: Split `_canManage` into `_canProgressStatus` and `_canGradeContent` in PaperDetailPage

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

**Problem:** In `_PaperDetailPageState` (~L146–160), the single `_canManage` getter controls ALL paper management actions: status progression, grade entry, answer sheet submission, AI marking, delete, and scheme uploads. For teachers, it checks whether the teacher teaches the specific subject to the paper's grade/stream via `_teacherSubjects`.

This is too restrictive for **status progression**. The user reports: when one paper in an exam is marked (a subject the teacher teaches), the progression button is hidden for other papers (subjects the teacher does NOT teach). The user interprets this as "when one paper is marked, the whole exam gets considered as marked."

**Root cause:** Status progression (Pending → In Progress → Done → Marked) is an **exam management** action, not a grading action. A teacher who created the exam or has exam-level permissions should be able to progress ANY paper's status in their exam, even papers for subjects they don't personally teach. However, grade entry and answer sheet submission should remain restricted to teachers who teach that specific subject.

**Fix — Split into two getters:**

Replace the current `_canManage` getter (~L146–160) with two:

```dart
/// Whether the current user can progress the paper's status (advance button),
/// delete the paper, edit the invigilator, or manage the scheme.
/// This is an exam-level management action — not subject-specific.
bool get _canProgressStatus {
  final entry = widget.schoolContext.currentEntry.value;
  // Owners and staff can manage any paper.
  if (entry is OwnerEntry || entry is StaffEntry) return true;
  if (entry is TeacherEntry) {
    // Teacher can progress status if:
    // 1. They created the exam (exam.teacher matches their user ID), OR
    // 2. They are the invigilator of this paper, OR
    // 3. They teach this subject to this class, OR
    // 4. They have the exams.update permission
    final userId = entry.teacher.user;
    if (_exam.teacher == userId) return true;
    if (_paper.invigilator == userId) return true;
    if (widget.schoolContext.permissions.can(
      Resource.exams,
      Action.update,
    )) return true;
    // Fall through to subject-teaching check
    return _teacherSubjects.any(
      (st) =>
          st.grade == _paper.grade &&
          st.subject == _paper.subject &&
          (_paper.stream == null || st.stream == _paper.stream),
    );
  }
  return false;
}

/// Whether the current user can enter grades, submit answer sheets, or
/// trigger AI marking for this paper. This IS subject-specific for teachers.
bool get _canGradeContent {
  final entry = widget.schoolContext.currentEntry.value;
  if (entry is OwnerEntry || entry is StaffEntry) return true;
  if (entry is TeacherEntry) {
    return _teacherSubjects.any(
      (st) =>
          st.grade == _paper.grade &&
          st.subject == _paper.subject &&
          (_paper.stream == null || st.stream == _paper.stream),
    );
  }
  return false;
}
```

Add the necessary import for `Resource` and `Action` if not already present:
```dart
import '../../../../models/permissions.dart' as perms;
```
Then use `perms.Resource.exams` and `perms.Action.update`. Check the existing imports — the file may already import permissions under a different alias or directly. Match the existing pattern.

**Now update all usages of `_canManage`:**

1. **`_PaperHeader` construction (~L396–397):**
   ```dart
   // BEFORE:
   canEdit: _canManage,
   canManage: _canManage,

   // AFTER:
   canEdit: _canProgressStatus,
   canManage: _canProgressStatus,
   ```
   The `canEdit` and `canManage` props on `_PaperHeader` control the status advancement button, delete button, invigilator edit, and scheme management — all exam-level actions.

2. **`_GradeSpreadsheet` construction (~L433):**
   ```dart
   // BEFORE:
   canGrade: _canManage,

   // AFTER:
   canGrade: _canGradeContent,
   ```

3. **`_GradeList` construction (~L489):**
   ```dart
   // BEFORE:
   canGrade: _canManage,

   // AFTER:
   canGrade: _canGradeContent,
   ```

4. **Delete the old `_canManage` getter** — it's fully replaced by the two new getters.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — note `_canManage` split into `_canProgressStatus` and `_canGradeContent`
- [ ] Mark this task `[x]`

---

### Task 7: Update `_PaperHeader` to use separate `canManage` for status vs `canGrade` for scheme

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** Task 6
**Parallel group:** —

**Specification:**

**Problem:** After Task 6, `_PaperHeader.canManage` now reflects `_canProgressStatus` (exam-level). However, some features inside `_PaperHeader` that were gated by `canManage` are actually grading-related and should use the subject-specific `_canGradeContent` instead:

- **Scheme file management** (upload/view marking scheme): This is grading infrastructure — only relevant if the teacher can grade the paper. Should use `canGrade`.
- **Status advancement button**: Exam management — should use `canManage` (already correct after Task 6).
- **Delete button**: Exam management — should use `canManage` (already correct).
- **Invigilator edit**: Exam management — should use `canEdit`/`canManage` (already correct).

**Fix — Add `canGrade` prop to `_PaperHeader`:**

1. Add a new field to the `_PaperHeader` widget class (~L554):
   ```dart
   final bool canGrade;
   ```

2. Add `required this.canGrade` to the constructor.

3. Update the `_PaperHeader` construction in `_PaperDetailPageState.build()` (~L390) to pass the new prop:
   ```dart
   _PaperHeader(
     paper: currentPaper,
     exam: widget.exam,
     schoolId: widget.schoolId,
     subjectNames: widget.subjectNames,
     cs: cs,
     canEdit: _canProgressStatus,
     canManage: _canProgressStatus,
     canGrade: _canGradeContent,  // ← NEW
     dao: _dao,
     // ... rest unchanged
   ),
   ```

4. In `_PaperHeaderState`, change the scheme button visibility check (~L1009) from `widget.canManage` to `widget.canGrade`:
   ```dart
   // BEFORE:
   if (widget.canManage) ...[
     const SizedBox(height: 8),
     GestureDetector(
       // scheme button...

   // AFTER:
   if (widget.canGrade) ...[
     const SizedBox(height: 8),
     GestureDetector(
       // scheme button...
   ```

5. The status advancement button (~L1126) should remain gated by `widget.canManage` (now `_canProgressStatus`):
   ```dart
   if (widget.canManage)
     AnimatedBuilder(
       animation: Listenable.merge([...]),
       builder: (_, __) => _buildActionButton(status, isMarked, color, nextColor),
     ),
   ```
   This is already correct — no change needed here.

6. The delete button (~L1110) should remain gated by `widget.canManage`:
   ```dart
   if (widget.canManage && isPending) ...[
   ```
   Already correct — no change.

**Update after completion:**
- [ ] Mark this task `[x]`

---

## Summary

| Task | Bug Group | Description | Parallel Group | Depends On |
|------|-----------|-------------|---------------|------------|
| 1 | 1 | Remove Attendance nav item from teacher role | P1 | — |
| 2 | 1 | Fix `_loadConfig()` stub to load SchoolConfig from streams | P1 | — |
| 3 | 1 | Replace raw-integer fallbacks with `gradeLabel()` in attendance_screen | — | Task 2 |
| 4 | 1 | Audit & fix raw-integer fallbacks in my_classes + exam_detail | P1 | — |
| 5 | 2 | Add `didUpdateWidget` to re-resolve `_canMark` on stream change | P2 | — |
| 6 | 3 | Split `_canManage` into `_canProgressStatus` + `_canGradeContent` | P2 | — |
| 7 | 3 | Add `canGrade` prop to `_PaperHeader` for scheme visibility | — | Task 6 |

**Execution order:**
- **Batch 1 (parallel):** Tasks 1, 2, 4, 5, 6 (all independent, touch different files)
- **Batch 2 (sequential):** Task 3 (depends on Task 2 — same file)
- **Batch 3 (sequential):** Task 7 (depends on Task 6 — same file)

> **Note on Task 5 + owner debugging:** The examiner could not reproduce the owner's attendance marking failure from code alone — the `_resolveCanMark` logic for `OwnerEntry` unconditionally returns `true`. The `didUpdateWidget` fix and diagnostic logging added in Task 5 will help the project owner identify the root cause if the issue persists after deployment. Possible causes include: no enrolled students in the selected stream, or the owner accessing attendance from the "All" stream tab where `_selectedStreamCode` falls back to the first stream.