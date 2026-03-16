# TASKS.md

---

## Track A: Comparisons Tab — Stats Cards & Stream Stats Redesign

### Task A1: Redesign summary stat cards to fit in a single row using Wrap ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/tabs/comparisons_tab.dart`
**Context files to read (if needed):** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Currently the `_SummaryRow` widget (L214–282) uses a horizontal `ListView` inside a fixed `SizedBox(height: 72)`. This forces mobile users to scroll horizontally to see all 4 cards, which is poor UX.

**Changes to `_SummaryRow.build()`:**

1. Remove the outer `SizedBox(height: 72)` and `ListView(scrollDirection: Axis.horizontal)`.
2. Replace with a `Wrap` widget:
   ```
   Wrap(
     spacing: 8,
     runSpacing: 8,
     children: [ ... the 4 _SummaryCard widgets ... ],
   )
   ```
3. Each `_SummaryCard` should no longer be unconstrained width. Wrap each in a `SizedBox` or use `ConstrainedBox` with a width that allows at least 2 cards per row on mobile (roughly `(screenWidth - 48) / 2` accounting for 16px padding on each side and 8px spacing, or simpler: use `IntrinsicWidth` and let `Wrap` handle it).

**Changes to `_SummaryCard` (L284–363):**

1. Make the card more compact:
   - Reduce icon container from `34×34` to `28×28`.
   - Reduce icon size from `16` to `14`.
   - Reduce horizontal padding from `14` to `10`.
   - Reduce vertical padding from `10` to `8`.
   - Reduce label font size from `10.5` to `9.5`.
   - Reduce value font size from `14` to `12.5`.
   - Reduce spacing between icon container and text from `10` to `8`.
2. Wrap the `_SummaryCard` in a `ConstrainedBox(constraints: BoxConstraints(minWidth: 130, maxWidth: 180))` so cards are small enough to fit 2 per row on narrow screens (~360px) and up to 4 on wider screens.
3. Keep the existing accent color scheme and gradient icon container — just make it smaller.

**Result:** On mobile (360px), cards wrap into 2 rows of 2. On tablet/desktop, all 4 fit in one row. No horizontal scrolling needed.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A2: Redesign stream comparison cards — compact cards on mobile, donut charts on desktop ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/tabs/comparisons_tab.dart`
**Context files to read (if needed):** `lib/ui/theme/app_theme.dart`, `lib/models/grade_analytics.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Currently each `_StreamComparisonCard` (L369–590) takes the full width with a stats grid of 2×2 cells with horizontal progress bars. Each stream takes the full width, which is too much space.

**Replace the current layout with a responsive design:**

#### Mobile (< 600px): Compact number cards in a wrapping grid

Replace the current full-width `_StreamComparisonCard` list with a `Wrap` layout where at least 3 stream cards fit per row.

Create a new widget `_CompactStreamCard` that replaces `_StreamComparisonCard` on mobile:
- Width: roughly `(screenWidth - 32 - 16) / 3` for 3 per row (16px outer padding each side, 8px spacing × 2).
- Use `LayoutBuilder` in the parent to determine breakpoint.
- Layout per card:
  - Top: Stream name (12px, w500) + colored dot (6px) in a row.
  - Below name: `_TrajectoryBadge` (existing widget, already compact).
  - Below that: 4 stat rows, each a simple label + percentage value:
    - `Avg: XX%` — colored by `_percentColor`
    - `Last: XX%` or `—`
    - `Att: XX%` or `—`
    - `Mastery: XX%` or `—`
  - Font sizes: label `9.5px` w400, value `11px` w500.
  - Student count badge: `N students` (9px, w400) at the bottom, using streamColor tint.
- Card styling: same as current card (surfaceContainerHighest background, left accent bar using `_streamColor`, rounded corners `kCardRadius`).
- Remove the horizontal progress bars on mobile — just show percentage numbers with color.

#### Desktop (≥ 600px): Donut charts — one per stream, each with 3 nested rings

