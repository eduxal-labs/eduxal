# Exams Screen — CONTEXT.md

## Directory
`lib/ui/screens/school_dashboard/exams/`

## Files

| File | Status | Description |
|---|---|---|
| `exams_grades_screen.dart` | ✅ Active | Top-level entry point for Exams & Grades section. Contains `ExamsGradesScreen` (entry widget), `_ExamsShell` (navigation state: list → exam detail → paper detail), `_ExamsListView`, `_ExamGroupDetailView`, `_PaperDetailView`, `_CreatePaperSheet`, `_AddStreamForm`, `_AddGradeToExamForm`, plus many helper/picker widgets. ~9800 lines. |
| `exam_creation_page.dart` | ✅ Active | Full-screen exam creation flow. |

## Key Exports / Entry Points

- **`ExamsGradesScreen`** — `StatelessWidget`, requires `SchoolContext`. Mounted from the dashboard shell under "Exams & Grades" (teacher) or "Academics → Exams" (owner/staff).

## Role-Based Access Guards

- **`ExamsGradesScreen.build()`** checks `schoolContext.currentEntry.value`:
  - `StudentEntry` or `GuardianEntry` → returns `_RestrictedAccessState` (lock icon + "Not available" message). Defense-in-depth — nav routing should also prevent these roles from reaching this screen.
  - All other roles (Owner, Teacher, Staff) → proceeds to term check and then `_ExamsShell`.

## Dependencies

- `SchoolContext` (from `lib/models/school_context.dart`) — provides `currentEntry`, `membership`, `permissions`
- `ActiveTermProvider` / `ActiveTermContext` — provides current term for exam queries
- `ExamsGradesDao` — `watchExamGroups(schoolId, year, term)`
- `CatalogDao`, `SubjectsDao`, `MembersDao` — supporting data for subjects, teachers
- `SchoolConfig` — grade/stream/curriculum configuration
- `ExamGroup` model — grouped exam data

## Conventions

- Navigation within the exams section is managed by `_ExamsShell` via `_ExamsView` enum (`list`, `examDetail`, `paperDetail`).
- Permission checks (`_canCreateExam`, `_canEditExam`, `_canDeleteExam`, `_canMarkGrades`) use `SchoolContext.permissions.can(Resource.xxx, Action.yyy)`.
- **Teacher scoping (B03):** Teachers with `exams.update`/`exams.delete` can only edit/delete exams they created (`exam.teacher == teacherId`) or exams whose grades overlap with their `subject_teachers` assignments. Owners and staff with proper permissions can edit/delete any exam. The `_isTeacherExamOwnerOrAssigned` getter in `_ExamGroupDetailViewState` implements this guard.
- **`_canGradeContent` teacher fallback (C2):** In `paper_detail_page.dart`, `_canGradeContent` now mirrors `_canProgressStatus` — if the user lacks explicit `grades.read`/`grades.mark` RBAC permissions, a `TeacherEntry` user is still granted grade access if they created the exam (`_exam.teacher == userId`), are the paper's invigilator (`_paper.invigilator == userId`), or teach the paper's subject to its grade/stream (checked via `_teacherSubjects`). This ensures a teacher who can advance paper status can also enter grades.
- **Grade picker scoping (B03):** `_AddGradeToExamForm` and `_AddStreamForm` accept an optional `teacherAssignedGrades` parameter (`Set<int>?`). When non-null (i.e. for `TeacherEntry`), only grades in that set are shown in the grade picker. The set is derived from `_teacherSubjects` (loaded via `MembersDao.watchTeacherSubjectsForTerm`).
- Visual style follows `AGENT.md` §21: data-table rows, `AppTheme` border radii, dual box-shadow modals.

## Last Updated
Task C2 — Add teacher-specific fallback to `_canGradeContent` in `paper_detail_page.dart`.