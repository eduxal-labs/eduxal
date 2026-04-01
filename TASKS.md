# TASKS.md — Question Bank & AI Marking Overhaul (Client)

> **Feature:** Question bank system with AI-powered paper generation, marking status feedback, and per-question results.
>
> **Key constraint:** Question bank tables are **server-only** — the client does NOT have these tables in Drift. All question data comes via unary gRPC calls to the `QuestionBank` service, not via the sync/Drift stream pipeline. UI uses `Future<Result<T, GrpcError>>` from services, not `Stream<T>` from DAOs.
>
> **Commit rule:** Every executor agent MUST run `git add -A && git commit -m "<type>: <description>"` 
> immediately after completing its task. Do NOT defer commits. Types: `feat`, `fix`, `refactor`, `ui`, `docs`, `chore`.

---

## Track 0: Commit Uncommitted Changes

### Task 00: Commit any uncommitted changes before starting work ✅
**Files to modify:** None (git operation only)
**Depends on:** None
**Parallel group:** P0

**Specification:**
Before starting any work, check for uncommitted changes:
```
git status --short
```
If there are uncommitted changes, commit them:
```
git add -A && git commit -m "chore: commit pending changes before question bank overhaul"
```

**Expected outcome:** Clean working tree. All previous work preserved.

**Commit:** This task IS the commit.

**Status:** ✅ Complete — working tree was already clean. No commit needed.

---

## Track 1: Proto Generation (Dart Bindings)

### Task 01: Define and generate QuestionBank proto Dart bindings ✅
**Files to create:** `lib/proto/services/question_bank.pb.dart`, `lib/proto/services/question_bank.pbenum.dart`, `lib/proto/services/question_bank.pbgrpc.dart`, `lib/proto/services/question_bank.pbjson.dart`
**Context files to read (if needed):** `lib/proto/CONTEXT.md`, `lib/proto/services/ai_marking.pb.dart` (reference for proto patterns)
**Depends on:** None (blocked on server providing `.proto` file — executor should confirm file exists or create stubs)
**Parallel group:** P1

**Specification:**

The server will provide `protos/services/question_bank.proto`. The executor must:

1. Obtain the `.proto` file from the server (or confirm it is already present in the `protos/` directory at the project root).
2. Run `protoc` to generate Dart bindings into `lib/proto/services/`:
   ```
   protoc --dart_out=grpc:lib/proto protos/services/question_bank.proto
   ```
3. Verify the generated files compile cleanly.

The proto service definition is:

```protobuf
service QuestionBank {
    rpc CreateQuestion(CreateQuestionRequest) returns (CreateQuestionResponse);
    rpc UpdateQuestion(UpdateQuestionRequest) returns (UpdateQuestionResponse);
    rpc DeleteQuestion(DeleteQuestionRequest) returns (DeleteQuestionResponse);
    rpc BulkImportQuestions(BulkImportRequest) returns (BulkImportResponse);
    rpc RequestImageUploadUrls(ImageUploadUrlsRequest) returns (ImageUploadUrlsResponse);
    rpc GeneratePaper(GeneratePaperRequest) returns (GeneratePaperResponse);
    rpc RegenerateQuestion(RegenerateQuestionRequest) returns (RegenerateQuestionResponse);
    rpc EditPaperQuestion(EditPaperQuestionRequest) returns (EditPaperQuestionResponse);
    rpc FinalizePaper(FinalizePaperRequest) returns (FinalizePaperResponse);
    rpc GetPaperPdf(GetPaperPdfRequest) returns (GetPaperPdfResponse);
    rpc ListQuestions(ListQuestionsRequest) returns (ListQuestionsResponse);
    rpc GetQuestion(GetQuestionRequest) returns (GetQuestionResponse);
    rpc GetQuestionGrades(GetQuestionGradesRequest) returns (GetQuestionGradesResponse);
    rpc GetMarkingStatus(MarkingStatusRequest) returns (MarkingStatusResponse);
}
```

**Expected proto message types (executor should verify against actual `.proto`):**

- `CreateQuestionRequest`: topic_id (int), text (string), marks (int), rubric (repeated RubricCriterion), example_answer (string, optional), images (repeated QuestionImage)
- `RubricCriterion`: criterion (string), marks (int)
- `QuestionImage`: context (enum: QUESTION=0, RUBRIC=1, EXAMPLE_ANSWER=2), filename (string), caption (string, optional), description (string)
- `CreateQuestionResponse`: question (Question message)
- `Question`: id (int), topic_id (int), text (string), marks (int), rubric (repeated RubricCriterion), example_answer (string), images (repeated QuestionImage), created (int64), updated (int64)
- `UpdateQuestionRequest`: id (int), text (string), marks (int), rubric (repeated RubricCriterion), example_answer (string), images (repeated QuestionImage)
- `UpdateQuestionResponse`: question (Question)
- `DeleteQuestionRequest`: id (int)
- `DeleteQuestionResponse`: (empty or success bool)
- `BulkImportRequest`: json_content (string) — the full topic.json content as a string
- `BulkImportResponse`: created_count (int), errors (repeated ImportError)
- `ImportError`: index (int), message (string)
- `ImageUploadUrlsRequest`: question_id (int), filenames (repeated string)
- `ImageUploadUrlsResponse`: urls (repeated SignedImageUrl)
- `SignedImageUrl`: filename (string), put_url (string), get_url (string), expiry (int64)
- `GeneratePaperRequest`: school (string), exam (string), subject (int), paper (int, optional), grade (int), stream (int, optional), total_marks (int), topic_allocations (repeated TopicAllocation)
- `TopicAllocation`: topic_id (int), marks (int)
- `GeneratePaperResponse`: paper_questions (repeated PaperQuestion)
- `PaperQuestion`: id (string — temp ID), question_id (int), text (string), marks (int), rubric (repeated RubricCriterion), images (repeated QuestionImage), order (int)
- `RegenerateQuestionRequest`: school (string), exam (string), subject (int), paper (int, optional), grade (int), paper_question_id (string), topic_id (int), marks (int)
- `RegenerateQuestionResponse`: paper_question (PaperQuestion)
- `EditPaperQuestionRequest`: school (string), exam (string), subject (int), paper (int, optional), paper_question_id (string), text (string), marks (int), rubric (repeated RubricCriterion)
- `EditPaperQuestionResponse`: paper_question (PaperQuestion)
- `FinalizePaperRequest`: school (string), exam (string), subject (int), paper (int, optional), grade (int), stream (int, optional), paper_question_ids (repeated string)
- `FinalizePaperResponse`: pdf_url (string), pdf_expiry (int64)
- `GetPaperPdfRequest`: school (string), exam (string), subject (int), paper (int, optional), grade (int), stream (int, optional)
- `GetPaperPdfResponse`: pdf_url (string), pdf_expiry (int64)
- `ListQuestionsRequest`: topic_id (int), offset (int), limit (int)
- `ListQuestionsResponse`: questions (repeated Question), total (int)
- `GetQuestionRequest`: id (int)
- `GetQuestionResponse`: question (Question)
- `GetQuestionGradesRequest`: school (string), exam (string), student (int), subject (int), paper (int, optional)
- `GetQuestionGradesResponse`: question_grades (repeated QuestionGrade)
- `QuestionGrade`: question_text (string), marks_awarded (double), total_marks (int), feedback (string), rubric_results (repeated RubricResult)
- `RubricResult`: criterion (string), satisfied (bool), marks_awarded (double), marks_available (int)
- `MarkingStatusRequest`: school (string), exam (string), subject (int), paper (int, optional), grade (int), stream (int, optional)
- `MarkingStatusResponse`: status (enum: QUEUED=0, DOWNLOADING=1, MARKING=2, COMPUTING=3, COMPLETE=4, FAILED=5), progress_current (int), progress_total (int), error_message (string)

