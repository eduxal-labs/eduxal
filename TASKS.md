# TASKS.md

## Overview

**Feature:** Multi-file bulk import with automatic image (SVG) upload to R2/S3.

**Context:** The system dashboard's Subjects section allows importing questions from JSON files. Currently, the `SubjectBulkImportSheet` picks a single `.json` file, sends its text to the server via `bulkImport`, and ignores image files entirely. The user wants to:

1. Select **multiple** `.json` topic files at once (e.g. 10 files for Mathematics Form 1).
2. Have the client **validate all image references** — each question's `images[].filename` will contain an **absolute filesystem path** to an SVG file.
3. Have the client **upload all referenced images to R2/S3** after a successful bulk import.
4. Show **clear error reporting** for missing images, failed uploads, and per-file import failures.

**Scale:** ~413 JSON files, ~17,673 questions, ~797 image references, ~604 SVG files on disk.

**Critical backend limitation:** `BulkImportResponse` currently returns only `{ created_count, errors[] }` — it does **not** return the IDs of created questions. The `requestImageUploadUrls` RPC requires a `questionId`. Without created IDs, the client cannot request upload URLs after a bulk import.

---

## Prerequisite P1: Backend Proto Changes & Stub Regeneration

**Status: Handled by backend tasks in `../ledger/TASKS.md` (Tasks B1 + B2)**

The backend already has `question_ids` in `BulkImportResponse` and populates it. Backend Task B1 adds `filename` to `ImageUploadSpec` for correct file extension support. Backend Task B2 regenerates Dart proto stubs. Client tasks below proceed after B2 completes.

**Proto contract changes after B2:**
- `BulkImportResponse` now has `questionIds` (repeated int32, field 3) — server-assigned IDs in order, excluding errored indices.
- `ImageUploadUrlsRequest` now takes `repeated ImageUploadSpec images` instead of `{questionId, filenames}`.
- `ImageUploadSpec` (new message): `questionId`, `position`, `context` (0=question, 1=rubric, 2=example\_answer), `caption` (optional), `filename` (basename for extension detection).
- `ImageUploadUrl` (replaces `SignedImageUrl`): `questionId`, `position`, `key` (S3 object key), `putUrl`.

---

## Task 01: Update `BulkImportResult` Domain Model

**Files to modify:** `lib/models/question.dart`
**Context files to read:** `lib/models/CONTEXT.md`
**Depends on:** P1 (proto stubs regenerated)
**Parallel group:** P1

**Specification:**

Add a `questionIds` field to the `BulkImportResult` class so the client can use server-assigned question IDs for image upload.

Current definition (around line 93):

```dart
class BulkImportResult {
  final int createdCount;
  final List<ImportError> errors;
  const BulkImportResult({required this.createdCount, required this.errors});

  factory BulkImportResult.fromProto(pb.BulkImportResponse proto) =>
      BulkImportResult(
        createdCount: proto.createdCount,
        errors: proto.errors.map(ImportError.fromProto).toList(),
      );
}
```

Change to:

```dart
class BulkImportResult {
  final int createdCount;
  final List<int> questionIds;
  final List<ImportError> errors;
  const BulkImportResult({
    required this.createdCount,
    required this.questionIds,
    required this.errors,
  });

  factory BulkImportResult.fromProto(pb.BulkImportResponse proto) =>
      BulkImportResult(
        createdCount: proto.createdCount,
        questionIds: proto.questionIds.toList(),
        errors: proto.errors.map(ImportError.fromProto).toList(),
      );
}
```

**Update after completion:**
- [x] Update `lib/models/CONTEXT.md` — note `BulkImportResult` now has `questionIds`
- [x] Mark this task `[x]`

---

## Task 02: Create `ImportFileParser` Utility

**Status: ✅ Complete**

**Files to create:** `lib/services/import_file_parser.dart`
**Context files to read:** `lib/models/CONTEXT.md`, `lib/services/CONTEXT.md`
**Depends on:** None
**Parallel group:** P1

**Specification:**

Create a pure-Dart utility that parses and validates question bank JSON files, extracts image references, verifies image files exist on the local filesystem, and produces a cleaned JSON string (with absolute paths stripped to basenames) ready for `bulkImport`.

This file must have **zero Flutter/UI imports** — it is pure business logic.

