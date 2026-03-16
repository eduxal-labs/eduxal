# TASKS.md

> **Orchestrator:** Each task is a self-contained UI improvement. Spawn executor agents in parallel where indicated. Every executor must commit after completing its task.

---

## Track A — Grade Detail Page: "All" Tab Restructure

### Task A1: Rename "Comparisons" stream tab to "All" and add sub-tabs
**Files to modify:** `lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/academics/tabs/comparisons_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/exams_tab.dart`, `lib/ui/screens/school_dashboard/academics/tabs/timetable_tab.dart`
**Depends on:** None
**Parallel group:** —

**Problem:**
When you tap a grade on the Academics page, the grade detail page shows stream tabs where the first tab is called "Comparisons". Selecting it shows stats/charts directly. This is limiting — users expect to also see grade-wide exams and timetable from this "all streams" view, not just stats.

The "Comparisons" tab should be renamed to "All" and when selected, it should show its own set of sub-tabs: **Stats**, **Exams**, and **Timetable** — mirroring the content tab bar that individual streams already have. The Stats sub-tab should contain what Comparisons currently shows. The Exams sub-tab should show exams across ALL streams of the grade (not filtered to a single stream). The Timetable sub-tab should show a consolidated timetable view.

The executor should study how the existing stream-specific content tabs work (with `_contentTabController` and `TabBarView`) and create an analogous sub-tab system for the "All" tab. The exams shown under "All → Exams" should use `watchExamsForGradeStream` from `AcademicsDao` which already supports querying across all streams for a grade.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: restructure Comparisons tab into All with Stats/Exams/Timetable sub-tabs"`

---

### Task A2: Improve the Stats (formerly Comparisons) tab — better charts, ranking, and overall design
**Files to modify:** `lib/ui/screens/school_dashboard/academics/tabs/comparisons_tab.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** Task A1

**Problem:**
The current Comparisons tab (now the Stats sub-tab under "All") has a poor visual design. The summary cards are plain and flat. The stream comparison cards feel like basic containers with text. The ranking table uses basic alternating row colors with no visual hierarchy. The trend chart is a raw custom painter with no interactivity.

The executor should redesign this entire tab to feel polished and modern. Think about:
- Making summary stat cards visually engaging (not just text in boxes)
- Improving stream comparison cards to feel alive with better use of color, spacing, and data visualization
- Making the ranking table feel like a real leaderboard (medals/trophies for top ranks, animated entrance, better row design)
- Replacing or enhancing the custom-painted trend chart with something more visually appealing using `fl_chart` which is already in the project

Follow the project's UI guidelines in `AGENT.md` §21 (typography weights, border radius tiers, spacing density, dark mode colors). Read `AppTheme` for available constants and helpers.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: redesign Stats tab with improved charts, ranking, and visual polish"`

---

## Track B — Academic Sub-Tab List Item Improvements

### Task B1: Improve the Students tab list rows
**Files to modify:** `lib/ui/screens/school_dashboard/academics/tabs/students_tab.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P1

**Problem:**
The `_StudentRow` widget in the Students tab of a grade/stream is a flat, lifeless data row. It has only a basic hover color change (`cs.primary @ 0.04` on transparent) with no press feedback, no visual container, no accent, and no sense that it's an interactive element. The trajectory icon and average badge are functional but visually disconnected from the row. The rows are separated by thin dividers which makes the list feel like a spreadsheet rather than a modern app.

The executor should make these rows feel alive and clickable — studying the recently improved `_ExamRow` and `_ExamGroupRow` in `exams_tab.dart` and `exams_grades_screen.dart` as reference for the interaction pattern (accent bar, scale animation, hover/press states, animated chevron). The executor should be creative in how student-specific data (avatar, name, trajectory, average) is presented within this pattern.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve Students tab list rows with interactive card treatment"`

---

### Task B2: Improve the Subjects tab list rows
**Files to modify:** `lib/ui/screens/school_dashboard/academics/tabs/subjects_tab.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P1

**Problem:**
The `_SubjectRow` widget is a flat row with only a basic hover highlight. The subject name, teacher avatar, and mastery bars are laid out but the row itself feels static and dead. There's no press feedback, no visual container treatment, no accent color, and the mastery bars section could use better visual integration with the row.

The executor should make these rows feel like interactive, tappable cards. Study the improved exam rows for the interaction pattern. Be creative with how to integrate the subject color, mastery data, and teacher info into a more visually compelling row design.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve Subjects tab list rows with interactive design"`

