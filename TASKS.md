# TASKS.md

## Feature: AI Usage Tracking (Client)

### Task C1: Add AI usage DAO methods on client (eduxal) — ✅ DONE

---

## Feature: File Sync — Marking Schemes & Answer Sheets

### Overview

Marking scheme files and student answer sheet files are currently **local-only**. They are saved to the device filesystem and uploaded to S3 only during the AI marking flow (ephemeral, one-shot). They do **not** sync across devices via the push/watch streams.

**Goal:** Wire both file types into the existing sync engine so that:
1. When Teacher A uploads a marking scheme on Device A, it appears on Device B.
2. When Teacher B uploads answer sheets on Device B, they appear on Device A.
3. Any device can trigger AI marking using synced files (future optimization).

### Architecture

The design follows the existing file sync pattern from AGENT.md §P9:

1. Client saves files locally → logs a sync action with a count-based payload.
2. Sync engine sends the action to the server.
3. Server creates metadata rows in new tables (`scheme_pages`, `answer_pages`), generates presigned S3 PUT URLs.
4. Server returns `ActionResponse.file_urls` with PUT URLs + relative paths.
5. Sync engine uploads local files via `_handleFileUrls` (existing logic).
6. Server changelog broadcasts to other clients via `watchChanges`.
7. Watchers receive `SyncDelta` with GET URLs → sync engine downloads via `_handleFileUrls`.
8. Downloaded files land at predictable local paths — existing UI code finds them.

**Key insight:** `FileCache` uses **relative paths** resolved against `appDir`. The current scheme/answer sheet code uses absolute paths via `getApplicationDocumentsDirectory()` directly. The client must standardize on relative paths through `FileCache` path helpers for sync to work.

### New tables (server + client mirror)

```
scheme_pages (school, exam, subject, paper, page, key, created)
  PK: (school, exam, subject, paper, page)  — paper nullable
  One scheme per subject+paper, shared across all grades/streams.

answer_pages (school, exam, student, subject, paper, page, key, created)
  PK: (school, exam, student, subject, paper, page)  — paper nullable
  Per-student answer sheets.
```

### New SyncAction values

```
uploadScheme(91)       — set/replace scheme pages for a paper
deleteScheme(92)       — remove all scheme pages for a paper
uploadAnswerSheet(93)  — set/replace answer pages for a student's paper
deleteAnswerSheet(94)  — remove all answer pages for a student's paper
```

### New InsertData tags (watch stream)

```
Tag 36: SchemePageInsert   → _applySchemePages() in DeltaWriter
Tag 37: AnswerPageInsert   → _applyAnswerPages() in DeltaWriter
```

### What already exists

| Layer | Component | Status |
|---|---|---|
| Proto | `FileUrl` message (path, put_url, get_url, expiry) | ✅ Exists |
| Proto | `ActionResponse.file_urls`, `SyncDelta.file_urls` | ✅ Exists |
| Proto | `UploadSchemePayload`, `DeleteSchemePayload` | ❌ Needs proto regen after S1 |
| Proto | `UploadAnswerSheetPayload`, `DeleteAnswerSheetPayload` | ❌ Needs proto regen after S1 |
| Proto | `SchemePageInsert` (InsertData tag 36) | ❌ Needs proto regen after S1 |
| Proto | `AnswerPageInsert` (InsertData tag 37) | ❌ Needs proto regen after S1 |
| Sync engine | `_handleFileUrls()` — uploads PUT / downloads GET | ✅ Exists, works as-is |
| FileCache | `upload()`, `download()`, `_resolve()` with relative paths | ✅ Exists |
| FileCache | Path helpers for schemes/answers | ❌ Missing |
| Drift table | `SchemePages` | ❌ Missing |
| Drift table | `AnswerPages` | ❌ Missing |
| Drift table | `PaperSubmissions` (client-only, tracks local answer paths) | ✅ Exists |
| SyncAction enum | Values 91–94 | ❌ Missing |
| DeltaWriter | Cases 36, 37 | ❌ Missing |
| UI (scheme) | `_SchemeUploadSheet` — saves to filesystem, no sync log | ⚠️ Needs sync wiring |
| UI (answers) | `_AnswerSubmissionSheet` — saves to filesystem + `paper_submissions`, no sync log | ⚠️ Needs sync wiring |

### Dependency Graph

