# EduXal — Task Board

> **Workflow:** Examiner writes tasks → Orchestrator dispatches → Executor implements.
> Each task is self-sufficient. The executor should not need to explore the codebase.

---

## Phase 1 — Layout Stability

### Task 01: Unify dashboard layout to preserve navigation state across breakpoints ✅
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/school_dashboard_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

The `_buildLayout` method in `_DashboardShellState` (lines 338–407) currently uses a `switch` on `_LayoutMode` that produces **three structurally different widget subtrees**:
- `full` → `Row > [_FullSidebar, Expanded(_wrapSidebarContent(content))]`
- `rail` → `Row > [_IconRail, Expanded(_wrapSidebarContent(content))]`
- `mobile` → `SafeArea > Column > [_TabLayoutTopBar, _PillTabStrip, Expanded(content)]`

Even with the `KeyedSubtree(key: ValueKey('dashboard-content'))` wrapping the content widget (built at line 319), Flutter tears down the element tree when the structural ancestors change this drastically (Column→Row, different wrapper depth). This causes exam/paper detail state loss when crossing the 600px breakpoint.

**Fix — single unified tree structure for all modes:**

Replace the `_buildLayout` method body (lines 338–407) with a single consistent tree. The content widget must always appear at the **exact same depth** in the Element tree regardless of mode. Here is the required structure:

```dart
Widget _buildLayout(
  BuildContext ctx,
  MembershipEntry currentEntry,
  _LayoutMode mode,
  Widget content,
) {
  final cs = Theme.of(ctx).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  final isMobile = mode == _LayoutMode.mobile;

  // Build the sidebar/rail widget — zero-width SizedBox for mobile
  Widget navigationChrome;
  switch (mode) {
    case _LayoutMode.full:
      navigationChrome = _FullSidebar(
        schoolContext: widget.schoolContext,
        currentEntry: currentEntry,
        items: _currentItems,
        selectedIndex: _selectedIndex,
        onItemSelected: _selectIndex,
        onRoleSwitchTap: () => _showRoleSwitcherSheet(ctx),
        activeTermContext: widget.activeTermContext,
      );
    case _LayoutMode.rail:
      navigationChrome = _IconRail(
        schoolContext: widget.schoolContext,
        currentEntry: currentEntry,
        items: _currentItems,
        selectedIndex: _selectedIndex,
        onItemSelected: _selectIndex,
        onRoleSwitchTap: () => _showRoleSwitcherSheet(ctx),
        activeTermContext: widget.activeTermContext,
      );
    case _LayoutMode.mobile:
      navigationChrome = const SizedBox.shrink();
  }

  // Wrap content the same way for desktop/rail (padded card); raw for mobile
  final wrappedContent = isMobile
      ? Expanded(child: content)
      : Expanded(child: _wrapSidebarContent(cs, content));

  // The Row is always present. For mobile, navigationChrome is zero-width.
  final mainRow = Row(
    children: [
      navigationChrome,
      wrappedContent,
    ],
  );

  return Scaffold(
    backgroundColor: cs.surfaceContainerLowest,
    body: SafeArea(
      // SafeArea wraps all modes uniformly
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mobile top bar — hidden for desktop/rail
          if (isMobile)
            _TabLayoutTopBar(
              schoolContext: widget.schoolContext,
              currentEntry: currentEntry,
              activeTermContext: widget.activeTermContext,
              onRoleSwitchTap: widget.schoolContext.canSwitch
                  ? () => _showRoleSwitcherSheet(ctx)
                  : null,
            ),
          // Mobile pill tab strip — hidden for desktop/rail
          if (isMobile)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: _PillTabStrip(
                items: _currentItems,
                controller: _tabController,
                isDark: isDark,
                cs: cs,
              ),
            ),
          // Main content row — always at the same tree position
          Expanded(child: mainRow),
        ],
      ),
    ),
  );
}
```

**Key constraint verified:** `content` is always the child of `wrappedContent` (`Expanded`) → child of `mainRow` (`Row`, index 1) → child of the outer `Expanded` → child of `Column` (last child) → child of `SafeArea` → child of `Scaffold.body`. This path is **identical** regardless of mode. Only the `if (isMobile)` widgets above it add/remove siblings in the Column, but the `Expanded(child: mainRow)` remains at a stable position.