```dart
// lib/services/import_file_parser.dart

import 'dart:convert';
import 'dart:io';

/// Result of parsing and validating a single JSON import file.
class ParsedImportFile {
  /// Original file path on disk.
  final String filePath;

  /// Display name (basename of the file, e.g. "algebraic-expressions.json").
  final String fileName;

  /// Subject name extracted from JSON.
  final String subject;

  /// Curriculum string ("844" or "cbc").
  final String curriculum;

  /// Grade number extracted from JSON.
  final int grade;

  /// Topic name extracted from JSON.
  final String topic;

  /// Total number of questions in the file.
  final int questionCount;

  /// Number of questions that have at least one image reference.
  final int questionsWithImages;

  /// Total number of image references across all questions.
  final int totalImageRefs;

  /// Image references that were verified to exist on disk.
  final int imagesFound;

  /// Image references where the file was NOT found on disk.
  /// Each entry is (questionIndex, filename, absolutePath).
  final List<MissingImage> missingImages;

  /// Structural validation errors (bad JSON, missing fields, etc.).
  /// If non-empty, this file cannot be imported.
  final List<String> validationErrors;

  /// The cleaned JSON string with image filenames stripped to basenames.
  /// Null if validationErrors is non-empty.
  final String? cleanedJson;

  /// Mapping from basename → absolute local path for every found image.
  /// Used after import to upload files to S3.
  final Map<String, String> imagePathMap;

  /// Per-question image basenames, indexed by question position in the JSON
  /// array. Only includes questions that have images. Key = original JSON
  /// index, value = list of basenames for that question.
  final Map<int, List<String>> questionImageMap;

  bool get isValid => validationErrors.isEmpty;
  bool get hasMissingImages => missingImages.isNotEmpty;
  bool get hasImages => totalImageRefs > 0;

  const ParsedImportFile({
    required this.filePath,
    required this.fileName,
    required this.subject,
    required this.curriculum,
    required this.grade,
    required this.topic,
    required this.questionCount,
    required this.questionsWithImages,
    required this.totalImageRefs,
    required this.imagesFound,
    required this.missingImages,
    required this.validationErrors,
    required this.cleanedJson,
    required this.imagePathMap,
    required this.questionImageMap,
  });
}

/// A missing image reference.
class MissingImage {
  final int questionIndex;
  final String filename;
  final String absolutePath;
  const MissingImage({
    required this.questionIndex,
    required this.filename,
    required this.absolutePath,
  });
}

/// Parses and validates a single JSON file for bulk import.
///
/// The JSON is expected to have the structure:
/// ```json
/// {
///   "subject": "Mathematics",
///   "curriculum": "844",
///   "grade": 1,
///   "topic": "Algebraic Expressions",
///   "questions": [
///     {
///       "text": "...",
///       "marks": 3,
///       "rubric": [{"criterion": "...", "marks": 1}],
///       "example_answer": "...",
///       "images": [
///         {
///           "context": "question",
///           "filename": "/absolute/path/to/illustrations/diagram.svg",
///           "caption": "Figure 1: ...",
///           "description": "..."
///         }
///       ]
///     }
///   ]
/// }
/// ```
///
/// The parser:
/// 1. Validates all required fields (subject, curriculum, grade, topic, questions).
/// 2. Validates each question (text, marks > 0, rubric with marks sum check).
/// 3. For each image: extracts the absolute path from `filename`, checks the
///    file exists on disk, records missing files.
/// 4. Produces a cleaned JSON string where `filename` values are replaced with
///    just the basename (e.g. "diagram.svg") — the server stores basenames only.
/// 5. Builds a mapping from basename → absolute path for the upload phase.
ParsedImportFile parseImportFile(String filePath, String jsonContent) {
  final fileName = filePath.split(Platform.pathSeparator).last;
  final errors = <String>[];
  final missingImages = <MissingImage>[];
  final imagePathMap = <String, String>{};
  final questionImageMap = <int, List<String>>{};

  String subject = '';
  String curriculum = '';
  int grade = 0;
  String topic = '';
  int questionCount = 0;
  int questionsWithImages = 0;
  int totalImageRefs = 0;
  int imagesFound = 0;

  dynamic parsed;
  try {
    parsed = jsonDecode(jsonContent);
  } on FormatException catch (e) {
    return _errorResult(filePath, fileName, 'Invalid JSON: ${e.message}');
  }

  if (parsed is! Map<String, dynamic>) {
    return _errorResult(filePath, fileName, 'Root must be a JSON object.');
  }

  // ── Validate top-level fields ──────────────────────────────────────────

  final rawSubject = parsed['subject'];
  if (rawSubject == null || rawSubject is! String || rawSubject.trim().isEmpty) {
    errors.add('Missing or empty "subject" field.');
  } else {
    subject = rawSubject.trim();
  }

  final rawCurriculum = parsed['curriculum'];
  if (rawCurriculum == null || rawCurriculum is! String) {
    errors.add('Missing "curriculum" field (expected "844" or "cbc").');
  } else if (rawCurriculum != '844' && rawCurriculum != 'cbc') {
    errors.add('"curriculum" must be "844" or "cbc".');
  } else {
    curriculum = rawCurriculum;
  }

  final rawGrade = parsed['grade'];
  if (rawGrade == null) {
    errors.add('Missing "grade" field.');
  } else if (rawGrade is int) {
    if (rawGrade <= 0) {
      errors.add('"grade" must be a positive integer.');
    } else {
      grade = rawGrade;
    }
  } else if (rawGrade is double) {
    grade = rawGrade.toInt();
    if (grade <= 0) errors.add('"grade" must be a positive integer.');
  } else {
    errors.add('"grade" must be an integer.');
  }

  final rawTopic = parsed['topic'];
  if (rawTopic == null || rawTopic is! String || rawTopic.trim().isEmpty) {
    errors.add('Missing or empty "topic" field.');
  } else {
    topic = rawTopic.trim();
  }

  // ── Validate questions array ───────────────────────────────────────────

  final rawQuestions = parsed['questions'];
  if (rawQuestions == null || rawQuestions is! List || rawQuestions.isEmpty) {
    errors.add('"questions" array is missing or empty.');
    return _buildResult(
      filePath: filePath,
      fileName: fileName,
      subject: subject,
      curriculum: curriculum,
      grade: grade,
      topic: topic,
      questionCount: 0,
      questionsWithImages: 0,
      totalImageRefs: 0,
      imagesFound: 0,
      missingImages: missingImages,
      errors: errors,
      cleanedJson: null,
      imagePathMap: imagePathMap,
      questionImageMap: questionImageMap,
    );
  }

  // Deep-clone the parsed JSON so we can mutate image filenames for cleaning.
  final cleanedParsed = jsonDecode(jsonContent) as Map<String, dynamic>;
  final cleanedQuestions = cleanedParsed['questions'] as List<dynamic>;

  for (var i = 0; i < rawQuestions.length; i++) {
    final q = rawQuestions[i];
    final prefix = 'Question ${i + 1}';

    if (q is! Map<String, dynamic>) {
      errors.add('$prefix: not a JSON object.');
      continue;
    }

    // text
    if (q['text'] == null ||
        q['text'] is! String ||
        (q['text'] as String).trim().isEmpty) {
      errors.add('$prefix: missing or empty "text".');
    }

    // marks
    final rawMarks = q['marks'];
    int? marks;
    if (rawMarks == null) {
      errors.add('$prefix: missing "marks".');
    } else if (rawMarks is int) {
      marks = rawMarks;
      if (marks <= 0) errors.add('$prefix: "marks" must be > 0.');
    } else if (rawMarks is double) {
      marks = rawMarks.toInt();
      if (marks <= 0) errors.add('$prefix: "marks" must be > 0.');
    } else {
      errors.add('$prefix: "marks" must be a number.');
    }

    // rubric
    final rawRubric = q['rubric'];
    if (rawRubric == null || rawRubric is! List || rawRubric.isEmpty) {
      errors.add('$prefix: missing or empty "rubric" array.');
    } else {
      int rubricSum = 0;
      for (var j = 0; j < rawRubric.length; j++) {
        final r = rawRubric[j];
        if (r is! Map<String, dynamic>) {
          errors.add('$prefix, rubric[${j + 1}]: not a JSON object.');
          continue;
        }
        if (r['criterion'] == null ||
            r['criterion'] is! String ||
            (r['criterion'] as String).trim().isEmpty) {
          errors.add('$prefix, rubric[${j + 1}]: missing "criterion".');
        }
        final rMarks = r['marks'];
        if (rMarks == null) {
          errors.add('$prefix, rubric[${j + 1}]: missing "marks".');
        } else if (rMarks is int) {
          rubricSum += rMarks;
        } else if (rMarks is double) {
          rubricSum += rMarks.toInt();
        } else {
          errors.add('$prefix, rubric[${j + 1}]: "marks" must be a number.');
        }
      }
      if (marks != null && rubricSum != marks) {
        errors.add(
          '$prefix: rubric marks sum ($rubricSum) ≠ question marks ($marks).',
        );
      }
    }

    // images — validate and extract paths
    final rawImages = q['images'];
    if (rawImages != null && rawImages is! List) {
      errors.add('$prefix: "images" must be an array if provided.');
    } else if (rawImages != null && rawImages is List && rawImages.isNotEmpty) {
      questionsWithImages++;
      final basenames = <String>[];

      for (var k = 0; k < rawImages.length; k++) {
        final img = rawImages[k];
        if (img is! Map<String, dynamic>) continue;

        final rawFilename = img['filename'];
        if (rawFilename == null || rawFilename is! String || rawFilename.trim().isEmpty) {
          errors.add('$prefix, image[${k + 1}]: missing "filename".');
          continue;
        }

        totalImageRefs++;
        final absolutePath = rawFilename.trim();
        final basename = absolutePath.split('/').last.split('\\').last;
        basenames.add(basename);

        // Check if the file exists on disk.
        final file = File(absolutePath);
        if (file.existsSync()) {
          imagesFound++;
          imagePathMap[basename] = absolutePath;
        } else {
          missingImages.add(MissingImage(
            questionIndex: i,
            filename: basename,
            absolutePath: absolutePath,
          ));
        }

        // Clean the filename in the cloned JSON — strip to basename.
        if (i < cleanedQuestions.length) {
          final cq = cleanedQuestions[i];
          if (cq is Map<String, dynamic>) {
            final cImages = cq['images'];
            if (cImages is List && k < cImages.length) {
              final cImg = cImages[k];
              if (cImg is Map<String, dynamic>) {
                cImg['filename'] = basename;
              }
            }
          }
        }
      }

      if (basenames.isNotEmpty) {
        questionImageMap[i] = basenames;
      }
    }

    questionCount++;
  }

  final cleanedJson = errors.isEmpty ? jsonEncode(cleanedParsed) : null;

  return _buildResult(
    filePath: filePath,
    fileName: fileName,
    subject: subject,
    curriculum: curriculum,
    grade: grade,
    topic: topic,
    questionCount: questionCount,
    questionsWithImages: questionsWithImages,
    totalImageRefs: totalImageRefs,
    imagesFound: imagesFound,
    missingImages: missingImages,
    errors: errors,
    cleanedJson: cleanedJson,
    imagePathMap: imagePathMap,
    questionImageMap: questionImageMap,
  );
}

