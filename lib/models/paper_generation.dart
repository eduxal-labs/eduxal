import 'package:fixnum/fixnum.dart' show Int64;

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
  final String text;
  final int marks;
  final List<RubricCriterion> rubric;
  final List<QuestionImage> images;
  final int order;
  final String? section; // 'A', 'B', 'C', or null
  const PaperQuestion({
    required this.id,
    required this.questionId,
    required this.text,
    required this.marks,
    required this.rubric,
    required this.images,
    required this.order,
    this.section,
  });

  factory PaperQuestion.fromProto(pb.PaperQuestion proto) {
    final q = proto.question;
    return PaperQuestion(
      id: q.id.toString(),
      questionId: q.id,
      text: q.text,
      marks: q.marks,
      rubric: q.rubric.map(RubricCriterion.fromProto).toList(),
      images: q.images.map(QuestionImage.fromProto).toList(),
      order: proto.position,
      section: proto.hasSection() ? proto.section : null,
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

  factory PaperPdf.fromProto(pb.FinalizePaperResponse proto) => PaperPdf(
    pdfUrl: proto.pdfUrl,
    pdfExpiry: DateTime.fromMillisecondsSinceEpoch(
      proto.pdfExpiry.toInt() * 1000,
    ),
    markingSchemeUrl: proto.hasMarkingSchemeUrl()
        ? proto.markingSchemeUrl
        : null,
    markingSchemeExpiry: proto.hasMarkingSchemeExpiry()
        ? DateTime.fromMillisecondsSinceEpoch(
            proto.markingSchemeExpiry.toInt() * 1000,
          )
        : null,
  );

  factory PaperPdf.fromGetPdfProto(pb.GetPaperPdfResponse proto) => PaperPdf(
    pdfUrl: proto.pdfUrl,
    pdfExpiry: DateTime.fromMillisecondsSinceEpoch(
      proto.pdfExpiry.toInt() * 1000,
    ),
    // GetPaperPdfResponse does not carry a marking scheme URL — stays null.
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

  factory StreamCopyResult.fromProto(pb.StreamCopyResult proto) {
    return StreamCopyResult(
      stream: proto.stream,
      success: proto.success,
      pdfUrl: proto.pdfUrl.isEmpty ? null : proto.pdfUrl,
      pdfExpiry: proto.pdfExpiry == Int64.ZERO
          ? null
          : DateTime.fromMillisecondsSinceEpoch(proto.pdfExpiry.toInt() * 1000),
      markingSchemeUrl: proto.markingSchemeUrl.isEmpty
          ? null
          : proto.markingSchemeUrl,
      markingSchemeExpiry: proto.markingSchemeExpiry == Int64.ZERO
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              proto.markingSchemeExpiry.toInt() * 1000,
            ),
      error: proto.error.isEmpty ? null : proto.error,
    );
  }
}
