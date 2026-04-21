# TASKS.md

## Paper Generation Bug Fixes & Improvements

---

### [x] Task 01: Fix error display, loading UX, and callback leak in paper generation wizard

**Files to create/modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Three separate fixes in `paper_generation_page.dart`, all within
`_PaperGenerationPageState`:

---

**Fix A — Replace SnackBar error with an inline error banner**

**Problem:** When `generatePaper` fails, the raw gRPC message "nothing to update"
is shown in a full-width SnackBar that looks like a button rather than an error,
and doesn't communicate the actual problem to the user.

**Solution:** Store the error in state and render an inline error banner — the same
pattern already used in `school_settings_screen.dart` and `mpesa_config_screen.dart`
(`_ErrorBanner` widget with `cs.errorContainer` background).

**Step A1 — Add `_generateError` state field**

In `_PaperGenerationPageState`, add a nullable field alongside the other state fields:

```dart
String? _generateError;
```

**Step A2 — Add `_friendlyGenerateError` helper method**

Add this private method to `_PaperGenerationPageState`:

```dart
String _friendlyGenerateError(GrpcError e) {
  final msg = e.message?.toLowerCase() ?? '';
  if (e.code == StatusCode.failedPrecondition ||
      msg.contains('nothing to update') ||
      msg.contains('not enough question')) {
    return 'Not enough questions in the bank to fill the requested marks. '
        'Try a smaller total, or contact the system admin to add more '
        'questions for this subject and grade.';
  }
  if (e.code == StatusCode.notFound) {
    return 'Subject, exam, or topic not found. Please refresh and try again.';
  }
  if (e.code == StatusCode.unauthenticated) {
    return 'Your session has expired. Please log in again.';
  }
  return e.message ?? 'Failed to generate paper. Please try again.';
}
```

`StatusCode` lives in `package:grpc/grpc.dart` — check the existing imports.
`GrpcError` is already imported so the grpc package is available.

**Step A3 — Update `_generate()` to use the new state field**

In `_generate()`, in the `Err` case, replace the SnackBar call:

```dart
// REMOVE this:
case Err(error: final e):
  setState(() => _isGenerating = false);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(e.message ?? 'Failed to generate paper'),
        behavior: SnackBarBehavior.floating,
      ),
    );
```

With:

```dart
// REPLACE with:
case Err(error: final e):
  setState(() {
    _isGenerating = false;
    _generateError = _friendlyGenerateError(e);
  });
```

Also clear the error at the top of `_generate()`, right after the guard checks,
before `setState(() => _isGenerating = true)`:

```dart
Future<void> _generate() async {
  if (!_canGenerate) return;

  final nonZero = _allocations.where((a) => a.marks > 0).toList();
  if (nonZero.isEmpty) return;

  // Clear any previous error before starting a new attempt.
  setState(() {
    _isGenerating = true;
    _generateError = null;   // ← add this
  });

  // ... rest of method unchanged
```

**Step A4 — Add a private `_GenerationErrorBanner` widget at the bottom of the file**

Add this private widget after the existing private widget classes (e.g. after
`_MiniIconButton` or at the end of the file):

```dart
/// Inline error banner for paper generation failures.
/// Styled to match the app's established _ErrorBanner pattern.
class _GenerationErrorBanner extends StatelessWidget {
  const _GenerationErrorBanner({required this.message, required this.cs});

  final String message;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step A5 — Render the banner in `_buildAllocationStep`**

In `_buildAllocationStep`, the method returns a `Column` whose last child is the
`_AllocationFooter`. Insert the banner *between* the `Expanded` topic list and
the `_AllocationFooter`:

```dart
// Inside the Column in _buildAllocationStep, after the Expanded(...) topic list:

// ── Inline error banner (shown after a failed generation attempt) ──
if (_generateError != null)
  _GenerationErrorBanner(message: _generateError!, cs: cs),