**Note on SafeArea:** The old desktop/rail modes did NOT use `SafeArea`. Wrapping all modes in `SafeArea` is harmless on desktop (no insets) and correct for mobile. If the full/rail sidebar previously relied on painting into the safe area insets, verify visually — but since the sidebar is inside the `Row` inside `SafeArea`, it will still render correctly.

**Update after completion:**
- [x] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note that `_buildLayout` now uses a unified tree structure for all layout modes
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Phase 2 — State Preservation

### Task 02: Preserve mobile paper timetable day tab index across navigation
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

`_PaperTimetableMobile` (line ~6137) has local `_selectedDayIndex` state that resets to 0 when navigating to paper detail and back. The fix follows the existing grade-tab/stream-tab preservation pattern already in `_ExamsShellState`.

**Step 1 — Add `_selectedDayIndex` to `_ExamsShellState` (around line 82):**

Add a new field after `_selectedStreamIndex`:
```dart
int? _selectedDayIndex;
```

**Step 2 — Capture day index in `_openPaper` (line ~186):**

Modify `_openPaper` to accept an optional `dayIndex` parameter and store it:
```dart
void _openPaper(Paper paper, Exam exam, int grade, {int streamIndex = 0, int dayIndex = 0}) {
  setState(() {
    _selectedPaper = paper;
    _selectedExamRow = exam;
    _selectedExamGrade = grade;
    _selectedStreamIndex = streamIndex;
    _selectedDayIndex = dayIndex;
    _view = _ExamsView.paperDetail;
  });
}
```

**Step 3 — Keep `_selectedDayIndex` in `_popToExam` (line ~197):**