// ── Private helpers ────────────────────────────────────────────────────────

ParsedImportFile _errorResult(String filePath, String fileName, String error) {
  return ParsedImportFile(
    filePath: filePath,
    fileName: fileName,
    subject: '',
    curriculum: '',
    grade: 0,
    topic: '',
    questionCount: 0,
    questionsWithImages: 0,
    totalImageRefs: 0,
    imagesFound: 0,
    missingImages: const [],
    validationErrors: [error],
    cleanedJson: null,
    imagePathMap: const {},
    questionImageMap: const {},
  );
}

ParsedImportFile _buildResult({
  required String filePath,
  required String fileName,
  required String subject,
  required String curriculum,
  required int grade,
  required String topic,
  required int questionCount,
  required int questionsWithImages,
  required int totalImageRefs,
  required int imagesFound,
  required List<MissingImage> missingImages,
  required List<String> errors,
  required String? cleanedJson,
  required Map<String, String> imagePathMap,
  required Map<int, List<String>> questionImageMap,
}) {
  return ParsedImportFile(
    filePath: filePath,
    fileName: fileName,
    subject: subject,
    curriculum: curriculum,
    grade: grade,
    topic: topic,
    questionCount: questionCount,
    questionsWithImages: questionsWithImages,
    totalImageRefs: totalImageRefs,
    imagesFound: imagesFound,
    missingImages: missingImages,
    validationErrors: errors,
    cleanedJson: cleanedJson,
    imagePathMap: imagePathMap,
    questionImageMap: questionImageMap,
  );
}
```

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md` — add entry for `import_file_parser.dart`
- [x] Mark this task `[x]`

