# EduXal — Bug Registry

> **Every agent MUST read this file before starting any work.**
> This file is append-only. It logs all bugs and their fixes to prevent regressions.
> Before modifying any file listed in a bug entry, review the entry to ensure the fix is preserved.

---

## BUG-001: Paper status change not reflected in UI immediately

**Status:** Fixed
**Date:** 2025-07-10
**Files affected:**
- `lib/database/daos/exams_grades_dao.dart` — `watchPaper()`, `getPaper()`, `updatePaper()`, `deletePaper()`
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` — `_PaperDetailPageState`

**Symptom:**
On the Paper Detail page, clicking the progress status button (e.g. Pending → In Progress → Done) updated the database but the UI did not reflect the change until navigating away and back.

**Root cause:**
The `watchPaper()` method in `ExamsGradesDao` only filtered by `(school, exam, subject, paperNum)` but the papers table has a composite primary key of `(school, exam, subject, paper, grade, stream)`. When multiple papers existed for the same subject across different grade/stream combinations, `watchSingleOrNull()` could fail or return the wrong row. This also meant the reactive stream might not emit correctly.

The `updatePaper()` method similarly only filtered by `(school, exam, subject, paperNum)`, so it updated ALL paper rows across all grade/stream combinations — but the watch query might not re-emit the specific row the UI was tracking.

**Fix:**
Added `grade` and `stream` parameters to `watchPaper()`, `getPaper()`, `updatePaper()`, and `deletePaper()` in `ExamsGradesDao`. Updated all call sites in `paper_detail_page.dart` and `exams_grades_screen.dart` to pass the paper's `grade` and `stream` values. This ensures:
1. The watch stream tracks exactly one paper row (the full PK is specified).
2. The update only affects the intended paper row, not papers of other streams.

**Prevention:**
Any future method that queries or mutates the `papers` table MUST include `grade` and `stream` in the WHERE clause (in addition to `school`, `exam`, `subject`, `paper`) to match the full composite primary key.

---

## BUG-002: Updating one stream's paper status affects all streams

**Status:** Fixed
**Date:** 2025-07-10
**Files affected:**
- `lib/database/daos/exams_grades_dao.dart` — `updatePaper()`, `deletePaper()`

**Symptom:**
In an exam with Form 4 and 3 streams (Blue, Green, Yellow), updating a paper's status from the Blue stream tab caused the same paper in Green and Yellow streams to also show as updated. The timetable slot showed the correct stream's invigilator name but the status color changed across all streams.

**Root cause:**
The `updatePaper()` WHERE clause only filtered by `(school, exam, subject, paperNum)`, missing the `grade` and `stream` columns that are part of the composite primary key `(school, exam, subject, paper, grade, stream)`. This caused the SQL UPDATE to affect ALL rows matching the partial key — i.e., the same subject's paper across all streams.

The same issue existed in `deletePaper()`.

**Fix:**
Added `grade` (required `int`) and `stream` (required `int?`) parameters to `updatePaper()` and `deletePaper()`. The WHERE clause now includes all composite PK columns. All call sites updated to pass the paper's `grade` and `stream` values.

**Prevention:**
The papers table composite PK is `(school, exam, subject, paper, grade, stream)`. Any UPDATE or DELETE on this table MUST filter by ALL six columns. Never use a partial key unless the intent is explicitly to affect multiple rows (e.g., "delete all papers for an exam" which filters by `school + exam` only).

---

## BUG-003: Paper detail page shows exam teacher instead of paper's invigilator

**Status:** Fixed
**Date:** 2025-07-10
**Files affected:**
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` — `_PaperHeaderState`

