import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import '../database/tables/enums.dart';

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
    Map<int, TimeOfDay>? dayStartTimes,
    Map<int, List<TimetableSlot>>? daySlots,
    List<int>? activeDays,
    this.maxLessonsPerDayTeacher = 6,
    this.maxLessonsPerDayClass = 8,
    this.allowDoubles = false,
    Map<String, Map<int, int>>? remainderAllocation,
    List<TeacherConstraintEntry>? teacherConstraints,
    List<SubjectConstraintEntry>? subjectConstraints,
  }) : dayStartTimes = dayStartTimes ?? {},
       daySlots = daySlots ?? {},
       activeDays = activeDays ?? [1, 2, 3, 4, 5],
       remainderAllocation = remainderAllocation ?? {},
       teacherConstraints = teacherConstraints ?? [],
       subjectConstraints = subjectConstraints ?? [] {
    // Ensure all active days have at least a default start time and empty slot list
    // if not provided.
    for (final day in this.activeDays) {
      this.dayStartTimes.putIfAbsent(day, () => const TimeOfDay(hour: 8, minute: 0));
      this.daySlots.putIfAbsent(day, () => []);
    }
  }

  // ── Day configuration ────────────────────────────────────────────────────

  /// The time the school day begins for each day.
  final Map<int, TimeOfDay> dayStartTimes;

  /// Ordered sequence of lesson and break slots for each day.
  final Map<int, List<TimetableSlot>> daySlots;

  /// Days of the week that are scheduled.  Stored as weekday indices
  /// (1 = Monday … 7 = Sunday).
  final List<int> activeDays;

  /// Returns the 0-based index of a [day] within the [activeDays] list.
  int weekdayToIndex(DayOfWeek day) {
    final int val = (day == DayOfWeek.sunday) ? 7 : day.index;
    return activeDays.indexOf(val);
  }

  // ── Load constraints ─────────────────────────────────────────────────────

  /// Maximum number of lesson slots a teacher may be assigned on any one day.
  final int maxLessonsPerDayTeacher;

  /// Maximum number of lesson slots a class may receive on any one day.
  final int maxLessonsPerDayClass;

  /// When `false`, the same subject is spread across different days for a
  /// class — no two instances of the same subject on the same day.
  final bool allowDoubles;

  /// Per-stream remainder subject allocation.
  ///
  /// Key format: "{grade}_{stream}" (e.g. "44_1") or "{grade}_null" for
  /// grades with a single un-streamed class.
  ///
  /// Value: Map of subject IDs to the number of EXTRA lessons per week
  /// (beyond the base allocation). The sum of these values should equal
  /// (totalWeeklySlots % numSubjects).
  final Map<String, Map<int, int>> remainderAllocation;

  // ── Constraints ──────────────────────────────────────────────────────────

  /// Per-teacher scheduling constraints.
  final List<TeacherConstraintEntry> teacherConstraints;

  /// Per-subject scheduling constraints.
  final List<SubjectConstraintEntry> subjectConstraints;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Produces the ordered list of **lesson-only** slots for a specific day
  /// with their computed start and end times (in seconds since midnight)
  /// and their 0-based index position in that day's slot list.
  List<({int index, int start, int end})> buildLessonSlotsForDay(int day) {
    final result = <({int index, int start, int end})>[];
    final startTime = dayStartTimes[day] ?? const TimeOfDay(hour: 8, minute: 0);
    final slots = daySlots[day] ?? [];
    
    int cursor = startTime.hour * 3600 + startTime.minute * 60;
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
    Map<int, TimeOfDay>? dayStartTimes,
    Map<int, List<TimetableSlot>>? daySlots,
    List<int>? activeDays,
    int? maxLessonsPerDayTeacher,
    int? maxLessonsPerDayClass,
    bool? allowDoubles,
    Map<String, Map<int, int>>? remainderAllocation,
    List<TeacherConstraintEntry>? teacherConstraints,
    List<SubjectConstraintEntry>? subjectConstraints,
  }) => TimetableRules(
    dayStartTimes: dayStartTimes ?? Map.from(this.dayStartTimes),
    daySlots: daySlots ?? Map.from(this.daySlots),
    activeDays: activeDays ?? this.activeDays,
    maxLessonsPerDayTeacher:
        maxLessonsPerDayTeacher ?? this.maxLessonsPerDayTeacher,
    maxLessonsPerDayClass: maxLessonsPerDayClass ?? this.maxLessonsPerDayClass,
    allowDoubles: allowDoubles ?? this.allowDoubles,
    remainderAllocation: remainderAllocation ?? this.remainderAllocation,
    teacherConstraints: teacherConstraints ?? this.teacherConstraints,
    subjectConstraints: subjectConstraints ?? this.subjectConstraints,
  );

  // ── JSON serialisation ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'version': 3,
    'day_start_times': dayStartTimes.map((k, v) => MapEntry(k.toString(), {
      'hour': v.hour,
      'minute': v.minute,
    })),
    'day_slots': daySlots.map((k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList())),
    'active_days': activeDays,
    'max_lessons_teacher': maxLessonsPerDayTeacher,
    'max_lessons_class': maxLessonsPerDayClass,
    'allow_doubles': allowDoubles,
    'remainder_allocation': remainderAllocation.map(
      (k, v) => MapEntry(k, v.map((sk, sv) => MapEntry(sk.toString(), sv))),
    ),
    'teacher_constraints': teacherConstraints.map((e) => e.toJson()).toList(),
    'subject_constraints': subjectConstraints.map((e) => e.toJson()).toList(),
  };

  /// Deserialise from a JSON map.
  factory TimetableRules.fromJson(Map<String, dynamic> json) {
    try {
      final version = (json['version'] as int?) ?? 1;
      if (version < 2) {
        return TimetableRules.defaults();
      }

      final activeDays = ((json['active_days'] as List<dynamic>?) ?? [1, 2, 3, 4, 5])
            .cast<int>();

      if (version == 2) {
        // Migrate v2 (global slots) to v3 (per-day slots)
        final globalStart = TimeOfDay(
          hour: (json['day_start_hour'] as int?) ?? 8,
          minute: (json['day_start_minute'] as int?) ?? 0,
        );
        final globalSlots = ((json['slots'] as List<dynamic>?) ?? [])
            .map((e) => TimetableSlot.fromJson(e as Map<String, dynamic>))
            .toList();

        final dayStartTimes = <int, TimeOfDay>{};
        final daySlots = <int, List<TimetableSlot>>{};
        for (final day in activeDays) {
          dayStartTimes[day] = globalStart;
          daySlots[day] = List.from(globalSlots);
        }

        return TimetableRules(
          dayStartTimes: dayStartTimes,
          daySlots: daySlots,
          activeDays: activeDays,
          maxLessonsPerDayTeacher: (json['max_lessons_teacher'] as int?) ?? 6,
          maxLessonsPerDayClass: (json['max_lessons_class'] as int?) ?? 8,
          allowDoubles: (json['allow_doubles'] as bool?) ?? false,
          remainderAllocation: () {
            // Priority list is no longer supported in v3, but we can't easily
            // migrate without subject counts. Solver will use defaults or
            // new allocation map.
            return <String, Map<int, int>>{};
          }(),
          teacherConstraints:
              ((json['teacher_constraints'] as List<dynamic>?) ?? [])
                  .map((e) => TeacherConstraintEntry.fromJson(e as Map<String, dynamic>))
                  .toList(),
          subjectConstraints:
              ((json['subject_constraints'] as List<dynamic>?) ?? [])
                  .map((e) => SubjectConstraintEntry.fromJson(e as Map<String, dynamic>))
                  .toList(),
        );
      }

      // Version 3+
      return TimetableRules(
        dayStartTimes: () {
          final raw = json['day_start_times'] as Map<String, dynamic>?;
          if (raw == null) return <int, TimeOfDay>{};
          return raw.map((k, v) {
            final m = v as Map<String, dynamic>;
            return MapEntry(int.parse(k), TimeOfDay(hour: m['hour'] as int, minute: m['minute'] as int));
          });
        }(),
        daySlots: () {
          final raw = json['day_slots'] as Map<String, dynamic>?;
          if (raw == null) return <int, List<TimetableSlot>>{};
          return raw.map((k, v) {
            return MapEntry(
              int.parse(k),
              (v as List<dynamic>).map((e) => TimetableSlot.fromJson(e as Map<String, dynamic>)).toList(),
            );
          });
        }(),
        activeDays: activeDays,
        maxLessonsPerDayTeacher: (json['max_lessons_teacher'] as int?) ?? 6,
        maxLessonsPerDayClass: (json['max_lessons_class'] as int?) ?? 8,
        allowDoubles: (json['allow_doubles'] as bool?) ?? false,
        remainderAllocation: () {
          final raw = json['remainder_allocation'] as Map<String, dynamic>?;
          if (raw == null) {
            // Check for legacy remainder_priority (migration)
            final legacy = json['remainder_priority'] as Map<String, dynamic>?;
            if (legacy != null) {
              // We can't fully migrate here because we don't know the remainder
              // count without the subjects list. The generator will handle
              // the default allocation if this map is empty.
              return <String, Map<int, int>>{};
            }
            return <String, Map<int, int>>{};
          }
          return raw.map((k, v) {
            final m = v as Map<String, dynamic>;
            return MapEntry(
              k,
              m.map((sk, sv) => MapEntry(int.parse(sk), sv as int)),
            );
          });
        }(),
        teacherConstraints:
            ((json['teacher_constraints'] as List<dynamic>?) ?? [])
                .map((e) => TeacherConstraintEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
        subjectConstraints:
            ((json['subject_constraints'] as List<dynamic>?) ?? [])
                .map((e) => SubjectConstraintEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
      );
    } catch (_) {
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
