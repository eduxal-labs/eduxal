import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Static utility class for caching files at constant, predictable local paths.
///
/// All files live under `{appDir}/{relativePath}` where `appDir` is resolved
/// once via [path_provider] and then cached for the lifetime of the process.
///
/// ### Path conventions
/// | Entity          | Path helper                        | Full path                                      |
/// |-----------------|------------------------------------|------------------------------------------------|
/// | User profile    | [profilePath]                      | `{appDir}/users/{userId}/profile`              |
/// | Student image   | (future)                           | `{appDir}/schools/{schoolId}/students/{adm}/image` |
/// | School logo     | (future)                           | `{appDir}/schools/{schoolId}/logo`             |
///
/// ### Design rules
/// - No URL expiry tracking — this class only cares about file presence.
/// - Write URLs are never stored or passed through here — only GET URLs.
/// - [download] always overwrites any existing file at the target path.
/// - All methods are safe to call concurrently — Dart's single-isolate model
///   means no explicit locking is needed.
class FileCache {
  FileCache._(); // purely static — never instantiated

  // ─────────────────────────────────────────────────────────────────────────
  // Internal state
  // ─────────────────────────────────────────────────────────────────────────

  /// Lazily initialised base directory. Resolved once and reused thereafter.
  static String? _appDir;

  /// Returns the resolved application documents directory path, initialising
  /// it on the first call.
  static Future<String> _baseDir() async {
    _appDir ??= (await getApplicationDocumentsDirectory()).path;
    return _appDir!;
  }

  /// Resolves [relativePath] to an absolute [File] path under [_baseDir].
  static Future<File> _resolve(String relativePath) async {
    final base = await _baseDir();
    return File('$base/$relativePath');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the [File] at `{appDir}/{relativePath}` if it exists on disk,
  /// or `null` if it has not yet been downloaded.
  ///
  /// Does **not** hit the network under any circumstances.
  ///
  /// ```dart
  /// final file = await FileCache.get(FileCache.profilePath(userId));
  /// if (file != null) {
  ///   // serve from local cache
  /// }
  /// ```
  static Future<File?> get(String relativePath) async {
    final file = await _resolve(relativePath);
    return file.existsSync() ? file : null;
  }

  /// Uploads the file at [relativePath] to S3 via HTTP PUT to [putUrl].
  ///
  /// The file must already exist locally (e.g. saved by [saveBytes] or
  /// copied from image_picker). Returns `true` on success, `false` on any
  /// error (file missing, network error, non-2xx response).
  ///
  /// Content-Type is always `application/octet-stream` — the server accepts
  /// any binary content for file fields.
  static Future<bool> upload(String putUrl, String relativePath) async {
    try {
      final file = await _resolve(relativePath);
      debugPrint(
        '[FileCache] upload() — file exists: ${file.existsSync()}, size: ${file.existsSync() ? file.lengthSync() : 0} bytes, putUrl prefix: ${putUrl.length > 60 ? putUrl.substring(0, 60) : putUrl}',
      );
      if (!file.existsSync()) return false;

      final client = HttpClient();
      try {
        final request = await client.putUrl(Uri.parse(putUrl));
        final length = await file.length();
        request.headers.set(HttpHeaders.contentLengthHeader, length.toString());
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/octet-stream',
        );
        await request.addStream(file.openRead());
        final response = await request.close();
        debugPrint(
          '[FileCache] upload() — HTTP status: ${response.statusCode}',
        );
        // Drain response body to allow connection reuse.
        await response.drain<void>();
        return response.statusCode >= 200 && response.statusCode < 300;
      } finally {
        client.close(force: false);
      }
    } catch (_) {
      return false;
    }
  }

  /// Downloads the resource at [url] via HTTP GET and saves it at
  /// `{appDir}/{relativePath}`, creating any missing parent directories.
  ///
  /// Overwrites any existing file at the target path.
  ///
  /// Returns the written [File] on success, or `null` if the download or
  /// write fails for any reason (network error, bad status code, I/O error).
  /// Errors are not re-thrown — callers that need fire-and-forget behaviour
  /// can call this without `.catchError`.
  ///
  /// ```dart
  /// final file = await FileCache.download(
  ///   readUrl,
  ///   FileCache.profilePath(userId),
  /// );
  /// ```
  static Future<File?> download(String url, String relativePath) async {
    try {
      debugPrint(
        '[FileCache] download() — url prefix: ${url.length > 60 ? url.substring(0, 60) : url}, path=$relativePath',
      );
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint(
            '[FileCache] download() — bad HTTP status: ${response.statusCode}',
          );
          return null;
        }

        final file = await _resolve(relativePath);

        // Ensure all parent directories exist before writing.
        final dir = file.parent;
        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }

        // Collect all bytes before writing so a partial failure does not
        // leave a corrupted file on disk.
        final bytes = await _collectBytes(response);
        // Evict stale cached image before overwriting file on disk.
        try {
          PaintingBinding.instance.imageCache.evict(FileImage(file));
        } catch (_) {}
        await file.writeAsBytes(bytes, flush: true);
        FileCacheNotifier.notify(relativePath);
        debugPrint(
          '[FileCache] download() — wrote ${bytes.length} bytes to ${file.path}',
        );
        return file;
      } finally {
        client.close(force: false);
      }
    } catch (_) {
      // Any network or I/O error is silently swallowed.
      // The caller is responsible for deciding whether to retry.
      return null;
    }
  }

  /// Saves raw [bytes] to `{appDir}/{relativePath}`, creating any missing
  /// parent directories. Overwrites any existing file at the target path.
  ///
  /// Returns the written [File] on success, or `null` if the write fails.
  ///
  /// Used when saving a locally-picked image (e.g. from `image_picker`) to
  /// the cache without an HTTP download step.
  ///
  /// ```dart
  /// final bytes = await pickedFile.readAsBytes();
  /// final cached = await FileCache.saveBytes(
  ///   bytes,
  ///   FileCache.profilePath(userId),
  /// );
  /// ```
  static Future<File?> saveBytes(List<int> bytes, String relativePath) async {
    try {
      final file = await _resolve(relativePath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      // Evict stale cached image before overwriting file on disk.
      try {
        PaintingBinding.instance.imageCache.evict(FileImage(file));
      } catch (_) {}
      await file.writeAsBytes(bytes, flush: true);
      FileCacheNotifier.notify(relativePath);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Deletes the file at `{appDir}/{relativePath}` if it exists.
  ///
  /// No-op if the file is absent. Errors during deletion are silently ignored.
  ///
  /// ```dart
  /// await FileCache.delete(FileCache.profilePath(userId));
  /// ```
  static Future<void> delete(String relativePath) async {
    try {
      final file = await _resolve(relativePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Silently ignore — a failed delete is non-fatal.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Path helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Relative path for a user's profile image.
  ///
  /// Resolves to `{appDir}/users/{userId}/profile` at runtime.
  /// This is the single canonical definition of this convention — no other
  /// file in the codebase should construct this path manually.
  static String profilePath(String userId) => 'users/$userId/profile';

  /// Relative path for a school's logo image.
  ///
  /// Resolves to `{appDir}/schools/{schoolId}/logo` at runtime.
  static String logoPath(String schoolId) => 'schools/$schoolId/logo';

  /// Relative path for a student's photo.
  ///
  /// Resolves to `{appDir}/schools/{schoolId}/students/{adm}/image` at runtime.
  /// Not used in Task Group 4 but establishes the convention for later groups.
  static String studentImagePath(String schoolId, int adm) =>
      'schools/$schoolId/students/$adm/image';

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Accumulates all byte chunks from an [HttpClientResponse] into a single
  /// flat [List<int>].
  static Future<List<int>> _collectBytes(HttpClientResponse response) async {
    final chunks = <List<int>>[];
    await for (final chunk in response) {
      chunks.add(chunk);
    }
    // Flatten into a single list to avoid writing a multi-part byte buffer.
    final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final bytes = List<int>.filled(totalLength, 0);
    var offset = 0;
    for (final chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return bytes;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FileCacheNotifier
// ─────────────────────────────────────────────────────────────────────────────

/// A [ChangeNotifier] subclass whose [ping] method is publicly callable,
/// allowing [FileCacheNotifier] to trigger listeners from outside the class.
class _FileChangeNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// A lightweight notifier that signals when a cached file path has been
/// written or updated on disk. Widgets that display cached files should
/// listen to this and rebuild when their path is notified.
///
/// Usage — notify after write:
///   FileCacheNotifier.notify('schools/x/students/23/image');
///
/// Usage — listen in a widget:
///   FileCacheNotifier.of('schools/x/students/23/image').addListener(_rebuild);
class FileCacheNotifier {
  FileCacheNotifier._();

  static final Map<String, _FileChangeNotifier> _notifiers = {};

  /// Returns the [ChangeNotifier] for [path], creating it if needed.
  static ChangeNotifier of(String path) {
    return _notifiers.putIfAbsent(path, _FileChangeNotifier.new);
  }

  /// Notifies all listeners for [path] that the file has changed on disk.
  ///
  /// Also evicts any [FileImage] for this path from Flutter's image cache so
  /// that the next build gets fresh bytes from disk rather than the stale
  /// cached image. The eviction happens **before** listeners are notified so
  /// that any [FutureBuilder] or [Image.file] widget that rebuilds in response
  /// to the notification already sees a clean cache.
  static void notify(String path) {
    // Evict any cached FileImage for this path so Flutter re-reads from disk.
    _evictFileImageCache(path);
    _notifiers[path]?.ping();
  }

  /// Evicts the [FileImage] entry for [relativePath] from Flutter's painting
  /// image cache. Uses the cached [FileCache._appDir] to construct the
  /// absolute path — if the base directory has not been resolved yet, no file
  /// can have been cached yet, so the eviction is skipped safely.
  static void _evictFileImageCache(String relativePath) {
    try {
      final base = FileCache._appDir;
      if (base == null) return; // not yet resolved — nothing cached yet
      final absPath = '$base/$relativePath';
      PaintingBinding.instance.imageCache.evict(FileImage(File(absPath)));
    } catch (_) {
      // Non-fatal — worst case the stale image shows briefly until next rebuild.
    }
  }
}
