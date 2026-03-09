# cache/ — File Cache Context

> Static utility class for caching files (profile images, school logos, student photos) at constant, predictable local paths on the device file system.

## Overview

This directory contains **1 file**. The file cache is a purely static utility — no instances, no state beyond a lazily-resolved base directory path. Files are stored at deterministic paths derived from entity identity (never random or timestamped), so any part of the app can construct the expected path and check for a cached file without consulting a database column.

## Files

| File | Key Exports | Status |
|---|---|---|
| `file_cache.dart` | `FileCache` (static class) | ✅ Complete |

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
| `download` | `Future<File?> download(String url, String relativePath)` | HTTP GET from `url`, saves to `relativePath`. Creates parent dirs. Overwrites existing. Returns `File` on success, `null` on any error. Errors swallowed silently. |
| `saveBytes` | `Future<File?> saveBytes(List<int> bytes, String relativePath)` | Writes raw bytes to `relativePath`. Creates parent dirs. Overwrites existing. Returns `File` on success, `null` on error. Used for locally-picked images (e.g. from `image_picker`). |
| `delete` | `Future<void> delete(String relativePath)` | Deletes the file at `relativePath` if it exists. No-op if absent. Errors silently ignored. |

### Internal

- `_appDir` — `String?`, lazily initialized. Resolved once via `path_provider`'s `getApplicationDocumentsDirectory()` and cached for process lifetime.
- `_baseDir()` — `Future<String>`, resolves `_appDir` on first call.
- `_resolve(String relativePath)` — `Future<File>`, combines `_baseDir()` + `relativePath`.
- `_collectBytes(HttpClientResponse)` — `Future<List<int>>`, accumulates all byte chunks from an HTTP response into a single flat list.

### Error Handling

All public methods **swallow errors silently** and return `null` (or void) on failure. The caller decides whether to retry. This is intentional — file caching is a best-effort operation that should never crash the app.

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
Initial creation — project restructuring for agent workflow.