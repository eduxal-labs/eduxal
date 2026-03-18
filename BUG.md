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