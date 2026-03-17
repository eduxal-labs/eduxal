import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';

import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_tab_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exam Creation Page — full-screen multi-grade exam form
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page form for creating exams across multiple grades and streams,
/// with a timetable-style paper scheduler. Users can dynamically add
/// papers to any day within the exam range, set custom start/end times,
/// assign subjects, and pick invigilators.
class ExamCreationPage extends StatefulWidget {
  const ExamCreationPage({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.entry,
    this.preselectedGrade,
    this.preselectedStream,
  });

  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final MembershipEntry entry;

  /// When pushed from a grade detail page, pre-select this grade in the
  /// grade selector so the user doesn't have to find it manually.
  final int? preselectedGrade;

  /// When pushed from a specific stream tab, pre-select this stream code
  /// within the pre-selected grade. Ignored if [preselectedGrade] is null.
  final int? preselectedStream;

  @override
  State<ExamCreationPage> createState() => _ExamCreationPageState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting types
// ─────────────────────────────────────────────────────────────────────────────

class _GradeTabEntry {
  const _GradeTabEntry({
    required this.label,
    required this.grade,
    required this.curriculum,
  });
  final String label;
  final int? grade; // null = "All"
  final CurriculumType? curriculum;
}

/// One grade+stream combination's loaded subject list (for papers section).
class _ClassSubjects {
  final int grade;
  final int? stream; // null = all-streams union
  final List<({SubjectTeacher subject, UsersData teacher, String subjectName})>
  subjects;

  _ClassSubjects({
    required this.grade,
    required this.stream,
    required this.subjects,
  });

  /// Returns the display name for a subject ID, falling back to 'Subject $id'.
  String nameFor(int subjectId) {
    final match = subjects
        .where((s) => s.subject.subject == subjectId)
        .firstOrNull;
    return match?.subjectName ?? 'Subject $subjectId';
  }
}

/// A single paper slot on the timetable — one row in the schedule.
class _PaperSlot {
  String id;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  int? subjectCode; // curriculum subject index
  String? invigilatorId; // teacher user id

  _PaperSlot({
    required this.id,
    required this.date,
    this.startTime = const TimeOfDay(hour: 8, minute: 0),
    this.endTime = const TimeOfDay(hour: 10, minute: 0),
    this.subjectCode,
    this.invigilatorId,
  });