```
S1 (proto definitions) ──── BLOCKING ── all other tasks wait for this
    │
    ├──→ S2, S3, S4, S5 (server — sequential)
    │
    └──→ C2 (proto regen on client)
           │
           └──→ C3 (Drift tables + enum + migration)
                  │
                  ├──→ C4 (DeltaWriter)      ─┐
                  ├──→ C5 (FileCache paths)   ─┤── Parallel group P2
                  │                            │
                  └──→ C6 (scheme sync wiring) ─┘── Depends on C4 + C5
                         │
                         └──→ C7 (answer sync wiring) ── Depends on C6
                                │
                                └──→ C8 (post-download hooks) ── Depends on C4 + C7
```

---

### Task C2: Regenerate proto stubs after S1

**Files to modify:** `lib/proto/services/sync.pb.dart`, `lib/proto/services/sync.pbgrpc.dart`, `lib/proto/services/sync.pbjson.dart`
**Depends on:** S1 (server proto definitions — BLOCKING)
**Parallel group:** —

**Specification:**

After the server completes S1 (proto definitions), copy the updated `sync.proto` file and regenerate Dart stubs:

```bash
# From the eduxal project root:
protoc --dart_out=grpc:lib/proto -Iproto proto/services/sync.proto
```

Alternatively, if the project owner provides pre-generated `.pb.dart` files, copy them directly into `lib/proto/services/`.

**Verify these new types exist after generation:**
- `UploadSchemePayload` — fields: school, exam, subject, paper (optional), count
- `DeleteSchemePayload` — fields: school, exam, subject, paper (optional)
- `UploadAnswerSheetPayload` — fields: school, exam, student, subject, paper (optional), count
- `DeleteAnswerSheetPayload` — fields: school, exam, student, subject, paper (optional)
- `SchemePageInsert` — fields: school, exam, subject, paper (optional), page, key, created
- `AnswerPageInsert` — fields: school, exam, student, subject, paper (optional), page, key, created
- `ActionRequest` oneof includes new payload tags for all 4 actions
- `InsertData` oneof includes `scheme_page` (tag 36) and `answer_page` (tag 37)

**Update after completion:**
- [ ] Proto stubs regenerated and compile cleanly
- [ ] New message types verified
- [ ] Mark this task `[x]`
- [ ] git commit: `chore: regenerate proto stubs with scheme/answer file sync messages`

---

### Task C3: Add Drift tables, SyncAction enum values, and schema migration

**Files to create:** `lib/database/tables/scheme_pages.dart`, `lib/database/tables/answer_pages.dart`
**Files to modify:** `lib/database/tables/enums.dart`, `lib/database/database.dart`
**Context files to read:** `lib/database/tables/papers.dart` (for nullable paper PK pattern), `lib/database/database.dart`
**Depends on:** C2
**Parallel group:** —

**Specification:**

#### Step 1 — Create `lib/database/tables/scheme_pages.dart`:

```dart
import 'package:drift/drift.dart';
import 'schools.dart';
import 'exams.dart';

class SchemePages extends Table {
  @override
  String get tableName => 'scheme_pages';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get subject => integer()();
  IntColumn get paper => integer().nullable()();
  IntColumn get page => integer()();
  TextColumn get key => text()(); // S3 object key
  Int64Column get created => int64()();

  // paper is nullable in the composite PK — same pattern as papers/grades.
  // Drift does not support nullable columns in primaryKey, so use
  // customConstraints.
  @override
  List<String> get customConstraints => [
    'PRIMARY KEY (school, exam, subject, paper, page)',
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
```

#### Step 2 — Create `lib/database/tables/answer_pages.dart`:

```dart
import 'package:drift/drift.dart';
import 'schools.dart';
import 'exams.dart';

class AnswerPages extends Table {
  @override
  String get tableName => 'answer_pages';

  TextColumn get school =>
      text().references(Schools, #id, onDelete: KeyAction.cascade)();
  TextColumn get exam =>
      text().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get student => integer()();
  IntColumn get subject => integer()();
  IntColumn get paper => integer().nullable()();
  IntColumn get page => integer()();
  TextColumn get key => text()(); // S3 object key
  Int64Column get created => int64()();

  @override
  List<String> get customConstraints => [
    'PRIMARY KEY (school, exam, student, subject, paper, page)',
    'FOREIGN KEY (school, student) REFERENCES students(school, adm) ON DELETE CASCADE',
    'FOREIGN KEY (subject) REFERENCES subjects(id) ON DELETE CASCADE',
  ];
}
```

#### Step 3 — Add SyncAction values in `lib/database/tables/enums.dart`:

After `removeExamGrade(90)`, add:

```dart
  // Scheme pages (marking scheme file sync)
  uploadScheme(91), deleteScheme(92),
  // Answer pages (student answer sheet file sync)
  uploadAnswerSheet(93), deleteAnswerSheet(94);
```

Change the semicolon after `removeExamGrade(90)` to a comma first.

#### Step 4 — Register in `lib/database/database.dart`:

1. Add imports:
   ```dart
   import 'tables/scheme_pages.dart';
   import 'tables/answer_pages.dart';
   ```

2. Add `SchemePages` and `AnswerPages` to the `tables: [...]` list in `@DriftDatabase` (after `AiUsage` and before `Scopes`).

3. Add to `deleteAllData()` — delete `scheme_pages` and `answer_pages` before `papers` (they reference papers via subject FK):
   ```dart
   await delete(schemePages).go();
   await delete(answerPages).go();
   ```

4. Bump `schemaVersion` from 5 to 6.

5. Add migration in `onUpgrade`:
   ```dart
   if (from < 6) {
     await m.createTable(schemePages);
     await m.createTable(answerPages);
   }
   ```

#### Step 5 — Run codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Update after completion:**
- [ ] Create `lib/database/tables/scheme_pages.dart`
- [ ] Create `lib/database/tables/answer_pages.dart`
- [ ] Add `uploadScheme(91)`, `deleteScheme(92)`, `uploadAnswerSheet(93)`, `deleteAnswerSheet(94)` to `SyncAction` enum
- [ ] Register tables in `database.dart`, bump schema to v6, add migration
- [ ] Add to `deleteAllData()` in correct order
- [ ] Run `build_runner` — codegen succeeds
- [ ] Update `lib/database/tables/CONTEXT.md`
- [ ] Update `lib/database/CONTEXT.md` (schema version, new tables)
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: add SchemePages and AnswerPages Drift tables + SyncAction 91-94 + schema v6`

---

### Task C4: Add DeltaWriter handlers for scheme_pages (table 36) and answer_pages (table 37)

**Files to modify:** `lib/sync/delta_writer.dart`
**Context files to read:** `lib/database/tables/scheme_pages.dart`, `lib/database/tables/answer_pages.dart`, existing `_applyPapers()` and `_applyGrades()` in delta_writer.dart for nullable-paper patterns
**Depends on:** C3
**Parallel group:** P2

**Specification:**

Add two new cases to the table dispatch `switch` in `DeltaWriter.apply()`:

```dart
case 36:
  await _applySchemePages(delta);
case 37:
  await _applyAnswerPages(delta);
