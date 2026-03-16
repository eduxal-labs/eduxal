# EduXal — Task Board

> **Workflow:** Examiner writes tasks → Orchestrator dispatches → Executor implements.
> Each task is self-sufficient. The executor should not need to explore the codebase.

---

## Track A: Exam Detail Page — Tab Bar Width Fix

### Task A1: Make ExamDetailPage tab bar use scrollable mode instead of forced full-width

**Files to modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** `lib/ui/widgets/edu_tab_bar.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

The `EduTabBar` in `ExamDetailPage` currently uses the default `isScrollable = false`, which forces the 3 tabs (Papers, Grades, Performance) to stretch across the full width. With only 3 short-label tabs, this looks unnatural and bloated.

In `_ExamDetailPageState.build()` (around line 146), change:

```dart
EduTabBar(controller: _tabController, tabs: _tabs),
```

to:

```dart
EduTabBar(controller: _tabController, tabs: _tabs, isScrollable: true),
```

The `EduTabBar` widget already supports `isScrollable: true` — when enabled it sets `TabAlignment.start` and wraps the strip in `Align(alignment: Alignment.centerLeft)` so the tabs hug to the left at their natural width instead of stretching to fill. No other changes needed.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track B: Grades Tab — Filter Students by Stream

### ~~Task B1: Pass `streamCode` to `_GradesTab` and `_PerformanceTab` and use it to filter enrolled students~~ [x]

**Files to modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** `lib/database/daos/exams_grades_dao.dart`
**Depends on:** None
**Parallel group:** P1

**Specification:**

**Problem:** Both `_GradesTab` and `_PerformanceTab` call `widget.dao.getEnrolledStudents(...)` without passing the `stream` parameter. The DAO method signature is:

```dart
Future<List<StudentsData>> getEnrolledStudents({
  required String schoolId,
  required int year,
  required int term,
  required int grade,
  int? stream, // null → all streams
})
```

The `ExamDetailPage` widget already has `widget.streamCode` (nullable `int?`) but it is never forwarded to these child tabs. As a result, when viewing an exam from within a specific stream tab, the Grades and Performance tabs show ALL students in the grade instead of just the students in that stream.

**Changes required:**

#### 1. Add `streamCode` parameter to `_GradesTab`

In the `_GradesTab` widget class (around line 437), add a new field:

```dart
final int? streamCode;
```

Add it to the constructor:

```dart
const _GradesTab({
  required this.exam,
  required this.schoolId,
  required this.year,
  required this.term,
  required this.grade,
  this.streamCode,           // ← ADD THIS
  required this.curriculumType,
  required this.dao,
  required this.subjectNames,
});
```

#### 2. Pass `streamCode` when loading students in `_GradesTabState`

In `_GradesTabState._loadStudents()` (around line 505), change:

```dart
final enrolled = await widget.dao.getEnrolledStudents(
  schoolId: widget.schoolId,
  year: widget.year,
  term: widget.term,
  grade: widget.grade,
);
```

to:

```dart
final enrolled = await widget.dao.getEnrolledStudents(
  schoolId: widget.schoolId,
  year: widget.year,
  term: widget.term,
  grade: widget.grade,
  stream: widget.streamCode,
);
```

#### 3. Add `streamCode` parameter to `_PerformanceTab`

In the `_PerformanceTab` widget class (around line 1356), add a new field:

```dart
final int? streamCode;
```

Add it to the constructor:

```dart
const _PerformanceTab({
  required this.exam,
  required this.schoolId,
  required this.year,
  required this.term,
  required this.grade,
  this.streamCode,           // ← ADD THIS
  required this.curriculumType,
  required this.dao,
  required this.subjectNames,
});
```

#### 4. Pass `streamCode` when loading students in `_PerformanceTabState`

In `_PerformanceTabState._load()` (around line 1405), change:

```dart
final enrolled = await widget.dao.getEnrolledStudents(
  schoolId: widget.schoolId,
  year: widget.year,
  term: widget.term,
  grade: widget.grade,
);
```

to:

```dart
final enrolled = await widget.dao.getEnrolledStudents(
  schoolId: widget.schoolId,
  year: widget.year,
  term: widget.term,
  grade: widget.grade,
  stream: widget.streamCode,
);
```

#### 5. Wire `streamCode` from the parent `_ExamDetailPageState.build()`

In the `TabBarView` children (around lines 166–185), update both tab constructors:

For `_GradesTab` (around line 167):

```dart
_GradesTab(
  exam: widget.exam,
  schoolId: widget.schoolId,
  year: widget.year,
  term: widget.term,
  grade: widget.grade,
  streamCode: widget.streamCode,  // ← ADD THIS
  curriculumType: widget.curriculumType,
  dao: _dao,
  subjectNames: widget.subjectNames,
),
```

For `_PerformanceTab` (around line 177):

```dart
_PerformanceTab(
  exam: widget.exam,
  schoolId: widget.schoolId,
  year: widget.year,
  term: widget.term,
  grade: widget.grade,
  streamCode: widget.streamCode,  // ← ADD THIS
  curriculumType: widget.curriculumType,
  dao: _dao,
  subjectNames: widget.subjectNames,
),
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

