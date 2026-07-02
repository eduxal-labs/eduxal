import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/exam_group.dart';
import '../../../../models/school_config.dart';
import '../../../theme/app_theme.dart';
import '../../../../core/formatters.dart';
import '../../../widgets/edu_sheet.dart';
import 'exams_shared.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add Stream to Exam — Form
// ─────────────────────────────────────────────────────────────────────────────

class AddStreamForm extends StatefulWidget {
  const AddStreamForm({
    super.key,
    required this.group,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.subjectNames,
    required this.dao,
    required this.subjectsDao,
    required this.membersDao,
    required this.onClose,
    this.teacherAssignedGrades,
  });

  final ExamGroup group;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;
  final MembersDao membersDao;
  final VoidCallback onClose;

  /// When non-null, only grades in this set are shown in the grade picker.
  /// Used to restrict stream addition for [TeacherEntry] users to their
  /// assigned grades.
  final Set<int>? teacherAssignedGrades;

  @override
  State<AddStreamForm> createState() => _AddStreamFormState();
}

class _AddStreamFormState extends State<AddStreamForm> {
  // ── Grade selection ────────────────────────────────────────────────────────
  // The grade index currently being configured (index into _gradesWithMissing).
  int _selectedGradeIndex = 0;

  // ── Stream dropdown overlay ────────────────────────────────────────────────
  // The stream code currently shown in the paper-config area.
  int? _activeStreamCode; // null = no stream selected yet

  // ── Paper slot state ───────────────────────────────────────────────────────
  // Slots keyed by stream code; streams with no slots are still saveable (no papers).
  final Map<int?, List<_GradePaperSlot>> _paperSlots = {};

  // ── Subject / teacher loading ──────────────────────────────────────────────
  final Map<int?, List<({SubjectTeacher subject, UsersData teacher})>>
  _subjects = {};
  final Map<int?, bool> _loadingSubjects = {};
  List<({TeachersData teacher, UsersData user})> _teachers = [];
  bool _teachersLoaded = false;

  // ── Misc ───────────────────────────────────────────────────────────────────
  bool _saving = false;

  // ── Invigilator conflict tracking ──────────────────────────────────────────
  Map<String, String> _slotConflicts = {};

