import 'dart:convert';

import 'question.dart';
import '../proto/services/question_bank.pb.dart' as pb;

/// A topic with its mark allocation for paper generation.
class TopicAllocation {
  final int topicId;
  final String topicName; // For display only — not sent to server
  int marks;
  TopicAllocation({
    required this.topicId,
    required this.topicName,
    this.marks = 0,
  });
}

/// A generated question for a paper (before finalization).
class PaperQuestion {
  final String id;
  final int questionId;

  /// Legacy text field — equals [body] for all questions created after proto migration.
  final String text;
  final String body;
  final String bodyFormat; // 'plain' | 'tiptap'
  final List<QuestionPart> parts;
  final Map<String, dynamic>? stimulus; // {type, body, body_format, caption?}
  final String
  type; // 'definition'|'explanation'|'calculation'|'structured'|'experiment'|'data_response'|'diagram'
  final int difficulty; // 1–5
  final int marks;
  final List<RubricCriterion> rubric;
  final List<QuestionImage> images;
  final String
  answerSpaceType; // 'lines'|'plain_box'|'diagram_box'|'construction_box'|'grid_box'
  final int answerLines; // line count when answerSpaceType == 'lines'
  final int order;
  final String? section; // 'A', 'B', 'C', or null

  const PaperQuestion({
    required this.id,
    required this.questionId,
    required this.text,
    String? body,
    this.bodyFormat = 'plain',
    this.parts = const [],
    this.stimulus,
    this.type = 'definition',
    this.difficulty = 3,
    required this.marks,
    required this.rubric,
    required this.images,
    this.answerSpaceType = 'lines',
    this.answerLines = 4,
    required this.order,
    this.section,
  }) : body = body ?? text;

  factory PaperQuestion.fromProto(pb.Question proto, [int order = 0]) {
    // Int-to-string helpers — mirrors Question._bodyFmtStr etc. in question.dart
    String bodyFmtStr(int v) => v == 1 ? 'tiptap' : 'plain';
    const typeStrs = [
      'definition',
      'explanation',
      'calculation',
      'structured',
      'experiment',
      'data_response',
      'diagram',
    ];
    const answerSpaceStrs = [
      'lines',
      'plain_box',
      'diagram_box',
      'construction_box',
      'grid_box',
    ];

    List<QuestionPart> parts = [];
    try {
      parts = proto.parts
          .map(
            (p) => QuestionPart.fromMap({
              'label': p.label,
              'body': p.body,
              'body_format': p.hasBodyFormat()
                  ? bodyFmtStr(p.bodyFormat)
                  : 'plain',
              'marks': p.marks,
              'answer_space_type': p.hasAnswerSpaceType()
                  ? answerSpaceStrs[p.answerSpaceType.clamp(0, 4)]
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

    return PaperQuestion(
      id: proto.id.toString(),
      questionId: proto.id,
      // proto no longer has a `text` field — use `body` for both
      text: proto.body,
      body: proto.hasBody() ? proto.body : '',
      bodyFormat: proto.hasBodyFormat()
          ? bodyFmtStr(proto.bodyFormat)
          : 'plain',
      parts: parts,
      stimulus: stimulus,
      type: proto.hasType() ? typeStrs[proto.type.clamp(0, 6)] : 'definition',
      difficulty: proto.hasDifficulty() ? proto.difficulty.clamp(1, 5) : 3,
      marks: proto.marks,
      rubric: proto.rubric.map(RubricCriterion.fromProto).toList(),
      // proto.images no longer exists in the updated proto; images are client-managed
      images: const [],
      answerSpaceType: proto.hasAnswerSpaceType()
          ? answerSpaceStrs[proto.answerSpaceType.clamp(0, 4)]
          : 'lines',
      answerLines: proto.hasAnswerLines() ? proto.answerLines : 4,
      // position and section are no longer in the proto (no PaperQuestion wrapper)
      order: order,
      section: null,
    );
  }
}

/// Result of paper finalization — contains the PDF URL and optional marking
/// scheme URL (only present when the server generates a marking scheme PDF).
class PaperPdf {
  final String pdfUrl;
  final DateTime pdfExpiry;
  final String? markingSchemeUrl; // null when not generated / not available
  final DateTime? markingSchemeExpiry; // null when markingSchemeUrl is null

  const PaperPdf({
    required this.pdfUrl,
    required this.pdfExpiry,
    this.markingSchemeUrl,
    this.markingSchemeExpiry,
  });

  /// Constructs a [PaperPdf] from a [pb.FinalizePaperResponse].
  ///
  /// After M0 proto regeneration, [pb.FinalizePaperResponse] no longer carries
  /// presigned URL fields. It now returns storage keys (`pdfKey`, `msKey`).
  /// The keys are stored as-is in [pdfUrl] / [markingSchemeUrl] until a signed
  /// URL is obtained separately by the client.
  factory PaperPdf.fromProto(pb.FinalizePaperResponse proto) => PaperPdf(
    pdfUrl: proto.pdfKey,
    // Expiry is unknown at this point — use a 1-hour placeholder.
    pdfExpiry: DateTime.now().add(const Duration(hours: 1)),
    markingSchemeUrl: proto.hasMsKey() && proto.msKey.isNotEmpty
        ? proto.msKey
        : null,
    markingSchemeExpiry: proto.hasMsKey() && proto.msKey.isNotEmpty
        ? DateTime.now().add(const Duration(hours: 1))
        : null,
  );
}

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
}
