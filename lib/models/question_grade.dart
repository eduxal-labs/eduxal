import '../proto/services/question_bank.pb.dart' as pb;

/// Per-rubric-criterion result from AI marking.
class RubricResult {
  final String criterion;
  final bool satisfied;
  final double marksAwarded;
  final int marksAvailable;
  const RubricResult({
    required this.criterion,
    required this.satisfied,
    required this.marksAwarded,
    required this.marksAvailable,
  });

  factory RubricResult.fromProto(pb.RubricResult proto) => RubricResult(
    criterion: proto.criterion,
    satisfied: proto.satisfied,
    marksAwarded: proto.marksAwarded,
    marksAvailable: proto.marksAvailable,
  );
}

/// Per-question grade breakdown from AI marking.
class QuestionGradeDetail {
  final String questionText;
  final double marksAwarded;
  final int totalMarks;
  final String feedback;
  final List<RubricResult> rubricResults;
  const QuestionGradeDetail({
    required this.questionText,
    required this.marksAwarded,
    required this.totalMarks,
    required this.feedback,
    required this.rubricResults,
  });

  factory QuestionGradeDetail.fromProto(pb.QuestionGrade proto) =>
      QuestionGradeDetail(
        questionText: proto.questionText,
        marksAwarded: proto.marksAwarded,
        totalMarks: proto.totalMarks,
        feedback: proto.feedback,
        rubricResults: proto.rubricResults.map(RubricResult.fromProto).toList(),
      );
}
