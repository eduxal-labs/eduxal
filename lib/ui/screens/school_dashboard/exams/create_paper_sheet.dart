import 'dart:async';
import 'dart:math' as math;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/exam_group.dart';
import '../../../../models/school_config.dart';
import '../../../../services/authorization_service.dart';
import '../../../widgets/permission_denied_handler.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../../core/formatters.dart';
import 'exams_shared.dart';

class CreatePaperSheet extends StatefulWidget {
  const CreatePaperSheet({
    required this.examGroup,
    required this.schoolId,
    required this.examId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.config,
    required this.subjectNames,
    required this.dao,
    required this.subjectsDao,
    this.teacherUserId,
  });

  final ExamGroup examGroup;
  final String schoolId;
  final String examId;
  final int year;
  final int term;
  final int grade;
  final int? stream;
  final SchoolConfig config;
  final Map<int, String> subjectNames;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;

  /// When non-null, only subjects assigned to this teacher are shown.
  /// Used to restrict paper creation for [TeacherEntry] users.
  final String? teacherUserId;

  @override
  State<CreatePaperSheet> createState() => _CreatePaperSheetState();
}

class _CreatePaperSheetState extends State<CreatePaperSheet> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<SubjectTeacher> _subjects = [];
  bool _loadingSubjects = true;

  // ── Form state ────────────────────────────────────────────────────────────
  int? _selectedSubject;
  bool _multiPaper = false;
  int _paperNumber = 1; // 1–3 wheel
  bool _calendarOpen = false;
  bool _timeOpen = false;
  int? _timeAllowedMinutes;
  final TextEditingController _instructionsCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int _startHour = 8;
  int _startMinIndex = 0; // index into 0..11 (0,5,10,...55)
  int _durationMinutes = 120; // default 2 h
  bool _saving = false;

  // ── Wheel controllers ─────────────────────────────────────────────────────
  late final FixedExtentScrollController _paperNumCtrl;
  late final FixedExtentScrollController _startHourCtrl;
  late final FixedExtentScrollController _startMinCtrl;
  late final FixedExtentScrollController _durHourCtrl;
  late final FixedExtentScrollController _durMinCtrl;

  static const _durMinValues = [0, 15, 30, 45];

  // ── Teacher names (userId → display name) for subject overlay subtitles ──
  Map<String, String> _teacherNames = {};

  // ── Subject overlay ───────────────────────────────────────────────────────
  OverlayEntry? _subjectOverlay;
  final _subjectTriggerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Initialise with exam group's first day as default date.
    final groupStartEpochDays = widget.examGroup.start;
    _selectedDate = DateTime.fromMillisecondsSinceEpoch(
      groupStartEpochDays * 86400 * 1000,
    );
    _paperNumCtrl = FixedExtentScrollController(initialItem: 0);
    _startHourCtrl = FixedExtentScrollController(initialItem: _startHour);
    _startMinCtrl = FixedExtentScrollController(initialItem: _startMinIndex);
    final durH = _durationMinutes ~/ 60;
    final durMIdx = _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3);
    _durHourCtrl = FixedExtentScrollController(initialItem: durH);
    _durMinCtrl = FixedExtentScrollController(initialItem: durMIdx);
    _loadSubjects(); // also triggers _loadTeacherNamesForSubjects when done
  }

  @override
  void dispose() {
    _closeSubjectOverlay();
    _paperNumCtrl.dispose();
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _durHourCtrl.dispose();
    _durMinCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _loadTeacherNamesForSubjects() async {
    // Wait until subjects are loaded, then resolve each teacher's display name.
    // We collect unique teacher IDs from the subject_teachers rows and look
    // up each via MembersDao.findUserById.
    final membersDao = MembersDao(db);
    // _subjects may still be loading; call after _loadSubjects populates it.
    // We resolve what we have at call time; a second call is made after
    // _loadSubjects finishes if subjects were empty at that point.
    final ids = _subjects.map((s) => s.teacher).toSet();
    if (ids.isEmpty) return;
    final names = <String, String>{};
    for (final id in ids) {
      final user = await membersDao.findUserById(id);
      if (user != null) names[id] = user.name;
    }
    if (mounted) setState(() => _teacherNames = names);
  }

  Future<void> _loadSubjects() async {
    final allSubs = await widget.subjectsDao.getSubjectsForTerm(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
    var filtered = allSubs
        .where(
          (s) =>
              s.grade == widget.grade &&
              (widget.stream == null || s.stream == widget.stream),
        )
        .toList();
    // Teacher restriction: only show subjects the teacher is assigned to.
    if (widget.teacherUserId != null) {
      filtered = filtered
          .where((s) => s.teacher == widget.teacherUserId)
          .toList();
    }
    if (mounted) {
      setState(() {
        _subjects = filtered;
        _loadingSubjects = false;
      });
      // Now that subjects are available, resolve teacher display names.
      _loadTeacherNamesForSubjects();
    }
  }

  int get _durHourValue => _durationMinutes ~/ 60;
  int get _durMinIndex =>
      _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3);

  DateTime get _startDateTime => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _startHour,
    _startMinIndex * 5,
  );

  DateTime get _endDateTime =>
      _startDateTime.add(Duration(minutes: _durationMinutes));

  String _formatMinutes(int m) {
    final h = m ~/ 60;
    final rem = m % 60;
    if (h == 0) return '$rem minutes';
    if (rem == 0) return '$h ${h == 1 ? 'hour' : 'hours'}';
    return '$h ${h == 1 ? 'hour' : 'hours'} $rem minutes';
  }

  String _fmtTimeTrigger() {
    final sh = _startHour.toString().padLeft(2, '0');
    final sm = (_startMinIndex * 5).toString().padLeft(2, '0');
    final eh = _endDateTime.hour.toString().padLeft(2, '0');
    final em = _endDateTime.minute.toString().padLeft(2, '0');
    final dh = _durHourValue;
    final dm = _durMinValues[_durMinIndex];
    final durLabel = dm == 0 ? '${dh}h' : '${dh}h ${dm}m';
    return '$sh:$sm – $eh:$em · $durLabel';
  }

  bool get _isOutOfRange {
    final groupStart = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.start * 86400 * 1000,
    );
    final groupEnd = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.end * 86400 * 1000,
    );
    final d = _selectedDate;
    final dayOnly = DateTime(d.year, d.month, d.day);
    final rangeStart = DateTime(
      groupStart.year,
      groupStart.month,
      groupStart.day,
    );
    final rangeEnd = DateTime(groupEnd.year, groupEnd.month, groupEnd.day);
    return dayOnly.isBefore(rangeStart) || dayOnly.isAfter(rangeEnd);
  }

  void _applyDurationPreset(int minutes) {
    setState(() => _durationMinutes = minutes);
    _durHourCtrl.jumpToItem(minutes ~/ 60);
    _durMinCtrl.jumpToItem(_durMinValues.indexOf(minutes % 60).clamp(0, 3));
  }

  // ── Subject overlay ───────────────────────────────────────────────────────

  void _closeSubjectOverlay() {
    _subjectOverlay?.remove();
    _subjectOverlay = null;
  }

  void _toggleSubjectOverlay(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    Color indigo,
  ) {
    if (_subjectOverlay != null) {
      _closeSubjectOverlay();
      return;
    }

    final renderBox =
        _subjectTriggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Decide whether to open above or below.
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - (offset.dy + size.height);
    final openAbove = spaceBelow < 200;

    _subjectOverlay = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeSubjectOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: openAbove ? null : offset.dy + size.height + 4,
              bottom: openAbove ? screenHeight - offset.dy + 4 : null,
              width: size.width,
              child: _SubjectMenuOverlay(
                subjects: _subjects,
                selected: _selectedSubject,
                subjectNames: widget.subjectNames,
                cs: cs,
                isDark: isDark,
                indigo: indigo,
                teacherNames: _teacherNames,
                onSelected: (code) {
                  _closeSubjectOverlay();
                  setState(() => _selectedSubject = code);
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_subjectOverlay!);
  }

  // ── Out-of-range extension ────────────────────────────────────────────────

  Future<void> _extendExamRange(BuildContext context) async {
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    final group = widget.examGroup;

    final groupStartDt = DateTime.fromMillisecondsSinceEpoch(
      group.start * 86400 * 1000,
    );
    final groupEndDt = DateTime.fromMillisecondsSinceEpoch(
      group.end * 86400 * 1000,
    );
    final d = _selectedDate;
    final selDay = DateTime(d.year, d.month, d.day);
    final gsDay = DateTime(
      groupStartDt.year,
      groupStartDt.month,
      groupStartDt.day,
    );
    final geDays = DateTime(groupEndDt.year, groupEndDt.month, groupEndDt.day);

    final newStart = selDay.isBefore(gsDay) ? selDay : gsDay;
    final newEnd = selDay.isAfter(geDays) ? selDay : geDays;

    // Convert back to days-since-epoch
    final newStartDays = newStart.millisecondsSinceEpoch ~/ (86400 * 1000);
    final newEndDays = newEnd.millisecondsSinceEpoch ~/ (86400 * 1000);

    try {
      await widget.dao.updateExamGroupDateRange(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        examName: group.name,
        newStart: newStartDays,
        newEnd: newEndDays,
        accountId: accountId,
      );
    } catch (_) {
      // Silently ignore — the date is still usable.
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selectedSubject == null) return;
    if (_durationMinutes <= 0) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // ── Validate start < end ─────────────────────────────────────────────
    if (!_endDateTime.isAfter(_startDateTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paper start time must be before end time.'),
          ),
        );
      }
      return;
    }

    // ── Check for overlapping time slots in the same grade+stream ────────
    try {
      final existingPapers = await widget.dao
          .watchPapersForExamGradeStream(
            schoolId: widget.schoolId,
            examIds: widget.examGroup.examIds,
            grade: widget.grade,
            stream: widget.stream,
          )
          .first;
      final newStartEpoch = _startDateTime.millisecondsSinceEpoch ~/ 1000;
      final newEndEpoch = _endDateTime.millisecondsSinceEpoch ~/ 1000;
      for (final existing in existingPapers) {
        final exStart = existing.start.toInt();
        final exEnd = existing.end.toInt();
        if (newStartEpoch < exEnd && exStart < newEndEpoch) {
          // Overlapping time slot found
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Another paper already occupies this time slot. Please choose a different time.',
                ),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking for time slot conflicts: $e');
    }

    final subjectRow = _subjects
        .where((s) => s.subject == _selectedSubject)
        .firstOrNull;
    final invigilatorId = subjectRow?.teacher ?? accountId;

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.createPaper(
        paper: PapersCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.examId),
          subject: Value(_selectedSubject!),
          paper: Value(_multiPaper ? _paperNumber : null),
          invigilator: Value(invigilatorId),
          start: Value(
            BigInt.from(_startDateTime.millisecondsSinceEpoch ~/ 1000),
          ),
          end: Value(BigInt.from(_endDateTime.millisecondsSinceEpoch ~/ 1000)),
          grade: Value(widget.grade),
          stream: Value(widget.stream),
          status: const Value(PaperStatus.pending),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
        timeAllowedMinutes: _timeAllowedMinutes,
        customInstructions: _instructionsCtrl.text.trim().isEmpty
            ? null
            : _instructionsCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } on PermissionException catch (e) {
      if (mounted) showPermissionDenied(context, e.reason);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  // Wrapping (Dialog on desktop / bottom sheet on mobile) is handled by
  // showEduSheet — this widget only returns the form content.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indigo = const Color(0xFF5C7CFA);

    final gradeLabel = examGradeLabel(widget.grade, widget.config);
    final streamLabel = widget.stream != null
        ? examStreamLabel(widget.grade, widget.stream!, widget.config)
        : null;
    final subtitle = streamLabel != null
        ? '$gradeLabel · $streamLabel'
        : gradeLabel;

    final sheetBg = isDark ? const Color(0xFF18222E) : cs.surface;

    // isSheet: false — the drag handle is provided by EduSheet / showEduSheet,
    // so we don't render a duplicate one inside the content.
    return _buildContent(
      context,
      cs: cs,
      isDark: isDark,
      indigo: indigo,
      subtitle: subtitle,
      sheetBg: sheetBg,
      isSheet: false,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
    required String subtitle,
    required Color sheetBg,
    required bool isSheet,
  }) {
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.25 : 0.4,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isSheet)
                Center(
                  child: Container(
                    width: 32,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.4 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Paper',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    style: IconButton.styleFrom(
                      splashFactory: NoSplash.splashFactory,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Divider(height: 1, thickness: 1, color: borderColor),
        // ── Body ────────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subject selector
                _buildSubjectRow(
                  context,
                  cs: cs,
                  isDark: isDark,
                  indigo: indigo,
                ),
                const SizedBox(height: 14),
                // Multi-paper + paper number wheel
                _buildPaperNumberRow(cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 14),
                // Date picker
                _buildDateRow(context, cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 14),
                // Out-of-range warning
                if (_isOutOfRange)
                  _buildOutOfRangeWarning(
                    context,
                    cs: cs,
                    isDark: isDark,
                    indigo: indigo,
                  ),
                if (_isOutOfRange) const SizedBox(height: 14),
                // Time picker
                _buildTimeRow(cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 14),
                // Time allowed (optional)
                _buildTimeAllowedRow(cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 14),
                // Custom instructions (optional)
                _buildInstructionsRow(cs: cs, isDark: isDark, indigo: indigo),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // ── Footer ──────────────────────────────────────────────────────────
        Divider(height: 1, thickness: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
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
                onTap: (_selectedSubject == null || _saving) ? null : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Subject row ───────────────────────────────────────────────────────────

  Widget _buildSubjectRow(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    final hasSubject = _selectedSubject != null;
    final label = hasSubject
        ? (widget.subjectNames[_selectedSubject!] ??
              'Subject $_selectedSubject')
        : (_loadingSubjects ? 'Loading…' : 'Select subject…');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Subject',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: _subjectTriggerKey,
          onTap: (_loadingSubjects || _subjects.isEmpty)
              ? null
              : () => _toggleSubjectOverlay(context, cs, isDark, indigo),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: hasSubject
                  ? indigo.withValues(alpha: isDark ? 0.12 : 0.07)
                  : (isDark
                        ? const Color(0xFF1E2C3C)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasSubject
                    ? indigo.withValues(alpha: 0.55)
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 16,
                  color: hasSubject
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasSubject
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: hasSubject ? indigo : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (!_loadingSubjects && _subjects.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No subjects assigned to this class yet.',
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
      ],
    );
  }

  // ── Paper number row ──────────────────────────────────────────────────────

  Widget _buildPaperNumberRow({
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2C3C)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _multiPaper,
              onChanged: (v) {
                setState(() {
                  _multiPaper = v ?? false;
                  if (!_multiPaper) _paperNumber = 1;
                });
              },
              visualDensity: VisualDensity.compact,
              activeColor: indigo,
              side: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.6),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Multiple papers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          // Paper number buttons (only when _multiPaper)
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _multiPaper
                ? _PaperNumberWheel(
                    controller: _paperNumCtrl,
                    selected: _paperNumber,
                    cs: cs,
                    isDark: isDark,
                    indigo: indigo,
                    onChanged: (n) => setState(() => _paperNumber = n),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Date row ──────────────────────────────────────────────────────────────

  Widget _buildDateRow(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    final groupStart = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.start * 86400 * 1000,
    );
    final groupEnd = DateTime.fromMillisecondsSinceEpoch(
      widget.examGroup.end * 86400 * 1000,
    );

    final d = _selectedDate;
    final dateLabel =
        '${kDayNames[d.weekday - 1]}, ${d.day} ${kMonthNames[d.month - 1]} ${d.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trigger
        GestureDetector(
          onTap: () => setState(() => _calendarOpen = !_calendarOpen),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _calendarOpen
                  ? indigo.withValues(alpha: isDark ? 0.14 : 0.08)
                  : (isDark
                        ? const Color(0xFF1E2C3C)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _calendarOpen
                    ? indigo.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                width: 1,
              ),
              boxShadow: _calendarOpen
                  ? [
                      BoxShadow(
                        color: indigo.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: _calendarOpen
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _calendarOpen ? indigo : cs.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _calendarOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _calendarOpen
                        ? indigo
                        : cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Inline calendar
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _calendarOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _PaperSingleCalendar(
              selected: _selectedDate,
              groupStart: groupStart,
              groupEnd: groupEnd,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onSelected: (d) {
                setState(() {
                  _selectedDate = d;
                  _calendarOpen = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Out-of-range warning ──────────────────────────────────────────────────

  Widget _buildOutOfRangeWarning(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    const amber = Color(0xFFFFA726);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: amber.withValues(alpha: isDark ? 0.35 : 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: amber.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Date is outside the exam period.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? amber.withValues(alpha: 0.8)
                    : const Color(0xFFB35A00),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _extendExamRange(context),
            child: Text(
              'Extend Period',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Time allowed row ──────────────────────────────────────────────────────

  Widget _buildTimeAllowedRow({
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Time allowed (minutes)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          initialValue: _timeAllowedMinutes?.toString(),
          decoration: InputDecoration(
            hintText: 'e.g. 90',
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            isDense: true,
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E2C3C)
                : cs.surfaceContainerHighest.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: indigo.withValues(alpha: 0.7)),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            setState(
              () => _timeAllowedMinutes = (parsed != null && parsed > 0)
                  ? parsed
                  : null,
            );
          },
        ),
        if (_timeAllowedMinutes != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '= ${_formatMinutes(_timeAllowedMinutes!)}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: indigo.withValues(alpha: 0.85),
              ),
            ),
          ),
      ],
    );
  }

  // ── Instructions row ──────────────────────────────────────────────────────

  Widget _buildInstructionsRow({
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Instructions (optional)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _instructionsCtrl,
          maxLines: 5,
          minLines: 2,
          decoration: InputDecoration(
            hintText: 'Leave blank to use default instructions',
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E2C3C)
                : cs.surfaceContainerHighest.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: indigo.withValues(alpha: 0.7)),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  // ── Time row ──────────────────────────────────────────────────────────────

  Widget _buildTimeRow({
    required ColorScheme cs,
    required bool isDark,
    required Color indigo,
  }) {
    final timeLabel = _fmtTimeTrigger();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trigger chip
        GestureDetector(
          onTap: () => setState(() => _timeOpen = !_timeOpen),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _timeOpen
                  ? indigo.withValues(alpha: isDark ? 0.14 : 0.08)
                  : (isDark
                        ? const Color(0xFF1E2C3C)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _timeOpen
                    ? indigo.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                width: 1,
              ),
              boxShadow: _timeOpen
                  ? [
                      BoxShadow(
                        color: indigo.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: _timeOpen
                      ? indigo
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: _timeOpen ? indigo : cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _timeOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _timeOpen
                        ? indigo
                        : cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Inline time configurator
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _timeOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _InlineTimeConfigurator(
              startHour: _startHour,
              startMinIndex: _startMinIndex,
              durationMinutes: _durationMinutes,
              startHourCtrl: _startHourCtrl,
              startMinCtrl: _startMinCtrl,
              durHourCtrl: _durHourCtrl,
              durMinCtrl: _durMinCtrl,
              cs: cs,
              isDark: isDark,
              indigo: indigo,
              onStartChanged: (h, mIdx) {
                setState(() {
                  _startHour = h;
                  _startMinIndex = mIdx;
                });
              },
              onDurationChanged: (minutes) {
                setState(() => _durationMinutes = minutes);
              },
              onPreset: _applyDurationPreset,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubjectMenuOverlay — macOS-style inline overlay for subject selection
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectMenuOverlay extends StatefulWidget {
  const _SubjectMenuOverlay({
    required this.subjects,
    required this.selected,
    required this.subjectNames,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
    this.teacherNames = const {},
  });

  final List<SubjectTeacher> subjects;
  final int? selected;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onSelected;

  /// Optional map of userId → display name for showing teacher names in items.
  final Map<String, String> teacherNames;

  @override
  State<_SubjectMenuOverlay> createState() => _SubjectMenuOverlayState();
}

class _SubjectMenuOverlayState extends State<_SubjectMenuOverlay>
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
              children: widget.subjects.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final isSelected = s.subject == widget.selected;
                final isLast = idx == widget.subjects.length - 1;
                final label =
                    widget.subjectNames[s.subject] ?? 'Subject ${s.subject}';
                final teacherDisplay = widget.teacherNames[s.teacher] ?? '';
                final hasTeacher = teacherDisplay.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: InkWell(
                    splashFactory: NoSplash.splashFactory,
                    borderRadius: BorderRadius.circular(4),
                    hoverColor: cs.primary.withValues(alpha: 0.06),
                    onTap: () => widget.onSelected(s.subject),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: isLast
                          ? null
                          : BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: isDark ? 0.15 : 0.25,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 14,
                            color: isSelected
                                ? indigo
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (hasTeacher)
                                  Text(
                                    teacherDisplay, // non-empty guaranteed by hasTeacher guard
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 14, color: indigo),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PaperNumberWheel — compact 1/2/3 wheel for paper number selection
// ─────────────────────────────────────────────────────────────────────────────

class _PaperNumberWheel extends StatelessWidget {
  const _PaperNumberWheel({
    required this.controller,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onChanged,
  });

  // controller kept for API compatibility but no longer used by ListWheelScrollView
  final FixedExtentScrollController controller;
  final int selected;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [1, 2, 3].map((n) {
        final isSelected = n == selected;
        return GestureDetector(
          onTap: () => onChanged(n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? null
                  : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : cs.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PaperSingleCalendar — inline single-date calendar
// ─────────────────────────────────────────────────────────────────────────────

class _PaperSingleCalendar extends StatefulWidget {
  const _PaperSingleCalendar({
    required this.selected,
    required this.groupStart,
    required this.groupEnd,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onSelected,
  });

  final DateTime selected;
  final DateTime groupStart;
  final DateTime groupEnd;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_PaperSingleCalendar> createState() => _PaperSingleCalendarState();
}

class _PaperSingleCalendarState extends State<_PaperSingleCalendar> {
  late DateTime _month; // first day of visible month

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.selected.year, widget.selected.month);
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inExamRange(DateTime d) {
    final gs = DateTime(
      widget.groupStart.year,
      widget.groupStart.month,
      widget.groupStart.day,
    );
    final ge = DateTime(
      widget.groupEnd.year,
      widget.groupEnd.month,
      widget.groupEnd.day,
    );
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(gs) && !day.isAfter(ge);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final indigo = widget.indigo;

    final firstWeekday = _month.weekday % 7; // 0=Sun
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2536)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: _prevMonth,
                style: IconButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: cs.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  '${kMonthNamesFull[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: _nextMonth,
                style: IconButton.styleFrom(
                  splashFactory: NoSplash.splashFactory,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Weekday headers
          Row(
            children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          // Day grid
          for (int r = 0; r < rows; r++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = r * 7 + col;
                final dayNum = cellIndex - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 32));
                }
                final day = DateTime(_month.year, _month.month, dayNum);
                final isSelected = _sameDay(day, widget.selected);
                final inRange = _inExamRange(day);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onSelected(day),
                    child: Container(
                      height: 32,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? indigo
                            : (inRange
                                  ? indigo.withValues(
                                      alpha: isDark ? 0.14 : 0.08,
                                    )
                                  : Colors.transparent),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : (inRange
                                      ? indigo
                                      : cs.onSurface.withValues(alpha: 0.85)),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InlineTimeConfigurator — two-column wheel time picker with presets
// ─────────────────────────────────────────────────────────────────────────────

class _InlineTimeConfigurator extends StatefulWidget {
  const _InlineTimeConfigurator({
    required this.startHour,
    required this.startMinIndex,
    required this.durationMinutes,
    required this.startHourCtrl,
    required this.startMinCtrl,
    required this.durHourCtrl,
    required this.durMinCtrl,
    required this.cs,
    required this.isDark,
    required this.indigo,
    required this.onStartChanged,
    required this.onDurationChanged,
    required this.onPreset,
  });

  final int startHour;
  final int startMinIndex;
  final int durationMinutes;
  final FixedExtentScrollController startHourCtrl;
  final FixedExtentScrollController startMinCtrl;
  final FixedExtentScrollController durHourCtrl;
  final FixedExtentScrollController durMinCtrl;
  final ColorScheme cs;
  final bool isDark;
  final Color indigo;
  final void Function(int hour, int minIndex) onStartChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onPreset;

  @override
  State<_InlineTimeConfigurator> createState() =>
      _InlineTimeConfiguratorState();
}

class _InlineTimeConfiguratorState extends State<_InlineTimeConfigurator> {
  static const _durMinValues = [0, 15, 30, 45];

  late int _startHour;
  late int _startMinIndex;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();
    _startHour = widget.startHour;
    _startMinIndex = widget.startMinIndex;
    _durationMinutes = widget.durationMinutes;
  }

  int get _durHour => _durationMinutes ~/ 60;
  int get _durMinIdx =>
      _durMinValues.indexOf(_durationMinutes % 60).clamp(0, 3);

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
              // Start time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Time',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CompactWheelColumn(
                          controller: widget.startHourCtrl,
                          itemCount: 24,
                          labelBuilder: (i) => i.toString().padLeft(2, '0'),
                          selectedIndex: _startHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            _startHour = i;
                            widget.onStartChanged(_startHour, _startMinIndex);
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
                        _CompactWheelColumn(
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
                            widget.onStartChanged(_startHour, _startMinIndex);
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
              // Duration
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
                        _CompactWheelColumn(
                          controller: widget.durHourCtrl,
                          itemCount: 12,
                          labelBuilder: (i) => '${i}h',
                          selectedIndex: _durHour,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            final newDur = i * 60 + _durMinValues[_durMinIdx];
                            _durationMinutes = newDur;
                            widget.onDurationChanged(newDur);
                          },
                        ),
                        const SizedBox(width: 4),
                        _CompactWheelColumn(
                          controller: widget.durMinCtrl,
                          itemCount: _durMinValues.length,
                          labelBuilder: (i) => '${_durMinValues[i]}m',
                          selectedIndex: _durMinIdx,
                          cs: cs,
                          isDark: isDark,
                          indigo: indigo,
                          onChanged: (i) {
                            final newDur = _durHour * 60 + _durMinValues[i];
                            _durationMinutes = newDur;
                            widget.onDurationChanged(newDur);
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
                  final isSelected = _durationMinutes == p.$2;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _durationMinutes = p.$2);
                      widget.onPreset(p.$2);
                    },
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
// _CompactWheelColumn — 32px itemExtent wheel, 1.5 diameterRatio
// ─────────────────────────────────────────────────────────────────────────────

class _CompactWheelColumn extends StatelessWidget {
  const _CompactWheelColumn({
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
    return Container(
      width: 40,
      height: 80,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF18222E)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.25),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight band
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: indigo.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 32,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (ctx, i) {
                if (i < 0 || i >= itemCount) return null;
                final isSelected = i == selectedIndex;
                return Center(
                  child: Text(
                    labelBuilder(i),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? indigo : cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GradeConfirmButton — confirm/save button with loading state
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
    return AnimatedSaveButton(
      isSaving: saving,
      isDirty: onTap != null,
      onSave: onTap,
    );
  }
}
