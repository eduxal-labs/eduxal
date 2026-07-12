import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import 'package:drift/drift.dart' show Value;

import '../../../../models/membership.dart';
import '../../../../models/result.dart';
import '../../../../models/school_config.dart';
import '../../../../services/paper_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/date_range_picker.dart';
import '../../../widgets/term_buttons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wizard-local enumerations and data classes
// ─────────────────────────────────────────────────────────────────────────────

enum _EventType {
  exam('Exam'),
  mock('Mock'),
  holidayRevision('Holiday Revision');

  const _EventType(this.label);
  final String label;
}

class _EventDraft {
  String name;
  _EventType type;
  int term;
  int year;
  DateTime? startDate;
  DateTime? endDate;
  bool generateAIQuestions;

  _EventDraft({
    required this.name,
    required this.type,
    required this.term,
    required this.year,
    this.generateAIQuestions = true,
  });
}

class _PaperScheduleRow {
  int? subjectId;
  String? subjectName;
  int? grade;
  int? stream; // null = all streams
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int? durationMinutes; // auto-computed from start/end
  String? invigilatorId;
  String? invigilatorName;
  int? paperNumber; // null = single paper, 1, 2, 3 for Paper 1, 2, 3

  _PaperScheduleRow({this.paperNumber});
}

// ─────────────────────────────────────────────────────────────────────────────
// ExamCreationPage — 5-step PageView wizard
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page wizard for creating exam events. Five steps:
///   1. Event details (name, type, term, year, date range)
///   2. Schedule papers (papers per grade/stream with timetable preview)
///   3. Syllabus coverage (topic selection per grade)
///   4. Review (timetable preview + paper summaries)
///   5. Confirm & activate (calls CreateEvent + SchedulePaper + ConfirmExamCoverage RPCs)
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

  /// Pre-select this grade in step 2.
  final int? preselectedGrade;

  /// Pre-select this stream within [preselectedGrade]. Ignored if null.
  final int? preselectedStream;

  @override
  State<ExamCreationPage> createState() => _ExamCreationPageState();
}

class _ExamCreationPageState extends State<ExamCreationPage> {
  // ── Wizard state ──────────────────────────────────────────────────────────
  int _step = 1;
  final _pageCtrl = PageController();

  // ── Step 1 state ──────────────────────────────────────────────────────────
  final _step1FormKey = GlobalKey<FormState>();
  late _EventDraft _draft;

  // ── Step 2 state ──────────────────────────────────────────────────────────
  final List<_PaperScheduleRow> _papers = [];
  Map<CurriculumType, List<Subject>> _subjectsByCurriculum = {};
  bool _subjectsLoaded = false;
  List<({TeachersData teacher, UsersData user})> _teachers = [];
  bool _teachersLoaded = false;
  final Map<int, String> _rowErrors = {};

  late final CatalogDao _catalogDao;
  late final MembersDao _membersDao;
  late final ExamsGradesDao _examsGradesDao;

  // ── Step 3 state ──────────────────────────────────────────────────────────
  Map<(int, int), List<int>> _confirmedCoverage = {};
  bool _step3CoverageLoaded = false;

  // ── Steps 4–5 state ───────────────────────────────────────────────────────
  bool _activating = false;
  String? _activationError;