Create a new widget `_StreamDonutCard`:
- Cards laid out in a `Wrap` with at least 3 per row.
- Each card width: dynamically calculated so at least 3 fit. Use `LayoutBuilder` to get available width, then `cardWidth = (availableWidth - (n-1)*spacing) / max(n, 3)` clamped to min 160px, max 280px.
- Each card contains a **triple-ring donut chart** painted with `CustomPainter`:
  - Outer ring: Overall Average (use `_percentColor` for color)
  - Middle ring: Attendance Rate (use a distinct color, e.g. `Color(0xFF42A5F5)` blue)
  - Inner ring: Last Exam Average (use `Color(0xFFFFA726)` amber)
  - Each ring: stroke width 8px (outer), 6px (middle), 4px (inner). Gap between rings: 4px.
  - Background track: `cs.surfaceContainerHighest` at 0.5 alpha.
  - The percentage value for each ring is clamped 0–100 and converted to arc sweep (0–2π).
  - Center of donut: stream name (12px, w500) and student count (10px, w400).
- Below the donut: A small legend with 3 items (colored dots + labels): "Average", "Attendance", "Last Exam" — font size 10px, w400.
- Below legend: `_TrajectoryBadge` (existing widget).
- Card border: left accent bar with `_streamColor`, same as current card.

**Implementation approach in `_ComparisonsTabState.build()`:**

Replace the current loop:
```dart
for (int i = 0; i < stats.length; i++) ...[
  _StreamComparisonCard(stats: stats[i]),
  ...
]
```

With:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isDesktop = constraints.maxWidth >= 600;
    if (isDesktop) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: stats.map((s) => _StreamDonutCard(stats: s, availableWidth: constraints.maxWidth, streamCount: stats.length)).toList(),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stats.map((s) => _CompactStreamCard(stats: s, availableWidth: constraints.maxWidth, streamCount: stats.length)).toList(),
      );
    }
  },
),
```

**The `CustomPainter` for the triple donut:**

```dart
class _TripleDonutPainter extends CustomPainter {
  final double averagePercent;   // 0–100
  final double attendancePercent; // 0–100 or -1 for no data
  final double lastExamPercent;   // 0–100 or -1 for no data
  final Color averageColor;
  final Color attendanceColor;
  final Color lastExamColor;
  final Color trackColor;