// ── Sticky footer ──
_AllocationFooter(
  // ... unchanged
),
```

---

**Fix B — Loading overlay during generation**

When `_isGenerating = true`, only the footer button shows a spinner. The topic
list appears frozen and the user thinks nothing is happening.

In `_buildAllocationStep`, wrap the `Expanded` child (the `StreamBuilder`) in a
`Stack` so a loading overlay can be shown on top while generating:

```dart
// Replace:
Expanded(
  child: StreamBuilder<List<Topic>>(...),
),

// With:
Expanded(
  child: Stack(
    children: [
      StreamBuilder<List<Topic>>(
        // ... existing StreamBuilder completely unchanged inside here ...
      ),
      // Loading overlay — shown while generating
      if (_isGenerating)
        Positioned.fill(
          child: Container(
            color: Theme.of(context)
                .colorScheme
                .surface
                .withValues(alpha: 0.75),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Generating questions…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  ),
),
```

---

**Fix C — Stop `addPostFrameCallback` from accumulating on every stream rebuild**

**Problem:** Inside the `StreamBuilder` builder in `_buildAllocationStep`, this
code runs on every stream event:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final needsSync = ...;
  if (needsSync) {
    setState(() => _syncAllocations(topics));
  } else if (_allocations.isEmpty && topics.isNotEmpty) {
    setState(() => _syncAllocations(topics));
  }
});
```

Each stream rebuild adds a new callback to the queue — they accumulate
indefinitely.

**Fix:** Add a field to `_PaperGenerationPageState` to track the last synced topic list:

```dart
List<Topic> _lastSyncedTopics = [];
```

Then inside the `StreamBuilder` builder, replace the `addPostFrameCallback` block
and the "First render — sync immediately" block below it with:

```dart
// Only schedule a sync when the topic list actually changed.
final topicsChanged =
    topics.length != _lastSyncedTopics.length ||
    topics.any((t) => !_lastSyncedTopics.any((l) => l.id == t.id));

if (topicsChanged) {
  _lastSyncedTopics = List.of(topics);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    setState(() => _syncAllocations(topics));
  });
}
```

Remove the old block that immediately called `_syncAllocations` without
`addPostFrameCallback` (the `if (_allocations.length != topics.length)` guard
below the callback block) — the new `topicsChanged` check above covers it.

---

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — note that `paper_generation_page.dart` now has `_generateError` state field, `_friendlyGenerateError` helper, `_GenerationErrorBanner` widget, loading overlay in allocation step, and topic-sync callback guard
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "fix: inline error banner, loading overlay, callback leak in paper wizard"`

---

### [x] Task 02: Fix mobile PDF sharing in paper_pdf_viewer.dart

**Files to create/modify:**
- `lib/ui/screens/school_dashboard/academics/paper_pdf_viewer.dart`
- `pubspec.yaml`

**Context files to read (if needed):** None
**Depends on:** None
**Parallel group:** P1 (disjoint from Task 01)

**Specification:**

**Step 1 — Add `share_plus` to `pubspec.yaml`**

Under `dependencies:`, add:
```yaml
  share_plus: ^10.0.0
```

Place it near `path_provider` (after that line).

---

**Step 2 — Fix `downloadAndOpenPdf` in `paper_pdf_viewer.dart`**

Currently the mobile branch (the `else` at the bottom) just shows a SnackBar
with the file path — the user cannot open or share the file:

```dart
} else {
  // Android / iOS — show saved path as fallback.
  messenger.showSnackBar(
    SnackBar(
      content: Text('PDF saved to: ${file.path}'),
      duration: const Duration(seconds: 5),
    ),
  );
}
```

Replace with a share-sheet call using `share_plus`:

```dart
} else {
  // Android / iOS — open system share sheet so the user can print,
  // open in a PDF viewer, or share the file.
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    subject: 'Exam Paper PDF',
  );
}
```

Add the import at the top of the file:
```dart
import 'package:share_plus/share_plus.dart';
```

No AndroidManifest changes are required — `share_plus` v10 handles FileProvider
registration automatically via its manifest merge.

---

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — note that `paper_pdf_viewer.dart` now uses `share_plus` for mobile
- [ ] Mark this task `[x]`
- [ ] Orchestrator: run `flutter pub get` then `git commit -m "fix: use share_plus for mobile PDF sharing in paper wizard"`

---

### [x] Task 03: Auto-advance paper status after finalization + expose print button earlier

**Files to create/modify:**
- `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** None
**Parallel group:** P2

