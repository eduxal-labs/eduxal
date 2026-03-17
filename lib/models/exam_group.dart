import '../database/database.dart';
import '../database/tables/enums.dart';

/// A logical exam grouping — exams that share the same
/// (school, year, term, type, start, end) are presented to the user
/// as a single exam entity.
///
/// In the normal case there is exactly **one** exam row per group.
/// The `exams` table has no grade/stream columns — a single exam can
/// span multiple grades and streams via its `papers` rows.
/// The grouping key exists to handle legacy data or edge cases where
/// multiple exam rows were created with identical metadata.
class ExamGroup {
  final String school;
  final int year;
  final int term;
  final ExamType type;
  final int start; // days since epoch
  final int end; // days since epoch
  final bool personalized;
  final UsersData teacher; // teacher from the first exam row (creator)
  final List<ExamGradeEntry> grades; // one per participating grade

  ExamGroup({
    required this.school,
    required this.year,
    required this.term,
    required this.type,
    required this.start,
    required this.end,
    required this.personalized,
    required this.teacher,
    required this.grades,
  });

  /// Unique grouping key for identification.
  String get groupKey => '$school|$year|$term|${type.index}|$start|$end';

  /// All exam row IDs in this group.
  List<String> get examIds => grades.expand((g) => g.examIds).toList();

  /// Total number of unique subjects across all papers in all grades.
  int get uniqueSubjectCount {
    final subjects = <int>{};
    for (final g in grades) {
      for (final p in g.papers) {
        subjects.add(p.subject);
      }
    }
    return subjects.length;
  }

  /// All participating grade indices.
  List<int> get participatingGrades =>
      grades.map((g) => g.grade).toSet().toList()..sort();
}

/// One grade's worth of papers within an exam group.
/// Papers are grouped by stream within each grade. Typically all papers
/// reference the same exam row (since exams have no grade/stream columns).
class ExamGradeEntry {
  final int grade;
  final List<ExamStreamEntry>
  streams; // one per stream (or one with stream=null)

  ExamGradeEntry({required this.grade, required this.streams});

  List<String> get examIds => streams.map((s) => s.exam.id).toList();

  List<Paper> get papers => streams.expand((s) => s.papers).toList();
}

/// Papers for a specific stream within a grade, linked back to the
/// parent exam row. Typically all streams share the same [exam] reference
/// since exams have no grade/stream columns — the stream is on the paper.
class ExamStreamEntry {
  final Exam exam;
  final int? streamCode; // null = grade-wide papers (no stream filter)
  final List<Paper> papers;

  ExamStreamEntry({
    required this.exam,
    required this.streamCode,
    required this.papers,
  });
}