If the `.proto` file is not yet available from the server, the executor should create **hand-written Dart stub files** that match the above message structure so downstream tasks are not blocked. Mark the task as partial and note that re-generation is needed once the server provides the actual `.proto`.

**Update after completion:**
- [x] Update `lib/proto/CONTEXT.md` — add QuestionBank service section with all message types
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "feat: create QuestionBank proto Dart stub bindings"`

---

## Track 2: Domain Models

### Task 02: Create client-side domain models for question bank data ✅
**Files to create:** `lib/models/question.dart`, `lib/models/paper_generation.dart`, `lib/models/marking_status.dart`, `lib/models/question_grade.dart`
**Context files to read (if needed):** `lib/models/CONTEXT.md`, `lib/models/result.dart`
**Depends on:** Task 01
**Parallel group:** P2

**Specification:**

Create pure Dart domain models that the UI will consume. These bridge proto types to clean app-layer types. All live in `lib/models/`.

**`lib/models/question.dart`:**

```dart
/// Image context for where the image appears.
enum ImageContext { question, rubric, exampleAnswer }

/// A single rubric criterion with its mark allocation.
class RubricCriterion {
  final String criterion;
  final int marks;
  const RubricCriterion({required this.criterion, required this.marks});
}

/// An image attached to a question.
class QuestionImage {
  final ImageContext context;
  final String filename;
  final String? caption;
  final String description;
  final String? getUrl; // Populated after upload or from server
  const QuestionImage({
    required this.context,
    required this.filename,
    this.caption,
    required this.description,
    this.getUrl,
  });
}

/// A question in the question bank.
class Question {
  final int id;
  final int topicId;
  final String text;
  final int marks;
  final List<RubricCriterion> rubric;
  final String? exampleAnswer;
  final List<QuestionImage> images;
  final DateTime created;
  final DateTime updated;
  const Question({ ... });

  /// Factory to create from proto message.
  factory Question.fromProto(/* proto Question type */ proto) { ... }
}

/// Result of a bulk import operation.
class BulkImportResult {
  final int createdCount;
  final List<ImportError> errors;
  const BulkImportResult({required this.createdCount, required this.errors});
}

class ImportError {
  final int index;
  final String message;
  const ImportError({required this.index, required this.message});
}
```

**`lib/models/paper_generation.dart`:**

```dart
/// A topic with its mark allocation for paper generation.
class TopicAllocation {
  final int topicId;
  final String topicName; // For display only — not sent to server
  int marks;
  TopicAllocation({required this.topicId, required this.topicName, this.marks = 0});
}

/// A generated question for a paper (before finalization).
class PaperQuestion {
  final String id; // Temporary server-assigned ID
  final int questionId;
  final String text;
  final int marks;
  final List<RubricCriterion> rubric;
  final List<QuestionImage> images;
  final int order;
  const PaperQuestion({ ... });

  factory PaperQuestion.fromProto(/* proto PaperQuestion */ proto) { ... }
}

/// Result of paper finalization — contains the PDF URL.
class PaperPdf {
  final String pdfUrl;
  final DateTime pdfExpiry;
  const PaperPdf({required this.pdfUrl, required this.pdfExpiry});
}
```

**`lib/models/marking_status.dart`:**

```dart
/// Status of an AI marking job.
enum MarkingPhase { queued, downloading, marking, computing, complete, failed }

class MarkingStatus {
  final MarkingPhase phase;
  final int progressCurrent;
  final int progressTotal;
  final String? errorMessage;
  const MarkingStatus({ ... });

  double get progressFraction =>
      progressTotal > 0 ? progressCurrent / progressTotal : 0.0;

  String get displayLabel => switch (phase) {
    MarkingPhase.queued => 'Queued',
    MarkingPhase.downloading => 'Downloading images...',
    MarkingPhase.marking => 'Marking ($progressCurrent/$progressTotal students)...',
    MarkingPhase.computing => 'Computing results...',
    MarkingPhase.complete => 'Complete',
    MarkingPhase.failed => 'Failed: ${errorMessage ?? "Unknown error"}',
  };

  factory MarkingStatus.fromProto(/* proto MarkingStatusResponse */ proto) { ... }
}
```

**`lib/models/question_grade.dart`:**

```dart
/// Per-rubric-criterion result from AI marking.
class RubricResult {
  final String criterion;
  final bool satisfied;
  final double marksAwarded;
  final int marksAvailable;
  const RubricResult({ ... });
}

/// Per-question grade breakdown from AI marking.
class QuestionGradeDetail {
  final String questionText;
  final double marksAwarded;
  final int totalMarks;
  final String feedback;
  final List<RubricResult> rubricResults;
  const QuestionGradeDetail({ ... });

