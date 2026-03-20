# TASKS.md

> Exam papers visual redesign — match timetable cell compactness and language.
> Two tasks, fully parallel (different files, no shared state).

---

### [x] Task 01: Redesign paper cell widgets in `exams_grades_screen.dart`

**Files to modify:** `lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** None — all context inlined below.
**Depends on:** Nothing
**Parallel group:** P1

---

**Background (do NOT read any other files — everything you need is here):**

The goal is to make exam paper cells in the cross-table grid and mobile list match
the visual language of the timetable's `_SWSlotCell`: compact, left-accent-only
border, tight text, no boxing.

`AppTheme.kChipRadius = 4.0`, `AppTheme.kCardRadius = 8.0`. Both are available
as static consts on `AppTheme`.

`_paperStatusColor(PaperStatus status, ColorScheme cs)` is a top-level function
in this file that returns a `Color` for a given paper status.

`_fmtTime(DateTime dt)` is a top-level function in this file that formats a time.

`FontFeature` is from `dart:ui` (already imported in the file via Flutter).

---

**Specification:**

#### Change A — Rewrite `_PaperSlotBox.build()` [approximately L6538–L6635]

The class fields stay unchanged. Only `build()` is replaced.

Current signature: `Widget build(BuildContext context)`

Key changes vs. current:
- Read `isDark` from context: `Theme.of(context).brightness == Brightness.dark`
- Remove `ClipRRect` wrapper (no longer needed — no full-border box)
- Remove `maxHeight: 68`; change `minHeight: 68` → `minHeight: 52`
- Border: change from four-sided box to **LEFT BORDER ONLY**
- Left border color: `statusColor.withValues(alpha: 0.65)` (was full opacity)
- Background alpha: `isDark ? 0.12 : 0.08` (was hard-coded `0.06`)
- Container `borderRadius`: `AppTheme.kChipRadius` (same numeric value 4.0, but use the constant)
- Outer `Padding`: `horizontal: 4` → `horizontal: 2`
- Container padding: `all(6)` (was `fromLTRB(8, 7, 8, 7)`)
- `paperLabel`: `' · P${paper.paper}'` (was `' · Paper ${paper.paper}'`)
- Subject `Text`: fontSize `11.5`, height `1.2` (was 12, no height)
- Time range: if `startMs == 0` → skip time row entirely (was showing "Time not set")
- Time `Text`: fontSize `10`, weight `w400`, alpha `0.65`, height `1.2`, `fontFeatures: [FontFeature.tabularFigures()]`
- Invigilator `Text`: no "Inv:" prefix — show name directly; fontSize `9.5`, weight `w300`, alpha `0.45`, height `1.2`
- Add `const SizedBox(height: 1)` before invigilator text (instead of height: 2)

Replace the entire `build()` body with:

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final subjectName = subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
  final paperLabel = (paper.paper ?? 1) > 1 ? ' · P${paper.paper}' : '';
  final startMs = paper.start.toInt();
  final endMs = paper.end.toInt();
  final timeUnset = startMs == 0;
  final timeRange = timeUnset
      ? null
      : '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(startMs * 1000))}'
            ' – '
            '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(endMs * 1000))}';
  final invDisplay = invigilatorName.isNotEmpty ? invigilatorName : '—';

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border(
            left: BorderSide(
              color: statusColor.withValues(alpha: 0.65),
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$subjectName$paperLabel',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (timeRange != null) ...[
              const SizedBox(height: 2),
              Text(
                timeRange,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(height: 1),
            Text(
              invDisplay,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

#### Change B — Rewrite `_PaperEmptyCell.build()` [approximately L6643–L6658]

The class field `cs` stays unchanged. Only `build()` is replaced.

Key changes:
- Read `isDark` from context
- Remove `maxHeight: 68`; change `minHeight: 68` → `minHeight: 52`
- Outer `Padding`: `horizontal: 4` → `horizontal: 2`
- Border: `Border.all(color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08), width: 1)`
  (was `cs.outlineVariant.withValues(alpha: 0.2)`, and note the switch from `outlineVariant`
  to `outline` — this is intentional to match `_SWEmptyCell`)
- `borderRadius`: `AppTheme.kChipRadius`

Replace the entire `build()` body with:

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
          width: 1,
        ),
      ),
    ),
  );
}
```

---

#### Change C — Two targeted edits inside `_ExamGroupCrossTable.build()` [approximately L6073–L6199]

Inside the `dates.map((date) { ... })` lambda, in the **non-empty cell branch** (where
`cellPapers.isNotEmpty`), there are two values to change:

1. The outer `Padding` wrapping the `Column` of `_PaperSlotBox` widgets:
   - Find: `padding: const EdgeInsets.symmetric(horizontal: 4),`
   - Replace with: `padding: const EdgeInsets.symmetric(horizontal: 2),`

2. The inter-cell gap between stacked papers (inside the `for` loop, guarded by
   `if (i < cellPapers.length - 1)`):
   - Find: `const SizedBox(height: 4),`
   - Replace with: `const SizedBox(height: 3),`