```

#### `_applySchemePages(SyncDelta delta)`:

rowKey format: `"{school}|{exam}|{subject}|{paper}|{page}"` where paper is empty string when NULL.

```dart
Future<void> _applySchemePages(SyncDelta delta) async {
  final k = _parseKey(delta.rowKey);
  final paperVal = _parseIntNullable(k[3]);
  final pageVal = _parseInt(k[4]);

  if (delta.operation == 2) {
    // DELETE
    await _db.customStatement(
      'DELETE FROM scheme_pages WHERE school = ? AND exam = ? AND subject = ?'
      ' AND paper ${paperVal == null ? 'IS NULL' : '= ?'}'
      ' AND page = ?',
      [k[0], k[1], _parseInt(k[2]), ?paperVal, pageVal],
    );
    return;
  }

  final row = delta.data.schemePage;

  if (paperVal == null) {
    // NULL paper — delete-then-insert (SQLite NULL != NULL in PK).
    await _db.customStatement(
      'DELETE FROM scheme_pages WHERE school = ? AND exam = ? AND subject = ?'
      ' AND paper IS NULL AND page = ?',
      [k[0], k[1], _parseInt(k[2]), pageVal],
    );
    await _db.customStatement(
      'INSERT INTO scheme_pages (school, exam, subject, paper, page, key, created)'
      ' VALUES (?, ?, ?, NULL, ?, ?, ?)',
      [k[0], k[1], _parseInt(k[2]), pageVal, row.key, row.created.toInt()],
    );
  } else {
    await _db.customStatement(
      'INSERT INTO scheme_pages (school, exam, subject, paper, page, key, created)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (school, exam, subject, paper, page) DO UPDATE SET'
      ' key = excluded.key,'
      ' created = excluded.created',
      [k[0], k[1], _parseInt(k[2]), paperVal, pageVal, row.key, row.created.toInt()],
    );
  }
}
```

#### `_applyAnswerPages(SyncDelta delta)`:

rowKey format: `"{school}|{exam}|{student}|{subject}|{paper}|{page}"` where paper is empty string when NULL.

```dart
Future<void> _applyAnswerPages(SyncDelta delta) async {
  final k = _parseKey(delta.rowKey);
  final paperVal = _parseIntNullable(k[4]);
  final pageVal = _parseInt(k[5]);

  if (delta.operation == 2) {
    await _db.customStatement(
      'DELETE FROM answer_pages WHERE school = ? AND exam = ? AND student = ? AND subject = ?'
      ' AND paper ${paperVal == null ? 'IS NULL' : '= ?'}'
      ' AND page = ?',
      [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), ?paperVal, pageVal],
    );
    return;
  }

  final row = delta.data.answerPage;

  if (paperVal == null) {
    await _db.customStatement(
      'DELETE FROM answer_pages WHERE school = ? AND exam = ? AND student = ? AND subject = ?'
      ' AND paper IS NULL AND page = ?',
      [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), pageVal],
    );
    await _db.customStatement(
      'INSERT INTO answer_pages (school, exam, student, subject, paper, page, key, created)'
      ' VALUES (?, ?, ?, ?, NULL, ?, ?, ?)',
      [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), pageVal, row.key, row.created.toInt()],
    );
  } else {
    await _db.customStatement(
      'INSERT INTO answer_pages (school, exam, student, subject, paper, page, key, created)'
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
      ' ON CONFLICT (school, exam, student, subject, paper, page) DO UPDATE SET'
      ' key = excluded.key,'
      ' created = excluded.created',
      [k[0], k[1], _parseInt(k[2]), _parseInt(k[3]), paperVal, pageVal, row.key, row.created.toInt()],
    );
  }
}
```

**Update after completion:**
- [ ] Add `case 36: await _applySchemePages(delta);`
- [ ] Add `case 37: await _applyAnswerPages(delta);`
- [ ] Implement `_applySchemePages()` with nullable-paper handling
- [ ] Implement `_applyAnswerPages()` with nullable-paper handling
- [ ] Verify no analysis errors
- [ ] Update `lib/sync/CONTEXT.md` if it exists
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: add DeltaWriter handlers for scheme_pages (36) and answer_pages (37)`

---

### Task C5: Add FileCache path helpers and standardize local file storage

**Files to modify:** `lib/cache/file_cache.dart`, `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`
**Context files to read:** `lib/cache/file_cache.dart` (current path helpers section), `_schemeDirectory()` and answer sheet directory logic in `paper_detail_page.dart`
**Depends on:** C3
**Parallel group:** P2

**Specification:**

The sync engine's `_handleFileUrls` uses `FileCache.upload(putUrl, relativePath)` and `FileCache.download(getUrl, relativePath)`. Both resolve `relativePath` against `appDir`. For file sync to work, the scheme and answer sheet files must use relative paths through FileCache — not absolute paths via `getApplicationDocumentsDirectory()`.

#### Step 1 — Add path helpers to `lib/cache/file_cache.dart`:

Add to the "Path helpers" section (after `studentImagePath`):

```dart
/// Relative path for a marking scheme page image.
///
/// Resolves to `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/scheme/{page}.jpg`.
/// [paper] is the paper number; pass 0 for single-paper subjects (paper=NULL).
static String schemePath(String schoolId, String examId, int subject, int paper, int page) =>
    'submissions/$schoolId/$examId/${subject}_$paper/scheme/$page.jpg';

/// Directory (relative) containing all scheme pages for a paper.
static String schemeDir(String schoolId, String examId, int subject, int paper) =>
    'submissions/$schoolId/$examId/${subject}_$paper/scheme';

/// Relative path for a student answer sheet page image.
///
/// Resolves to `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/{adm}/{page}.jpg`.
static String answerPath(String schoolId, String examId, int subject, int paper, int adm, int page) =>
    'submissions/$schoolId/$examId/${subject}_$paper/$adm/$page.jpg';

/// Directory (relative) containing all answer pages for a student's paper.
static String answerDir(String schoolId, String examId, int subject, int paper, int adm) =>
    'submissions/$schoolId/$examId/${subject}_$paper/$adm';
```

#### Step 2 — Update `_PaperDetailPageState._schemeDirectory()`:

Replace the current absolute-path logic with FileCache-based resolution:

```dart
Future<Directory> _schemeDirectory() async {
  final base = await FileCache.baseDir(); // Need to expose _baseDir or use getApplicationDocumentsDirectory
  final rel = FileCache.schemeDir(
    widget.schoolId,
    _exam.id,
    _paper.subject,
    _paper.paper ?? 0,
  );
  return Directory('$base/$rel');
}
```

**Note:** `FileCache._baseDir()` is currently private. Either:
- Make it public: `static Future<String> baseDir() async { ... }` (preferred — simple, non-breaking)
- Or keep using `getApplicationDocumentsDirectory()` with the same relative path convention as FileCache.

Choose making it public — add `static Future<String> baseDir() => _baseDir();` to FileCache's public API.

#### Step 3 — Update `_SchemeUploadSheetState._schemeDirectory()`:

Same change as Step 2 — use FileCache path helpers.

#### Step 4 — Update `_AnswerSubmissionSheetState._savePickedFiles()`:

The answer sheet directory currently uses:
```dart
final dir = Directory(
  '${appDir.path}/submissions/${widget.schoolId}/${widget.examId}/$paperSuffix/${widget.student.adm}',
);
```

Update to use FileCache:
```dart
final base = await FileCache.baseDir();
final rel = FileCache.answerDir(
  widget.schoolId,
  widget.examId,
  widget.subject,
  widget.paperNum ?? 0,
  widget.student.adm,
);
final dir = Directory('$base/$rel');
```

#### Step 5 — Standardize file naming to 0-indexed:

The scheme files already use 0-indexed naming (`0.jpg`, `1.jpg`, ...). The answer sheet files currently use 1-indexed naming. Change answer sheet `_savePickedFiles` to use 0-indexed:

```dart
// Before: final index = _paths.length + newPaths.length + 1;
// After:
final index = _paths.length + newPaths.length; // 0-indexed
```

#### Step 6 — Add re-indexing on file removal:

In `_SchemeUploadSheetState._removePhoto()`, after removing a file, re-index the remaining files on disk so there are no gaps:

```dart
Future<void> _removePhoto(int index) async {
  final removedPath = _paths[index];
  try {
    final file = File(removedPath);
    if (await file.exists()) await file.delete();
  } catch (_) {}
  setState(() => _paths.removeAt(index));

  // Re-index remaining files on disk to fill the gap.
  final dir = await _schemeDirectory();
  for (int i = index; i < _paths.length; i++) {
    final oldFile = File(_paths[i]);
    final newDest = File('${dir.path}/$i.jpg');
    if (oldFile.path != newDest.path && await oldFile.exists()) {
      await oldFile.rename(newDest.path);
      _paths[i] = newDest.path;
    }
  }

  widget.onUpdated();
}
```

Add similar re-indexing to `_AnswerSubmissionSheetState._removePhoto()`.

**Update after completion:**
- [ ] Add `schemePath`, `schemeDir`, `answerPath`, `answerDir` helpers to FileCache
- [ ] Expose `FileCache.baseDir()` as a public static method
- [ ] Update `_schemeDirectory()` in both `_PaperDetailPageState` and `_SchemeUploadSheetState`
- [ ] Update answer sheet directory logic in `_AnswerSubmissionSheetState`
- [ ] Standardize answer file naming to 0-indexed
- [ ] Add re-indexing on file removal for both scheme and answer sheets
- [ ] Verify no analysis errors
- [ ] Mark this task `[x]`
- [ ] git commit: `refactor: standardize scheme/answer file paths through FileCache helpers`

---

### Task C6: Wire scheme upload/replace/delete to sync log

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/database/daos/exams_grades_dao.dart`
**Context files to read:** `lib/database/daos/exams_grades_dao.dart` (for log insertion pattern), `lib/proto/services/sync.pb.dart` (for `UploadSchemePayload`, `DeleteSchemePayload`)
**Depends on:** C4, C5
**Parallel group:** —

**Specification:**

When the user adds, replaces, or removes scheme files, log a sync action so the sync engine pushes the change to the server.

#### Step 1 — Add DAO methods for scheme sync logging:

In `ExamsGradesDao`, add:

```dart
/// Logs an [uploadScheme] sync action for the given paper's scheme.
/// Called after the user adds or replaces scheme files locally.
///
/// [count] is the total number of scheme pages after the change.
Future<void> logUploadScheme({
  required String schoolId,
  required String examId,
  required int subject,
  required int? paper,
  required int count,
  required String accountId,
}) async {
  final payload = UploadSchemePayload()
    ..school = schoolId
    ..exam = examId
    ..subject = subject
    ..count = count;
  if (paper != null) payload.paper = paper;

  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  await into(logs).insert(
    LogsCompanion(
      account: Value(accountId),
      action: Value(SyncAction.uploadScheme),
      resource: Value('Marking scheme'),
      payload: Value(payload.writeToBuffer()),
      created: Value(now),
    ),
  );
}