  factory QuestionGradeDetail.fromProto(/* proto QuestionGrade */ proto) { ... }
}
```

All `fromProto` factories should map proto enum values (ints) to the Dart enums. Follow the existing pattern in the codebase where proto types are used only as deserialization targets and domain models are what the UI sees.

**Update after completion:**
- [x] Update `lib/models/CONTEXT.md` — add entries for all four new model files
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "feat: create domain models for question bank (question, paper_generation, marking_status, question_grade)"`

---

## Track 3: Service Layer

### Task 03: Create QuestionBankService — question CRUD + bulk import ✅
**Files to create:** `lib/services/question_bank.dart`
**Context files to read (if needed):** `lib/services/CONTEXT.md`, `lib/services/ai_marking.dart` (reference pattern), `lib/client.dart`
**Depends on:** Task 01, Task 02
**Parallel group:** P3

**Specification:**

Create `lib/services/question_bank.dart` — a stateless service that wraps `QuestionBankClient` gRPC stubs.

**Constructor pattern** (same as `AiMarkingService`):
```dart
class QuestionBankService {
  QuestionBankService({
    required ClientChannel channel,
    required String host,
    required int port,
  }) : _mainChannel = channel,
       _host = host,
       _port = port;

  final ClientChannel _mainChannel;
  final String _host;
  final int _port;

  ClientChannel _freshChannel() => ClientChannel(
    _host,
    port: _port,
    options: const ChannelOptions(credentials: ChannelCredentials.secure()),
  );
```

**Methods to implement:**

| Method | Signature | Description |
|---|---|---|
| `listQuestions` | `Future<Result<(List<Question>, int), GrpcError>> listQuestions({required int topicId, int offset = 0, int limit = 50, required String accessToken})` | Paginated question list for a topic. Returns `(questions, totalCount)`. |
| `getQuestion` | `Future<Result<Question, GrpcError>> getQuestion({required int id, required String accessToken})` | Single question by ID. |
| `createQuestion` | `Future<Result<Question, GrpcError>> createQuestion({required int topicId, required String text, required int marks, required List<RubricCriterion> rubric, String? exampleAnswer, List<QuestionImage> images = const [], required String accessToken})` | Create one question in a topic. |
| `updateQuestion` | `Future<Result<Question, GrpcError>> updateQuestion({required int id, required String text, required int marks, required List<RubricCriterion> rubric, String? exampleAnswer, List<QuestionImage> images = const [], required String accessToken})` | Update an existing question. |
| `deleteQuestion` | `Future<Result<void, GrpcError>> deleteQuestion({required int id, required String accessToken})` | Delete a question. |
| `bulkImport` | `Future<Result<BulkImportResult, GrpcError>> bulkImport({required String jsonContent, required String accessToken})` | Bulk import questions from topic.json content. |
| `requestImageUploadUrls` | `Future<Result<List<SignedImageUrl>, GrpcError>> requestImageUploadUrls({required int questionId, required List<String> filenames, required String accessToken})` | Get presigned PUT URLs for question images. |

**Error handling pattern:** Same as `AiMarkingService` — try main channel, catch `GrpcError`, return `Err(e)`. Non-gRPC exceptions mapped to `GrpcError.internal(...)`. Use `print()` for logging (not `debugPrint`).

**All methods take `required String accessToken`** and pass it via `CallOptions(metadata: {'authorization': 'Bearer $accessToken'})`.

**Update after completion:**
- [ ] Update `lib/services/CONTEXT.md` — add QuestionBankService section
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

### Task 04: Create PaperGenerationService — generate, review, finalize papers ✅
**Files to create/modify:** `lib/services/question_bank.dart` (extend with paper generation methods)
**Context files to read (if needed):** `lib/services/CONTEXT.md`
**Depends on:** Task 03
**Parallel group:** P3b

**Specification:**

Add paper generation methods to `QuestionBankService`:

| Method | Signature | Description |
|---|---|---|
| `generatePaper` | `Future<Result<List<PaperQuestion>, GrpcError>> generatePaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required int totalMarks, required List<TopicAllocation> allocations, required String accessToken})` | Generate paper questions from topic allocations. |
| `regenerateQuestion` | `Future<Result<PaperQuestion, GrpcError>> regenerateQuestion({required String school, required String exam, required int subject, int? paper, required int grade, required String paperQuestionId, required int topicId, required int marks, required String accessToken})` | Regenerate a single question. |
| `editPaperQuestion` | `Future<Result<PaperQuestion, GrpcError>> editPaperQuestion({required String school, required String exam, required int subject, int? paper, required String paperQuestionId, required String text, required int marks, required List<RubricCriterion> rubric, required String accessToken})` | Edit a question on the generated paper. |
| `finalizePaper` | `Future<Result<PaperPdf, GrpcError>> finalizePaper({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required List<String> paperQuestionIds, required String accessToken})` | Finalize the paper and generate PDF. |
| `getPaperPdf` | `Future<Result<PaperPdf, GrpcError>> getPaperPdf({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required String accessToken})` | Get the PDF URL for a finalized paper. |

Each method maps domain models → proto request, calls gRPC, maps proto response → domain model.

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "<type>: <description>"`

---

### Task 05: Create MarkingStatusService — poll marking status + per-question grades ✅
**Files to create/modify:** `lib/services/question_bank.dart` (extend with marking status methods)
**Context files to read (if needed):** `lib/services/CONTEXT.md`
**Depends on:** Task 03
**Parallel group:** P3b

**Specification:**

Add marking/results methods to `QuestionBankService`:

| Method | Signature | Description |
|---|---|---|
| `getMarkingStatus` | `Future<Result<MarkingStatus, GrpcError>> getMarkingStatus({required String school, required String exam, required int subject, int? paper, required int grade, int? stream, required String accessToken})` | Get current marking job status. |
| `getQuestionGrades` | `Future<Result<List<QuestionGradeDetail>, GrpcError>> getQuestionGrades({required String school, required String exam, required int student, required int subject, int? paper, required String accessToken})` | Get per-question grade breakdown for a student. |

Also add a convenience method for polling:

```dart
/// Polls marking status every [interval] until complete or failed.
/// Yields each status update to the caller.
Stream<MarkingStatus> watchMarkingStatus({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? stream,
  required String accessToken,
  Duration interval = const Duration(seconds: 3),
}) async* {
  while (true) {
    final result = await getMarkingStatus(
      school: school, exam: exam, subject: subject, paper: paper,
      grade: grade, stream: stream, accessToken: accessToken,
    );
    switch (result) {
      case Ok(:final value):
        yield value;
        if (value.phase == MarkingPhase.complete ||
            value.phase == MarkingPhase.failed) return;
      case Err(:final error):
        yield MarkingStatus(
          phase: MarkingPhase.failed, progressCurrent: 0,
          progressTotal: 0, errorMessage: error.message,
        );
        return;
    }
    await Future.delayed(interval);
  }
}
```

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "<type>: <description>"`