---

## Task 03: Add `uploadFileToUrl` Method to `QuestionBankService`

**Status: ✅ Complete**

**Files to modify:** `lib/services/question_bank.dart`
**Context files to read:** `lib/services/CONTEXT.md`, `lib/cache/file_cache.dart` (reference for S3 upload pattern)
**Depends on:** None
**Parallel group:** P1

**Specification:**

Add a static method to `QuestionBankService` that uploads a local file to a presigned S3/R2 PUT URL. This is modelled after `FileCache.upload()` but works with **absolute file paths** and auto-detects Content-Type from the file extension.

Add this method inside `class QuestionBankService`, before the `_toProtoImageContext` helper (around line 640):

```dart
  // ---------------------------------------------------------------------------
  // Image File Upload
  // ---------------------------------------------------------------------------

  /// Uploads a local file to a presigned S3/R2 PUT URL.
  ///
  /// [putUrl] — the presigned PUT URL from [requestImageUploadUrls].
  /// [localPath] — absolute path to the file on the local filesystem.
  ///
  /// Returns `true` on HTTP 2xx, `false` on any failure.
  static Future<bool> uploadFileToUrl(String putUrl, String localPath) async {
    if (putUrl.isEmpty || localPath.isEmpty) return false;
    HttpClient? httpClient;
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('[QB] uploadFileToUrl: file not found at $localPath');
        return false;
      }
      final length = await file.length();
      final contentType = _contentTypeForExtension(localPath);

      httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      request.headers.set(HttpHeaders.contentLengthHeader, length.toString());
      await request.addStream(file.openRead());
      final response = await request.close();
      await response.drain<void>();

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      print(
        '[QB] uploadFileToUrl: ${ok ? 'OK' : 'FAIL'} '
        '(${response.statusCode}) ${localPath.split('/').last}',
      );
      return ok;
    } catch (e) {
      print('[QB] uploadFileToUrl: ERROR $e');
      return false;
    } finally {
      httpClient?.close(force: false);
    }
  }

  /// Returns the MIME Content-Type for common image file extensions.
  static String _contentTypeForExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }
```

The `dart:io` import (`HttpClient`, `HttpHeaders`, `File`) is already present in the file via `package:grpc/grpc.dart` which re-exports `dart:io`. If needed, add `import 'dart:io';` at the top.

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md` — note new static methods on `QuestionBankService`
- [x] Mark this task `[x]`

---

## Task 03b: Rewrite `requestImageUploadUrls` for New Proto Contract

**Files to modify:** `lib/services/question_bank.dart`
**Context files to read:** `lib/services/CONTEXT.md`
**Depends on:** P1 (proto stubs regenerated)
**Parallel group:** P2

**Specification:**

The `requestImageUploadUrls` method must be rewritten because the proto contract changed. The old contract used `{questionId, filenames}` → `SignedImageUrl`. The new contract uses `{repeated ImageUploadSpec}` → `ImageUploadUrl`.

Replace the current `requestImageUploadUrls` method (around line 252) with:

```dart
    /// Requests presigned S3/R2 PUT URLs for uploading question images.
    ///
    /// Each [spec] in [imageSpecs] must contain:
    /// - `questionId`: the server-assigned question ID
    /// - `position`: 1-indexed position within the question's images
    /// - `context`: 0=question, 1=rubric, 2=example_answer
    /// - `filename`: basename of the file (for extension detection)
    /// - `caption`: optional caption text
    ///
    /// Returns [ImageUploadUrl] objects with `putUrl` for each image.
    Future<Result<List<pb.ImageUploadUrl>, GrpcError>> requestImageUploadUrls({
      required List<pb.ImageUploadSpec> imageSpecs,
      required String accessToken,
    }) async {
      print(
        '[QB] requestImageUploadUrls → specs=${imageSpecs.length}',
      );
      try {
        final req = pb.ImageUploadUrlsRequest();
        req.images.addAll(imageSpecs);
        final options = CallOptions(
          metadata: {'authorization': 'Bearer $accessToken'},
          timeout: const Duration(seconds: 30),
        );
        final client = pbgrpc.QuestionBankClient(_mainChannel);
        final resp = await client.requestImageUploadUrls(req, options: options);
        print('[QB] requestImageUploadUrls ← OK (urls=${resp.urls.length})');
        return Ok(resp.urls.toList());
      } on GrpcError catch (e) {
        print('[QB] requestImageUploadUrls ← GrpcError: ${e.code} ${e.message}');
        return Err(e);
      } catch (e, st) {
        print(
          '[QB] requestImageUploadUrls ← UNEXPECTED ${e.runtimeType}: $e\n$st',
        );
        return Err(GrpcError.internal('requestImageUploadUrls failed: $e'));
      }
    }