  Duration get duration {
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    return Duration(minutes: endMin - startMin);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _ExamCreationPageState extends State<ExamCreationPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final ExamsGradesDao _examsDao;
  late final SubjectsDao _subjectsDao;
  late final MembersDao _membersDao;

  bool _saving = false;

  // Section 1 — Exam details
  final _nameCtrl = TextEditingController();
  ExamType _type = ExamType.exam;
  bool _personalized = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _calendarOpen = false;

  bool get _isTeacherEntry => widget.entry is TeacherEntry;

  // Section 2 — Grade tabs
  late TabController _gradeTabController;
  int _activeGradeTabIndex = 0;
  late List<_GradeTabEntry> _gradeTabs;

  // Section 3 — Stream sub-tabs (per-grade TabControllers)
  final Map<int, TabController> _streamTabControllers = {};
  final Map<int, int> _activeStreamTabIndex = {};

  // Section 4 — Paper timetable
  final Map<String, _ClassSubjects> _classSubjects = {};
  final Map<String, bool> _loadingSubjects = {};
  // Tracks in-progress subject loading futures so _ensureAllStreamsCovered
  // and _autoPopulateSlots can await them instead of silently skipping.
  final Map<String, Future<void>> _loadingFutures = {};
  // Key = "$grade:$stream", value = list of paper slots
  final Map<String, List<_PaperSlot>> _paperSlots = {};

  // Teachers list for invigilator picker
  List<({TeachersData teacher, UsersData user})> _teachers = [];
  bool _teachersLoaded = false;

  // Invigilator time-slot conflict tracking (slot ID → error message)
  Map<String, String> _slotConflicts = {};

  // Duplicate subject conflict tracking (slot ID → error message)
  Map<String, String> _duplicateSubjectConflicts = {};

  @override
  void initState() {
    super.initState();
    _examsDao = ExamsGradesDao(db);
    _subjectsDao = SubjectsDao(db);
    _membersDao = MembersDao(db);

    // Build grade tabs: one tab per configured grade (no synthetic "All" tab).
    _gradeTabs = [
      for (final curriculum in widget.config.curricula)
        for (final gc in curriculum.grades)
          _GradeTabEntry(
            label:
                gradeLabelsFor(curriculum.type)[gc.grade] ??
                'Grade ${gc.grade}',
            grade: gc.grade,
            curriculum: curriculum.type,
          ),
    ];

    // Determine initial tab index from preselectedGrade.
    int initialIndex = 0;
    final preGrade = widget.preselectedGrade;
    if (preGrade != null) {
      final idx = _gradeTabs.indexWhere((t) => t.grade == preGrade);
      if (idx >= 0) {
        initialIndex = idx;
        _activeGradeTabIndex = idx;
      }
    }

    _gradeTabController = TabController(
      length: _gradeTabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _gradeTabController.addListener(() {
      if (!_gradeTabController.indexIsChanging) {
        setState(() {
          _activeGradeTabIndex = _gradeTabController.index;
          _onGradeTabChanged();
        });
      }
    });

    // Build per-grade stream tab controllers
    for (final tab in _gradeTabs) {
      if (tab.grade == null) continue;
      final gc = _gradeConfigFor(tab.grade!);
      if (gc != null && gc.streams.isNotEmpty) {
        // Determine initial stream index from preselection (if any).
        int initialStreamIdx = 0;
        if (tab.grade == widget.preselectedGrade &&
            widget.preselectedStream != null) {
          final idx = gc.streams.indexWhere(
            (s) => s.code == widget.preselectedStream,
          );
          if (idx >= 0) initialStreamIdx = idx;
        }

        final ctrl = TabController(
          length: gc.streams.length,
          vsync: this,
          initialIndex: initialStreamIdx,
        );
        ctrl.addListener(() {
          if (!ctrl.indexIsChanging) {
            setState(() {
              _activeStreamTabIndex[tab.grade!] = ctrl.index;
              _onStreamTabChanged(tab.grade!);
            });
          }
        });
        _streamTabControllers[tab.grade!] = ctrl;
        _activeStreamTabIndex[tab.grade!] = initialStreamIdx;
      }
    }

    _onGradeTabChanged();
    _loadTeachers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gradeTabController.dispose();
    for (final ctrl in _streamTabControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _classKey(int grade, int? stream) => '$grade:$stream';

  bool get _hasSelection => _gradeTabs.isNotEmpty;

  /// Derive the exam-level teacher from the entry (if teacher) or from the
  /// first paper slot that has an invigilator assigned across ALL configured
  /// classes. Returns empty string if none found — the save method validates.
  String get _teacherId {
    final entry = widget.entry;
    if (entry is TeacherEntry) return entry.teacher.user;
    // For non-teacher entries, search ALL paper slots for the first invigilator
    for (final slots in _paperSlots.values) {
      for (final slot in slots) {
        if (slot.invigilatorId != null && slot.invigilatorId!.isNotEmpty) {
          return slot.invigilatorId!;
        }
      }
    }
    return '';
  }

  GradeConfig? _gradeConfigFor(int grade) {
    for (final c in widget.config.curricula) {
      for (final g in c.grades) {
        if (g.grade == grade) return g;
      }
    }
    return null;
  }

  CurriculumType? _curriculumForGrade(int grade) {
    for (final c in widget.config.curricula) {
      for (final g in c.grades) {
        if (g.grade == grade) return c.type;
      }
    }
    return null;
  }

  bool _isSpecificStreamActive(int grade) {
    final gc = _gradeConfigFor(grade);
    if (gc == null || gc.streams.length <= 1) return false;
    return true;
  }

  /// Ensures every stream in every grade has paper slots before saving.
  ///
  /// For each grade that has multiple streams, finds the first stream that
  /// has paper slots configured (the "source") and copies them to every other
  /// stream that is empty. Subjects for unvisited streams are loaded on-the-fly.
  Future<void> _ensureAllStreamsCovered() async {
    for (final tab in _gradeTabs) {
      if (tab.grade == null) continue;
      final gc = _gradeConfigFor(tab.grade!);
      if (gc == null || gc.streams.length <= 1) continue;

      // Find the first stream that has paper slots — that's our source.
      int? sourceStreamCode;
      for (final stream in gc.streams) {
        final key = _classKey(tab.grade!, stream.code);
        final slots = _paperSlots[key];
        if (slots != null && slots.any((s) => s.subjectCode != null)) {
          sourceStreamCode = stream.code;
          break;
        }
      }
      if (sourceStreamCode == null) continue; // no papers for this grade at all

      // Ensure subjects are FULLY loaded for every stream in this grade.
      // Uses _loadOrWaitSubjects which also awaits in-progress loads
      // (fixes race condition where tab switch triggered a load that
      // hasn't completed yet).
      final waitFutures = <Future<void>>[];
      for (final stream in gc.streams) {
        waitFutures.add(_loadOrWaitSubjects(tab.grade!, stream.code));
      }
      await Future.wait(waitFutures);

      // Now copy papers from source to any stream that is still empty.
      final sourceKey = _classKey(tab.grade!, sourceStreamCode);
      final sourceSlots = _paperSlots[sourceKey];
      if (sourceSlots == null || sourceSlots.isEmpty) continue;

      for (final stream in gc.streams) {
        if (stream.code == sourceStreamCode) continue;
        final targetKey = _classKey(tab.grade!, stream.code);
        final existing = _paperSlots[targetKey];
        if (existing != null && existing.any((s) => s.subjectCode != null)) {
          continue; // already has papers — don't overwrite
        }

        final targetSubjects = _classSubjects[targetKey];
        final copiedSlots = <_PaperSlot>[];
        for (final slot in sourceSlots) {
          if (slot.subjectCode == null) {
            copiedSlots.add(
              _PaperSlot(
                id: _generateId(),
                date: slot.date,
                startTime: slot.startTime,
                endTime: slot.endTime,
              ),
            );
            continue;
          }

          // Try to match a subject-teacher assignment in the target stream.
          // If none exists (target stream has no subject_teachers rows), fall
          // back to using the source subject code directly — subject IDs are
          // global and valid across all streams.
          final targetMatch = targetSubjects?.subjects
              .where((s) => s.subject.subject == slot.subjectCode)
              .firstOrNull;

          final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
          final endMin = slot.endTime.hour * 60 + slot.endTime.minute;

          // Use target stream's assigned teacher if available,
          // otherwise fall back to source slot's invigilator.
          String? invigilatorId =
              targetMatch?.subject.teacher ?? slot.invigilatorId;
          if (invigilatorId != null &&
              _isInvigilatorBusy(
                invigilatorId,
                slot.date,
                startMin,
                endMin,
                targetKey,
              )) {
            invigilatorId = _findAvailableTeacher(
              slot.date,
              startMin,
              endMin,
              targetKey,
            );
          }

          copiedSlots.add(
            _PaperSlot(
              id: _generateId(),
              date: slot.date,
              startTime: slot.startTime,
              endTime: slot.endTime,
              subjectCode: slot.subjectCode,
              invigilatorId: invigilatorId,
            ),
          );
        }
        _paperSlots[targetKey] = copiedSlots;
      }
    }

    // Refresh conflict maps after propagation.
    _recomputeConflicts();
  }

  Future<void> _copyPapersToAllStreams(int grade, int sourceStreamCode) async {
    final gc = _gradeConfigFor(grade);
    if (gc == null) return;
    final sourceKey = _classKey(grade, sourceStreamCode);
    final sourceSlots = _paperSlots[sourceKey];
    if (sourceSlots == null || sourceSlots.isEmpty) return;

    // Ensure subjects are loaded for ALL target streams before copying.
    // Without this, unvisited stream tabs would have null subjects and
    // produce empty paper lists.
    final waitFutures = <Future<void>>[];
    for (final stream in gc.streams) {
      if (stream.code == sourceStreamCode) continue;
      waitFutures.add(_loadOrWaitSubjects(grade, stream.code));
    }
    if (waitFutures.isNotEmpty) {
      await Future.wait(waitFutures);
    }

    if (!mounted) return;

    setState(() {
      for (final stream in gc.streams) {
        if (stream.code == sourceStreamCode) continue;
        final targetKey = _classKey(grade, stream.code);
        final targetSubjects = _classSubjects[targetKey];

        final copiedSlots = <_PaperSlot>[];
        for (final slot in sourceSlots) {
          if (slot.subjectCode == null) {
            // Copy slot without subject
            copiedSlots.add(
              _PaperSlot(
                id: _generateId(),
                date: slot.date,
                startTime: slot.startTime,
                endTime: slot.endTime,
              ),
            );
            continue;
          }

          // Try to match a subject-teacher assignment in the target stream.
          // If none exists (target stream has no subject_teachers rows), fall
          // back to using the source subject code directly — subject IDs are
          // global and valid across all streams.
          final targetMatch = targetSubjects?.subjects
              .where((s) => s.subject.subject == slot.subjectCode)
              .firstOrNull;

          final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
          final endMin = slot.endTime.hour * 60 + slot.endTime.minute;

          // Use target stream's assigned teacher if available,
          // otherwise fall back to source slot's invigilator.
          String? invigilatorId =
              targetMatch?.subject.teacher ?? slot.invigilatorId;
          if (invigilatorId != null &&
              _isInvigilatorBusy(
                invigilatorId,
                slot.date,
                startMin,
                endMin,
                targetKey,
              )) {
            invigilatorId = _findAvailableTeacher(
              slot.date,
              startMin,
              endMin,
              targetKey,
            );
          }

          copiedSlots.add(
            _PaperSlot(
              id: _generateId(),
              date: slot.date,
              startTime: slot.startTime,
              endTime: slot.endTime,
              subjectCode: slot.subjectCode,
              invigilatorId: invigilatorId,
            ),
          );
        }
        _paperSlots[targetKey] = copiedSlots;
      }
      _recomputeConflicts();
    });
  }

  /// Returns all exam dates in order.
  List<DateTime> get _examDays {
    if (_startDate == null || _endDate == null) return [];
    final days = <DateTime>[];
    var d = _startDate!;
    while (!d.isAfter(_endDate!)) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Teachers loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadTeachers() async {
    try {
      final teachersList = await _membersDao
          .watchTeachers(widget.schoolId)
          .first;
      if (!mounted) return;
      final results = <({TeachersData teacher, UsersData user})>[];
      for (final t in teachersList) {
        final user = await _membersDao.findUserById(t.user);
        if (!mounted) return;
        if (user != null) {
          results.add((teacher: t, user: user));
        }
      }
      if (mounted) {
        setState(() {
          _teachers = results
            ..sort((a, b) => a.user.name.compareTo(b.user.name));
          _teachersLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teachersLoaded = true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Grade tab & stream chip logic
  // ─────────────────────────────────────────────────────────────────────────

  void _onGradeTabChanged() {
    if (_gradeTabs.isEmpty) return;
    final tab = _gradeTabs[_activeGradeTabIndex];
    if (tab.grade != null) {
      _onStreamTabChanged(tab.grade!);
    }
  }

  void _onStreamTabChanged(int grade) {
    final gc = _gradeConfigFor(grade);
    if (gc == null) return;
    if (gc.streams.isEmpty) {
      // Grade without streams — load with null stream
      final key = _classKey(grade, null);
      if (!_classSubjects.containsKey(key) && _loadingSubjects[key] != true) {
        _loadSubjectsForClass(grade, null);
      }
    } else {
      final streamIdx = _activeStreamTabIndex[grade] ?? 0;
      final stream = gc.streams[streamIdx];
      final key = _classKey(grade, stream.code);
      if (!_classSubjects.containsKey(key) && _loadingSubjects[key] != true) {
        _loadSubjectsForClass(grade, stream.code);
      }
    }
  }

  Future<void> _loadSubjectsForClass(int grade, int? stream) async {
    final key = _classKey(grade, stream);
    if (_classSubjects.containsKey(key) || _loadingSubjects[key] == true) {
      return;
    }

    setState(() => _loadingSubjects[key] = true);

    final future = _doLoadSubjects(key, grade, stream);
    _loadingFutures[key] = future;
    await future;
  }

  Future<void> _doLoadSubjects(String key, int grade, int? stream) async {
    try {
      // Subjects are always loaded per individual stream. For grades without
      // streams, `stream` is null and the DAO handles that case.
      final subjects = stream != null
          ? await _subjectsDao.getSubjectsForClass(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: grade,
              stream: stream,
            )
          : <
              ({SubjectTeacher subject, UsersData teacher, String subjectName})
            >[];

      if (!mounted) return;
      setState(() {
        _classSubjects[key] = _ClassSubjects(
          grade: grade,
          stream: stream,
          subjects: subjects,
        );
        _loadingSubjects[key] = false;
      });
    } catch (e) {
      debugPrint('[ExamCreation] Failed to load subjects for key=$key: $e');
      if (mounted) {
        setState(() => _loadingSubjects[key] = false);
      }
    } finally {
      _loadingFutures.remove(key);
    }
  }

  /// Ensures subjects for [grade]/[stream] are fully loaded.
  /// If already loaded, returns immediately. If a load is in progress,
  /// waits for it to complete. Otherwise, starts a new load and waits.
  Future<void> _loadOrWaitSubjects(int grade, int? stream) async {
    final key = _classKey(grade, stream);
    // Already loaded — nothing to do.
    if (_classSubjects.containsKey(key)) return;
    // A load is in progress — wait for it.
    final existing = _loadingFutures[key];
    if (existing != null) {
      await existing;
      return;
    }
    // Not loaded and not loading — start a fresh load.
    await _loadSubjectsForClass(grade, stream);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Paper slot management
  // ─────────────────────────────────────────────────────────────────────────

  List<_PaperSlot> _slotsFor(String classKey) {
    return _paperSlots.putIfAbsent(classKey, () => []);
  }

  void _addPaperSlot(String classKey, DateTime date, int grade) {
    final slots = _slotsFor(classKey);
    // Find the last slot on the same day to chain the start time
    final sameDay = slots.where((s) => _sameDay(s.date, date));
    TimeOfDay startTime;
    if (sameDay.isNotEmpty) {
      final last = sameDay.reduce(
        (a, b) =>
            (a.endTime.hour * 60 + a.endTime.minute) >=
                (b.endTime.hour * 60 + b.endTime.minute)
            ? a
            : b,
      );
      startTime = last.endTime;
    } else {
      startTime = const TimeOfDay(hour: 8, minute: 0);
    }

    final endMinutes = startTime.hour * 60 + startTime.minute + 120;
    final endTime = TimeOfDay(
      hour: (endMinutes ~/ 60).clamp(0, 23),
      minute: endMinutes % 60,
    );

    // Auto-assign the first unassigned subject
    final cs = _classSubjects[classKey];
    int? autoSubject;
    String? autoInvigilator;
    if (cs != null) {
      final usedSubjects = slots.map((s) => s.subjectCode).toSet();
      for (final s in cs.subjects) {
        if (!usedSubjects.contains(s.subject.subject)) {
          autoSubject = s.subject.subject;
          autoInvigilator = s.subject.teacher;
          break;
        }
      }
    }

    setState(() {
      slots.add(
        _PaperSlot(
          id: _generateId(),
          date: date,
          startTime: startTime,
          endTime: endTime,
          subjectCode: autoSubject,
          invigilatorId: autoInvigilator,
        ),
      );
      _recomputeConflicts();
    });
  }

  void _removePaperSlot(String classKey, String slotId) {
    setState(() {
      _slotsFor(classKey).removeWhere((s) => s.id == slotId);
      _recomputeConflicts();
    });
  }

  Future<void> _autoPopulateSlots(String classKey, int grade) async {
    // Wait for subjects to be fully loaded before populating.
    // This fixes the race condition where the user switches to a stream
    // tab and clicks Auto-fill before subjects finish loading — previously
    // the method would silently return with no papers.
    final parts = classKey.split(':');
    final stream = parts[1] == 'null' ? null : int.tryParse(parts[1]);
    await _loadOrWaitSubjects(grade, stream);
    if (!mounted) return;

    final cs = _classSubjects[classKey];
    if (cs == null || cs.subjects.isEmpty) return;
    if (_startDate == null || _endDate == null) return;

    final days = _examDays;
    if (days.isEmpty) return;

    setState(() {
      final slots = _slotsFor(classKey);
      slots.clear();

      int dayIdx = 0;
      int slotInDay = 0;
      const maxSlotsPerDay = 3;
      const slotDuration = 120; // minutes

      for (final subj in cs.subjects) {
        if (dayIdx >= days.length) break;
        final day = days[dayIdx];
        final startMin = 8 * 60 + slotInDay * slotDuration;
        final endMin = startMin + slotDuration;

        // Determine invigilator: use subject's teacher if not conflicting
        String? invigilatorId = subj.subject.teacher;
        if (_isInvigilatorBusy(
          invigilatorId,
          day,
          startMin,
          endMin,
          classKey,
        )) {
          invigilatorId = _findAvailableTeacher(
            day,
            startMin,
            endMin,
            classKey,
          );
        }

        slots.add(
          _PaperSlot(
            id: _generateId(),
            date: day,
            startTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
            endTime: TimeOfDay(
              hour: (endMin ~/ 60).clamp(0, 23),
              minute: endMin % 60,
            ),
            subjectCode: subj.subject.subject,
            invigilatorId: invigilatorId,
          ),
        );

        slotInDay++;
        if (slotInDay >= maxSlotsPerDay) {
          slotInDay = 0;
          dayIdx++;
        }
      }
      _recomputeConflicts();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Invigilator conflict detection
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a map of slot ID → error message for all slots that have
  /// an invigilator time-slot conflict with a slot in a different stream.
  Map<String, String> _findInvigilatorConflicts() {
    final conflicts = <String, String>{};
    // Collect all slots across all class keys with their metadata
    final all = <({String classKey, _PaperSlot slot})>[];
    for (final entry in _paperSlots.entries) {
      for (final slot in entry.value) {
        if (slot.invigilatorId != null &&
            slot.invigilatorId!.isNotEmpty &&
            slot.subjectCode != null) {
          all.add((classKey: entry.key, slot: slot));
        }
      }
    }

    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.classKey == b.classKey) continue; // same stream, OK
        if (a.slot.invigilatorId != b.slot.invigilatorId) continue;
        if (!_sameDay(a.slot.date, b.slot.date)) continue;

        final aStart = a.slot.startTime.hour * 60 + a.slot.startTime.minute;
        final aEnd = a.slot.endTime.hour * 60 + a.slot.endTime.minute;
        final bStart = b.slot.startTime.hour * 60 + b.slot.startTime.minute;
        final bEnd = b.slot.endTime.hour * 60 + b.slot.endTime.minute;

        if (aStart < bEnd && bStart < aEnd) {
          // Find teacher name for the message
          final teacherName =
              _teachers
                  .where((t) => t.user.id == a.slot.invigilatorId)
                  .map((t) => t.user.name)
                  .firstOrNull ??
              'Teacher';
          final msg = '$teacherName is assigned to another paper at this time';
          conflicts[a.slot.id] = msg;
          conflicts[b.slot.id] = msg;
        }
      }
    }
    return conflicts;
  }

  /// Checks if a teacher is already assigned to a paper slot at the same
  /// time in a different stream (different classKey).
  bool _isInvigilatorBusy(
    String teacherId,
    DateTime day,
    int startMin,
    int endMin,
    String excludeClassKey,
  ) {
    for (final entry in _paperSlots.entries) {
      if (entry.key == excludeClassKey) continue;
      for (final slot in entry.value) {
        if (slot.invigilatorId != teacherId) continue;
        if (!_sameDay(slot.date, day)) continue;
        final sStart = slot.startTime.hour * 60 + slot.startTime.minute;
        final sEnd = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin < sEnd && sStart < endMin) return true;
      }
    }
    return false;
  }

  /// Finds a teacher who is not busy at the given time in any stream.
  /// Returns null if no teacher is available.
  String? _findAvailableTeacher(
    DateTime day,
    int startMin,
    int endMin,
    String excludeClassKey,
  ) {
    for (final t in _teachers) {
      if (!_isInvigilatorBusy(
        t.user.id,
        day,
        startMin,
        endMin,
        excludeClassKey,
      )) {
        return t.user.id;
      }
    }
    return null; // No available teacher found
  }

  Map<String, String> _findDuplicateSubjects() {
    final conflicts = <String, String>{};
    for (final entry in _paperSlots.entries) {
      final slots = entry.value.where((s) => s.subjectCode != null).toList();
      final seen = <int, String>{}; // subjectCode → first slot ID
      for (final slot in slots) {
        final existing = seen[slot.subjectCode!];
        if (existing != null) {
          conflicts[slot.id] =
              'Duplicate subject — already assigned in this class';
          conflicts[existing] =
              'Duplicate subject — already assigned in this class';
        } else {
          seen[slot.subjectCode!] = slot.id;
        }
      }
    }
    return conflicts;
  }

  void _recomputeConflicts() {
    _slotConflicts = _findInvigilatorConflicts();
    _duplicateSubjectConflicts = _findDuplicateSubjects();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Calendar
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleCalendar() {
    setState(() => _calendarOpen = !_calendarOpen);
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
        // Clear paper slots when date range changes
        _paperSlots.clear();
      } else if (day.isAfter(_startDate!)) {
        _endDate = day;
        _calendarOpen = false;
      } else if (day.isBefore(_startDate!)) {
        _startDate = day;
        _paperSlots.clear();
      } else {
        _startDate = null;
        _endDate = null;
        _paperSlots.clear();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasSelection) return;
    final examName = _nameCtrl.text.trim();
    if (examName.isEmpty) {
      _showError('Please enter a name for this exam.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError('Please select the exam date range.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      _showError('Start date must be before end date.');
      return;
    }
    if (!_isTeacherEntry && _teacherId.isEmpty) {
      _showError('Please assign an invigilator to at least one paper.');
      return;
    }

    _recomputeConflicts();
    if (_slotConflicts.isNotEmpty || _duplicateSubjectConflicts.isNotEmpty) {
      final messages = <String>[];
      if (_slotConflicts.isNotEmpty) {
        messages.add('invigilator conflicts');
      }
      if (_duplicateSubjectConflicts.isNotEmpty) {
        messages.add('duplicate subject assignments');
      }
      _showError(
        'Some papers have ${messages.join(' and ')}. Please resolve the highlighted conflicts before saving.',
      );
      setState(() => _saving = false);
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving = true);

    try {
      // Propagate papers to all streams that haven't been configured yet.
      // This loads subjects for unvisited stream tabs and copies the paper
      // schedule from the first configured stream in each grade.
      await _ensureAllStreamsCovered();

      // Re-check conflicts after propagation (invigilator conflicts may
      // have been introduced by the auto-copy).
      _recomputeConflicts();
      if (_slotConflicts.isNotEmpty || _duplicateSubjectConflicts.isNotEmpty) {
        final messages = <String>[];
        if (_slotConflicts.isNotEmpty) {
          messages.add('invigilator conflicts');
        }
        if (_duplicateSubjectConflicts.isNotEmpty) {
          messages.add('duplicate subject assignments');
        }
        _showError(
          'Some papers have ${messages.join(' and ')}. Please resolve the highlighted conflicts before saving.',
        );
        setState(() => _saving = false);
        return;
      }

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final startDays =
          DateTime.utc(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          ).millisecondsSinceEpoch ~/
          (86400 * 1000);
      final endDays =
          DateTime.utc(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
          ).millisecondsSinceEpoch ~/
          (86400 * 1000);
      final teacherId = _teacherId;

      // ── Create ONE exam, collect ALL papers across grade+stream combos ─
      // The exams table has no grade/stream columns — a single exam can
      // span multiple grades and streams. The grade and stream are on the
      // papers table, so we create one exam ID and attach all papers to it.
      final examId = _generateId();
      final allPapers = <PapersCompanion>[];

      // Debug: log _paperSlots state before collecting papers
      debugPrint(
        '[ExamCreation] _paperSlots has ${_paperSlots.length} entries:',
      );
      for (final entry in _paperSlots.entries) {
        final actionable = entry.value
            .where((s) => s.subjectCode != null)
            .length;
        debugPrint(
          '  key="${entry.key}" → ${entry.value.length} slots ($actionable with subjects)',
        );
      }

      for (final entry in _paperSlots.entries) {
        final slots = entry.value;
        // Skip class keys with no actionable slots
        final actionableSlots = slots
            .where((s) => s.subjectCode != null)
            .toList();
        if (actionableSlots.isEmpty) continue;

        // Parse the class key ("grade:stream") back into grade + stream
        final parts = entry.key.split(':');
        final grade = int.parse(parts[0]);
        final stream = parts[1] == 'null' ? null : int.tryParse(parts[1]);

        debugPrint(
          '[ExamCreation] Processing key="${entry.key}" → grade=$grade, stream=$stream, ${actionableSlots.length} papers',
        );

        for (final slot in actionableSlots) {
          final startDt = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.startTime.hour,
            slot.startTime.minute,
          );
          final endDt = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.endTime.hour,
            slot.endTime.minute,
          );
          final startSecs = BigInt.from(startDt.millisecondsSinceEpoch ~/ 1000);
          final endSecs = BigInt.from(endDt.millisecondsSinceEpoch ~/ 1000);

          allPapers.add(
            PapersCompanion(
              school: Value(widget.schoolId),
              exam: Value(examId),
              subject: Value(slot.subjectCode!),
              paper: const Value(null),
              invigilator: Value(slot.invigilatorId ?? teacherId),
              grade: Value(grade),
              stream: Value(stream),
              start: Value(startSecs),
              end: Value(endSecs),
              status: Value(PaperStatus.pending),
              created: Value(now),
              updated: Value(now),
            ),
          );
        }
      }

      debugPrint(
        '[ExamCreation] Total papers before dedup: ${allPapers.length}',
      );

      // ── Safety net: deduplicate by (subject, paper, grade, stream) ──
      // The real-time _findDuplicateSubjects() should prevent this, but
      // guard against edge cases (e.g. rapid taps, state race) so we
      // never hit the SQLite UNIQUE constraint.
      {
        final seen = <String>{};
        final deduped = <PapersCompanion>[];
        for (final p in allPapers) {
          final paperVal = p.paper.present ? p.paper.value : null;
          final streamVal = p.stream.present ? p.stream.value : null;
          final key =
              '${p.subject.value}:$paperVal:${p.grade.value}:$streamVal';
          if (seen.add(key)) {
            deduped.add(p);
          } else {
            debugPrint(
              '[ExamCreation] Dropped duplicate paper: subject=${p.subject.value}, '
              'paper=$paperVal, grade=${p.grade.value}, stream=$streamVal',
            );
          }
        }
        allPapers
          ..clear()
          ..addAll(deduped);
      }

      debugPrint(
        '[ExamCreation] Total papers after dedup: ${allPapers.length}',
      );

      final exam = ExamsCompanion(
        id: Value(examId),
        school: Value(widget.schoolId),
        year: Value(widget.year),
        term: Value(widget.term),
        name: Value(examName),
        personalized: Value(_personalized),
        type: Value(_type),
        start: Value(startDays),
        end: Value(endDays),
        teacher: Value(teacherId),
        created: Value(now),
        updated: Value(now),
      );

      await _examsDao.createExamWithPapers(
        exam: exam,
        paperRows: allPapers,
        accountId: accountId,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('══════ EXAM CREATION ERROR ══════');
      debugPrint('Type : ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack:\n$stack');
      debugPrint('═════════════════════════════════');
      if (mounted) {
        _showError(_friendlyExamError(e));
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB71C1C),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 15, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close, size: 20, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New Exam',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── Section 1: Exam Details ─────────────────────────────
                  _buildSectionHeader(cs, 'EXAM DETAILS'),
                  const SizedBox(height: 12),
                  _buildNameField(cs, isDark),
                  const SizedBox(height: 12),
                  _buildTypeSelector(cs),
                  const SizedBox(height: 16),
                  _buildDateRange(cs),
                  const SizedBox(height: 12),
                  _buildPersonalizedToggle(
                    cs,
                    cs.brightness == Brightness.dark,
                  ),
                  const SizedBox(height: 28),

                  // ── Section 2: Grade ────────────────────────────────────
                  _buildSectionHeader(cs, 'CLASS'),
                  const SizedBox(height: 4),
                  Text(
                    'Select which grade and streams this exam covers.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGradeTabs(cs),

                  // ── Section 3: Stream chips ─────────────────────────────
                  ..._buildStreamSection(cs),

                  const SizedBox(height: 20),

                  // ── Section 4: Paper timetable ──────────────────────────
                  ..._buildTimetableSections(cs, isDark),
                ],
              ),
            ),
            // ── Footer ─────────────────────────────────────────────────
            Container(
              height: 1,
              color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _saving
                              ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                              : cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ExamConfirmButton(
                    saving: _saving,
                    enabled:
                        _hasSelection && _startDate != null && _endDate != null,
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section builders
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNameField(ColorScheme cs, bool isDark) {
    return TextFormField(
      controller: _nameCtrl,
      enabled: !_saving,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        hintText: 'e.g. Mid-Term Exam, End of Term…',
        hintStyle: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1E2C3C)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.7)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.error.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.error),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Name is required.';
        if (v.trim().length < 2) return 'Name must be at least 2 characters.';
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildSectionHeader(ColorScheme cs, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return Row(
      children: ExamType.values.map((t) {
        final isSelected = t == _type;
        final label = switch (t) {
          ExamType.exam => 'Exam',
          ExamType.assignment => 'Assignment',
          ExamType.assessment => 'Assessment',
        };
        return Padding(
          padding: EdgeInsets.only(right: t == ExamType.values.last ? 0 : 6),
          child: GestureDetector(
            onTap: () => setState(() => _type = t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(
                            alpha: isDark ? 0.25 : 0.15,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRange(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final hasRange = _startDate != null && _endDate != null;
    final hasStart = _startDate != null && _endDate == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExamDateRangeTrigger(
          startDate: _startDate,
          endDate: _endDate,
          isOpen: _calendarOpen,
          enabled: !_saving,
          isDark: isDark,
          cs: cs,
          indigo: indigo,
          onTap: _saving ? null : _toggleCalendar,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _calendarOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ExamRangeCalendar(
                    startDate: _startDate,
                    endDate: _endDate,
                    onDayTapped: _saving ? null : _onDayTapped,
                    isDark: isDark,
                    cs: cs,
                    indigo: indigo,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (_calendarOpen && hasStart && !hasRange)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Now tap the end date',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: indigo.withValues(alpha: 0.70),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalizedToggle(ColorScheme cs, bool isDark) {
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return GestureDetector(
      onTap: () => setState(() => _personalized = !_personalized),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _personalized
              ? indigo.withValues(alpha: isDark ? 0.08 : 0.05)
              : isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _personalized
                ? indigo.withValues(alpha: isDark ? 0.25 : 0.18)
                : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Custom toggle switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 32,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _personalized
                    ? indigo.withValues(alpha: 0.85)
                    : cs.onSurfaceVariant.withValues(
                        alpha: isDark ? 0.15 : 0.12,
                      ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: _personalized
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _personalized
                        ? Colors.white
                        : cs.onSurfaceVariant.withValues(
                            alpha: isDark ? 0.4 : 0.35,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personalized exam',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: _personalized
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Different questions per student',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: _personalized
                          ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeTabs(ColorScheme cs) {
    return EduTabBar(
      controller: _gradeTabController,
      tabs: _gradeTabs.map((e) => EduTab(label: e.label)).toList(),
      isScrollable: true,
      padding: EdgeInsets.zero,
    );
  }

  List<Widget> _buildStreamSection(ColorScheme cs) {
    if (_gradeTabs.isEmpty) return [];
    final tab = _gradeTabs[_activeGradeTabIndex];
    if (tab.grade == null) return [];
    final gc = _gradeConfigFor(tab.grade!);
    if (gc == null || gc.streams.isEmpty) return [];
    final ctrl = _streamTabControllers[tab.grade!];
    if (ctrl == null) return [];

    return [
      const SizedBox(height: 8),
      EduTabBar(
        controller: ctrl,
        isScrollable: true,
        padding: EdgeInsets.zero,
        tabs: [for (final s in gc.streams) EduTab(label: s.name)],
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 4 — Paper timetable (new timetable-style)
  // ─────────────────────────────────────────────────────────────────────────

  List<Widget> _buildTimetableSections(ColorScheme cs, bool isDark) {
    if (_gradeTabs.isEmpty) return [];
    final tab = _gradeTabs[_activeGradeTabIndex];
    if (tab.grade == null) return [];

    if (_startDate == null || _endDate == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Set the exam date range above to start scheduling papers.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ];
    }

    final gc = _gradeConfigFor(tab.grade!);

    // Grade with no streams → single timetable, no stream header
    if (gc == null || gc.streams.isEmpty) {
      return [
        _buildTimetableForClass(cs, isDark, tab.grade!, null),
        const SizedBox(height: 16),
      ];
    }

    final streamIdx = _activeStreamTabIndex[tab.grade!] ?? 0;
    final stream = gc.streams[streamIdx];
    return [
      _buildTimetableForClass(cs, isDark, tab.grade!, stream.code),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildTimetableForClass(
    ColorScheme cs,
    bool isDark,
    int grade,
    int? stream,
  ) {
    final key = _classKey(grade, stream);
    final isLoading = _loadingSubjects[key] == true;
    final classData = _classSubjects[key];
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final conflicts = <String, String>{..._slotConflicts};
    // Merge duplicate subject conflicts, combining messages if both exist
    for (final entry in _duplicateSubjectConflicts.entries) {
      final existing = conflicts[entry.key];
      if (existing != null) {
        conflicts[entry.key] = '$existing\n${entry.value}';
      } else {
        conflicts[entry.key] = entry.value;
      }
    }

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }
    if (classData == null || classData.subjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No subjects assigned to this class yet.',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final slots = _slotsFor(key);
    final days = _examDays;
    final curriculum = _curriculumForGrade(grade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with actions
        Row(
          children: [
            Icon(
              Icons.view_timeline_outlined,
              size: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              'PAPER SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            if (slots.isEmpty)
              _MiniTextButton(
                label: 'Auto-fill',
                icon: Icons.auto_fix_high,
                cs: cs,
                isDark: isDark,
                onTap: () => _autoPopulateSlots(key, grade),
              ),
            if (slots.isNotEmpty) ...[
              _MiniTextButton(
                label: 'Clear',
                icon: Icons.clear_all,
                cs: cs,
                isDark: isDark,
                onTap: () => setState(() => slots.clear()),
              ),
            ],
            if (_isSpecificStreamActive(grade) && slots.isNotEmpty)
              _MiniTextButton(
                label: 'Copy to all',
                icon: Icons.copy_all,
                cs: cs,
                isDark: isDark,
                onTap: () => _copyPapersToAllStreams(grade, stream!),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (slots.isEmpty)
          _EmptyTimetableHint(cs: cs, isDark: isDark)
        else
          // Group slots by day
          ...days.map((day) {
            final daySlots = slots.where((s) => _sameDay(s.date, day)).toList();
            if (daySlots.isEmpty) return const SizedBox.shrink();

            daySlots.sort((a, b) {
              final aMin = a.startTime.hour * 60 + a.startTime.minute;
              final bMin = b.startTime.hour * 60 + b.startTime.minute;
              return aMin.compareTo(bMin);
            });

            return _DayColumn(
              day: day,
              slots: daySlots,
              classKey: key,
              curriculum: curriculum,
              classSubjects: classData,
              teachers: _teachers,
              teachersLoaded: _teachersLoaded,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              slotConflicts: conflicts,
              onRemoveSlot: (id) => _removePaperSlot(key, id),
              onSlotChanged: () => setState(() {
                _recomputeConflicts();
              }),
            );
          }),

        const SizedBox(height: 8),

        // Day chips — tap to add a paper to that day
        _AddPaperRow(
          days: days,
          existingSlots: slots,
          cs: cs,
          isDark: isDark,
          indigo: indigo,
          onAddToDay: (day) => _addPaperSlot(key, day, grade),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Private widgets
// ═════════════════════════════════════════════════════════════════════════════

bool _sameDay(DateTime a, DateTime? b) {
  if (b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Translates low-level database exceptions into concise, user-readable messages.
///
/// The teacher FK is pre-validated via [_teacherId] before any DB call,
/// so no heuristic guessing on FK columns is needed here.
String _friendlyExamError(Object e) {
  final raw = e.toString();

  // Drift InvalidDataException — missing required (non-nullable) column value.
  // This is a programmer error (missing field in companion), not a user error.
  if (raw.contains('InvalidDataException') ||
      raw.contains('null value') ||
      raw.contains('required') && raw.contains('absent')) {
    return 'Internal error: a required field is missing. Please report this.';
  }

  // SQLite unique constraint (code 2067 / 1555)
  if (raw.contains('2067') || raw.contains('1555') || raw.contains('UNIQUE')) {
    return 'A paper with this subject already exists for this grade and stream in the exam.';
  }

  // SQLite check constraint (code 275) — e.g. start >= end
  if (raw.contains('275') || raw.contains('CHECK')) {
    return 'The exam date range is invalid — the end date must be after the start date.';
  }

  // SQLite FK constraint (code 787) — shouldn't normally reach here
  if (raw.contains('787') || raw.contains('FOREIGN KEY')) {
    return 'A required record is missing. Make sure the term exists before creating exams.';
  }

  // Generic fallback — include a short hint from the error itself
  return 'Something went wrong while saving (${e.runtimeType}). Please try again.';
}

String _generateId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rand = math.Random().nextInt(0x7FFFFFFF);
  return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
}

const _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _kDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _fmtDate(DateTime d) => '${d.day} ${_kMonths[d.month - 1]}';
String _fmtDateFull(DateTime d) =>
    '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

// ─────────────────────────────────────────────────────────────────────────────
// Confirm button
// ─────────────────────────────────────────────────────────────────────────────

class _ExamConfirmButton extends StatelessWidget {
  const _ExamConfirmButton({
    required this.saving,
    required this.enabled,
    required this.onTap,
  });
  final bool saving;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final canTap = !saving && enabled;

    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: canTap ? indigo : indigo.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          boxShadow: canTap
              ? [
                  BoxShadow(
                    color: indigo.withValues(alpha: isDark ? 0.30 : 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: saving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.onPrimary.withValues(alpha: 0.7),
                ),
              )
            : Text(
                'Create Exam',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: canTap
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini text button for section header actions
// ─────────────────────────────────────────────────────────────────────────────

class _MiniTextButton extends StatelessWidget {
  const _MiniTextButton({
    required this.label,
    required this.icon,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: cs.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty timetable hint
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTimetableHint extends StatelessWidget {
  const _EmptyTimetableHint({required this.cs, required this.isDark});
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.view_timeline_outlined,
            size: 28,
            color: cs.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            'No papers scheduled yet',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a date below to add papers, or use Auto-fill',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day column — groups all paper slots for one day
// ─────────────────────────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.slots,
    required this.classKey,
    required this.curriculum,
    required this.classSubjects,
    required this.teachers,
    required this.teachersLoaded,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.slotConflicts,
    required this.onRemoveSlot,
    required this.onSlotChanged,
  });

  final DateTime day;
  final List<_PaperSlot> slots;
  final String classKey;
  final CurriculumType? curriculum;
  final _ClassSubjects classSubjects;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final Map<String, String> slotConflicts;
  final ValueChanged<String> onRemoveSlot;
  final VoidCallback onSlotChanged;

  @override
  Widget build(BuildContext context) {
    final dayName = _kDayNames[day.weekday % 7];
    final dateLabel = _fmtDate(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: indigo.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$dayName, $dateLabel',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.75),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${slots.length} ${slots.length == 1 ? "paper" : "papers"}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Paper slot cards
          ...slots.asMap().entries.map((entry) {
            final slot = entry.value;
            return _PaperSlotCard(
              slot: slot,
              curriculum: curriculum,
              classSubjects: classSubjects,
              teachers: teachers,
              teachersLoaded: teachersLoaded,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              errorMessage: slotConflicts[slot.id],
              onRemove: () => onRemoveSlot(slot.id),
              onChanged: onSlotChanged,
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper slot card — a single paper entry in the timetable
// ─────────────────────────────────────────────────────────────────────────────

class _PaperSlotCard extends StatefulWidget {
  const _PaperSlotCard({
    required this.slot,
    required this.curriculum,
    required this.classSubjects,
    required this.teachers,
    required this.teachersLoaded,
    required this.cs,
    required this.isDark,
    required this.indigo,
    this.errorMessage,
    required this.onRemove,
    required this.onChanged,
  });

  final _PaperSlot slot;
  final CurriculumType? curriculum;
  final _ClassSubjects classSubjects;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final String? errorMessage;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_PaperSlotCard> createState() => _PaperSlotCardState();
}

class _PaperSlotCardState extends State<_PaperSlotCard> {
  bool _timePickerOpen = false;

  // Duration is derived from slot.startTime + slot.endTime on first build,
  // then kept in sync as user changes start or duration.
  late int _durationMinutes;

  late FixedExtentScrollController _startHourCtrl;
  late FixedExtentScrollController _startMinCtrl;
  late FixedExtentScrollController _durHourCtrl;
  late FixedExtentScrollController _durMinCtrl;

  static const _durMinValues = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    final start = widget.slot.startTime;
    final end = widget.slot.endTime;
    final startMins = start.hour * 60 + start.minute;
    final endMins = end.hour * 60 + end.minute;
    _durationMinutes = (endMins - startMins).clamp(15, 240);

    _startHourCtrl = FixedExtentScrollController(initialItem: start.hour);
    _startMinCtrl = FixedExtentScrollController(initialItem: start.minute ~/ 5);
    _durHourCtrl = FixedExtentScrollController(
      initialItem: _durationMinutes ~/ 60,
    );
    final remMin = _durationMinutes % 60;
    final mIdx = _durMinValues.indexOf(remMin);
    _durMinCtrl = FixedExtentScrollController(initialItem: mIdx < 0 ? 0 : mIdx);
  }

  @override
  void dispose() {
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _durHourCtrl.dispose();
    _durMinCtrl.dispose();
    super.dispose();
  }

  void _onStartTimeChanged(int h, int m) {
    widget.slot.startTime = TimeOfDay(hour: h, minute: m);
    final startMins = h * 60 + m;
    final endTotalMins = startMins + _durationMinutes;
    widget.slot.endTime = TimeOfDay(
      hour: (endTotalMins ~/ 60) % 24,
      minute: endTotalMins % 60,
    );
    widget.onChanged();
  }

  void _onDurationChanged(int minutes) {
    setState(() => _durationMinutes = minutes);
    final start = widget.slot.startTime;
    final startMins = start.hour * 60 + start.minute;
    final endTotalMins = startMins + minutes;
    widget.slot.endTime = TimeOfDay(
      hour: (endTotalMins ~/ 60) % 24,
      minute: endTotalMins % 60,
    );
    widget.onChanged();
  }

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;
    final hasSubject = slot.subjectCode != null;
    final hasConflict = widget.errorMessage != null;

    final borderColor = hasConflict
        ? cs.error.withValues(alpha: isDark ? 0.6 : 0.5)
        : hasSubject
        ? indigo.withValues(alpha: isDark ? 0.18 : 0.12)
        : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06);

    final timeTriggerFill = isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final timeBorderColor = _timePickerOpen
        ? indigo.withValues(alpha: isDark ? 0.55 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.22)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: remove button ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
            child: Row(
              children: [
                // Inline time field trigger
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      color: timeTriggerFill,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: timeBorderColor,
                        width: _timePickerOpen ? 1.5 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _timePickerOpen = !_timePickerOpen),
                        borderRadius: BorderRadius.circular(6),
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: WidgetStateProperty.resolveWith((s) {
                          if (s.contains(WidgetState.hovered) ||
                              s.contains(WidgetState.pressed)) {
                            return indigo.withValues(alpha: 0.05);
                          }
                          return Colors.transparent;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: indigo.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${_fmtTod(slot.startTime)} · ${_fmtDuration(_durationMinutes)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: _timePickerOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more,
                                  size: 14,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Remove button
                GestureDetector(
                  onTap: widget.onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Inline time configurator (expandable) ──────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: _SlotInlineTimeConfigurator(
                startTime: slot.startTime,
                durationMinutes: _durationMinutes,
                startHourCtrl: _startHourCtrl,
                startMinCtrl: _startMinCtrl,
                durHourCtrl: _durHourCtrl,
                durMinCtrl: _durMinCtrl,
                isDark: isDark,
                cs: cs,
                indigo: indigo,
                onStartTimeChanged: _onStartTimeChanged,
                onDurationChanged: _onDurationChanged,
              ),
            ),
            crossFadeState: _timePickerOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),

          const SizedBox(height: 8),

          // ── Subject selector ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _SubjectDropdown(
              value: slot.subjectCode,
              curriculum: widget.curriculum,
              classSubjects: widget.classSubjects,
              cs: cs,
              isDark: isDark,
              onChanged: (code) {
                slot.subjectCode = code;
                if (code != null) {
                  final match = widget.classSubjects.subjects
                      .where((s) => s.subject.subject == code)
                      .firstOrNull;
                  if (match != null) {
                    slot.invigilatorId = match.subject.teacher;
                  }
                }
                widget.onChanged();
              },
            ),
          ),

          const SizedBox(height: 6),

          // ── Invigilator ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, hasConflict ? 4 : 10),
            child: _InlineInvigilator(
              value: slot.invigilatorId,
              teachers: widget.teachers,
              teachersLoaded: widget.teachersLoaded,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onChanged: (id) {
                slot.invigilatorId = id;
                widget.onChanged();
              },
            ),
          ),

          // ── Conflict error indicator ────────────────────────────────
          if (hasConflict)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: cs.error.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline time configurator for slot cards (start time + duration wheels)
// ─────────────────────────────────────────────────────────────────────────────

class _SlotInlineTimeConfigurator extends StatefulWidget {
  const _SlotInlineTimeConfigurator({
    required this.startTime,
    required this.durationMinutes,
    required this.startHourCtrl,
    required this.startMinCtrl,
    required this.durHourCtrl,
    required this.durMinCtrl,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.onStartTimeChanged,
    required this.onDurationChanged,
  });

  final TimeOfDay startTime;
  final int durationMinutes;
  final FixedExtentScrollController startHourCtrl;
  final FixedExtentScrollController startMinCtrl;
  final FixedExtentScrollController durHourCtrl;
  final FixedExtentScrollController durMinCtrl;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final void Function(int hour, int minute) onStartTimeChanged;
  final void Function(int minutes) onDurationChanged;

  @override
  State<_SlotInlineTimeConfigurator> createState() =>
      _SlotInlineTimeConfiguratorState();
}

class _SlotInlineTimeConfiguratorState
    extends State<_SlotInlineTimeConfigurator> {
  static const _durMinValues = [0, 15, 30, 45];

  late int _startHour;
  late int _startMin;
  late int _durHour;
  late int _durMinIndex;

  @override
  void initState() {
    super.initState();
    _startHour = widget.startTime.hour;
    _startMin = widget.startTime.minute;
    _durHour = widget.durationMinutes ~/ 60;
    final remMin = widget.durationMinutes % 60;
    _durMinIndex = _durMinValues.indexOf(remMin);
    if (_durMinIndex < 0) _durMinIndex = 0;
  }

  int get _currentDurationMinutes =>
      _durHour * 60 + _durMinValues[_durMinIndex];

  void _applyDurationPreset(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final mIdx = _durMinValues.indexOf(m);
    if (mIdx < 0) return;
    setState(() {
      _durHour = h;
      _durMinIndex = mIdx;
    });
    widget.durHourCtrl.animateToItem(
      h,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    widget.durMinCtrl.animateToItem(
      mIdx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    widget.onDurationChanged(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    final sectionLabelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
    );

    final containerBg = isDark
        ? const Color(0xFF1A2332)
        : cs.surfaceContainerHighest.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Wheels row ──────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('START', style: sectionLabelStyle),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              child: _WheelColumn(
                                controller: widget.startHourCtrl,
                                itemCount: 24,
                                labelBuilder: (i) =>
                                    i.toString().padLeft(2, '0'),
                                selectedIndex: _startHour,
                                cs: cs,
                                isDark: isDark,
                                indigo: indigo,
                                onChanged: (i) {
                                  setState(() => _startHour = i);
                                  widget.onStartTimeChanged(
                                    _startHour,
                                    _startMin,
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  color: cs.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: _WheelColumn(
                                controller: widget.startMinCtrl,
                                itemCount: 12,
                                labelBuilder: (i) =>
                                    (i * 5).toString().padLeft(2, '0'),
                                selectedIndex: _startMin ~/ 5,
                                cs: cs,
                                isDark: isDark,
                                indigo: indigo,
                                onChanged: (i) {
                                  setState(() => _startMin = i * 5);
                                  widget.onStartTimeChanged(
                                    _startHour,
                                    _startMin,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical divider
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Container(
                    width: 1,
                    height: 100,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.15 : 0.25,
                    ),
                  ),
                ),
                // Duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('DURATION', style: sectionLabelStyle),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 42,
                              child: _WheelColumn(
                                controller: widget.durHourCtrl,
                                itemCount: 5,
                                labelBuilder: (i) => '${i}h',
                                selectedIndex: _durHour,
                                cs: cs,
                                isDark: isDark,
                                indigo: indigo,
                                onChanged: (i) {
                                  setState(() => _durHour = i);
                                  widget.onDurationChanged(
                                    _currentDurationMinutes,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 42,
                              child: _WheelColumn(
                                controller: widget.durMinCtrl,
                                itemCount: 4,
                                labelBuilder: (i) =>
                                    '${_durMinValues[i].toString().padLeft(2, '0')}m',
                                selectedIndex: _durMinIndex,
                                cs: cs,
                                isDark: isDark,
                                indigo: indigo,
                                onChanged: (i) {
                                  setState(() => _durMinIndex = i);
                                  widget.onDurationChanged(
                                    _currentDurationMinutes,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Duration presets ────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in [
                (label: '30m', minutes: 30),
                (label: '1h', minutes: 60),
                (label: '1h 30m', minutes: 90),
                (label: '2h', minutes: 120),
                (label: '2h 30m', minutes: 150),
                (label: '3h', minutes: 180),
              ])
                _TimePresetChip(
                  label: p.label,
                  isSelected: _currentDurationMinutes == p.minutes,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => _applyDurationPreset(p.minutes),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wheel column for time picker
// ─────────────────────────────────────────────────────────────────────────────

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.selectedIndex,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final int selectedIndex;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Selection highlight
        Positioned.fill(
          child: Center(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: indigo.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        // Wheel
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 36,
          perspective: 0.003,
          diameterRatio: 1.6,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final isSelected = index == selectedIndex;
              return Center(
                child: Text(
                  labelBuilder(index),
                  style: TextStyle(
                    fontSize: isSelected ? 20 : 15,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                    color: isSelected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.35),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time preset chip
// ─────────────────────────────────────────────────────────────────────────────

class _TimePresetChip extends StatelessWidget {
  const _TimePresetChip({
    required this.label,
    required this.isSelected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? indigo.withValues(alpha: 0.15)
              : isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? indigo.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected
                ? indigo
                : cs.onSurfaceVariant.withValues(alpha: 0.65),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectDropdown extends StatelessWidget {
  const _SubjectDropdown({
    required this.value,
    required this.curriculum,
    required this.classSubjects,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final int? value;
  final CurriculumType? curriculum;
  final _ClassSubjects classSubjects;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = classSubjects.subjects;
    final hasValue = value != null;
    final label = hasValue ? classSubjects.nameFor(value!) : 'Select subject';

    return GestureDetector(
      onTap: () => _showPicker(context, items),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
              : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: hasValue
                ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.15)
                : cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 13,
              color: hasValue
                  ? cs.primary.withValues(alpha: 0.7)
                  : cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasValue ? FontWeight.w400 : FontWeight.w400,
                  color: hasValue
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.unfold_more,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    List<({SubjectTeacher subject, UsersData teacher, String subjectName})>
    items,
  ) {
    final renderBox = context.findRenderObject() as RenderBox;
    final triggerSize = renderBox.size;
    final triggerOffset = renderBox.localToGlobal(Offset.zero);

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _SubjectDropdownOverlay(
        items: items,
        value: value,
        curriculum: curriculum,
        triggerOffset: triggerOffset,
        triggerSize: triggerSize,
        onSelected: (code) {
          entry.remove();
          onChanged(code);
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// macOS-style inline subject dropdown overlay (exam creation page)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectDropdownOverlay extends StatefulWidget {
  const _SubjectDropdownOverlay({
    required this.items,
    required this.value,
    required this.curriculum,
    required this.triggerOffset,
    required this.triggerSize,
    required this.onSelected,
    required this.onDismiss,
  });

  final List<({SubjectTeacher subject, UsersData teacher, String subjectName})>
  items;
  final int? value;
  final CurriculumType? curriculum;
  final Offset triggerOffset;
  final Size triggerSize;
  final ValueChanged<int?> onSelected;
  final VoidCallback onDismiss;

  @override
  State<_SubjectDropdownOverlay> createState() =>
      _SubjectDropdownOverlayState();
}

class _SubjectDropdownOverlayState extends State<_SubjectDropdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _scaleAnim = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    final screenSize = MediaQuery.sizeOf(context);

    final menuWidth = widget.triggerSize.width;
    const noneItemHeight = 36.0;
    const subjectItemHeight = 44.0; // taller to fit subtitle (teacher name)
    // +1 for the "None" option
    final totalItems = widget.items.length + 1;
    final menuHeight =
        (noneItemHeight + widget.items.length * subjectItemHeight + 8).clamp(
          0.0,
          280.0,
        );

    // Position below trigger, or above if not enough space below.
    final spaceBelow =
        screenSize.height -
        widget.triggerOffset.dy -
        widget.triggerSize.height -
        8;
    final showAbove =
        spaceBelow < menuHeight && widget.triggerOffset.dy > menuHeight;

    final menuTop = showAbove
        ? widget.triggerOffset.dy - menuHeight - 4
        : widget.triggerOffset.dy + widget.triggerSize.height + 4;
    final menuLeft = widget.triggerOffset.dx;

    final menuBg = isDark ? const Color(0xFF1E2A3A) : cs.surface;

    return Stack(
      children: [
        // Barrier — dismiss on tap outside
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          top: menuTop,
          left: menuLeft,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: showAbove ? Alignment.bottomLeft : Alignment.topLeft,
              child: Container(
                width: menuWidth,
                constraints: BoxConstraints(maxHeight: menuHeight),
                decoration: BoxDecoration(
                  color: menuBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.3 : 0.5,
                    ),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.4 : 0.12,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.06,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    physics: const ClampingScrollPhysics(),
                    itemCount: totalItems,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.15 : 0.25,
                      ),
                    ),
                    itemBuilder: (_, i) {
                      // First item is "None"
                      if (i == 0) {
                        final isSelected = widget.value == null;
                        return _buildMenuItem(
                          label: 'None',
                          subtitle: null,
                          isSelected: isSelected,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onTap: () => widget.onSelected(null),
                        );
                      }
                      final item = widget.items[i - 1];
                      final code = item.subject.subject;
                      final name = widget.items[i - 1].subjectName;
                      final isSelected = widget.value == code;
                      return _buildMenuItem(
                        label: name,
                        subtitle: item.teacher.name,
                        isSelected: isSelected,
                        cs: cs,
                        isDark: isDark,
                        indigo: indigo,
                        onTap: () => widget.onSelected(code),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String label,
    required String? subtitle,
    required bool isSelected,
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return indigo.withValues(alpha: 0.06);
          }
          return Colors.transparent;
        }),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle != null ? 44 : 36),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: subtitle != null ? 6 : 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: isSelected ? indigo : cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isSelected) Icon(Icons.check, size: 13, color: indigo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline invigilator — compact row showing assigned teacher with tap to change
// ─────────────────────────────────────────────────────────────────────────────

class _InlineInvigilator extends StatelessWidget {
  const _InlineInvigilator({
    required this.value,
    required this.teachers,
    required this.teachersLoaded,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final String? value;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final match = hasValue
        ? teachers.where((t) => t.user.id == value).firstOrNull
        : null;
    final name = match?.user.name;

    return GestureDetector(
      onTap: teachersLoaded ? () => _showPicker(context) : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            Icons.person_outline,
            size: 11,
            color: hasValue
                ? indigo.withValues(alpha: 0.5)
                : cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 5),
          Text(
            'Invigilator',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name ?? (hasValue ? 'Unknown' : 'Not assigned'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: hasValue ? FontWeight.w400 : FontWeight.w400,
                color: hasValue
                    ? cs.onSurface.withValues(alpha: 0.7)
                    : cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!teachersLoaded)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            )
          else
            Icon(
              Icons.swap_horiz,
              size: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A2332) : cs.surface;

    showEduSheet(
      context: context,
      builder: (ctx) => _InvigilatorPickerSheet(
        teachers: teachers,
        value: value,
        cs: cs,
        isDark: isDark,
        sheetBg: sheetBg,
        onChanged: (id) {
          onChanged(id);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invigilator picker sheet with search
// ─────────────────────────────────────────────────────────────────────────────

class _InvigilatorPickerSheet extends StatefulWidget {
  const _InvigilatorPickerSheet({
    required this.teachers,
    required this.value,
    required this.cs,
    required this.isDark,
    required this.sheetBg,
    required this.onChanged,
  });

  final List<({TeachersData teacher, UsersData user})> teachers;
  final String? value;
  final ColorScheme cs;
  final bool isDark;
  final Color sheetBg;
  final ValueChanged<String?> onChanged;

  @override
  State<_InvigilatorPickerSheet> createState() =>
      _InvigilatorPickerSheetState();
}

class _InvigilatorPickerSheetState extends State<_InvigilatorPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<({TeachersData teacher, UsersData user})> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.teachers;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.teachers;
      } else {
        _filtered = widget.teachers
            .where((t) => t.user.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: widget.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: isDark ? 0.15 : 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Invigilator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 6),
                      child: Icon(
                        Icons.search,
                        size: 16,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 0,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              height: 1,
              color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: _filtered.map((item) {
                  return _PickerOption(
                    label: item.user.name,
                    subtitle: item.user.phone,
                    isSelected: widget.value == item.user.id,
                    cs: cs,
                    isDark: isDark,
                    onTap: () => widget.onChanged(item.user.id),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Picker option row
// ─────────────────────────────────────────────────────────────────────────────

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final String? subtitle;
  final bool isSelected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final indigo = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: isSelected
            ? indigo.withValues(alpha: isDark ? 0.1 : 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? indigo : cs.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check, size: 16, color: indigo),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add paper row — day chips to add papers
// ─────────────────────────────────────────────────────────────────────────────

class _AddPaperRow extends StatelessWidget {
  const _AddPaperRow({
    required this.days,
    required this.existingSlots,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onAddToDay,
  });

  final List<DateTime> days;
  final List<_PaperSlot> existingSlots;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<DateTime> onAddToDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              'Add paper to:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days.map((day) {
              final count = existingSlots
                  .where((s) => _sameDay(s.date, day))
                  .length;
              final dayName = _kDayNames[day.weekday % 7];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onAddToDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: count > 0
                            ? indigo.withValues(alpha: isDark ? 0.2 : 0.15)
                            : cs.outline.withValues(
                                alpha: isDark ? 0.08 : 0.06,
                              ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$dayName ${day.day}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: indigo.withValues(
                                alpha: isDark ? 0.2 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: indigo,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 2),
                        Icon(
                          Icons.add,
                          size: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  INLINE DATE RANGE — trigger + calendar
// ═════════════════════════════════════════════════════════════════════════════

class _ExamDateRangeTrigger extends StatelessWidget {
  const _ExamDateRangeTrigger({
    required this.startDate,
    required this.endDate,
    required this.isOpen,
    required this.enabled,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.onTap,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final bool isOpen;
  final bool enabled;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final VoidCallback? onTap;

  bool get _hasRange => startDate != null && endDate != null;

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? const Color(0xFF1E2C3C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);

    final borderColor = _hasRange
        ? indigo.withValues(alpha: isDark ? 0.55 : 0.45)
        : isOpen
        ? indigo.withValues(alpha: isDark ? 0.45 : 0.35)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4);

    final iconBg = _hasRange
        ? indigo.withValues(alpha: isDark ? 0.18 : 0.10)
        : isOpen
        ? indigo.withValues(alpha: isDark ? 0.12 : 0.07)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.25);

    final iconColor = _hasRange || isOpen
        ? indigo
        : cs.onSurfaceVariant.withValues(alpha: enabled ? 0.45 : 0.25);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: _hasRange || isOpen ? 1.5 : 1,
        ),
        boxShadow: _hasRange
            ? [
                BoxShadow(
                  color: indigo.withValues(alpha: isDark ? 0.10 : 0.06),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return indigo.withValues(alpha: 0.05);
            }
            return Colors.transparent;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                // Icon badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    _hasRange
                        ? Icons.date_range_outlined
                        : Icons.calendar_today_outlined,
                    size: 12,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 9),

                // Label
                Expanded(
                  child: _hasRange
                      ? Row(
                          children: [
                            Text(
                              _fmtDateFull(startDate!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 10,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _fmtDateFull(endDate!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          startDate != null
                              ? '${_fmtDateFull(startDate!)}  →  …'
                              : 'Pick date range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: startDate != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: startDate != null
                                ? cs.onSurface.withValues(alpha: 0.75)
                                : cs.onSurfaceVariant.withValues(
                                    alpha: enabled ? 0.40 : 0.22,
                                  ),
                          ),
                        ),
                ),

                // Chevron
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(
                      alpha: enabled ? 0.40 : 0.18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline range calendar
// ─────────────────────────────────────────────────────────────────────────────

class _ExamRangeCalendar extends StatefulWidget {
  const _ExamRangeCalendar({
    required this.startDate,
    required this.endDate,
    required this.onDayTapped,
    required this.isDark,
    required this.cs,
    required this.indigo,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime>? onDayTapped;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;

  @override
  State<_ExamRangeCalendar> createState() => _ExamRangeCalendarState();
}

class _ExamRangeCalendarState extends State<_ExamRangeCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _viewMonth;
  late final AnimationController _slideCtrl;
  int _slideDirection = 0; // -1 prev, 0 none, +1 next

  @override
  void initState() {
    super.initState();
    final seed = widget.startDate ?? DateTime.now();
    _viewMonth = DateTime(seed.year, seed.month);
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() {
    _slideDirection = -1;
    _slideCtrl.forward(from: 0).then((_) {
      setState(() {
        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
        _slideDirection = 0;
      });
    });
  }

  void _nextMonth() {
    _slideDirection = 1;
    _slideCtrl.forward(from: 0).then((_) {
      setState(() {
        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
        _slideDirection = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.isDark
        ? const Color(0xFF141E2A)
        : widget.cs.surfaceContainer.withValues(alpha: 0.60);
    final border = widget.cs.outlineVariant.withValues(
      alpha: widget.isDark ? 0.20 : 0.35,
    );

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalendarMonthHeader(
            viewMonth: _viewMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
            isDark: widget.isDark,
            cs: widget.cs,
          ),
          const SizedBox(height: 8),
          _CalendarWeekdayRow(isDark: widget.isDark, cs: widget.cs),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _slideCtrl,
            builder: (context, child) {
              // Slight fade during transition for a smooth feel
              final opacity = _slideDirection != 0
                  ? (1.0 - _slideCtrl.value * 0.3)
                  : 1.0;
              return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
            },
            child: _CalendarDayGrid(
              viewMonth: _viewMonth,
              startDate: widget.startDate,
              endDate: widget.endDate,
              onDayTapped: widget.onDayTapped,
              isDark: widget.isDark,
              cs: widget.cs,
              indigo: widget.indigo,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

const _kFullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.viewMonth,
    required this.onPrev,
    required this.onNext,
    required this.isDark,
    required this.cs,
  });

  final DateTime viewMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final chevronColor = cs.onSurfaceVariant.withValues(alpha: 0.50);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CalendarChevronBtn(
          icon: Icons.chevron_left,
          onTap: onPrev,
          color: chevronColor,
        ),
        Text(
          '${_kFullMonthNames[viewMonth.month - 1]} ${viewMonth.year}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            letterSpacing: 0.1,
          ),
        ),
        _CalendarChevronBtn(
          icon: Icons.chevron_right,
          onTap: onNext,
          color: chevronColor,
        ),
      ],
    );
  }
}

class _CalendarChevronBtn extends StatelessWidget {
  const _CalendarChevronBtn({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _CalendarWeekdayRow extends StatelessWidget {
  const _CalendarWeekdayRow({required this.isDark, required this.cs});

  final bool isDark;
  final ColorScheme cs;

  static const _labels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels.map((label) {
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CalendarDayGrid extends StatelessWidget {
  const _CalendarDayGrid({
    required this.viewMonth,
    required this.startDate,
    required this.endDate,
    required this.onDayTapped,
    required this.isDark,
    required this.cs,
    required this.indigo,
  });

  final DateTime viewMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime>? onDayTapped;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday % 7; // Sun=0

    final totalCells = startWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rowCount, (row) {
        return SizedBox(
          height: 30,
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - startWeekday + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return Expanded(
                  child: _CalendarOverflowCell(
                    viewMonth: viewMonth,
                    dayNum: dayNum,
                    daysInMonth: daysInMonth,
                    isDark: isDark,
                    cs: cs,
                  ),
                );
              }

              final date = DateTime(viewMonth.year, viewMonth.month, dayNum);
              final isToday = date == todayDate;
              final isStart = _sameDay(date, startDate);
              final isEnd = _sameDay(date, endDate);
              final isEndpoint = isStart || isEnd;

              final inRange =
                  startDate != null &&
                  endDate != null &&
                  date.isAfter(startDate!) &&
                  date.isBefore(endDate!);

              _BandPos bandPos = _BandPos.none;
              if (isStart && endDate != null && !isEnd) {
                bandPos = _BandPos.start;
              } else if (isEnd && startDate != null && !isStart) {
                bandPos = _BandPos.end;
              } else if (inRange) {
                bandPos = _BandPos.mid;
              } else if (isStart && isEnd) {
                bandPos = _BandPos.single;
              }

              return Expanded(
                child: _CalendarDayCell(
                  day: dayNum,
                  isToday: isToday,
                  isEndpoint: isEndpoint,
                  bandPos: bandPos,
                  isDark: isDark,
                  cs: cs,
                  indigo: indigo,
                  onTap: onDayTapped != null ? () => onDayTapped!(date) : null,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _CalendarOverflowCell extends StatelessWidget {
  const _CalendarOverflowCell({
    required this.viewMonth,
    required this.dayNum,
    required this.daysInMonth,
    required this.isDark,
    required this.cs,
  });

  final DateTime viewMonth;
  final int dayNum;
  final int daysInMonth;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    int display;
    if (dayNum < 1) {
      final prevMonth = DateTime(viewMonth.year, viewMonth.month, 0);
      display = prevMonth.day + dayNum;
    } else {
      display = dayNum - daysInMonth;
    }
    return Center(
      child: Text(
        '$display',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: isDark ? 0.18 : 0.22),
        ),
      ),
    );
  }
}

enum _BandPos { none, start, mid, end, single }

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.isEndpoint,
    required this.bandPos,
    required this.isDark,
    required this.cs,
    required this.indigo,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isEndpoint;
  final _BandPos bandPos;
  final bool isDark;
  final ColorScheme cs;
  final Color indigo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bandColor = indigo.withValues(alpha: isDark ? 0.16 : 0.11);
    final hasBand = bandPos != _BandPos.none && bandPos != _BandPos.single;

    const double circleDia = 26;
    const double halfCircle = circleDia / 2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Range band background
          if (hasBand)
            Positioned.fill(
              child: Container(
                margin: EdgeInsets.only(
                  left: bandPos == _BandPos.start ? halfCircle : 0,
                  right: bandPos == _BandPos.end ? halfCircle : 0,
                ),
                decoration: BoxDecoration(
                  color: bandColor,
                  borderRadius: BorderRadius.horizontal(
                    left: bandPos == _BandPos.start
                        ? Radius.circular(halfCircle)
                        : Radius.zero,
                    right: bandPos == _BandPos.end
                        ? Radius.circular(halfCircle)
                        : Radius.zero,
                  ),
                ),
              ),
            ),

          // Circle / ring
          Container(
            width: circleDia,
            height: circleDia,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEndpoint ? indigo : Colors.transparent,
              border: isToday && !isEndpoint
                  ? Border.all(color: indigo, width: 1.2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isEndpoint || isToday
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isEndpoint
                    ? Colors.white
                    : isToday
                    ? indigo
                    : cs.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