  // ── Overlay for stream dropdown ────────────────────────────────────────────
  OverlayEntry? _streamOverlay;
  final GlobalKey _streamTriggerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    // Auto-select first grade with missing streams
    final grades = _gradesWithMissing;
    if (grades.isNotEmpty) {
      // Auto-select first available stream for that grade
      final missing = _missingStreamsForGrade(grades[0].grade);
      if (missing.isNotEmpty) {
        _activeStreamCode = missing.first;
        _loadSubjectsForStream(grades[0].grade, missing.first);
      }
    }
  }

  @override
  void dispose() {
    _closeStreamOverlay();
    super.dispose();
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  /// Grades that already participate in the exam group AND still have at
  /// least one stream missing from the group.
  List<GradeConfig> get _gradesWithMissing {
    final result = <GradeConfig>[];
    final allowed = widget.teacherAssignedGrades;
    for (final gradeEntry in widget.group.grades) {
      // For teachers, skip grades they are not assigned to
      if (allowed != null && !allowed.contains(gradeEntry.grade)) continue;
      final gc = _gradeConfigFor(gradeEntry.grade);
      if (gc == null) continue;
      if (_missingStreamsForGrade(gradeEntry.grade).isNotEmpty) {
        result.add(gc);
      }
    }
    return result;
  }

  GradeConfig? _gradeConfigFor(int grade) {
    for (final curriculum in widget.config.curricula) {
      final gc = curriculum.grades.where((g) => g.grade == grade).firstOrNull;
      if (gc != null) return gc;
    }
    return null;
  }

  /// Stream codes present in the config but NOT yet in the exam group for
  /// the given grade.
  List<int?> _missingStreamsForGrade(int grade) {
    final gc = _gradeConfigFor(grade);
    if (gc == null) return [];
    // Find streams already in the group for this grade
    final existing = <int?>{};
    for (final gradeEntry in widget.group.grades) {
      if (gradeEntry.grade != grade) continue;
      for (final se in gradeEntry.streams) {
        existing.add(se.streamCode);
      }
    }
    if (gc.streams.isEmpty) {
      // No-stream grade — already covered if null is in existing
      if (existing.contains(null)) return [];
      return [null];
    }
    return gc.streams
        .map((s) => s.code as int?)
        .where((c) => !existing.contains(c))
        .toList();
  }

  GradeConfig? get _currentGradeConfig {
    final grades = _gradesWithMissing;
    if (grades.isEmpty) return null;
    final idx = _selectedGradeIndex.clamp(0, grades.length - 1);
    return grades[idx];
  }

  int? get _currentGrade => _currentGradeConfig?.grade;

  List<int?> get _currentMissingStreams {
    final grade = _currentGrade;
    if (grade == null) return [];
    return _missingStreamsForGrade(grade);
  }

  String _streamName(int grade, int? streamCode) {
    if (streamCode == null) return 'All Streams';
    return examStreamLabel(grade, streamCode, widget.config);
  }

  List<DateTime> get _examDays {
    final start = DateTime.fromMillisecondsSinceEpoch(
      widget.group.start * 86400 * 1000,
      isUtc: true,
    );
    final end = DateTime.fromMillisecondsSinceEpoch(
      widget.group.end * 86400 * 1000,
      isUtc: true,
    );
    final days = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endLocal)) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  List<_GradePaperSlot> _slotsFor(int? streamCode) =>
      _paperSlots.putIfAbsent(streamCode, () => []);

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _loadTeachers() async {
    try {
      final teachersList = await widget.membersDao
          .watchTeachers(widget.schoolId)
          .first;
      if (!mounted) return;
      final results = <({TeachersData teacher, UsersData user})>[];
      for (final t in teachersList) {
        final user = await widget.membersDao.findUserById(t.user);
        if (!mounted) return;
        if (user != null) results.add((teacher: t, user: user));
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

  Future<void> _loadSubjectsForStream(int grade, int? streamCode) async {
    if (_loadingSubjects[streamCode] == true ||
        _subjects.containsKey(streamCode)) {
      return;
    }
    setState(() => _loadingSubjects[streamCode] = true);
    try {
      final result = streamCode != null
          ? (await widget.subjectsDao.getSubjectsForClass(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: grade,
              stream: streamCode,
            )).map((s) => (subject: s.subject, teacher: s.teacher)).toList()
          : <({SubjectTeacher subject, UsersData teacher})>[];
      if (mounted) {
        setState(() {
          _subjects[streamCode] = result;
          _loadingSubjects[streamCode] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubjects[streamCode] = false);
    }
  }

  // ── Invigilator conflict helpers ──────────────────────────────────────────

  /// Checks if a teacher is already assigned to a paper slot at the same
  /// time in a different stream.
  bool _isInvigilatorBusy(
    String teacherId,
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final entry in _paperSlots.entries) {
      if (entry.key == excludeStreamCode) continue;
      for (final slot in entry.value) {
        if (slot.invigilatorId != teacherId) continue;
        if (!(slot.date.year == day.year &&
            slot.date.month == day.month &&
            slot.date.day == day.day)) {
          continue;
        }
        final sStart = slot.startTime.hour * 60 + slot.startTime.minute;
        final sEnd = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin < sEnd && sStart < endMin) return true;
      }
    }
    return false;
  }

  /// Finds a teacher who is not busy at the given time in any stream.
  String? _findAvailableTeacher(
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final t in _teachers) {
      if (!_isInvigilatorBusy(
        t.user.id,
        day,
        startMin,
        endMin,
        excludeStreamCode,
      )) {
        return t.user.id;
      }
    }
    return null;
  }

  /// Scans all paper slots across all streams and returns a map of
  /// slot ID → error message for conflicting invigilators.
  Map<String, String> _findInvigilatorConflicts() {
    final conflicts = <String, String>{};
    final all = <({int? streamCode, _GradePaperSlot slot})>[];
    for (final entry in _paperSlots.entries) {
      for (final slot in entry.value) {
        if (slot.invigilatorId != null &&
            slot.invigilatorId!.isNotEmpty &&
            slot.subjectCode != null) {
          all.add((streamCode: entry.key, slot: slot));
        }
      }
    }
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.streamCode == b.streamCode) continue;
        if (a.slot.invigilatorId != b.slot.invigilatorId) continue;
        if (!(a.slot.date.year == b.slot.date.year &&
            a.slot.date.month == b.slot.date.month &&
            a.slot.date.day == b.slot.date.day)) {
          continue;
        }
        final aStart = a.slot.startTime.hour * 60 + a.slot.startTime.minute;
        final aEnd = a.slot.endTime.hour * 60 + a.slot.endTime.minute;
        final bStart = b.slot.startTime.hour * 60 + b.slot.startTime.minute;
        final bEnd = b.slot.endTime.hour * 60 + b.slot.endTime.minute;
        if (aStart < bEnd && bStart < aEnd) {
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

  void _recomputeConflicts() {
    _slotConflicts = _findInvigilatorConflicts();
  }

  // ── Auto-fill ─────────────────────────────────────────────────────────────

  void _autoFillStream(int grade, int? streamCode) {
    final subjs = _subjects[streamCode] ?? [];
    if (subjs.isEmpty) return;
    final days = _examDays;
    if (days.isEmpty) return;

    final slots = _slotsFor(streamCode);
    slots.clear();

    int dayIdx = 0;
    int slotInDay = 0;
    const maxPerDay = 3;
    const durationMin = 120;

    for (final s in subjs) {
      if (dayIdx >= days.length) break;
      final day = days[dayIdx];
      final startMin = 8 * 60 + slotInDay * durationMin;
      final endMin = startMin + durationMin;

      // Check if this teacher is busy in another stream at this time
      String? invigilatorId = s.subject.teacher;
      if (_isInvigilatorBusy(
        invigilatorId,
        day,
        startMin,
        endMin,
        streamCode,
      )) {
        invigilatorId = _findAvailableTeacher(
          day,
          startMin,
          endMin,
          streamCode,
        );
      }

      slots.add(
        _GradePaperSlot(
          id: generateId(),
          date: day,
          startTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
          endTime: TimeOfDay(
            hour: (endMin ~/ 60).clamp(0, 23),
            minute: endMin % 60,
          ),
          subjectCode: s.subject.subject,
          invigilatorId: invigilatorId,
        ),
      );
      slotInDay++;
      if (slotInDay >= maxPerDay) {
        slotInDay = 0;
        dayIdx++;
      }
    }
    _recomputeConflicts();
    setState(() {});
  }

  void _autoFillAllStreams() {
    final grade = _currentGrade;
    if (grade == null) return;
    for (final streamCode in _currentMissingStreams) {
      _autoFillStream(grade, streamCode);
    }
  }

  // ── Stream overlay ────────────────────────────────────────────────────────

  void _closeStreamOverlay() {
    _streamOverlay?.remove();
    _streamOverlay = null;
  }

  void _toggleStreamOverlay(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    Color indigo,
    int grade,
    List<int?> streams,
  ) {
    if (_streamOverlay != null) {
      _closeStreamOverlay();
      return;
    }

    final renderBox =
        _streamTriggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _streamOverlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeStreamOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              width: size.width,
              child: _StreamDropdownOverlay(
                streams: streams,
                current: _activeStreamCode,
                grade: grade,
                config: widget.config,
                cs: cs,
                isDark: isDark,
                indigo: indigo,
                onSelected: (code) {
                  _closeStreamOverlay();
                  if (code == null) {
                    // "Auto-fill all streams" action
                    _autoFillAllStreams();
                  } else {
                    setState(() => _activeStreamCode = code);
                    _loadSubjectsForStream(grade, code);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_streamOverlay!);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final grade = _currentGrade;
    if (grade == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Validate invigilator conflicts
    _recomputeConflicts();
    if (_slotConflicts.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some papers have invigilator time conflicts. Please resolve the highlighted conflicts before saving.',
            ),
          ),
        );
        setState(() {});
      }
      return;
    }

    // ── Validate start < end for every slot ──────────────────────────────
    for (final streamCode in _currentMissingStreams) {
      for (final slot in _slotsFor(streamCode)) {
        if (slot.subjectCode == null) continue;
        final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
        final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin >= endMin) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Paper start time must be before end time. Please fix the highlighted slot.',
                ),
              ),
            );
          }
          return;
        }
      }
    }

    // ── Validate no duplicate time slots within the batch ────────────────
    {
      final allSlots =
          <({int? streamCode, int dateKey, int startMin, int endMin})>[];
      for (final streamCode in _currentMissingStreams) {
        for (final slot in _slotsFor(streamCode)) {
          if (slot.subjectCode == null) continue;
          final dateKey =
              slot.date.year * 10000 + slot.date.month * 100 + slot.date.day;
          final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
          final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
          allSlots.add((
            streamCode: streamCode,
            dateKey: dateKey,
            startMin: startMin,
            endMin: endMin,
          ));
        }
      }
      for (int i = 0; i < allSlots.length; i++) {
        for (int j = i + 1; j < allSlots.length; j++) {
          final a = allSlots[i];
          final b = allSlots[j];
          if (a.streamCode == b.streamCode &&
              a.dateKey == b.dateKey &&
              a.startMin < b.endMin &&
              b.startMin < a.endMin) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Two papers in the same stream have overlapping time slots on the same day. Please adjust the times.',
                  ),
                ),
              );
            }
            return;
          }
        }
      }
    }

    // Find the existing exam row for this grade (use first stream's exam as
    // the template for school/year/term/type/dates/teacher fields).
    final gradeEntry = widget.group.grades
        .where((g) => g.grade == grade)
        .firstOrNull;
    if (gradeEntry == null) return;
    final templateExam = gradeEntry.streams.first.exam;

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);

      // Add papers to the EXISTING exam — no new exam rows needed.
      // The grade and stream are on the papers table.
      final existingExamId = templateExam.id;

      for (final streamCode in _currentMissingStreams) {
        for (final slot in _slotsFor(streamCode)) {
          if (slot.subjectCode == null) continue;
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
          await widget.dao.createPaper(
            paper: PapersCompanion(
              school: Value(widget.schoolId),
              exam: Value(existingExamId),
              subject: Value(slot.subjectCode!),
              paper: const Value(null),
              invigilator: Value(slot.invigilatorId ?? templateExam.teacher),
              start: Value(BigInt.from(startDt.millisecondsSinceEpoch ~/ 1000)),
              end: Value(BigInt.from(endDt.millisecondsSinceEpoch ~/ 1000)),
              grade: Value(grade),
              stream: Value(streamCode),
              status: const Value(PaperStatus.pending),
              created: Value(now),
              updated: Value(now),
            ),
            accountId: accountId,
          );
        }
      }
      if (mounted) widget.onClose();
    } catch (e, stack) {
      debugPrint('══════ ADD STREAM ERROR ══════');
      debugPrint('Type : ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack:\n$stack');
      debugPrint('══════════════════════════════');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB71C1C),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to add stream (${e.runtimeType}). Please try again.',
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
        setState(() => _saving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indigo = const Color(0xFF5C6BC0);

    final grades = _gradesWithMissing;

    // Empty state — all streams already included across all participating grades
    if (grades.isEmpty) {
      return _buildAllStreamsIncluded(cs, isDark);
    }

    final gc = _currentGradeConfig!;
    final grade = gc.grade;
    final missing = _missingStreamsForGrade(grade);
    final activeCode = _activeStreamCode;
    final activeSubjects = activeCode != null
        ? (_subjects[activeCode] ?? [])
        : <({SubjectTeacher subject, UsersData teacher})>[];
    final isLoading =
        activeCode != null && _loadingSubjects[activeCode] == true;
    final activeSlots = activeCode != null
        ? _slotsFor(activeCode)
        : <_GradePaperSlot>[];

    // Set count badge: how many streams have ≥1 slot configured
    final setCount = missing
        .where((sc) => (_paperSlots[sc] ?? []).isNotEmpty)
        .length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildStreamHeader(cs, isDark, indigo, grade),
          // Grade selector (only when multiple grades have missing streams)
          if (grades.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _buildGradeSelector(grades, cs, isDark, indigo),
            ),
          // Stream dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _buildStreamDropdownTrigger(
              context,
              missing,
              grade,
              setCount,
              cs,
              isDark,
              indigo,
            ),
          ),
          // Paper slot list for active stream
          Flexible(
            child: activeCode == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Select a stream above to configure papers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : activeSubjects.isEmpty && activeSlots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No subjects assigned to this class yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    shrinkWrap: true,
                    children: [
                      ...activeSlots.asMap().entries.map(
                        (e) => _GradePaperSlotCard(
                          key: ValueKey(e.value.id),
                          slot: e.value,
                          subjects: activeSubjects,
                          teachers: _teachers,
                          teachersLoaded: _teachersLoaded,
                          config: widget.config,
                          subjectNames: widget.subjectNames,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          examDays: _examDays,
                          errorMessage: _slotConflicts[e.value.id],
                          onChanged: (_) {
                            _recomputeConflicts();
                            setState(() {});
                          },
                          onRemove: () {
                            setState(() {
                              activeSlots.remove(e.value);
                              _recomputeConflicts();
                            });
                          },
                        ),
                      ),
                      _GradeAddPaperButton(
                        cs: cs,
                        isDark: isDark,
                        indigo: indigo,
                        onTap: () {
                          final days = _examDays;
                          if (days.isEmpty) return;
                          final slots = _slotsFor(activeCode);
                          TimeOfDay startTime;
                          if (slots.isNotEmpty) {
                            startTime = slots.last.endTime;
                          } else {
                            startTime = const TimeOfDay(hour: 8, minute: 0);
                          }
                          final endMin =
                              startTime.hour * 60 + startTime.minute + 120;
                          final usedSubjects = slots
                              .map((s) => s.subjectCode)
                              .toSet();
                          int? autoSubject;
                          String? autoInvig;
                          for (final s in activeSubjects) {
                            if (!usedSubjects.contains(s.subject.subject)) {
                              autoSubject = s.subject.subject;
                              autoInvig = s.subject.teacher;
                              break;
                            }
                          }
                          setState(() {
                            slots.add(
                              _GradePaperSlot(
                                id: generateId(),
                                date: days.first,
                                startTime: startTime,
                                endTime: TimeOfDay(
                                  hour: (endMin ~/ 60).clamp(0, 23),
                                  minute: endMin % 60,
                                ),
                                subjectCode: autoSubject,
                                invigilatorId: autoInvig,
                              ),
                            );
                          });
                        },
                      ),
                      if (activeSlots.isEmpty && activeSubjects.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: TextButton.icon(
                            onPressed: () => _autoFillStream(grade, activeCode),
                            icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                            ),
                            label: const Text('Auto-fill from subjects'),
                            style: TextButton.styleFrom(
                              splashFactory: NoSplash.splashFactory,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
          // Footer
          _buildStreamFooter(cs, isDark, indigo),
        ],
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _buildStreamHeader(
    ColorScheme cs,
    bool isDark,
    Color indigo,
    int grade,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
    child: Row(
      children: [
        Text(
          'Add Stream',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            examGradeLabel(grade, widget.config),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
          onPressed: widget.onClose,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
        ),
      ],
    ),
  );

  Widget _buildAllStreamsIncluded(ColorScheme cs, bool isDark) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 32,
          color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 14),
        Text(
          'All streams included',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Every stream for all participating grades is already in this exam.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _buildGradeSelector(
    List<GradeConfig> grades,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    return Row(
      children: grades.asMap().entries.map((e) {
        final isSelected = _selectedGradeIndex == e.key;
        final label = examGradeLabel(e.value.grade, widget.config);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () {
              if (_selectedGradeIndex == e.key) return;
              setState(() {
                _selectedGradeIndex = e.key;
                _activeStreamCode = null;
              });
              final missing = _missingStreamsForGrade(e.value.grade);
              if (missing.isNotEmpty) {
                setState(() => _activeStreamCode = missing.first);
                _loadSubjectsForStream(e.value.grade, missing.first);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? indigo.withValues(alpha: isDark ? 0.18 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? indigo.withValues(alpha: 0.55)
                      : cs.outlineVariant.withValues(
                          alpha: isDark ? 0.25 : 0.35,
                        ),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? indigo : cs.onSurface,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStreamDropdownTrigger(
    BuildContext context,
    List<int?> streams,
    int grade,
    int setCount,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final activeCode = _activeStreamCode;
    final hasActive = activeCode != null;
    final label = hasActive ? _streamName(grade, activeCode) : 'Select stream…';

    return GestureDetector(
      key: _streamTriggerKey,
      onTap: () =>
          _toggleStreamOverlay(context, cs, isDark, indigo, grade, streams),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasActive
              ? indigo.withValues(alpha: isDark ? 0.12 : 0.07)
              : (isDark
                    ? const Color(0xFF1E2C3C)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasActive
                ? indigo.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasActive ? FontWeight.w500 : FontWeight.w400,
                color: hasActive ? indigo : cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (setCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$setCount set',
                  style: TextStyle(fontSize: 10.5, color: indigo),
                ),
              ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamFooter(ColorScheme cs, bool isDark, Color indigo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: widget.onClose,
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              _GradeConfirmButton(
                saving: _saving,
                indigo: indigo,
                onTap: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream dropdown overlay (macOS-style inline overlay)
// ─────────────────────────────────────────────────────────────────────────────

class _StreamDropdownOverlay extends StatefulWidget {
  const _StreamDropdownOverlay({
    required this.streams,
    required this.current,
    required this.grade,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
  });

  final List<int?> streams;
  final int? current;
  final int grade;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;

  /// Called with null for "auto-fill all streams", or a stream code to select.
  final ValueChanged<int?> onSelected;

  @override
  State<_StreamDropdownOverlay> createState() => _StreamDropdownOverlayState();
}

class _StreamDropdownOverlayState extends State<_StreamDropdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _streamName(int? code) {
    if (code == null) return 'All Streams';
    return examStreamLabel(widget.grade, code, widget.config);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2A3A) : cs.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Regular stream items
                ...widget.streams.map((code) {
                  final isSelected = code == widget.current;
                  final label = _streamName(code);
                  return InkWell(
                    splashFactory: NoSplash.splashFactory,
                    onTap: () => widget.onSelected(code),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
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
                          const Spacer(),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 14, color: indigo),
                        ],
                      ),
                    ),
                  );
                }),
                // Divider before special action
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.35,
                  ),
                ),
                // Auto-fill all streams action
                InkWell(
                  splashFactory: NoSplash.splashFactory,
                  // Pass null to signal "auto-fill all"
                  onTap: () => widget.onSelected(null),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 15, color: indigo),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-fill all streams',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: indigo,
                          ),
                        ),
                      ],
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
// Add Grade to Exam — Form (two-step)
// ─────────────────────────────────────────────────────────────────────────────

/// A two-step form for adding a new grade (+ streams) to an existing exam group.
///
/// Step 1: Grade selection + stream toggle checkboxes.
/// Step 2: Per-stream paper timetable configuration.
class AddGradeToExamForm extends StatefulWidget {
  const AddGradeToExamForm({
    super.key,
    required this.group,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.subjectNames,
    required this.dao,
    required this.subjectsDao,
    required this.membersDao,
    required this.onClose,
    this.teacherAssignedGrades,
  });

  final ExamGroup group;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;
  final MembersDao membersDao;
  final VoidCallback onClose;

  /// When non-null, only grades in this set are shown in the grade picker.
  /// Used to restrict grade addition for [TeacherEntry] users to their
  /// assigned grades.
  final Set<int>? teacherAssignedGrades;

  @override
  State<AddGradeToExamForm> createState() => _AddGradeToExamFormState();
}

class _AddGradeToExamFormState extends State<AddGradeToExamForm>
    with SingleTickerProviderStateMixin {
  // ── Step management ────────────────────────────────────────────────────────
  int _step = 0; // 0 = grade+stream, 1 = paper timetable

  // ── Step 1 state ──────────────────────────────────────────────────────────
  int? _selectedGrade;
  final Set<int?> _selectedStreams = {}; // null = no-stream grade

  // ── Step 2 state ──────────────────────────────────────────────────────────
  // Paper slots keyed by stream code (null for no-stream grades)
  final Map<int?, List<_GradePaperSlot>> _paperSlots = {};
  // Subjects loaded per stream
  final Map<int?, List<({SubjectTeacher subject, UsersData teacher})>>
  _subjects = {};
  final Map<int?, bool> _loadingSubjects = {};
  // Active stream being configured in step 2
  int _activeStreamTabIndex = 0;
  // Teachers for invigilator picker
  List<({TeachersData teacher, UsersData user})> _teachers = [];
  bool _teachersLoaded = false;
  bool _saving = false;

  // ── Invigilator conflict tracking ──────────────────────────────────────────
  Map<String, String> _slotConflicts = {};

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// All grades in the school config that are NOT already in the exam group.
  List<GradeConfig> get _availableGrades {
    final existing = widget.group.participatingGrades.toSet();
    final allowed = widget.teacherAssignedGrades;
    final result = <GradeConfig>[];
    for (final curriculum in widget.config.curricula) {
      for (final gc in curriculum.grades) {
        if (existing.contains(gc.grade)) continue;
        // For teachers, skip grades they are not assigned to
        if (allowed != null && !allowed.contains(gc.grade)) continue;
        result.add(gc);
      }
    }
    return result;
  }

  /// Stream codes for the selected grade, or [null] in a singleton list if
  /// the grade has no streams.
  List<int?> get _streamsForSelected {
    if (_selectedGrade == null) return [];
    for (final curriculum in widget.config.curricula) {
      final gc = curriculum.grades
          .where((g) => g.grade == _selectedGrade)
          .firstOrNull;
      if (gc != null) {
        if (gc.streams.isEmpty) return [null];
        return gc.streams.map((s) => s.code as int?).toList();
      }
    }
    return [];
  }

  String _streamName(int grade, int? streamCode) {
    if (streamCode == null) return 'All Streams';
    return examStreamLabel(grade, streamCode, widget.config);
  }

  Future<void> _loadTeachers() async {
    try {
      final teachersList = await widget.membersDao
          .watchTeachers(widget.schoolId)
          .first;
      if (!mounted) return;
      final results = <({TeachersData teacher, UsersData user})>[];
      for (final t in teachersList) {
        final user = await widget.membersDao.findUserById(t.user);
        if (!mounted) return;
        if (user != null) results.add((teacher: t, user: user));
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

  Future<void> _loadSubjectsForStream(int grade, int? streamCode) async {
    if (_loadingSubjects[streamCode] == true ||
        _subjects.containsKey(streamCode)) {
      return;
    }
    setState(() => _loadingSubjects[streamCode] = true);
    try {
      final result = streamCode != null
          ? (await widget.subjectsDao.getSubjectsForClass(
              schoolId: widget.schoolId,
              year: widget.year,
              term: widget.term,
              grade: grade,
              stream: streamCode,
            )).map((s) => (subject: s.subject, teacher: s.teacher)).toList()
          : <({SubjectTeacher subject, UsersData teacher})>[];
      if (mounted) {
        setState(() {
          _subjects[streamCode] = result;
          _loadingSubjects[streamCode] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubjects[streamCode] = false);
    }
  }

  List<_GradePaperSlot> _slotsFor(int? streamCode) {
    return _paperSlots.putIfAbsent(streamCode, () => []);
  }

  List<DateTime> get _examDays {
    final start = DateTime.fromMillisecondsSinceEpoch(
      widget.group.start * 86400 * 1000,
      isUtc: true,
    );
    final end = DateTime.fromMillisecondsSinceEpoch(
      widget.group.end * 86400 * 1000,
      isUtc: true,
    );
    final days = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endLocal)) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  // ── Invigilator conflict helpers ──────────────────────────────────────────

  bool _isInvigilatorBusy(
    String teacherId,
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final entry in _paperSlots.entries) {
      if (entry.key == excludeStreamCode) continue;
      for (final slot in entry.value) {
        if (slot.invigilatorId != teacherId) continue;
        if (!(slot.date.year == day.year &&
            slot.date.month == day.month &&
            slot.date.day == day.day)) {
          continue;
        }
        final sStart = slot.startTime.hour * 60 + slot.startTime.minute;
        final sEnd = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin < sEnd && sStart < endMin) return true;
      }
    }
    return false;
  }

  String? _findAvailableTeacher(
    DateTime day,
    int startMin,
    int endMin,
    int? excludeStreamCode,
  ) {
    for (final t in _teachers) {
      if (!_isInvigilatorBusy(
        t.user.id,
        day,
        startMin,
        endMin,
        excludeStreamCode,
      )) {
        return t.user.id;
      }
    }
    return null;
  }

  Map<String, String> _findInvigilatorConflicts() {
    final conflicts = <String, String>{};
    final all = <({int? streamCode, _GradePaperSlot slot})>[];
    for (final entry in _paperSlots.entries) {
      for (final slot in entry.value) {
        if (slot.invigilatorId != null &&
            slot.invigilatorId!.isNotEmpty &&
            slot.subjectCode != null) {
          all.add((streamCode: entry.key, slot: slot));
        }
      }
    }
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.streamCode == b.streamCode) continue;
        if (a.slot.invigilatorId != b.slot.invigilatorId) continue;
        if (!(a.slot.date.year == b.slot.date.year &&
            a.slot.date.month == b.slot.date.month &&
            a.slot.date.day == b.slot.date.day)) {
          continue;
        }
        final aStart = a.slot.startTime.hour * 60 + a.slot.startTime.minute;
        final aEnd = a.slot.endTime.hour * 60 + a.slot.endTime.minute;
        final bStart = b.slot.startTime.hour * 60 + b.slot.startTime.minute;
        final bEnd = b.slot.endTime.hour * 60 + b.slot.endTime.minute;
        if (aStart < bEnd && bStart < aEnd) {
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

  void _recomputeConflicts() {
    _slotConflicts = _findInvigilatorConflicts();
  }

  void _autoFillStream(int? streamCode) {
    final grade = _selectedGrade;
    if (grade == null) return;
    final subjs = _subjects[streamCode] ?? [];
    if (subjs.isEmpty) return;
    final days = _examDays;
    if (days.isEmpty) return;

    final slots = _slotsFor(streamCode);
    slots.clear();

    int dayIdx = 0;
    int slotInDay = 0;
    const maxPerDay = 3;
    const durationMin = 120;

    for (final s in subjs) {
      if (dayIdx >= days.length) break;
      final day = days[dayIdx];
      final startMin = 8 * 60 + slotInDay * durationMin;
      final endMin = startMin + durationMin;

      // Check if this teacher is busy in another stream at this time
      String? invigilatorId = s.subject.teacher;
      if (_isInvigilatorBusy(
        invigilatorId,
        day,
        startMin,
        endMin,
        streamCode,
      )) {
        invigilatorId = _findAvailableTeacher(
          day,
          startMin,
          endMin,
          streamCode,
        );
      }

      slots.add(
        _GradePaperSlot(
          id: generateId(),
          date: day,
          startTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
          endTime: TimeOfDay(
            hour: (endMin ~/ 60).clamp(0, 23),
            minute: endMin % 60,
          ),
          subjectCode: s.subject.subject,
          invigilatorId: invigilatorId,
        ),
      );
      slotInDay++;
      if (slotInDay >= maxPerDay) {
        slotInDay = 0;
        dayIdx++;
      }
    }
    _recomputeConflicts();
    setState(() {});
  }

  // ── Step transitions ───────────────────────────────────────────────────────

  void _goToStep2() {
    if (_selectedGrade == null || _selectedStreams.isEmpty) return;
    // Pre-load subjects for all selected streams
    for (final sc in _selectedStreams) {
      _loadSubjectsForStream(_selectedGrade!, sc);
    }
    setState(() {
      _step = 1;
      _activeStreamTabIndex = 0;
    });
  }

  void _goBackToStep1() {
    setState(() => _step = 0);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final grade = _selectedGrade;
    if (grade == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Validate invigilator conflicts
    _recomputeConflicts();
    if (_slotConflicts.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some papers have invigilator time conflicts. Please resolve the highlighted conflicts before saving.',
            ),
          ),
        );
        setState(() {});
      }
      return;
    }

    // ── Validate start < end for every slot ──────────────────────────────
    for (final streamCode in _selectedStreams) {
      for (final slot in _slotsFor(streamCode)) {
        if (slot.subjectCode == null) continue;
        final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
        final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
        if (startMin >= endMin) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Paper start time must be before end time. Please fix the highlighted slot.',
                ),
              ),
            );
          }
          return;
        }
      }
    }

    // ── Validate no duplicate time slots within the batch ────────────────
    {
      final allSlots =
          <({int? streamCode, int dateKey, int startMin, int endMin})>[];
      for (final streamCode in _selectedStreams) {
        for (final slot in _slotsFor(streamCode)) {
          if (slot.subjectCode == null) continue;
          final dateKey =
              slot.date.year * 10000 + slot.date.month * 100 + slot.date.day;
          final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
          final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
          allSlots.add((
            streamCode: streamCode,
            dateKey: dateKey,
            startMin: startMin,
            endMin: endMin,
          ));
        }
      }
      for (int i = 0; i < allSlots.length; i++) {
        for (int j = i + 1; j < allSlots.length; j++) {
          final a = allSlots[i];
          final b = allSlots[j];
          if (a.streamCode == b.streamCode &&
              a.dateKey == b.dateKey &&
              a.startMin < b.endMin &&
              b.startMin < a.endMin) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Two papers in the same stream have overlapping time slots on the same day. Please adjust the times.',
                  ),
                ),
              );
            }
            return;
          }
        }
      }
    }

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final teacherId = widget.group.teacher.id;

      // Add papers to the EXISTING exam — no new exam rows needed.
      // The grade and stream are on the papers table, not on exams.
      final existingExamId = widget.group.examIds.first;

      for (final streamCode in _selectedStreams) {
        for (final slot in _slotsFor(streamCode)) {
          if (slot.subjectCode == null) continue;
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
          await widget.dao.createPaper(
            paper: PapersCompanion(
              school: Value(widget.schoolId),
              exam: Value(existingExamId),
              subject: Value(slot.subjectCode!),
              paper: const Value(null),
              invigilator: Value(slot.invigilatorId ?? teacherId),
              start: Value(BigInt.from(startDt.millisecondsSinceEpoch ~/ 1000)),
              end: Value(BigInt.from(endDt.millisecondsSinceEpoch ~/ 1000)),
              grade: Value(grade),
              stream: Value(streamCode),
              status: const Value(PaperStatus.pending),
              created: Value(now),
              updated: Value(now),
            ),
            accountId: accountId,
          );
        }
      }
      if (mounted) widget.onClose();
    } catch (e, stack) {
      debugPrint('══════ ADD GRADE ERROR ══════');
      debugPrint('Type : ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack:\n$stack');
      debugPrint('═════════════════════════════');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB71C1C),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to add grade (${e.runtimeType}). Please try again.',
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
        setState(() => _saving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indigo = const Color(0xFF5C6BC0);

    final available = _availableGrades;

    // Empty state — all grades already included
    if (available.isEmpty) {
      return _buildAllGradesIncluded(cs, isDark);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(cs, isDark, indigo),
          // Step indicator
          _GradeStepDots(step: _step, indigo: indigo, cs: cs),
          const SizedBox(height: 8),
          // Step content
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              child: _step == 0
                  ? _buildStep1(cs, isDark, indigo, available)
                  : _buildStep2(cs, isDark, indigo),
            ),
          ),
          // Footer
          _buildFooter(cs, isDark, indigo),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark, Color indigo) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
    child: Row(
      children: [
        Text(
          _step == 0 ? 'Add Grade' : 'Paper Timetable',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
          onPressed: widget.onClose,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
        ),
      ],
    ),
  );

  Widget _buildAllGradesIncluded(ColorScheme cs, bool isDark) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 32,
          color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 14),
        Text(
          'All grades included',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This exam already covers all configured grades.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  // ── Step 1 ────────────────────────────────────────────────────────────────

  Widget _buildStep1(
    ColorScheme cs,
    bool isDark,
    Color indigo,
    List<GradeConfig> available,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select grade',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          // Grade option rows
          ...available.map(
            (gc) => _buildGradeOptionRow(gc, cs, isDark, indigo),
          ),
          if (_selectedGrade != null && _streamsForSelected.length > 1) ...[
            const SizedBox(height: 14),
            Text(
              'Select streams',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            ..._streamsForSelected.map(
              (sc) => _buildStreamToggleRow(sc, cs, isDark, indigo),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGradeOptionRow(
    GradeConfig gc,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final isSelected = _selectedGrade == gc.grade;
    final streamCount = gc.streams.length;
    final label = examGradeLabel(gc.grade, widget.config);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGrade = gc.grade;
          _selectedStreams.clear();
          // Auto-select all streams (or null if no-stream grade)
          if (gc.streams.isEmpty) {
            _selectedStreams.add(null);
          } else {
            _selectedStreams.addAll(gc.streams.map((s) => s.code as int?));
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 5),
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? indigo.withValues(alpha: isDark ? 0.18 : 0.10)
              : (isDark
                    ? const Color(0xFF1A2536)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? indigo.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? indigo : cs.onSurface,
              ),
            ),
            const Spacer(),
            if (streamCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$streamCount ${streamCount == 1 ? "stream" : "streams"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamToggleRow(
    int? streamCode,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final grade = _selectedGrade!;
    final isChecked = _selectedStreams.contains(streamCode);
    final name = _streamName(grade, streamCode);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isChecked) {
            _selectedStreams.remove(streamCode);
          } else {
            _selectedStreams.add(streamCode);
          }
        });
      },
      child: Container(
        height: 32,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            // Custom 16×16 checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isChecked ? indigo : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isChecked
                      ? indigo
                      : cs.outlineVariant.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isChecked ? FontWeight.w500 : FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  Widget _buildStep2(ColorScheme cs, bool isDark, Color indigo) {
    final grade = _selectedGrade!;
    final streams = _selectedStreams.toList();
    final hasMultipleStreams = streams.length > 1;
    final currentStreamCode = streams.isNotEmpty
        ? streams[_activeStreamTabIndex.clamp(0, streams.length - 1)]
        : null;
    final currentSlots = _slotsFor(currentStreamCode);
    final currentSubjects = _subjects[currentStreamCode] ?? [];
    final isLoading = _loadingSubjects[currentStreamCode] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stream selector (when multiple streams)
        if (hasMultipleStreams)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _buildStreamDropdown(streams, grade, cs, isDark, indigo),
          ),
        // Slots list
        Flexible(
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : currentSubjects.isEmpty && currentSlots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No subjects assigned to this class yet.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shrinkWrap: true,
                  children: [
                    ...currentSlots.asMap().entries.map(
                      (e) => _GradePaperSlotCard(
                        key: ValueKey(e.value.id),
                        slot: e.value,
                        subjects: currentSubjects,
                        teachers: _teachers,
                        teachersLoaded: _teachersLoaded,
                        config: widget.config,
                        subjectNames: widget.subjectNames,
                        cs: cs,
                        isDark: isDark,
                        indigo: indigo,
                        examDays: _examDays,
                        errorMessage: _slotConflicts[e.value.id],
                        onChanged: (_) {
                          _recomputeConflicts();
                          setState(() {});
                        },
                        onRemove: () {
                          setState(() {
                            currentSlots.remove(e.value);
                            _recomputeConflicts();
                          });
                        },
                      ),
                    ),
                    // Add paper dashed button
                    _GradeAddPaperButton(
                      cs: cs,
                      isDark: isDark,
                      indigo: indigo,
                      onTap: () {
                        final days = _examDays;
                        if (days.isEmpty) return;
                        final slots = _slotsFor(currentStreamCode);
                        // Chain from last slot's end time
                        TimeOfDay startTime;
                        if (slots.isNotEmpty) {
                          startTime = slots.last.endTime;
                        } else {
                          startTime = const TimeOfDay(hour: 8, minute: 0);
                        }
                        final endMin =
                            startTime.hour * 60 + startTime.minute + 120;
                        // Auto-assign first unassigned subject
                        final usedSubjects = slots
                            .map((s) => s.subjectCode)
                            .toSet();
                        int? autoSubject;
                        String? autoInvig;
                        for (final s in currentSubjects) {
                          if (!usedSubjects.contains(s.subject.subject)) {
                            autoSubject = s.subject.subject;
                            autoInvig = s.subject.teacher;
                            break;
                          }
                        }
                        setState(() {
                          slots.add(
                            _GradePaperSlot(
                              id: generateId(),
                              date: days.first,
                              startTime: startTime,
                              endTime: TimeOfDay(
                                hour: (endMin ~/ 60).clamp(0, 23),
                                minute: endMin % 60,
                              ),
                              subjectCode: autoSubject,
                              invigilatorId: autoInvig,
                            ),
                          );
                        });
                      },
                    ),
                    if (currentSlots.isEmpty && currentSubjects.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: TextButton.icon(
                          onPressed: () => _autoFillStream(currentStreamCode),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                          ),
                          label: const Text('Auto-fill from subjects'),
                          style: TextButton.styleFrom(
                            splashFactory: NoSplash.splashFactory,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStreamDropdown(
    List<int?> streams,
    int grade,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    final currentIdx = _activeStreamTabIndex.clamp(0, streams.length - 1);
    final currentCode = streams[currentIdx];
    final label = _streamName(grade, currentCode);
    // Show set count badge
    final setCounts = streams
        .where((sc) => (_paperSlots[sc] ?? []).isNotEmpty)
        .length;

    return GestureDetector(
      onTap: () async {
        // Show a simple overlay-style picker
        final chosen = await showDialog<int?>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (_) => GradeStreamPickerDialog(
            streams: streams,
            current: currentCode,
            grade: grade,
            config: widget.config,
            cs: cs,
            isDark: isDark,
          ),
        );
        if (chosen == null) return;
        final idx = streams.indexOf(chosen);
        if (idx >= 0) setState(() => _activeStreamTabIndex = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            if (setCounts > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$setCounts set',
                  style: TextStyle(fontSize: 10.5, color: indigo),
                ),
              ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, bool isDark, Color indigo) {
    final canGoNext = _selectedGrade != null && _selectedStreams.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(
            children: [
              if (_step == 1)
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: _goBackToStep1,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                  ),
                  tooltip: 'Back',
                ),
              const Spacer(),
              TextButton(
                onPressed: widget.onClose,
                style: TextButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              if (_step == 0)
                _GradeNextButton(
                  enabled: canGoNext,
                  indigo: indigo,
                  onTap: _goToStep2,
                )
              else
                _GradeConfirmButton(
                  saving: _saving,
                  indigo: indigo,
                  onTap: _save,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator dots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeStepDots extends StatelessWidget {
  const _GradeStepDots({
    required this.step,
    required this.indigo,
    required this.cs,
  });

  final int step;
  final Color indigo;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [_dot(0), const SizedBox(width: 6), _dot(1)],
    );
  }

  Widget _dot(int index) {
    final isActive = index == step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? indigo : Colors.transparent,
        border: Border.all(
          color: isActive ? indigo : cs.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next button (step 1 → step 2)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeNextButton extends StatelessWidget {
  const _GradeNextButton({
    required this.enabled,
    required this.indigo,
    required this.onTap,
  });

  final bool enabled;
  final Color indigo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? indigo : indigo.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Next',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled ? Colors.white : Colors.white60,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: enabled ? Colors.white : Colors.white60,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm button (step 2 save)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeConfirmButton extends StatelessWidget {
  const _GradeConfirmButton({
    required this.saving,
    required this.indigo,
    required this.onTap,
  });

  final bool saving;
  final Color indigo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (saving || onTap == null) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (saving || onTap == null)
              ? AppTheme.brandGreen.withValues(alpha: 0.4)
              : AppTheme.brandGreen,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper slot data class (local to Add Grade / Add Stream modals)
// ─────────────────────────────────────────────────────────────────────────────

class _GradePaperSlot {
  String id;
  DateTime date;
  TimeOfDay startTime;
  TimeOfDay endTime;
  int? subjectCode;
  String? invigilatorId;

  _GradePaperSlot({
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
// Paper slot card for the Add Grade / Add Stream modals
// ─────────────────────────────────────────────────────────────────────────────

class _GradePaperSlotCard extends StatefulWidget {
  const _GradePaperSlotCard({
    super.key,
    required this.slot,
    required this.subjects,
    required this.teachers,
    required this.teachersLoaded,
    required this.config,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.examDays,
    required this.onChanged,
    required this.onRemove,
    this.errorMessage,
  });

  final _GradePaperSlot slot;
  final List<({SubjectTeacher subject, UsersData teacher})> subjects;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final List<DateTime> examDays;
  final ValueChanged<_GradePaperSlot> onChanged;
  final VoidCallback onRemove;
  final String? errorMessage;

  @override
  State<_GradePaperSlotCard> createState() => _GradePaperSlotCardState();
}

class _GradePaperSlotCardState extends State<_GradePaperSlotCard> {
  bool _timeOpen = false;
  late int _durationMinutes;
  late final FixedExtentScrollController _startHourCtrl;
  late final FixedExtentScrollController _startMinCtrl;
  late final FixedExtentScrollController _durHourCtrl;
  late final FixedExtentScrollController _durMinCtrl;

  static const _durMinValues = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    final slot = widget.slot;
    final startMin = slot.startTime.hour * 60 + slot.startTime.minute;
    final endMin = slot.endTime.hour * 60 + slot.endTime.minute;
    _durationMinutes = (endMin - startMin).clamp(0, 23 * 60 + 45);
    _startHourCtrl = FixedExtentScrollController(
      initialItem: slot.startTime.hour,
    );
    _startMinCtrl = FixedExtentScrollController(
      initialItem: slot.startTime.minute ~/ 5,
    );
    _durHourCtrl = FixedExtentScrollController(
      initialItem: _durationMinutes ~/ 60,
    );
    _durMinCtrl = FixedExtentScrollController(
      initialItem: _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _durHourCtrl.dispose();
    _durMinCtrl.dispose();
    super.dispose();
  }

  void _onStartChanged(TimeOfDay newStart) {
    final startMin = newStart.hour * 60 + newStart.minute;
    final endMin = startMin + _durationMinutes;
    widget.slot.startTime = newStart;
    widget.slot.endTime = TimeOfDay(
      hour: (endMin ~/ 60).clamp(0, 23),
      minute: endMin % 60,
    );
    widget.onChanged(widget.slot);
  }

  void _onDurationChanged(int durationMin) {
    _durationMinutes = durationMin;
    final startMin =
        widget.slot.startTime.hour * 60 + widget.slot.startTime.minute;
    final endMin = startMin + durationMin;
    widget.slot.endTime = TimeOfDay(
      hour: (endMin ~/ 60).clamp(0, 23),
      minute: endMin % 60,
    );
    widget.onChanged(widget.slot);
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;
    final slot = widget.slot;

    final timeSummary =
        '${_fmtTod(slot.startTime)} · ${_fmtDuration(_durationMinutes)}';
    final isInvalid = _durationMinutes <= 0;
    final hasError = widget.errorMessage != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2536)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError
              ? cs.error.withValues(alpha: 0.6)
              : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: time chip + remove button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                // Time trigger chip
                GestureDetector(
                  onTap: () => setState(() => _timeOpen = !_timeOpen),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2C3C)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _timeOpen
                            ? indigo.withValues(alpha: 0.6)
                            : cs.outlineVariant.withValues(
                                alpha: isDark ? 0.3 : 0.45,
                              ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeSummary,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: isInvalid ? cs.error : cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _timeOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 140),
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Date selector
                const SizedBox(width: 8),
                _GradeDateChip(
                  date: slot.date,
                  examDays: widget.examDays,
                  cs: cs,
                  isDark: isDark,
                  indigo: indigo,
                  onChanged: (d) {
                    widget.slot.date = d;
                    widget.onChanged(widget.slot);
                    setState(() {});
                  },
                ),
                const Spacer(),
                // Remove button
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: cs.error.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Inline time configurator (expandable)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _timeOpen
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _GradeInlineTimeConfigurator(
                startTime: slot.startTime,
                durationMinutes: _durationMinutes,
                startHourCtrl: _startHourCtrl,
                startMinCtrl: _startMinCtrl,
                durHourCtrl: _durHourCtrl,
                durMinCtrl: _durMinCtrl,
                isDark: isDark,
                cs: cs,
                indigo: indigo,
                onStartTimeChanged: _onStartChanged,
                onDurationChanged: _onDurationChanged,
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
          // Subject selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: _GradeSubjectSelector(
              value: slot.subjectCode,
              subjects: widget.subjects,
              subjectNames: widget.subjectNames,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onChanged: (code, teacherId) {
                widget.slot.subjectCode = code;
                widget.slot.invigilatorId = teacherId;
                widget.onChanged(widget.slot);
                setState(() {});
              },
            ),
          ),
          // Invigilator selector
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, hasError ? 4 : 10),
            child: _GradeInvigilatorSelector(
              value: slot.invigilatorId,
              teachers: widget.teachers,
              teachersLoaded: widget.teachersLoaded,
              cs: cs,
              isDark: isDark,
              onChanged: (id) {
                widget.slot.invigilatorId = id;
                widget.onChanged(widget.slot);
                setState(() {});
              },
            ),
          ),
          // Invigilator conflict error
          if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.error.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w400,
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
// Date chip — shows exam date, opens a simple picker overlay
// ─────────────────────────────────────────────────────────────────────────────

class _GradeDateChip extends StatelessWidget {
  const _GradeDateChip({
    required this.date,
    required this.examDays,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final DateTime date;
  final List<DateTime> examDays;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final label =
        '${date.day.toString().padLeft(2, '0')} ${kMonthNames[date.month - 1]}';
    return GestureDetector(
      onTap: () async {
        final chosen = await showDialog<DateTime>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (_) => _GradeDatePickerDialog(
            selectedDate: date,
            examDays: examDays,
            cs: cs,
            isDark: isDark,
            indigo: indigo,
          ),
        );
        if (chosen != null) onChanged(chosen);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker dialog for the Add Grade modal
// ─────────────────────────────────────────────────────────────────────────────

class _GradeDatePickerDialog extends StatelessWidget {
  const _GradeDatePickerDialog({
    required this.selectedDate,
    required this.examDays,
    required this.cs,
    required this.isDark,
    required this.indigo,
  });

  final DateTime selectedDate;
  final List<DateTime> examDays;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18222E) : cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Select date',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: examDays.map((day) {
                  final isSelected = _sameDay(day, selectedDate);
                  final label =
                      '${day.day.toString().padLeft(2, '0')} ${kMonthNames[day.month - 1]}';
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo
                            : (isDark
                                  ? const Color(0xFF1A2536)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.5,
                                    )),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? indigo
                              : cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.25 : 0.4,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isSelected ? Colors.white : cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline time configurator for Add Grade modal slots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeInlineTimeConfigurator extends StatefulWidget {
  const _GradeInlineTimeConfigurator({
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
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final ValueChanged<int> onDurationChanged;

  @override
  State<_GradeInlineTimeConfigurator> createState() =>
      _GradeInlineTimeConfiguratorState();
}

class _GradeInlineTimeConfiguratorState
    extends State<_GradeInlineTimeConfigurator> {
  static const _durMinValues = [0, 15, 30, 45];

  int _startHour = 0;
  int _startMinIndex = 0; // index into 0..11 (0,5,10,...55)
  int _durHour = 0;
  int _durMinIndex = 0; // index into _durMinValues

  @override
  void initState() {
    super.initState();
    _startHour = widget.startTime.hour;
    _startMinIndex = (widget.startTime.minute ~/ 5).clamp(0, 11);
    _durHour = widget.durationMinutes ~/ 60;
    _durMinIndex = _durMinValues
        .indexOf(widget.durationMinutes % 60)
        .clamp(0, 3);
  }

  int get _currentDurationMinutes =>
      _durHour * 60 + _durMinValues[_durMinIndex];

  void _applyPreset(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final mIdx = _durMinValues.indexOf(m).clamp(0, 3);
    setState(() {
      _durHour = h;
      _durMinIndex = mIdx;
    });
    widget.durHourCtrl.jumpToItem(h);
    widget.durMinCtrl.jumpToItem(mIdx);
    widget.onDurationChanged(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2C3C)
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wheel row
          Row(
            children: [
              // Start time column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GradeWheelColumn(
                          controller: widget.startHourCtrl,
                          itemCount: 24,
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          selectedIndex: _startHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startHour = i;
                            widget.onStartTimeChanged(
                              TimeOfDay(
                                hour: _startHour,
                                minute: _startMinIndex * 5,
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        _GradeWheelColumn(
                          controller: widget.startMinCtrl,
                          itemCount: 12,
                          labelBuilder: (i) =>
                              (i * 5).toString().padLeft(2, '0'),
                          selectedIndex: _startMinIndex,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startMinIndex = i;
                            widget.onStartTimeChanged(
                              TimeOfDay(
                                hour: _startHour,
                                minute: _startMinIndex * 5,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 52,
                  child: VerticalDivider(
                    width: 1,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.2 : 0.35,
                    ),
                  ),
                ),
              ),
              // Duration column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GradeWheelColumn(
                          controller: widget.durHourCtrl,
                          itemCount: 12,
                          labelBuilder: (i) => '${i}h',
                          selectedIndex: _durHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _durHour = i;
                            widget.onDurationChanged(_currentDurationMinutes);
                          },
                        ),
                        const SizedBox(width: 4),
                        _GradeWheelColumn(
                          controller: widget.durMinCtrl,
                          itemCount: _durMinValues.length,
                          labelBuilder: (i) => '${_durMinValues[i]}m',
                          selectedIndex: _durMinIndex,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _durMinIndex = i;
                            widget.onDurationChanged(_currentDurationMinutes);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Preset chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children:
                const [
                  ('30m', 30),
                  ('1h', 60),
                  ('1h 30m', 90),
                  ('2h', 120),
                  ('2h 30m', 150),
                  ('3h', 180),
                ].map<Widget>((p) {
                  final isSelected = _currentDurationMinutes == p.$2;
                  return GestureDetector(
                    onTap: () => _applyPreset(p.$2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo.withValues(alpha: 0.18)
                            : (isDark
                                  ? const Color(0xFF18222E)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.4,
                                    )),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? indigo.withValues(alpha: 0.5)
                              : cs.outlineVariant.withValues(
                                  alpha: isDark ? 0.2 : 0.35,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        p.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isSelected ? indigo : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wheel column widget (32px item extent)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeWheelColumn extends StatelessWidget {
  const _GradeWheelColumn({
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
    return SizedBox(
      width: 44,
      height: 96,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 32,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (_, i) {
            final isSelected = i == selectedIndex;
            return Center(
              child: Text(
                labelBuilder(i),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject selector for Add Grade modal slots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSubjectSelector extends StatelessWidget {
  const _GradeSubjectSelector({
    required this.value,
    required this.subjects,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  final int? value;
  final List<({SubjectTeacher subject, UsersData teacher})> subjects;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final void Function(int? code, String? teacherId) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value != null
        ? (subjectNames[value!] ?? 'Subject $value')
        : 'Select subject';
    final hasValue = value != null;

    return GestureDetector(
      onTap: () async {
        if (subjects.isEmpty) return;
        await showEduSheet<void>(
          context: context,
          builder: (_) => _GradeSubjectPickerSheet(
            subjects: subjects,
            value: value,
            subjectNames: subjectNames,
            cs: cs,
            isDark: isDark,
            indigo: indigo,
            onSelected: (code, teacherId) {
              onChanged(code, teacherId);
              Navigator.of(context).pop();
            },
          ),
        );
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: hasValue
                ? indigo.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 14,
              color: hasValue
                  ? indigo
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                  color: hasValue
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSubjectPickerSheet extends StatelessWidget {
  const _GradeSubjectPickerSheet({
    required this.subjects,
    required this.value,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
  });

  final List<({SubjectTeacher subject, UsersData teacher})> subjects;
  final int? value;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final void Function(int code, String? teacherId) onSelected;

  @override
  Widget build(BuildContext context) {
    final sheetBg = isDark ? const Color(0xFF18222E) : cs.surface;
    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'Select subject',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: subjects.length,
            itemBuilder: (_, i) {
              final s = subjects[i];
              final label =
                  subjectNames[s.subject.subject] ??
                  'Subject ${s.subject.subject}';
              final isSelected = s.subject.subject == value;
              return InkWell(
                onTap: () => onSelected(s.subject.subject, s.subject.teacher),
                splashFactory: NoSplash.splashFactory,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected ? indigo : cs.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 16, color: indigo),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invigilator selector for Add Grade modal slots
// ─────────────────────────────────────────────────────────────────────────────

class _GradeInvigilatorSelector extends StatelessWidget {
  const _GradeInvigilatorSelector({
    required this.value,
    required this.teachers,
    required this.teachersLoaded,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final String? value;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolved = value != null
        ? teachers.where((t) => t.user.id == value).firstOrNull
        : null;
    final label =
        resolved?.user.name ?? (teachersLoaded ? 'No invigilator' : 'Loading…');
    final hasValue = resolved != null;

    return GestureDetector(
      onTap: () async {
        if (!teachersLoaded || teachers.isEmpty) return;
        await showEduSheet<void>(
          context: context,
          builder: (_) => _GradeInvigilatorPickerSheet(
            teachers: teachers,
            value: value,
            cs: cs,
            isDark: isDark,
            sheetBg: isDark ? const Color(0xFF18222E) : cs.surface,
            onChanged: (id) {
              onChanged(id);
              Navigator.of(context).pop();
            },
          ),
        );
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2C3C)
              : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invigilator picker sheet (reuses the same picker pattern from exam_creation)
// ─────────────────────────────────────────────────────────────────────────────

class _GradeInvigilatorPickerSheet extends StatefulWidget {
  const _GradeInvigilatorPickerSheet({
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
  State<_GradeInvigilatorPickerSheet> createState() =>
      _GradeInvigilatorPickerSheetState();
}

class _GradeInvigilatorPickerSheetState
    extends State<_GradeInvigilatorPickerSheet> {
  late final TextEditingController _searchCtrl;
  late List<({TeachersData teacher, UsersData user})> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered = List.of(widget.teachers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.of(widget.teachers)
          : widget.teachers
                .where(
                  (t) =>
                      t.user.name.toLowerCase().contains(lower) ||
                      t.user.phone.toLowerCase().contains(lower),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    return Container(
      decoration: BoxDecoration(
        color: widget.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'Select invigilator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filter,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1A2536)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final t = _filtered[i];
                final isSelected = t.user.id == widget.value;
                return InkWell(
                  onTap: () => widget.onChanged(t.user.id),
                  splashFactory: NoSplash.splashFactory,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.user.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF5C6BC0)
                                      : cs.onSurface,
                                ),
                              ),
                              Text(
                                t.user.phone,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Color(0xFF5C6BC0),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed "Add Paper" button for the modal
// ─────────────────────────────────────────────────────────────────────────────

class _GradeAddPaperButton extends StatelessWidget {
  const _GradeAddPaperButton({
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onTap,
  });

  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
          radius: 4,
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                'Add Paper',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 4.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream picker dialog (used by the stream dropdown in step 2)
// ─────────────────────────────────────────────────────────────────────────────

class GradeStreamPickerDialog extends StatelessWidget {
  const GradeStreamPickerDialog({
    super.key,
    required this.streams,
    required this.current,
    required this.grade,
    required this.config,
    required this.cs,
    required this.isDark,
  });

  final List<int?> streams;
  final int? current;
  final int grade;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final indigo = const Color(0xFF5C6BC0);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2A3A) : cs.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: streams.map((sc) {
              final isSelected = sc == current;
              final label = sc == null
                  ? 'All Streams'
                  : examStreamLabel(grade, sc, config);
              return InkWell(
                onTap: () => Navigator.of(context).pop(sc),
                splashFactory: NoSplash.splashFactory,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected ? indigo : cs.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 14, color: indigo),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
