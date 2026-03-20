# cache/ — File Cache Context

> Static utility class for caching files (profile images, school logos, student photos) at constant, predictable local paths on the device file system.

## Overview

This directory contains **1 file**. The file cache is a purely static utility — no instances, no state beyond a lazily-resolved base directory path. Files are stored at deterministic paths derived from entity identity (never random or timestamped), so any part of the app can construct the expected path and check for a cached file without consulting a database column.

## Files

| File | Key Exports | Status |
|---|---|---|
| `file_cache.dart` | `FileCache` (static class), `FileCacheNotifier` (static notifier) | ✅ Complete |

## `FileCache` — Detailed API

**Constructor:** Private (`FileCache._()`) — purely static, never instantiated.

### Path Helpers (static)

| Method | Returns | Resolves to |
|---|---|---|
| `profilePath(String userId)` | `String` | `users/{userId}/profile` |
| `logoPath(String schoolId)` | `String` | `schools/{schoolId}/logo` |
| `studentImagePath(String schoolId, int adm)` | `String` | `schools/{schoolId}/students/{adm}/image` |
| `schemePath(String schoolId, String examId, int subject, int paper, int page)` | `String` | `submissions/{schoolId}/{examId}/{subject}_{paper}/scheme/{page}.jpg` |
| `schemeDir(String schoolId, String examId, int subject, int paper)` | `String` | `submissions/{schoolId}/{examId}/{subject}_{paper}/scheme` |
| `answerPath(String schoolId, String examId, int subject, int paper, int adm, int page)` | `String` | `submissions/{schoolId}/{examId}/{subject}_{paper}/{adm}/{page}.jpg` |
| `answerDir(String schoolId, String examId, int subject, int paper, int adm)` | `String` | `submissions/{schoolId}/{examId}/{subject}_{paper}/{adm}` |

Pass `paper = 0` for single-paper subjects (where `paper` is NULL in the database). All paths are **relative** — they are resolved against the app documents directory at runtime. The full path is `{appDir}/{relativePath}`.

### Core Methods (static, async)

| Method | Signature | Description |
|---|---|---|
| `baseDir` | `Future<String> baseDir()` | Returns the resolved application documents directory path (lazily cached). Public wrapper around `_baseDir()`. Use when you need the absolute base to combine with a relative path helper result. |
| `get` | `Future<File?> get(String relativePath)` | Returns the `File` at the given path if it exists on disk, or `null`. No network call. |
| `upload` | `Future<bool> upload(String putUrl, String relativePath)` | HTTP PUT of the local file at `relativePath` to S3 `putUrl`. File must already exist locally. Returns `true` on 2xx, `false` on any error (missing file, network error, non-2xx). Content-Type: `application/octet-stream`. Errors swallowed silently. |
| `download` | `Future<File?> download(String url, String relativePath)` | HTTP GET from `url`, saves to `relativePath`. Creates parent dirs. Overwrites existing. Returns `File` on success, `null` on any error. Errors swallowed silently. |
| `saveBytes` | `Future<File?> saveBytes(List<int> bytes, String relativePath)` | Writes raw bytes to `relativePath`. Creates parent dirs. Overwrites existing. Returns `File` on success, `null` on error. Used for locally-picked images (e.g. from `image_picker`). |
| `delete` | `Future<void> delete(String relativePath)` | Deletes the file at `relativePath` if it exists. No-op if absent. Errors silently ignored. |
| `loadTimetableRules` | `Future<TimetableRules> loadTimetableRules({required String schoolId, required int year, required int term})` | Reads `timetable_rules_{year}_{term}.json` from `{appDir}/schools/{schoolId}/`. Returns `TimetableRules.defaults()` if the file does not exist or JSON parsing fails. |
| `saveTimetableRules` | `Future<void> saveTimetableRules({required String schoolId, required int year, required int term, required TimetableRules rules})` | Writes `rules` as JSON to `{appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json`. Creates parent directories if they do not exist. |

### `FileCacheNotifier` — Live File Change Signals

A lightweight static registry of `ChangeNotifier`s keyed by relative path. Allows UI widgets to rebuild immediately when a cached file is written or updated on disk — without polling or navigating away and back.

| Member | Signature | Description |
|---|---|---|
| `of` | `static ChangeNotifier of(String path)` | Returns the `ChangeNotifier` for `path`, creating it lazily if needed. Widgets call `addListener` / `removeListener` on this. |
| `notify` | `static void notify(String path)` | Fires all listeners registered for `path`. Called internally after every file write (`download`, `saveBytes`) and by `services/members.dart` after `sourceFile.copy()`. |

**When `notify` is called:**
- `FileCache.download()` — after `file.writeAsBytes(..., flush: true)`
- `FileCache.saveBytes()` — after `file.writeAsBytes(..., flush: true)`
- `MemberCreationService.saveStudentImage()` — after `sourceFile.copy(targetPath)` (via `FileCacheNotifier.notify(FileCache.studentImagePath(schoolId, adm))`)
- `MemberCreationService.saveUserProfileImage()` — after `sourceFile.copy(targetPath)` (via `FileCacheNotifier.notify(FileCache.profilePath(userId))`)

**Widget pattern (StatefulWidget):**
```dart
@override
void initState() {
  super.initState();
  _path = FileCache.studentImagePath(widget.schoolId, widget.adm);
  _future = FileCache.get(_path);
  FileCacheNotifier.of(_path).addListener(_onFileChanged);
}

@override
void dispose() {
  FileCacheNotifier.of(_path).removeListener(_onFileChanged);
  super.dispose();
}

void _onFileChanged() => setState(() { _future = FileCache.get(_path); });
```

**Widgets already converted to use this pattern:**
- `lib/ui/widgets/student_avatar.dart` — `StudentAvatar` (shared widget used in `exam_detail_page.dart`, `paper_detail_page.dart`)
- `lib/ui/screens/school_dashboard/academics/tabs/students_tab.dart` — `_StudentAvatar`
- `lib/ui/screens/school_dashboard/members/members_page.dart` — `_StudentAvatar`
- `lib/ui/screens/school_dashboard/academics/student_grade_page.dart` — `_StudentAvatar`
- `lib/ui/screens/school_dashboard/members/student_detail_page.dart` — `_StudentAvatarLarge`

### Internal

- `_appDir` — `String?`, lazily initialized. Resolved once via `path_provider`'s `getApplicationDocumentsDirectory()` and cached for process lifetime.
- `_baseDir()` — `Future<String>`, resolves `_appDir` on first call. Also exposed publicly as `baseDir()`.
- `_resolve(String relativePath)` — `Future<File>`, combines `_baseDir()` + `relativePath`.
- `_collectBytes(HttpClientResponse)` — `Future<List<int>>`, accumulates all byte chunks from an HTTP response into a single flat list.

### Error Handling

All public methods **swallow errors silently** and return `null` (or void) on failure. The caller decides whether to retry. This is intentional — file caching is a best-effort operation that should never crash the app.

### Upload Implementation

Uses `dart:io`'s `HttpClient` for HTTP PUT. Streams the local file directly into the request body via `file.openRead()` — no in-memory buffering. Sets `Content-Length` and `Content-Type: application/octet-stream` headers. Drains the response body to allow connection reuse. Returns `true` on 2xx, `false` on any error.

### Download Implementation

Uses `dart:io`'s `HttpClient` (not `package:http`) for HTTP GET. Collects all bytes into memory before writing to disk to avoid leaving corrupted partial files on failure.

## File Path Conventions

| Entity | Local path pattern | Path helper |
|---|---|---|
| User profile image | `{appDir}/users/{userId}/profile` | `FileCache.profilePath(userId)` |
| Student image | `{appDir}/schools/{schoolId}/students/{adm}/image` | `FileCache.studentImagePath(schoolId, adm)` |
| School logo | `{appDir}/schools/{schoolId}/logo` | `FileCache.logoPath(schoolId)` |
| Timetable rules | `{appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json` | `FileCache.loadTimetableRules(...)` / `FileCache.saveTimetableRules(...)` |
| Marking scheme page | `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/scheme/{page}.jpg` | `FileCache.schemePath(schoolId, examId, subject, paper, page)` |
| Marking scheme dir | `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/scheme/` | `FileCache.schemeDir(schoolId, examId, subject, paper)` |
| Answer sheet page | `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/{adm}/{page}.jpg` | `FileCache.answerPath(schoolId, examId, subject, paper, adm, page)` |
| Answer sheet dir | `{appDir}/submissions/{schoolId}/{examId}/{subject}_{paper}/{adm}/` | `FileCache.answerDir(schoolId, examId, subject, paper, adm)` |
| Any future asset | `{appDir}/{entityType}/{id}/{assetName}` | Add new static helper to `FileCache` |

**Key rules:**
- **Scheme and answer page files use 0-indexed naming** (`0.jpg`, `1.jpg`, …). The page index matches the `page` column in `scheme_pages` / `answer_pages`. Pass `paper = 0` for single-paper subjects (NULL in the DB). Re-indexing on deletion maintains a gap-free sequence so the server and client always agree on page numbers.
- **No file paths or blobs in the database.** File presence is determined by checking the file system at the constant path.
- **Read URLs** (S3-like signed URLs valid ~1 month) are stored in DB columns where applicable (e.g. `accounts.profile_read_url`). Expiry is tracked via companion columns (e.g. `accounts.profile_url_expiry`).
- **Write URLs** (presigned PUT URLs valid ~1 hour) are **never stored** — used immediately for upload and discarded.
- **Offline serving:** When offline, serve from local file at constant path regardless of URL expiry.
- **Online + valid URL:** Serve from local file; re-download only if file is missing on disk.
- **Online + expired URL:** Re-fetch a fresh read URL from the server, update the DB column, re-download file.

## Dependencies

- **Depends on:** `dart:io` (`File`, `HttpClient`, `HttpClientResponse`), `package:path_provider` (`getApplicationDocumentsDirectory()`)
- **Depends on:** `dart:io` (`File`, `HttpClient`, `HttpClientResponse`), `package:path_provider` (`getApplicationDocumentsDirectory()`), `lib/models/timetable_rules.dart` (`TimetableRules`)
- **Depended on by:** `services/authentication.dart` (downloads profile image on auth), `services/members.dart` (saves profile/student images), future UI widgets (serving cached images via `FileCache.get()`), timetable UI (loads/saves `TimetableRules` via `loadTimetableRules`/`saveTimetableRules`)

## Conventions

- Path helpers are the **single canonical definition** of each path convention. No other file should construct these paths manually.
- All methods are safe to call concurrently — Dart's single-isolate model means no explicit locking is needed.
- New entity types that need cached files should add a static path helper method to `FileCache` and document the path pattern here.

## Last Updated
Tasks C3–C8 (File Sync — Marking Schemes & Answer Sheets):
- Exposed `_baseDir()` as public `static Future<String> baseDir()` — allows UI and sync engine to resolve relative paths to absolute without duplicating resolution logic.
- Added path helpers: `schemePath(schoolId, examId, subject, paper, page)`, `schemeDir(schoolId, examId, subject, paper)`, `answerPath(schoolId, examId, subject, paper, adm, page)`, `answerDir(schoolId, examId, subject, paper, adm)`.
- Updated `_PaperDetailPageState._schemeDirectory()` and `_SchemeUploadSheetState._schemeDirectory()` in `paper_detail_page.dart` to use `FileCache.baseDir()` + `FileCache.schemeDir()` instead of direct `getApplicationDocumentsDirectory()` calls.
- Updated `_AnswerSubmissionSheetState._savePickedFiles()` to use `FileCache.baseDir()` + `FileCache.answerDir()` with 0-indexed file naming (was 1-indexed).

Previous: Task A2 (TimetableRulesPersistence) — Added `FileCache.loadTimetableRules(...)` and `FileCache.saveTimetableRules(...)`.

Previous: Task 2 (FileCacheNotifier) — Added `FileCacheNotifier` class and `notify()` calls after every file write.

Previous: Task 1 — Added `FileCache.upload(String putUrl, String relativePath) → Future<bool>` for S3 HTTP PUT uploads.