---

### Task 06: Register QuestionBankService on Client ✅
**Files to modify:** `lib/client.dart`
**Context files to read (if needed):** `lib/client.dart` (lines 111–145 for existing pattern)
**Depends on:** Task 03
**Parallel group:** P3c

**Specification:**

Wire `QuestionBankService` into `Client` following the same pattern as `aiMarking`:

1. Add import: `import 'services/question_bank.dart';`
2. Add late field in `Client` class (next to `aiMarking` around line 134):
   ```dart
   late final questionBank = QuestionBankService(
     channel: _channel,
     host: kDomain,
     port: kPort,
   );
   ```
3. Add a global accessor (optional, for convenience from UI code):
   ```dart
   // In the globals section at the top of client.dart, after `get sync`:
   QuestionBankService get questionBankService => client.questionBank;
   ```

No changes to `initializeClient()` needed — the `late final` lazy-initializes on first access.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: register QuestionBankService on Client"`

---

## Track 4: System Dashboard — Question Management UI

### Task 07: Add "Questions" tab/panel to topic expanded content in SubjectsSection ✅
**Files to modify:** `lib/ui/screens/system/settings/subjects_section.dart`
**Context files to read (if needed):** `lib/ui/screens/system/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`
**Depends on:** Task 06
**Parallel group:** P4

**Specification:**

Currently, each `_TopicTile` expands to show `_TopicExpandedContent` (lines 1309–1389) which shows basic topic info. Modify this to include a question management panel:

1. In `_TopicExpandedContent.build()`, add a new section below the existing content:
   - A header row: "Questions" label + question count badge + "Add" button (if user has `Subjects.create` permission)
   - The count is fetched via `questionBankService.listQuestions(topicId: topic.id, limit: 1)` to get the total count (we only need the `total` field)
   - The "Add" button opens `_CreateQuestionSheet` (Task 08)
   - Below, a "View all questions" row that navigates to a full-page `QuestionsListPage` (Task 09)
   - A "Bulk import" row that opens `_BulkImportSheet` (Task 10)

2. Add a `FutureBuilder` for the question count, with a shimmer placeholder while loading and "—" on error.

3. Style: Use existing `_TinyAction` pattern for action buttons. Question count displayed as a small badge (AppTheme.kChipRadius, `cs.primaryContainer` background).

**Key imports needed:**
- `'../../../../client.dart'` (for `questionBankService`, `accessToken`)
- `'../../../../models/question.dart'`

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

### Task 08: Single question creation form (CreateQuestionSheet) ✅
**Files to create:** `lib/ui/screens/system/settings/create_question_sheet.dart`
**Context files to read (if needed):** `lib/ui/widgets/edu_sheet.dart`, `lib/ui/widgets/animated_save_button.dart`, `lib/ui/screens/system/settings/subjects_section.dart` (for `_CreateTopicSheet` pattern)
**Depends on:** Task 06
**Parallel group:** P4

**Specification:**

Create a bottom sheet / desktop dialog (via `showEduSheet`) for creating a single question under a topic.

**Widget:** `CreateQuestionSheet` (StatefulWidget)

**Constructor:**
```dart
const CreateQuestionSheet({
  required this.topicId,
  required this.topicName,
  required this.subjectName,
  required this.grade,
});
```

**Form fields:**

1. **Question text** — multiline `TextField` with min 3 lines, max unlimited. Label: "Question text". Hint: "Enter the question text..."
2. **Marks** — integer `TextField` with `TextInputType.number`. Label: "Total marks". Width: 80px inline.
3. **Rubric criteria** — dynamic list:
   - Each row: criterion `TextField` (expanded) + marks `TextField` (width: 60px) + remove `IconButton` (trash icon, 28×28)
   - "Add criterion" button below the list (dashed border row, `+` icon)
   - **Validation:** Sum of all rubric marks must equal the total marks field. Show error banner if mismatch.
4. **Example answer** — optional multiline `TextField`. Label: "Example answer (optional)". Collapsed by default, expandable via "Add example answer" link.
5. **Image references** — for now, a simple text-based entry (image upload will be a follow-up). Each image entry has:
   - Context dropdown: Question / Rubric / Example Answer
   - Filename `TextField`
   - Caption `TextField` (optional)
   - Description `TextField` (multiline)
   - Add/remove rows

**Submit flow:**
1. Validate all fields.
2. Call `questionBankService.createQuestion(...)` with `accessToken` from global.
3. Show loading spinner on submit button (use `AnimatedSaveButton` or similar pattern).
4. On success: pop sheet, show SnackBar "Question created".
5. On error: show `_ErrorBanner` with error message.

**UI design rules:**
- Wrap in `EduSheet(title: 'New Question', child: ...)` for mobile, auto-handled by `showEduSheet` for desktop.
- Internal padding: 12–16px.
- Body text: w300/w400. Labels: w500.
- Rubric rows separated by `AppTheme.tableRowDivider`.
- Submit button: green checkmark icon button (28×28) when form is valid + dirty.

**Update after completion:**
- [x] Update `lib/ui/screens/system/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "ui: create CreateQuestionSheet for single question creation"`

---

### Task 09: Questions list page (full-page question browser) ✅
**Files to create:** `lib/ui/screens/system/settings/questions_list_page.dart`
**Context files to read (if needed):** `lib/ui/screens/system/settings/subjects_section.dart` (for navigation/style patterns)
**Depends on:** Task 06, Task 08
**Parallel group:** P4b

**Specification:**

Full-page screen showing all questions for a given topic with paginated loading.

**Widget:** `QuestionsListPage` (StatefulWidget)

**Constructor:**
```dart
const QuestionsListPage({
  required this.topicId,
  required this.topicName,
  required this.subjectName,
  required this.grade,
  required this.canEdit,
  required this.canDelete,
  required this.canCreate,
});
```

**Layout:**

1. **AppBar:** Back chevron (`Icons.chevron_left_rounded`), title: "{subjectName} › {topicName}" (w400, 17px), trailing "+" icon button to create question (opens `CreateQuestionSheet`).