Note: the empty-cell branch (`cellPapers.isEmpty`) uses `_PaperEmptyCell` directly —
no change needed there; Change B already handles it.

---

#### Change F — Targeted edits to `_PaperSlotCard.build()` [approximately L6988–L7107]

The class fields stay unchanged. Inside `build()`, make these specific changes:

**F-1. Container constraints:** `minHeight: 68` → `minHeight: 60`

**F-2. Container padding:** `fromLTRB(12, 10, 12, 10)` → `fromLTRB(12, 8, 12, 8)`

**F-3. Remove "Inv:" prefix:** In the third `Text` widget (the invigilator line),
change `'Inv: $invDisplay'` → `invDisplay`. The variable `invDisplay` already holds
`'—'` as fallback, so no further change needed.

**F-4. Add `height: 1.2`** to all three `TextStyle`s in the left `Column`:
- Subject `Text`: add `height: 1.2`
- Time range `Text`: add `height: 1.2`
- Invigilator `Text`: add `height: 1.2`

**F-5. Replace the right-side `Column`** (currently contains `_StatusChip` + `SizedBox(height: 4)` +
`Icon(chevron_right_rounded)`). Replace the entire right `Column` with:

```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: statusColor.withValues(alpha: 0.75),
      ),
    ),
    const SizedBox(height: 5),
    Icon(
      Icons.chevron_right_rounded,
      size: 16,
      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
    ),
  ],
),
```

The `_StatusChip` class itself remains in the file — do NOT delete it. It is simply
no longer referenced by `_PaperSlotCard`.

---

#### Change H (optional) — Column width constants in `_ExamGroupCrossTable.build()`

These two constants appear near the top of `_ExamGroupCrossTable.build()`:

```dart
const double rowLabelWidth = 140;
const double colWidth = 152;
```

Change to:

```dart
const double rowLabelWidth = 128;
const double colWidth = 140;
```

Apply only if the change does not cause row-label text to overflow. If the 128px
label width causes grade+stream labels (e.g. "Senior 3 · Blue Stream") to overflow,
revert `rowLabelWidth` to `140` and keep only the `colWidth` reduction.

Note: `_PaperTimetableGrid` already uses `dateColWidth = 140` — no change needed there.

---

**Update after completion:**
- [ ] Mark this task `[x]` in TASKS.md
- [ ] Commit: `git add -A && git commit -m "ui: redesign exam paper cells in exams_grades_screen"`

---

### [x] Task 02: Redesign paper cell widgets in `exam_detail_page.dart`

**Files to modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None — all context inlined below.
**Depends on:** Nothing
**Parallel group:** P1

---

**Background (do NOT read any other files — everything you need is here):**

`AppTheme.kChipRadius = 4.0`, `AppTheme.kCardRadius = 8.0`.

`_examPaperStatusColor(PaperStatus status, ColorScheme cs)` is a top-level function
in this file that returns a `Color` for a given paper status.

`_fmtTime(DateTime dt)` and `_fmtDate(DateTime dt)` are top-level functions in this file.

`_PaperStatusChip` is a class defined later in this same file AND is also used in
`paper_detail_page.dart`. Do NOT delete the class. It is simply removed from
`_PaperTimetableCard`'s build method.

`FontFeature` is from `dart:ui` (already imported in the file via Flutter).

---

**Specification:**

#### Change D — Rewrite `_PapersCrossTable._buildCell(...)` [approximately L3020–L3100]

The `_buildCell` method signature stays unchanged:
```dart
Widget _buildCell(Paper paper, ColorScheme cs, bool isDark, Color borderColor)
```

Key changes vs. current:
- Remove `ClipRRect` wrapper
- Remove `maxHeight: 68`; change `minHeight: 68` → `minHeight: 52`
- Border: change from four-sided box to **LEFT BORDER ONLY**
- Left border color: `statusColor.withValues(alpha: 0.65)` (was `statusColor` full opacity)
- Background alpha: `isDark ? 0.12 : 0.08` (was `0.06`)
- Container `borderRadius`: `AppTheme.kChipRadius`
- `InkWell borderRadius`: `AppTheme.kChipRadius`
- Container padding: `all(6)` (was `fromLTRB(8, 7, 8, 7)`)
- `paperLabel`: `' · P${paper.paper}'` (was `' · Paper ${paper.paper}'`)
- Subject `Text`: fontSize `11.5`, height `1.2` (was 12, no height)
- Time range: if `startMs == 0` → skip time row entirely (was showing "Time not set")
- Time `Text`: fontSize `10`, weight `w400`, alpha `0.65`, height `1.2`, `fontFeatures: [FontFeature.tabularFigures()]`
- Note: `_PapersCrossTable` does NOT have invigilator names — only 2 text lines (subject + time).
  Do NOT add an invigilator line. This is intentional and correct.

Replace the entire `_buildCell` method body with:

```dart
Widget _buildCell(
  Paper paper,
  ColorScheme cs,
  bool isDark,
  Color borderColor,
) {
  final statusColor = _examPaperStatusColor(paper.status, cs);
  final subjectName = subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
  final paperLabel = paper.paper != null && paper.paper! > 1
      ? ' · P${paper.paper}'
      : '';
  final startMs = paper.start.toInt();
  final endMs = paper.end.toInt();
  final timeUnset = startMs == 0;
  final timeRange = timeUnset
      ? null
      : '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(startMs * 1000))}'
            ' – '
            '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(endMs * 1000))}';

  return InkWell(
    onTap: () => onTap(paper),
    splashFactory: NoSplash.splashFactory,
    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border(
          left: BorderSide(
            color: statusColor.withValues(alpha: 0.65),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$subjectName$paperLabel',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (timeRange != null) ...[
            const SizedBox(height: 2),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                height: 1.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

---

#### Change E — Three targeted edits inside `_PapersCrossTable.build()` [approximately L2802–L3019]

**E-1. Empty cell branch** (`cellPapers.isEmpty`):

Find the current empty-cell return which looks like:
```dart
if (cellPapers.isEmpty) {
  return SizedBox(
    width: colWidth,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68, maxHeight: 68),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(color: borderColor, width: 1),
        ),
      ),
    ),
  );
}
```

Replace with:
```dart
if (cellPapers.isEmpty) {
  return SizedBox(
    width: colWidth,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.08),
            width: 1,
          ),
        ),
      ),
    ),
  );
}
```

**E-2. Occupied cell outer padding:** In the non-empty cell return, find the `Padding`
wrapping the `Column` of `_buildCell` calls:
- Find: `padding: const EdgeInsets.symmetric(horizontal: 4),`
- Replace with: `padding: const EdgeInsets.symmetric(horizontal: 2),`

**E-3. Inter-cell gap:** Inside the `for` loop (guarded by `if (i < cellPapers.length - 1)`):
- Find: `const SizedBox(height: 4),`
- Replace with: `const SizedBox(height: 3),`

---

#### Change G — Targeted edits to `_PaperTimetableCard.build()` [approximately L2620–L2736]

The class fields stay unchanged. Inside `build()`, make these specific changes:

**G-1. Container constraints:** `minHeight: 60` stays at 60 — **no change needed**.

**G-2. Container padding:** `fromLTRB(10, 10, 10, 10)` → `fromLTRB(10, 8, 10, 8)`

**G-3. Add `height: 1.2`** to both `TextStyle`s in the left `Column`:
- Subject+paperLabel `Text` (fontSize 12.5): add `height: 1.2`
- Date/time range `Text` (fontSize 10.5): add `height: 1.2`

**G-4. Replace the right-side row tail** (currently `_PaperStatusChip` + `SizedBox(width: 4)` +
`Icon(chevron_right)`). In the outer `Row`, after the left `Expanded` column and `SizedBox(width: 8)`,
replace:
```dart
_PaperStatusChip(status: paper.status, cs: cs),
const SizedBox(width: 4),
Icon(
  Icons.chevron_right,
  size: 16,
  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
),
```
with:
```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _examPaperStatusColor(paper.status, cs).withValues(alpha: 0.75),
      ),
    ),
    const SizedBox(height: 5),
    Icon(
      Icons.chevron_right_rounded,
      size: 16,
      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
    ),
  ],
),
```

Note: `statusColor` is already computed at the top of `build()` as
`_examPaperStatusColor(paper.status, cs)`. You may use `statusColor` instead of
re-calling `_examPaperStatusColor(paper.status, cs)` in the dot decoration.

The `_PaperStatusChip` class itself remains in the file — do NOT delete it.

---

#### Change H (optional) — Column width constants in `_PapersCrossTable.build()`

These two constants appear near the top of `_PapersCrossTable.build()`:

```dart
const double rowLabelWidth = 120;
const double colWidth = 152;
```

Change to:

```dart
const double rowLabelWidth = 110;
const double colWidth = 140;
```

Apply only if the change does not cause stream name row labels to overflow. If
`110px` is too narrow for labels like "Blue Stream" or "All Streams", revert
`rowLabelWidth` to `120` and keep only the `colWidth` reduction.

---

**Update after completion:**
- [ ] Mark this task `[x]` in TASKS.md
- [ ] Commit: `git add -A && git commit -m "ui: redesign exam paper cells in exam_detail_page"`

---

## Regression Notes (from BUG.md — read before touching these files)

- **BUG-001 / BUG-002**: The `papers` table composite PK is `(school, exam, subject, paper, grade, stream)`.
  Any DAO query or mutation on the `papers` table MUST include all six PK columns.
  **The changes in Tasks 01 and 02 are purely visual (widget `build()` methods and layout
  constants) and do NOT touch any DAO calls, stream subscriptions, or database logic.
  No regression risk from BUG-001/002 for these tasks.**

- **BUG-003**: `_PaperHeader` must use `paper.invigilator` (not `exam.teacher`) for the
  invigilator display. `_PaperSlotBox` already uses `invigilatorName` (passed in as a
  resolved string from the parent). Change A only changes how that string is *displayed*
  (removes "Inv:" prefix). The resolved value and resolution logic are untouched.

- **BUG-006**: `_applyPapers` in `delta_writer.dart` is not touched by these tasks.