## Track C: Performance Tab — Redesign with Passion

### ~~Task C1: Redesign the `_PerformanceTab` with a thoughtful, information-rich layout~~ [x]

**Files to modify:** `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read (if needed):** None — all information is inlined below
**Depends on:** Task B1 (needs `streamCode` parameter already added)
**Parallel group:** P2

**Specification:**

The current Performance tab feels generic and uninspired — a summary card with big numbers, some bar charts that don't convey meaningful insight, and a ranking table. The redesign should feel **intentional, insightful, and beautiful** — like something a teacher would actually enjoy opening.

Replace the entire `_PerformanceTabState.build()` method and all its helper methods (`_buildSummaryCard`, `_buildSubjectBar`, `_buildDistributionChart`, `_buildRankingTable`, `_buildSectionLabel`) with the new design described below.

**Important:** Keep the same data loading in `_load()` — do NOT change `initState` or the `_load` method. Only change the `build` method and its helper builders. Keep `AutomaticKeepAliveClientMixin`. Keep the existing `_analytics`, `_rankings`, `_enrolled`, `_loading` state fields.

**Add a new state field** for the currently selected view:

```dart
int _selectedInsight = 0; // 0 = Overview, 1 = Subjects, 2 = Rankings
```

#### New Design Structure

The new build method returns a `Column` with:
1. **Insight selector strip** (at the top, inside padding)
2. **Expanded content** (based on selected insight)

```dart
@override
Widget build(BuildContext context) {
  super.build(context);
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;

  if (_loading) return _buildLoading(cs);

  final analytics = _analytics;
  final rankings = _rankings;
  final enrolled = _enrolled;

  if (analytics == null || analytics.isEmpty) {
    return _buildEmpty(cs, 'No grades recorded for this exam yet');
  }

  // Overall stats
  double totalAvg = 0;
  double highest = 0;
  double lowest = 100;
  for (final a in analytics.values) {
    totalAvg += a.averagePercent;
    if (a.averagePercent > highest) highest = a.averagePercent;
    if (a.averagePercent < lowest) lowest = a.averagePercent;
  }
  final overallAvg = totalAvg / analytics.length;
  final totalGraded = rankings?.length ?? 0;
  final totalEnrolled = enrolled?.length ?? 0;

  return Column(
    children: [
      // ── Insight selector ──
      _buildInsightSelector(cs, isDark),
      // ── Content ──
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedInsight == 0
              ? _buildOverviewInsight(cs, isDark, overallAvg, highest, lowest, totalGraded, totalEnrolled, analytics)
              : _selectedInsight == 1
                  ? _buildSubjectsInsight(cs, isDark, analytics)
                  : _buildRankingsInsight(cs, isDark, rankings ?? []),
        ),
      ),
    ],
  );
}
```

#### 1. `_buildInsightSelector` — Three compact chips

A horizontal row of 3 tappable chips: **Overview**, **Subjects**, **Rankings**. Styled similarly to filter chips used elsewhere — compact, not full-width tabs.

```dart
Widget _buildInsightSelector(ColorScheme cs, bool isDark) {
  const labels = ['Overview', 'Subjects', 'Rankings'];
  const icons = [Icons.insights_rounded, Icons.menu_book_rounded, Icons.emoji_events_rounded];

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: List.generate(3, (i) {
        final selected = _selectedInsight == i;
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _selectedInsight = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.3)
                      : cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[i],
                    size: 14,
                    color: selected
                        ? cs.primary
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}
```

#### 2. `_buildOverviewInsight` — The thoughtful overview

A `ListView` with:

**(a) Hero metric row** — Three stat tiles arranged horizontally. Each tile is a small rounded container with a subtle background. Not using giant 28px numbers — use 20px w500 for the value, 11px muted for the label:

```dart
Widget _buildOverviewInsight(
  ColorScheme cs,
  bool isDark,
  double overallAvg,
  double highest,
  double lowest,
  int totalGraded,
  int totalEnrolled,
  Map<int, PaperAnalytics> analytics,
) {
  return ListView(
    key: const ValueKey('overview'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      // ── Hero metrics ──
      _buildHeroMetrics(cs, isDark, overallAvg, highest, lowest, totalGraded, totalEnrolled),
      const SizedBox(height: 16),

      // ── Grade distribution ──
      _buildDistribution(cs, isDark, analytics),
      const SizedBox(height: 16),

      // ── Strengths & Weaknesses ──
      _buildStrengthsWeaknesses(cs, isDark, analytics),
    ],
  );
}
```

**(a-i) `_buildHeroMetrics`:**

```dart
Widget _buildHeroMetrics(ColorScheme cs, bool isDark, double avg, double highest, double lowest, int graded, int enrolled) {
  return Row(
    children: [
      Expanded(child: _buildMetricTile(cs, isDark, '${avg.toStringAsFixed(1)}%', 'Class Average', _pctColor(avg, cs))),
      const SizedBox(width: 8),
      Expanded(child: _buildMetricTile(cs, isDark, '$graded / $enrolled', 'Graded', cs.onSurface)),
      const SizedBox(width: 8),
      Expanded(child: _buildMetricTile(cs, isDark, '${(highest - lowest).toStringAsFixed(1)}%', 'Spread', cs.onSurfaceVariant)),
    ],
  );
}

Widget _buildMetricTile(ColorScheme cs, bool isDark, String value, String label, Color valueColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: valueColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    ),
  );
}
```

**(a-ii) `_buildDistribution`** — A cleaner grade distribution visualization. Instead of using `fl_chart`'s `BarChart`, build a **custom horizontal stacked bar** (single row) + legend below. This is more compact and more visually meaningful than separate vertical bars:

```dart
Widget _buildDistribution(ColorScheme cs, bool isDark, Map<int, PaperAnalytics> analytics) {
  // Merge distributions
  final aggregate = <String, int>{};
  for (final pa in analytics.values) {
    for (final entry in pa.distribution.entries) {
      aggregate[entry.key] = (aggregate[entry.key] ?? 0) + entry.value;
    }
  }
  if (aggregate.isEmpty) return const SizedBox.shrink();

  const buckets = ['0–39', '40–49', '50–59', '60–69', '70–79', '80–100'];
  const bucketColors = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFF84CC16), // lime
    Color(0xFF22C55E), // green
    Color(0xFF10B981), // emerald
  ];

  final counts = <int>[];
  final labels = <String>[];
  final colors = <Color>[];
  int total = 0;
  for (int i = 0; i < buckets.length; i++) {
    final c = aggregate[buckets[i]] ?? 0;
    counts.add(c);
    labels.add(buckets[i]);
    colors.add(bucketColors[i]);
    total += c;
  }
  if (total == 0) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
          : cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Distribution',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        // Stacked horizontal bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 28,
            child: Row(
              children: List.generate(counts.length, (i) {
                if (counts[i] == 0) return const SizedBox.shrink();
                final fraction = counts[i] / total;
                return Expanded(
                  flex: (fraction * 1000).round().clamp(1, 1000),
                  child: Tooltip(
                    message: '${labels[i]}: ${counts[i]} student${counts[i] == 1 ? '' : 's'}',
                    child: Container(
                      color: colors[i].withValues(alpha: isDark ? 0.7 : 0.8),
                      alignment: Alignment.center,
                      child: fraction > 0.08
                          ? Text(
                              '${counts[i]}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: List.generate(counts.length, (i) {
            if (counts[i] == 0) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: isDark ? 0.7 : 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${labels[i]}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    ),
  );
}
```

**(a-iii) `_buildStrengthsWeaknesses`** — A small insight card showing the best and weakest subjects (sorted by average). This gives the teacher **actionable information**:

```dart
Widget _buildStrengthsWeaknesses(ColorScheme cs, bool isDark, Map<int, PaperAnalytics> analytics) {
  if (analytics.length < 2) return const SizedBox.shrink();

  final sorted = analytics.entries.toList()
    ..sort((a, b) => b.value.averagePercent.compareTo(a.value.averagePercent));

  final best = sorted.first;
  final worst = sorted.last;
  final bestName = widget.subjectNames[best.key] ?? 'Subject ${best.key}';
  final worstName = widget.subjectNames[worst.key] ?? 'Subject ${worst.key}';

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
          : cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Insights',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        _buildInsightRow(
          cs,
          icon: Icons.trending_up_rounded,
          iconColor: AppTheme.brandGreen,
          title: 'Strongest Subject',
          subtitle: bestName,
          value: '${best.value.averagePercent.toStringAsFixed(1)}%',
          valueColor: AppTheme.brandGreen,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        _buildInsightRow(
          cs,
          icon: Icons.trending_down_rounded,
          iconColor: cs.error,
          title: 'Needs Attention',
          subtitle: worstName,
          value: '${worst.value.averagePercent.toStringAsFixed(1)}%',
          valueColor: cs.error,
        ),
      ],
    ),
  );
}

Widget _buildInsightRow(
  ColorScheme cs, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required String value,
  required Color valueColor,
}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: iconColor.withValues(alpha: 0.7)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: valueColor,
        ),
      ),
    ],
  );
}
```

#### 3. `_buildSubjectsInsight` — Per-subject deep view

A `ListView` with one card per subject, each showing the subject name, average, graded count, and a slim progress bar. Much more meaningful than the old naked `LinearProgressIndicator`:

```dart
Widget _buildSubjectsInsight(ColorScheme cs, bool isDark, Map<int, PaperAnalytics> analytics) {
  final sorted = analytics.entries.toList()
    ..sort((a, b) => b.value.averagePercent.compareTo(a.value.averagePercent));

  return ListView.builder(
    key: const ValueKey('subjects'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    itemCount: sorted.length,
    itemBuilder: (context, i) {
      final entry = sorted[i];
      final name = widget.subjectNames[entry.key] ?? 'Subject ${entry.key}';
      final pa = entry.value;
      final avg = pa.averagePercent;
      final barColor = avg >= 75
          ? AppTheme.brandGreen
          : avg >= 50
              ? const Color(0xFFF59E0B)
              : cs.error;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
                : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${avg.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: (avg / 100).clamp(0.0, 1.0),
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(barColor.withValues(alpha: isDark ? 0.7 : 0.8)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${pa.gradedStudents} of ${pa.totalStudents} graded',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (pa.averageScore > 0)
                    Text(
                      'Avg score: ${pa.averageScore.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

#### 4. `_buildRankingsInsight` — Refined student ranking

A `ListView` with the ranking table redesigned. Use the data-table list style (thin dividers, hover highlight, no cards per row) as required by the UI guidelines. Keep the top-3 medal accents:

```dart
Widget _buildRankingsInsight(ColorScheme cs, bool isDark, List<_StudentRankRow> rankings) {
  if (rankings.isEmpty) {
    return _buildEmpty(cs, 'No student rankings available');
  }

  return ListView.builder(
    key: const ValueKey('rankings'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    itemCount: rankings.length + 1, // +1 for header
    itemBuilder: (context, i) {
      if (i == 0) {
        // Header
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.2 : 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              ),
              Expanded(
                flex: 3,
                child: Text('Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              ),
              SizedBox(
                width: 56,
                child: Text('Score', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Text('%', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        );
      }

      final r = rankings[i - 1];
      final pctColor = _pctColor(r.percentage, cs);

      // Medal colors for top 3
      Color? medal;
      if (r.rank == 1) medal = const Color(0xFFFFD700);
      if (r.rank == 2) medal = const Color(0xFFC0C0C0);
      if (r.rank == 3) medal = const Color(0xFFCD7F32);

      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.15),
              width: 0.5,
            ),
            left: medal != null
                ? BorderSide(color: medal.withValues(alpha: 0.6), width: 2.5)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: medal != null
                  ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                  : Text(
                      '${r.rank}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ADM ${r.adm}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${_fmtScore(r.totalScore)}/${r.totalPossible}',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: cs.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pctColor.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${r.percentage.toStringAsFixed(1)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: pctColor),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

#### 5. Remove the `fl_chart` import

Since we no longer use `BarChart`, remove the `fl_chart` import at the top of the file. Search for:

```dart
import 'package:fl_chart/fl_chart.dart';
```

Remove it. Also remove the `dart:math` import alias if it was only used for the bar chart (`math.max`). Check: the `dart:math` import line — if it says `import 'dart:math' as math;`, check whether `math` is used elsewhere in the file. If not, remove it. If it is used elsewhere, keep it.

**Note:** The `_buildSectionLabel`, `_buildSummaryCard`, `_buildSubjectBar`, `_buildDistributionChart`, `_buildRankingTable`, and `_medalTint` methods inside `_PerformanceTabState` should all be **deleted** and replaced with the new methods described above.

**Keep** the `_pctColor` and `_fmtScore` top-level helper functions — they are shared with other widgets in the file.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update the `exam_detail_page.dart` entry to reflect: (1) Performance tab redesigned with 3-insight views (Overview/Subjects/Rankings), no longer uses fl_chart BarChart, uses custom stacked bar + insight cards + data-table ranking. (2) EduTabBar is now scrollable. (3) Grades and Performance tabs filter by streamCode.
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---