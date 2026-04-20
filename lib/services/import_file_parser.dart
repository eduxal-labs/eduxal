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
  final List<MissingImage> missingImages;

  /// Structural validation errors (bad JSON, missing fields, etc.).
  final List<String> validationErrors;

  /// The cleaned JSON string with image filenames stripped to basenames.
  /// Null if validationErrors is non-empty.
  final String? cleanedJson;

  /// Mapping from basename → absolute local path for every found image.
  final Map<String, String> imagePathMap;

  /// Per-question image basenames, indexed by question position in the JSON
  /// array. Only includes questions that have images.
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
/// This parser is intentionally school-agnostic for the system question-bank
/// import flow. It validates only file-local question payload structure
/// (`subject`, `curriculum`, `grade`, `topic`, `questions`, and image
/// references) and does not derive, inject, or require any school identifier.
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
  if (rawSubject == null ||
      rawSubject is! String ||
      rawSubject.trim().isEmpty) {
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
        if (rawFilename == null ||
            rawFilename is! String ||
            rawFilename.trim().isEmpty) {
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
          missingImages.add(
            MissingImage(
              questionIndex: i,
              filename: basename,
              absolutePath: absolutePath,
            ),
          );
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
