import '../proto/services/question_bank.pb.dart' as pb;
import '../proto/services/question_bank.pbenum.dart' as pbenum;

/// Image context for where the image appears on a question.
enum ImageContext { question, rubric, exampleAnswer }

/// A single rubric criterion with its mark allocation.
class RubricCriterion {
  final String criterion;
  final int marks;
  const RubricCriterion({required this.criterion, required this.marks});

  factory RubricCriterion.fromProto(pb.RubricCriterion proto) =>
      RubricCriterion(criterion: proto.criterion, marks: proto.marks);
}

/// An image attached to a question.
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

  factory QuestionImage.fromProto(pb.QuestionImage proto) => QuestionImage(
    context: _imageContextFromProto(proto.context),
    filename: proto.filename,
    caption: proto.hasCaption() ? proto.caption : null,
    description: proto.description,
    getUrl: proto.hasGetUrl() ? proto.getUrl : null,
  );
}

ImageContext _imageContextFromProto(pbenum.ImageContext proto) =>
    switch (proto) {
      pbenum.ImageContext.QUESTION => ImageContext.question,
      pbenum.ImageContext.RUBRIC => ImageContext.rubric,
      pbenum.ImageContext.EXAMPLE_ANSWER => ImageContext.exampleAnswer,
      _ => ImageContext.question,
    };

/// A question in the question bank.
class Question {
  final int id;
  final int topicId;
  final String text;
  final int marks;
  final List<RubricCriterion> rubric;
  final String? exampleAnswer;
  final List<QuestionImage> images;
  final DateTime created;
  final DateTime updated;
  const Question({
    required this.id,
    required this.topicId,
    required this.text,
    required this.marks,
    required this.rubric,
    this.exampleAnswer,
    required this.images,
    required this.created,
    required this.updated,
  });

  /// Factory to create from proto message.
  /// Proto `created` and `updated` are Int64 seconds since epoch.
  factory Question.fromProto(pb.Question proto) => Question(
    id: proto.id,
    topicId: proto.topicId,
    text: proto.text,
    marks: proto.marks,
    rubric: proto.rubric.map(RubricCriterion.fromProto).toList(),
    exampleAnswer: proto.hasExampleAnswer() ? proto.exampleAnswer : null,
    images: proto.images.map(QuestionImage.fromProto).toList(),
    created: DateTime.fromMillisecondsSinceEpoch(proto.created.toInt() * 1000),
    updated: DateTime.fromMillisecondsSinceEpoch(proto.updated.toInt() * 1000),
  );
}

/// Result of a bulk import operation.
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

/// A single error from a bulk import operation.
class ImportError {
  final int index;
  final String message;
  const ImportError({required this.index, required this.message});

  factory ImportError.fromProto(pb.ImportError proto) =>
      ImportError(index: proto.index, message: proto.message);
}