/// Logs a [deleteScheme] sync action.
/// Called when the user removes all scheme files for a paper.
Future<void> logDeleteScheme({
  required String schoolId,
  required String examId,
  required int subject,
  required int? paper,
  required String accountId,
}) async {
  final payload = DeleteSchemePayload()
    ..school = schoolId
    ..exam = examId
    ..subject = subject;
  if (paper != null) payload.paper = paper;

  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  await into(logs).insert(
    LogsCompanion(
      account: Value(accountId),
      action: Value(SyncAction.deleteScheme),
      resource: Value('Marking scheme'),
      payload: Value(payload.writeToBuffer()),
      created: Value(now),
    ),
  );
}
```

Add the required import at the top of `exams_grades_dao.dart`:
```dart
import '../../proto/services/sync.pb.dart' show UploadSchemePayload, DeleteSchemePayload, UploadAnswerSheetPayload, DeleteAnswerSheetPayload;
```

#### Step 2 — Wire into `_SchemeUploadSheetState`:

After every mutation that changes the scheme file set, call the DAO to log the action. The sheet already calls `widget.onUpdated()` which triggers `_loadSchemeFiles()`. We need to also log:

**In `_savePickedFiles()` (after files are saved):**
```dart
// After: widget.onUpdated();
final accountId = cache.currentUser?.user.id;
if (accountId != null) {
  final dao = ExamsGradesDao(db);
  await dao.logUploadScheme(
    schoolId: widget.schoolId,
    examId: widget.examId,
    subject: widget.subject,
    paper: widget.paperNum,
    count: _paths.length,
    accountId: accountId,
  );
}
```

**In `_removePhoto()` (after re-indexing):**
```dart
final accountId = cache.currentUser?.user.id;
if (accountId != null) {
  final dao = ExamsGradesDao(db);
  if (_paths.isEmpty) {
    await dao.logDeleteScheme(
      schoolId: widget.schoolId,
      examId: widget.examId,
      subject: widget.subject,
      paper: widget.paperNum,
      accountId: accountId,
    );
  } else {
    await dao.logUploadScheme(
      schoolId: widget.schoolId,
      examId: widget.examId,
      subject: widget.subject,
      paper: widget.paperNum,
      count: _paths.length,
      accountId: accountId,
    );
  }
}
```

**In `_replaceAll()` (after new photos are taken — `_takePhoto` calls `_savePickedFiles` which logs):**
Before calling `_takePhoto()`, log a `deleteScheme` to clear server state. The subsequent `_takePhoto → _savePickedFiles` will log the new `uploadScheme`.

Actually, simpler: `_replaceAll` deletes all then takes new photos. The `_savePickedFiles` in `_takePhoto` will log `uploadScheme` with the new count. We just need to handle the case where the user cancels the camera (count stays 0 → should still delete). Add a `deleteScheme` log at the top of `_replaceAll`:

```dart
final accountId = cache.currentUser?.user.id;
if (accountId != null) {
  await ExamsGradesDao(db).logDeleteScheme(
    schoolId: widget.schoolId,
    examId: widget.examId,
    subject: widget.subject,
    paper: widget.paperNum,
    accountId: accountId,
  );
}
```

The `_takePhoto → _savePickedFiles` path will then log `uploadScheme` with the new count if photos are taken.

#### Step 3 — Add proto import to `paper_detail_page.dart`:

```dart
import '../../../../proto/services/sync.pb.dart' show UploadSchemePayload, DeleteSchemePayload;
```

The `db` global and `cache` are already imported.

**Update after completion:**
- [ ] Add `logUploadScheme()` and `logDeleteScheme()` to `ExamsGradesDao`
- [ ] Wire `_savePickedFiles()` in scheme sheet to log `uploadScheme`
- [ ] Wire `_removePhoto()` in scheme sheet to log `uploadScheme` or `deleteScheme`
- [ ] Wire `_replaceAll()` to log `deleteScheme` before clearing
- [ ] Add proto imports
- [ ] Verify no analysis errors
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: wire marking scheme upload/delete to sync action log`

---

### Task C7: Wire answer sheet upload/delete to sync log