```

**Update after completion:**
- [x] Update `lib/services/CONTEXT.md` — note `requestImageUploadUrls` signature changed to accept `List<pb.ImageUploadSpec>` and return `List<pb.ImageUploadUrl>`
- [x] Mark this task `[x]`

---

## Task 04: Add `importFileWithImages` Orchestrator to `QuestionBankService`

**Files to modify:** `lib/services/question_bank.dart`
**Context files to read:** `lib/services/CONTEXT.md`, `lib/services/import_file_parser.dart` (from Task 02)
**Depends on:** Task 01, Task 02, Task 03, Task 03b
**Parallel group:** None (sequential)

**Specification:**

Add a high-level orchestrator method that handles the full pipeline for a single parsed file: bulk import → request image upload URLs → upload files. This method is called by the UI for each file in the multi-file batch.

Add these imports at the top of `question_bank.dart` if not already present:

```dart
import 'dart:convert';
import 'import_file_parser.dart';
```

Add the following types and method to the `QuestionBankService` class:

```dart
  /// Progress callback for [importFileWithImages].
  ///
  /// [phase] — "importing", "uploading"
  /// [detail] — human-readable detail (e.g. "Uploading image 3/7")
  /// [progress] — 0.0 to 1.0
  typedef ImportProgressCallback = void Function(
    String phase,
    String detail,
    double progress,
  );
```

Actually, since `typedef` can't be inside a class, define this **outside** the class, above it:

```dart
/// Callback for reporting progress from [QuestionBankService.importFileWithImages].
typedef ImportProgressCallback = void Function(
  String phase,
  String detail,
  double progress,
);

/// Result of importing a single file with its images.
class FileImportResult {
  final String fileName;
  final String topic;
  final int questionsCreated;
  final int questionsErrored;
  final int imagesUploaded;
  final int imagesFailed;
  final int imagesSkipped; // missing on disk
  final List<String> errors; // per-question import errors + per-image upload errors

  const FileImportResult({
    required this.fileName,
    required this.topic,
    required this.questionsCreated,
    required this.questionsErrored,
    required this.imagesUploaded,
    required this.imagesFailed,
    required this.imagesSkipped,
    required this.errors,
  });

