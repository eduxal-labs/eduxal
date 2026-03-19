import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;

// ─────────────────────────────────────────────────────────────────────────────
// Slot model
// ─────────────────────────────────────────────────────────────────────────────

/// Whether a slot in the school-day sequence is a schedulable lesson period
/// or an unschedulable break/transition gap.
enum SlotType { lesson, breakSlot }

/// One slot in the ordered school-day sequence.
///
/// The slot's **start time is derived**, not stored: it is computed from
/// [TimetableRules.dayStartTime] plus the sum of all preceding slot durations.
/// Only [TimetableSlot.type] and [TimetableSlot.durationMinutes] are persisted.
class TimetableSlot {
  const TimetableSlot({required this.type, required this.durationMinutes});

  final SlotType type;

  /// How long this slot lasts, in minutes.
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'duration': durationMinutes,
  };

  factory TimetableSlot.fromJson(Map<String, dynamic> json) => TimetableSlot(
    type: SlotType.values[(json['type'] as int?) ?? 0],
    durationMinutes: (json['duration'] as int?) ?? 40,
  );

  @override
  bool operator ==(Object other) =>
      other is TimetableSlot &&
      type == other.type &&
      durationMinutes == other.durationMinutes;

  @override
  int get hashCode => Object.hash(type, durationMinutes);
}

// ─────────────────────────────────────────────────────────────────────────────
// Constraint entry types
// ─────────────────────────────────────────────────────────────────────────────

/// A constraint restricting a specific teacher's scheduling availability.
///
/// [days] uses weekday indices 1=Mon … 7=Sun.
/// [slotIndices] are 0-based indices into [TimetableRules.slots] (the OVERALL
///   slot list, including breaks — but only lesson-slot indices are effective
///   during generation).
/// When [isBlock] is `true` the teacher is **blocked** from those slots on
/// those days.  When `false` it is a **requirement**: the teacher may ONLY
/// be scheduled in those slots on those days.
class TeacherConstraintEntry {
  const TeacherConstraintEntry({
    required this.teacherId,
    required this.days,
    required this.slotIndices,
    required this.isBlock,
  });

  /// The teacher's user ID (UUID string matching the `users.id` column).
  final String teacherId;

  /// Weekday indices the constraint applies to (1=Mon … 7=Sun).
  final List<int> days;

  /// 0-based indices into [TimetableRules.slots] that this constraint targets.
  final List<int> slotIndices;

  /// `true` = block (forbidden slots); `false` = requirement (only allowed slots).
  final bool isBlock;

  Map<String, dynamic> toJson() => {
    'teacher': teacherId,
    'days': days,
    'slots': slotIndices,
    'is_block': isBlock,
  };

  factory TeacherConstraintEntry.fromJson(Map<String, dynamic> json) =>
      TeacherConstraintEntry(
        teacherId: json['teacher'] as String,
        days: (json['days'] as List<dynamic>).cast<int>(),
        slotIndices: (json['slots'] as List<dynamic>).cast<int>(),
        isBlock: json['is_block'] as bool,
      );
}

/// A constraint restricting when a specific subject may be scheduled.
///
/// Semantics mirror [TeacherConstraintEntry] — same day-index and
/// slot-index conventions, same block / requirement flag.
class SubjectConstraintEntry {
  const SubjectConstraintEntry({
    required this.subjectId,
    required this.days,
    required this.slotIndices,
    required this.isBlock,
  });

  /// The global catalog subject ID (`subjects.id` integer primary key).
  final int subjectId;

  /// Weekday indices the constraint applies to (1=Mon … 7=Sun).
  final List<int> days;

  /// 0-based indices into [TimetableRules.slots] that this constraint targets.
  final List<int> slotIndices;

  /// `true` = block (forbidden); `false` = requirement (only allowed).
  final bool isBlock;

  Map<String, dynamic> toJson() => {
    'subject': subjectId,
    'days': days,
    'slots': slotIndices,
    'is_block': isBlock,
  };