**Files to modify:** `lib/ui/screens/school_dashboard/academics/paper_detail_page.dart`, `lib/database/daos/exams_grades_dao.dart`
**Context files to read:** Task C6 (same pattern), `_AnswerSubmissionSheetState` in `paper_detail_page.dart`
**Depends on:** C6 (proto import + DAO pattern established)
**Parallel group:** —

**Specification:**

Same pattern as C6 but for answer sheets.

#### Step 1 — Add DAO methods:

In `ExamsGradesDao`, add:

```dart
/// Logs an [uploadAnswerSheet] sync action for a student's answer pages.
Future<void> logUploadAnswerSheet({
  required String schoolId,
  required String examId,
  required int student,
  required int subject,
  required int? paper,
  required int count,
  required String accountId,
}) async {
  final payload = UploadAnswerSheetPayload()
    ..school = schoolId
    ..exam = examId
    ..student = student
    ..subject = subject
    ..count = count;
  if (paper != null) payload.paper = paper;

  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  await into(logs).insert(
    LogsCompanion(
      account: Value(accountId),
      action: Value(SyncAction.uploadAnswerSheet),
      resource: Value('Answer sheet — student $student'),
      payload: Value(payload.writeToBuffer()),
      created: Value(now),
    ),
  );
}

/// Logs a [deleteAnswerSheet] sync action.
Future<void> logDeleteAnswerSheet({
  required String schoolId,
  required String examId,
  required int student,
  required int subject,
  required int? paper,
  required String accountId,
}) async {
  final payload = DeleteAnswerSheetPayload()
    ..school = schoolId
    ..exam = examId
    ..student = student
    ..subject = subject;
  if (paper != null) payload.paper = paper;

  final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
  await into(logs).insert(
    LogsCompanion(
      account: Value(accountId),
      action: Value(SyncAction.deleteAnswerSheet),
      resource: Value('Answer sheet — student $student'),
      payload: Value(payload.writeToBuffer()),
      created: Value(now),
    ),
  );
}
```

#### Step 2 — Wire into `_AnswerSubmissionSheetState`:

**In `_savePickedFiles()` (after files saved + `paper_submissions` inserted):**
```dart
final accountId = cache.currentUser?.user.id;
if (accountId != null) {
  await widget.dao.logUploadAnswerSheet(
    schoolId: widget.schoolId,
    examId: widget.examId,
    student: widget.student.adm,
    subject: widget.subject,
    paper: widget.paperNum,
    count: _paths.length,
    accountId: accountId,
  );
}
```

**In `_removePhoto()` (after removal):**
```dart
final accountId = cache.currentUser?.user.id;
if (accountId != null) {
  if (_paths.isEmpty) {
    await widget.dao.logDeleteAnswerSheet(
      schoolId: widget.schoolId,
      examId: widget.examId,
      student: widget.student.adm,
      subject: widget.subject,
      paper: widget.paperNum,
      accountId: accountId,
    );
  } else {
    await widget.dao.logUploadAnswerSheet(
      schoolId: widget.schoolId,
      examId: widget.examId,
      student: widget.student.adm,
      subject: widget.subject,
      paper: widget.paperNum,
      count: _paths.length,
      accountId: accountId,
    );
  }
}
```

#### Step 3 — Add re-indexing to `_AnswerSubmissionSheetState._removePhoto()`:

Same pattern as scheme sheet (Task C5 Step 6). After removing the file, re-index remaining files on disk and update `_paths` list. Also update `paper_submissions` rows to reflect new paths.

**Update after completion:**
- [ ] Add `logUploadAnswerSheet()` and `logDeleteAnswerSheet()` to `ExamsGradesDao`
- [ ] Wire `_savePickedFiles()` in answer sheet to log `uploadAnswerSheet`
- [ ] Wire `_removePhoto()` in answer sheet to log `uploadAnswerSheet` or `deleteAnswerSheet`
- [ ] Add re-indexing on removal
- [ ] Verify no analysis errors
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: wire answer sheet upload/delete to sync action log`

---

### Task C8: Post-download hooks — populate paper_submissions after answer file download

**Files to modify:** `lib/sync/sync_engine.dart`
**Context files to read:** `lib/sync/sync_engine.dart` (watch stream handler + `_handleFileUrls`), `lib/database/daos/exams_grades_dao.dart` (`insertSubmission`)
**Depends on:** C4, C7
**Parallel group:** —

**Specification:**

When a watcher receives answer sheet files via the watch stream, the sync engine downloads them via `_handleFileUrls`. After download, we need to insert `paper_submissions` rows so the existing UI code discovers the files.

For scheme files, no post-download hook is needed — the UI uses filesystem directory listing (`_loadSchemeFiles`), and the downloaded files land at the expected paths.

#### Step 1 — Extend the watch stream handler in `sync_engine.dart`:

After the existing `_handleFileUrls` call for watch deltas, add a post-processing step for answer_pages deltas:

Find this section (around line 782):
```dart
await _deltaWriter.apply(delta);

