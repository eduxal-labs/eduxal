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
- Visual style follows `AGENT.md` §21: data-table rows, `AppTheme` border radii, dual box-shadow modals.

## Last Updated
Task B3 — Guard `ExamsGradesScreen` against student and guardian access.