  factory SubjectConstraintEntry.fromJson(Map<String, dynamic> json) =>
      SubjectConstraintEntry(
        subjectId: json['subject'] as int,
        days: (json['days'] as List<dynamic>).cast<int>(),
        slotIndices: (json['slots'] as List<dynamic>).cast<int>(),
        isBlock: json['is_block'] as bool,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Default slot list
// ─────────────────────────────────────────────────────────────────────────────

/// Sensible default school-day slot sequence used when no persisted rules exist.
List<TimetableSlot> _defaultSlots() => const [
  TimetableSlot(type: SlotType.lesson, durationMinutes: 40),
  TimetableSlot(type: SlotType.breakSlot, durationMinutes: 10),
  TimetableSlot(type: SlotType.lesson, durationMinutes: 40),
  TimetableSlot(type: SlotType.lesson, durationMinutes: 40),
  TimetableSlot(type: SlotType.breakSlot, durationMinutes: 60), // lunch
  TimetableSlot(type: SlotType.lesson, durationMinutes: 40),
  TimetableSlot(type: SlotType.lesson, durationMinutes: 40),
  TimetableSlot(type: SlotType.lesson, durationMinutes: 40),
];

// ─────────────────────────────────────────────────────────────────────────────
// TimetableRules
// ─────────────────────────────────────────────────────────────────────────────

/// School-day configuration and generation constraint rules for one timetable
/// run.
///
/// Persisted as JSON at:
///   `{appDir}/schools/{schoolId}/timetable_rules_{year}_{term}.json`
///
/// **Slot-based model (v2):**
/// Instead of specifying a single fixed lesson duration and break duration,
/// the user builds an explicit ordered [slots] list of [TimetableSlot]s.
/// Each slot is either a lesson period or a break.  Start times for all slots
/// are computed from [dayStartTime] + the cumulative sum of preceding slot
/// durations.  Break slots are never placed into the solver's domain — only
/// [SlotType.lesson] slots are schedulable.
///
/// **Constraint model:**
/// Teacher and subject constraints reference slots by their **0-based index
/// in the overall [slots] list** (including breaks).  This makes the wizard
/// UI unambiguous — the user sees "Slot 3 (09:30–10:10)" rather than a
/// lesson-only re-numbered list.  The generator filters for lesson-only slots
/// and checks whether their overall slot index satisfies the constraints.
class TimetableRules {
  TimetableRules({
    TimeOfDay? dayStartTime,
    List<TimetableSlot>? slots,
    List<int>? activeDays,
    this.maxLessonsPerDayTeacher = 6,
    this.maxLessonsPerDayClass = 8,
    this.allowDoubles = false,
    this.defaultLessonsPerWeek = 4,
    Map<int, int>? lessonsPerWeekBySubject,
    List<TeacherConstraintEntry>? teacherConstraints,
    List<SubjectConstraintEntry>? subjectConstraints,
  }) : dayStartTime = dayStartTime ?? const TimeOfDay(hour: 8, minute: 0),
       slots = slots ?? _defaultSlots(),
       activeDays = activeDays ?? [1, 2, 3, 4, 5], // Mon–Fri
       lessonsPerWeekBySubject = lessonsPerWeekBySubject ?? {},
       teacherConstraints = teacherConstraints ?? [],
       subjectConstraints = subjectConstraints ?? [];

  // ── Day configuration ────────────────────────────────────────────────────

  /// The time the school day begins.  All slot start times are derived from
  /// this anchor plus cumulative preceding-slot durations.
  final TimeOfDay dayStartTime;

  /// Ordered sequence of lesson and break slots that make up one school day.
  final List<TimetableSlot> slots;

  /// Days of the week that are scheduled.  Stored as weekday indices
  /// (1 = Monday … 7 = Sunday).
  final List<int> activeDays;

  // ── Load constraints ─────────────────────────────────────────────────────

  /// Maximum number of lesson slots a teacher may be assigned on any one day.
  final int maxLessonsPerDayTeacher;

  /// Maximum number of lesson slots a class may receive on any one day.
  final int maxLessonsPerDayClass;

  /// When `false`, the same subject is spread across different days for a
  /// class — no two instances of the same subject on the same day.
  final bool allowDoubles;

  /// How many times per week each subject is scheduled by default.
  /// Applies to every subject unless overridden in [lessonsPerWeekBySubject].
  final int defaultLessonsPerWeek;

  /// Per-subject overrides: `subject ID → lessons per week`.
  /// Subjects absent from this map fall back to [defaultLessonsPerWeek].
  final Map<int, int> lessonsPerWeekBySubject;

  // ── Constraints ──────────────────────────────────────────────────────────

  /// Per-teacher scheduling constraints.
  final List<TeacherConstraintEntry> teacherConstraints;

  /// Per-subject scheduling constraints.
  final List<SubjectConstraintEntry> subjectConstraints;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns how many times per week [subjectId] should be scheduled,
  /// honouring any per-subject override before falling back to [defaultLessonsPerWeek].
  int lessonsPerWeekForSubject(int subjectId) =>
      lessonsPerWeekBySubject[subjectId] ?? defaultLessonsPerWeek;

  /// Produces the ordered list of **lesson-only** slots with their computed
  /// start and end times (in seconds since midnight) and their 0-based index
  /// position in the overall [slots] list.
  ///
  /// Break slots are excluded from the returned list but their durations still
  /// advance the running time cursor.
  ///
  /// Use this list to build the solver's slot domain and for display labels
  /// in the wizard UI.
  List<({int index, int start, int end})> buildLessonSlots() {
    final result = <({int index, int start, int end})>[];
    int cursor = dayStartTime.hour * 3600 + dayStartTime.minute * 60;
    for (int i = 0; i < slots.length; i++) {
      final s = slots[i];
      final end = cursor + s.durationMinutes * 60;
      if (s.type == SlotType.lesson) {
        result.add((index: i, start: cursor, end: end));
      }
      cursor = end;
    }
    return result;
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  TimetableRules copyWith({
    TimeOfDay? dayStartTime,
    List<TimetableSlot>? slots,
    List<int>? activeDays,
    int? maxLessonsPerDayTeacher,
    int? maxLessonsPerDayClass,
    bool? allowDoubles,
    int? defaultLessonsPerWeek,
    Map<int, int>? lessonsPerWeekBySubject,
    List<TeacherConstraintEntry>? teacherConstraints,
    List<SubjectConstraintEntry>? subjectConstraints,
  }) => TimetableRules(
    dayStartTime: dayStartTime ?? this.dayStartTime,
    slots: slots ?? this.slots,
    activeDays: activeDays ?? this.activeDays,
    maxLessonsPerDayTeacher:
        maxLessonsPerDayTeacher ?? this.maxLessonsPerDayTeacher,
    maxLessonsPerDayClass: maxLessonsPerDayClass ?? this.maxLessonsPerDayClass,
    allowDoubles: allowDoubles ?? this.allowDoubles,
    defaultLessonsPerWeek: defaultLessonsPerWeek ?? this.defaultLessonsPerWeek,
    lessonsPerWeekBySubject:
        lessonsPerWeekBySubject ?? this.lessonsPerWeekBySubject,
    teacherConstraints: teacherConstraints ?? this.teacherConstraints,
    subjectConstraints: subjectConstraints ?? this.subjectConstraints,
  );

  // ── JSON serialisation ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'version': 2, // v2 = slot-based model; v1 = legacy time-range model
    'day_start_hour': dayStartTime.hour,
    'day_start_minute': dayStartTime.minute,
    'slots': slots.map((s) => s.toJson()).toList(),
    'active_days': activeDays,
    'max_lessons_teacher': maxLessonsPerDayTeacher,
    'max_lessons_class': maxLessonsPerDayClass,
    'allow_doubles': allowDoubles,
    'default_lessons_per_week': defaultLessonsPerWeek,
    'lessons_per_week_by_subject': lessonsPerWeekBySubject.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
    'teacher_constraints': teacherConstraints.map((e) => e.toJson()).toList(),
    'subject_constraints': subjectConstraints.map((e) => e.toJson()).toList(),
  };

  /// Deserialise from a JSON map.
  ///
  /// If the stored data uses the v1 (legacy time-range) format, or if any
  /// parse error occurs, [TimetableRules.defaults()] is returned so the app
  /// never crashes on malformed or outdated saved rules.
  factory TimetableRules.fromJson(Map<String, dynamic> json) {
    try {
      final version = (json['version'] as int?) ?? 1;
      if (version < 2) {
        // Legacy v1 format used entirely different keys (day_start, day_end,
        // lesson_duration, etc.).  It cannot be migrated losslessly, so we
        // discard it and open the wizard with defaults.
        return TimetableRules.defaults();
      }

      return TimetableRules(
        dayStartTime: TimeOfDay(
          hour: (json['day_start_hour'] as int?) ?? 8,
          minute: (json['day_start_minute'] as int?) ?? 0,
        ),
        slots: ((json['slots'] as List<dynamic>?) ?? [])
            .map((e) => TimetableSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeDays: ((json['active_days'] as List<dynamic>?) ?? [1, 2, 3, 4, 5])
            .cast<int>(),
        maxLessonsPerDayTeacher: (json['max_lessons_teacher'] as int?) ?? 6,
        maxLessonsPerDayClass: (json['max_lessons_class'] as int?) ?? 8,
        allowDoubles: (json['allow_doubles'] as bool?) ?? false,
        defaultLessonsPerWeek: (json['default_lessons_per_week'] as int?) ?? 4,
        lessonsPerWeekBySubject: () {
          final raw =
              json['lessons_per_week_by_subject'] as Map<String, dynamic>?;
          if (raw == null) return <int, int>{};
          return raw.map((k, v) => MapEntry(int.parse(k), v as int));
        }(),
        teacherConstraints:
            ((json['teacher_constraints'] as List<dynamic>?) ?? [])
                .map(
                  (e) => TeacherConstraintEntry.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
        subjectConstraints:
            ((json['subject_constraints'] as List<dynamic>?) ?? [])
                .map(
                  (e) => SubjectConstraintEntry.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
      );
    } catch (_) {
      // Any unexpected format → safe fallback.
      return TimetableRules.defaults();
    }
  }

  factory TimetableRules.defaults() => TimetableRules();

  String toJsonString() => jsonEncode(toJson());

  factory TimetableRules.fromJsonString(String s) {
    try {
      return TimetableRules.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return TimetableRules.defaults();
    }
  }
}