---

### Task B3: Improve the Lessons tab list rows
**Files to modify:** `lib/ui/screens/school_dashboard/academics/tabs/lessons_tab.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P1

**Problem:**
The `_LessonRow` widget has a 3px left color accent (which is good) but is otherwise a flat row with only basic hover highlighting. There's no press animation, no card container, no border treatment, and the overall feel is static. The date headers (`_DateHeader`) are also plain text separators with no visual weight.

The executor should enhance the lesson rows to feel alive and polished — building on the existing accent bar concept but adding the full interactive treatment (press animation, container, border states). The date headers should also be improved to be more visually distinct section separators.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve Lessons tab rows and date headers"`

---

### Task B4: Improve the Teachers tab cards
**Files to modify:** `lib/ui/screens/school_dashboard/academics/tabs/teachers_tab.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P1

**Problem:**
The Teachers tab has three sections: active class teacher card, past class teacher cards, and subject teacher cards. All of these are plain `Container` widgets with basic `surfaceContainerHighest` backgrounds. The active class teacher card has a primary-colored border but otherwise feels flat. Past teacher cards are even more muted. Subject teacher cards are simple rows with no interactivity.

The executor should make all three card types feel more alive and polished. The active class teacher should feel prominent and important. Subject teacher cards should feel like tappable items. The section headers and collapsible "Previous Class Teachers" section could also use visual improvement.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve Teachers tab card designs"`

---

## Track C — Members Page List Item Improvements

### Task C1: Improve the `_UserDataRow` widget (used by Owners, Teachers, Staff, Guardians tabs)
**Files to modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P2

**Problem:**
The `_UserDataRow` widget (around line 1506) is the shared row component used across the Owners, Teachers, Staff, and Guardians tabs on the Members page. It's a flat data-table row with only a basic hover color (`cs.primary @ 0.04` on transparent), no press feedback, no visual container, no accent, and no sense of being an interactive element. The avatar, name, subtitle, status indicator, and action buttons are all present but the row itself feels dead and static.

This is a high-impact widget because improving it automatically improves four of the five member tabs. The executor should make it feel alive and clickable with proper interactive states, while preserving the existing functionality (avatar with status indicator, inline desktop actions that fade on hover, mobile overflow menu). Study the improved exam rows for the interaction pattern but be creative — member rows have avatars and status indicators which offer unique design opportunities.

Both mobile and desktop layouts must be considered and improved.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve _UserDataRow with interactive card treatment across all member tabs"`

---

### Task C2: Improve the `_FlatRow` widget (used by Students tab) and `_StudentRow` in members
**Files to modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P2

**Problem:**
The `_FlatRow` widget (around line 1651) is a near-identical copy of `_UserDataRow` but used for the Students tab on the Members page. It has the same flat, dead feel — basic hover only, no press feedback, no visual container. The `_StudentRow` widget (around line 1189) that wraps `_FlatRow` with a student avatar also has the same lifeless presentation.

The executor should apply the same interactive card treatment to `_FlatRow`, making student rows on the Members page feel alive and clickable. The student avatar (which uses a file-cached image with fallback initials) should be nicely integrated into the design. Both mobile and desktop layouts must be considered.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve _FlatRow and student rows on Members page"`

---

### Task C3: Improve the Departments tab list design
**Files to modify:** `lib/ui/screens/school_dashboard/members/members_page.dart`
**Context files to read:** `lib/ui/theme/app_theme.dart`
**Depends on:** None
**Parallel group:** P2

**Problem:**
The `_DepartmentsTab` (around line 235) shows a list of departments. Looking at the build method and how department rows are rendered, they likely use a similar flat row pattern. The department detail screen (`_DepartmentDetailScreen` around line 4316) also has member lists (`_DeptAllMemberList`, `_DeptMemberRow`) that need visual improvement.

The executor should improve the department list items and the member rows within department details to feel alive and interactive, consistent with the improvements being made across the rest of the app. Department cards should feel like tappable entities with clear visual hierarchy.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "ui: improve Departments tab and department detail member rows"`

---