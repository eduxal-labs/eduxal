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