  bool get isFullSuccess =>
      questionsErrored == 0 && imagesFailed == 0 && imagesSkipped == 0;
  bool get isPartialSuccess => questionsCreated > 0;
}
```

Then add this method inside `QuestionBankService`:

```dart
  /// Imports a single parsed file: bulk-imports questions, then uploads images.
  ///
  /// [parsed] — a validated [ParsedImportFile] (must have `isValid == true`).
  /// [accessToken] — auth token.
  /// [onProgress] — optional progress callback.
  ///
  /// Flow:
  /// 1. Call `bulkImport(parsed.cleanedJson)`.
  /// 2. Map `question_ids` back to original question indices (skipping errored
  ///    indices from the import response).
  /// 3. Build `ImageUploadSpec` objects for all images across all created
  ///    questions and call `requestImageUploadUrls` once with all specs.
  /// 4. Upload each image file to its PUT URL via `uploadFileToUrl`.
  /// 5. Collect results.
  Future<FileImportResult> importFileWithImages({
    required ParsedImportFile parsed,
    required String accessToken,
    ImportProgressCallback? onProgress,
  }) async {
    assert(parsed.isValid && parsed.cleanedJson != null);

    final errors = <String>[];

    // ── Phase 1: Bulk import questions ────────────────────────────────────
    onProgress?.call('importing', 'Importing ${parsed.questionCount} questions…', 0.0);

    final importResult = await bulkImport(
      jsonContent: parsed.cleanedJson!,
      accessToken: accessToken,
    );

    switch (importResult) {
      case Err(:final error):
        return FileImportResult(
          fileName: parsed.fileName,
          topic: parsed.topic,
          questionsCreated: 0,
          questionsErrored: parsed.questionCount,
          imagesUploaded: 0,
          imagesFailed: 0,
          imagesSkipped: parsed.missingImages.length,
          errors: ['Import failed: ${error.message ?? error.code}'],
        );
      case Ok(:final value):
        // Collect per-question import errors.
        final errorIndices = <int>{};
        for (final e in value.errors) {
          errorIndices.add(e.index);
          errors.add('Q${e.index + 1}: ${e.message}');
        }

        final createdIds = value.questionIds;

        // If no questions were created or no images to upload, return early.
        if (createdIds.isEmpty || !parsed.hasImages) {
          return FileImportResult(
            fileName: parsed.fileName,
            topic: parsed.topic,
            questionsCreated: value.createdCount,
            questionsErrored: value.errors.length,
            imagesUploaded: 0,
            imagesFailed: 0,
            imagesSkipped: parsed.missingImages.length,
            errors: errors,
          );
        }

        // ── Phase 2: Build ImageUploadSpec objects ───────────────────────
        // Parse cleanedJson to get image metadata (context, caption,
        // filename) for building ImageUploadSpec objects.
        int imagesUploaded = 0;
        int imagesFailed = 0;
        int imagesSkipped = parsed.missingImages.length;

        final allSpecs = <pb.ImageUploadSpec>[];
        final specToLocalPath = <String, String>{}; // "qid:position" → local path

        final cleanedParsed =
            jsonDecode(parsed.cleanedJson!) as Map<String, dynamic>;
        final questions = cleanedParsed['questions'] as List<dynamic>;

        int k = 0;
        for (var j = 0;
            j < parsed.questionCount && k < createdIds.length;
            j++) {
          if (errorIndices.contains(j)) continue;
          final questionId = createdIds[k];
          k++;

          if (j >= questions.length) continue;
          final q = questions[j] as Map<String, dynamic>;
          final images = q['images'] as List<dynamic>? ?? [];

          for (var p = 0; p < images.length; p++) {
            final img = images[p] as Map<String, dynamic>;
            final basename = (img['filename'] as String?) ?? '';
            if (basename.isEmpty) continue;

            final localPath = parsed.imagePathMap[basename];
            if (localPath == null) continue; // missing on disk

            final contextStr =
                (img['context'] as String?) ?? 'question';
            final contextInt = switch (contextStr) {
              'rubric' => 1,
              'example_answer' => 2,
              _ => 0, // question
            };

            final spec = pb.ImageUploadSpec()
              ..questionId = questionId
              ..position = p + 1
              ..context = contextInt
              ..filename = basename;
            if (img['caption'] is String) {
              spec.caption = img['caption'] as String;
            }

            allSpecs.add(spec);
            specToLocalPath['$questionId:${p + 1}'] = localPath;
          }
        }

        if (allSpecs.isEmpty) {
          return FileImportResult(
            fileName: parsed.fileName,
            topic: parsed.topic,
            questionsCreated: value.createdCount,
            questionsErrored: value.errors.length,
            imagesUploaded: 0,
            imagesFailed: 0,
            imagesSkipped: imagesSkipped,
            errors: errors,
          );
        }

        // ── Phase 3: Request upload URLs and upload files ────────────────
        int uploadsDone = 0;
        final totalUploads = allSpecs.length;

        onProgress?.call(
          'uploading',
          'Uploading images (0/$totalUploads)…',
          0.0,
        );

        // Single batched call for all images in this file.
        final urlResult = await requestImageUploadUrls(
          imageSpecs: allSpecs,
          accessToken: accessToken,
        );

        switch (urlResult) {
          case Err(:final error):
            imagesFailed += allSpecs.length;
            errors.add(
              'Image URL request failed: '
              '${error.message ?? error.code}',
            );
          case Ok(:final value):
            for (final uploadUrl in value) {
              final key =
                  '${uploadUrl.questionId}:${uploadUrl.position}';
              final localPath = specToLocalPath[key];
              if (localPath == null) {
                imagesFailed++;
                errors.add(
                  'No local path for Q${uploadUrl.questionId} '
                  'pos ${uploadUrl.position}.',
                );
                uploadsDone++;
                onProgress?.call(
                  'uploading',
                  'Uploading images ($uploadsDone/$totalUploads)…',
                  uploadsDone / totalUploads,
                );
                continue;
              }

              final ok =
                  await uploadFileToUrl(uploadUrl.putUrl, localPath);
              if (ok) {
                imagesUploaded++;
              } else {
                imagesFailed++;
                errors.add(
                  'Upload failed: Q${uploadUrl.questionId} '
                  'pos ${uploadUrl.position}.',
                );
              }
              uploadsDone++;
              onProgress?.call(
                'uploading',
                'Uploading images ($uploadsDone/$totalUploads)…',
                uploadsDone / totalUploads,
              );
            }
        }

        return FileImportResult(
          fileName: parsed.fileName,
          topic: parsed.topic,
          questionsCreated: value.createdCount,
          questionsErrored: value.errors.length,
          imagesUploaded: imagesUploaded,
          imagesFailed: imagesFailed,
          imagesSkipped: imagesSkipped,
          errors: errors,
        );
    }
  }
```

Note: The `Result` import (`Ok`, `Err`) is already used throughout this file, so no new imports are needed for it. Add `import 'dart:io';` and `import 'dart:convert';` at the top if not already present.

**Update after completion:**
- [ ] Update `lib/services/CONTEXT.md` — add `importFileWithImages`, `ImportProgressCallback`, `FileImportResult`
- [ ] Mark this task `[x]`

---

## Task 05: Create `MultiFileImportSheet` UI Widget

**Files to create:** `lib/ui/screens/system/settings/multi_file_import_sheet.dart`
**Context files to read:** `lib/ui/CONTEXT.md`, `lib/ui/screens/system/CONTEXT.md`, `lib/ui/screens/system/settings/subject_bulk_import_sheet.dart` (reference for styling patterns), `lib/ui/widgets/edu_sheet.dart`
**Depends on:** Task 02, Task 04
**Parallel group:** None (sequential)

**Specification:**

Create a new bottom sheet / dialog widget that supports:

1. **Multi-file selection** — pick 1–N `.json` files at once via `FilePicker`.
2. **Parse & validate all files** — using `parseImportFile` from `import_file_parser.dart`.
3. **Image verification** — show per-file image status (found/missing counts).
4. **Sequential import** — import each valid file one at a time, showing progress.
5. **Image upload** — after each file's import, upload images to S3/R2.
6. **Results** — per-file summary with expandable error details.

**Constructor:**

```dart
class MultiFileImportSheet extends StatefulWidget {
  const MultiFileImportSheet({
    super.key,
    required this.subjectName,
    required this.subjectId,
    required this.curriculum,
    this.onImported,
  });