  // Paint 3 concentric arcs starting from -π/2 (12 o'clock)
  // Outer ring: radius = size/2 - strokeWidth/2
  // Middle ring: radius = outer - outerStroke/2 - gap - middleStroke/2
  // Inner ring: radius = middle - middleStroke/2 - gap - innerStroke/2
}
```

Keep `_StreamComparisonCard` in the file (or remove it if fully replaced). The old `_StatCell` widget can remain for use elsewhere or be removed if no longer referenced.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task A3: Upgrade stream ranking table ✅
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/tabs/comparisons_tab.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1

**Specification:**

The current `_RankingTable` (L751–978) and `_RankingRow` (L980–1151) are already decent with medal icons, hover effects, and staggered animations. Improve them with:

1. **Add a podium-style visual for top 3** (when ≥ 3 streams exist):
   - Before the table, add a `_PodiumSection` widget showing the top 3 streams visually:
     - Center: 1st place (tallest bar, gold tint), Left: 2nd (medium, silver tint), Right: 3rd (short, bronze tint).
     - Each podium step: a column with stream color dot, stream name (11px, w500), average percentage (13px, w500, colored), and a colored rectangle bar underneath.
     - Bar heights: 1st = 64px, 2nd = 48px, 3rd = 36px.
     - Bar width: roughly `(availableWidth - 48) / 3`.
     - Bar colors: gold `Color(0xFFFFD700)` at 0.15 alpha, silver `Color(0xFFC0C0C0)` at 0.15, bronze `Color(0xFFCD7F32)` at 0.15.
     - Bars aligned to the bottom using `CrossAxisAlignment.end` in a `Row`.
   - The podium is shown above the ranking table.

2. **Add visual distinction to the ranking rows:**
   - For rank 1: add a subtle gold gradient background (`goldColor.withValues(alpha: 0.04)` → transparent).
   - Add a thin `Divider` between header and first row.
   - Add stream color dot next to the stream name (already exists — keep it).

3. **Mobile improvement:**
   - On mobile (< 600px), hide the "Students" and "Overall" columns from the table to prevent overflow. Only show: Rank, Stream name, Last Exam, Trend icon.
   - Use `LayoutBuilder` to determine width and conditionally render columns.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track B: Exam Detail Page — Papers Tab Timetable Redesign

### Task B1: Redesign Papers tab to use timetable-style layout with status colors
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Currently the `_PapersTab` (L339–430) renders a plain `ListView` of `_PaperCard` widgets. Each `_PaperCard` (L2315–2388) is a simple card with subject name, date/time, status chip, and chevron. This feels like a flat list rather than a timetable.

The reference implementation is in `exams_grades_screen.dart` which uses `_PaperSlotBox` (desktop, L6121–6236) and `_PaperSlotCard` (mobile, L6574–6698) with colored left accent borders and tinted backgrounds based on paper status.

**Changes to `_PapersTab`:**

1. Replace the plain `ListView` with a timetable-like layout:

2. Add a `_paperStatusColor` helper (copy from `exams_grades_screen.dart`):
   ```dart
   Color _examPaperStatusColor(PaperStatus status, ColorScheme cs) => switch (status) {
     PaperStatus.pending => cs.onSurfaceVariant.withValues(alpha: 0.3),
     PaperStatus.progress => const Color(0xFF42A5F5),
     PaperStatus.done => const Color(0xFFFFA726),
     PaperStatus.marked => const Color(0xFF66BB6A),
   };
   ```

3. Add a `_PaperStatusLegend` widget (copy pattern from `exams_grades_screen.dart` L6530–6568):
   - A `Wrap` of 4 colored dots + labels for the 4 statuses.
   - Place this above the paper list.

4. **Replace `_PaperCard`** with a new `_PaperTimetableCard`:
   - Left accent border: `BorderSide(color: statusColor, width: 2.5)` — same as `_PaperSlotBox`/`_PaperSlotCard`.
   - Background tint: `statusColor.withValues(alpha: 0.06)`.
   - Other 3 borders: `cs.outlineVariant.withValues(alpha: 0.2)`.
   - Use `ClipRRect` with `borderRadius: BorderRadius.circular(4)`.
   - Content layout (same info as before but styled differently):
     - Row 1: Subject name + paper number (13px, w500) — left aligned.
     - Row 2: Date + time range (10px, w400) — left aligned.
     - Right side: `_PaperStatusChip` (existing widget) + chevron.
   - Bottom margin: 6px between cards.

5. **Group papers by date** (optional enhancement): If papers span multiple dates, add date section headers between groups:
   - Date header: `Text('DD Mon YYYY', style: ...)` — 12px, w500, with `cs.onSurfaceVariant.withValues(alpha: 0.6)`.
   - This makes it feel more like a timetable/schedule.

6. **Keep the existing `onTap` → `PaperDetailPage` navigation.**

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track C: Grades Tab — Visual Separation Improvements

### Task C1: Add clear visual separation between students and subjects in Grades tab
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

The `_GradesTab` (L436–1352) has a desktop spreadsheet and a mobile expandable card list. The user wants clearer separation between students and subjects.

#### Desktop spreadsheet changes (`_buildDesktopTable`, L621–979):

1. **Row separation:** Add alternating row backgrounds. Currently rows have no background distinction. Add:
   - Even rows: transparent.
   - Odd rows: `cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.08 : 0.06)`.
   - Apply this in the `ListView.builder` by checking `index.isOdd`.

2. **Column separation for subjects:** Add thin vertical dividers between subject columns:
   - Between each subject column header, add a `Container(width: 0.5, color: cs.outlineVariant.withValues(alpha: 0.15))`.
   - In each data row, add corresponding vertical separators at the same positions.
   - The "Total" and "%" columns should have a slightly thicker left border (`1px`) to visually separate them from the subject scores.

3. **Student name column:** Add a subtle bottom border to each row:
   - `Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.1), width: 0.5))`.

4. **Header row styling:** Make the header row more distinct:
   - Add a bottom border: `BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 1)`.
   - Background: `cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.25)`.

#### Mobile card list changes (`_MobileStudentGradeCard`, L1030–1352):

1. **Card separation:** Increase bottom margin from `6` to `8`.
2. **Subject rows inside expanded card:** Add thin dividers between subject score rows:
   - `Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withValues(alpha: 0.15))` between each subject row in the expanded view.
3. **Total row:** Add a visual separator (thicker divider or different background) above the "Total" row at the bottom of the expanded subject list.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track D: Performance Tab — Overview Redesign

### Task D1: Compact hero metrics and add donut chart for score distribution
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Currently in `_buildOverviewInsight` (L1605–1628), the layout is:
1. `_buildHeroMetrics` — 3 tiles each taking 1/3 of width (too much space)
2. `_buildDistribution` — stacked horizontal bar (separate section below)
3. `_buildStrengthsWeaknesses` — key insights

The user wants: hero metrics more compact + score distribution moved up as a donut chart next to them in the same horizontal row.

**Changes to `_buildOverviewInsight`:**

Replace the current:
```dart
_buildHeroMetrics(...),
const SizedBox(height: 16),
_buildDistribution(...),
```

With a single row:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Left: compact metrics column
    Column(children: [metric1, metric2, metric3]),
    SizedBox(width: 12),
    // Right: donut chart
    Expanded(child: _buildDonutDistribution(...)),
  ],
)
```

