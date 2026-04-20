# TASKS.md

## Question Import Investigation — System-Wide Questions + 8-4-4 Grade Coverage

The system dashboard question import flow has two reported issues:

1. Importing many JSON files from the **system dashboard** fails with **"school not found"**.
   This is incorrect for question-bank CRUD/import because system questions are global and should not require a school.
2. Under **8-4-4** in the system dashboard question/topic flow, only **Form 3** and **Form 4** are available.
   The user wants **Form 1–Form 4** available for question import and topic management.

Research findings already confirmed from the current client codebase:
- System settings/question-bank UI is documented as **system-wide, not school-scoped**.
- `QuestionBankService.createQuestion()` and `bulkImport()` currently send only `topicId` / `jsonContent` and **do not send a school field**.
- Generated proto request types for question CRUD/import (`CreateQuestionRequest`, `BulkImportRequest`, `ListQuestionsRequest`) also **do not contain a `school` field**.
- The current 8-4-4 restriction is client-side in `lib/ui/screens/system/settings/subjects_section.dart`, where `_TopicsPanelState._gradeEntries` explicitly filters 8-4-4 grades down to only `43` and `44`.
- Shared grade labels already support full 8-4-4 coverage: `41=Form 1`, `42=Form 2`, `43=Form 3`, `44=Form 4`.

Because the user also asked whether the server needs changes, the tasks below separate:
- client fixes that are definitely needed,
- and a server/proto contract audit to determine whether backend changes are also required.

---

### Task 01: Remove client-side 8-4-4 grade restriction in system subjects/questions UI
**Files to create/modify:** `lib/ui/screens/system/settings/subjects_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** none
**Parallel group:** P1

**Specification:**
Update `_TopicsPanelState._gradeEntries` so that:
- CBC still excludes `PP1` and `PP2` (`grade <= 2`) exactly as it does now.
- 8-4-4 no longer filters to only `43` and `44`.
- For `CurriculumType.eightFourFour`, all entries from `gradeLabelsFor(widget.curriculum)` must remain available, which includes:
  - `41 -> Form 1`
  - `42 -> Form 2`
  - `43 -> Form 3`
  - `44 -> Form 4`

Do not change the shared grade-label maps in `models/school_config.dart`; they already contain the correct labels.
Do not alter CBC behavior.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note that system question/topic grade chips now expose full 8-4-4 Form 1–4 coverage
- [x] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 02: Audit and fix system question import flow so it remains school-agnostic on the client
**Files to create/modify:** `lib/ui/screens/system/settings/multi_file_import_sheet.dart`, `lib/ui/screens/system/settings/subject_bulk_import_sheet.dart`, `lib/services/import_file_parser.dart`, `lib/services/question_bank.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`, `lib/services/CONTEXT.md`
**Depends on:** none
**Parallel group:** P1

**Specification:**
Perform a focused client audit of the system-dashboard import path and fix any client-side behavior that incorrectly assumes school scope.

Use the already-known flow:
- `MultiFileImportSheet._importAll()` calls `client.questionBank.importFileWithImages(...)`
- `QuestionBankService.importFileWithImages()` calls `bulkImport(parsed.cleanedJson!, accessToken: ...)`
- `QuestionBankService.bulkImport()` sends `pb.BulkImportRequest()..jsonContent = jsonContent`
- `BulkImportRequest` has no `school` field in the generated proto

Required work:
1. Verify that no client code in this import path injects, derives, or requires a school ID.
2. If any client-side validation/error mapping is converting a backend failure into a misleading generic import failure, improve the surfaced error text/logging so the exact backend message is preserved for diagnosis.
3. Add concise diagnostic logging around the import request/response path so future failures clearly show:
   - file/topic being imported,
   - whether the request is system-wide,
   - and the exact gRPC error code/message returned by the backend.
4. Preserve the existing import behavior for image upload and partial-success handling.

Important constraints:
- Do not invent a school parameter in the client proto/service layer.
- Do not change generated proto files.
- Do not broaden this into paper-generation APIs; those school-scoped APIs are separate and valid.

**Update after completion:**
- [ ] Update `lib/services/CONTEXT.md` — document the clarified system-wide import behavior and any new diagnostics in `QuestionBankService`
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — document any import-sheet behavior/error-message changes
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 03: Produce backend/proto compatibility findings for the “school not found” import failure
**Files to create/modify:** `TASKS.md`
**Context files to read (if needed):** `lib/proto/CONTEXT.md`, `lib/services/CONTEXT.md`, `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Task 02
**Parallel group:** P2

**Specification:**
After Task 02 confirms the client request shape, append a short findings section under this task in `TASKS.md` summarizing whether the server must change.

The executor should base the conclusion on the already-established client/proto contract:
- `CreateQuestionRequest` has `topicId`, `text`, `marks`, `exampleAnswer`, `rubric`
- `BulkImportRequest` has only `jsonContent`
- `ListQuestionsRequest` has `topicId`, `minMarks`, `maxMarks`, `offset`, `limit`
- None of these request types include `school`

Expected conclusion format to append under this task:
- **Client status:** whether the client is now correctly school-agnostic
- **Proto contract status:** whether the proto currently models question-bank CRUD/import as global
- **Server change required?:** `Yes`, `No`, or `Likely yes`
- **Why:** one concise paragraph

Decision rule:
- If the backend still throws “school not found” for `bulkImportQuestions` / question creation despite the proto carrying no school field, mark **Server change required?: Likely yes** and explain that the backend is incorrectly enforcing school scope for a system-wide question-bank endpoint, or is deriving school from auth/session in a way that breaks system imports.
- If Task 02 uncovers a client bug that actually sends the wrong endpoint/path/metadata, document that instead.

This task is documentation-only inside `TASKS.md`; do not edit server code in this repository.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task

---

### Task 04: Update context inventories after the question-import fixes
**Files to create/modify:** `lib/ui/screens/system/CONTEXT.md`, `lib/services/CONTEXT.md`
**Context files to read (if needed):** none
**Depends on:** Tasks 01–03
**Parallel group:** P3

**Specification:**
Refresh the relevant context files so future agents do not re-investigate the same issue.

Required updates:
- In `lib/ui/screens/system/CONTEXT.md`:
  - note that system question/topic management is system-wide and not school-scoped,
  - note that 8-4-4 grade selection now exposes Form 1–4,
  - note any improved import diagnostics or user-facing error behavior.
- In `lib/services/CONTEXT.md`:
  - note the question-bank import request shape is school-agnostic,
  - note any new logging/diagnostic behavior in `QuestionBankService.importFileWithImages()` / `bulkImport()`.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Orchestrator: git commit after this task