**Specification:**

**Background:**
After `finalizePaper` succeeds in the generation wizard, the paper's local Drift
status stays `pending`. The "Print Paper" button in `paper_detail_page.dart` only
shows when `isDoneOrMarked`. So once the user exits the wizard, they have no way
to re-access the PDF from the paper detail page — the print button simply isn't
there.

The fix has two parts:
1. After `finalizePaper` succeeds, the wizard automatically advances the paper
   status from `pending` → `progress` via `ExamsGradesDao.updatePaper`. This also
   writes a `SyncAction.updatePaper` log entry so the change syncs to the server.
2. The "Print Paper" button condition in `paper_detail_page.dart` is broadened to
   `!isPending` (shows for `progress`, `done`, `marked`).

---

**Change 1 — `paper_generation_page.dart`: advance status after finalization**

Location: `_finalize()` method in `_PaperGenerationPageState` (around line 1253).

The current `Ok` case:
```dart
case Ok(:final value):
  setState(() {
    _paperPdf = value;
    _isFinalizing = false;
  });
```

Replace with:
```dart
case Ok(:final value):
  // Auto-advance paper status pending → progress so the "View / Print Paper"
  // button is visible on the paper detail page immediately after the user exits.
  final accountId = cache.currentUser?.user.id;
  if (accountId != null) {
    final now = BigInt.from(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    try {
      await ExamsGradesDao(db).updatePaper(
        schoolId: widget.schoolId,
        examId: widget.examId,
        subject: widget.subjectId,
        paperNum: widget.paperId,
        grade: widget.grade,
        stream: widget.stream,
        changes: PapersCompanion(
          status: const Value(PaperStatus.progress),
          updated: Value(now),
        ),
        accountId: accountId,
      );
    } catch (e) {
      // Non-fatal: PDF was generated successfully even if status advance fails.
      debugPrint('[PaperGen] Failed to advance paper status: $e');
    }
  }
  if (!mounted) return;
  setState(() {
    _paperPdf = value;
    _isFinalizing = false;
  });
```

`ExamsGradesDao`, `PapersCompanion`, and `PaperStatus` are all accessible via the
existing `import '../../../../database/database.dart'` import. Add this import for
`Value` if it is not already present:

```dart
import 'package:drift/drift.dart' show Value;
```

`cache` and `db` are accessible via the existing `import '../../../../client.dart'`
import.

---

**Change 2 — `paper_detail_page.dart`: show print button for all non-pending statuses**

Location: `_PaperHeaderState.build()` method (around line 929).

The build method defines this local variable:
```dart
final isDoneOrMarked = status == PaperStatus.done || isMarked;
```

Find the print button block — it currently reads:
```dart
// ── Print Paper (done or marked) ──────────────────────────
if (isDoneOrMarked) ...[
```

Change the condition and comment:
```dart
// ── View / Print Paper (visible once paper has been finalized / in progress) ──
if (!isPending) ...[
```

Also update the `Tooltip` message inside that block from `'Print Paper'` to
`'View / Print Paper'`:
```dart
Tooltip(
  message: 'View / Print Paper',
  // ... rest of Tooltip unchanged
```

The `isDoneOrMarked` local variable can remain — it may be referenced elsewhere
in the build method. Only the one `if` condition on the print button changes.

