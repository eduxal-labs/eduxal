import 'dart:convert';
import '../database/tables/enums.dart';

/// Global timetable generation rules — applies to the entire school for one term.
///
/// Persisted as JSON in the app documents directory at:
///   {appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json
class TimetableRules {
  TimetableRules({
    this.dayStartSeconds = 8 * 3600,
    this.dayEndSeconds = 16 * 3600,
    this.lessonDurationMinutes = 40,
    this.breakDurationMinutes = 10,
    this.lunchStartSeconds = 12 * 3600 + 30 * 60,
    this.lunchDurationMinutes = 60,
    this.maxLessonsPerDayTeacher = 6,
    this.maxLessonsPerDayClass = 8,
    this.allowDoubles = false,
    List<DayOfWeek>? activeDays,
    List<TeacherBlockRule>? teacherBlocks,
    List<SubjectBlockRule>? subjectBlocks,
  }) : activeDays =
           activeDays ??
           [
             DayOfWeek.monday,
             DayOfWeek.tuesday,
             DayOfWeek.wednesday,
             DayOfWeek.thursday,
             DayOfWeek.friday,
           ],
       teacherBlocks = teacherBlocks ?? [],
       subjectBlocks = subjectBlocks ?? [];

  int dayStartSeconds;
  int dayEndSeconds;
  int lessonDurationMinutes;
  int breakDurationMinutes;
  int lunchStartSeconds;
  int lunchDurationMinutes;
  int maxLessonsPerDayTeacher;
  int maxLessonsPerDayClass;
  bool allowDoubles;
  List<DayOfWeek> activeDays;
  List<TeacherBlockRule> teacherBlocks;
  List<SubjectBlockRule> subjectBlocks;

  /// Generates the ordered list of (start, end) slot pairs in seconds-since-midnight
  /// for a school day, excluding the lunch window.
  List<({int start, int end})> buildSlots() {
    final slots = <({int start, int end})>[];
    int cursor = dayStartSeconds;
    final slotSecs = lessonDurationMinutes * 60;
    final breakSecs = breakDurationMinutes * 60;
    final lunchEnd = lunchStartSeconds + lunchDurationMinutes * 60;

    while (cursor + slotSecs <= dayEndSeconds) {
      final end = cursor + slotSecs;
      final overlapLunch = cursor < lunchEnd && end > lunchStartSeconds;
      if (!overlapLunch) {
        slots.add((start: cursor, end: end));
      }
      if (end > lunchStartSeconds && cursor < lunchEnd) {
        cursor = lunchEnd;
      } else {
        cursor = end + breakSecs;
      }
    }
    return slots;
  }

  Map<String, dynamic> toJson() => {
    'day_start': dayStartSeconds,
    'day_end': dayEndSeconds,
    'lesson_duration': lessonDurationMinutes,
    'break_duration': breakDurationMinutes,
    'lunch_start': lunchStartSeconds,
    'lunch_duration': lunchDurationMinutes,
    'max_lessons_teacher': maxLessonsPerDayTeacher,
    'max_lessons_class': maxLessonsPerDayClass,
    'allow_doubles': allowDoubles,
    'active_days': activeDays.map((d) => d.index).toList(),
    'teacher_blocks': teacherBlocks.map((b) => b.toJson()).toList(),
    'subject_blocks': subjectBlocks.map((b) => b.toJson()).toList(),
  };

  factory TimetableRules.fromJson(Map<String, dynamic> json) => TimetableRules(
    dayStartSeconds: (json['day_start'] as int?) ?? 8 * 3600,
    dayEndSeconds: (json['day_end'] as int?) ?? 16 * 3600,
    lessonDurationMinutes: (json['lesson_duration'] as int?) ?? 40,
    breakDurationMinutes: (json['break_duration'] as int?) ?? 10,
    lunchStartSeconds: (json['lunch_start'] as int?) ?? (12 * 3600 + 30 * 60),
    lunchDurationMinutes: (json['lunch_duration'] as int?) ?? 60,
    maxLessonsPerDayTeacher: (json['max_lessons_teacher'] as int?) ?? 6,
    maxLessonsPerDayClass: (json['max_lessons_class'] as int?) ?? 8,
    allowDoubles: (json['allow_doubles'] as bool?) ?? false,
    activeDays: ((json['active_days'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5])
        .map((i) => DayOfWeek.values[i])
        .toList(),
    teacherBlocks: ((json['teacher_blocks'] as List?) ?? [])
        .map((e) => TeacherBlockRule.fromJson(e as Map<String, dynamic>))
        .toList(),
    subjectBlocks: ((json['subject_blocks'] as List?) ?? [])
        .map((e) => SubjectBlockRule.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  factory TimetableRules.defaults() => TimetableRules();

  String toJsonString() => jsonEncode(toJson());
  factory TimetableRules.fromJsonString(String s) =>
      TimetableRules.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// A time window on specific days during which a teacher must NOT be scheduled.
class TeacherBlockRule {
  const TeacherBlockRule({
    required this.teacherUserId,
    required this.days,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String teacherUserId;
  final List<DayOfWeek> days;
  final int startSeconds;
  final int endSeconds;

  bool blocks(DayOfWeek day, int slotStart, int slotEnd) {
    if (!days.contains(day)) return false;
    return slotStart < endSeconds && slotEnd > startSeconds;
  }

  Map<String, dynamic> toJson() => {
    'teacher': teacherUserId,
    'days': days.map((d) => d.index).toList(),
    'start': startSeconds,
    'end': endSeconds,
  };

  factory TeacherBlockRule.fromJson(Map<String, dynamic> json) =>
      TeacherBlockRule(
        teacherUserId: json['teacher'] as String,
        days: ((json['days'] as List).cast<int>())
            .map((i) => DayOfWeek.values[i])
            .toList(),
        startSeconds: json['start'] as int,
        endSeconds: json['end'] as int,
      );
}

/// A restriction on when a subject may be scheduled.
class SubjectBlockRule {
  const SubjectBlockRule({
    required this.subjectId,
    this.allowedDays,
    this.blockedAfterSeconds,
    this.blockedBeforeSeconds,
  });

  final int subjectId;
  final List<DayOfWeek>? allowedDays;
  final int? blockedAfterSeconds;
  final int? blockedBeforeSeconds;

  bool blocks(DayOfWeek day, int slotStart, int slotEnd) {
    if (allowedDays != null && !allowedDays!.contains(day)) return true;
    if (blockedAfterSeconds != null && slotStart >= blockedAfterSeconds!)
      return true;
    if (blockedBeforeSeconds != null && slotEnd <= blockedBeforeSeconds!)
      return true;
    return false;
  }

  Map<String, dynamic> toJson() => {
    'subject': subjectId,
    if (allowedDays != null)
      'allowed_days': allowedDays!.map((d) => d.index).toList(),
    if (blockedAfterSeconds != null) 'blocked_after': blockedAfterSeconds,
    if (blockedBeforeSeconds != null) 'blocked_before': blockedBeforeSeconds,
  };

  factory SubjectBlockRule.fromJson(Map<String, dynamic> json) =>
      SubjectBlockRule(
        subjectId: json['subject'] as int,
        allowedDays: (json['allowed_days'] as List?)
            ?.cast<int>()
            .map((i) => DayOfWeek.values[i])
            .toList(),
        blockedAfterSeconds: json['blocked_after'] as int?,
        blockedBeforeSeconds: json['blocked_before'] as int?,
      );
}
