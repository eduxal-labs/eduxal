# Exams Screen — CONTEXT.md

## Last Updated
Task 02 (fix) — `paper_pdf_viewer.dart` now uses `share_plus` (`Share.shareXFiles`) for mobile PDF sharing instead of showing the raw file path in a SnackBar. `share_plus: ^10.0.0` added to `pubspec.yaml`.


## Directory
`lib/ui/screens/school_dashboard/exams/`

## Files

| File | Status | Description |
|---|---|---|
| `exams_grades_screen.dart` | ✅ Active | Top-level entry point for Exams & Grades section. Contains `ExamsGradesScreen` (entry widget), `_ExamsShell` (navigation state: list → exam detail → paper detail), `_ExamGroupDetailView`, `_PaperDetailView`, `_CreatePaperSheet`, `_AddStreamForm`, `_AddGradeToExamForm`, plus many helper/picker widgets. ~9800 lines. |
| `paper_detail_page.dart` | ✅ Active | Paper detail page with grade entry, AI marking, scheme upload, and — as of Task 01 — **"Generate Paper" button (⚡ icon, visible when `canManage && isPending`) now navigates to `PaperGenerationPage`** via `Navigator.push(MaterialPageRoute(...))`. Previously showed a "coming soon" SnackBar. Import `paper_generation_page.dart` was added to wire this up. |
| `paper_generation_page.dart` | ✅ Active | 3-step AI paper generation wizard: Step 0 = topic mark allocation (loads `CatalogDao.watchTopicsBySubjectAndGrade`), Step 1 = review/edit/regenerate questions (calls `QuestionBankService.generatePaper`, `regenerateQuestion`, `editPaperQuestion`), Step 2 = finalize + download PDF (calls `QuestionBankService.finalizePaper`, `getPaperPdf`). Fully implemented. Entry point: `PaperGenerationPage(schoolId, examId, subjectId, paperId?, grade, stream?, subjectName, examName)`. **UX improvements (Task 01 fix):** (1) Generation errors now show as inline `_GenerationErrorBanner` (red container above footer) instead of a SnackBar — `_generateError` state field, cleared on each new attempt, set via `_friendlyGenerateError(GrpcError)` which maps `failedPrecondition`/`notFound`/`unauthenticated` to human-readable strings. (2) Loading overlay (`Stack` + `Positioned.fill`, semi-transparent surface + spinner + "Generating questions…" label) covers the topic list while `_isGenerating` is true. (3) `addPostFrameCallback` accumulation fixed: `_lastSyncedTopics` field tracks the last synced topic list; the callback is only registered when `topicsChanged` is true (length or ID mismatch), preventing redundant `setState` calls on every stream rebuild. |
| `paper_pdf_viewer.dart` | ✅ Active | `downloadAndOpenPdf` — top-level async function that fetches a presigned PDF URL via `QuestionBankService.getPaperPdf`, downloads bytes via `HttpClient`, saves to temp dir, and opens with the system viewer (`xdg-open`/`open`/`start`). On Android/iOS, opens the system share sheet via `Share.shareXFiles` (`share_plus` ^10.0.0) so the user can print, open in a PDF viewer, or share the file. Used by both `paper_generation_page.dart` (Step 2 finalize) and `paper_detail_page.dart` (Print Paper button on done/marked papers). |
| `exam_list_view.dart` | ✅ Active | `ExamsListView` — main exam list with search/filter toolbar. Accepts `schoolId`, `year`, `term`, `schoolContext`, `config`, `subjectNames`, `entry`, `onExamTap`. Uses `ExamsGradesDao.watchExamGroups()` → `Stream<List<ExamGroup>>`. **Stream caching (Task C3):** The Drift stream is cached in `_examStream` state field, initialized in `initState()`, and rebuilt in `didUpdateWidget()` only when `schoolId`, `year`, `term`, or `entry` change. Search query and type filter changes trigger `setState` but do NOT rebuild the stream — filtering is applied client-side via `_applyFilters()` on the snapshot data. This prevents re-subscription churn (unsubscribe→resubscribe with loading spinner flash) on every keystroke or filter toggle. Teacher scoping: teachers without `exams.read` permission only see exams they participate in (creator, invigilator, or subject teacher) via `teacherFilter` param. |
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
Task 02 (fix) — `paper_pdf_viewer.dart` mobile branch now uses `share_plus` (`Share.shareXFiles`) instead of raw path SnackBar. See file table entry above for full details.