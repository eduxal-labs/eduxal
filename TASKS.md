# TASKS.md — AI Marking MVP

## Track C: Client Implementation

> **Depends on:** Server Task S1 (proto definitions) must be completed first.
> The proto file is at `../ledger/protos/services/ai_marking.proto`.

---

### Task C1: Generate Dart Proto Stubs from `ai_marking.proto` ✅

**Files to create:**
- `lib/proto/services/ai_marking.pb.dart`
- `lib/proto/services/ai_marking.pbgrpc.dart`
- `lib/proto/services/ai_marking.pbenum.dart`
- `lib/proto/services/ai_marking.pbjson.dart`

**Context files to read (if needed):** `lib/proto/services/sync.pbgrpc.dart` (for import pattern reference)
**Depends on:** Server Task S1
**Parallel group:** —

**Specification:**

Run `protoc` with the Dart gRPC plugin to generate stubs from the server's proto file:

```
protoc --dart_out=grpc:lib/proto/services/ \
  -I../ledger/protos/ \
  services/ai_marking.proto
```

If `protoc-gen-dart` is not available, install it:
```
dart pub global activate protoc_plugin
```

Verify the generated files compile by running `dart analyze lib/proto/services/ai_marking.pb.dart`.

The key generated classes should be:
- `AiMarkingClient` — gRPC client stub with `requestUploadUrls()` and `markPaper()` methods
- `UploadUrlsRequest`, `UploadUrlsResponse`, `SignedUrl`, `StudentSignedUrls`, `StudentSheetCount`
- `MarkPaperRequest`, `MarkPaperResponse`, `StudentMarkTarget`

**Update after completion:**
- [x] Verify generated files exist and compile in `lib/proto/services/`
- [x] Mark this task `[x]`

---

### Task C2: Create AiMarking Service

**Files to create:** `lib/services/ai_marking.dart`
**Context files to read (if needed):** `lib/services/authentication.dart` (service pattern), `lib/services/file_upload.dart` (existing stubbed upload service), `lib/cache/file_cache.dart` (for `FileCache.upload()`)
**Depends on:** C1
**Parallel group:** —

**Specification:**

Create `lib/services/ai_marking.dart` following the existing service pattern from `authentication.dart`.
This service replaces the stubbed `FileUploadService` in `lib/services/file_upload.dart`.

```dart
import 'dart:io';
import 'package:grpc/grpc.dart';
import '../models/result.dart';
import '../proto/services/ai_marking.pbgrpc.dart';

class AiMarkingService {
  AiMarkingService(ClientChannel channel)
    : _client = AiMarkingClient(channel);

  final AiMarkingClient _client;

  /// Request presigned PUT URLs for marking scheme and student answer sheets.
  Future<Result<UploadUrlsResponse, GrpcError>> requestUploadUrls({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int schemeCount,
    required Map<int, int> studentSheetCounts, // adm → count
    required String accessToken,
  }) async {
    try {
      final req = UploadUrlsRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..schemeCount = schemeCount;
      if (paper != null) req.paper = paper;
      for (final entry in studentSheetCounts.entries) {
        req.students.add(StudentSheetCount()
          ..adm = entry.key
          ..count = entry.value);
      }
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
      );
      final resp = await _client.requestUploadUrls(req, options: options);
      return Ok(resp);
    } on GrpcError catch (e) {
      return Err(e);
    }
  }

  /// Upload a single file to S3 using a presigned PUT URL.
  /// Returns true on success.
  Future<bool> uploadFile(String putUrl, String localPath) async {
    if (putUrl.isEmpty) return true; // stub mode
    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
      request.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      request.add(bytes);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      httpClient?.close();
    }
  }

  /// Request the server to mark a paper using AI.
  /// Returns immediately; actual grades arrive via watchChanges SyncDelta stream.
  Future<Result<MarkPaperResponse, GrpcError>> markPaper({
    required String school,
    required String exam,
    required int subject,
    int? paper,
    required int grade,
    int? stream,
    required int totalMarks,
    required List<String> schemeKeys,
    required Map<int, List<String>> studentKeys, // adm → list of S3 keys
    required String accessToken,
  }) async {
    try {
      final req = MarkPaperRequest()
        ..school = school
        ..exam = exam
        ..subject = subject
        ..grade = grade
        ..totalMarks = totalMarks;
      if (paper != null) req.paper = paper;
      if (stream != null) req.stream = stream;
      req.schemeKeys.addAll(schemeKeys);
      for (final entry in studentKeys.entries) {
        req.students.add(StudentMarkTarget()
          ..adm = entry.key
          ..keys.addAll(entry.value));
      }
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $accessToken'},
      );
      final resp = await _client.markPaper(req, options: options);
      return Ok(resp);
    } on GrpcError catch (e) {
      return Err(e);
    }
  }
}
```

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task C3: Wire AiMarking Service in Client + Remove Stubbed FileUploadService