---

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — note status auto-advance in `_finalize()` and updated print button condition `!isPending` in `_PaperHeaderState`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "feat: auto-advance paper status on finalization, show print button from progress onwards"`

---

### [x] Task 04: Add GetPaperQuestions RPC so the wizard can restore state on re-entry

**Files to create/modify:**
- `lib/services/question_bank.dart`
- `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/exams/CONTEXT.md`
**Depends on:** Server Task S3 (server must add the `GetPaperQuestions` RPC and
regenerate Dart proto files before this task starts)
**Parallel group:** P3 (blocked until server Task S3 is complete)

**Specification:**

> **Note:** Do NOT start this task until the server confirms `GetPaperQuestions`
> is live and the generated Dart files (`question_bank.pb.dart`,
> `question_bank.pbgrpc.dart`) have been updated.

**Background:**
When a user exits the paper generation wizard and navigates back to the same
paper, `_generatedQuestions` is empty (it is pure in-memory state). The server
still has the questions in its `paper_questions` table. Without a restore call the
user is forced to regenerate the whole paper, discarding any manual edits.

---

**Step 1 — Add `getPaperQuestions` to `QuestionBankService`**

Add this method to the `QuestionBankService` class in
`lib/services/question_bank.dart`, following the same pattern as the surrounding
methods:

```dart
/// Fetch the currently assembled question list for a paper from the server.
/// Returns an empty list if no paper has been generated yet.
Future<Result<List<models.PaperQuestion>, GrpcError>> getPaperQuestions({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? stream,
  required String accessToken,
}) async {
  try {
    final req = pb.GetPaperQuestionsRequest()
      ..school = school
      ..exam = exam
      ..subject = subject
      ..grade = grade;
    if (paper != null) req.paper = paper;
    if (stream != null) req.stream = stream;
    final options = CallOptions(
      metadata: {'authorization': 'Bearer $accessToken'},
      timeout: const Duration(seconds: 30),
    );
    final client = pbgrpc.QuestionBankClient(_mainChannel);
    final resp = await client.getPaperQuestions(req, options: options);
    final questions =
        resp.questions.map(models.PaperQuestion.fromProto).toList();
    return Ok(questions);
  } on GrpcError catch (e) {
    return Err(e);
  } catch (e, st) {
    print('[QB] getPaperQuestions ← UNEXPECTED ${e.runtimeType}: $e\n$st');
    return Err(GrpcError.internal('getPaperQuestions failed: $e'));
  }
}
```

---

**Step 2 — Load existing questions on wizard entry**

In `_PaperGenerationPageState.initState()`, after setting up the controllers,
call a restore helper:

```dart
@override
void initState() {
  super.initState();
  _totalMarksController = TextEditingController(text: '$_totalMarks');
  _tryRestoreExistingQuestions(); // ← add
}
```

Add the helper method:

```dart
Future<void> _tryRestoreExistingQuestions() async {
  final result = await questionBankService.getPaperQuestions(
    school: widget.schoolId,
    exam: widget.examId,
    subject: widget.subjectId,
    paper: widget.paperId,
    grade: widget.grade,
    stream: widget.stream,
    accessToken: accessToken,
  );
  if (!mounted) return;
  switch (result) {
    case Ok(value: final questions) when questions.isNotEmpty:
      _buildQuestionTopicMap(
        questions,
        _allocations.where((a) => a.marks > 0).toList(),
      );
      setState(() {
        _generatedQuestions = questions;
        _currentStep = 1; // skip straight to the review step
      });
    case Ok():
    case Err():
      // No existing questions or network error — stay on allocation step.
      break;
  }
}
```

---

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/exams/CONTEXT.md` — note `getPaperQuestions` in `QuestionBankService` and `_tryRestoreExistingQuestions` in `_PaperGenerationPageState`
- [ ] Mark this task `[x]`
- [ ] Orchestrator: `git commit -m "feat: restore existing paper questions on wizard re-entry"`
