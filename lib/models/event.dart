/// Generation phases for a scheduled paper.
enum PaperGenerationPhase {
  pending, // not yet started — exam is in the future
  generating, // server is generating student papers
  complete, // all student papers are ready
  failed, // generation failed
}

/// An exam event created by a school admin.
class ExamEvent {
  final String id;
  final String schoolId;
  final String name;
  final String type; // 'exam' | 'mock' | 'holiday_revision'
  final int term; // 1 | 2 | 3
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final List<ScheduledPaper> papers;

  const ExamEvent({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.type,
    required this.term,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.papers = const [],
  });
}

/// A paper (one subject × one grade × one stream) scheduled within an event.
class ScheduledPaper {
  final String scheduleId;
  final String eventId;
  final int subjectId;
  final String subjectName;
  final int grade;
  final int? stream; // null = all streams
  final DateTime date;
  final int startMinutes; // minutes since midnight
  final int endMinutes; // minutes since midnight
  final String? invigilatorId;
  final String? invigilatorName;
  final PaperGenerationPhase phase;
  final int totalStudents;
  final int generatedCount;

  const ScheduledPaper({
    required this.scheduleId,
    required this.eventId,
    required this.subjectId,
    required this.subjectName,
    required this.grade,
    this.stream,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    this.invigilatorId,
    this.invigilatorName,
    this.phase = PaperGenerationPhase.pending,
    this.totalStudents = 0,
    this.generatedCount = 0,
  });

  int get durationMinutes => endMinutes - startMinutes;

  /// Human-readable time range, e.g. "08:00 – 10:00".
  String get timeRange {
    String fmt(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '${fmt(startMinutes)} – ${fmt(endMinutes)}';
  }

  /// Exact DateTime when the exam starts (combines date + startMinutes).
  DateTime get startDateTime => DateTime(
    date.year,
    date.month,
    date.day,
  ).add(Duration(minutes: startMinutes));
}
