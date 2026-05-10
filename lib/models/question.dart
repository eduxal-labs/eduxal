import 'dart:convert';

import '../proto/services/question_bank.pb.dart' as pb;

/// Image context for where the image appears on a question.
enum ImageContext { question, rubric, exampleAnswer }

/// A single rubric criterion with its mark allocation.
class RubricCriterion {
  final String criterion;
  final int marks;
  const RubricCriterion({required this.criterion, required this.marks});

  factory RubricCriterion.fromProto(pb.RubricCriterion proto) =>
      RubricCriterion(criterion: proto.criterion, marks: proto.marks);

  factory RubricCriterion.fromMap(Map<String, dynamic> m) => RubricCriterion(
    criterion: m['criterion'] as String? ?? '',
    marks: m['marks'] as int? ?? 0,
  );
}

/// An image attached to a question (client-side only; no longer in proto).
class QuestionImage {
  final ImageContext context;
  final String filename;
  final String? caption;
  final String description;
  final String? getUrl;
  const QuestionImage({
    required this.context,
    required this.filename,
    this.caption,
    required this.description,
    this.getUrl,
  });
}

/// A labelled sub-question (part) within a structured question.
class QuestionPart {
  final String label; // e.g. 'a', 'b', 'i', 'ii'
  final String body; // part question text
  final String bodyFormat; // 'plain' | 'tiptap'
  final int marks;
  final String
  answerSpaceType; // 'lines' | 'plain_box' | 'diagram_box' | 'construction_box' | 'grid_box'
  final int answerLines; // lines count when answerSpaceType == 'lines'
  final int answerBoxHeightMm; // box height in mm for box types
  final List<RubricCriterion> rubric;
  final dynamic
  exampleAnswer; // String (old) or Map<String, dynamic>{format, content} (new)

  const QuestionPart({
    required this.label,
    required this.body,
    this.bodyFormat = 'plain',
    required this.marks,
    this.answerSpaceType = 'lines',
    this.answerLines = 4,
    this.answerBoxHeightMm = 80,
    this.rubric = const [],
    this.exampleAnswer,
  });

  factory QuestionPart.fromMap(Map<String, dynamic> m) => QuestionPart(
    label: m['label'] as String? ?? '',
    body: m['body'] as String? ?? '',
    bodyFormat: m['body_format'] as String? ?? 'plain',
    marks: m['marks'] as int? ?? 0,
    answerSpaceType: m['answer_space_type'] as String? ?? 'lines',
    answerLines: m['answer_lines'] as int? ?? 4,
    answerBoxHeightMm: m['answer_box_height_mm'] as int? ?? 80,
    rubric:
        (m['rubric'] as List<dynamic>?)
            ?.map((e) => RubricCriterion.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    exampleAnswer: m['example_answer'],
  );
}

/// A question in the question bank.
class Question {
  final int id;
  final int topicId;

  /// Legacy text field — equals [body] for all questions created after proto migration.
  final String text;
  final String body;
  final String bodyFormat; // 'plain' | 'tiptap'
  final List<QuestionPart> parts;
  final Map<String, dynamic>? stimulus; // {type, body, body_format, caption?}
  final String
  type; // 'definition'|'explanation'|'calculation'|'structured'|'experiment'|'data_response'|'diagram'
  final int difficulty; // 1–5
  final String
  cognitiveLevel; // 'recall'|'comprehension'|'application'|'analysis'
  final int marks;
  final int maxMarks; // <= marks; for partial-credit questions
  final String
  answerSpaceType; // 'lines'|'plain_box'|'diagram_box'|'construction_box'|'grid_box'
  final int answerLines; // line count when answerSpaceType == 'lines'
  final List<RubricCriterion> rubric;
  final dynamic exampleAnswer;

  /// Client-side image list — not populated from proto (proto no longer carries images on Question).
  final List<QuestionImage> images;
  final DateTime created;
  final DateTime updated;

  const Question({
    required this.id,
    required this.topicId,
    required this.text,
    String? body,
    this.bodyFormat = 'plain',
    this.parts = const [],
    this.stimulus,
    this.type = 'definition',
    this.difficulty = 3,
    this.cognitiveLevel = 'recall',
    required this.marks,
    int? maxMarks,
    this.answerSpaceType = 'lines',
    this.answerLines = 4,
    required this.rubric,
    this.exampleAnswer,
    required this.images,
    required this.created,
    required this.updated,
  }) : body = body ?? text,
       maxMarks = maxMarks ?? marks;

  // ── Proto enum → string conversion helpers ──────────────────────────────

  static String _bodyFmtStr(int v) => v == 1 ? 'tiptap' : 'plain';