  final String subjectName;
  final int subjectId;
  final CurriculumType curriculum;
  final VoidCallback? onImported;

  @override
  State<MultiFileImportSheet> createState() => _MultiFileImportSheetState();
}
```

**State shape:**

```dart
class _MultiFileImportSheetState extends State<MultiFileImportSheet> {
  // ── File selection ─────────────────────────────────────────────────────
  bool _pickingFiles = false;
  List<ParsedImportFile> _parsedFiles = [];

  // ── Import execution ───────────────────────────────────────────────────
  bool _importing = false;
  int _currentFileIndex = -1;       // -1 = not started
  String _currentPhase = '';        // "importing" | "uploading"
  String _currentDetail = '';       // Human-readable progress detail
  double _currentProgress = 0.0;   // 0.0–1.0 within current file

  // ── Results ────────────────────────────────────────────────────────────
  List<FileImportResult> _results = [];
  bool _completed = false;
  String? _fatalError;              // non-recoverable error (e.g. auth)
}
```

**UI layout (inside `EduSheet`):**

The sheet has three phases, driven by state:

**Phase A — File Selection (before import):**
- Title: `"Bulk Import Questions"`
- Subtitle: `"${widget.subjectName} · ${curriculumLabel}"`
- A `_FilePickerChip` button: `"Select JSON files"` with `Icons.folder_open_outlined`. Tapping it calls `FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['json'])`.
- After files are picked and parsed, show a scrollable list of `_FileValidationTile` widgets — one per file:
  - File name (bold)
  - Topic name (subtitle)
  - Question count badge
  - Image status: `"12 images (all found)"` in green OR `"12 images (2 missing)"` in amber with expandable missing-image list
  - Validation errors (if any) — shown in red, file marked with ❌
  - Valid files marked with ✅
- Below the list: summary row — `"8 valid files · 2 invalid · 47 images (3 missing)"`
- Two action buttons:
  - `"Import All"` (primary, enabled only when at least 1 valid file exists, disabled during import)
  - `"Clear"` (secondary, resets to empty state)

**Phase B — Import in Progress:**
- Same file list but each file shows its current status:
  - ⏳ Pending (grey)
  - 🔄 In progress — shows phase ("Importing…" or "Uploading images 3/7…") with a thin `LinearProgressIndicator`
  - ✅ Done (green)
  - ❌ Failed (red)
- Overall progress: `"File 3 of 8"` at the top
- `"Cancel"` button (sets a flag to stop after the current file completes — do not abort mid-file)

**Phase C — Results:**
- Summary header: `"Import Complete"` (or `"Import Complete with Errors"`)
- Aggregate stats: `"342 questions created · 47 images uploaded · 3 errors"`
- Per-file expandable tiles showing `FileImportResult`:
  - File name + topic
  - `"55 created · 0 errors · 12 images uploaded"` (green)
  - OR `"52 created · 3 errors · 10 images uploaded · 2 failed"` (amber)
  - Expandable: error detail list
- `"Done"` button — pops the sheet and calls `widget.onImported`

**File picking logic:**

```dart
Future<void> _pickFiles() async {
  setState(() => _pickingFiles = true);
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.isNotEmpty) {
      final parsed = <ParsedImportFile>[];
      for (final pf in result.files) {
        if (pf.path == null) continue;
        final file = File(pf.path!);
        final content = await file.readAsString();
        parsed.add(parseImportFile(pf.path!, content));
      }
      // Sort by topic name for readability.
      parsed.sort((a, b) => a.topic.compareTo(b.topic));
      setState(() {
        _parsedFiles = parsed;
        _results = [];
        _completed = false;
        _fatalError = null;
      });
    }
  } catch (_) {
    // Silently ignore picker cancellation.
  } finally {
    if (mounted) setState(() => _pickingFiles = false);
  }
}
```

**Import execution logic:**

```dart
Future<void> _importAll() async {
  final validFiles = _parsedFiles.where((f) => f.isValid).toList();
  if (validFiles.isEmpty) return;

  setState(() {
    _importing = true;
    _results = [];
    _completed = false;
    _fatalError = null;
  });

  final questionBankService = client.questionBank; // from client.dart
  final token = accessToken; // from client.dart globals

  for (var i = 0; i < validFiles.length; i++) {
    if (!_importing) break; // cancelled

    setState(() {
      _currentFileIndex = i;
      _currentPhase = 'importing';
      _currentDetail = 'Preparing…';
      _currentProgress = 0.0;
    });

    final result = await questionBankService.importFileWithImages(
      parsed: validFiles[i],
      accessToken: token,
      onProgress: (phase, detail, progress) {
        if (mounted) {
          setState(() {
            _currentPhase = phase;
            _currentDetail = detail;
            _currentProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _results.add(result);
      });
    }
  }

  if (mounted) {
    setState(() {
      _importing = false;
      _completed = true;
      _currentFileIndex = -1;
    });
    // Notify parent to refresh topic counts.
    if (_results.any((r) => r.questionsCreated > 0)) {
      widget.onImported?.call();
    }
  }
}
```

**Styling rules (per AGENT.md §21):**

- Typography: body `w300`/`w400`, labels `w500` max.
- Border radius: `AppTheme.kModalRadius` (12) for the sheet, `AppTheme.kCardRadius` (8) for file tiles, `AppTheme.kChipRadius` (4) for badges.
- Internal padding: `12–16 px`.
- Gaps between items: `6–8 px`.
- Dark mode colors via `AppTheme.modalBg`, `AppTheme.nestedBg`, `AppTheme.borderColor`.
- File list uses data-table style (thin dividers, not cards) per `AppTheme.tableRowDivider`.
- Action buttons use `_ActionChip` pattern from `subject_bulk_import_sheet.dart`.
- Loading state: `16×16 CircularProgressIndicator(strokeWidth: 1.5)`.
- Success/error indicators: green check (`Icons.check_circle_rounded`), red error (`Icons.error_outline_rounded`), amber warning (`Icons.warning_amber_rounded`).

**Imports needed:**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../client.dart';
import '../../../../services/import_file_parser.dart';
import '../../../../services/question_bank.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';
```

**Important BUG-010 compliance:** The sheet must be **self-contained** — it wraps itself in `EduSheet` and does NOT expect the caller to add extra chrome. The caller launches it via:
```dart
showEduSheet(
  context: context,
  maxWidth: 620,
  builder: (_) => MultiFileImportSheet(...),
);
```

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — add entry for `multi_file_import_sheet.dart`
- [ ] Mark this task `[x]`

---

## Task 06: Wire Up `MultiFileImportSheet` in `SubjectsSection`

**Files to modify:** `lib/ui/screens/system/settings/subjects_section.dart`
**Context files to read:** `lib/ui/screens/system/CONTEXT.md`
**Depends on:** Task 05
**Parallel group:** None (sequential)

**Specification:**

Replace the `SubjectBulkImportSheet` launch in `_SubjectTile` with the new `MultiFileImportSheet`.

**Step 1:** Add import at the top of `subjects_section.dart`:

```dart
import 'multi_file_import_sheet.dart';
```

**Step 2:** In `_SubjectTileState`, find the `_TinyAction` with `icon: Icons.upload_file_outlined` and `tooltip: 'Bulk import questions'` (currently around line 522–534 in the original file). Change the `onTap` handler from:

```dart
onTap: () {
  showEduSheet(
    context: context,
    maxWidth: 560,
    builder: (_) => SubjectBulkImportSheet(
      subjectName: subject.name,
      subjectId: subject.id,
      curriculum: widget.curriculum,
      onImported: () {
        setState(() {});
      },
    ),
  );
},
```

To:

```dart
onTap: () {
  showEduSheet(
    context: context,
    maxWidth: 620,
    builder: (_) => MultiFileImportSheet(
      subjectName: subject.name,
      subjectId: subject.id,
      curriculum: widget.curriculum,
      onImported: () {
        setState(() {});
      },
    ),
  );
},
```

**Step 3:** Optionally update the tooltip from `'Bulk import questions'` to `'Import question files'` to reflect the multi-file nature.

**Do NOT delete** `subject_bulk_import_sheet.dart` — it still works for the paste-only workflow and may be useful as a fallback. Just change the wiring so the button opens the new multi-file sheet.

**Update after completion:**
- [ ] Update `lib/ui/screens/system/CONTEXT.md` — note `_SubjectTile` now opens `MultiFileImportSheet`
- [ ] Mark this task `[x]`

---

## Dependency Graph

```
P1 (Backend: B1 + B2) ─────────────────────────────────┐
                                                        │
Task 01 (update BulkImportResult model) ←───── P1 ─────┤
Task 02 (ImportFileParser utility)      ←── (none) ─────┤── Parallel group P1
Task 03 (uploadFileToUrl method)        ←── (none) ─────┤
Task 03b (rewrite requestImageUploadUrls) ←── P1 ───────┘
                                                        │
Task 04 (importFileWithImages orchestr) ←── 01, 02, 03, 03b ── Sequential
                                                        │
Task 05 (MultiFileImportSheet UI)       ←── 02, 04 ─────┤── Sequential
                                                        │
Task 06 (Wire up in SubjectsSection)    ←── 05 ─────────┘── Sequential
```

**Parallel execution plan:**
- **Batch 1:** Tasks 02 (✅ DONE), 03 (✅ DONE) — already completed
- **Batch 2 (after P1/stubs):** Tasks 01, 03b in parallel (disjoint areas: `models/question.dart`, `services/question_bank.dart` line ~252)
- **Batch 3:** Task 04 (modifies `services/question_bank.dart` — must wait for 01 + 03b)
- **Batch 4:** Task 05 (new file, no conflicts)
- **Batch 5:** Task 06 (modifies `subjects_section.dart`)