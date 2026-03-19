# TASKS.md

> Tasks for the Timetable page overhaul, exam generation wizard redesign,
> academic grade timetable multi-stream view, and exam papers unified grid layout.
>
> All tasks follow §0d self-sufficient format. Executors must read AGENT.md and BUG.md
> in full before starting any task.

---

## Execution Plan

```
Round 1 (parallel): TT-01 · AC-01 · EX-01
Round 2 (after TT-01 done): TT-02
Round 3 (after TT-02 done): TT-03
```

AC-01 and EX-01 are independent of the TT chain and of each other — they touch
completely different files. TT-01, TT-02, TT-03 are sequential because they all
modify `timetable_screen.dart`.

---

### [x] Task TT-01: Add Two-Tab Structure and Fix the FAB on the Timetable Page

**Files to create/modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** none
**Parallel group:** P1 (runs in parallel with AC-01 and EX-01)

**Specification:**

The Timetable page (owner/admin view) currently presents a single monolithic view — a class selector chip strip plus a per-class grid. There are no tabs. The timetable content and the lessons log are not separated in any way.

The page needs to be split into two top-level tabs named **Timetable** and **Lessons**, using the `EduTabBar` widget. Every other tabbed surface in the school dashboard uses `EduTabBar` — this page must match that pattern exactly.

The **Timetable** tab hosts the timetable grid/schedule area (the display will be redesigned in TT-02, but the tab must exist and host the existing content as a placeholder for now).

