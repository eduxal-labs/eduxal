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

  factory RubricResult.fromProto(pb.RubricCriterion proto) => RubricResult(
    criterion: proto.criterion,
    satisfied: proto.marks > 0,
    marksAwarded: proto.marks.toDouble(),
    marksAvailable: proto.marks,
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

  /// Constructs from [pb.QuestionGrade].
  ///
  /// After M0 proto regeneration, the response carries [pb.QuestionGrade]
  /// (questionId, score, feedback) instead of the richer QuestionGradeDetail
  /// message. Fields not present in the new proto are stubbed with defaults.
  factory QuestionGradeDetail.fromProto(pb.QuestionGrade proto) =>
      QuestionGradeDetail(
        questionText: '', // not available in QuestionGrade (M0 proto change)
        marksAwarded: proto.score.toDouble(),
        totalMarks: 0, // not available in QuestionGrade (M0 proto change)
        feedback: proto.feedback,
        rubricResults:
            const [], // not available in QuestionGrade (M0 proto change)
      );
}
