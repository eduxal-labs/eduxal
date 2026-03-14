import '../database/database.dart';

// ─── Stream Comparison Stats ────────────────────────────────────────────────

/// Statistics for one stream within a grade — used on the Comparisons tab.
class StreamStats {
  const StreamStats({
    required this.streamCode,
    required this.streamName,
    required this.studentCount,
    required this.averageScore,
    required this.lastExamAverage,
    required this.trajectory,
    required this.attendanceRate,
    required this.masteryAverage,
  });

  final int streamCode;
  final String streamName;
  final int studentCount;

  /// Overall average percentage across all exams for this stream.
  final double averageScore;

  /// Average percentage on the most recent exam (null if no exams graded yet).
  final double? lastExamAverage;

  /// Trajectory enum: improving / declining / stable / insufficient data.
  final Trajectory trajectory;

  /// Attendance rate as a percentage (0–100). null if no attendance data.
  final double? attendanceRate;

  /// Average mastery percentage across all subjects for students in this stream.
  final double? masteryAverage;
}

/// Trajectory direction for a stream or student.
enum Trajectory { improving, declining, stable, insufficientData }

// ─── Subject-Teacher-Stream combo for the Subjects tab ──────────────────────

/// One row on the Subjects tab: a subject taught in a specific stream by a
/// specific teacher, together with mastery averages.
class SubjectTeacherEntry {
  const SubjectTeacherEntry({
    required this.subject,
    required this.subjectName,
    required this.streamCode,
    required this.streamName,
    required this.teacher,
    required this.streamMasteryAverage,
    required this.gradeMasteryAverage,
  });

  final SubjectTeacher subject;

  /// Human-readable subject name from the `subjects` table (via JOIN).
  final String subjectName;

  final int streamCode;
  final String streamName;
  final UsersData teacher;

  /// Average mastery for this (subject, teacher, stream) combo across all
  /// students enrolled in this stream. null if no mastery data.
  final double? streamMasteryAverage;

  /// Average mastery for this subject across ALL streams in the grade.
  /// null if no mastery data.
  final double? gradeMasteryAverage;
}

// ─── Student row for the Students tab ───────────────────────────────────────

/// One student row on the Students tab — enriched with trajectory info.
class GradeStudentRow {
  const GradeStudentRow({
    required this.student,
    required this.enrollment,
    required this.trajectory,
    required this.lastExamPercent,
    required this.overallAverage,
  });

  final StudentsData student;
  final Enrollment enrollment;
  final Trajectory trajectory;

  /// Percentage on the most recent exam. null if not yet graded.
  final double? lastExamPercent;

  /// Overall average percentage across all exams. null if no grades.
  final double? overallAverage;
}

// ─── Class Teacher History Entry ────────────────────────────────────────────

/// One class teacher assignment — used on the Teachers tab.
class ClassTeacherHistoryEntry {
  const ClassTeacherHistoryEntry({
    required this.classTeacher,
    required this.user,
    required this.isActive,
  });

  final ClassTeacher classTeacher;
  final UsersData user;

  /// True when `classTeacher.end` is null (currently active).
  final bool isActive;
}
