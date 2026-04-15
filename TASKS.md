# TASKS.md

## Proto Reconciliation — Fix Build Errors from question_bank Proto Schema Change

The generated `question_bank.pb.dart` proto stubs were updated to a newer schema, but the
app-side models and services still target the old field names/types. This caused ~40 compile
errors that prevented the Linux (and all other) builds.

**Status: ✅ All tasks complete. Build passes.**

---

### Task 01: Fix `lib/models/marking_status.dart`
**Files to create/modify:** `lib/models/marking_status.dart`
**Context files to read (if needed):** none
**Depends on:** none
**Parallel group:** P1

**Specification:**

The proto `MarkingStatusResponse` changed:
- `status` (MarkingStatusEnum) → `phase` (MarkingPhase enum from pbenum)
- `progressCurrent` (int) + `progressTotal` (int) → `progress` (String, e.g. "5/14")
- `errorMessage` (String) + `hasErrorMessage()` → `error` (String) + `hasError()`
- New field: `estimatedCompletion` (Int64)

The pbenum file no longer has `MarkingStatusEnum`. It has `MarkingPhase` with values:
`QUEUED(0)`, `DOWNLOADING(1)`, `CACHING(2)`, `MARKING(3)`, `AGGREGATING(4)`, `COMPLETE(5)`, `FAILED(6)`.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 02: Fix `lib/models/question.dart`
**Files to create/modify:** `lib/models/question.dart`
**Context files to read (if needed):** none
**Depends on:** none
**Parallel group:** P1

**Specification:**

Three issues fixed:
- `QuestionImage.fromProto` updated to use new proto fields (`key`, `url`, `caption` instead of `filename`, `description`, `getUrl`)
- `_imageContextFromProto` changed to accept `int` instead of `pbenum.ImageContext`
- `BulkImportResult.fromProto`: `proto.createdCount` → `proto.questionsCreated`
- Removed `pbenum` import

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 03: Fix `lib/models/question_grade.dart`
**Files to create/modify:** `lib/models/question_grade.dart`
**Context files to read (if needed):** none
**Depends on:** none
**Parallel group:** P1

**Specification:**

- `RubricResult.fromProto` changed from `pb.RubricResult` to `pb.RubricCriterion`
- `QuestionGradeDetail.fromProto` changed from `pb.QuestionGrade` to `pb.QuestionGradeDetail`

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 04: Fix `lib/models/paper_generation.dart`
**Files to create/modify:** `lib/models/paper_generation.dart`
**Context files to read (if needed):** none
**Depends on:** none
**Parallel group:** P1

**Specification:**

Proto `PaperQuestion` changed from flat fields to nested: `position` (int) + `question` (nested `Question`).
Rewrote `PaperQuestion.fromProto` to extract fields from the nested `question` sub-message.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 05: Fix `lib/services/question_bank.dart`
**Files to create/modify:** `lib/services/question_bank.dart`
**Context files to read (if needed):** none
**Depends on:** Tasks 01–04 (model changes)
**Parallel group:** P2

**Specification:**

Fixed all field name mismatches:
- Removed `pbenum` import and `_toProtoImageContext`/`_toProtoImage` helpers
- Changed `_toProtoCriterion` to return `pb.RubricCriterionInput`
- Fixed `getQuestion`, `updateQuestion`, `deleteQuestion`: `..id` → `..questionId`
- Removed `req.images.addAll(...)` from `createQuestion`/`updateQuestion`
- Fixed `generatePaper`: `resp.paperQuestions` → `resp.questions`
- Fixed `regenerateQuestion`: `paperQuestionId` → `position`, `resp.paperQuestion` → `resp.replacement`
- Fixed `editPaperQuestion`: removed `school`/`exam`/`subject`/`paper` params, return type → `Question`
- Fixed `finalizePaper`: removed `paperQuestionIds` param
- Fixed `getQuestionGrades`: `resp.questionGrades` → `resp.grades`
- Removed unused `_freshChannel` method

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 06: Fix `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** none
**Depends on:** Task 05 (service signature changes)
**Parallel group:** P3

**Specification:**

- `regenerateQuestion` call: `paperQuestionId: question.id` → `position: question.order`
- `editPaperQuestion` call: removed `school`/`exam`/`subject`/`paper`, changed to `questionId: question.questionId`, added PaperQuestion reconstruction from returned Question
- `finalizePaper` call: removed `paperQuestionIds` parameter

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 07: Fix minor warnings
**Files to create/modify:** `lib/database/tables/roles.dart`
**Context files to read (if needed):** none
**Depends on:** none
**Parallel group:** P1

**Specification:**

Removed unused import of `dart:typed_data`.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task 08: Verify build
**Depends on:** Tasks 01–07
**Parallel group:** P4

`flutter analyze` — 0 errors, 0 new warnings. Only pre-existing info/warnings.
`flutter build linux` — ✅ Built successfully.

- [x] Mark this task `[x]`
