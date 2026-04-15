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
  const PaperQuestion({
    required this.id,
    required this.questionId,
    required this.text,
    required this.marks,
    required this.rubric,
    required this.images,
    required this.order,
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
    );
  }
}

/// Result of paper finalization — contains the PDF URL.
class PaperPdf {
  final String pdfUrl;
  final DateTime pdfExpiry;
  const PaperPdf({required this.pdfUrl, required this.pdfExpiry});

  factory PaperPdf.fromProto(pb.FinalizePaperResponse proto) => PaperPdf(
    pdfUrl: proto.pdfUrl,
    pdfExpiry: DateTime.fromMillisecondsSinceEpoch(
      proto.pdfExpiry.toInt() * 1000,
    ),
  );

  factory PaperPdf.fromGetPdfProto(pb.GetPaperPdfResponse proto) => PaperPdf(
    pdfUrl: proto.pdfUrl,
    pdfExpiry: DateTime.fromMillisecondsSinceEpoch(
      proto.pdfExpiry.toInt() * 1000,
    ),
  );
}