**Files to modify:** `lib/client.dart`
**Files to delete:** `lib/services/file_upload.dart`
**Context files to read (if needed):** `lib/client.dart` (L111-145)
**Depends on:** C2
**Parallel group:** —

**Specification:**

1. In `lib/client.dart`:
   - Replace import `import 'services/file_upload.dart';` with `import 'services/ai_marking.dart';`
   - Replace the `fileUpload` field (L133):
     ```dart
     // BEFORE:
     late final fileUpload = FileUploadService(_channel);
     // AFTER:
     late final aiMarking = AiMarkingService(_channel);
     ```

2. Delete `lib/services/file_upload.dart` — it's fully replaced by `AiMarkingService`.

3. Search for all references to `client.fileUpload` in the codebase (primarily in `paper_detail_page.dart` around the `_AnswerSubmissionSheet._uploadPendingFiles()` method) and update them to use `client.aiMarking`. The existing `uploadAnswerSheets()` call sites should be temporarily commented out or adapted — Task C5 will wire them up properly with the real upload flow.

4. Grep for any other imports of `file_upload.dart` and remove them.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task C4: Add Marking Scheme Photo Capture UI

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):** `paper_detail_page.dart` — read `_AnswerSubmissionSheet` (L2723-3189) for the photo picker pattern, `_PaperHeader._buildActionButton()` (L1016-1041) for the action button cascade, and `_PaperDetailPageState` (L66-115) for parent state.
**Depends on:** C3
**Parallel group:** P1

**Specification:**

Add marking scheme image capture/management to the paper detail page. The marking scheme is a set of images showing the rubric/answer key for the paper. Images are stored locally at predictable filesystem paths (no new DB table needed).

**1. State in `_PaperDetailPageState` (~L84):**

Add these fields:
```dart
List<String> _schemeFiles = []; // absolute local paths to scheme images
```

Add a method to load scheme files from the local filesystem:
```dart
Future<void> _loadSchemeFiles() async {
  final dir = await _schemeDirectory();
  if (!await dir.exists()) {
    setState(() => _schemeFiles = []);
    return;
  }
  final files = await dir.list().where((e) => e is File).toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  setState(() => _schemeFiles = files.map((f) => f.path).toList());
}

Future<Directory> _schemeDirectory() async {
  final appDir = await getApplicationDocumentsDirectory();
  final paperKey = '${widget.subject}_${widget.paperNum ?? 0}';
  return Directory('${appDir.path}/submissions/${widget.schoolId}/${widget.examId}/$paperKey/scheme');
}
```

Call `_loadSchemeFiles()` in `initState()` after the existing initialization.

**2. Pass `_schemeFiles` down to child widgets:**

Both `_GradeSpreadsheet` and `_GradeList` widgets need access to `_schemeFiles`. Add a `schemeFiles` parameter to both widgets and pass `_schemeFiles` from the parent. Also pass an `onSchemeUpdated` callback so children can trigger a reload.

**3. Scheme upload button in `_PaperHeader`:**

In `_buildActionButton()` (~L1016), add a new priority level in the cascade. After the AI-marking-in-progress check but before the "has unmarked submissions" check:

- If `canManage` AND `_schemeFiles.isEmpty` → show an "Add Marking Scheme" button with `Icons.note_add_outlined` icon (same teal/indigo styling as the AI wand button).
- Tapping it calls `_showSchemeUploadSheet()`.

**4. `_SchemeUploadSheet` bottom sheet widget:**

Create a new widget (insert near `_AnswerSubmissionSheet` at ~L2723) that reuses the same photo picker pattern:

```dart
class _SchemeUploadSheet extends StatefulWidget {
  final String schoolId;
  final String examId;
  final int subject;
  final int? paperNum;
  final List<String> existingPaths;
  final VoidCallback onUpdated;
  // ... constructor
}
```

Features:
- Camera button (single shot) + Gallery button (multi-pick) — same as `_AnswerSubmissionSheet._addPhotos()`
- Save images to: `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/scheme/{n}.jpg`
  - Where `n` is zero-indexed (0.jpg, 1.jpg, ...)
  - `paper` is the paper number as string, use "0" for null/single paper
- Display thumbnails in a grid with remove (X) button on each
- When images are added or removed, call `widget.onUpdated()` which triggers `_loadSchemeFiles()` in the parent

**5. Scheme indicator in `_PaperHeader`:**

When `_schemeFiles.isNotEmpty`, show a small chip/badge near the paper info area:
- Text: "Scheme: {n} pages" (use `AppTheme.kChipRadius` for border radius)
- Tapping the chip opens `_SchemeUploadSheet` to view/edit
- Color: subtle surface variant background

**UI style:** Follow all conventions from AGENT.md §21 — light font weights, kChipRadius for badges, data-table dividers, no bold text.

**Update after completion:**
- [x] Mark this task `[x]`

---