// Download files from S3 if the server provided GET URLs.
if (delta.fileUrls.isNotEmpty) {
  await _handleFileUrls(delta.fileUrls, isPushOriginator: false);
}
```

After the `_handleFileUrls` call, add:
```dart
// After downloading answer sheet files, insert paper_submissions rows
// so the UI discovers the files.
if (delta.table == 37 && delta.operation != 2 && delta.fileUrls.isNotEmpty) {
  await _insertAnswerSubmissions(delta);
}
```

#### Step 2 — Implement `_insertAnswerSubmissions`:

```dart
/// After downloading answer sheet files from the watch stream, insert
/// [PaperSubmissions] rows so the existing UI can find them via DAO queries.
Future<void> _insertAnswerSubmissions(sync_pb.SyncDelta delta) async {
  try {
    final k = delta.rowKey.split('|');
    // rowKey: "{school}|{exam}|{student}|{subject}|{paper}|{page}"
    if (k.length < 6) return;

    final schoolId = k[0];
    final examId = k[1];
    final student = int.tryParse(k[2]) ?? 0;
    final subject = int.tryParse(k[3]) ?? 0;
    final paper = k[4].isEmpty ? null : int.tryParse(k[4]);

    for (final fileUrl in delta.fileUrls) {
      if (fileUrl.path.isEmpty) continue;
      // Resolve to absolute path for paper_submissions storage.
      final base = await FileCache.baseDir();
      final absPath = '$base/${fileUrl.path}';

      // Only insert if the file was actually downloaded successfully.
      final file = File(absPath);
      if (!file.existsSync()) continue;

      await _examsGradesDao.insertSubmission(
        schoolId: schoolId,
        examId: examId,
        student: student,
        subject: subject,
        paperNum: paper,
        path: absPath,
      );
    }
  } catch (e) {
    debugPrint('[SyncEngine] Error inserting answer submissions: $e');
  }
}
```

This requires `_examsGradesDao` to be available in the SyncEngine. Check if it already is — if not, add it as a constructor parameter or instantiate it from the database reference.

#### Step 3 — Add FileCache import to sync_engine.dart (if not already imported):

```dart
import '../cache/file_cache.dart';
```

**Update after completion:**
- [ ] Add post-download hook for answer_pages deltas (table 37)
- [ ] Implement `_insertAnswerSubmissions()` helper
- [ ] Ensure `ExamsGradesDao` is accessible in SyncEngine (add if missing)
- [ ] Add necessary imports
- [ ] Verify no analysis errors
- [ ] Update `lib/sync/CONTEXT.md` if it exists
- [ ] Mark this task `[x]`
- [ ] git commit: `feat: insert paper_submissions rows after downloading synced answer sheets`

---

### Notes

#### Future optimization: AI marking with synced files

Once file sync is working, the AI marking flow (`runAiMarking` in `_GradeSpreadsheetState` / `_GradeListState`) could be optimized to reference existing S3 keys from `scheme_pages` and `answer_pages` tables instead of re-uploading all files. This would skip Phases 2 and 3 of the marking flow entirely. Not in scope for this task group.

#### Push originator file path mapping

When the sync engine processes an `uploadScheme` action response, it receives `FileUrl` entries with:
- `path`: relative path like `submissions/{school}/{exam}/{subj}_{paper}/scheme/0.jpg`
- `putUrl`: presigned S3 PUT URL

The sync engine calls `FileCache.upload(putUrl, path)` which resolves the relative path to `{appDir}/submissions/...`. This works because Task C5 standardizes local file storage to match these relative paths.

The server must construct `FileUrl.path` using the same convention. This is documented in the server task S3.

#### Handling re-uploads after file changes

`uploadScheme` and `uploadAnswerSheet` are idempotent-replace operations. The server:
1. Deletes all existing rows for that paper (or student+paper).
2. Creates N new rows with fresh S3 keys.
3. Returns PUT URLs for all N pages.

The client uploads all local files, not just the changed ones. This is simple and correct — the server always has the complete set.