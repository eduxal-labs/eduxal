# TASKS.md

## Feature Group P — Paper Generation: Status Fix, Clear/Regenerate, Multi-Stream Copy, In-App PDF Viewer

---

### Task P01: ✅ Remove auto-status-advance from `_finalize()` in PaperGenerationPage

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** None — full spec below
**Depends on:** None
**Parallel group:** P1 (runs immediately alongside P02)

**Specification:**

In `_PaperGenerationPageState._finalize()` (approx lines 1456–1514), inside the `case Ok` branch
after a successful `finalizePaper` call, there is a block that calls
`ExamsGradesDao(db).updatePaper(...)` with `PaperStatus.progress`. This auto-advance is wrong
and must be removed entirely.

The block to remove looks like this:

```dart
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
```

Remove this entire `if (accountId != null)` block. Leave the rest of the `case Ok` branch
untouched (the `_paperPdf = value` and `_isFinalizing = false` setState must remain).

After the fix, `_finalize()` succeeds → sets `_paperPdf` → shows the PDF success section.
The paper's `status` remains `PaperStatus.pending`. The teacher explicitly advances status
from the paper detail page when they want to start the exam.

**Update after completion:**
- [x] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "fix: do not auto-advance paper status to progress after PDF generation"`

---

### Task P02: ✅ Fix "View/Print Paper" button — load PDF URL on init and update condition

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** None — full spec below
**Depends on:** None
**Parallel group:** P1 (runs immediately alongside P01)

**Specification:**

Because Task P01 removes the auto-status-advance, a `pending` paper can now have a generated
PDF. The "View/Print Paper" button was gated on `!isPending` — after P01 it would never appear.
This task fixes that in two parts.

---

**Part A — Try to load an existing PDF URL on page init.**

In `_PaperDetailPageState.initState()` (approx lines 226–276), after the call to
`_loadSchemeFiles()`, add:

```dart
_tryLoadExistingPdf();
```

Then add this new method anywhere in `_PaperDetailPageState` (e.g. near `_loadSchemeFiles`):

```dart
/// Attempt to load the presigned PDF URL for this paper from the server.
/// Called on init so returning users can view a previously-generated PDF
/// without having to re-open the generation wizard.
/// Silently ignores errors — not every pending paper has a generated PDF.
Future<void> _tryLoadExistingPdf() async {
  final token = accessToken;
  if (token.isEmpty) return;
  final result = await questionBankService.getPaperPdf(
    school: widget.schoolId,
    exam: _exam.id,
    subject: _paper.subject,
    paper: _paper.paper,
    grade: _paper.grade,
    stream: _paper.stream,
    accessToken: token,
  );
  if (!mounted) return;
  switch (result) {
    case Ok(:final value):
      setState(() => _paperPdf = value);
    case Err():
      // Paper not yet finalized — ignore silently.
      break;
  }
}
```

---

**Part B — Fix the "View/Print Paper" button condition.**

In `_PaperHeaderState.build()` find the block (approx lines 1260–1295) that guards the
"View / Print Paper" `InkWell`:

```dart
// ── Print Paper (progress, done, or marked) ───────────────
if (!isPending) ...[
```

Change it to:

```dart
// ── Print Paper (PDF generated) ───────────────────────────
if (widget.paperPdf != null) ...[
```

This makes the button appear as soon as a PDF URL exists, regardless of paper status.

---

**Part C — Add `onPdfCleared` callback to `_PaperHeader`.**

When a teacher clears questions (Task P04) and exits the generation page, the detail page
must know to hide the "View/Print" button. Add a nullable callback to `_PaperHeader`:

In the `_PaperHeader` class (approx line 628–679), add a new field after `onPaperGenerated`:

```dart
final VoidCallback? onPdfCleared;
```

In `_PaperDetailPageState.build()`, inside the `_PaperHeader(...)` constructor call, add:

```dart
onPdfCleared: () => setState(() => _paperPdf = null),
```

In `_PaperHeaderState`, find where `PaperGenerationPage` is pushed via `Navigator.push`
(the "Generate Paper" button `onTap`). It currently does something like:

```dart
final pdf = await Navigator.push<PaperPdf?>(
  context,
  MaterialPageRoute(builder: (_) => PaperGenerationPage(...)),
);
if (pdf != null && mounted) widget.onPaperGenerated?.call(pdf);
```

Update the callback handling to also fire `onPdfCleared` when the result is null
(teacher may have cleared the paper):

```dart
final pdf = await Navigator.push<PaperPdf?>(
  context,
  MaterialPageRoute(builder: (_) => PaperGenerationPage(...)),
);
if (!mounted) return;
if (pdf != null) {
  widget.onPaperGenerated?.call(pdf);
} else {
  // Teacher may have cleared questions — refresh PDF state.
  widget.onPdfCleared?.call();
}
```

**Update after completion:**
- [x] Mark this task `[x]`
- [x] Commit: `git add -A && git commit -m "fix: show View/Print Paper button for any paper with a generated PDF"`

---

### Task P03: Add `clearPaperQuestions` service method to `QuestionBankService`

**Files to modify:**
- `lib/services/question_bank.dart`
- `lib/proto/services/question_bank.pb.dart` ← replace with regenerated stubs from server team
- `lib/proto/services/question_bank.pbgrpc.dart` ← replace with regenerated stubs from server team

**Context files to read (if needed):** `lib/services/CONTEXT.md`
**Depends on:** SERVER TASK S01 must be completed first (server implements RPC + provides new Dart stubs)
**Parallel group:** P2 (starts after server delivers S01 stubs)

**Specification:**

The server adds a `ClearPaperQuestions` RPC to the `QuestionBank` service. The new proto
messages (defined by the server in `question_bank.proto`) are:

```protobuf
message ClearPaperQuestionsRequest {
  string school         = 1;
  string exam           = 2;
  int32  subject        = 3;
  optional int32 paper  = 4;
  int32  grade          = 5;
  optional int32 stream = 6;
}

message ClearPaperQuestionsResponse {
  int32 questions_deleted = 1;
  bool  pdf_deleted       = 2;
}
```

**Step 1:** Replace `lib/proto/services/question_bank.pb.dart` and
`lib/proto/services/question_bank.pbgrpc.dart` with the regenerated files provided by
the server team after they implement S01.

**Step 2:** Add the following method to `QuestionBankService` in
`lib/services/question_bank.dart`, after the `finalizePaper` method:

```dart
/// Delete all generated questions for a paper and invalidate its S3 PDF.
/// Only valid when the paper is still in Pending status.
/// Returns the count of paper_questions rows deleted on success.
Future<Result<int, GrpcError>> clearPaperQuestions({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? stream,
  required String accessToken,
}) async {
  print(
    '[QB] clearPaperQuestions → school=$school exam=$exam '
    'subject=$subject grade=$grade',
  );
  try {
    final req = pb.ClearPaperQuestionsRequest()
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
    final resp = await client.clearPaperQuestions(req, options: options);
    print(
      '[QB] clearPaperQuestions ← OK '
      '(deleted=${resp.questionsDeleted} pdf=${resp.pdfDeleted})',
    );
    return Ok(resp.questionsDeleted);
  } on GrpcError catch (e) {
    print('[QB] clearPaperQuestions ← GrpcError: ${e.code} ${e.message}');
    return Err(e);
  } catch (e, st) {
    print(
      '[QB] clearPaperQuestions ← UNEXPECTED ${e.runtimeType}: $e\n$st',
    );
    return Err(GrpcError.internal('clearPaperQuestions failed: $e'));
  }
}
```

**Update after completion:**
- [ ] Update `lib/services/CONTEXT.md` — add `clearPaperQuestions` to `question_bank.dart` entry
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add clearPaperQuestions service method"`

---

### Task P04: Add "Clear & Regenerate" button to `PaperGenerationPage`

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
**Context files to read (if needed):** None — full spec below
**Depends on:** P03
**Parallel group:** P2-B (after P03 completes)

**Specification:**

Teachers need to discard all generated questions for a paper and start fresh. This task adds
a "Clear & Regenerate" destructive action to the generation wizard.

---

**New state variable** — add to `_PaperGenerationPageState`:

```dart
bool _isClearing = false;
```

---

**New method `_clearAndRestart()`** — add to `_PaperGenerationPageState`:

```dart
Future<void> _clearAndRestart() async {
  if (_isClearing) return;

  // Confirm — this is destructive.
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text(
          'Clear Questions?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        content: const Text(
          'This will permanently delete all generated questions and the PDF '
          'for this paper. You can then generate a new set from scratch.',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: cs.error)),
          ),
        ],
      );
    },
  );
  if (confirm != true || !mounted) return;

  setState(() => _isClearing = true);

  final result = await questionBankService.clearPaperQuestions(
    school: widget.schoolId,
    exam: widget.examId,
    subject: widget.subjectId,
    paper: widget.paperId,
    grade: widget.grade,
    stream: widget.stream,
    accessToken: accessToken,
  );

  if (!mounted) return;
  setState(() => _isClearing = false);

  switch (result) {
    case Ok():
      // Reset wizard to step 0.
      setState(() {
        _generatedQuestions = [];
        _paperPdf = null;
        _currentStep = 0;
        _editingIndex = -1;
        _regeneratingIndex = -1;
        _questionTopics.clear();
      });
    case Err(:final error):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear questions: ${error.message}'),
        ),
      );
  }
}
```

---

**Where to render the button:**

Create a private helper widget `_ClearRegenerateButton` at the bottom of the file (alongside
other private widget classes):

```dart
class _ClearRegenerateButton extends StatelessWidget {
  const _ClearRegenerateButton({
    required this.onTap,
    required this.isClearing,
    required this.cs,
  });

  final VoidCallback onTap;
  final bool isClearing;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isClearing ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.error.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: isClearing
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.error.withValues(alpha: 0.75),
              ),
            )
          : Icon(Icons.refresh_outlined, size: 16, color: cs.error.withValues(alpha: 0.75)),
      label: Text(
        isClearing ? 'Clearing…' : 'Clear & Regenerate',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400),
      ),
    );
  }
}
```

**Placement — Step 1 (review step):**
In `_ReviewFooter` (or directly in `_buildReviewStep`), add `_ClearRegenerateButton` to the
left of the "Continue to Finalize" button in the sticky footer row. The footer row becomes
a `Row` with the clear button on the left and the finalize button on the right.

If `_ReviewFooter` is a separate widget passed `onFinalize`, update it to also accept
`onClear` and `isClearing`:

```dart
// _ReviewFooter updated constructor:
final VoidCallback? onClear;
final bool isClearing;
```

Inside `_ReviewFooterState.build`, render:
```dart
Row(
  children: [
    _ClearRegenerateButton(
      onTap: widget.onClear ?? () {},
      isClearing: widget.isClearing,
      cs: cs,
    ),
    const Spacer(),
    // ... existing "Continue to Finalize" button ...
  ],
)
```

Pass values from `_buildReviewStep`:
```dart
_ReviewFooter(
  // ... existing params ...
  onClear: _generatedQuestions.isNotEmpty ? _clearAndRestart : null,
  isClearing: _isClearing,
)
```

**Placement — Step 2 (finalize step), before PDF is generated (`_paperPdf == null`):**
In `_buildFinalizeStep`, above the `_FinalizeFooter` widget (shown only when `_paperPdf == null`),
add:

```dart
if (_paperPdf == null)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: _ClearRegenerateButton(
        onTap: _clearAndRestart,
        isClearing: _isClearing,
        cs: cs,
      ),
    ),
  ),
```

**Placement — Step 2 (finalize step), after PDF is generated (`_paperPdf != null`):**
In the PDF success section (inside `if (_paperPdf != null) ...`), add a "Regenerate Paper"
TextButton below the "Done" button:

```dart
const SizedBox(height: 4),
Center(
  child: _ClearRegenerateButton(
    onTap: _clearAndRestart,
    isClearing: _isClearing,
    cs: cs,
  ),
),
```

**Update after completion:**
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add Clear & Regenerate button to paper generation page"`

---

### Task P05: Add `copyPaperToStreams` service method + `StreamCopyResult` model

**Files to modify/create:**
- `lib/models/paper_generation.dart` — add `StreamCopyResult` class
- `lib/services/question_bank.dart` — add `copyPaperToStreams` method
- `lib/proto/services/question_bank.pb.dart` ← replace with regenerated stubs from server team
- `lib/proto/services/question_bank.pbgrpc.dart` ← replace with regenerated stubs from server team

**Context files to read (if needed):** `lib/models/CONTEXT.md`, `lib/services/CONTEXT.md`
**Depends on:** SERVER TASK S02 must be completed first
**Parallel group:** P2 (runs in parallel with P03/P04 once S02 stubs are available)

**Specification:**

The server adds a `CopyPaperToStreams` RPC. Proto messages:

```protobuf
message CopyPaperToStreamsRequest {
  string school                = 1;
  string exam                  = 2;
  int32  subject               = 3;
  optional int32 paper         = 4;
  int32  grade                 = 5;
  optional int32 source_stream = 6;
  repeated int32 target_streams = 7;
}

message StreamCopyResult {
  int32  stream                = 1;
  bool   success               = 2;
  string pdf_url               = 3;
  int64  pdf_expiry            = 4;
  string marking_scheme_url    = 5;
  int64  marking_scheme_expiry = 6;
  string error                 = 7;
}

message CopyPaperToStreamsResponse {
  repeated StreamCopyResult results = 1;
}
```

**Step 1:** Replace proto stubs with regenerated files from server (same as P03 step 1).

**Step 2:** Add `StreamCopyResult` to `lib/models/paper_generation.dart` (after `PaperPdf`):

```dart
/// Result for a single target stream in a [copyPaperToStreams] operation.
class StreamCopyResult {
  final int stream;
  final bool success;
  final String? pdfUrl;
  final DateTime? pdfExpiry;
  final String? markingSchemeUrl;
  final DateTime? markingSchemeExpiry;
  final String? error;

  const StreamCopyResult({
    required this.stream,
    required this.success,
    this.pdfUrl,
    this.pdfExpiry,
    this.markingSchemeUrl,
    this.markingSchemeExpiry,
    this.error,
  });

  factory StreamCopyResult.fromProto(pb.StreamCopyResult proto) {
    return StreamCopyResult(
      stream: proto.stream,
      success: proto.success,
      pdfUrl: proto.pdfUrl.isEmpty ? null : proto.pdfUrl,
      pdfExpiry: proto.pdfExpiry == Int64.ZERO
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              proto.pdfExpiry.toInt() * 1000,
            ),
      markingSchemeUrl: proto.markingSchemeUrl.isEmpty
          ? null
          : proto.markingSchemeUrl,
      markingSchemeExpiry: proto.markingSchemeExpiry == Int64.ZERO
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              proto.markingSchemeExpiry.toInt() * 1000,
            ),
      error: proto.error.isEmpty ? null : proto.error,
    );
  }
}
```

Note: `pb` here is the question_bank proto import alias already in `paper_generation.dart`.
Add `import 'package:fixnum/fixnum.dart' show Int64;` if not already imported.

**Step 3:** Add `copyPaperToStreams` to `QuestionBankService` in
`lib/services/question_bank.dart`, after `clearPaperQuestions`:

```dart
/// Copy a finalized paper's question set to one or more additional streams.
/// The server copies question rows and generates a PDF for each target stream.
/// The source stream must already have generated questions.
/// Partial failures are possible — check [StreamCopyResult.success] per stream.
Future<Result<List<models.StreamCopyResult>, GrpcError>> copyPaperToStreams({
  required String school,
  required String exam,
  required int subject,
  int? paper,
  required int grade,
  int? sourceStream,
  required List<int> targetStreams,
  required String accessToken,
}) async {
  print(
    '[QB] copyPaperToStreams → school=$school exam=$exam '
    'grade=$grade targets=$targetStreams',
  );
  try {
    final req = pb.CopyPaperToStreamsRequest()
      ..school = school
      ..exam = exam
      ..subject = subject
      ..grade = grade;
    if (paper != null) req.paper = paper;
    if (sourceStream != null) req.sourceStream = sourceStream;
    req.targetStreams.addAll(targetStreams);
    final options = CallOptions(
      metadata: {'authorization': 'Bearer $accessToken'},
      // Allow up to 2 minutes — server generates a PDF per stream.
      timeout: const Duration(seconds: 120),
    );
    final client = pbgrpc.QuestionBankClient(_mainChannel);
    final resp = await client.copyPaperToStreams(req, options: options);
    final results =
        resp.results.map(models.StreamCopyResult.fromProto).toList();
    print('[QB] copyPaperToStreams ← OK (${results.length} streams)');
    return Ok(results);
  } on GrpcError catch (e) {
    print('[QB] copyPaperToStreams ← GrpcError: ${e.code} ${e.message}');
    return Err(e);
  } catch (e, st) {
    print(
      '[QB] copyPaperToStreams ← UNEXPECTED ${e.runtimeType}: $e\n$st',
    );
    return Err(GrpcError.internal('copyPaperToStreams failed: $e'));
  }
}
```

**Update after completion:**
- [ ] Update `lib/models/CONTEXT.md` — add `StreamCopyResult` to `paper_generation.dart` entry
- [ ] Update `lib/services/CONTEXT.md` — add `copyPaperToStreams` to `question_bank.dart` entry
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add copyPaperToStreams service method and StreamCopyResult model"`

---

### Task P06: Add multi-stream copy UI to `PaperGenerationPage`

**Files to modify:**
- `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart`
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** P05
**Parallel group:** P3 (after P05 completes)

**Specification:**

After a paper is finalized (PDF generated), the teacher should be able to copy the same
questions to other streams in the same grade with one tap.

---

**1. Add `allStreamsForGrade` param and new state to `PaperGenerationPage`:**

In the `PaperGenerationPage` `StatefulWidget`, add:

```dart
/// All streams available for this grade. Used to populate the multi-stream
/// copy picker shown after PDF generation. Pass an empty list to hide the
/// copy section (e.g. for grade-wide papers with no stream distinction).
final List<({int code, String name})> allStreamsForGrade;
```

Set a default value of `const []` so existing callers need no changes until the
`paper_detail_page.dart` update below.

In `_PaperGenerationPageState`, add:

```dart
// Multi-stream copy state
final Set<int> _selectedTargetStreams = {};
bool _isCopying = false;
List<StreamCopyResult>? _copyResults; // null = not yet attempted
```

---

**2. New `_copyToOtherStreams()` method:**

```dart
Future<void> _copyToOtherStreams() async {
  if (_selectedTargetStreams.isEmpty || _isCopying) return;

  setState(() => _isCopying = true);

  final result = await questionBankService.copyPaperToStreams(
    school: widget.schoolId,
    exam: widget.examId,
    subject: widget.subjectId,
    paper: widget.paperId,
    grade: widget.grade,
    sourceStream: widget.stream,
    targetStreams: _selectedTargetStreams.toList(),
    accessToken: accessToken,
  );

  if (!mounted) return;
  setState(() {
    _isCopying = false;
    switch (result) {
      case Ok(:final value):
        _copyResults = value;
      case Err(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: ${error.message}')),
        );
    }
  });
}
```

---

**3. In `_buildFinalizeStep`, add the multi-stream copy section:**

Compute `otherStreams` — all streams except the current paper's stream:

```dart
final otherStreams = widget.allStreamsForGrade
    .where((s) => s.code != widget.stream)
    .toList();
```

Inside the PDF success section (`if (_paperPdf != null) ...`), after the "Done" button
and any "Clear & Regenerate" button added by P04, add:

```dart
// ── Multi-stream copy section (only when other streams exist) ──
if (otherStreams.isNotEmpty) ...[
  const SizedBox(height: 20),
  Divider(color: AppTheme.borderColor(isDark, cs), thickness: 0.5),
  const SizedBox(height: 16),

  // Header
  Text(
    'Copy to other streams',
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: cs.onSurface,
    ),
  ),
  const SizedBox(height: 4),
  Text(
    'Apply the same questions and generate PDFs for additional streams '
    'in the same grade.',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
    ),
  ),
  const SizedBox(height: 12),

  // Stream multi-select chips
  Wrap(
    spacing: 6,
    runSpacing: 6,
    children: otherStreams.map((s) {
      final selected = _selectedTargetStreams.contains(s.code);
      return GestureDetector(
        onTap: _copyResults != null
            ? null // lock after copy is done
            : () => setState(() {
                  if (selected) {
                    _selectedTargetStreams.remove(s.code);
                  } else {
                    _selectedTargetStreams.add(s.code);
                  }
                }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                : (isDark
                    ? const Color(0xFF1A2536)
                    : cs.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : AppTheme.borderColor(isDark, cs),
              width: 0.5,
            ),
          ),
          child: Text(
            s.name,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight:
                  selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      );
    }).toList(),
  ),

  const SizedBox(height: 12),

  // "Apply" button — shown when no copy has been done yet.
  if (_copyResults == null)
    SizedBox(
      width: double.infinity,
      child: _FinalizeActionButton(
        icon: _isCopying
            ? Icons.hourglass_empty_rounded
            : Icons.copy_all_rounded,
        label: _isCopying
            ? 'Copying…'
            : _selectedTargetStreams.isEmpty
                ? 'Select streams above'
                : 'Apply to ${_selectedTargetStreams.length} '
                    'stream${_selectedTargetStreams.length == 1 ? '' : 's'}',
        color: _selectedTargetStreams.isEmpty || _isCopying
            ? (isDark
                ? cs.surfaceContainerHighest
                : cs.surfaceContainerHigh)
            : cs.secondary,
        textColor: _selectedTargetStreams.isEmpty || _isCopying
            ? cs.onSurfaceVariant.withValues(alpha: 0.5)
            : cs.onSecondary,
        onTap: _selectedTargetStreams.isEmpty || _isCopying
            ? null
            : _copyToOtherStreams,
      ),
    ),

  // Per-stream copy results
  if (_copyResults != null) ...[
    const SizedBox(height: 8),
    Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(
          color: AppTheme.borderColor(isDark, cs),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _copyResults!.length; i++) ...[
            if (i > 0) AppTheme.tableRowDivider(isDark, cs),
            _buildCopyResultRow(_copyResults![i], otherStreams, cs, isDark),
          ],
        ],
      ),
    ),
  ],
],
```

**New `_buildCopyResultRow` helper:**

```dart
Widget _buildCopyResultRow(
  StreamCopyResult result,
  List<({int code, String name})> streams,
  ColorScheme cs,
  bool isDark,
) {
  final streamName = streams
      .firstWhere((s) => s.code == result.stream,
          orElse: () => (code: result.stream, name: 'Stream ${result.stream}'))
      .name;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        Icon(
          result.success
              ? Icons.check_circle_rounded
              : Icons.error_outline_rounded,
          size: 16,
          color: result.success ? Colors.green.shade400 : cs.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streamName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
              if (!result.success && result.error != null)
                Text(
                  result.error!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.error.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
        if (result.success)
          Text(
            'PDF generated',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.green.shade400,
            ),
          ),
      ],
    ),
  );
}
```

---

**4. Update `paper_detail_page.dart` — pass `allStreamsForGrade` to `_PaperHeader`.**

In the `_PaperHeader` widget class (approx line 628–679), add a new field:

```dart
final Map<int, String> streamNames;
```

In `_PaperDetailPageState.build()`, pass `streamNames: widget.streamNames` to
`_PaperHeader(...)`.

In `_PaperHeaderState`, find where `PaperGenerationPage` is constructed in the
"Generate Paper" button `onTap`. Add `allStreamsForGrade`:

```dart
PaperGenerationPage(
  schoolId: widget.schoolId,
  examId: widget.exam.exam.id,
  subjectId: widget.paper.subject,
  paperId: widget.paper.paper,
  grade: widget.paper.grade,
  stream: widget.paper.stream,
  subjectName: widget.subjectNames[widget.paper.subject] ??
      'Subject ${widget.paper.subject}',
  examName: widget.exam.exam.name,
  allStreamsForGrade: widget.streamNames.entries
      .map((e) => (code: e.key, name: e.value))
      .toList(),
)
```

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update `paper_generation_page.dart`
  and `paper_detail_page.dart` entries to reflect new params
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add multi-stream paper copy UI to generation page"`

---

### Task P07: ✅ Add in-app PDF viewer (`PaperPdfViewerPage`)

**Files to modify/create:**
- `pubspec.yaml` — add `pdfx` and `printing` packages
- `lib/ui/screens/school_dashboard/academics/paper_pdf_viewer.dart` — add `PaperPdfViewerPage`
- `lib/ui/screens/school_dashboard/academics/paper_generation_page.dart` — update "View PDF" button
- `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart` — update "View/Print" button

**Context files to read (if needed):** `lib/ui/screens/school_dashboard/CONTEXT.md`
**Depends on:** P02 (the button condition is changed by P02; this task replaces the `onTap`)
**Parallel group:** P2 (can run while server implements S01/S02)

**Specification:**

Currently `downloadAndOpenPdf` opens a PDF in the OS viewer via `xdg-open`/`open`/`start`,
and on mobile triggers a share sheet. This task replaces all "View Paper" call sites with
navigation to a new `PaperPdfViewerPage` — a full-screen in-app PDF renderer.

---

**1. Add packages to `pubspec.yaml`:**

Under `dependencies:`, add:
```yaml
pdfx: ^2.6.0
printing: ^5.13.2
```

Run `flutter pub get` after editing.

**Linux note:** `pdfx` on Linux requires `libpoppler-glib-dev`. Add the following to
`linux/CMakeLists.txt` in the `target_link_libraries` block:
```cmake
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app
  PkgConfig::GTK poppler-glib)
```
Also add `find_package(PkgConfig REQUIRED)` and
`pkg_check_modules(POPPLER REQUIRED IMPORTED_TARGET poppler-glib)` near the top
of `linux/CMakeLists.txt`. Refer to https://pub.dev/packages/pdfx#linux for the
full setup instructions.

---

**2. Add `PaperPdfViewerPage` to `paper_pdf_viewer.dart`.**

Keep the existing `downloadAndOpenPdf` and `downloadAndOpenDirectUrl` functions —
they are still used for marking scheme viewing and as a download/share fallback.

Add the following imports at the top of the file (after existing imports):
```dart
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';
import '../../../../client.dart';
import '../../../../models/result.dart';
```

Then add the widget class at the bottom of the file:

```dart
// ─────────────────────────────────────────────────────────────────────────────
// PaperPdfViewerPage
//
// Full-screen in-app PDF viewer. Downloads the paper PDF from the server and
// renders it inline using the `pdfx` package.
// ─────────────────────────────────────────────────────────────────────────────

class PaperPdfViewerPage extends StatefulWidget {
  const PaperPdfViewerPage({
    super.key,
    required this.school,
    required this.exam,
    required this.subject,
    this.paper,
    required this.grade,
    this.stream,
    required this.accessToken,
    required this.title,
  });

  final String school;
  final String exam;
  final int subject;
  final int? paper;
  final int grade;
  final int? stream;
  final String accessToken;

  /// Shown in the AppBar — e.g. "Mathematics Paper 1".
  final String title;

  @override
  State<PaperPdfViewerPage> createState() => _PaperPdfViewerPageState();
}

class _PaperPdfViewerPageState extends State<PaperPdfViewerPage> {
  PdfController? _pdfController;
  Uint8List? _pdfBytes; // retained for printing/sharing
  bool _loading = true;
  String? _error;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Step 1 — get presigned URL from the question bank service.
      final urlResult = await questionBankService.getPaperPdf(
        school: widget.school,
        exam: widget.exam,
        subject: widget.subject,
        paper: widget.paper,
        grade: widget.grade,
        stream: widget.stream,
        accessToken: widget.accessToken,
      );

      final String pdfUrl;
      switch (urlResult) {
        case Ok(:final value):
          pdfUrl = value.pdfUrl;
        case Err(:final error):
          throw Exception(error.message ?? 'Failed to get PDF URL');
      }

      // Step 2 — download PDF bytes.
      final httpClient = HttpClient();
      try {
        final request = await httpClient.getUrl(Uri.parse(pdfUrl));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw Exception(
            'Download failed (HTTP ${response.statusCode})',
          );
        }
        final bytes = await consolidateHttpClientResponseBytes(response);

        if (!mounted) return;

        // Step 3 — open in pdfx.
        _pdfBytes = bytes;
        _pdfController = PdfController(
          document: PdfDocument.openData(bytes),
        );
        setState(() => _loading = false);
      } finally {
        httpClient.close();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _print() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: widget.title,
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _share() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final paperSuffix = widget.paper != null ? '_${widget.paper}' : '';
    final filename =
        'paper_${widget.exam}_${widget.subject}$paperSuffix.pdf';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${widget.title} PDF',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (!_loading && _error == null) ...[
            // Print button (uses the `printing` package).
            IconButton(
              icon: _isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.print_rounded, size: 20),
              tooltip: 'Print',
              onPressed: _isPrinting ? null : _print,
            ),
            // Share / save to files.
            IconButton(
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: 'Share PDF',
              onPressed: _share,
            ),
          ],
          const SizedBox(width: 4),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load PDF',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _loadPdf,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return PdfView(
      controller: _pdfController!,
      scrollDirection: Axis.vertical,
      pageSnapping: false,
      padding: 16,
      physics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
    );
  }
}
```

Add `import 'dart:typed_data' show Uint8List;` at the top of `paper_pdf_viewer.dart`
if not already present.

---

**3. Update "View/Print Paper" button in `paper_detail_page.dart`:**

In `_PaperHeaderState.build()`, find the `onTap` for the "View / Print Paper" `InkWell`
(updated by P02 to show when `widget.paperPdf != null`). Replace the body of the `onTap`:

Before:
```dart
onTap: _printBusy
    ? null
    : () async {
        setState(() => _printBusy = true);
        try {
          await downloadAndOpenPdf(...);
        } finally {
          if (mounted) setState(() => _printBusy = false);
        }
      },
```

After:
```dart
onTap: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PaperPdfViewerPage(
        school: widget.schoolId,
        exam: widget.exam.exam.id,
        subject: widget.paper.subject,
        paper: widget.paper.paper,
        grade: widget.paper.grade,
        stream: widget.paper.stream,
        accessToken: accessToken,
        title: '${widget.subjectNames[widget.paper.subject] ?? 'Paper'}'
            '${widget.paper.paper != null ? ' Paper ${widget.paper.paper}' : ''}',
      ),
    ),
  );
},
```

Remove the `_printBusy` state variable and its `setState` calls entirely — navigation
is synchronous from the button's perspective.

Also remove the spinner child branch for `_printBusy` from the `InkWell` child — replace
it with a static icon:
```dart
child: Icon(
  Icons.picture_as_pdf_rounded,
  size: 18,
  color: cs.primary.withValues(alpha: 0.7),
),
```

Add `import 'paper_pdf_viewer.dart' show PaperPdfViewerPage;` at the top of
`paper_detail_page.dart` if not already imported.

---

**4. Update "Download / Print PDF" button in `paper_generation_page.dart`:**

In `_buildFinalizeStep`, find the `_FinalizeActionButton` labelled "Download / Print PDF".
Replace its `onTap` to navigate to `PaperPdfViewerPage` instead:

```dart
_FinalizeActionButton(
  icon: Icons.picture_as_pdf_outlined,
  label: 'View PDF',
  color: cs.primary,
  textColor: cs.onPrimary,
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PaperPdfViewerPage(
        school: widget.schoolId,
        exam: widget.examId,
        subject: widget.subjectId,
        paper: widget.paperId,
        grade: widget.grade,
        stream: widget.stream,
        accessToken: accessToken,
        title: widget.subjectName,
      ),
    ),
  ),
),
```

Add `import 'paper_pdf_viewer.dart' show PaperPdfViewerPage;` at the top of
`paper_generation_page.dart` if not already imported.

---

**Update after completion:**
- [ ] Update `lib/ui/screens/school_dashboard/CONTEXT.md` — update `paper_pdf_viewer.dart`
  entry to document `PaperPdfViewerPage`
- [ ] Mark this task `[x]`
- [ ] Commit: `git add -A && git commit -m "feat: add in-app PDF viewer (PaperPdfViewerPage) using pdfx"`
```

Now let me write the server TASKS.md to `../ledger/TASKS.md` using the terminal.