`_popToExam` already keeps `_selectedExamGrade` and `_selectedStreamIndex`. Add a comment showing `_selectedDayIndex` is also kept (it's not cleared, so it survives).

**Step 4 — Clear `_selectedDayIndex` in `_popToList` (line ~204):**

Add `_selectedDayIndex = null;` alongside the other resets.

**Step 5 — Thread `initialDayIndex` through `_ExamGroupDetailView`:**

Add a new optional parameter to `_ExamGroupDetailView` (line ~700):
```dart
this.initialDayIndex = 0,
```
And the corresponding field:
```dart
final int initialDayIndex;
```

In the shell's `build` method where `_ExamGroupDetailView` is constructed (around line 269), pass:
```dart
initialDayIndex: _selectedDayIndex ?? 0,
```

**Step 6 — Thread through `_PaperContentArea`:**

Add to `_PaperContentArea` constructor (line ~5592):
```dart
this.initialDayIndex = 0,
```
And field:
```dart
final int initialDayIndex;
```

In `_ExamGroupDetailViewState.build` where `_PaperContentArea` is constructed (line ~1281), pass:
```dart
initialDayIndex: widget.initialDayIndex,
```

**Step 7 — Thread through `_PaperTimetableMobile`:**

Add to `_PaperTimetableMobile` constructor (line ~6138):
```dart
this.initialDayIndex = 0,
```
And field:
```dart
final int initialDayIndex;
```

In `_PaperContentAreaState.build` where `_PaperTimetableMobile` is constructed (line ~5667), pass:
```dart
initialDayIndex: widget.initialDayIndex,
```

**Step 8 — Use `initialDayIndex` in `_PaperTimetableMobileState.initState`:**

In `initState` (line ~6164), replace:
```dart
_selectedDayIndex = 0;
// (implicit — it's the field default)
```
With initialization from widget:
```dart
// In _rebuildGroups, called from initState:
// Replace the line `_selectedDayIndex = _selectedDayIndex.clamp(...)` logic:
// On first build, use widget.initialDayIndex
```

Actually, the simplest approach: in `initState`, set `_selectedDayIndex = widget.initialDayIndex;` **before** calling `_rebuildGroups()`. The `_rebuildGroups` method already clamps the value (line ~6186: `_selectedDayIndex = _selectedDayIndex.clamp(0, (_dates.length - 1).clamp(0, 999))`), so if `initialDayIndex` exceeds bounds, it self-corrects.

**Step 9 — Add `onDayChanged` callback to propagate day index up:**

Add a callback to `_PaperTimetableMobile`:
```dart
final ValueChanged<int>? onDayChanged;
```

In `_PaperTimetableMobileState`, wherever `_selectedDayIndex` is updated (the `TabController` listener at line ~6201), call:
```dart
widget.onDayChanged?.call(_selectedDayIndex);
```

Thread this callback up through `_PaperContentArea` → `_ExamGroupDetailView` → `_ExamsShellState`. In the shell, the callback simply does:
```dart
onDayChanged: (index) {
  _selectedDayIndex = index; // No setState needed — just record it
},
```

**Step 10 — Propagate day index through `onPaperTap` chain:**

Modify the `onPaperTap` callback signature throughout the chain to include `dayIndex`:

In `_PaperTimetableMobile`, when a paper is tapped, pass the current `_selectedDayIndex`:
```dart
widget.onPaperTap(paper, widget.exam, widget.grade, streamIndex: 0);
```
This already works because the `_ExamGroupDetailView` intercepts the callback and replaces `streamIndex` with its own `_selectedStreamIndex`. The day index is captured separately via `onDayChanged`.

**Actually, the simpler approach:** Since we added `onDayChanged` which fires on every tab switch, the shell's `_selectedDayIndex` is always up-to-date by the time `_openPaper` is called. So we don't need to pass `dayIndex` through `onPaperTap` at all — the shell already has it. Just make sure `_openPaper` captures the current `_selectedDayIndex` value:

```dart
void _openPaper(Paper paper, Exam exam, int grade, {int streamIndex = 0}) {
  setState(() {
    _selectedPaper = paper;
    _selectedExamRow = exam;
    _selectedExamGrade = grade;
    _selectedStreamIndex = streamIndex;
    // _selectedDayIndex is already current from onDayChanged callback — no action needed
    _view = _ExamsView.paperDetail;
  });
}
```

So the `_openPaper` signature does NOT need a `dayIndex` parameter. The value is passively kept up-to-date via the callback.

**Update after completion:**
- [x] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note day index preservation in exams shell
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Phase 3 — Paper Header & Student Row Cleanup (Parallel)

### Task 03: Merge info card, action bar, and analytics into single `_PaperHeader`
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** None
**Parallel group:** P3

**Specification:**

Replace the three separate sections (`_PaperInfoCard`, `_PaperActionBar`, `_AnalyticsSection` + `_CompactBarChart`) with a single `_PaperHeader` widget. The old widgets should be **deleted** after the new one is complete.

**Where used in main build (lines 262–292):**
Currently:
```dart
_PaperInfoCard(...),
const SizedBox(height: 12),
_PaperActionBar(...),
const SizedBox(height: 16),
if (currentPaper.status == PaperStatus.marked) ...[
  _AnalyticsSection(...),
  const SizedBox(height: 20),
],
```

Replace with:
```dart
_PaperHeader(
  paper: currentPaper,
  exam: widget.exam,
  schoolId: widget.schoolId,
  subjectNames: widget.subjectNames,
  cs: cs,
  canEdit: _canManage,
  canManage: _canManage,
  dao: _dao,
  gradeRows: gradeRows,
  totalStudents: _students.length,
  hasDirtyGrades: _hasDirtyGrades,
  onEditInvigilator: () => _showInvigilatorPicker(context, currentPaper),
  onDeleted: widget.onBack ?? () => Navigator.of(context).pop(),
  onSaveAllGrades: () async {
    await _spreadsheetKey.currentState?.saveAllDirty();
    if (mounted) setState(() => _hasDirtyGrades = false);
  },
  // Bug 4 fields — will be wired in Task 04
  hasUnmarkedSubmissions: false,
  onAiMark: null,
  aiProgress: null,
),
const SizedBox(height: 16),
```

**`_PaperHeader` widget design:**

```dart
class _PaperHeader extends StatefulWidget {
  const _PaperHeader({
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.subjectNames,
    required this.cs,
    required this.canEdit,
    required this.canManage,
    required this.dao,
    required this.gradeRows,
    required this.totalStudents,
    required this.hasDirtyGrades,
    required this.onEditInvigilator,
    required this.onDeleted,
    required this.onSaveAllGrades,
    this.hasUnmarkedSubmissions = false,
    this.onAiMark,
    this.aiProgress,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final String schoolId;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool canEdit;
  final bool canManage;
  final ExamsGradesDao dao;
  final List<GradeRow> gradeRows;
  final int totalStudents;
  final bool hasDirtyGrades;
  final VoidCallback onEditInvigilator;
  final VoidCallback onDeleted;
  final VoidCallback onSaveAllGrades;
  final bool hasUnmarkedSubmissions;
  final VoidCallback? onAiMark;
  final double? aiProgress; // null = not marking, 0.0–1.0 = progress
}
```

**Internal layout (single rounded container):**

Use `Container` with `BoxDecoration(borderRadius: BorderRadius.circular(AppTheme.kCardRadius), border: ...)` matching the existing `_PaperInfoCard` border style.

Inside, a `Column` with these rows (separated by `Divider` or thin spacing):

**Row 1 — Title + Status:**
```
[ Subject Name — Paper N ]  ←Expanded  [ _PaperStatusChip ]
```
- Subject name from `subjectNames[paper.subject]`; paper number from `paper.paper` (if not null).
- `_PaperStatusChip` reused from existing code (it's already a standalone widget — find it in the existing `_PaperInfoCard` or `_PaperActionBar`).

**Row 2 — Date/Time (compact single line):**
```
[ Icons.schedule_outlined 14px ]  [ "Mon, 15 Jan 2025 · 08:00 – 10:00" ]
```
- Format: `EEE, d MMM y · HH:mm – HH:mm`
- Reuse the date formatting logic from `_PaperInfoCard` (lines ~470–520).

**Row 3 — Exam Type (compact single line):**
```
[ Icons.quiz_outlined 14px ]  [ Exam type label ]  [ if personalized: "Personalized" chip ]
```
- Reuse the exam type badge logic from `_PaperInfoCard` (lines ~570–630).

**Row 4 — Invigilator (always editable when `canEdit` is true):**
```
[ UserAvatar 28px ]  [ teacher name text ]  [ if canEdit: Icons.edit_outlined 14px tappable ]
```
- **CHANGE from old behavior:** Remove the `status == pending` gate. When `canEdit` is true, always show the edit icon and allow tapping to change invigilator.
- If no invigilator assigned: show "Assign invigilator" placeholder text.

**Row 5 — Analytics (conditional: only when `gradeRows` is not empty):**

Show when `gradeRows.isNotEmpty` (NOT just when `paper.status == PaperStatus.marked` — this is a deliberate change).

Layout as a `Row`:
```
[ Donut chart (CustomPaint, 80×80) ]  [ SizedBox(width: 12) ]  [ Column: graded count line + class average line ]
```

**Donut chart (`_ScoreDonut`):**
- A `CustomPainter` drawing a donut/ring chart.
- 6 segments representing distribution buckets: 0–49 (red), 50–59 (orange), 60–69 (amber), 70–79 (lightGreen), 80–89 (green), 90–100 (darkGreen).
- Use the same bucket colors as `_CompactBarChart`: `[Color(0xFFEF5350), Color(0xFFFF9800), Color(0xFFFFC107), Color(0xFF8BC34A), Color(0xFF4CAF50), Color(0xFF2E7D32)]`.
- Ring thickness: 10px. Outer radius: 36px (total 80×80 including center space).
- Center text: total graded count (e.g. "24") in `w500, fontSize 16`.
- On tap/hover of a segment: show that bucket's label and count at center instead of total. Use `GestureDetector` with hit-testing on the `CustomPainter` — or simplify by just showing the static total in center (skip interactive hover for now to keep scope reasonable).
- If all scores are in one bucket, show a full ring in that bucket's color.
- If no graded students, show a gray ring.

**Donut `CustomPainter` implementation:**

```dart
class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.strokeWidth});

  final List<_DonutSegment> segments; // each has: double fraction, Color color
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track background (gray)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFE0E0E0);
    canvas.drawCircle(center, radius, trackPaint);

    // Draw segments
    double startAngle = -math.pi / 2; // start from top
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweep = seg.fraction * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = seg.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments;
}

class _DonutSegment {
  final double fraction;
  final Color color;
  const _DonutSegment(this.fraction, this.color);
}
```

Stats next to donut:
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text('$gradedCount / $totalStudents graded', style: ...),
    const SizedBox(height: 4),
    Text('${averagePercent.toStringAsFixed(0)}% avg', style: TextStyle(
      fontSize: 20, fontWeight: FontWeight.w500,
      color: _avgColor(averagePercent), // red <50, orange <60, amber <70, green >=70
    )),
  ],
)
```

Compute `gradedCount`, `averagePercent`, and distribution from `gradeRows` using the same logic as `_AnalyticsSection._compute()` (lines 1115–1168).

**Row 6 — Bottom action row: delete button (left) + action circle (right):**
```
[ if canManage && pending: delete icon button ]  ←Spacer→  [ Action circle button ]
```

The action circle button has the same arc-progress + status-advance behavior from `_PaperActionBar`. Move the animation controllers (`_arcCtrl`, `_scaleCtrl`, `_flashCtrl`) into `_PaperHeaderState`.

**For now (Task 03), the action circle button handles these states:**
1. **Has dirty grades** → Orange border, save icon (`Icons.save_rounded`). Tap calls `onSaveAllGrades`.
2. **Normal advance** (not fully marked) → Arc progress + next-status icon. Tap advances status.
3. **Fully marked** → Green filled circle with check.

States 1 and 2 come from the old `_PaperActionBar`. The AI marking state (state for Bug 4) will be wired in Task 04.

**Reuse from old code:**
- Copy `_arcFraction`, `_statusColor`, `_statusIcon`, `_statusLabel`, `_nextStatus`, `_advance` methods from `_PaperActionBar`.
- Copy `_ArcProgressPainter` (it's used by both `_PaperActionBar` and `_MiniArcIndicator`).
- Copy animation controller setup pattern from `_PaperActionBarState`.

**Delete old widgets after `_PaperHeader` is complete:**
- Delete `_PaperInfoCard` (lines 354–680)
- Delete `_PaperActionBar` (lines 686–1031)
- Delete `_AnalyticsSection` (lines 1094–1296)
- Delete `_CompactBarChart` (lines 1302–1421)
- Keep `_PaperStatusChip` — it's reused by `_PaperHeader`.
- Keep `_ArcProgressPainter` — it's reused by `_PaperHeader`.

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note `_PaperInfoCard`, `_PaperActionBar`, `_AnalyticsSection`, `_CompactBarChart` deleted; replaced by `_PaperHeader`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 04: Clean up student row buttons in spreadsheet and mobile list
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None (same file as Task 03)
**Depends on:** None
**Parallel group:** P3 (can run in parallel with Task 03 — Task 03 modifies header area, Task 04 modifies row area, different line ranges)

**⚠️ IMPORTANT — Conflict avoidance with Task 03:**
Task 03 modifies lines ~260–1420 (header area). Task 04 modifies lines ~2117–2475 (row area) and ~2700–2830 (mobile action sheet). These ranges do NOT overlap, so they can safely run in parallel. However, Task 04 must NOT delete or modify `_AiMarkButton` (lines ~1954–2115) — that will be handled by Task 05 which depends on both.

**Specification:**

#### Part A — Desktop `_SpreadsheetRow` (lines 2117–2410)

The current row layout is:
```
[Adm] [Name + submission badge] [Score input] [Edit pencil] [% badge] [AI quick-grade _MiniArcIndicator] [Upload/check icon] [Save]
```

The target row layout is:
```
[Adm] [Name] [Score input] [% badge] [Upload icon + count overlay] [Save]
```

**Changes:**

1. **Remove the submission count badge next to name** (lines ~2228–2260):
   Delete the `if (widget.submissionCount > 0) ...[` block that renders the green badge with `Icons.description_outlined` and count text next to the student name.

2. **Remove the edit pencil icon button** (lines ~2320–2340):
   Delete the entire `if (showGradeButton)` block that renders the `Icons.edit_outlined` Tooltip/InkWell. Also delete the `else const SizedBox(width: 22)` fallback. Remove the `onGradeButtonTap` callback from the widget parameters.

3. **Remove the `_MiniArcIndicator` / AI quick-grade button** (lines ~2360–2380):
   Delete the `if (showAiGrade && widget.submissionCount > 0) ...[` block that renders the `GestureDetector` wrapping `_MiniArcIndicator`. Remove the `onQuickGradeTap` and `isQuickGrading` parameters from the widget.

4. **Change the upload/submit button** (lines ~2383–2403):
   Currently it shows `Icons.check_circle` (green) when files exist and `Icons.upload_file_outlined` (gray) when no files.
   
   Change to: **Always show `Icons.upload_file_outlined`** (same gray color). When `submissionCount > 0`, overlay a small count badge in the top-right corner of the icon:
   
   ```dart
   if (showSubmit)
     GestureDetector(
       onTap: widget.onSubmitTap,
       child: Tooltip(
         message: widget.submissionCount > 0
             ? '${widget.submissionCount} page(s) submitted'
             : 'Submit answer sheets',
         child: SizedBox(
           width: 24,
           height: 24,
           child: Stack(
             clipBehavior: Clip.none,
             children: [
               Center(
                 child: Icon(
                   Icons.upload_file_outlined,
                   size: 16,
                   color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                 ),
               ),
               if (widget.submissionCount > 0)
                 Positioned(
                   top: -2,
                   right: -2,
                   child: Container(
                     padding: const EdgeInsets.all(3),
                     decoration: BoxDecoration(
                       color: AppTheme.brandGreen,
                       shape: BoxShape.circle,
                     ),
                     child: Text(
                       '${widget.submissionCount}',
                       style: const TextStyle(
                         fontSize: 8,
                         fontWeight: FontWeight.w500,
                         color: Colors.white,
                       ),
                     ),
                   ),
                 ),
             ],
           ),
         ),
       ),
     ),
   ```

5. **Update `_SpreadsheetRow` constructor** — remove these parameters:
   - `onGradeButtonTap`
   - `onQuickGradeTap`
   - `isQuickGrading`

6. **Update all call sites of `_SpreadsheetRow`** — in `_GradeSpreadsheetState._buildRow()` (around line ~1740), remove the deleted parameters from the constructor call. Search for `_SpreadsheetRow(` to find all usages.

7. **Delete `_MiniArcIndicator`** class entirely (lines 2412–2472). It is no longer used anywhere.

#### Part B — Mobile `_GradeList` action sheet (lines ~2753–2825)

In `_openStudentActionSheet`, the action sheet currently shows:
1. "Submit Answer Sheets" — always
2. "Quick Grade with AI" — conditional
3. "Enter Grade" — always
4. "View Submissions (N)" — conditional

Change to:
1. "Submit Answer Sheets" — always (keep as-is)
2. "Enter Grade" — always (keep as-is, move to position 2)
3. Remove "Quick Grade with AI" row entirely (the unified AI button in the header handles this now)
4. Remove "View Submissions (N)" row (tapping "Submit Answer Sheets" already opens the same `_AnswerSubmissionSheet` which shows existing submissions)

#### Part C — Mobile `_GradeList` row widget

Find the mobile row widget (the `ListTile` or custom row used in `_GradeList.build`). Apply the same cleanup:
- Remove any per-row AI indicator if present
- Keep upload button with count overlay (same pattern as Part A step 4)
- The mobile row's three-dot menu calls `_openStudentActionSheet` which is already cleaned up in Part B

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note `_MiniArcIndicator` deleted, `_SpreadsheetRow` simplified, mobile action sheet cleaned up
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Phase 4 — Unified Action Button

### Task 05: Unify action circle button with AI marking behavior
**Files to create/modify:** `eduxal/lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** Task 03 (action button lives in `_PaperHeader`), Task 04 (AI marking sources cleaned up)
**Parallel group:** P4

**Specification:**

After Task 03, the `_PaperHeader` has an action circle button with states: dirty-save, normal-advance, and fully-marked. After Task 04, the per-row AI quick-grade buttons and standalone `_AiMarkButton` are removed (or ready to be removed).

This task adds AI marking as a state of the unified action circle button and removes `_AiMarkButton` entirely.

**Step 1 — Move AI marking state up to `PaperDetailPageState`:**

Add these fields to `_PaperDetailPageState` (the top-level state, around line ~70):
```dart
bool _aiMarking = false;
_AiPhase _aiPhase = _AiPhase.idle;
int _aiMarkedCount = 0;
double _aiProgress = 0.0; // 0.0–1.0
```

The `_AiPhase` enum should be defined (if not already at file scope):
```dart
enum _AiPhase { idle, analyzing, assigning, done }
```

**Step 2 — Move `_runAiMarking` logic up to `PaperDetailPageState`:**

The AI marking logic currently lives in `_GradeSpreadsheetState._runAiMarking()` (around line 1590) and `_GradeListState._runAiMarking()` (around line 2567). It needs to be callable from the header button.

Add a method to `_PaperDetailPageState`:
```dart
Future<void> _runAiMarking() async {
  // Delegate to the active grade widget (spreadsheet or list)
  if (_lastIsDesktop) {
    await _spreadsheetKey.currentState?.runAiMarking();
  } else {
    await _gradeListKey.currentState?.runAiMarking();
  }
}
```

Add a `GlobalKey` for the grade list (similar to `_spreadsheetKey`):
```dart
final _gradeListKey = GlobalKey<_GradeListState>();
```

Pass it to `_GradeList`:
```dart
_GradeList(
  key: _gradeListKey,
  ...
)
```

Make `_GradeSpreadsheetState._runAiMarking()` and `_GradeListState._runAiMarking()` public (rename to `runAiMarking`).

Have these methods report progress back to the page state via callbacks:
```dart
// In _GradeSpreadsheet / _GradeList constructors, add:
final ValueChanged<_AiPhase>? onAiPhaseChanged;
final ValueChanged<double>? onAiProgressChanged;
final ValueChanged<int>? onAiMarkedCountChanged;
```

Wire these callbacks in the `_runAiMarking` methods at each phase transition.

In `_PaperDetailPageState`, wire the callbacks:
```dart
onAiPhaseChanged: (phase) => setState(() => _aiPhase = phase),
onAiProgressChanged: (p) => setState(() => _aiProgress = p),
onAiMarkedCountChanged: (c) => setState(() => _aiMarkedCount = c),
```

**Step 3 — Compute `hasUnmarkedSubmissions`:**

Add a method/getter to both `_GradeSpreadsheetState` and `_GradeListState`:
```dart
bool get hasUnmarkedSubmissions {
  return _submissions.entries.any((e) =>
    e.value.isNotEmpty && !widget.gradeMap.containsKey(e.key));
}
```

Expose this to the page state via a callback or by checking directly:
```dart
// In _PaperDetailPageState:
bool get _hasUnmarkedSubmissions {
  if (_lastIsDesktop) {
    return _spreadsheetKey.currentState?.hasUnmarkedSubmissions ?? false;
  } else {
    return _gradeListKey.currentState?.hasUnmarkedSubmissions ?? false;
  }
}
```

**Step 4 — Update `_PaperHeader` action circle button states:**

In `_PaperHeaderState`, the action circle button now has 4 priority states:

```dart
Widget _buildActionButton() {
  // State 1: Has dirty grades → orange save
  if (widget.hasDirtyGrades && widget.paper.status != PaperStatus.marked) {
    return _buildDirtySaveButton();
  }

  // State 2: AI marking in progress → radial progress fill
  if (widget.aiProgress != null) {
    return _buildAiProgressButton();
  }

  // State 3: Has unmarked submissions → indigo/purple AI button
  if (widget.hasUnmarkedSubmissions &&
      (widget.paper.status == PaperStatus.done ||
       widget.paper.status == PaperStatus.marked)) {
    return _buildAiMarkButton();
  }

  // State 4: Normal advance or fully marked
  if (widget.paper.status == PaperStatus.marked) {
    return _buildFullyMarkedButton();
  }
  return _buildAdvanceButton();
}
```

**State 2 — AI progress button (`_buildAiProgressButton`):**
```dart
Widget _buildAiProgressButton() {
  final progress = widget.aiProgress ?? 0.0;
  final pctText = '${(progress * 100).toInt()}%';
  return SizedBox(
    width: 48,
    height: 48,
    child: CustomPaint(
      painter: _RadialFillPainter(
        progress: progress,
        fillColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
        borderColor: const Color(0xFF6366F1),
        strokeWidth: 2.5,
      ),
      child: Center(
        child: Text(
          pctText,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
    ),
  );
}
```

**`_RadialFillPainter`:**
```dart
class _RadialFillPainter extends CustomPainter {
  _RadialFillPainter({
    required this.progress,
    required this.fillColor,
    required this.borderColor,
    required this.strokeWidth,
  });
  final double progress;
  final Color fillColor;
  final Color borderColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;

    // Fill arc (from top, clockwise)
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      true,
      fillPaint,
    );

    // Border circle
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = borderColor;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialFillPainter old) =>
      old.progress != progress;
}
```

**State 3 — AI mark button (`_buildAiMarkButton`):**
```dart
Widget _buildAiMarkButton() {
  return GestureDetector(
    onTap: widget.onAiMark,
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF6366F1), width: 2.5),
      ),
      child: const Center(
        child: Icon(Icons.auto_fix_high, size: 20, color: Color(0xFF6366F1)),
      ),
    ),
  );
}
```

**Step 5 — Wire everything in main build:**

In `_PaperDetailPageState.build`, pass the new fields to `_PaperHeader`:
```dart
_PaperHeader(
  ...
  hasUnmarkedSubmissions: _hasUnmarkedSubmissions,
  onAiMark: _runAiMarking,
  aiProgress: _aiMarking ? _aiProgress : null,
),
```

**Step 6 — Remove `_AiMarkButton` widget:**

Delete the `_AiMarkButton` class (lines ~1954–2115).

Remove the `_AiMarkButton` placement from `_GradeSpreadsheetState.build` (lines ~1806–1821) and `_GradeListState.build` (lines ~2836–2852). The AI marking is now triggered only from the header's unified action button.

**Step 7 — Staggered flash effect on AI completion:**

The existing `_runAiMarking` logic in both spreadsheet and list states already includes the wave flash (30ms stagger per row). This behavior is preserved — the header button just triggers it.

When AI marking completes (`_aiPhase = done`), the progress circle should briefly show a green check before reverting:
```dart
// In the _runAiMarking callback, when phase changes to done:
if (phase == _AiPhase.done) {
  // Show check for 2 seconds, then reset
  await Future.delayed(const Duration(seconds: 2));
  if (mounted) {
    setState(() {
      _aiMarking = false;
      _aiPhase = _AiPhase.idle;
      _aiProgress = 0.0;
      _aiMarkedCount = 0;
    });
  }
}
```

**Update after completion:**
- [ ] Update `eduxal/lib/ui/screens/school_dashboard/CONTEXT.md` — note `_AiMarkButton` deleted, unified action circle in `_PaperHeader`, AI marking triggered from header
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Execution Summary

| Task | Phase | Parallel Group | Depends On | Description |
|------|-------|---------------|------------|-------------|
| 01 | 1 | P1 | — | Unify dashboard layout tree structure |
| 02 | 2 | P2 | — | Preserve mobile timetable day tab index |
| 03 | 3 | P3 | — | Merge info card + action bar + analytics → `_PaperHeader` |
| 04 | 3 | P3 | — | Clean up spreadsheet row buttons + mobile action sheet |
| 05 | 4 | P4 | 03, 04 | Unify action circle button with AI marking |

**Phase 1** (Task 01) → commit
**Phase 2** (Task 02) → commit
**Phase 3** (Tasks 03 + 04 in parallel) → commit each
**Phase 4** (Task 05) → commit