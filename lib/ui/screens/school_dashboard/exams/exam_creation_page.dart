import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/daos/members_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../theme/app_theme.dart';

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

  _EventDraft({
    required this.name,
    required this.type,
    required this.term,
    required this.year,
    this.startDate,
    this.endDate,
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

  _PaperScheduleRow();
}

// ─────────────────────────────────────────────────────────────────────────────
// ExamCreationPage — 5-step PageView wizard
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page wizard for creating exam events. Five steps:
///   1. Event details (name, type, term, year, date range)
///   2. Schedule papers (papers per grade/stream with timetable preview)
///   3–5. Coming soon (Tasks D2, D3)
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

  @override
  void initState() {
    super.initState();
    _catalogDao = CatalogDao(db);
    _membersDao = MembersDao(db);

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
          _teachers = results..sort((a, b) => a.user.name.compareTo(b.user.name));
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

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _back() {
    if (_step == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
    _pageCtrl.previousPage(
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

    if (_step >= 5) {
      _activate();
      return;
    }

    setState(() => _step++);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  bool _validatePapers() {
    _rowErrors.clear();
    if (_papers.isEmpty) {
      _showSnack('Add at least one paper before continuing.');
      return false;
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

  void _activate() {
    // TODO: Task D3 — wire up PaperService.createEvent
    _showSnack('Activate — coming soon (Task D3)');
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
          'Create Exam — Step $_step of 5',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _step / 5,
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
                  onAddPaper: () => setState(() => _papers.add(_PaperScheduleRow())),
                  onRemovePaper: (i) => setState(() {
                    _papers.removeAt(i);
                    // Re-key errors after removal so indices stay correct.
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
                ),
                // Steps 3–5 — placeholders (Tasks D2, D3)
                const Center(
                  child: Text(
                    'Step 3 — coming soon',
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
                const Center(
                  child: Text(
                    'Step 4 — coming soon',
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
                const Center(
                  child: Text(
                    'Step 5 — coming soon',
                    style: TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavRow(
        onBack: _back,
        onNext: _next,
        backLabel: _step == 1 ? 'Cancel' : 'Back',
        nextLabel: _step == 5 ? 'Activate' : 'Next',
      ),
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

  void _notify() => widget.onDraftChanged();

  Future<void> _pickStartDate() async {
    final d = widget.draft;
    final picked = await showDatePicker(
      context: context,
      initialDate: d.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    d.startDate = picked;
    if (d.endDate != null && d.endDate!.isBefore(picked)) d.endDate = null;
    _notify();
  }

  Future<void> _pickEndDate() async {
    final d = widget.draft;
    final first = d.startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.endDate ?? first,
      firstDate: first,
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    d.endDate = picked;
    _notify();
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
            value: d.type,
            decoration: _inputDec(cs, isDark, null),
            dropdownColor: AppTheme.overlayBg(isDark, cs),
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            items: _EventType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.label),
                  ),
                )
                .toList(),
            onChanged: (t) {
              if (t == null) return;
              d.type = t;
              _notify();
            },
          ),
          const SizedBox(height: 16),

          // ── Term ──────────────────────────────────────────────────────────
          _fieldLabel('Term'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Term 1')),
              ButtonSegment(value: 2, label: Text('Term 2')),
              ButtonSegment(value: 3, label: Text('Term 3')),
            ],
            selected: {d.term},
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              ),
            ),
            onSelectionChanged: (s) {
              d.term = s.first;
              _notify();
            },
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
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  label: d.startDate == null
                      ? 'Start Date'
                      : _fmtDate(d.startDate!),
                  hasValue: d.startDate != null,
                  onTap: _pickStartDate,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateTile(
                  label: d.endDate == null ? 'End Date' : _fmtDate(d.endDate!),
                  hasValue: d.endDate != null,
                  onTap: _pickEndDate,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
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
                    'Tap "Add Paper" below to schedule the first paper.',
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
            separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                  side: BorderSide(
                    color: cs.primary.withValues(alpha: 0.35),
                  ),
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
    final initial = (row.date != null &&
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
                  Text(
                    'Paper ${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

              // ── Subject ────────────────────────────────────────────────
              _FieldBlock(
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
                  text: row.invigilatorName ??
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
    final dates = papers
        .where((p) => p.date != null)
        .map((p) => p.date!)
        .toSet()
        .toList()
      ..sort();

    // Collect unique sorted grades
    final grades = papers
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
      if (gi < 0 || di < 0) continue;
      cellData.putIfAbsent((gi, di), () => []).add(row.subjectName ?? '?');
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
                            _dataCell(
                              gi,
                              di,
                              cellData,
                              cellW,
                              rowH,
                              borderC,
                            ),
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
              children: subjects!
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
              .where((t) =>
                  t.user.name.toLowerCase().contains(q.trim().toLowerCase()))
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
          top: BorderSide(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
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
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
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
            hint: _hint(
              (!gradeSelected) ? '—' : 'N/A',
              cs,
            ),
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
              DropdownMenuItem(
                value: s.code,
                child: Text(s.name),
              ),
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
                  child: Text(
                    s.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged:
              (!gradeSelected || subjects.isEmpty) ? null : onChanged,
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
        border: Border.all(
          color: AppTheme.borderColor(isDark, cs),
          width: 0.8,
        ),
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
            Icon(
              icon,
              size: 13,
              color: hasValue ? cs.primary : faded,
            ),
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

/// Tappable date tile used in Step 1.
class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.hasValue,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final bool hasValue;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: AppTheme.borderColor(isDark, cs),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: hasValue ? cs.primary : faded,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w400 : FontWeight.w300,
                  color: hasValue ? cs.onSurface : faded,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: faded),
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _fmtDateShort(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
```

Now let me check for diagnostics and then update the CONTEXT.md and TASKS.md:
