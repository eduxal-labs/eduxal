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

All paths are **relative** — they are resolved against the app documents directory at runtime. The full path is `{appDir}/{relativePath}`.

### Core Methods (static, async)

| Method | Signature | Description |
|---|---|---|
| `get` | `Future<File?> get(String relativePath)` | Returns the `File` at the given path if it exists on disk, or `null`. No network call. |
| `upload` | `Future<bool> upload(String putUrl, String relativePath)` | HTTP PUT of the local file at `relativePath` to S3 `putUrl`. File must already exist locally. Returns `true` on 2xx, `false` on any error (missing file, network error, non-2xx). Content-Type: `application/octet-stream`. Errors swallowed silently. |
| `download` | `Future<File?> download(String url, String relativePath)` | HTTP GET from `url`, saves to `relativePath`. Creates parent dirs. Overwrites existing. Returns `File` on success, `null` on any error. Errors swallowed silently. |
| `saveBytes` | `Future<File?> saveBytes(List<int> bytes, String relativePath)` | Writes raw bytes to `relativePath`. Creates parent dirs. Overwrites existing. Returns `File` on success, `null` on error. Used for locally-picked images (e.g. from `image_picker`). |
| `delete` | `Future<void> delete(String relativePath)` | Deletes the file at `relativePath` if it exists. No-op if absent. Errors silently ignored. |

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
- `_baseDir()` — `Future<String>`, resolves `_appDir` on first call.
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
| Any future asset | `{appDir}/{entityType}/{id}/{assetName}` | Add new static helper to `FileCache` |

**Key rules:**
- **No file paths or blobs in the database.** File presence is determined by checking the file system at the constant path.
- **Read URLs** (S3-like signed URLs valid ~1 month) are stored in DB columns where applicable (e.g. `accounts.profile_read_url`). Expiry is tracked via companion columns (e.g. `accounts.profile_url_expiry`).
- **Write URLs** (presigned PUT URLs valid ~1 hour) are **never stored** — used immediately for upload and discarded.
- **Offline serving:** When offline, serve from local file at constant path regardless of URL expiry.
- **Online + valid URL:** Serve from local file; re-download only if file is missing on disk.
- **Online + expired URL:** Re-fetch a fresh read URL from the server, update the DB column, re-download file.

## Dependencies

- **Depends on:** `dart:io` (`File`, `HttpClient`, `HttpClientResponse`), `package:path_provider` (`getApplicationDocumentsDirectory()`)
- **Depended on by:** `services/authentication.dart` (downloads profile image on auth), `services/members.dart` (saves profile/student images), future UI widgets (serving cached images via `FileCache.get()`)

## Conventions

- Path helpers are the **single canonical definition** of each path convention. No other file should construct these paths manually.
- All methods are safe to call concurrently — Dart's single-isolate model means no explicit locking is needed.
- New entity types that need cached files should add a static path helper method to `FileCache` and document the path pattern here.

## Last Updated
Task 2 (FileCacheNotifier) — Added `FileCacheNotifier` class to `file_cache.dart`. Added `FileCacheNotifier.notify()` calls after every file write in `FileCache.download()` and `FileCache.saveBytes()`. Added `FileCacheNotifier.notify()` calls in `services/members.dart` after `saveStudentImage()` and `saveUserProfileImage()` file copies. Converted all `_StudentAvatar` / `_StudentAvatarLarge` / `StudentAvatar` widgets from `StatelessWidget` to `StatefulWidget` with `initState`/`dispose`/`didUpdateWidget` listener lifecycle so they rebuild immediately when a cached image file lands on disk (local save or remote download).

Previous: Task 1 — Added `FileCache.upload(String putUrl, String relativePath) → Future<bool>` static method for S3 HTTP PUT uploads. Called by `SyncEngine._handleFileUrls()` when the push originator device receives PUT URLs in `ActionResponse.fileUrls`.