**Changes to `_buildHeroMetrics` (L1630–1670):**

1. Replace the `Row` of 3 `Expanded` tiles with a `Column` of 3 compact metric rows.
2. Each metric row layout:
   ```
   Row(
     children: [
       // Value
       SizedBox(width: 60, child: Text(value, fontSize: 16, w500, color: valueColor)),
       SizedBox(width: 8),
       // Label
       Text(label, fontSize: 11, w400, muted),
     ],
   )
   ```
3. Wrap the column in a `Container` with `padding: EdgeInsets.all(12)`, same background as current tiles.
4. `SizedBox(height: 10)` between each metric row.
5. Total width: roughly 160–180px (use `IntrinsicWidth` or a fixed `SizedBox(width: 170)`).

**New `_buildDonutDistribution` method:**

Replace `_buildDistribution` (L1714–1850) which currently renders a stacked horizontal bar.

1. Use `CustomPainter` to draw a donut chart:
   - Donut = single ring, stroke width 24px.
   - 6 segments for the 6 score buckets: `0–39`, `40–49`, `50–59`, `60–69`, `70–79`, `80–100`.
   - Same bucket colors as current: red `0xFFEF4444`, orange `0xFFF97316`, amber `0xFFF59E0B`, lime `0xFF84CC16`, green `0xFF22C55E`, emerald `0xFF10B981`.
   - Each segment's arc = `(count / total) * 2π`.
   - Start angle = `-π/2` (12 o'clock position).
   - Small gap between segments: 2px visual gap (achieved by subtracting a small angle).
   - Center text: total count in large text (16px, w500) + "students" label below (10px, w400).
2. Size: the donut should fill available width up to 160px, with aspect ratio 1:1.
3. Below the donut: `Wrap` legend with colored dots + labels (same as current but more compact, 9.5px font).
4. Add `Tooltip` to each segment via `GestureDetector` + `CustomPainter` hit testing, or use a simpler approach: show the tooltip data as a row below the legend with `hoveredBucket` state.

**On mobile (< 600px),** if the row is too cramped, stack them vertically instead:
```dart
LayoutBuilder(builder: (ctx, c) {
  if (c.maxWidth < 400) {
    return Column(children: [compactMetrics, SizedBox(height: 12), donut]);
  }
  return Row(children: [compactMetrics, SizedBox(width: 12), Expanded(child: donut)]);
})
```

**Remove or keep `_buildDistribution`:** Remove the old stacked bar implementation since it's fully replaced by the donut.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task D2: Redesign Subjects tab with compact wrapping cards
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

Currently `_buildSubjectsInsight` (L1975–2087) renders a `ListView.builder` where each subject takes the full width with a progress bar and grade counts.

**Replace with compact wrapping cards:**

1. Replace `ListView.builder` with a `SingleChildScrollView` containing a `Wrap`:
   ```dart
   SingleChildScrollView(
     padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
     child: Wrap(
       spacing: 8,
       runSpacing: 8,
       alignment: WrapAlignment.center,
       children: sorted.map((entry) => _SubjectCompactCard(...)).toList(),
     ),
   )
   ```

2. Create `_SubjectCompactCard` widget:
   - Width: use `ConstrainedBox(constraints: BoxConstraints(minWidth: 140, maxWidth: 200))` so roughly 2–3 fit per row on mobile, more on desktop.
   - Layout:
     ```
     Container(
       padding: EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: surfaceContainerHighest.withValues(alpha: 0.2),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: outlineVariant.withValues(alpha: 0.2)),
         // Left accent border using barColor
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Subject name (12.5px, w500, ellipsis)
           Text(name, maxLines: 1, overflow: ellipsis),
           SizedBox(height: 6),
           // Large percentage (18px, w500, colored by barColor)
           Text('${avg.toStringAsFixed(1)}%'),
           SizedBox(height: 6),
           // Thin progress bar (4px height, same as current but shorter)
           ClipRRect(borderRadius: 3, child: SizedBox(height: 4, child: LinearProgressIndicator(...))),
           SizedBox(height: 6),
           // Graded count (10px, w400, muted)
           Text('${pa.gradedStudents}/${pa.totalStudents} graded'),
         ],
       ),
     )
     ```
   - Left accent bar: add a `Border(left: BorderSide(color: barColor, width: 2.5))` to the container decoration.
   - Use `IntrinsicWidth` or calculate width based on `LayoutBuilder` parent.

3. The `Wrap` uses `alignment: WrapAlignment.center` so cards center when they don't fill the last row.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task D3: Improve Rankings tab design
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P2

**Specification:**

The current `_buildRankingsInsight` (L2089–2281) is a simple list with medal icons for top 3. Improvements:

1. **Add a podium/highlight section for top 3:**
   - Before the main rankings list, add a visual top-3 section:
   - A `Row` with 3 cards (2nd | 1st | 3rd) arranged in podium order:
     - 1st place card: centered, slightly taller visual presence.
     - 2nd place card: left.
     - 3rd place card: right.
   - Each card:
     ```
     Column(
       children: [
         // Medal icon (emoji_events_rounded, size 24, gold/silver/bronze)
         Icon(Icons.emoji_events_rounded, size: 24, color: medalColor),
         SizedBox(height: 4),
         // Student name (12px, w500, centered, maxLines: 1, ellipsis)
         Text(name),
         // ADM (10px, w400, muted)
         Text('ADM $adm'),
         SizedBox(height: 4),
         // Percentage (16px for 1st, 14px for 2nd/3rd, w500, colored)
         Text('${pct.toStringAsFixed(1)}%'),
         SizedBox(height: 6),
         // Podium bar (colored rectangle, height: 48/36/28 for 1st/2nd/3rd)
         Container(height: h, decoration: BoxDecoration(color: medalColor.withAlpha(0.15), borderRadius: ...)),
       ],
     )
     ```
   - Only show this section if `rankings.length >= 3`.
   - Wrap in a `Container` with subtle background.

2. **Improve the main list:**
   - Add alternating row backgrounds (even: transparent, odd: surfaceContainerHighest at 0.06 alpha).
   - Add a thin left border accent for top 3 rows using medal colors (already exists — keep it).
   - Add a subtle hover effect on desktop: `InkWell` with `cs.primary.withValues(alpha: 0.04)`.

3. **Add student profile circle** (see Task E1 — this task focuses on layout only, Task E1 adds the avatar widget). Leave a `SizedBox(width: 24)` placeholder in each row where the avatar will go, between the rank number and the student name.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track E: Student Profile Photos

### Task E1: Create `StudentAvatar` widget
**Files to create/modify:** `lib/ui/widgets/student_avatar.dart` (NEW)
**Context files to read (if needed):** `lib/ui/widgets/user_avatar.dart`, `lib/cache/file_cache.dart`
**Depends on:** None
**Parallel group:** P3

**Specification:**

Create a new `StudentAvatar` widget modeled after `UserAvatar` but using the student image path convention.

```dart
import 'dart:io';
import 'package:flutter/material.dart';

import '../../cache/file_cache.dart';

/// A circular profile image for a student, reading from the local file cache.
///
/// Falls back to a circle with the student's initials (first letter of name)
/// when no cached image exists.
class StudentAvatar extends StatelessWidget {
  final String schoolId;
  final int adm;
  final String name; // Used for initials fallback

  /// Half-size of the avatar.
  final double radius;

  final VoidCallback? onTap;

  const StudentAvatar({
    super.key,
    required this.schoolId,
    required this.adm,
    required this.name,
    this.radius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Deterministic color from adm number for variety
    final colors = [
      const Color(0xFF5C6BC0), // indigo
      const Color(0xFF26A69A), // teal
      const Color(0xFFEF5350), // red
      const Color(0xFFFFA726), // amber
      const Color(0xFF66BB6A), // green
      const Color(0xFFAB47BC), // purple
      const Color(0xFF42A5F5), // blue
      const Color(0xFFEC407A), // pink
    ];
    final bgColor = colors[adm % colors.length];

    // Extract initials: first letter of first word + first letter of last word
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?');

    Widget avatar = FutureBuilder<File?>(
      future: FileCache.get(FileCache.studentImagePath(schoolId, adm)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainerHighest,
          );
        }

        // Fallback: colored circle with initials
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: TextStyle(
              fontSize: radius * 0.7,
              fontWeight: FontWeight.w500,
              color: bgColor,
            ),
          ),
        );
      },
    );

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      );
    }

    return avatar;
  }
}
```

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E2: Add student avatars to paper_detail_page.dart grade lists
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** Task E1
**Parallel group:** P4

**Specification:**

Add `StudentAvatar` to both desktop spreadsheet rows and mobile grade list rows.

1. **Add import** at top of file:
   ```dart
   import '../../../widgets/student_avatar.dart';
   ```

2. **Desktop: `_SpreadsheetRow.build()` (L1876–2053):**

   In the `Row` children, after the ADM number badge and before the Name `Expanded` widget, insert:
   ```dart
   StudentAvatar(
     schoolId: widget.schoolId, // Need to pass schoolId through to _SpreadsheetRow
     adm: widget.student.adm,
     name: widget.student.name,
     radius: 14,
   ),
   const SizedBox(width: 8),
   ```

   This requires `schoolId` to be available in `_SpreadsheetRow`. Trace the widget tree:
   - `PaperDetailPage` has `schoolId` → it passes to `_GradeSpreadsheet` → which creates `_SpreadsheetRow`.
   - `_GradeSpreadsheet` already receives `schoolId` (check the constructor). If not, add it.
   - `_SpreadsheetRow` needs `schoolId` added to its constructor and passed through.

3. **Mobile: `_GradeList.build()` (L2414–2587):**

   In the mobile card list `itemBuilder`, inside the `Row` children, before the Name + ADM column, insert:
   ```dart
   StudentAvatar(
     schoolId: widget.schoolId, // Need to pass schoolId through to _GradeList
     adm: student.adm,
     name: student.name,
     radius: 14,
   ),
   const SizedBox(width: 10),
   ```

   Same approach: ensure `schoolId` is available in `_GradeList`.

**Note:** The `schoolId` is available in `PaperDetailPage` as `widget.schoolId`. Trace through the widget tree to ensure it reaches `_SpreadsheetRow` and `_GradeList`. Both widgets receive students data, so adding `schoolId` as a constructor parameter is straightforward.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task E3: Add student avatars to exam_detail_page.dart grades and rankings
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None
**Depends on:** Task E1
**Parallel group:** P4

**Specification:**

Add `StudentAvatar` to the Grades tab (both desktop and mobile) and Rankings tab.

1. **Add import** at top of file:
   ```dart
   import '../../../widgets/student_avatar.dart';
   ```

2. **Grades tab — Desktop spreadsheet (`_buildDesktopTable`, L621–979):**

   The desktop spreadsheet's fixed left column shows student name + ADM. In the left column builder, before the student name text, add:
   ```dart
   StudentAvatar(
     schoolId: widget.schoolId,
     adm: row.student.adm,
     name: row.student.name,
     radius: 13,
   ),
   const SizedBox(width: 8),
   ```

3. **Grades tab — Mobile cards (`_MobileStudentGradeCard`, L1030–1352):**

   In the card's header `Row`, before the name/ADM column, add:
   ```dart
   StudentAvatar(
     schoolId: widget.schoolId, // Pass schoolId to _MobileStudentGradeCard
     adm: widget.row.student.adm,
     name: widget.row.student.name,
     radius: 14,
   ),
   const SizedBox(width: 10),
   ```

   `_MobileStudentGradeCard` needs `schoolId` added to its constructor. It's created inside `_GradesTabState._buildMobileList()` which has access to `widget.schoolId`.

4. **Rankings tab (`_buildRankingsInsight`, L2089–2281):**

   In each ranking row (the `i > 0` branch), between the rank number `SizedBox(width: 32)` and the student name `Expanded(flex: 3)`, add:
   ```dart
   StudentAvatar(
     schoolId: widget.schoolId,
     adm: r.adm,
     name: r.name,
     radius: 13,
   ),
   const SizedBox(width: 8),
   ```

   Note: `_buildRankingsInsight` is a method on `_PerformanceTabState` which has access to `widget.schoolId`.

5. **Rankings podium (if Task D3 added one):** Also add `StudentAvatar` in each podium card, above the student name, with `radius: 18`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Dependency & Parallelism Summary

| Group | Tasks | Can run in parallel | Notes |
|-------|-------|--------------------|----|
| P1 | A1, A2, A3 | Yes (all in `comparisons_tab.dart` but different widgets — A1=`_SummaryRow`/`_SummaryCard`, A2=`_StreamComparisonCard` replacement, A3=`_RankingTable`) | ⚠️ All modify same file. Assign to single executor to avoid conflicts. |
| P2 | B1, C1, D1, D2, D3 | Yes (B1=Papers tab, C1=Grades tab, D1/D2/D3=Performance tab — all in `exam_detail_page.dart`) | ⚠️ All modify same file. Assign to single executor to avoid conflicts. |
| P3 | E1 | Yes (new file, no conflicts) | Can run parallel with P1 and P2. |
| P4 | E2, E3 | Yes with each other (different files) | Depends on E1 (P3). |

**Recommended execution order:**
1. **Batch 1:** P1 (A1+A2+A3 as single executor on `comparisons_tab.dart`) + P3 (E1 — new file) — in parallel.
2. **Batch 2:** P2 (B1+C1+D1+D2+D3 as single executor on `exam_detail_page.dart`) + P4 (E2+E3 — one executor per file) — in parallel. P4 depends on E1 from Batch 1.