**Symptom:**
When navigating to a paper's detail page from a stream tab (e.g. Green), the invigilator row in `_PaperHeader` always displayed the exam creator's name and avatar (e.g. Blue's invigilator) instead of the paper's actual invigilator for that stream. The paper status was correct, but the invigilator was wrong.

**Root cause:**
The `_PaperHeader` widget's Row 4 (Invigilator) used `exam.teacher.id` for the `UserAvatar` and `exam.teacher.name` for the label. `ExamWithPapers.teacher` is the user who **created the exam** — NOT the paper's invigilator. Each paper has its own `invigilator` field (a user ID string), but the header was ignoring it entirely and always showing the exam-level teacher.

When `_PaperDetailView` in `exams_grades_screen.dart` constructs the `ExamWithPapers` record, it sets `teacher: _selectedGroup!.teacher`, which is the exam group's teacher — always the same user regardless of which stream's paper was tapped.

**Fix:**
1. Added `_invigilatorName` (nullable String) and `_lastInvigilatorId` fields to `_PaperHeaderState`.
2. Added `_loadInvigilator()` method that resolves the paper's `invigilator` user ID to a `UsersData.name` via `MembersDao(db).findUserById()`.
3. Called `_loadInvigilator()` in both `initState()` and `didUpdateWidget()` (with an early-return guard when the ID hasn't changed).
4. Changed the invigilator row to use `UserAvatar(userId: paper.invigilator, ...)` and display `_invigilatorName ?? paper.invigilator` instead of `exam.teacher.id` / `exam.teacher.name`.

**Prevention:**
The `_PaperHeader` must NEVER use `exam.teacher` for the invigilator display. The invigilator is a per-paper field (`paper.invigilator`), not an exam-level field. Any future UI that displays a paper's invigilator must read from `paper.invigilator` and resolve the user name via DAO lookup — not from the `ExamWithPapers.teacher` record.

---

## BUG-004: DeltaWriter UNIQUE constraint failure when reconciling server-assigned IDs for subjects/topics

**Status:** Fixed
**Date:** 2025-07-15
**Files affected:**
- `lib/sync/delta_writer.dart` — `_applySubjectCatalog()`, `_applyTopic()`

**Symptom:**
When a System user creates a subject (e.g. "English" with curriculum CBC), the UI succeeds and shows the new subject immediately (optimistic local insert), but the terminal prints:
```
[DeltaWriter] ⚠ Error applying delta: table=31, op=0, key=5, hasData=true — SqliteException(2067): UNIQUE constraint failed: subjects.name, subjects.curriculum
```
The error is silently caught, so the local row retains its client-assigned autoIncrement ID (e.g. `id = 17`) instead of being reconciled with the server's authoritative ID (e.g. `id = 5`). This causes subsequent `updateSubject` / `deleteSubject` operations to send the wrong ID to the server, and topics referencing the server's subject ID fail to find the local row.

**Root cause:**
The `subjects` and `topics` tables use `integer().autoIncrement()` for their `id` columns. `CatalogDao.createSubject()` inserts a local row optimistically, letting SQLite assign a local auto-increment ID. When the server responds with its authoritative row (different ID, same natural key), `_applySubjectCatalog()` used `insertOnConflictUpdate()` which generates `INSERT ... ON CONFLICT("id") DO UPDATE ...`. Since the server ID (e.g. `5`) differs from the local ID (e.g. `17`), there is no primary key conflict — the `ON CONFLICT("id")` clause does not trigger. Instead, the INSERT attempts to create a second row with the same `(name, curriculum)`, violating the `UNIQUE(name, curriculum)` index. The same applies to `_applyTopic()` with `UNIQUE(subject, grade, name)`.

**Fix:**
The DeltaWriter now deletes any existing row matching the natural unique key but with a different ID before upserting. This removes the stale optimistic local row so the server's authoritative row can be inserted cleanly:

- `_applySubjectCatalog()`: `DELETE FROM subjects WHERE name = ? AND curriculum = ? AND id != ?`
- `_applyTopic()`: `DELETE FROM topics WHERE subject = ? AND grade = ? AND name = ? AND id != ?`

The optimistic local insert in the DAO is preserved — the subject/topic appears in the UI immediately. When the server responds, the DeltaWriter deletes the stale local row (wrong autoIncrement ID) and inserts the server's authoritative row (correct ID). The Drift reactive stream fires on both the delete and the insert, so the UI updates seamlessly. Subsequent `update` and `delete` operations then reference the correct server-assigned ID.

**Prevention:**
Any table that uses `autoIncrement()` for its primary key AND has a secondary UNIQUE index on natural columns requires this delete-by-natural-key pattern in the DeltaWriter. The `insertOnConflictUpdate()` method only generates `ON CONFLICT` for the primary key — it does NOT handle secondary unique constraints. For such tables, always delete the stale local row by natural key (with `id != serverID`) before upserting. Currently affected tables: `subjects` (PK: `id`, UNIQUE: `name, curriculum`) and `topics` (PK: `id`, UNIQUE: `subject, grade, name`).

---

## BUG-005: DeltaWriter trigger self-collision when applying terms upsert

**Status:** Fixed
**Date:** 2025-07-15
**Files affected:**
- `lib/sync/delta_writer.dart` — `_applyTerms()`

**Symptom:**
When a user creates a term, the UI succeeds but the terminal prints:
```
[DeltaWriter] ⚠ Error applying delta: table=9, op=0, key=...|2026|1, hasData=true — SqliteException(1811): term dates overlap with an existing term for this school, constraint failed (code 1811)
```
The error is silently caught, so the UI appears normal, but the local row retains the client's timestamps instead of being reconciled with the server's authoritative values (e.g. `created`, `updated`).

**Root cause:**
The `terms` table has a `BEFORE INSERT` trigger (`terms_no_overlap`) that checks the `terms` table itself for any existing row whose date range overlaps with the row being inserted:

```sql
CREATE TRIGGER terms_no_overlap
BEFORE INSERT ON terms
BEGIN
  SELECT RAISE(ABORT, 'term dates overlap with an existing term for this school')
  WHERE EXISTS (
    SELECT 1 FROM terms
    WHERE school = NEW.school
      AND start < NEW.end
      AND end   > NEW.start
  );
END
```

When the server responds after a successful push with the authoritative term row, `_applyTerms()` called `insertOnConflictUpdate()`, which generates `INSERT ... ON CONFLICT("school","year","term") DO UPDATE ...`. SQLite fires `BEFORE INSERT` triggers **before** evaluating the `ON CONFLICT` clause. The trigger finds the existing local row (same school, overlapping dates — in fact identical dates) and aborts with error 1811 before the conflict handler ever runs.

Unlike the UPDATE trigger (`terms_no_overlap_update`), which excludes the row being updated via `AND NOT (year = OLD.year AND term = OLD.term)`, the INSERT trigger has no such exclusion — it matches any overlapping row including the one about to be replaced.

**Fix:**
Changed `_applyTerms()` from `insertOnConflictUpdate` to a delete-then-insert pattern. The method now deletes any existing row matching the composite PK `(school, year, term)` before inserting the server's authoritative row. This ensures the `BEFORE INSERT` trigger sees a clean table and does not self-collide.

**Prevention:**
Any table with a `BEFORE INSERT` trigger that queries its own table for validation (e.g. overlap checks, uniqueness checks beyond the PK) is vulnerable to this bug when the DeltaWriter uses `insertOnConflictUpdate`. The trigger fires before `ON CONFLICT` resolution, so it sees the existing row as a conflict. For such tables, always use delete-then-insert in the DeltaWriter instead of `insertOnConflictUpdate`. Currently the only affected table is `terms` (trigger: `terms_no_overlap`). Other `BEFORE INSERT` triggers (`papers_within_exam_range`, `attendance_within_term`, `lessons_within_term`, `grades_enrollment_check`, `subscriptions_invoice_check`) check parent tables, not their own table, so they are not vulnerable to self-collision.

---

## BUG-006: DeltaWriter `_applyPapers` uses wrong ON CONFLICT target — last stream overwrites all previous streams

**Status:** Fixed
**Date:** 2025-07-16
**Files affected:**
- `lib/sync/delta_writer.dart` — `_applyPapers()`

**Symptom:**
When creating an exam with 1 grade and 3 streams, each with 12 autofilled papers (36 total), only the last stream's papers appear in the UI and in the local SQLite database after sync. The first two streams show no papers at all.

**Root cause:**
The `papers` table composite primary key is `(school, exam, subject, paper, grade, stream)` — 6 columns. The server encodes all 6 in the `rowKey` as `"{school}|{exam}|{subject}|{paper}|{grade}|{stream}"`.

However, `_applyPapers()` in `DeltaWriter` only used 4 of those 6 columns in its `ON CONFLICT` upsert target:

```dart
' ON CONFLICT (school, exam, subject, paper) DO UPDATE SET'
```

This is a narrower conflict target than the actual 6-column PK. The consequence:

The server sends cumulative `SyncDelta` broadcasts — every time a new paper is created, the server re-emits all previously confirmed papers via the watch stream. So after paper N is created, the client receives deltas for papers 1..N again.

When stream=1, subject=S, paper=P is inserted first, it occupies a row with `grade=44, stream=1`. When stream=2, subject=S, paper=P arrives next (same subject and paper number but different stream), the `ON CONFLICT (school, exam, subject, paper)` target **matches the existing stream=1 row** (because stream is not in the conflict target). The `DO UPDATE SET` then **overwrites** that row's `grade` and `stream` columns with the new values (`stream=2`), destroying the stream=1 row in-place. When stream=3 arrives, it overwrites stream=2 in the same way. End result: only stream=3 papers survive.

The same narrower-target bug exists in the `DELETE` operation path — it only filters by `(school, exam, subject, paper)` and could delete papers for all streams instead of the one targeted.

**Fix:**
Changed the `ON CONFLICT` target in `_applyPapers()` to include all 6 PK columns:

```dart
' ON CONFLICT (school, exam, subject, paper, grade, stream) DO UPDATE SET'
```

Also updated the `DELETE` operation path to parse `k[4]` (grade) and `k[5]` (stream) from the row key and include them in the `WHERE` clause, so deletes are precisely scoped to one row.

For the `NULL paper` branch, the delete-before-insert pattern already used `school, exam, subject` with `paper IS NULL` but also needed `grade` and `stream` to avoid deleting papers for other streams. Both the pre-insert delete and the delete-operation path are updated accordingly.

**Prevention:**
The `papers` table PK is `(school, exam, subject, paper, grade, stream)`. Any `ON CONFLICT` clause, `UPDATE`, or `DELETE` targeting a single paper row MUST include ALL SIX columns. Never use a partial subset of this PK as a conflict target — SQLite will silently match and overwrite the wrong row. When adding new delta-apply logic for papers (or any table with a multi-column PK that includes nullable columns), verify the `ON CONFLICT` target exactly matches the full PK declaration in `papers.dart`.

---

## BUG-007: Graded count on paper detail page inflated across streams

**Status:** Fixed
**Date:** 2025-07-17
**Files affected:**
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` — `_PaperDetailPageState.build()`
- `lib/ui/screens/school_dashboard/academics/exam_detail_page.dart` — `_PerformanceTabState._load()`

**Symptom:**
When viewing an exam with multiple streams (e.g. East with 14 students, West with 9 students), the paper detail header showed "graded 2/14" and "graded 2/9" instead of "graded 1/14" and "graded 1/9". The graded count (X in "graded X/Y") was summed across ALL streams instead of being filtered per-stream. The total students count (Y) was correct because it came from `getEnrolledStudents` which correctly filters by stream.

The same issue affected the Performance tab's rankings and "Graded" metric in the exam detail page — students from other streams were included in the rankings and graded count.

**Root cause:**
The `grades` table has the composite PK `(school, exam, student, subject, paper)` — it intentionally has NO `grade` or `stream` columns. A student's stream is determined by their enrollment, not stored on the grade row. The comment in `grades.dart` explicitly states: "there is intentionally NO FK from grades to papers. The papers PK includes (grade, stream) which grades does not carry."

`watchGradesForPaper(school, exam, subject, paper)` returns grade rows for ALL students matching those four columns, regardless of which stream those students belong to. When two papers exist for the same exam+subject+paperNum but different streams (e.g. Math Paper 1 for Stream East vs Stream West), the query returns grades from both streams.

In `paper_detail_page.dart`, `_students` was correctly filtered by `_paper.stream` via `getEnrolledStudents`, but `gradeRows` from `watchGradesForPaper` included students from all streams. `_PaperHeader._computeAnalytics()` counted `gradeRows.where((r) => r.grade.score > 0).length` as `gradedCount`, which was inflated by grades from other streams.

In `exam_detail_page.dart`, `_PerformanceTabState._load()` built rankings from `watchClassGrades(schoolId, examId)` (all grades for the exam) but compared against stream-filtered `enrolled` students. Students from other streams appeared in the rankings with fallback names ("Student $adm") and inflated `totalGraded`.

**Fix:**
1. **`paper_detail_page.dart`** — In `_PaperDetailPageState.build()`, after receiving `snap.data` from the grades stream, filter the grade rows to only include students whose `adm` is in the enrolled students set (`_students`). The enrolled students are already correctly stream-filtered by `getEnrolledStudents(stream: _paper.stream)`. The filtered `gradeRows` list is then passed to both `_PaperHeader` (for analytics) and the grade spreadsheet/list (for display).

2. **`exam_detail_page.dart`** — In `_PerformanceTabState._load()`, build a set of enrolled student adms and skip any grade row whose `student` is not in that set when populating the `byStudent` map. This ensures rankings and the "Graded" metric only count students from the current stream context.

**Prevention:**
The `grades` table lacks `grade`/`stream` columns by design. Any UI or service that displays per-stream grade counts MUST cross-reference grades against the stream-filtered enrolled student list. Never assume that `watchGradesForPaper` or `watchClassGrades` returns stream-scoped results — these queries return grades across all streams. Always filter grade rows through the enrolled student set when computing per-stream metrics.

---

## BUG-008: DeltaWriter `customStatement` writes don't trigger Drift watch streams

**Status:** Fixed
**Date:** 2025-07-18
**Files affected:**
- `lib/sync/delta_writer.dart` — `flush()`

**Symptom:**
After AI marking completes and the server syncs grade results back via `watchChanges`, the paper detail page UI does not update to show the new grades. The user must navigate away and back to see the updated data. The grades ARE written to the local SQLite database, but the `StreamBuilder` bound to `watchGradesForPaper` never re-emits.

**Root cause:**
The `DeltaWriter.flush()` method writes all delta data using `_db.customStatement()` (raw SQL). Drift does NOT track `customStatement` writes for stream invalidation — only writes done through Drift's typed API (`into(table).insert(...)`, `update(table)...`, `delete(table)...`) trigger automatic stream notifications. Since `customStatement` bypasses Drift's write tracking, the `StreamQueryStore` is never informed that tables were modified, and `watch*` queries never re-emit.

This affects ALL tables written by the DeltaWriter, not just grades. However, grades are the most visible case because the user is actively watching `watchGradesForPaper` on the paper detail page when AI marking results arrive.

**Fix:**
Added a `touchedTables` set to `flush()` that collects the `delta.table` index for each successfully applied delta. After the transaction completes and FK checks are re-enabled, the method calls `_db.notifyUpdates(updates)` with a `Set<TableUpdate>` built from the touched table indices mapped to their SQLite table names via a static `_tableNames` constant map. This explicitly tells Drift's stream engine which tables were modified, causing all active `watch*` queries on those tables to re-emit.

**Prevention:**
Any code that writes to the Drift database using `customStatement` (raw SQL) MUST call `_db.notifyUpdates({TableUpdate('table_name')})` afterwards to notify Drift's stream engine. Prefer Drift's typed API when possible. If `customStatement` is necessary (e.g. for complex upserts, trigger avoidance, or FK-disabled batches), always follow up with `notifyUpdates`.

---

## BUG-009: DeltaWriter `_applyGrades` INSERT ON CONFLICT blocked by `BEFORE INSERT` trigger

**Status:** Fixed
**Date:** 2025-07-18
**Files affected:**
- `lib/sync/delta_writer.dart` — `_applyGrades()`

**Symptom:**
When the server sends an update (operation=1) for an existing grade record via sync, the DeltaWriter silently fails to apply it. The terminal shows:
```
[DeltaWriter] ⚠ Error applying delta: table=18, op=1, key=..., hasData=true — SqliteException(...)
```
The grade row retains its old score/total instead of being updated with the server's authoritative values.

**Root cause:**
The `_applyGrades` method used `INSERT ... ON CONFLICT (school, exam, student, subject, paper) DO UPDATE SET ...` for non-NULL paper grades. The `grades` table has a `BEFORE INSERT` trigger (`grades_enrollment_check`) that validates the student's enrollment by querying the `enrollments`, `exams`, and `papers` tables.

SQLite fires `BEFORE INSERT` triggers **before** evaluating the `ON CONFLICT` clause. When the grade row already exists and the server sends an update delta, the INSERT fires the trigger first. If enrollment data hasn't settled in the current batch (deltas arrive in `seq` order, and enrollments for a different school context may not be present yet), or if the trigger's complex JOIN fails for any timing reason, the trigger aborts the INSERT with an error before the `ON CONFLICT DO UPDATE` clause ever executes. The error is caught by the `flush()` try-catch and logged, but the grade is never updated.

This is the same class of bug as BUG-005 (terms trigger self-collision), though the mechanism differs: BUG-005's trigger checked its own table; this trigger checks parent tables that may not have settled.

**Fix:**
Changed `_applyGrades` from a branched approach (NULL paper → delete-then-insert, non-NULL paper → INSERT ON CONFLICT) to a unified delete-then-insert pattern for ALL cases. The method now:
1. Deletes any existing row matching the full PK `(school, exam, student, subject, paper)` — handles both NULL and non-NULL paper with a single conditional SQL clause.
2. If the operation is a pure delete (operation=2), returns immediately.
3. Otherwise, inserts the server's authoritative row as a fresh INSERT (no ON CONFLICT needed since the old row was already deleted).

The `BEFORE INSERT` trigger fires on the fresh INSERT, but since the old row is gone, the validation runs against a clean state and is more likely to succeed.

**Prevention:**
Any table with a `BEFORE INSERT` trigger that queries other tables for validation (e.g. enrollment checks, date range checks, constraint checks) is vulnerable to this issue when the DeltaWriter uses `INSERT ON CONFLICT`. The trigger fires before conflict resolution, potentially failing if referenced data hasn't settled. For such tables, always use delete-then-insert in the DeltaWriter instead of `INSERT ON CONFLICT DO UPDATE`. Currently affected tables: `terms` (BUG-005), `grades` (this bug). Other tables with self-referencing or cross-table `BEFORE INSERT` triggers should be audited for the same pattern.

---

## BUG-010: Mobile modals double-wrapped by `showEduSheet` causing duplicate chrome and keyboard occlusion

**Severity:** Medium (visual glitch + functional keyboard issue on mobile)
**Discovered:** During Track A task examination
**Fixed by:** Tasks A0–A10

**Root Cause:**
`showEduSheet` in `lib/ui/widgets/edu_sheet.dart` wrapped every sheet widget in an `EduSheet` container on mobile (providing `modalBg` background, top border-radius, drag handle, title row, and `viewInsets.bottom` keyboard padding). However, every sheet widget (e.g. `CreateSchoolSheet`, `InviteUserSheet`, `CreateRoleSheet`, etc.) was already self-contained — each provided its own `Container` with `cs.surface` background, top border-radius, `_SheetHandle`, title/header row, and in many cases its own `viewInsets.bottom` padding on action buttons. This created two nested layers of chrome.

On desktop, a similar issue existed: `showEduSheet`'s dialog branch rendered a `_DialogTitleRow` above the sheet content, but each sheet already had its own header.

**Visible symptoms:**
- Two drag handles stacked vertically on mobile.
- A faint colour seam between `modalBg` (outer) and `cs.surface` (inner).
- When the keyboard opened, two layers both tried to account for `viewInsets.bottom`, causing form fields to be sandwiched and invisible.

**Files changed:**
- `lib/ui/widgets/edu_sheet.dart` — Removed `EduSheet` wrapper from mobile path; removed `_DialogTitleRow` from desktop path. `title` parameter deprecated (kept for backward compat).
- `lib/ui/screens/system/schools/create_school_sheet.dart` — ScrollView bottom padding 0→16.
- `lib/ui/screens/system/users/invite_user_sheet.dart` — ScrollView bottom padding 0→16.
- `lib/ui/screens/system/roles/create_role_sheet.dart` — ScrollView bottom padding now includes `viewInsets.bottom`.
- `lib/ui/screens/system/roles/role_detail_sheet.dart` — ScrollView bottom padding now includes `viewInsets.bottom`.
- `lib/ui/screens/system/users/user_detail_sheet.dart` — ScrollView bottom padding includes `viewInsets.bottom` in edit mode.
- `lib/ui/screens/system/members/members_section.dart` — `AddMemberSheet` ListView and `_AssignRoleSheet` ListView bottom padding now includes `viewInsets.bottom`.
- `lib/ui/screens/system/plans/plans_section.dart` — `_CreatePlanSheet` and `_PlanDetailSheet` ScrollView bottom padding now includes `viewInsets.bottom`.
- `lib/ui/screens/system/schools/school_detail_screen.dart` — Audited `_EditSchoolSheet`, `_AddOwnerSheet`, `_MpesaConfigSheet`; all already correct (no changes needed).

**Fix applied:**
1. `showEduSheet` mobile path now returns `builder(ctx)` directly (no `EduSheet` wrapper).
2. `showEduSheet` desktop path no longer renders `_DialogTitleRow` (sheets provide their own headers).
3. Each sheet audited to ensure it is the sole `viewInsets.bottom` handler, with keyboard-aware bottom padding on its ScrollView/ListView.

**Prevention:**
When adding new sheets launched via `showEduSheet`, the sheet widget must be fully self-contained (own background, handle, title, keyboard padding). `showEduSheet` only provides the system modal/dialog scaffolding (transparent background on mobile, outer chrome on desktop) — it does NOT add any sheet chrome.

---

## BUG-011: Permissions appear empty after saving a role (create or edit flow)

**Severity:** High (permissions silently show as 0 after save — misleads admins into thinking save failed)
**Discovered:** Track F investigation
**Fixed by:** Task F1

**Root Cause:**
Two independent issues combined to make permissions appear empty after save:

1. **Silent error swallowing in `parsePermissions`:** The `catch (_) { return {}; }` block in `_role_helpers.dart` discarded all parse errors without any logging. If `Permissions.fromJson` or `jsonDecode` threw for any reason (e.g. unexpected input shape, encoding edge case), the function silently returned an empty map — making it appear as if the role had no permissions. No diagnostic information was available to identify when or why parsing failed.

2. **Stale `didUpdateWidget` lifecycle in `_PermissionsTabState`:** After `_save()` in the permissions tab, the following race existed:
   - `await widget.dao.updateRole(...)` completes → DB updated
   - The parent `StreamBuilder` could fire with the new role data *before* `setState(() { _originalPermissions = Map.of(_editPermissions); })` ran
   - In `didUpdateWidget`, the condition `!_hasChanges` would be `false` (because `_originalPermissions` hadn't been updated yet), so `_resetFromRole` was skipped
   - On subsequent stream emissions, `old.role.permissions == widget.role.permissions` (both are the new value), so `_resetFromRole` was again skipped
   - The widget kept stale state from before the save

   Without a `Key` on the `_PermissionsTab` widget, Flutter reused the same `State` object across `StreamBuilder` rebuilds, making the `didUpdateWidget` timing-dependent behavior the sole mechanism for state refresh.

**Files changed:**
- `lib/ui/screens/school_dashboard/roles/_role_helpers.dart` — Replaced silent `catch (_)` with `catch (e, st)` that logs the input string, error, and stack trace via `debugPrint`. Added input logging at the start of `parsePermissions` and result logging on successful parse.
- `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart` — Added `super.key` to `_PermissionsTab` constructor. Added `key: ValueKey('perms_${role.id}_${role.updated}')` to the `_PermissionsTab` instantiation in `_SchoolRoleDetailScreenState.build()`, forcing Flutter to create a fresh `State` whenever the role's `updated` timestamp changes (i.e. after every save). Added diagnostic logging to `_resetFromRole` (logs role ID, raw permissions string, and parsed result).
- `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart` — Added roundtrip verification logging in `_RoleFormSheet._save()`: after `serialisePermissions`, logs the serialised JSON and the result of parsing it back via `parsePermissions`, confirming the roundtrip is lossless before writing to the DB.

**Fix applied:**
1. `parsePermissions` now logs all inputs, outputs, and errors — silent failures are no longer possible.
2. `_PermissionsTab` receives a `ValueKey` derived from `role.id` + `role.updated`, so after any save (which updates `role.updated`), Flutter disposes the old state and creates a fresh one via `initState` → `_resetFromRole`. This eliminates the `didUpdateWidget` timing race entirely.
3. `_RoleFormSheet._save()` reuses the serialised JSON variable for both logging and DB write, eliminating any possibility of double-serialisation.

**Prevention:**
- Never use empty `catch (_)` blocks in data parsing functions — always log at minimum the input and error in debug mode.
- When a `StatefulWidget` inside a `StreamBuilder` must reflect the latest stream data, prefer a `ValueKey` tied to the data's version/timestamp over relying on `didUpdateWidget` lifecycle timing.
- Add roundtrip verification logging when serialisation/deserialisation flows are introduced, at least during development.

---

## BUG-012: Permissions data corruption from seeder format and delta writer encoding

**Severity:** High (permissions silently empty — same user-visible symptom as BUG-011 but different root cause)
**Discovered:** Task 03 deep code trace
**Related:** BUG-011 (previous fix addressed UI state timing symptoms, not the underlying data corruption)

**Root Cause:**
Two independent data-layer bugs corrupt the `roles.permissions` text column so that `parsePermissions()` returns an empty map:

1. **Seeder stored permissions in an unparseable format.** In `lib/core/seeder.dart`, the seeder built a raw binary blob as a `List<int>` (`[5, 2, 0, 7, 2, 0, 8, 130, 0, ...]`) using the `[resource_id, lo_byte, hi_byte]` encoding, then stored `jsonEncode(permBytes)` — producing a JSON array of raw integers like `'[5,2,0,7,2,0,8,130,0,9,15,0,11,134,0,14,2,0]'`. `Permissions.fromJson()` only handles two shapes: (a) list of `{"resource": "...", "actions": [...]}` objects, (b) flat `{"resource.action": true}` map. The seeder's integer array matched neither shape — every entry was an `int`, not a `Map<String, dynamic>`, so all entries were silently skipped. Result: empty permissions for all seeded roles.

2. **Delta writer base64-encoded instead of UTF-8-decoding.** In `lib/sync/delta_writer.dart`, `_applyRoles` stored `base64Encode(row.permissions)` where `row.permissions` is a protobuf `bytes` field (`List<int>`). The client originally sent these bytes as `utf8.encode(jsonString)`. The server stores and returns the same bytes. But the delta writer base64-encoded them instead of UTF-8-decoding them back to the original JSON string. After a server sync, the permissions column contained a base64 string like `'W3sicmVzb3VyY2UiOiJ1c2VycyIsImFjdGlvbnMiOlsicmVhZCJdfV0='` — which `jsonDecode()` throws on, causing `parsePermissions` to return empty.

**Files changed:**
- `lib/ui/screens/school_dashboard/roles/_role_helpers.dart` — `parsePermissions()` rewritten to be resilient to all three storage formats: (1) standard JSON objects via `Permissions.fromJson`, (2) JSON integer arrays via `Permissions.fromBlob`, (3) base64-encoded strings via base64 decode then try UTF-8 JSON or raw binary blob. Each attempt is logged. Falls through gracefully — never throws.
- `lib/sync/delta_writer.dart` — Added `_decodePermissions(List<int> bytes)` helper that tries `utf8.decode` first (restoring the original JSON string), falls back to `base64Encode` if the bytes aren't valid UTF-8. Changed `_applyRoles` from `base64Encode(row.permissions)` to `_decodePermissions(row.permissions)`.
- `lib/core/seeder.dart` — Replaced the manual binary blob construction (`permBytes` + `addPerm` + `jsonEncode(permBytes)`) with a proper `Map<Resource, int>` built using typed `Resource` and `Action` enums from `models/permissions.dart`, serialised to the standard JSON list-of-objects format (`[{"resource": "students", "actions": ["read"]}, ...]`) that `Permissions.fromJson()` parses directly. The `CreateRolePayload.permissions` field now uses `utf8.encode(permJson)` for consistency.

**Fix applied:**
1. `parsePermissions` handles all three storage formats with clear logging at each step — no format silently produces an empty map if the data is valid in any known encoding.
2. Delta writer correctly UTF-8-decodes permissions bytes back to JSON, with base64 fallback that `parsePermissions` can recover from.
3. Seeder produces the canonical JSON format, eliminating the source of binary-int-array corruption for new seed data.

**Prevention:**
- When storing protobuf `bytes` fields into Drift `text` columns, always decode with `utf8.decode` — never `base64Encode` — unless the column is explicitly documented as base64.
- When a data format has multiple possible encodings, the parser must handle all of them defensively rather than assuming a single canonical form.
- Seeder code must use the same serialisation functions as production code (or equivalent logic) — never hand-roll a different encoding for the same column.
- Cross-reference BUG-011: the UI-level fixes (ValueKey, logging) from BUG-011 remain valuable as defense-in-depth, but would not have fixed the data-layer corruption addressed here.

---

## BUG-013: Mobile tab dual-animation ripple on school dashboard

**Severity:** Low (visual glitch — dual ripple when switching tabs)
**Discovered:** User-reported Issue 1
**Fixed by:** Task A1

**Root Cause:**
Each tab in `_UnifiedMobileTabBar` was an independent `AnimatedContainer` whose `color` and `boxShadow` properties transitioned when `selectedIndex` changed. When the parent rebuilt with a new `selectedIndex`, every tab widget rebuilt — the old selected tab animated from `cs.surface` → `transparent` while the new selected tab animated from `transparent` → `cs.surface`. Both animations ran in parallel, creating a visible dual-ripple effect.

**Files changed:**
- `lib/ui/screens/school_dashboard/school_dashboard_screen.dart` — `_UnifiedMobileTabBar` rewritten to use `TabBar` + `TabController` instead of custom `GestureDetector` + `AnimatedContainer`. `_buildTab` helper removed. Constructor changed from `selectedIndex` + `onTabSelected` to `TabController controller`.

**Fix applied:**
Replaced the custom per-tab `AnimatedContainer` approach with Flutter's `TabBar` widget connected to the existing `_tabController`. `TabBar` uses a single sliding `BoxDecoration` indicator that moves between tabs — only one visual element animates. Splash and overlay effects suppressed via `NoSplash.splashFactory` + transparent `overlayColor`.

**Prevention:**
When building custom tab indicators, prefer Flutter's built-in `TabBar` with `TabController` to get a single sliding indicator animation. Avoid multiple independent `AnimatedContainer` widgets that all respond to the same state change.

---

## BUG-014: Silent permission parse failure in dashboard session init

**Severity:** High (dashboard tabs silently missing — teachers see only 4 base tabs regardless of permissions)
**Discovered:** User-reported Issue 2
**Fixed by:** Task B2

**Root Cause:**
In `_SchoolDashboardScreenState._initializeSession()`, permissions were parsed using inline `jsonDecode(r.permissions)` + `Permissions.fromJson(decoded)` wrapped in a silent `catch (_) {}`. If the permission string was in any format that `jsonDecode` or `Permissions.fromJson` couldn't handle (e.g. the seeder's binary-int-array format, or base64-encoded strings from the delta writer), the catch block silently swallowed the error. The result: `aggregated` stayed as `Permissions.empty()`, `SchoolPermissions` had no permissions, and all conditional tabs in `_itemsForRole()` were skipped.

The resilient `parsePermissions()` function (written as part of BUG-012's fix) handles ALL known formats — but `_initializeSession()` wasn't using it.

**Files changed:**
- `lib/core/permission_parser.dart` — Created (Task B1): extracted `parsePermissions`, `serialisePermissions`, `countPermissions`, `popcount` from `_role_helpers.dart`.
- `lib/ui/screens/school_dashboard/roles/_role_helpers.dart` — Modified (Task B1): function bodies replaced with re-export from `permission_parser.dart`.
- `lib/ui/screens/school_dashboard/school_dashboard_screen.dart` — Modified (Task B2): replaced inline `jsonDecode` + `Permissions.fromJson` + silent `catch` with `parsePermissions()` from `core/permission_parser.dart`. Added diagnostic logging. Removed `dart:convert` import.

**Fix applied:**
1. Extracted `parsePermissions` to `lib/core/permission_parser.dart` for shared use.
2. Replaced the fragile inline parsing in `_initializeSession()` with the resilient `parsePermissions()` call.
3. Added diagnostic logging showing scope count, role count, and aggregated permissions.

**Prevention:**
- Never use empty `catch (_) {}` blocks in data parsing — always log at minimum the error.
- Reuse shared parsing functions instead of duplicating parsing logic inline.
- Cross-reference BUG-012 which originally created the resilient parser.

---

## BUG-015: Role edit permissions not persisting (ValueKey timestamp collision)

**Severity:** Medium (permissions appear to save but revert on re-entry)
**Discovered:** User-reported Issue 3
**Fixed by:** Task C1

**Root Cause:**
The `_PermissionsTabState._save()` method used seconds-precision timestamps (`DateTime.now().millisecondsSinceEpoch ~/ 1000`) for the `roles.updated` column. When two saves occurred within the same second, the `ValueKey('perms_${role.id}_${role.updated}')` on the `_PermissionsTab` widget did not change, so Flutter reused the old `State` object instead of creating a fresh one via `initState` → `_resetFromRole`. The stale state showed the old permissions. Additionally, `didUpdateWidget` could race with the stream emission after save, potentially skipping `_resetFromRole`.

**Files changed:**
- `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart` — Changed `nowSeconds` (seconds) to `nowMs` (milliseconds) for `updated` timestamp. Added comprehensive diagnostic logging to `_save()`, `_resetFromRole`, and `didUpdateWidget`. Added post-save DB verification read.
- `lib/ui/screens/school_dashboard/roles/school_roles_screen.dart` — Changed create flow timestamp from seconds to milliseconds for consistency.

**Fix applied:**
1. Switched from seconds to milliseconds precision for `updated` timestamps, making `ValueKey` collisions virtually impossible.
2. Added pre-save logging (cleaned map, serialised string, roundtrip parse).
3. Added post-save verification (read role back from DB, log stored permissions and roundtrip parse, flag mismatches).
4. Added `didUpdateWidget` logging to trace when/why permission resets happen.

**Prevention:**
- Use millisecond-precision timestamps for any column that drives a `ValueKey` — seconds granularity is too coarse for interactive saves.
- Add roundtrip verification logging during development to catch serialisation/deserialisation issues early.

---

## BUG-016: Paper detail mobile sheets missing EduSheet wrapper post BUG-010

**Severity:** Medium (grading form inputs hidden behind keyboard; action sheet has no background)
**Discovered:** User-reported Issues 4 & 5
**Fixed by:** Tasks D1 + D2

**Root Cause:**
After BUG-010, `showEduSheet` on mobile no longer wraps builder content in an `EduSheet` container — every sheet must be self-contained (own background, drag handle, title row, `viewInsets.bottom` keyboard padding). However, `_MobileGradeEntrySheet` and `_openStudentActionSheet` in `paper_detail_page.dart` were never updated to be self-contained. They still returned bare widgets expecting the now-removed `EduSheet` wrapper. A stale comment even said "EduSheet (via showEduSheet) owns the background container…" — which was incorrect post BUG-010.

**Files changed:**
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` — (Task D1) `_MobileGradeEntrySheet.build()` wrapped in `EduSheet(title: student.name)`. Stale comment replaced. Layout compacted (tighter padding, reduced gaps, compact input decorations). `ElevatedButton` replaced with two icon buttons (cancel + green save). (Task D2) `_openStudentActionSheet` content wrapped in `EduSheet(title: student.name)` + `SafeArea(top: false)`. `title` param removed from `showEduSheet` call.

**Fix applied:**
1. Both sheets now wrap their content in `EduSheet` directly, providing modal background, drag handle, title row, and keyboard padding.
2. Grade entry form compacted for better mobile fit.
3. Save button replaced with icon buttons per §21 guidelines.
4. Student action sheet gains proper `SafeArea` for bottom home indicator.

**Prevention:**
When `showEduSheet`'s wrapping behaviour changes (as in BUG-010), ALL existing sheets launched through it must be audited. Search for all `showEduSheet` call sites and verify each builder returns a self-contained widget.

---

## BUG-017: Teacher with attendance.mark role permission cannot mark attendance for non-assigned classes

**Severity:** High (RBAC-granted attendance permission silently ignored for teachers)
**Discovered:** User-reported
**Related:** §17a Resource & Action Design — Attendance resource has `Read` and `Mark` actions

**Root Cause:**
In `attendance_tab.dart`, the `_resolveCanMark()` method handled `TeacherEntry` by **only** checking `_membersDao.isClassTeacherFor()` — whether the teacher is the active class teacher for the specific class. It never consulted `SchoolPermissions` at all. In contrast, the `StaffEntry` case correctly checked `permissions.can(Resource.attendance, Action.mark)`.

This meant a teacher who had been assigned a role granting `Attendance.Mark` permission (via the `scopes` + `roles` tables) was still denied marking ability for any class they didn't personally teach. The class picker already showed all classes school-wide (`EnrollmentsDao.watchPopulatedClasses()` has no teacher filter), so the teacher could navigate to any class but was incorrectly denied marking permission once there.

**Files changed:**
- `lib/ui/screens/school_dashboard/academics/tabs/attendance_tab.dart` — `_resolveCanMark()` `TeacherEntry` case rewritten to a two-step check: (1) check `permissions.can(Resource.attendance, Action.mark)` first — if granted, `canMark = true` for any class; (2) only if the permission is not granted, fall back to `isClassTeacherFor()` check.

**Fix applied:**
The `TeacherEntry` case now mirrors the `StaffEntry` logic as a first check, with the original class-teacher assignment check as a fallback. Teachers with the attendance.mark permission via an assigned role can now mark attendance for ALL classes. Teachers without the explicit permission can still mark attendance for classes they are the active class teacher for (preserving the original default behavior).

**Prevention:**
- When implementing RBAC-gated features, always check `SchoolPermissions` first for ALL member entry types (not just Staff). The class-teacher / assignment check is a default fallback, not the primary gate.
- Cross-reference §17a: the three-tier permission model applies to Teachers the same as Staff. Only the fallback behavior differs (teachers get implicit access to their assigned classes).

---

## BUG-018: Role permission save on school dashboard — success SnackBar never shown, errors silently swallowed

**Severity:** Medium (permissions ARE saved to DB, but user receives no confirmation — leads to perception that save failed)
**Discovered:** User-reported ("nothing gets saved" on school dashboard role edit)
**Related:** BUG-011 (ValueKey fix), BUG-015 (timestamp precision fix)

**Root Cause:**
The `ValueKey('perms_${role.id}_${role.updated}')` mechanism on `_PermissionsTab` (introduced by BUG-011) works correctly for state freshness — after a save, the `updated` timestamp changes, the `ValueKey` changes, and Flutter creates a fresh `_PermissionsTabState` that reads the saved data from the DB. However, this same mechanism has a side effect: the OLD `_PermissionsTabState` (where `_save()` is running) gets **disposed** when the Drift stream fires with the new role data — often BEFORE `_save()` reaches its post-`await` code.

When the old state is disposed:
- `mounted` returns `false`
- `setState(() { _originalPermissions = ... })` is skipped (correct — new state handles this)
- `ScaffoldMessenger.of(context).showSnackBar(...)` is SKIPPED — **user sees no success feedback**
- In the `catch` block, `setState(() => _saveError = ...)` is SKIPPED — **errors are silently lost**

The save actually succeeds (DB is updated, the new state shows correct permissions), but the user has no confirmation. Combined with the state recreation collapsing all expanded resource sections, the experience feels like "nothing happened."

**Files changed:**
- `lib/ui/screens/school_dashboard/roles/school_role_detail_screen.dart` — `_PermissionsTabState._save()`: (1) Capture `ScaffoldMessengerState` via `ScaffoldMessenger.of(context)` BEFORE the `await` gap, while `context` is still valid. (2) Show success SnackBar via the captured messenger unconditionally (outside the `if (mounted)` block). (3) In the `catch` block, always `debugPrint` the error, and when `!mounted`, show an error SnackBar via the captured messenger instead of silently dropping it.

**Fix applied:**
1. `final messenger = ScaffoldMessenger.of(context);` captured at the top of `_save()`, before any async gap.
2. Success SnackBar (`'Permissions saved.'`) shown via `messenger.showSnackBar(...)` regardless of mount state.
3. Error SnackBar shown via `messenger.showSnackBar(...)` when `!mounted`, with `debugPrint` for all errors.
4. `setState` calls remain guarded by `if (mounted)` — only the SnackBar feedback bypasses the mount check.

**Prevention:**
- When a `StatefulWidget` uses a `ValueKey` tied to mutable data (e.g., a timestamp that changes on save), always capture `ScaffoldMessengerState` (and any other context-dependent references) BEFORE `await` calls that might trigger the key change.
- Never assume `mounted` will be `true` after an `await` that writes to a watched Drift table — the stream emission can dispose the state before the `await` resumes.

---

## BUG-019: System role detail screen missing BUG-011/BUG-015 fixes — permissions don't persist on update

**Severity:** High (system-scoped role permission edits silently fail to reflect in UI after save)
**Discovered:** User-reported, code audit
**Related:** BUG-011 (ValueKey fix), BUG-015 (timestamp precision), BUG-018 (SnackBar feedback)

**Root Cause:**
The system role detail screen (`lib/ui/screens/system/roles/role_detail_screen.dart`) was never updated with the fixes applied to the school dashboard role detail screen in BUG-011 and BUG-015. Three issues combined:

1. **No `ValueKey` on `_PermissionsTab`** — after `_save()` writes to the DB, the Drift stream fires and `didUpdateWidget` is called. Due to the race condition described in BUG-011, `_resetFromRole` is often skipped: `permsDiffer` is `true` but `_hasChanges` is also `true` (because `_originalPermissions` hasn't been updated yet), so the condition `permsDiffer && !_hasChanges` evaluates to `false`. The widget keeps stale state. Without a `ValueKey`, Flutter reuses the same `State` object and never forces a fresh `initState`.

2. **Seconds-precision timestamp** — `_save()` used `DateTime.now().millisecondsSinceEpoch ~/ 1000` (seconds). Even if a `ValueKey` were added, two saves within the same second would produce the same key, causing Flutter to reuse the old state (BUG-015 scenario).

3. **No save feedback when unmounted** — same issue as BUG-018; `ScaffoldMessenger.of(context)` not captured before `await`.

**Files changed:**
- `lib/ui/screens/system/roles/role_detail_screen.dart` — (1) Added `super.key` to `_PermissionsTab` constructor. (2) Added `key: ValueKey('perms_${role.id}_${role.updated}')` at the `_PermissionsTab` instantiation site in `_RoleDetailScreenState.build()`. (3) Changed `nowSeconds` (seconds since epoch) to `nowMs` (milliseconds since epoch) in `_save()`. (4) Added `final messenger = ScaffoldMessenger.of(context)` before the `await` gap. (5) Added post-save verification `debugPrint` statements. (6) Changed SnackBar to use captured messenger; added error logging and error SnackBar for unmounted state.

**Fix applied:**
1. `ValueKey` forces Flutter to destroy the old `_PermissionsTabState` and create a fresh one after every save, eliminating the `didUpdateWidget` timing race.
2. Millisecond-precision timestamps make `ValueKey` collisions virtually impossible.
3. Captured `ScaffoldMessengerState` ensures success/error SnackBars always display.
4. Post-save verification confirms the DB write succeeded.

**Prevention:**
- When a bug fix is applied to one variant of a screen (e.g., school dashboard roles), always audit whether the same fix is needed on other variants (e.g., system roles). Search for parallel implementations.
- The system roles screen still uses a string-based permission model (`Map<String, bool>`) with local `_parsePermissions`/`_serialisePermissions` instead of the typed `Resource`/`Action` enum model. A future task should fully convert it to the typed system used by the school dashboard, using the shared `parsePermissions`/`serialisePermissions` from `core/permission_parser.dart`.

---

## BUG-020: Standalone user invites were queued as `updateUser`, got stuck, and duplicated school-owner logs

**Status:** Fixed
**Date:** 2026-05-02
**Files affected:**
- `lib/database/database.dart`
- `lib/database/daos/users_dao.dart`
- `lib/database/daos/logs_dao.dart`
- `lib/ui/screens/system/users/invite_user_sheet.dart`
- `lib/ui/screens/system/schools/create_school_sheet.dart`
- `lib/ui/screens/system/schools/school_detail_screen.dart`
- `lib/services/authorization_service.dart`
- `lib/models/app_notification.dart`
- `lib/ui/screens/system/notifications/notifications_section.dart`
- `lib/ui/screens/system/notifications/notifications_panel.dart`
- `lib/ui/screens/notifications/notifications_page.dart`

**Symptom:**
Standalone user invites from the system users screen were written as `SyncAction.updateUser` with an invite-shaped `UpdateUserPayload`. Once the server moved to a dedicated `inviteUser` action, those queued rows failed and stayed stuck in the failed queue. The school-creation and owner-link flows also queued an extra standalone invite log even though their parent payloads already embedded the owner invite fields.

**Root cause:**
The client originally used `updateUser` as a create-via-update workaround because no standalone invite action existed. After the contract added `InviteUserPayload` + `SyncAction.inviteUser`, old on-disk log rows still contained protobuf bytes for `UpdateUserPayload`, so replaying them kept hitting the wrong server path. The school-owner UI also still called `usersDao.inviteUser()`, producing redundant logs beside `createSchool` / `createOwner` even though those parent actions already carried owner identity data.

**Fix:**
1. Bumped the local Drift schema to **12**.
2. Added a one-time migration that scans queued `updateUser` logs, detects the legacy invite shape (`id + phone + name + level + status=invited`), rewrites the payload to `InviteUserPayload`, and changes the action to `SyncAction.inviteUser`.
3. Failed invite-shaped rows are reset back to `pending`, `error = NULL`, and `attempts = 0` so they replay automatically after upgrade.
4. `UsersDao.inviteUser()` now queues the dedicated standalone invite action and payload.
5. The standalone invite sheet now mirrors the final server invite rules: system creators with `Users.Create` may invite **System** only; only super creators may invite **Normal**, **System**, or **Super**.
6. School creation and owner-link flows no longer queue a second standalone invite log. They stage a local invited `users` row for optimistic FK integrity and rely on the parent `createSchool` / `createOwner` action payload for sync.
7. Revert, notification, and authorization mappings were updated for the new `inviteUser` action, including discarding failed optimistic invite rows cleanly.

**Prevention:**
- Standalone invites must use `SyncAction.inviteUser` only; genuine user edits stay on `SyncAction.updateUser`.
- Any future on-disk sync action change must ship with an explicit queue migration because `logs.action` values and protobuf payloads are persisted locally.
- School/member parent actions that already embed invite fields must not queue a second standalone invite log.