2. **Body:** Scrollable list of question rows in data-table style:
   - Each row: question text (truncated to 2 lines, w300, 13px) | marks badge (small pill, `AppTheme.kChipRadius`) | rubric count badge | action buttons
   - Rows separated by `AppTheme.tableRowDivider`
   - Row height: 56–64px with subtitle
   - Desktop (≥600px): inline icon buttons for edit (pencil) and delete (trash)
   - Mobile (<600px): `Icons.more_vert` → bottom sheet with actions

3. **Pagination:** Load 50 questions at a time. "Load more" button at bottom, or infinite scroll.

4. **Empty state:** `EduEmptyState` with book icon: "No questions yet. Add questions manually or import from JSON."

5. **Question detail expansion:** Tapping a row expands it inline (animated, like `_TopicTile` pattern) to show:
   - Full question text
   - Rubric criteria list (criterion + marks, data-table style)
   - Example answer (if present)
   - Image references (filename + context badge)

6. **Edit action:** Opens an `_EditQuestionSheet` (similar to `CreateQuestionSheet` but pre-filled, calls `updateQuestion`).

7. **Delete action:** `EduConfirmDialog` → calls `deleteQuestion` → removes from list → SnackBar.

**Data fetching:** `questionBankService.listQuestions(topicId: topicId, offset: 0, limit: 50, accessToken: accessToken)` — returns `(List<Question>, int total)`. Store in local state, re-fetch on create/edit/delete.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

### Task 10: Bulk import sheet ✅
**Files to create:** `lib/ui/screens/system/settings/bulk_import_sheet.dart`
**Context files to read (if needed):** `lib/ui/widgets/edu_sheet.dart`, `eduxal/topic.json` (for expected format), `eduxal/question_generation_instructions.md`
**Depends on:** Task 06
**Parallel group:** P4

**Specification:**

Bottom sheet / dialog for bulk-importing questions from a topic.json file.

**Widget:** `BulkImportSheet` (StatefulWidget)

**Constructor:**
```dart
const BulkImportSheet({
  required this.topicId,
  required this.topicName,
  required this.subjectName,
});
```

**Layout:**

1. **Header:** `EduSheet(title: 'Bulk Import Questions', ...)`

2. **Input area:** A large multiline `TextField` (min 10 lines, scrollable) where the user pastes the topic.json content. Placeholder hint shows truncated example of the JSON format.

3. **OR file picker:** A row below the text field: "Or pick a .json file" with a file icon button. On tap, opens file picker (use `dart:io` `FilePicker` or a simple `showOpenPanel`). On pick, loads file contents into the text field.

4. **Validate button:** Before submitting, a "Validate" text button that:
   - Parses the JSON locally
   - Checks required fields exist (`questions` array, each with `text`, `marks`, `rubric`)
   - Checks rubric marks sum = question marks for each question
   - Shows validation results inline: "✓ 12 questions found, all valid" or "✗ Question 3: rubric marks (5) ≠ question marks (4)"

5. **Import button:** Enabled only after validation passes. Calls `questionBankService.bulkImport(jsonContent: ..., accessToken: ...)`.

6. **Results display:** After import completes:
   - Success: "✓ {N} questions created" in green
   - Partial: "{N} created, {M} errors:" followed by error list (index + message)
   - Full failure: red error banner

**UI design:**
- Text field uses monospace font (for JSON readability): `TextStyle(fontFamily: 'monospace', fontSize: 12)`
- Validation results in a bordered container with `AppTheme.nestedBg`
- Import button uses `AnimatedActionButton` pattern (scale animation, loading spinner)

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

## Track 5: Teacher Paper Generation UI

### Task 11: Paper generation entry point — "Generate Paper" button on PaperDetailPage ✅
**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** Task 06
**Parallel group:** P5

**Specification:**

Add a "Generate Paper" action to the paper detail page header (`_PaperHeader`).

**Changes to `_PaperHeader`:**

1. Add a new action button in the header's action row (near the existing status progression button, around the `_buildActionButton` method area at ~line 1260):
   - Icon: `Icons.auto_awesome_rounded` (consistent with the timetable generate lessons FAB)
   - Tooltip: "Generate Paper"
   - Visible when: paper status is `PaperStatus.pending` AND user has `canProgressStatus` permission
   - Colour: `AppTheme.brandIndigo` (or `cs.primary`)
   - Size: 28×28 icon button

2. On tap, navigate to `PaperGenerationPage` (Task 12) via `Navigator.push`.

3. Also add a "Print Paper" button:
   - Icon: `Icons.print_rounded`
   - Tooltip: "Print Paper"
   - Visible when: paper status is `PaperStatus.done` or `PaperStatus.marked` (paper has been finalized)
   - On tap: calls `getPaperPdf` and opens the PDF (Task 15)

**Pass through to PaperGenerationPage:**
- `schoolId`, `exam` (ExamWithPapers), `paper` (Paper), `grade`, `stream`, `subjectNames`, `accessToken`

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "ui: add generate paper and print/download PDF buttons to paper detail page"`

---

### Task 12: Paper generation page — topic allocation step ✅
**Files to create:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/database/daos/catalog_dao.dart` (for topic queries), `lib/database/tables/topics.dart`
**Depends on:** Task 06, Task 11
**Parallel group:** P5

**Specification:**

Full-page screen for the paper generation flow. This is a multi-step wizard:
- **Step 1:** Topic mark allocation
- **Step 2:** Review & edit generated questions (Task 13)
- **Step 3:** Finalize (Task 14)

This task covers Step 1.

**Widget:** `PaperGenerationPage` (StatefulWidget)

**Constructor:**
```dart
const PaperGenerationPage({
  required this.schoolId,
  required this.exam,
  required this.paper,
  required this.grade,
  required this.subjectNames,
  required this.schoolContext,
});
```

**Step 1 layout:**

1. **AppBar:** Back chevron, title: "Generate Paper" (w400, 17px), step indicator dots (●○○)

2. **Total marks input:** A prominent row at top:
   - Label: "Total marks"
   - `TextField` with `TextInputType.number`, default value from paper's existing total or 80
   - Width: 100px, centered

3. **Topic allocation list:**
   - Query topics for this subject + grade from local Drift: `catalogDao.watchTopicsBySubjectAndGrade(subjectId, grade)` → `Stream<List<Topic>>`
   - For each topic, show a row:
     - Topic name (w400, 14px)
     - Marks input `TextField` (width: 60px, `TextInputType.number`)
   - Rows in data-table style separated by `AppTheme.tableRowDivider`
   - Row height: 48px