  @override
  void initState() {
    super.initState();
    _catalogDao = CatalogDao(db);
    _membersDao = MembersDao(db);
    _examsGradesDao = ExamsGradesDao(db);

    _draft = _EventDraft(
      name: '',
      type: _EventType.exam,
      term: widget.term,
      year: widget.year,
    );

    // Pre-seed a paper row if navigated from a grade detail page.
    if (widget.preselectedGrade != null) {
      _papers.add(
        _PaperScheduleRow()
          ..grade = widget.preselectedGrade
          ..stream = widget.preselectedStream,
      );
    }

    _loadTeachers();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadTeachers() async {
    try {
      final list = await _membersDao.watchTeachers(widget.schoolId).first;
      if (!mounted) return;
      final results = <({TeachersData teacher, UsersData user})>[];
      for (final t in list) {
        final u = await _membersDao.findUserById(t.user);
        if (!mounted) return;
        if (u != null) results.add((teacher: t, user: u));
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

  Future<void> _loadSubjects() async {
    if (_subjectsLoaded) return;
    try {
      final all = await _catalogDao.getSubjects();
      final map = <CurriculumType, List<Subject>>{};
      for (final s in all) {
        map.putIfAbsent(s.curriculum, () => []).add(s);
      }
      for (final list in map.values) {
        list.sort((a, b) => a.name.compareTo(b.name));
      }
      if (mounted) {
        setState(() {
          _subjectsByCurriculum = map;
          _subjectsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _subjectsLoaded = true);
    }
  }

  // ── Config helpers ─────────────────────────────────────────────────────────

  CurriculumType? _curriculumForGrade(int grade) {
    for (final c in widget.config.curricula) {
      if (c.grades.any((g) => g.grade == grade)) return c.type;
    }
    return null;
  }

  List<Subject> _subjectsForGrade(int? grade) {
    if (grade == null) return [];
    final curr = _curriculumForGrade(grade);
    if (curr == null) return [];
    return _subjectsByCurriculum[curr] ?? [];
  }

  List<GradeStream> _streamsForGrade(int? grade) {
    if (grade == null) return [];
    for (final c in widget.config.curricula) {
      for (final gc in c.grades) {
        if (gc.grade == grade) return gc.streams;
      }
    }
    return [];
  }

  String _gradeLabel(int grade) =>
      kCbcGradeLabels[grade] ??
      kEightFourFourGradeLabels[grade] ??
      'Grade $grade';

  List<GradeConfig> get _allGrades => [
    for (final c in widget.config.curricula)
      for (final g in c.grades) g,
  ];

  int get _totalSteps => _draft.generateAIQuestions ? 5 : 3;

  int get _displayStep {
    if (_draft.generateAIQuestions) return _step;
    if (_step == 1) return 1;
    if (_step == 2) return 2;
    return 3;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _back() {
    if (_step == 1) {
      Navigator.of(context).pop();
      return;
    }
    final prevStep = (!_draft.generateAIQuestions && _step == 5) ? 2 : _step - 1;
    setState(() => _step = prevStep);
    _pageCtrl.animateToPage(
      _step - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_step == 1) {
      if (!(_step1FormKey.currentState?.validate() ?? false)) return;
      if (_draft.startDate == null) {
        _showSnack('Please pick a start date.');
        return;
      }
      if (_draft.endDate == null) {
        _showSnack('Please pick an end date.');
        return;
      }
      _loadSubjects(); // pre-warm subjects for step 2
    }

    if (_step == 2 && !_validatePapers()) return;

    if (_step == 3) {
      if (!_step3CoverageLoaded) {
        _showSnack('Syllabus coverage is still loading. Please wait.');
        return;
      }
      if (_confirmedCoverage.isNotEmpty &&
          _confirmedCoverage.values.any((v) => v.isEmpty)) {
        _showSnack(
          'Select at least one topic for every subject–grade combination.',
        );
        return;
      }
    }

    if (_step >= 5) {
      _activate();
      return;
    }

    final nextStep = (!_draft.generateAIQuestions && _step == 2) ? 5 : _step + 1;
    setState(() => _step = nextStep);
    _pageCtrl.animateToPage(
      _step - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  bool _validatePapers() {
    _rowErrors.clear();
    if (_papers.isEmpty) {
      // Scheduling papers during creation setup is fully optional.
      return true;
    }
    for (int i = 0; i < _papers.length; i++) {
      final row = _papers[i];
      final missing = <String>[];
      if (row.subjectId == null) missing.add('subject');
      if (row.grade == null) missing.add('grade');
      if (row.date == null) missing.add('date');
      if (row.startTime == null) missing.add('start time');
      if (row.endTime == null) missing.add('end time');
      if (missing.isNotEmpty) {
        _rowErrors[i] = 'Missing: ${missing.join(', ')}';
      } else {
        final s = row.startTime!.hour * 60 + row.startTime!.minute;
        final e = row.endTime!.hour * 60 + row.endTime!.minute;
        if (e <= s) _rowErrors[i] = 'End time must be after start time';
      }
    }
    if (_rowErrors.isNotEmpty) {
      setState(() {});
      _showSnack('Fix the highlighted papers before continuing.');
      return false;
    }
    return true;
  }

  Future<void> _activate() async {
    if (_activating) return;
    setState(() {
      _activating = true;
      _activationError = null;
    });

    // 1. Create the event.
    final typeInt = _draft.type.index; // exam=0, mock=1, holidayRevision=2
    final eventResult = await paperService.createEvent(
      school: widget.schoolId,
      name: _draft.name,
      type: typeInt,
      term: _draft.term,
      year: _draft.year,
      startDate: _draft.startDate!,
      endDate: _draft.endDate!,
      accessToken: accessToken,
    );
    if (!mounted) return;

    final String eventId;
    switch (eventResult) {
      case Ok(:final value):
        eventId = value;
      case Err(:final error):
        setState(() {
          _activating = false;
          _activationError = 'Activation failed: ${error.message}';
        });
        return;
    }

    if (!_draft.generateAIQuestions) {
      final accountId = cache.currentUser?.user.id;
      if (accountId == null) {
        setState(() {
          _activating = false;
          _activationError = 'Activation failed: User is not authenticated.';
        });
        return;
      }

      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      try {
        for (int i = 0; i < _papers.length; i++) {
          final row = _papers[i];
          final startSecs = row.date!.add(Duration(hours: row.startTime!.hour, minutes: row.startTime!.minute)).millisecondsSinceEpoch ~/ 1000;
          final endSecs = row.date!.add(Duration(hours: row.endTime!.hour, minutes: row.endTime!.minute)).millisecondsSinceEpoch ~/ 1000;
          final invigilatorId = row.invigilatorId ?? accountId;

          await _examsGradesDao.createPaper(
            paper: PapersCompanion(
              school: Value(widget.schoolId),
              exam: Value(eventId),
              subject: Value(row.subjectId!),
              paper: Value(row.paperNumber),
              invigilator: Value(invigilatorId),
              start: Value(BigInt.from(startSecs)),
              end: Value(BigInt.from(endSecs)),
              grade: Value(row.grade!),
              stream: Value(row.stream),
              status: const Value(PaperStatus.pending),
              created: Value(now),
              updated: Value(now),
            ),
            accountId: accountId,
            timeAllowedMinutes: row.durationMinutes,
            customInstructions: null,
          );
        }
      } catch (e) {
        final errorMsg = e.toString();
        String userFriendlyError;
        if (errorMsg.contains('paper schedule falls outside the exam date range') ||
            errorMsg.contains('1811')) {
          userFriendlyError = 'Some papers have been scheduled on dates that fall outside your selected exam start and end dates.\n\n'
              '• Solution: Go back to Step 1 and extend your Exam Date Range, or reschedule those papers in Step 2 to fall within that range.';
        } else {
          userFriendlyError = 'Paper creation failed: $e';
        }
        setState(() {
          _activating = false;
          _activationError = userFriendlyError;
        });
        return;
      }

      // Success for manual exam.
      setState(() => _activating = false);
      _showSnack('Exam activated — papers created successfully');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // 2. Schedule each paper.
    final scheduleIds = <int, String>{}; // paper index → scheduleId
    for (int i = 0; i < _papers.length; i++) {
      final row = _papers[i];
      final startMinutes = row.startTime!.hour * 60 + row.startTime!.minute;
      final endMinutes = row.endTime!.hour * 60 + row.endTime!.minute;
      final schedResult = await paperService.schedulePaper(
        eventId: eventId,
        subject: row.subjectId!,
        grade: row.grade!,
        stream: row.stream ?? 0,
        date: row.date!,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        invigilatorId: row.invigilatorId,
        accessToken: accessToken,
      );
      if (!mounted) return;
      switch (schedResult) {
        case Ok(:final value):
          scheduleIds[i] = value;
        case Err(:final error):
          final errMsg = error.message;
          String userFriendlyError;
          if (errMsg != null && errMsg.contains('paper schedule falls outside the exam date range')) {
            userFriendlyError = 'Some papers have been scheduled on dates that fall outside your selected exam start and end dates.\n\n'
                '• Solution: Go back to Step 1 and extend your Exam Date Range, or reschedule those papers in Step 2 to fall within that range.';
          } else {
            userFriendlyError = 'Activation failed: $errMsg';
          }
          setState(() {
            _activating = false;
            _activationError = userFriendlyError;
          });
          return;
      }
    }

    // 3. Confirm topic coverage for each (subjectId, grade) pair.
    for (final coverageEntry in _confirmedCoverage.entries) {
      final (subjectId, grade) = coverageEntry.key;
      final topicIds = coverageEntry.value;
      if (topicIds.isEmpty) continue;

      // Find all paper indices that match this (subject, grade).
      for (int i = 0; i < _papers.length; i++) {
        final row = _papers[i];
        if (row.subjectId != subjectId || row.grade != grade) continue;
        final scheduleId = scheduleIds[i];
        if (scheduleId == null) continue;
        await paperService.confirmExamCoverage(
          scheduleId: scheduleId,
          topicIds: topicIds,
          accessToken: accessToken,
        );
        if (!mounted) return;
      }
    }

    // 4. Success.
    setState(() => _activating = false);
    _showSnack('Exam activated — papers will be auto-generated');
    if (mounted) Navigator.of(context).pop();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w400)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showAutomatedSetupDialog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AutomatedSetupSheet(
        allGrades: _allGrades,
        gradeLabel: _gradeLabel,
        subjectsForGrade: _subjectsForGrade,
        examStartDate: _draft.startDate,
        existingPapersCount: _papers.length,
        onGenerated: (papers) {
          setState(() {
            _papers
              ..clear()
              ..addAll(papers);
            _rowErrors.clear();

            if (papers.isNotEmpty) {
              DateTime? maxDate;
              for (final p in papers) {
                if (p.date != null) {
                  if (maxDate == null || p.date!.isAfter(maxDate)) {
                    maxDate = p.date;
                  }
                }
              }
              if (maxDate != null && (_draft.endDate == null || maxDate.isAfter(_draft.endDate!))) {
                _draft.endDate = maxDate;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Successfully scheduled ${papers.length} papers! '
                      'The exam end date was automatically extended to ${_fmtDate(maxDate)} to cover all papers.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully scheduled ${papers.length} papers!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.modalBg(isDark, cs),
      appBar: AppBar(
        backgroundColor: AppTheme.modalBg(isDark, cs),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: _back,
          tooltip: _step == 1 ? 'Cancel' : 'Back',
        ),
        title: Text(
          'Create Exam — Step $_displayStep of $_totalSteps',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _displayStep / _totalSteps,
            minHeight: 2,
            backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1 — Event Details
                _EventDetailsStep(
                  formKey: _step1FormKey,
                  draft: _draft,
                  onDraftChanged: () => setState(() {}),
                ),
                // Step 2 — Schedule Papers
                _SchedulePapersStep(
                  papers: _papers,
                  allGrades: _allGrades,
                  gradeLabel: _gradeLabel,
                  streamsForGrade: _streamsForGrade,
                  subjectsForGrade: _subjectsForGrade,
                  teachers: _teachers,
                  teachersLoaded: _teachersLoaded,
                  rowErrors: Map.from(_rowErrors),
                  examStartDate: _draft.startDate,
                  examEndDate: _draft.endDate,
                  onAddPaper: () =>
                      setState(() => _papers.add(_PaperScheduleRow())),
                  onRemovePaper: (i) => setState(() {
                    _papers.removeAt(i);
                    final shifted = <int, String>{};
                    for (final e in _rowErrors.entries) {
                      if (e.key < i) shifted[e.key] = e.value;
                      if (e.key > i) shifted[e.key - 1] = e.value;
                    }
                    _rowErrors
                      ..clear()
                      ..addAll(shifted);
                  }),
                  onPaperChanged: (i) => setState(() => _rowErrors.remove(i)),
                  onAutomateSetup: () => _showAutomatedSetupDialog(context),
                ),
                // Step 3 — Syllabus Coverage
                _SyllabusCoverageStep(
                  papers: _papers,
                  schoolId: widget.schoolId,
                  catalogDao: _catalogDao,
                  gradeLabel: _gradeLabel,
                  config: widget.config,
                  onCoverageChanged: (coverage) {
                    if (mounted) {
                      setState(() {
                        _confirmedCoverage = coverage;
                        _step3CoverageLoaded = true;
                      });
                    }
                  },
                ),
                // Step 4 — Review
                _ReviewStep(
                  draft: _draft,
                  papers: _papers,
                  confirmedCoverage: _confirmedCoverage,
                  gradeLabel: _gradeLabel,
                ),
                // Step 5 — Confirm
                _ConfirmStep(
                  papers: _papers,
                  activating: _activating,
                  error: _activationError,
                  onActivate: () {
                    _activate();
                  },
                ),
              ],
            ),
          ),
          _BottomNavRow(
            onBack: _back,
            onNext: _next,
            backLabel: _step == 1 ? 'Cancel' : 'Back',
            nextLabel: _step == 5 ? 'Activate' : 'Next',
          ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Event Details
// ─────────────────────────────────────────────────────────────────────────────

class _EventDetailsStep extends StatefulWidget {
  const _EventDetailsStep({
    required this.formKey,
    required this.draft,
    required this.onDraftChanged,
  });

  final GlobalKey<FormState> formKey;
  final _EventDraft draft;
  final VoidCallback onDraftChanged;

  @override
  State<_EventDetailsStep> createState() => _EventDetailsStepState();
}

class _EventDetailsStepState extends State<_EventDetailsStep> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.draft.name);
    _yearCtrl = TextEditingController(text: widget.draft.year.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  bool _calendarOpen = false;

  void _notify() => widget.onDraftChanged();

  void _toggleCalendar() {
    setState(() => _calendarOpen = !_calendarOpen);
  }

  void _onDayTapped(DateTime day) {
    final d = widget.draft;
    final start = d.startDate;
    final end = d.endDate;

    if (start == null) {
      // First tap — set start date.
      d.startDate = day;
      _notify();
    } else if (end == null) {
      if (day.isAfter(start)) {
        // Second tap — set end date.
        d.endDate = day;
        _notify();
        setState(() => _calendarOpen = false);
      } else if (day.isBefore(start)) {
        // Reset start.
        d.startDate = day;
        _notify();
      }
    } else {
      // Both already set — reset and start over.
      d.startDate = day;
      d.endDate = null;
      _notify();
    }
  }

  InputDecoration _inputDec(ColorScheme cs, bool isDark, String? hint) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      borderSide: BorderSide(
        color: AppTheme.borderColor(isDark, cs),
        width: 0.8,
      ),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.4),
        fontWeight: FontWeight.w300,
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppTheme.nestedBg(isDark, cs),
      border: baseBorder,
      enabledBorder: baseBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.error, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final d = widget.draft;

    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // ── Name ──────────────────────────────────────────────────────────
          _fieldLabel('Exam Name'),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDec(
              cs,
              isDark,
              'e.g. End of Term 1 Examinations',
            ),
            style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            onChanged: (v) {
              d.name = v;
              _notify();
            },
          ),
          const SizedBox(height: 16),

          // ── Type ──────────────────────────────────────────────────────────
          _fieldLabel('Type'),
          DropdownButtonFormField<_EventType>(
            initialValue: d.type,
            decoration: _inputDec(cs, isDark, null),
            dropdownColor: AppTheme.overlayBg(isDark, cs),
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            items: _EventType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (t) {
              if (t == null) return;
              d.type = t;
              _notify();
            },
          ),
          const SizedBox(height: 16),

          // ── Term (read-only, inherited from current school term) ─────────
          _fieldLabel('Term'),
          TermButton(
            label: 'Term ${d.term}',
            isSelected: true,
            isDark: isDark,
            cs: cs,
            indigo: isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo,
            enabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 4),
          Text(
            'Using the current school term. Change it from the school page.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 16),

          // ── Year ──────────────────────────────────────────────────────────
          _fieldLabel('Year'),
          TextFormField(
            controller: _yearCtrl,
            decoration: _inputDec(cs, isDark, 'e.g. 2025'),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Year is required';
              final y = int.tryParse(v.trim());
              if (y == null || y < 2000 || y > 2100) {
                return 'Enter a valid year';
              }
              return null;
            },
            onChanged: (v) {
              final y = int.tryParse(v.trim());
              if (y != null) {
                d.year = y;
                _notify();
              }
            },
          ),
          const SizedBox(height: 16),

          // ── Date Range ────────────────────────────────────────────────────
          _fieldLabel('Date Range'),
          DateRangeTrigger(
            startDate: d.startDate,
            endDate: d.endDate,
            isOpen: _calendarOpen,
            hasError: false,
            enabled: true,
            isDark: isDark,
            cs: cs,
            indigo: isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo,
            onTap: _toggleCalendar,
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DateRangeCalendar(
                startDate: d.startDate,
                endDate: d.endDate,
                onDayTapped: _onDayTapped,
                isDark: isDark,
                cs: cs,
                indigo: isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo,
              ),
            ),
            crossFadeState: _calendarOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
          if (_calendarOpen && d.startDate != null && d.endDate == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Now tap the end date',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: (isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo)
                      .withValues(alpha: 0.70),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ── AI Generation Option ──────────────────────────────────────────
          _fieldLabel('Question Source'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.nestedBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: AppTheme.borderColor(isDark, cs),
                width: 0.8,
              ),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: const Text(
                'AI Question Generator',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Let AI generate papers based on syllabus topic coverage. Turn off to provide custom questions or enter grades manually.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ),
              value: d.generateAIQuestions,
              activeColor: isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo,
              onChanged: (val) {
                setState(() {
                  d.generateAIQuestions = val;
                });
                _notify();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Schedule Papers
// ─────────────────────────────────────────────────────────────────────────────

class _SchedulePapersStep extends StatelessWidget {
  const _SchedulePapersStep({
    required this.papers,
    required this.allGrades,
    required this.gradeLabel,
    required this.streamsForGrade,
    required this.subjectsForGrade,
    required this.teachers,
    required this.teachersLoaded,
    required this.rowErrors,
    this.examStartDate,
    this.examEndDate,
    required this.onAddPaper,
    required this.onRemovePaper,
    required this.onPaperChanged,
    required this.onAutomateSetup,
  });

  final List<_PaperScheduleRow> papers;
  final List<GradeConfig> allGrades;
  final String Function(int) gradeLabel;
  final List<GradeStream> Function(int?) streamsForGrade;
  final List<Subject> Function(int?) subjectsForGrade;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final Map<int, String> rowErrors;
  final DateTime? examStartDate;
  final DateTime? examEndDate;
  final VoidCallback onAddPaper;
  final void Function(int) onRemovePaper;
  final void Function(int) onPaperChanged;
  final VoidCallback onAutomateSetup;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        // Premium Auto Setup banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tedious to add papers manually?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Let the system auto-generate all papers with customizable settings.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onAutomateSetup,
                    icon: const Icon(Icons.flash_on, size: 14),
                    label: const Text('Auto Setup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Empty state
        if (papers.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
              child: Column(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 42,
                    color: cs.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No papers scheduled yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Add Paper" below to schedule a paper, or tap "Next" to continue without scheduling papers (you can add them later from the dashboard).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Paper cards
        SliverPadding(
          padding: const EdgeInsets.only(top: 12),
          sliver: SliverList.separated(
            itemCount: papers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) => _PaperScheduleCard(
              index: i,
              row: papers[i],
              allGrades: allGrades,
              gradeLabel: gradeLabel,
              streamsForGrade: streamsForGrade,
              subjectsForGrade: subjectsForGrade,
              teachers: teachers,
              teachersLoaded: teachersLoaded,
              errorMessage: rowErrors[i],
              examStartDate: examStartDate,
              examEndDate: examEndDate,
              onRemove: () => onRemovePaper(i),
              onChanged: () => onPaperChanged(i),
            ),
          ),
        ),

        // Add Paper button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextButton.icon(
              onPressed: onAddPaper,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Paper',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
        ),

        // Timetable preview
        if (papers.isNotEmpty)
          SliverToBoxAdapter(
            child: _TimetablePreview(
              papers: papers,
              gradeLabel: gradeLabel,
              cs: cs,
              isDark: isDark,
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper Schedule Card
// ─────────────────────────────────────────────────────────────────────────────

class _PaperScheduleCard extends StatelessWidget {
  const _PaperScheduleCard({
    required this.index,
    required this.row,
    required this.allGrades,
    required this.gradeLabel,
    required this.streamsForGrade,
    required this.subjectsForGrade,
    required this.teachers,
    required this.teachersLoaded,
    this.errorMessage,
    this.examStartDate,
    this.examEndDate,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _PaperScheduleRow row;
  final List<GradeConfig> allGrades;
  final String Function(int) gradeLabel;
  final List<GradeStream> Function(int?) streamsForGrade;
  final List<Subject> Function(int?) subjectsForGrade;
  final List<({TeachersData teacher, UsersData user})> teachers;
  final bool teachersLoaded;
  final String? errorMessage;
  final DateTime? examStartDate;
  final DateTime? examEndDate;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  // ── Mutation helpers ──────────────────────────────────────────────────────

  void _mutate(void Function() fn) {
    fn();
    onChanged();
  }

  Future<void> _pickDate(BuildContext context) async {
    final first = examStartDate ?? DateTime(DateTime.now().year);
    final last = examEndDate ?? DateTime(DateTime.now().year + 1);
    final initial =
        (row.date != null &&
            !row.date!.isBefore(first) &&
            !row.date!.isAfter(last))
        ? row.date!
        : first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !context.mounted) return;
    _mutate(() => row.date = picked);
  }

  Future<void> _pickStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: row.startTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null || !context.mounted) return;
    _mutate(() {
      row.startTime = picked;
      _recomputeDuration();
    });
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: row.endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null || !context.mounted) return;
    _mutate(() {
      row.endTime = picked;
      _recomputeDuration();
    });
  }

  void _recomputeDuration() {
    if (row.startTime != null && row.endTime != null) {
      final s = row.startTime!.hour * 60 + row.startTime!.minute;
      final e = row.endTime!.hour * 60 + row.endTime!.minute;
      row.durationMinutes = e > s ? e - s : null;
    }
  }

  Future<void> _pickInvigilator(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvigilatorSheet(
        teachers: teachers,
        selectedId: row.invigilatorId,
        cs: cs,
        isDark: isDark,
        onSelected: (t, u) => _mutate(() {
          row.invigilatorId = u.id;
          row.invigilatorName = u.name;
        }),
        onCleared: () => _mutate(() {
          row.invigilatorId = null;
          row.invigilatorName = null;
        }),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final subjects = subjectsForGrade(row.grade);
    final streams = streamsForGrade(row.grade);
    final hasError = errorMessage != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: hasError
                ? cs.error.withValues(alpha: 0.55)
                : AppTheme.borderColor(isDark, cs),
            width: hasError ? 1.0 : 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.subjectId != null
                          ? '${row.subjectName ?? ""}${row.paperNumber != null ? " - Paper ${row.paperNumber}" : ""}'
                          : 'Paper ${index + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (row.durationMinutes != null) ...[
                    const SizedBox(width: 8),
                    _InlineBadge(
                      label: _fmtDuration(row.durationMinutes!),
                      cs: cs,
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: cs.error,
                      ),
                      tooltip: 'Remove paper',
                      onPressed: onRemove,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Grade + Stream ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _FieldBlock(
                      label: 'Grade',
                      child: _GradeDropdown(
                        value: row.grade,
                        allGrades: allGrades,
                        gradeLabel: gradeLabel,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (g) {
                          if (g == row.grade) return;
                          _mutate(() {
                            row.grade = g;
                            row.stream = null;
                            row.subjectId = null;
                            row.subjectName = null;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FieldBlock(
                      label: 'Stream',
                      child: _StreamDropdown(
                        value: row.stream,
                        streams: streams,
                        gradeSelected: row.grade != null,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (s) => _mutate(() => row.stream = s),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _FieldBlock(
                      label: 'Subject',
                      child: _SubjectDropdown(
                        value: row.subjectId,
                        subjects: subjects,
                        gradeSelected: row.grade != null,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (id) {
                          if (id == null) return;
                          final name = subjects.firstWhere((s) => s.id == id).name;
                          _mutate(() {
                            row.subjectId = id;
                            row.subjectName = name;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _FieldBlock(
                      label: 'Paper Type',
                      child: _PaperNumberDropdown(
                        value: row.paperNumber,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (n) => _mutate(() => row.paperNumber = n),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Date + Times ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _FieldBlock(
                      label: 'Date',
                      child: _PickerTile(
                        text: row.date == null
                            ? 'Pick date'
                            : _fmtDate(row.date!),
                        hasValue: row.date != null,
                        icon: Icons.calendar_today_outlined,
                        onTap: () => _pickDate(context),
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _FieldBlock(
                      label: 'Start',
                      child: _PickerTile(
                        text: row.startTime == null
                            ? '—'
                            : _fmtTime(row.startTime!),
                        hasValue: row.startTime != null,
                        icon: Icons.access_time_outlined,
                        onTap: () => _pickStartTime(context),
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _FieldBlock(
                      label: 'End',
                      child: _PickerTile(
                        text: row.endTime == null
                            ? '—'
                            : _fmtTime(row.endTime!),
                        hasValue: row.endTime != null,
                        icon: Icons.access_time_outlined,
                        onTap: () => _pickEndTime(context),
                        cs: cs,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Invigilator ────────────────────────────────────────────
              _FieldBlock(
                label: 'Invigilator (optional)',
                child: _PickerTile(
                  text:
                      row.invigilatorName ??
                      (teachersLoaded ? 'None assigned' : 'Loading…'),
                  hasValue: row.invigilatorId != null,
                  icon: Icons.person_outline_rounded,
                  onTap: () => _pickInvigilator(context),
                  cs: cs,
                  isDark: isDark,
                ),
              ),

              // ── Validation error ───────────────────────────────────────
              if (hasError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 13, color: cs.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.error,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timetable Preview
// ─────────────────────────────────────────────────────────────────────────────

class _TimetablePreview extends StatelessWidget {
  const _TimetablePreview({
    required this.papers,
    required this.gradeLabel,
    required this.cs,
    required this.isDark,
  });

  final List<_PaperScheduleRow> papers;
  final String Function(int) gradeLabel;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Collect unique sorted dates
    final dates =
        papers.where((p) => p.date != null).map((p) => p.date!).toSet().toList()
          ..sort();

    // Collect unique sorted grades
    final grades =
        papers
            .where((p) => p.grade != null)
            .map((p) => p.grade!)
            .toSet()
            .toList()
          ..sort();

    if (dates.isEmpty || grades.isEmpty) return const SizedBox();

    // Build cell map: (gradeIndex, dateIndex) → subject names
    final cellData = <(int, int), List<String>>{};
    for (final row in papers) {
      if (row.grade == null || row.date == null) continue;
      final gi = grades.indexOf(row.grade!);
      final di = dates.indexWhere(
        (d) =>
            d.year == row.date!.year &&
            d.month == row.date!.month &&
            d.day == row.date!.day,
      );
      final pNumStr = row.paperNumber != null ? ' (P${row.paperNumber})' : '';
      cellData.putIfAbsent((gi, di), () => []).add('${row.subjectName ?? "?"}$pNumStr');
    }

    const labelW = 76.0;
    const cellW = 82.0;
    const headerH = 32.0;
    const rowH = 40.0;
    final borderC = AppTheme.borderColor(isDark, cs);
    final headerBg = AppTheme.nestedBg(isDark, cs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Schedule Preview',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderC, width: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        _tCell(
                          'Grade',
                          w: labelW,
                          h: headerH,
                          bg: headerBg,
                          isHeader: true,
                        ),
                        for (final d in dates)
                          _tCell(
                            _fmtDateShort(d),
                            w: cellW,
                            h: headerH,
                            bg: headerBg,
                            isHeader: true,
                            center: true,
                          ),
                      ],
                    ),
                    Container(height: 0.5, color: borderC),
                    // Grade rows
                    for (int gi = 0; gi < grades.length; gi++) ...[
                      Row(
                        children: [
                          _tCell(
                            gradeLabel(grades[gi]),
                            w: labelW,
                            h: rowH,
                            isHeader: false,
                          ),
                          for (int di = 0; di < dates.length; di++)
                            _dataCell(gi, di, cellData, cellW, rowH, borderC),
                        ],
                      ),
                      if (gi < grades.length - 1)
                        Container(height: 0.5, color: borderC),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tCell(
    String text, {
    required double w,
    required double h,
    Color? bg,
    required bool isHeader,
    bool center = false,
  }) {
    return Container(
      width: w,
      height: h,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHeader ? FontWeight.w500 : FontWeight.w400,
          color: cs.onSurface.withValues(alpha: isHeader ? 0.85 : 0.7),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dataCell(
    int gi,
    int di,
    Map<(int, int), List<String>> cellData,
    double w,
    double h,
    Color borderC,
  ) {
    final subjects = cellData[(gi, di)];
    final isEmpty = subjects == null || subjects.isEmpty;
    return Container(
      width: w,
      constraints: BoxConstraints(minHeight: h),
      decoration: BoxDecoration(
        color: isEmpty
            ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
            : null,
        border: Border(left: BorderSide(color: borderC, width: 0.5)),
      ),
      padding: isEmpty ? EdgeInsets.zero : const EdgeInsets.all(4),
      child: isEmpty
          ? null
          : Wrap(
              spacing: 3,
              runSpacing: 3,
              children: subjects
                  .map((name) => _SubjectBadge(name: name, cs: cs))
                  .toList(),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invigilator Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvigilatorSheet extends StatefulWidget {
  const _InvigilatorSheet({
    required this.teachers,
    required this.selectedId,
    required this.cs,
    required this.isDark,
    required this.onSelected,
    required this.onCleared,
  });

  final List<({TeachersData teacher, UsersData user})> teachers;
  final String? selectedId;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TeachersData, UsersData) onSelected;
  final VoidCallback onCleared;

  @override
  State<_InvigilatorSheet> createState() => _InvigilatorSheetState();
}

class _InvigilatorSheetState extends State<_InvigilatorSheet> {
  final _searchCtrl = TextEditingController();
  late List<({TeachersData teacher, UsersData user})> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.teachers;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.trim().isEmpty
          ? widget.teachers
          : widget.teachers
                .where(
                  (t) => t.user.name.toLowerCase().contains(
                    q.trim().toLowerCase(),
                  ),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final sheetBg = AppTheme.modalBg(isDark, cs);
    final borderC = AppTheme.borderColor(isDark, cs);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: borderC, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'Select Invigilator',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (widget.selectedId != null)
                    TextButton(
                      onPressed: () {
                        widget.onCleared();
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppTheme.nestedBg(isDark, cs),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    borderSide: BorderSide(color: borderC, width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    borderSide: BorderSide(color: borderC, width: 0.8),
                  ),
                ),
              ),
            ),
            // Teacher list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No teachers found',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final t = _filtered[i];
                        final isSelected = t.user.id == widget.selectedId;
                        return InkWell(
                          onTap: () {
                            widget.onSelected(t.teacher, t.user);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.user.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Row
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavRow extends StatelessWidget {
  const _BottomNavRow({
    required this.onBack,
    required this.onNext,
    required this.backLabel,
    required this.nextLabel,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final String backLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              side: BorderSide(color: cs.outlineVariant, width: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            child: Text(backLabel),
          ),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(nextLabel),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Vertical label + field block.
class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// Styled grade dropdown.
class _GradeDropdown extends StatelessWidget {
  const _GradeDropdown({
    required this.value,
    required this.allGrades,
    required this.gradeLabel,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final int? value;
  final List<GradeConfig> allGrades;
  final String Function(int) gradeLabel;
  final ColorScheme cs;
  final bool isDark;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownBox(
      cs: cs,
      isDark: isDark,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          hint: _hint('Grade', cs),
          dropdownColor: AppTheme.overlayBg(isDark, cs),
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          items: allGrades
              .map(
                (gc) => DropdownMenuItem(
                  value: gc.grade,
                  child: Text(gradeLabel(gc.grade)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Styled stream dropdown.
class _StreamDropdown extends StatelessWidget {
  const _StreamDropdown({
    required this.value,
    required this.streams,
    required this.gradeSelected,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final int? value;
  final List<GradeStream> streams;
  final bool gradeSelected;
  final ColorScheme cs;
  final bool isDark;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    // Grade not yet chosen, or grade has no streams
    if (!gradeSelected || streams.isEmpty) {
      return _DropdownBox(
        cs: cs,
        isDark: isDark,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: null,
            hint: _hint((!gradeSelected) ? '—' : 'N/A', cs),
            dropdownColor: AppTheme.overlayBg(isDark, cs),
            isExpanded: true,
            isDense: true,
            items: const [],
            onChanged: null,
          ),
        ),
      );
    }

    return _DropdownBox(
      cs: cs,
      isDark: isDark,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          hint: _hint('All', cs),
          dropdownColor: AppTheme.overlayBg(isDark, cs),
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('All streams'),
            ),
            for (final s in streams)
              DropdownMenuItem(value: s.code, child: Text(s.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Styled subject dropdown.
class _SubjectDropdown extends StatelessWidget {
  const _SubjectDropdown({
    required this.value,
    required this.subjects,
    required this.gradeSelected,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final int? value;
  final List<Subject> subjects;
  final bool gradeSelected;
  final ColorScheme cs;
  final bool isDark;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final hintText = !gradeSelected
        ? 'Pick a grade first'
        : subjects.isEmpty
        ? 'No subjects'
        : 'Select subject';

    return _DropdownBox(
      cs: cs,
      isDark: isDark,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          hint: _hint(hintText, cs),
          dropdownColor: AppTheme.overlayBg(isDark, cs),
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          items: subjects
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (!gradeSelected || subjects.isEmpty) ? null : onChanged,
        ),
      ),
    );
  }
}

/// Container decoration wrapper used by all in-card dropdowns.
class _DropdownBox extends StatelessWidget {
  const _DropdownBox({
    required this.cs,
    required this.isDark,
    required this.child,
  });

  final ColorScheme cs;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.overlayBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs), width: 0.8),
      ),
      child: child,
    );
  }
}

/// Tappable tile for date/time/person pickers.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.text,
    required this.hasValue,
    required this.icon,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String text;
  final bool hasValue;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final faded = cs.onSurface.withValues(alpha: 0.4);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.overlayBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: hasValue ? cs.primary : faded),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasValue ? FontWeight.w400 : FontWeight.w300,
                  color: hasValue ? cs.onSurface : faded,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small badge used for duration display in card header.
class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Abbreviated subject chip in the timetable preview.
class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({required this.name, required this.cs});

  final String name;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        _abbrevSubject(name),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a styled hint Text widget for use as DropdownButton.hint.
Text _hint(String text, ColorScheme cs) => Text(
  text,
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: cs.onSurface.withValues(alpha: 0.45),
  ),
);

String _fmtDate(DateTime d) {
  const months = [
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
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _fmtDateShort(DateTime d) {
  const months = [
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
  return '${d.day}\n${months[d.month - 1]}';
}

String _fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final min = t.minute.toString().padLeft(2, '0');
  final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$min $suffix';
}

String _fmtDuration(int mins) {
  if (mins < 60) return '${mins}min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}min';
}

/// Returns an abbreviation for a subject name.
/// Multi-word: first letter of each word (up to 3). Single word: first 4 chars.
String _abbrevSubject(String name) {
  final words = name.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.length == 1) {
    return name.substring(0, math.min(4, name.length)).toUpperCase();
  }
  return words.take(3).map((w) => w[0].toUpperCase()).join();
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Syllabus Coverage
// ─────────────────────────────────────────────────────────────────────────────

/// Internal data for one loaded (subjectId, grade) coverage pair.
class _CoveragePairData {
  const _CoveragePairData({required this.topics, required this.taught});
  final List<Topic> topics;
  final List<TaughtTopic> taught;
}

class _SyllabusCoverageStep extends StatefulWidget {
  const _SyllabusCoverageStep({
    required this.papers,
    required this.schoolId,
    required this.catalogDao,
    required this.gradeLabel,
    required this.config,
    required this.onCoverageChanged,
  });

  final List<_PaperScheduleRow> papers;
  final String schoolId;
  final CatalogDao catalogDao;
  final String Function(int) gradeLabel;
  final SchoolConfig config;
  final void Function(Map<(int, int), List<int>>) onCoverageChanged;

  @override
  State<_SyllabusCoverageStep> createState() => _SyllabusCoverageStepState();
}

class _SyllabusCoverageStepState extends State<_SyllabusCoverageStep> {
  bool _isLoading = true;
  String? _loadError;

  /// All topics + taught status per (subjectId, grade) key.
  Map<(int, int), _CoveragePairData> _pairData = {};

  /// User-checked topic IDs per (subjectId, grade).
  Map<(int, int), Set<int>> _checked = {};

  /// Display name per subjectId.
  Map<int, String> _subjectNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    // Gather unique (subjectId, grade) pairs from the paper schedule.
    final keys = <(int, int)>{};
    for (final p in widget.papers) {
      if (p.subjectId != null && p.grade != null) {
        keys.add((p.subjectId!, p.grade!));
      }
    }

    if (keys.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      _notifyParent();
      return;
    }

    try {
      // Preserve any existing checked state from prior loads.
      final checked = Map<(int, int), Set<int>>.from(_checked);
      final subjectNames = Map<int, String>.from(_subjectNames);
      final pairData = <(int, int), _CoveragePairData>{};

      // ── 1. Load subject display names ──────────────────────────────────────
      final uniqueSubjectIds = keys.map((k) => k.$1).toSet();
      for (final sid in uniqueSubjectIds) {
        if (!subjectNames.containsKey(sid)) {
          final subject = await widget.catalogDao.getSubject(sid);
          if (!mounted) return;
          if (subject != null) subjectNames[sid] = subject.name;
        }
      }

      // ── 2. Load topics from local DB (batched per unique subjectId) ─────────
      final topicsAllBySubject = <int, List<Topic>>{};
      for (final sid in uniqueSubjectIds) {
        topicsAllBySubject[sid] = await widget.catalogDao.getTopicsForSubject(
          sid,
        );
        if (!mounted) return;
      }

      // ── 3. Fetch taught status per (subjectId, grade) from server ──────────
      for (final key in keys) {
        if (!mounted) return;
        final (subjectId, grade) = key;

        // Filter topics to this specific grade.
        final gradeTopics =
            (topicsAllBySubject[subjectId] ?? [])
                .where((t) => t.grade == grade)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        // Fetch taught status from server.
        List<TaughtTopic> taught = [];
        final result = await paperService.getTaughtTopics(
          school: widget.schoolId,
          subject: subjectId,
          grade: grade,
          accessToken: accessToken,
        );
        if (!mounted) return;
        switch (result) {
          case Ok(:final value):
            taught = value;
          case Err():
            taught = [];
        }

        pairData[key] = _CoveragePairData(topics: gradeTopics, taught: taught);

        // Pre-check completed topics only if the user hasn't touched this key.
        if (!checked.containsKey(key)) {
          checked[key] = taught
              .where((t) => t.status == 2)
              .map((t) => t.topicId)
              .toSet();
        }
      }

      if (!mounted) return;
      setState(() {
        _pairData = pairData;
        _subjectNames = subjectNames;
        _checked = checked;
        _isLoading = false;
      });
      _notifyParent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
      _notifyParent();
    }
  }

  /// Reports coverage to the parent. Only includes (subjectId, grade) pairs
  /// that have at least one topic in the catalog — so empty-catalog pairs
  /// never block wizard progression.
  void _notifyParent() {
    final coverage = <(int, int), List<int>>{};
    for (final entry in _checked.entries) {
      final hasTopics = (_pairData[entry.key]?.topics.isNotEmpty) ?? false;
      if (hasTopics) {
        coverage[entry.key] = entry.value.toList();
      }
    }
    widget.onCoverageChanged(coverage);
  }

  void _setChecked((int, int) key, int topicId, bool value) {
    setState(() {
      if (value) {
        _checked.putIfAbsent(key, () => {}).add(topicId);
      } else {
        _checked[key]?.remove(topicId);
      }
    });
    _notifyParent();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_isLoading) return _buildLoading(cs);
    if (_loadError != null) return _buildError(cs);

    // Derive subject → sorted [grades] mapping.
    final subjectGrades = <int, List<int>>{};
    for (final key in _pairData.keys) {
      subjectGrades.putIfAbsent(key.$1, () => []).add(key.$2);
    }
    final subjectIds = subjectGrades.keys.toList()
      ..sort(
        (a, b) => (_subjectNames[a] ?? '').compareTo(_subjectNames[b] ?? ''),
      );
    for (final sid in subjectIds) {
      subjectGrades[sid]!.sort();
    }

    if (subjectIds.isEmpty) {
      return Center(
        child: Text(
          'No papers with subject and grade selected.',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return DefaultTabController(
      // Key by subject count so the controller is recreated if subjects change.
      key: ValueKey(subjectIds.length),
      length: subjectIds.length,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
          // ── Tab strip ──────────────────────────────────────────────────────
          ColoredBox(
            color: AppTheme.modalBg(isDark, cs),
            child: TabBar(
              isScrollable: subjectIds.length > 3,
              tabAlignment: subjectIds.length > 3
                  ? TabAlignment.start
                  : TabAlignment.fill,
              tabs: [
                for (final sid in subjectIds)
                  Tab(text: _subjectNames[sid] ?? 'Subject $sid'),
              ],
            ),
          ),
          // ── Tab bodies ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              children: [
                for (final sid in subjectIds)
                  _buildSubjectTab(
                    cs: cs,
                    isDark: isDark,
                    subjectId: sid,
                    grades: subjectGrades[sid]!,
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSubjectTab({
    required ColorScheme cs,
    required bool isDark,
    required int subjectId,
    required List<int> grades,
  }) {
    // Aggregate coverage counts for the summary chip.
    int totalTopics = 0;
    int coveredTopics = 0;
    final uncoveredGrades = <int>[];

    for (final grade in grades) {
      final key = (subjectId, grade);
      final topics = _pairData[key]?.topics ?? [];
      final checkedSet = _checked[key] ?? {};
      totalTopics += topics.length;
      coveredTopics += checkedSet.length;
      if (topics.isNotEmpty && checkedSet.isEmpty) {
        uncoveredGrades.add(grade);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        // Coverage summary chip.
        _CoverageChip(covered: coveredTopics, total: totalTopics, cs: cs),
        const SizedBox(height: 10),
        // Warning card for grades with zero topics selected.
        if (uncoveredGrades.isNotEmpty) ...[
          _UncoveredWarning(
            grades: uncoveredGrades,
            gradeLabel: widget.gradeLabel,
            subjectName: _subjectNames[subjectId] ?? 'Subject',
            cs: cs,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
        ],
        // One expansion tile per grade.
        for (final grade in grades)
          _buildGradeTile(
            cs: cs,
            isDark: isDark,
            subjectId: subjectId,
            grade: grade,
          ),
      ],
    );
  }

  Widget _buildGradeTile({
    required ColorScheme cs,
    required bool isDark,
    required int subjectId,
    required int grade,
  }) {
    final key = (subjectId, grade);
    final data = _pairData[key];
    final topics = data?.topics ?? [];
    final taught = data?.taught ?? [];
    final taughtMap = {for (final t in taught) t.topicId: t};
    final checkedSet = _checked[key] ?? {};

    // Collect stream names for papers with a specific stream on this pair.
    final streamNames = <String>[];
    for (final p in widget.papers) {
      if (p.subjectId == subjectId && p.grade == grade && p.stream != null) {
        String? name;
        for (final c in widget.config.curricula) {
          for (final gc in c.grades) {
            if (gc.grade == grade) {
              final gs = gc.streams
                  .where((s) => s.code == p.stream)
                  .firstOrNull;
              if (gs != null) name = gs.name;
            }
          }
        }
        streamNames.add(name ?? 'Stream ${p.stream}');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppTheme.nestedBg(isDark, cs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        side: BorderSide(color: AppTheme.borderColor(isDark, cs), width: 0.5),
      ),
      child: ExpansionTile(
        key: PageStorageKey('coverage-$subjectId-$grade'),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Row(
          children: [
            Text(
              widget.gradeLabel(grade),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            _InlineBadge(
              label: '${checkedSet.length}/${topics.length}',
              cs: cs,
            ),
          ],
        ),
        children: [
          if (topics.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'No topics found in the catalog for this grade.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            for (final topic in topics)
              CheckboxListTile(
                dense: true,
                value: checkedSet.contains(topic.id),
                title: Text(
                  topic.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                subtitle: _buildTopicSubtitle(taughtMap[topic.id], cs),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                onChanged: (v) => _setChecked(key, topic.id, v ?? false),
              ),
          // Stream overrides section — shown when stream-specific papers exist.
          if (streamNames.isNotEmpty) ...[
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: AppTheme.borderColor(isDark, cs),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.alt_route_rounded,
                    size: 13,
                    color: cs.primary.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Stream overrides',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.primary.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            for (final name in streamNames)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                child: Text(
                  '• $name — has a separate paper for this exam',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget? _buildTopicSubtitle(TaughtTopic? taught, ColorScheme cs) {
    if (taught == null) return null;
    if (taught.status == 2 && taught.taughtDate != null) {
      return Text(
        'Covered ${_fmtDate(taught.taughtDate!)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w300,
          color: cs.primary.withValues(alpha: 0.75),
        ),
      );
    }
    if (taught.status == 1) {
      return Text(
        'In progress',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w300,
          color: cs.tertiary.withValues(alpha: 0.75),
        ),
      );
    }
    return null;
  }

  Widget _buildLoading(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < 4; i++) ...[
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: cs.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Failed to load syllabus coverage',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _loadError!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 auxiliary widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Small chip at the top of each subject tab showing N / Total topics covered.
class _CoverageChip extends StatelessWidget {
  const _CoverageChip({
    required this.covered,
    required this.total,
    required this.cs,
  });

  final int covered;
  final int total;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isGood = covered > 0;
    final chipColor = isGood ? Colors.green.shade700 : cs.error;
    return Wrap(
      children: [
        Chip(
          label: Text(
            '$covered / $total topics covered',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: chipColor,
            ),
          ),
          backgroundColor: chipColor.withValues(alpha: 0.08),
          side: BorderSide(color: chipColor.withValues(alpha: 0.3), width: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// Warning card listing grade combinations that have zero topics selected.
class _UncoveredWarning extends StatelessWidget {
  const _UncoveredWarning({
    required this.grades,
    required this.gradeLabel,
    required this.subjectName,
    required this.cs,
    required this.isDark,
  });

  final List<int> grades;
  final String Function(int) gradeLabel;
  final String subjectName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final lines = grades
        .map((g) => '$subjectName — ${gradeLabel(g)}')
        .join('\n');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: isDark ? 0.15 : 0.18),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 15,
            color: cs.error.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No topics selected for:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.error.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lines,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.error.withValues(alpha: 0.8),
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
// Step 4 — Review
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.draft,
    required this.papers,
    required this.confirmedCoverage,
    required this.gradeLabel,
  });

  final _EventDraft draft;
  final List<_PaperScheduleRow> papers;
  final Map<(int, int), List<int>> confirmedCoverage;
  final String Function(int) gradeLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final borderC = AppTheme.borderColor(isDark, cs);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Event details card ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.nestedBg(isDark, cs),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: borderC, width: 0.8),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        draft.name.isEmpty ? '(Untitled)' : draft.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        draft.type.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: borderC, height: 1, thickness: 0.5),
                const SizedBox(height: 10),
                _metaRow(
                  Icons.school_outlined,
                  'Term ${draft.term}  ·  ${draft.year}',
                  cs,
                ),
                const SizedBox(height: 6),
                _metaRow(
                  Icons.date_range_outlined,
                  draft.startDate != null && draft.endDate != null
                      ? '${_fmtDate(draft.startDate!)}  –  ${_fmtDate(draft.endDate!)}'
                      : '—',
                  cs,
                ),
                const SizedBox(height: 6),
                _metaRow(
                  Icons.description_outlined,
                  '${papers.length} paper${papers.length == 1 ? '' : 's'} scheduled',
                  cs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Timetable preview ─────────────────────────────────────────────
          _TimetablePreview(
            papers: papers,
            gradeLabel: gradeLabel,
            cs: cs,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          // ── Paper summary cards ───────────────────────────────────────────
          Text(
            'Paper Details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          for (final row in papers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _paperCard(row, cs, isDark, borderC),
            ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paperCard(
    _PaperScheduleRow row,
    ColorScheme cs,
    bool isDark,
    Color borderC,
  ) {
    final topicIds = (row.subjectId != null && row.grade != null)
        ? confirmedCoverage[(row.subjectId!, row.grade!)] ?? <int>[]
        : <int>[];
    final topicCount = topicIds.length;
    final lowPool = topicCount > 0 && topicCount < 10;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: borderC, width: 0.8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject + grade header
          Row(
            children: [
              Expanded(
                child: Text(
                  row.subjectId != null
                      ? '${row.subjectName ?? ""}${row.paperNumber != null ? " - Paper ${row.paperNumber}" : ""}'
                      : '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (row.grade != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  ),
                  child: Text(
                    gradeLabel(row.grade!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: borderC, height: 1, thickness: 0.5),
          const SizedBox(height: 8),
          // Date + time + duration
          if (row.date != null &&
              row.startTime != null &&
              row.endTime != null) ...[
            _metaRow(
              Icons.schedule_outlined,
              '${_fmtDate(row.date!)}  ·  '
              '${_fmtTime(row.startTime!)} – ${_fmtTime(row.endTime!)}'
              '  (${_fmtDuration(row.durationMinutes ?? 0)})',
              cs,
            ),
            const SizedBox(height: 4),
          ],
          // Invigilator
          if (row.invigilatorId != null && row.invigilatorName != null)
            _metaRow(Icons.person_outline_rounded, row.invigilatorName!, cs)
          else
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  'No invigilator assigned',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          // Topics confirmed count
          _metaRow(
            Icons.checklist_outlined,
            topicCount > 0
                ? '$topicCount topic${topicCount == 1 ? '' : 's'} confirmed'
                : 'No topics confirmed',
            cs,
          ),
          // Low question pool warning
          if (lowPool) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Low question pool — paper generation may fail.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Confirm
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.papers,
    required this.activating,
    required this.error,
    required this.onActivate,
  });

  final List<_PaperScheduleRow> papers;
  final bool activating;
  final String? error;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final n = papers.length;
    final subjects = papers
        .map((p) => p.subjectId)
        .whereType<int>()
        .toSet()
        .length;
    final grades = papers.map((p) => p.grade).whereType<int>().toSet().length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_outlined,
                size: 28,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ready to activate?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You are about to activate $n exam paper${n == 1 ? '' : 's'} '
              'across $subjects subject${subjects == 1 ? '' : 's'} and '
              '$grades grade${grades == 1 ? '' : 's'}. '
              'Papers will be automatically generated 1 hour before each '
              'scheduled start time. Teachers will be notified 30 minutes before.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.75),
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Activate button / loading indicator
            if (activating)
              Column(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Activating…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onActivate,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Activate Exam',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
              ),
            // Error card
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: cs.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Activation Error',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: cs.error,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            foregroundColor: cs.error,
                            padding: EdgeInsets.zero,
                          ),
                          tooltip: 'Copy Error',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: error!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error copied to clipboard!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      error!,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: cs.error.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper Number Dropdown and Automated Setup
// ─────────────────────────────────────────────────────────────────────────────

class _PaperNumberDropdown extends StatelessWidget {
  const _PaperNumberDropdown({
    required this.value,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _DropdownBox(
      cs: cs,
      isDark: isDark,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          dropdownColor: AppTheme.overlayBg(isDark, cs),
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Single'),
            ),
            ...[1, 2, 3].map(
              (n) => DropdownMenuItem<int?>(
                value: n,
                child: Text('Paper $n'),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AutomatedSetupSheet extends StatefulWidget {
  const _AutomatedSetupSheet({
    required this.allGrades,
    required this.gradeLabel,
    required this.subjectsForGrade,
    this.examStartDate,
    required this.existingPapersCount,
    required this.onGenerated,
  });

  final List<GradeConfig> allGrades;
  final String Function(int) gradeLabel;
  final List<Subject> Function(int?) subjectsForGrade;
  final DateTime? examStartDate;
  final int existingPapersCount;
  final ValueChanged<List<_PaperScheduleRow>> onGenerated;

  @override
  State<_AutomatedSetupSheet> createState() => _AutomatedSetupSheetState();
}

class _AutomatedSetupSheetState extends State<_AutomatedSetupSheet> {
  final Set<int> _selectedGrades = {};
  int _selectedDurationMinutes = 120; // Default: 2 hours

  bool _splitLanguages = true;
  bool _splitMath = true;
  bool _splitSciences = true;

  @override
  void initState() {
    super.initState();
    _selectedGrades.addAll(widget.allGrades.map((g) => g.grade));
  }

  void _selectAll() {
    setState(() {
      _selectedGrades.addAll(widget.allGrades.map((g) => g.grade));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedGrades.clear();
    });
  }

  TimeOfDay _addMinutes(TimeOfDay base, int minutes) {
    final totalMinutes = base.hour * 60 + base.minute + minutes;
    final hour = (totalMinutes ~/ 60) % 24;
    final minute = totalMinutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _generate() {
    if (_selectedGrades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one grade.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      DateTime currentDate = widget.examStartDate ?? DateTime.now();
      final sessionStarts = [
        const TimeOfDay(hour: 8, minute: 30),
        const TimeOfDay(hour: 11, minute: 30),
        const TimeOfDay(hour: 14, minute: 30),
      ];

      int sessionIndex = 0;

      final Map<String, List<({int grade, Subject subject})>> subjectGroups = {};
      for (final grade in _selectedGrades) {
        final subjects = widget.subjectsForGrade(grade);
        for (final subject in subjects) {
          final key = subject.name.trim().toLowerCase();
          subjectGroups.putIfAbsent(key, () => []).add((grade: grade, subject: subject));
        }
      }

      final sortedKeys = subjectGroups.keys.toList()..sort();
      final List<_PaperScheduleRow> generatedPapers = [];

      for (final key in sortedKeys) {
        final group = subjectGroups[key]!;
        if (group.isEmpty) continue;

        int numPapers = 1;
        final isLanguage = key.contains('english') ||
            key.contains('kiswahili') ||
            key.contains('lugha') ||
            key.contains('fasihi') ||
            key.contains('language') ||
            key.contains('composition') ||
            key.contains('insha');

        final isMath = key.contains('math') || key.contains('hesabu');

        final isScience = key.contains('chem') ||
            key.contains('phys') ||
            key.contains('bio') ||
            key.contains('science');

        if (isLanguage && _splitLanguages) {
          numPapers = 3;
        } else if (isMath && _splitMath) {
          numPapers = 2;
        } else if (isScience && _splitSciences) {
          numPapers = 3;
        }

        for (int p = 1; p <= numPapers; p++) {
          while (currentDate.weekday == DateTime.sunday) {
            currentDate = currentDate.add(const Duration(days: 1));
          }

          final startTime = sessionStarts[sessionIndex];
          final endTime = _addMinutes(startTime, _selectedDurationMinutes);

          for (final item in group) {
            final row = _PaperScheduleRow(paperNumber: numPapers > 1 ? p : null)
              ..grade = item.grade
              ..subjectId = item.subject.id
              ..subjectName = item.subject.name
              ..date = currentDate
              ..startTime = startTime
              ..endTime = endTime
              ..durationMinutes = _selectedDurationMinutes;
            generatedPapers.add(row);
          }

          sessionIndex++;
          if (sessionIndex >= 3) {
            sessionIndex = 0;
            currentDate = currentDate.add(const Duration(days: 1));
          }
        }
      }

      widget.onGenerated(generatedPapers);
      Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('Error generating schedule: $e\n$stack');
      _showErrorDialog(e, stack);
    }
  }

  void _showErrorDialog(Object error, StackTrace stack) {
    if (!mounted) return;
    final errorText = '$error\n\n$stack';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final dCs = Theme.of(dialogCtx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.error_outline_rounded, color: dCs.error, size: 40),
          title: const Text('Generation Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'An error occurred while automatically generating the exam schedule papers. '
                'Please copy the error details below and share them with support.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: dCs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dCs.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    errorText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: dCs.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Details'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: errorText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error details copied to clipboard!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmAndGenerate() {
    if (widget.existingPapersCount > 0) {
      showDialog<bool>(
        context: context,
        builder: (dialogCtx) {
          final dCs = Theme.of(dialogCtx).colorScheme;
          return AlertDialog(
            title: const Text('Overwrite Scheduled Papers?'),
            content: Text(
              'You already have ${widget.existingPapersCount} manually added paper(s). '
              'Generating a new automated schedule will replace them completely. Are you sure you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: dCs.error),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Overwrite'),
              ),
            ],
          );
        },
      ).then((confirmed) {
        if (confirmed == true) {
          _generate();
        }
      });
    } else {
      _generate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final durationPresets = [
      (label: '1h', mins: 60),
      (label: '1h 30m', mins: 90),
      (label: '2h', mins: 120),
      (label: '2h 30m', mins: 150),
      (label: '3h', mins: 180),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Automated Paper Setup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Instantly schedule all subject papers aligned across classes to create a beautiful, synchronized exam timetable.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const _SectionHeader(title: '1. Select Target Grades'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all_rounded, size: 16),
                  label: const Text('Select All', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: _selectNone,
                  icon: const Icon(Icons.deselect_rounded, size: 16),
                  label: const Text('Deselect All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.allGrades.map((gc) {
                final isSelected = _selectedGrades.contains(gc.grade);
                return FilterChip(
                  label: Text(
                    widget.gradeLabel(gc.grade),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGrades.add(gc.grade);
                      } else {
                        _selectedGrades.remove(gc.grade);
                      }
                    });
                  },
                  selectedColor: cs.primary.withValues(alpha: 0.15),
                  checkmarkColor: cs.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(title: '2. Default Paper Duration'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: durationPresets.map((p) {
                final isSelected = _selectedDurationMinutes == p.mins;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDurationMinutes = p.mins),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : AppTheme.borderColor(isDark, cs),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? cs.onPrimary : cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(title: '3. Multi-Paper Rules'),
            const SizedBox(height: 4),
            Text(
              'Some subjects are divided into multiple papers for exam-standard grading. Choose which to split:',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _RuleSwitchTile(
              title: 'Split Languages (Paper 1, 2, 3)',
              subtitle: 'English & Kiswahili compositions, grammar, and literature.',
              value: _splitLanguages,
              onChanged: (val) => setState(() => _splitLanguages = val),
              cs: cs,
            ),
            const SizedBox(height: 8),
            _RuleSwitchTile(
              title: 'Split Mathematics (Paper 1, 2)',
              subtitle: 'Mathematics is divided into Paper 1 and Paper 2.',
              value: _splitMath,
              onChanged: (val) => setState(() => _splitMath = val),
              cs: cs,
            ),
            const SizedBox(height: 8),
            _RuleSwitchTile(
              title: 'Split Sciences (Paper 1, 2, 3)',
              subtitle: 'Biology, Chemistry & Physics theories + practicals.',
              value: _splitSciences,
              onChanged: (val) => setState(() => _splitSciences = val),
              cs: cs,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirmAndGenerate,
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('Generate Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: cs.primary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _RuleSwitchTile extends StatelessWidget {
  const _RuleSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.cs,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
