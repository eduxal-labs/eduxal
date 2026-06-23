# EduXal Flutter — Task List

## Track A: Fix Grade Normalization for CBC Curriculum

### Task A1: Update CBC Grade Normalization in Import File Parser
**Files to create/modify:** `lib/services/import_file_parser.dart`
**Context files to read (if needed):** `lib/services/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**
Update the private top-level helper `_normalizeGrade(String curriculum, int rawGrade) → int` in `lib/services/import_file_parser.dart`.
Currently, it returns the raw grade as-is for the CBC curriculum:
```dart
int _normalizeGrade(String curriculum, int rawGrade) {
  if (curriculum == '844') {
    switch (rawGrade) {
      case 1:
        return 41;
      case 2:
        return 42;
      case 3:
        return 43;
      case 4:
        return 44;
      default:
        return rawGrade;
    }
  }
  // CBC — return as-is.
  return rawGrade;
}
```
In the database, CBC grades are represented as PP1=1, PP2=2, Grade 1–9 = 3–11, Grade 10–12 = 12–14.
When a user uploads a question bank JSON file for CBC Grade 12, they write `"grade": 12` in the JSON.
However, in the database, Grade 12 is represented by the integer `14`. The raw grade `12` represents Grade 10.
Thus, we must normalize CBC raw grades `1` to `12` by mapping them to `rawGrade + 2` (so Grade 1 becomes 3, Grade 10 becomes 12, Grade 12 becomes 14).
If the raw grade is already normalized (i.e. `13` or `14`), or outside the `1` to `12` range, it should be returned as-is.

Modify `_normalizeGrade` to:
```dart
int _normalizeGrade(String curriculum, int rawGrade) {
  if (curriculum == '844') {
    switch (rawGrade) {
      case 1:
        return 41;
      case 2:
        return 42;
      case 3:
        return 43;
      case 4:
        return 44;
      default:
        return rawGrade;
    }
  }
  if (curriculum == 'cbc') {
    if (rawGrade >= 1 && rawGrade <= 12) {
      return rawGrade + 2;
    }
  }
  return rawGrade;
}
```

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md` to document the grade normalization change.
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task

---

### Task A2: Update CONTEXT.md and BUG.md
**Files to create/modify:** `lib/services/CONTEXT.md`, `BUG.md`
**Context files to read (if needed):** None
**Depends on:** Task A1
**Parallel group:** None

**Specification:**
1. Update `lib/services/CONTEXT.md` under `## Last Updated` to document that `_normalizeGrade` now maps CBC raw grades 1–12 to DB-compatible grade numbers 3–14.
2. Append a new entry to `BUG.md` for `BUG-022: CBC Grade 12 questions bulk uploaded as Grade 10 due to missing grade normalization`.
   - Title: CBC Grade 12 questions bulk uploaded as Grade 10 due to missing grade normalization
   - Root Cause: In `lib/services/import_file_parser.dart`, `_normalizeGrade` returned the raw grade as-is for the CBC curriculum. Since Grade 12 is represented by integer `14` in the database and Grade 10 is represented by `12`, uploading a file with `"grade": 12` resulted in questions being saved under Grade 10.
   - Files changed: `lib/services/import_file_parser.dart`
   - Fix applied: Updated `_normalizeGrade` to map CBC raw grades `1` to `12` to `rawGrade + 2`.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task

---

## Track B: EditPaperQuestion Feature and Constant Q1 Label Bug

### Task B1: Implement EditPaperQuestion RPC on Server
**Files to create/modify:** `../ledger/protos/services/question_bank.proto`, `../ledger/src/db/database/tables/question_bank.rs`, `../ledger/src/proto/services/question_bank.rs`, `../ledger/src/services/question_bank.rs`
**Depends on:** None
**Parallel group:** None

**Specification:**
1. Add `EditPaperQuestion` RPC method to `question_bank.proto`.
2. Implement `edit_paper_question` database function in `../ledger/src/db/database/tables/question_bank.rs` that checks if the question is associated with other papers. If so, duplicate it and update the current paper's reference; otherwise, update it directly.
3. Implement the gRPC service handler in `../ledger/src/services/question_bank.rs`.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task

---

### Task B2: Wire EditPaperQuestion and Fix Constant Q1 Label Bug on Client
**Files to create/modify:** `lib/models/paper_generation.dart`, `lib/services/question_bank.dart`, `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Depends on:** Task B1
**Parallel group:** None

**Specification:**
1. Regenerate client-side Dart protobuf stubs using `./generate.sh`.
2. Update `PaperQuestion.fromProto` in `lib/models/paper_generation.dart` to accept an optional `order` parameter and set `order: order`.
3. Update `getPaperQuestions` and `regenerateQuestion` in `lib/services/question_bank.dart` to pass the correct order/index to `fromProto`.
4. Implement `editPaperQuestion` in `lib/services/question_bank.dart` to call the new gRPC endpoint.
5. Update `PaperGenerationPage` to pass `paperId: _rpcPaperId` to `editPaperQuestion`.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task

---

## Track C: System Dashboard Question Editing

### Task C1: Enable Question Editing on System Dashboard
**Files to create/modify:** `lib/ui/screens/system/settings/questions_list_page.dart`, `lib/ui/screens/system/settings/subjects_section.dart`
**Depends on:** None
**Parallel group:** None

**Specification:**
1. Make `_EditQuestionSheet` public as `EditQuestionSheet` in `questions_list_page.dart` so it can be imported and opened from other files.
2. Add an "Edit" button to `_QuestionTileState` in `subjects_section.dart` when `widget.canEdit` is true.
3. Wire the "Edit" button to launch `EditQuestionSheet` bottom sheet.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task

---

## Track D: Windows Build Fix

### Task D1: Silence MSVC Experimental Coroutine Deprecation Warning
**Files to create/modify:** `windows/CMakeLists.txt`
**Depends on:** None
**Parallel group:** None

**Specification:**
1. Add `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` to `add_definitions` in `windows/CMakeLists.txt`.
2. Add `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` to `target_compile_definitions` in `APPLY_STANDARD_SETTINGS` in `windows/CMakeLists.txt`.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Orchestrator: git commit after this task