  static const _typeStrs = [
    'definition',
    'explanation',
    'calculation',
    'structured',
    'experiment',
    'data_response',
    'diagram',
  ];

  static const _cognitiveStrs = [
    'recall',
    'comprehension',
    'application',
    'analysis',
  ];

  static const _answerSpaceStrs = [
    'lines',
    'plain_box',
    'diagram_box',
    'construction_box',
    'grid_box',
  ];

  /// Factory to create from proto message.
  /// Proto [created] and [updated] are Int64 seconds since epoch.
  factory Question.fromProto(pb.Question proto) {
    List<QuestionPart> parts = [];
    try {
      parts = proto.parts
          .map(
            (p) => QuestionPart.fromMap({
              'label': p.label,
              'body': p.body,
              'body_format': p.hasBodyFormat()
                  ? _bodyFmtStr(p.bodyFormat)
                  : 'plain',
              'marks': p.marks,
              'answer_space_type': p.hasAnswerSpaceType()
                  ? _answerSpaceStrs[p.answerSpaceType.clamp(0, 4)]
                  : 'lines',
              'answer_lines': p.answerLines,
              'answer_box_height_mm': p.answerBoxHeightMm,
              'rubric': p.rubric
                  .map((r) => {'criterion': r.criterion, 'marks': r.marks})
                  .toList(),
              'example_answer': p.hasExampleAnswer() ? p.exampleAnswer : null,
            }),
          )
          .toList();
    } catch (_) {}

    Map<String, dynamic>? stimulus;
    try {
      if (proto.hasStimulus() && proto.stimulus.isNotEmpty) {
        stimulus = jsonDecode(proto.stimulus) as Map<String, dynamic>;
      }
    } catch (_) {}

    return Question(
      id: proto.id,
      topicId: proto.topicId,
      // proto no longer has a `text` field — use `body` for both
      text: proto.body,
      body: proto.hasBody() ? proto.body : '',
      bodyFormat: proto.hasBodyFormat()
          ? _bodyFmtStr(proto.bodyFormat)
          : 'plain',
      parts: parts,
      stimulus: stimulus,
      type: proto.hasType() ? _typeStrs[proto.type.clamp(0, 6)] : 'definition',
      difficulty: proto.hasDifficulty() ? proto.difficulty.clamp(1, 5) : 3,
      cognitiveLevel: proto.hasCognitiveLevel()
          ? _cognitiveStrs[proto.cognitiveLevel.clamp(0, 3)]
          : 'recall',
      marks: proto.marks,
      maxMarks: proto.hasMaxMarks() ? proto.maxMarks : proto.marks,
      answerSpaceType: proto.hasAnswerSpaceType()
          ? _answerSpaceStrs[proto.answerSpaceType.clamp(0, 4)]
          : 'lines',
      answerLines: proto.hasAnswerLines() ? proto.answerLines : 4,
      rubric: proto.rubric.map(RubricCriterion.fromProto).toList(),
      exampleAnswer: proto.hasExampleAnswer() ? proto.exampleAnswer : null,
      // proto.images no longer exists in the updated proto; images are client-managed
      images: const [],
      created: DateTime.fromMillisecondsSinceEpoch(
        proto.created.toInt() * 1000,
      ),
      updated: DateTime.fromMillisecondsSinceEpoch(
        proto.updated.toInt() * 1000,
      ),
    );
  }
}

/// Result of a bulk import operation.
class BulkImportResult {
  final int createdCount;

  /// Server-assigned question IDs for the created questions (not populated).
  final List<int> questionIds;

  /// Per-question server-side errors from the import (partial success).
  final List<ImportError> errors;

  const BulkImportResult({
    required this.createdCount,
    required this.questionIds,
    required this.errors,
  });

  factory BulkImportResult.fromProto(pb.BulkImportResponse proto) {
    final importErrors = <ImportError>[];
    for (final err in proto.errors) {
      // Server errors are formatted as "Q{1-based idx}: {message}"
      final match = RegExp(r'^Q(\d+):\s*(.*)').firstMatch(err);
      if (match != null) {
        final idx = int.tryParse(match.group(1)!) ?? importErrors.length;
        importErrors.add(ImportError(
          index: idx - 1, // convert to 0-based
          message: match.group(2)!,
        ));
      } else {
        importErrors.add(ImportError(
          index: importErrors.length,
          message: err,
        ));
      }
    }
    return BulkImportResult(
      createdCount: proto.created,
      questionIds: const [],
      errors: importErrors,
    );
  }
}

/// A single error from a bulk import operation.
class ImportError {
  /// 0-based question index in the import batch.
  final int index;
  final String message;
  const ImportError({required this.index, required this.message});
}