### Task C5: Replace Fake AI Marking with Real Implementation

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read (if needed):**
- `paper_detail_page.dart` L1545-1647 (`_GradeSpreadsheetState.runAiMarking()` — desktop)
- `paper_detail_page.dart` L2236-2336 (`_GradeListState.runAiMarking()` — mobile)
- `paper_detail_page.dart` L1888 (`_AiPhase` enum)
- `lib/services/ai_marking.dart` (from C2)
- `lib/client.dart` (global `client` accessor)
**Depends on:** C3, C4
**Parallel group:** —

**Specification:**

Replace the fake `runAiMarking()` method in BOTH `_GradeSpreadsheetState` (desktop, L1545-1647) AND `_GradeListState` (mobile, L2236-2336). The `_AiPhase` enum stays unchanged: `{idle, analyzing, assigning, done}`.

**Current fake logic being replaced:** Both methods generate random scores with `55 + rng.nextInt(46)` and call `widget.dao.upsertGrade()` with fake data. All of this is removed.

**New `runAiMarking()` flow (identical in both classes):**

```
Phase: IDLE → ANALYZING (0% → 50%)
  1. Guard checks (keep existing): submissions required, canGrade, not already marking, valid account
  2. Check scheme files exist — if empty, show snackbar "Please add a marking scheme first" and return
  3. Filter students: only those with submissions AND no existing grade (keep existing filter logic)
  4. If no students to mark → return
  5. Set phase = analyzing, progress = 0.0
  6. Call client.aiMarking.requestUploadUrls() to get PUT URLs for:
     - schemeCount = schemeFiles.length
     - studentSheetCounts = { adm: submissions[adm].length for each student to mark }
  7. On error → resetAi(), show snackbar, return
  8. Upload scheme files: for each schemeUrl in response.schemeUrls:
     - await client.aiMarking.uploadFile(url.url, schemeFiles[i])
     - Update progress: (uploaded / totalFiles) * 0.5
     - On failure → resetAi(), show snackbar, return
  9. Upload student answer sheets: for each studentUrl in response.studentUrls:
     - For each url in studentUrl.urls:
       - await client.aiMarking.uploadFile(url.url, submissions[studentUrl.adm][i])
       - Update progress: (uploaded / totalFiles) * 0.5
     - Collect S3 keys for each student
  10. On failure at any point → resetAi(), show snackbar, return

Phase: ANALYZING → ASSIGNING (50% → 60%)
  11. Set phase = assigning, progress = 0.5
  12. Call client.aiMarking.markPaper() with:
      - school, exam, subject, paper, grade, stream, totalMarks
      - schemeKeys = response.schemeUrls.map(u => u.key).toList()
      - studentKeys = { adm: [key1, key2, ...] } from collected keys
  13. On error → resetAi(), show snackbar, return
  14. Set progress = 0.6

Phase: ASSIGNING → DONE (60% → 100%)
  15. Wait for grades to arrive via existing _gradesStream (Drift reactive stream).
      Poll every 2 seconds, check how many of the expected students now have grades.
      Update progress: 0.6 + (receivedCount / expectedCount) * 0.4
  16. Timeout after 120 seconds — if not all grades arrived, show snackbar
      "AI marking partially complete — {received}/{expected} graded"
  17. On completion → set phase = done, progress = 1.0

Phase: DONE → IDLE
  18. Keep existing wave flash animation logic
  19. Keep existing 2-second display then reset to idle
  20. Keep all widget.onAiStateChanged callbacks throughout
```

**Properties needed from widget tree:**
- `schemeFiles` — `List<String>` passed from `_PaperDetailPageState._schemeFiles`
- `totalMarks` — `int` from paper data (paper.total or the exam's total marks for this paper)
- `grade` — `int` from the current paper's grade field
- `stream` — `int?` from the current paper's stream field

If these aren't already available on the widget, add them as constructor parameters and pass from the parent.

**Important constraints:**
- Keep ALL existing guard checks from the current implementation
- Keep the wave flash animation logic from the existing `done` phase
- Keep `widget.onAiStateChanged` callbacks that drive the parent's `_PaperHeader` progress UI
- Keep the per-row animation stagger from the existing `assigning` phase (but now it triggers when grades arrive via stream, not when fake scores are generated)
- Both desktop (`_GradeSpreadsheetState`) and mobile (`_GradeListState`) get the SAME logic
- Do NOT modify `_AiPhase` enum
- Do NOT break manual grade entry — it must still work independently
- Error states should reset to `_AiPhase.idle` and show a `SnackBar` with the error message

**Update after completion:**
- [x] Mark this task `[x]`

---

## Dependency & Parallelism Summary

```
Server S1 (proto) ──► C1 (generate Dart stubs)
                          │
                          ▼
                      C2 (AiMarking service)
                          │
                          ▼
                      C3 (wire in client.dart)
                          │
                     ┌────┴────┐
                     ▼         ▼
                 C4 (scheme UI)  │
                     │         │
                     └────┬────┘
                          ▼
                      C5 (replace fake AI marking)
```

C4 can start as soon as C3 is done (parallel group P1 with any other independent work).
C5 depends on both C3 and C4.