4. **Running total:** Sticky footer showing:
   - "Allocated: {sum} / {total}" with colour coding:
     - Green when sum == total
     - Red when sum > total
     - Amber when sum < total
   - "Generate" button — enabled only when sum == total AND total > 0
   - Button uses `AnimatedActionButton` pattern (scale 0.95→1.0, loading spinner)

5. **On "Generate" tap:**
   - Build `List<TopicAllocation>` from non-zero topic marks
   - Call `questionBankService.generatePaper(...)`
   - On success: transition to Step 2 (store `List<PaperQuestion>` in page state)
   - On error: show SnackBar with error
   - Show loading state: disable all inputs, show progress indicator

**Data source for topics:** The `topics` table IS in the local Drift database (it's a synced table). Use `catalogDao.watchTopicsBySubjectAndGrade(paper.subject, grade)` to get the list reactively.

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "ui: create PaperGenerationPage with topic allocation step"`

---

### Task 13: Paper generation page — question review step ✅
**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** `lib/models/paper_generation.dart`
**Depends on:** Task 12
**Parallel group:** P5b

**Specification:**

Step 2 of the paper generation wizard: reviewing and editing generated questions.

**Step 2 layout:**

1. **AppBar:** Back chevron (goes to Step 1), title: "Review Questions" (w400, 17px), step indicator dots (○●○)

2. **Question list:** Scrollable list of `PaperQuestion` items, each in a card-like container:
   - **Question header row:** "Q{order}." label + marks badge (pill, `AppTheme.kChipRadius`) + action icons
   - **Question text:** Full text displayed (w300, 14px), with line breaks rendered
   - **Rubric section:** Collapsible, shows criteria list (criterion + marks)
   - **Images:** If any, show filename + context badge (tiny pills: "Question"/"Rubric"/"Answer")
   - **Action buttons (inline, 28×28):**
     - 🔄 Regenerate (`Icons.refresh_rounded`) — calls `regenerateQuestion`, replaces this item in the list with the response
     - ✏️ Edit (`Icons.edit_outlined`) — opens inline edit mode (Task 13a below)

3. **Inline edit mode** (for a single question):
   - Question text becomes an editable `TextField`
   - Marks becomes editable
   - Rubric criteria become editable (same dynamic list pattern as `CreateQuestionSheet`)
   - "Save" button (green check) calls `editPaperQuestion`, updates the item in the list
   - "Cancel" button (x) reverts to display mode

4. **Regenerate flow:**
   - On tap, show a small loading shimmer on the question card
   - Call `questionBankService.regenerateQuestion(...)` with the topic_id and marks from the current question
   - On success: animate the card replacement (fade out old → fade in new)
   - On error: SnackBar

5. **Footer:** "Finalize" button — always visible, enabled when at least 1 question exists. On tap → goes to Step 3 (Task 14).

**State management:** The `List<PaperQuestion>` is held in `_PaperGenerationPageState`. Edits/regenerations mutate this list in place and call `setState`.

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "ui: implement paper generation review step with regenerate and inline edit"`

---

### Task 14: Paper generation page — finalize step ✅
**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** `lib/models/paper_generation.dart`
**Depends on:** Task 13
**Parallel group:** P5c

**Specification:**

Step 3 of the paper generation wizard: finalization and PDF.

**Step 3 layout:**

1. **AppBar:** Back chevron (goes to Step 2), title: "Finalize Paper", step indicator dots (○○●)

2. **Summary view:** Read-only summary of the paper:
   - Total questions: N
   - Total marks: M
   - Subject name + grade label
   - Compact list of questions (just "Q1: {truncated text} ({marks}m)")

3. **Finalize button:** Prominent centered button:
   - Label: "Finalize & Generate PDF"
   - Uses `AnimatedActionButton` with loading spinner
   - On tap: calls `questionBankService.finalizePaper(...)` with all `paperQuestionIds`
   - On success: shows the PDF result area (below)
   - On error: SnackBar with error message

4. **PDF result area** (visible after successful finalization):
   - "Paper generated successfully!" message with green checkmark
   - "Download PDF" button — downloads the PDF from `pdfUrl` to local storage
   - "Print" button — opens print flow (Task 15)
   - "Done" button — pops back to paper detail page

5. **Post-finalization:** The paper detail page should refresh (the paper status may have been updated by the server via the sync delta stream).

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "ui: implement paper generation finalize step with PDF download"`

---

## Track 6: Print Paper

### Task 15: Print/download paper PDF functionality ✅
**Files to create:** `lib/ui/screens/school_dashboard/academics/paper_pdf_viewer.dart`
**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` (wire print button)
**Context files to read (if needed):** `eduxal/pubspec.yaml`
**Depends on:** Task 04, Task 06
**Parallel group:** P6

**Specification:**

Implement PDF download and print for finalized papers.

**Approach:** Use `dart:io` `HttpClient` to download the PDF from the presigned URL returned by `getPaperPdf`, save to a temp file, then open with the system PDF viewer via `open_file` or `url_launcher`. For printing, research the best approach for the target platforms:

- **Option A (recommended):** Download PDF to temp directory → open with system viewer → user prints from there. This is the simplest cross-platform approach.
- **Option B:** Use the `printing` Flutter package for in-app print preview. This requires adding `printing` to `pubspec.yaml`.

**Implementation:**

1. **`_downloadAndOpenPdf` helper** (in `paper_pdf_viewer.dart`):
   ```dart
   Future<void> downloadAndOpenPdf({
     required String school,
     required String exam,
     required int subject,
     int? paper,
     required int grade,
     int? stream,
     required String accessToken,
     required BuildContext context,
   }) async {
     // 1. Call questionBankService.getPaperPdf(...)
     // 2. Download PDF from pdfUrl using HttpClient
     // 3. Save to temp directory: path_provider getTemporaryDirectory()
     // 4. Open file with system viewer (Process.run on desktop, url_launcher on mobile)
     // 5. Show loading overlay while downloading
   }
   ```

2. **Wire into `_PaperHeader`:** The "Print" button (added in Task 11) calls this function.

3. **Wire into `PaperGenerationPage` Step 3:** The "Print" and "Download" buttons call this function.

4. **Loading state:** Show a small `CircularProgressIndicator(strokeWidth: 1.5)` on the button while downloading.

5. **Error handling:** SnackBar with "Failed to download PDF: {error}".

**Note:** Do NOT add any new pub dependencies without confirming they are compatible. If `printing` is used, add it to `pubspec.yaml`:
```yaml
printing: ^5.13.0
```

**Update after completion:**
- [x] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "ui: add generate paper and print/download PDF buttons to paper detail page"`

---

## Track 7: Marking Status Feedback UI

### Task 16: Marking status widget for paper detail page ✅
**Files to create:** `lib/ui/widgets/marking_status_indicator.dart`
**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/models/marking_status.dart`, `lib/ui/widgets/thin_progress_bar.dart`
**Depends on:** Task 05, Task 06
**Parallel group:** P7

**Specification:**

Create a reusable widget that shows real-time marking status and integrate it into the paper detail page.

**Widget:** `MarkingStatusIndicator` (StatefulWidget)

**Constructor:**
```dart
const MarkingStatusIndicator({
  required this.school,
  required this.exam,
  required this.subject,
  this.paper,
  required this.grade,
  this.stream,
  this.onComplete,
  this.onRetry,
});
```

**Behaviour:**
1. On `initState`, starts polling via `questionBankService.watchMarkingStatus(...)` stream.
2. Renders different UI based on `MarkingPhase`:

   - **queued:** Pulsing dot (amber) + "Queued for marking..." text
   - **downloading:** Small progress bar (indeterminate) + "Downloading answer images..."
   - **marking:** Determinate progress bar + "Marking ({current}/{total} students)..." text + percentage
   - **computing:** Indeterminate progress bar + "Computing results..."
   - **complete:** Green checkmark icon + "Marking complete" text. Calls `onComplete` callback. Auto-hides after 3 seconds.
   - **failed:** Red error icon + error message + "Retry" button (calls `onRetry` callback)

3. **Visual style:**
   - Compact: max height 36px, horizontal layout
   - Progress bar uses `ThinProgressBar` pattern (existing widget) or a custom `LinearProgressIndicator(minHeight: 2)`
   - Text: w300, 12px, `cs.onSurfaceVariant`
   - Pulsing dot animation: scale 0.8→1.2, 800ms, infinite repeat
   - Integrates with existing `_ArcProgressPainter` pattern in paper_detail_page for the arc-based indicator

4. **Disposal:** Cancel the stream subscription on dispose.

**Integration into `_PaperHeader`:**

1. Add a `_markingStatus` field to `_PaperHeaderState` (or `_PaperDetailPageState`).
2. When AI marking is triggered (existing `_runAiMarking` flow completes the upload+markPaper call), start showing `MarkingStatusIndicator` below the header stats row.
3. The indicator appears between the header and the grade spreadsheet/list.
4. On `onComplete`: refresh the grades stream (it should auto-refresh via Drift watch, but if grades come via `watchChanges` delta, we may need a manual re-query). Also, set `_aiPhase = _AiPhase.idle`.
5. On `onRetry`: call `_runAiMarking()` again.

**Visibility condition:** Show the `MarkingStatusIndicator` when:
- `_aiPhase != _AiPhase.idle` (marking was recently triggered), OR
- The paper status is `PaperStatus.progress` (server is marking)

**Update after completion:**
- [ ] Update `lib/ui/widgets/CONTEXT.md`
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

## Track 8: Per-Question Results View

### Task 17: Question grade breakdown sheet ✅
**Files to create:** `lib/ui/screens/school_dashboard/academics/question_grades_sheet.dart`
**Context files to read (if needed):** `lib/models/question_grade.dart`, `lib/ui/widgets/edu_sheet.dart`
**Depends on:** Task 05, Task 06
**Parallel group:** P8

**Specification:**

A bottom sheet / desktop dialog showing per-question AI marking breakdown for a student's paper.

**Widget:** `QuestionGradesSheet` (StatefulWidget)

**Constructor:**
```dart
const QuestionGradesSheet({
  required this.school,
  required this.exam,
  required this.student,
  required this.subject,
  this.paper,
  required this.studentName,
  required this.overallScore,
  required this.totalMarks,
});
```

**Layout:**

1. **Header (via EduSheet):** Title: "Marking Breakdown — {studentName}"

2. **Overall score bar:** At top, a visual summary:
   - Score: "{overallScore} / {totalMarks}" in large text (w500, 20px)
   - Percentage badge (colour-coded via `_pctColor` from existing paper_detail_page helpers)
   - Thin horizontal score bar (fill = score/total, colour-coded)

3. **Question list:** Fetched via `questionBankService.getQuestionGrades(...)`. Shows a `FutureBuilder`:
   - **Loading:** Shimmer placeholder rows
   - **Error:** Error banner with retry button
   - **Data:** List of `QuestionGradeDetail` cards:

   Each question card:
   - **Header:** "Q{n}" label + marks badge ("{marksAwarded}/{totalMarks}") + feedback icon
   - **Question text:** Truncated to 3 lines, expandable on tap
   - **AI feedback:** Italic text block (w300, 13px) showing the AI's reasoning
   - **Rubric results:** Data-table style list of criteria:
     - Each row: ✓/✗ icon (green/red) + criterion text + "{awarded}/{available}" marks
     - Rows separated by thin divider
     - Satisfied criteria: green tint on the icon
     - Unsatisfied criteria: red tint on the icon

4. **Empty state:** "No marking breakdown available." (shouldn't happen if called correctly)

**Data fetching:** On `initState`, call `questionBankService.getQuestionGrades(...)`. Store result in local state.

**UI design:**
- Cards separated by 8px gap (not dividers — these are distinct logical blocks)
- Each card has `AppTheme.nestedBg` background with `AppTheme.kCardRadius` corners
- Internal padding: 12px
- Rubric result icons: `Icons.check_circle_rounded` (green) / `Icons.cancel_rounded` (red), size 16

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

### Task 18: Wire "View Breakdown" button into grade spreadsheet/list rows ✅
**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/academics/question_grades_sheet.dart`
**Depends on:** Task 17
**Parallel group:** P8b

**Specification:**

Add a "View Breakdown" action to each student row in both `_GradeSpreadsheet` and `_GradeList` on the paper detail page.

**Changes to `_SpreadsheetRow` (desktop, ~line 2383):**

1. Add a small icon button after the score input:
   - Icon: `Icons.analytics_outlined` (size 16)
   - Tooltip: "View marking breakdown"
   - Visible when: the student has a grade AND the paper is marked (status == `PaperStatus.marked`)
   - On tap: `showEduSheet(context: context, builder: (ctx) => QuestionGradesSheet(...))`
   - Size: 24×24 inline icon button

**Changes to `_GradeList` mobile rows (~line 2688):**

1. In the mobile action sheet (`_openStudentActionSheet`), add a new row:
   - Icon: `Icons.analytics_outlined`
   - Label: "Marking breakdown"
   - Visible when: student has a grade AND paper status is marked
   - On tap: pop action sheet, then `showEduSheet(context: context, builder: (ctx) => QuestionGradesSheet(...))`

2. Alternatively, in the grade entry/display tile itself, add a small "breakdown" link text that opens the sheet.

**Props to pass to `QuestionGradesSheet`:**
- `school`: from paper
- `exam`: from exam.id
- `student`: student.adm
- `subject`: paper.subject
- `paper`: paper.paper (nullable)
- `studentName`: student.name
- `overallScore`: grade.score (from gradeMap)
- `totalMarks`: grade.total (from gradeMap)

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

## Track 9: Cleanup & Polish

### Task 19: Add question count badge to topic tiles in system settings ✅
**Files to modify:** `lib/ui/screens/system/settings/subjects_section.dart`
**Context files to read (if needed):** None
**Depends on:** Task 07
**Parallel group:** P9

**Specification:**

Enhance the `_TopicTile` widget (~line 1085) to show a question count badge next to the topic name.

1. In `_TopicTileState`, add a `_questionCount` field (int?, initially null).
2. In `initState`, fire-and-forget a call to `questionBankService.listQuestions(topicId: widget.topic.id, limit: 1, accessToken: accessToken)` to get just the total count.
3. Display the count as a small badge next to the topic name:
   - Style: `AppTheme.kChipRadius` border radius, `cs.primaryContainer` background, 11px text
   - Content: "{count} Qs"
   - Show shimmer placeholder while loading (width 30, height 14, rounded)
   - Show nothing on error

4. Refresh the count when the expanded panel's create/import actions complete (pass a callback that re-fetches the count).

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "ui: add question count badge to topic tiles in system settings"`

---

### Task 20: Update CONTEXT.md files for all tracks
**Files to modify:** `lib/proto/CONTEXT.md`, `lib/services/CONTEXT.md`, `lib/models/CONTEXT.md`, `lib/ui/screens/system/CONTEXT.md`, `lib/ui/screens/school_dashboard/CONTEXT.md`, `lib/ui/widgets/CONTEXT.md`
**Context files to read (if needed):** All CONTEXT.md files
**Depends on:** Tasks 01–19
**Parallel group:** P10 (run last)

**Specification:**

Final pass to ensure all CONTEXT.md files accurately reflect the new files, exports, methods, and dependencies added by the question bank feature. Each must include:

1. **`lib/proto/CONTEXT.md`:** Add `services/question_bank.pbgrpc.dart` section listing the `QuestionBankClient` with all 14 RPCs and key message types.

2. **`lib/services/CONTEXT.md`:** Add `QuestionBankService` section with method signatures table, constructor, and dependencies.

3. **`lib/models/CONTEXT.md`:** Add entries for `question.dart`, `paper_generation.dart`, `marking_status.dart`, `question_grade.dart` with key types and exports.

4. **`lib/ui/screens/system/CONTEXT.md`:** Add entries for `settings/create_question_sheet.dart`, `settings/questions_list_page.dart`, `settings/bulk_import_sheet.dart`.

5. **`lib/ui/screens/school_dashboard/CONTEXT.md`:** Add entry for `academics/paper_generation_page.dart`, `academics/paper_pdf_viewer.dart`, `academics/question_grades_sheet.dart`. Update `academics/paper_detail_page.dart` entry with new buttons and marking status integration.

6. **`lib/ui/widgets/CONTEXT.md`:** Add entry for `marking_status_indicator.dart`.

7. Each CONTEXT.md must have its `## Last Updated` line updated to reference this task.

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "<type>: <description>"`

---

## Dependency Graph Summary

```
Task 01 (proto gen)
  ├─► Task 02 (domain models) ──► Task 03 (service: CRUD)
  │                                  ├─► Task 04 (service: paper gen)
  │                                  ├─► Task 05 (service: marking status)
  │                                  └─► Task 06 (register on Client)
  │                                       ├─► Task 07 (topic expanded content) ──► Task 19 (count badges)
  │                                       ├─► Task 08 (create question sheet)
  │                                       ├─► Task 09 (questions list page) [depends: 08]
  │                                       ├─► Task 10 (bulk import sheet)
  │                                       ├─► Task 11 (paper detail buttons) ──► Task 12 (gen step 1) ──► Task 13 (gen step 2) ──► Task 14 (gen step 3)
  │                                       ├─► Task 15 (print/download PDF)
  │                                       ├─► Task 16 (marking status widget) [depends: 05]
  │                                       ├─► Task 17 (question grades sheet) [depends: 05]
  │                                       └─► Task 18 (wire breakdown button) [depends: 17]
  └─► Task 20 (CONTEXT.md updates) [depends: all]
```

## Parallel Execution Groups

| Group | Tasks | Notes |
|---|---|---|
| P1 | 01 | Proto generation — blocks everything |
| P2 | 02 | Domain models — blocks services |
| P3 | 03 | Core service — blocks everything downstream |
| P3b | 04, 05 | Service extensions — can run in parallel |
| P3c | 06 | Client registration — quick, blocks all UI |
| P4 | 07, 08, 10 | System dashboard UI — can run in parallel (different files) |
| P4b | 09 | Questions list — depends on 08 for the sheet import |
| P5 | 11, 12 | Paper gen entry + step 1 — sequential dependency |
| P5b | 13 | Paper gen step 2 — depends on 12 |
| P5c | 14 | Paper gen step 3 — depends on 13 |
| P6 | 15 | Print — independent once 06 done |
| P7 | 16 | Marking status — depends on 05 |
| P8 | 17 | Question grades sheet — depends on 05 |
| P8b | 18 | Wire breakdown button — depends on 17 |
| P9 | 19 | Polish — depends on 07 |
| P10 | 20 | CONTEXT updates — run last |