The **Lessons** tab hosts a log of all lessons that have been recorded for the active school term. The lesson data should be presented grouped by date, with each entry showing the subject name and the teacher who taught it, consistent with how lessons are displayed in the `LessonsTab` widget in the academics section (read `lib/ui/screens/school_dashboard/CONTEXT.md` for that widget's description). If `TimetableDao` does not already have a method that watches all lessons for a school+term (without filtering to a specific timetable slot), one should be added to the DAO.

The FAB that triggers the timetable rules/generation flow is currently a large, rounded `FloatingActionButton` — visually inconsistent with the rest of the dashboard. It must be changed to match the `FloatingActionButton.small` pattern used on the Members page, Announcements page, and Roles page: small icon size, boxy/non-pill shape, same icon. The FAB still triggers the same generation flow; only its visual form changes.

The teacher, student, guardian, and staff timetable views in the same file are not affected — they remain single-view layouts with no tabs.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update the `timetable/` subdirectory entry to document the 2-tab structure and the new DAO method if one was added
- [x] Update `lib/database/daos/CONTEXT.md` if a new DAO method was added to `TimetableDao`
- [x] Mark this task `[x]`
- [x] Commit: `ui: timetable page 2-tab structure and FAB style fix`

---

### [x] Task TT-02: School-Wide Cross-Matrix Timetable Display

**Files to create/modify:** `lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`, `lib/database/daos/timetable_dao.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** Task TT-01
**Parallel group:** Sequential with TT-01 and TT-03

**Specification:**

The timetable display inside the Timetable tab (introduced in TT-01) still shows only one class at a time, gated behind a chip selector. Owners and administrators cannot see the full school schedule at once.

The new display must show the **complete school timetable** for the active term in a single unified cross-table matrix, without any class selector. The layout follows the structure shown in the attached reference image (`timetable.png`):

**Row axis (vertical):** Rows are organized as a three-level hierarchy: **Day → Grade → Stream**. Each day of the week for which at least one slot exists becomes a row group. Within each day, each grade is a sub-group, and within each grade, each stream is a leaf row. Days and grades that have no scheduled data are not shown.

**Column axis (horizontal):** Each column represents one time slot in the school day. Column headers show the start and end time of that slot (e.g., "8:00 – 8:40"). Where a break window falls between consecutive lesson slots, a **"Break"** label cell spans the full height of all data rows for that column position — it is a visual separator, not a lesson cell.

**Cells:** Each cell at the intersection of a leaf stream-row and a lesson-slot column shows the subject name and the teacher name for that assignment. Subject name and teacher name must be visually differentiated from each other — one must look different from the other through some combination of size, weight, color, or layout (the executor decides the exact styling, keeping it aligned with §21 of AGENT.md). A colored left accent border per subject (deterministic color from subject ID, matching the existing `_kSubjectColors` palette in the file) should be used to visually tie each cell to its subject.

**Empty cells:** When a class has no lesson in a lesson-slot column, the cell should be rendered as a clearly empty placeholder (e.g., a very subtle background with a dashed or thin border), not left as a blank gap.

A new DAO method is needed on `TimetableDao` that returns all timetable entries for a school+year+term, enriched with subject names (joined from the subjects catalog) and teacher names (joined from the users table). The existing `watchTimetable(schoolId, year, term, grade, stream)` is scoped to a single class and cannot be reused for this purpose.

**Desktop layout (≥600px):** Full cross-table grid rendered as a scrollable table. The Day column and its sub-hierarchy should be pinned on the left; time slot columns scroll horizontally.

**Mobile layout (<600px):** The full grid is too wide for narrow screens. The mobile layout should let the user browse one day at a time, with all grade/stream rows visible as a vertical list and time slots as horizontal columns within each day. The executor decides the exact adaptation (day pager, day selector chips, etc.) keeping it practical and consistent with §21.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update the `timetable/` section with the new display design and describe the new DAO method
- [ ] Update `lib/database/daos/CONTEXT.md` — document the new enriched school-wide timetable watch method
- [ ] Mark this task `[x]`
- [ ] Commit: `ui: school-wide cross-matrix timetable display`

---

### Task TT-03: Multi-Stage Timetable Generation Wizard

**Files to create/modify:**
`lib/ui/screens/school_dashboard/timetable/timetable_screen.dart`,
`lib/models/timetable_rules.dart`,
`lib/services/timetable_generator.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/models/CONTEXT.md`
**Depends on:** Task TT-02
**Parallel group:** Sequential with TT-01 and TT-02

**Specification:**

The current timetable configuration interface (`_TimetableRulesPage`) is a 3-tab sheet (Global / Teachers / Subjects). Its Global tab uses opaque numeric fields — a fixed start time, a uniform lesson duration, a uniform break duration, a separate lunch start and duration — that give the user no way to visualize the actual day structure before generating. Teacher and subject constraints are expressed as arbitrary time-range blocks, not as references to specific named slot positions in the day's sequence. There is no conflict resolution step, no visual feedback during generation, and after a successful generation run the user is not automatically sent to the timetable view.

This entire interface must be replaced with a **multi-stage sequential wizard** presented as a full-screen push route (not a bottom sheet). The wizard has five stages. The user navigates forward with a "Next" button and backward with a "Back" button. Stage headings and a step indicator should communicate progress. The aesthetic must be consistent with §21 of AGENT.md.

---

**Stage 1 — Build the Day's Slot Sequence**

The user builds an ordered list of slots that together define a single school day. The first slot starts at a day-start time that the user configures (e.g., 8:00 AM). Every subsequent slot starts immediately where the previous one ended — start times are computed automatically; the user never types them manually.

Each slot in the list is one of two types:
- **Lesson slot** — occupies a bookable period. The user specifies only the duration in minutes (e.g., 40). The slot is labeled with its computed start and end time.
- **Break slot** — a non-schedulable gap (short break, lunch, etc.). The user specifies only the duration in minutes (e.g., 20). The slot is displayed as a muted "Break" entry, visually distinct from lesson slots.

The user adds slots via a FAB. This FAB, when tapped, **expands** to reveal two secondary action buttons: one for "Lesson" and one for "Break". The pattern should be a compact expandable FAB consistent with the dashboard aesthetic (not a heavy widget). Tapping either secondary button prompts the user for the duration in minutes, then appends the new slot to the end of the sequence. Slots can be removed individually with a delete action on each row.

The slot list shows each slot's sequential number (useful in later stages when constraints reference slot positions), computed time range, type label, and duration.

---

**Stage 2 — Select Active Days**

The user selects which days of the week will follow the slot sequence built in Stage 1. Only the selected days will be used during timetable generation. The day selector should be clear and tappable (e.g., day chips), consistent with how day selectors appear elsewhere in the app.

---

**Stage 3 — Teacher Constraints**

The user can express scheduling constraints for individual teachers. A teacher is selected from a searchable list of all teachers at the school. For the selected teacher, the user creates constraint entries. Each entry specifies:
- Which day(s) it applies to (from the active days chosen in Stage 2)
- Which slot number(s) it applies to (referenced by the numbered positions from Stage 1)
- Whether it is a **block** (the teacher cannot be scheduled in those slots on those days) or a **requirement** (the teacher must only be scheduled in those slots on those days — i.e., blocked from everything else)

Multiple constraint entries per teacher are allowed. Constraint entries can be removed. The list of all configured teacher constraints (across all teachers) is visible on this stage, grouped by teacher.

---

**Stage 4 — Subject Constraints**

Analogous to Stage 3 but for subjects. A subject is selected from the school's assigned subjects for the active term. For the selected subject, constraint entries specify:
- Which day(s) it applies to
- Which slot number(s) it applies to
- Whether it is a block or a requirement (only appears in those slots)

Multiple constraint entries per subject are allowed, and the full list is visible grouped by subject.

---

**Stage 5 — Conflict Resolution and Generation**

Before allowing the user to generate, the wizard scans the configured teacher and subject constraints and identifies **incompatible pairs** — situations where a teacher constraint and a subject constraint, when applied together to a specific class assignment, have no valid slot that satisfies both simultaneously. For example: a teacher is required in slots 1–2 only, but the subject they teach is required in slots 3–4 only.

For each detected conflict pair, the user is shown the teacher constraint, the subject constraint, and a binary choice of which takes priority. The lower-priority constraint will be dropped when generating. This prevents the generator from entering an unsolvable state.

If no conflicts are detected, Stage 5 shows only a summary of the configured rules and the "Generate" button.

When the user taps Generate:
- A visual animation plays while generation runs in the background (the executor decides the animation style — e.g., animated progress indicator, slot-by-slot reveal, or other feedback that feels dynamic and polished per §21)
- On **success**: the wizard closes and the user is taken directly back to the **Timetable** tab of the Timetable page (the tab introduced in TT-01)
- On **failure**: an error state is shown explaining why generation failed, with options to go back and adjust constraints or retry

---

**Model and Generator Updates**

The `TimetableRules` model (`lib/models/timetable_rules.dart`) must be updated to represent the new slot-based structure. The ordered list of typed slots (each with a type and duration, from which start/end times are derived) replaces the current `dayStartSeconds`, `dayEndSeconds`, `lessonDurationMinutes`, `breakDurationMinutes`, `lunchStartSeconds`, and `lunchDurationMinutes` fields. Teacher and subject constraint structures must reference slot indices rather than time ranges. JSON serialization and deserialization must be updated accordingly.

The timetable generator (`lib/services/timetable_generator.dart`) must be adapted to build its schedulable slot domain from the new slot list rather than the old `buildSlots()` method. Teacher and subject constraint enforcement must use slot-index references instead of time-range overlap checks. Concepts like `maxLessonsPerDayTeacher`, `maxLessonsPerDayClass`, `allowDoubles`, and `defaultLessonsPerWeek` may be retained, removed, or moved — the executor decides what is still meaningful in the new slot-based model.

Backward compatibility with previously saved rule files in the old format is not required. If an old file is loaded and cannot be parsed by the new format, the wizard should silently open with default/empty state rather than crashing.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — fully rewrite the `timetable/` section to reflect the 5-stage wizard, the new rules page structure, and the generation flow
- [ ] Update `lib/models/CONTEXT.md` — update the `timetable_rules.dart` entry to describe the new slot-based model and updated constraint types
- [ ] Mark this task `[x]`
- [ ] Commit: `feat: multi-stage timetable generation wizard with slot builder`

---

### [x] Task AC-01: All-Streams Timetable View in the Grade Detail Page

**Files to create/modify:**
`lib/ui/screens/school_dashboard/academics/tabs/timetable_tab.dart`,
`lib/ui/screens/school_dashboard/academics/grade_detail_page.dart`,
`lib/database/daos/timetable_dao.dart` (if a new DAO method is needed)
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/database/daos/CONTEXT.md`
**Depends on:** none
**Parallel group:** P1 (runs in parallel with TT-01 and EX-01)

**Specification:**

Inside the Grade Detail page (reached by tapping a grade on the Academics screen), there is a two-layer tab system:
- **Layer 1:** A "Comparisons" tab (showing `ComparisonsTab`) followed by one tab per stream (e.g., Blue, Green, Yellow)
- **Layer 2 (only shown when a specific stream tab is active):** Students · Exams · Subjects · Attendance · Timetable · Lessons · Teachers

There are two problems with the current timetable display in this context:

**Problem 1 — No timetable on the Comparisons/All tab.**
When the user is on the Comparisons tab, no timetable is visible. Since the Comparisons tab gives a grade-wide view across all streams, it is natural for a timetable to be available here showing all streams at once. A timetable view must be added to the Comparisons tab, displaying a cross-table layout where the row axis is **Day → Stream** (grade is already implicit from the page context, so it is not needed as a row grouping level) and the column axis is time slots. Break windows between lesson slots should be displayed as spanning "Break" cells. Subject name and teacher name in each cell should be visually differentiated. This is the same visual principle described in TT-02 but adapted to a per-grade scope.

**Problem 2 — The stream-specific Timetable tab only shows one stream.**
When the user is on a specific stream tab (e.g., "Blue") and then taps the "Timetable" content tab, the current `TimetableTab` widget shows only that stream's schedule using a grid format. This is correct in principle, but since the user is already scoped to a single grade and a single stream, the display should show only **Day as the row grouping** and time slots as columns — no stream sub-grouping is needed. This is essentially a simplified version of the Comparisons-tab layout (same matrix structure but with the stream dimension removed).

Both layouts (all-streams from Comparisons, single-stream from a stream tab) must share the same visual design language: matrix grid with colored left-border cells, differentiated subject/teacher text, break spanning cells, consistent with §21 of AGENT.md.

If `TimetableDao` does not already have a method that returns all timetable entries for a given grade (across all streams, for a given school+year+term), one must be added. The existing `watchClassTimetable` is scoped to a single stream and cannot serve the Comparisons-tab view.

The executor should look at the `TimetableTab` widget's description in `lib/ui/screens/school_dashboard/CONTEXT.md` for the current implementation details before making changes.

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update the `academics/tabs/timetable_tab.dart` entry and the grade detail page structure section to reflect the new all-streams view and the modified single-stream layout
- [ ] Update `lib/database/daos/CONTEXT.md` if a new DAO method was added to `TimetableDao`
- [ ] Mark this task `[x]`
- [ ] Commit: `ui: all-streams cross-table timetable in grade detail page`

---

### [x] Task EX-01: Unified Cross-Table Layout for Exam Papers on Desktop

**Files to create/modify:**
`lib/ui/screens/school_dashboard/exams/exams_grades_screen.dart`,
`lib/ui/screens/school_dashboard/academics/exam_detail_page.dart`
**Context files to read:** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** none
**Parallel group:** P1 (runs in parallel with TT-01 and AC-01)

**Specification:**

Exam papers are displayed in two surfaces across the app. Both currently use a tab-based model on desktop that forces the user to click through grade tabs and stream sub-tabs to find a specific paper:

**Surface 1 — Exams & Grades page** (`exams_grades_screen.dart`):
When a user taps an exam group, `_ExamGroupDetailView` appears. It shows grade tabs at the top, stream sub-tabs below the grade tabs, and a paper grid (`_PaperTimetableGrid`) for the currently selected grade/stream. The user cannot see papers for multiple grades/streams simultaneously on desktop.

**Surface 2 — Academic Exam Detail** (`exam_detail_page.dart`):
When a user taps an exam from within the grade detail page's Exams content tab, `ExamDetailPage` opens. It has a Papers tab that shows papers filtered to one stream at a time.

**The problem:** On desktop screens (≥600px), having tabs to switch between grades/streams is an unnecessary navigation step. Since desktops have sufficient horizontal space, all papers for an exam should be visible in a single, unified view organized by their natural axes: when and which class.

**Required change for desktop (≥600px) on both surfaces:**

Replace the grade-tab + stream-sub-tab paper navigation with a single unified **cross-table matrix** that shows all papers for the exam at once:

- **Row axis:** Each row represents one **grade + stream combination** (one row per class that has papers in this exam). Row labels show the grade name and stream name. If the exam only spans a single grade (common when accessed from `ExamDetailPage`), rows represent only the streams of that grade.
- **Column axis:** Each column represents an exam **date**. Within each date column, if multiple papers are scheduled at different times on the same date, they are stacked vertically within the same column cell. Column headers show the formatted date (e.g., "Mon, 12 Jan").
- **Cells:** Each cell shows the paper's subject name and paper number. It must also carry **paper status coloring** — the same status-to-color mapping currently used (`_paperStatusColor`: pending=muted, in progress=blue, done=amber, marked=green) expressed as a left-accent border, background tint, or chip, at the executor's discretion. Tapping a cell must still navigate to `PaperDetailPage` for that paper.
- **Empty cells:** When a grade/stream has no paper on a given date, the cell is a clearly empty placeholder.

For `exams_grades_screen.dart` (`_ExamGroupDetailView`): The grade tabs and stream sub-tabs are replaced on desktop by this unified cross-table. The exam header (type badge, date range, delete button) and the Grades and Performance tabs remain unchanged. Only the Papers tab content changes on desktop. The executor should read the full description of `_ExamGroupDetailView` and `_PaperTimetableGrid` in `lib/ui/screens/school_dashboard/CONTEXT.md` before modifying.

For `exam_detail_page.dart` (`ExamDetailPage`): The Papers tab on desktop should similarly display the cross-table for all papers in the exam visible to this context (i.e., all papers for the exam's grade, across all streams of that grade). The Grades and Performance tabs are not affected. The executor should read the full `ExamDetailPage` description in `lib/ui/screens/school_dashboard/CONTEXT.md` before modifying.

**Mobile (< 600px):** No changes. The existing tab-based or list-based paper navigation is preserved for mobile. The `_PaperTimetableMobile` / `_PaperSlotCard` pattern in `exams_grades_screen.dart` remains untouched.

The visual design of the cross-table (typography, spacing, accent borders, cell sizing, header row) should be consistent with the matrix style used in TT-02 and AC-01 — the executor should harmonize the three grid designs so they share a recognizable visual language.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update both the `exams/` section (`_ExamGroupDetailView`, `_PaperTimetableGrid`) and the `academics/` section (`exam_detail_page.dart`, `_PapersTab`) to describe the new desktop layout
- [x] Mark this task `[x]`
- [x] Commit: `ui: unified cross-table layout for exam papers on desktop`
