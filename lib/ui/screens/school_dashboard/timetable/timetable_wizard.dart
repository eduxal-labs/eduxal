import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Action;

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/timetable_dao.dart';
import '../../../../database/daos/catalog_dao.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../../models/timetable_rules.dart';
import '../../../../core/extensions.dart';
import '../../../../services/timetable_generator.dart';
import '../../../theme/app_theme.dart';
import 'timetable_shared.dart';

// ── Public data classes (used by main shell) ──────────────────────────────────

class RulesSheetResult {
  const RulesSheetResult({required this.rules, required this.shouldGenerate});
  final TimetableRules rules;
  final bool shouldGenerate;
}

// ── Wizard data classes ───────────────────────────────────────────────────────

class WizardTeacher {
  const WizardTeacher({required this.id, required this.name});
  final String id;
  final String name;
}

class WizardSubject {
  const WizardSubject({required this.id, required this.name});
  final int id;
  final String name;
}

/// A detected incompatibility between a [TeacherConstraintEntry] and a
/// [SubjectConstraintEntry] when applied to the same class assignment.
class ConflictPair {
  ConflictPair({required this.teacherEntry, required this.subjectEntry});
  final TeacherConstraintEntry teacherEntry;
  final SubjectConstraintEntry subjectEntry;

  /// When `true` the teacher constraint is preserved and the subject
  /// constraint is dropped at generation time.
  bool teacherWins = true;
}

// ── Wizard entry point ────────────────────────────────────────────────────────

Future<RulesSheetResult?> showTimetableWizardDialog({
  required BuildContext context,
  required TimetableRules initialRules,
  required SchoolContext schoolContext,
  required ActiveTermContext termContext,
  required SchoolConfig config,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  if (w >= AppTheme.kMobileBreakpoint) {
    return showDialog<RulesSheetResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _TimetableWizard(
                initialRules: initialRules,
                schoolContext: schoolContext,
                termContext: termContext,
                config: config,
              ),
            ),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<RulesSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.kModalRadius),
              topRight: Radius.circular(AppTheme.kModalRadius),
            ),
            border: Border(
              top: BorderSide(color: AppTheme.borderColor(isDark, cs)),
            ),
          ),
          child: _TimetableWizard(
            initialRules: initialRules,
            schoolContext: schoolContext,
            termContext: termContext,
            config: config,
          ),
        ),
      );
    },
  );
}

// ── Wizard widget ─────────────────────────────────────────────────────────────

class _TimetableWizard extends StatefulWidget {
  const _TimetableWizard({
    required this.initialRules,
    required this.schoolContext,
    required this.termContext,
    required this.config,
  });

  final TimetableRules initialRules;
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;
  final SchoolConfig config;

  @override
  State<_TimetableWizard> createState() => _TimetableWizardState();
}

class _TimetableWizardState extends State<_TimetableWizard> {
  int _stage =
      0; // 0=Days+Slots, 1=Teachers, 2=Subjects, 3=Remainder Slots, 4=Generate
  late TimetableRules _rules;

  List<WizardTeacher> _teachers = [];
  List<WizardSubject> _subjects = [];
  List<SolverAssignment> _assignments = [];
  bool _loaded = false;
  bool _saving = false;

  // Stage-3 state
  List<ConflictPair> _conflicts = [];
  bool _generating = false;
  GeneratorResult? _generationResult;

  @override
  void initState() {
    super.initState();
    _rules = TimetableRules.fromJson(widget.initialRules.toJson());
    _loadData();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final term = widget.termContext.currentTerm;
    if (term == null || !mounted) return;

    final schoolId = widget.schoolContext.membership.school.id;
    final timetableDao = TimetableDao(db);

    // Load subject-teacher assignments for this term.
    final assignments = await timetableDao.getSubjectTeachersForTerm(
      schoolId: schoolId,
      year: term.year,
      term: term.term,
    );

    // Resolve teacher names from the users table.
    final teacherIds = assignments.map((a) => a.teacherUserId).toSet().toList();
    final users = teacherIds.isEmpty
        ? <UsersData>[]
        : await (db.select(
            db.users,
          )..where((u) => u.id.isIn(teacherIds))).get();
    final userNameMap = <String, String>{for (final u in users) u.id: u.name};
    final teachers =
        teacherIds
            .map((id) => WizardTeacher(id: id, name: userNameMap[id] ?? id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    // Resolve subject names from the global catalog.
    final subjectIds = assignments.map((a) => a.subjectId).toSet();
    final allSubjects = await CatalogDao(db).getSubjects();
    final subjects =
        allSubjects
            .where((s) => subjectIds.contains(s.id))
            .map((s) => WizardSubject(id: s.id, name: s.name))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (mounted) {
      setState(() {
        _teachers = teachers;
        _subjects = subjects;
        _assignments = assignments;
        _loaded = true;
      });
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goNext() {
    if (_stage == 3) _computeConflicts();
    if (_stage < 4) setState(() => _stage++);
  }

  void _goBack() {
    if (_stage > 0) {
      setState(() => _stage--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FileCache.saveTimetableRules(
        schoolId: widget.schoolContext.membership.school.id,
        year: term.year,
        term: term.term,
        rules: _rules,
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pop(RulesSheetResult(rules: _rules, shouldGenerate: false));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _completeWithGeneration() => Navigator.of(
    context,
  ).pop(RulesSheetResult(rules: _rules, shouldGenerate: true));

  // ── Conflict detection ──────────────────────────────────────────────────

  void _computeConflicts() {
    final conflicts = <ConflictPair>[];
    for (final tc in _rules.teacherConstraints) {
      for (final sc in _rules.subjectConstraints) {
        // Only relevant when both constraints target the same class assignment.
        final hasAssignment = _assignments.any(
          (a) => a.teacherUserId == tc.teacherId && a.subjectId == sc.subjectId,
        );
        if (!hasAssignment) continue;

        final sharedDays = tc.days.where((d) => sc.days.contains(d)).toList();
        if (sharedDays.isEmpty) continue;

        bool incompatible = false;
        if (!tc.isBlock && !sc.isBlock) {
          // Both requirements: intersection of allowed slots must be non-empty.
          final intersection = tc.slotIndices
              .where((s) => sc.slotIndices.contains(s))
              .toList();
          if (intersection.isEmpty) incompatible = true;
        } else if (tc.isBlock && !sc.isBlock) {
          // Teacher blocks the exact slots the subject requires.
          final requiresAll =
              sc.slotIndices.isNotEmpty &&
              sc.slotIndices.every((s) => tc.slotIndices.contains(s));
          if (requiresAll) incompatible = true;
        } else if (!tc.isBlock && sc.isBlock) {
          // Teacher requires the exact slots the subject blocks.
          final requiresAll =
              tc.slotIndices.isNotEmpty &&
              tc.slotIndices.every((s) => sc.slotIndices.contains(s));
          if (requiresAll) incompatible = true;
        }

        if (incompatible) {
          conflicts.add(ConflictPair(teacherEntry: tc, subjectEntry: sc));
        }
      }
    }
    setState(() => _conflicts = conflicts);
  }

  // ── Generation ──────────────────────────────────────────────────────────

  Future<void> _runGeneration() async {
    final term = widget.termContext.currentTerm;
    if (term == null || _generating) return;
    setState(() {
      _generating = true;
      _generationResult = null;
    });

    try {
      // Drop lower-priority constraints from each detected conflict pair.
      final resolvedTeacher = List<TeacherConstraintEntry>.from(
        _rules.teacherConstraints,
      );
      final resolvedSubject = List<SubjectConstraintEntry>.from(
        _rules.subjectConstraints,
      );
      for (final cp in _conflicts) {
        if (cp.teacherWins) {
          resolvedSubject.remove(cp.subjectEntry);
        } else {
          resolvedTeacher.remove(cp.teacherEntry);
        }
      }

      final resolvedRules = _rules.copyWith(
        teacherConstraints: resolvedTeacher,
        subjectConstraints: resolvedSubject,
      );

      final input = GeneratorInput(
        assignments: _assignments,
        rules: resolvedRules,
      );
      final result = await compute(runTimetableGenerator, input);
      if (mounted) setState(() => _generationResult = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _generationResult = GeneratorFailure(
            reason: e.toString(),
            conflicts: [],
          );
        });
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - 80,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs, isDark, isMobile),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_stage),
                child: _buildStage(cs, isDark),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          _buildFooter(cs, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark, bool isMobile) {
    const stageLabels = [
      'Day & Slot Setup',
      'Teacher Constraints',
      'Subject Constraints',
      'Remainder Slots',
      'Review & Generate',
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isMobile ? 4 : 16, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMobile)
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
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
                      stageLabels[_stage],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${_stage + 1} of 5',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _WizardStepDots(currentStep: _stage, totalSteps: 5, cs: cs),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStage(ColorScheme cs, bool isDark) {
    if (!_loaded && _stage >= 1) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }
    return switch (_stage) {
      0 => _Stage0DaysSlots(
        rules: _rules,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      1 => _Stage1TeacherConstraints(
        rules: _rules,
        teachers: _teachers,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      2 => _Stage2SubjectConstraints(
        rules: _rules,
        subjects: _subjects,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      3 => _Stage3RemainderSlots(
        rules: _rules,
        assignments: _assignments,
        subjects: _subjects,
        config: widget.config,
        cs: cs,
        isDark: isDark,
        onChanged: (r) => setState(() => _rules = r),
      ),
      4 => _Stage3Generate(
        rules: _rules,
        conflicts: _conflicts,
        teachers: _teachers,
        subjects: _subjects,
        generating: _generating,
        result: _generationResult,
        cs: cs,
        isDark: isDark,
        onConflictResolved: (cp, teacherWins) =>
            setState(() => cp.teacherWins = teacherWins),
        onGenerate: _runGeneration,
        onComplete: _completeWithGeneration,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildFooter(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          if (_stage > 0)
            _WizardTextButton(label: 'Back', onTap: _goBack, cs: cs),
          const Spacer(),
          _WizardTextButton(
            label: 'Save',
            onTap: _saving ? null : _save,
            loading: _saving,
            cs: cs,
          ),
          if (_stage < 4) ...[
            const SizedBox(width: 8),
            _WizardFilledButton(
              label: _stage == 3 ? 'Review' : 'Next',
              onTap: _goNext,
              cs: cs,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wizard button helpers
// ─────────────────────────────────────────────────────────────────────────────

class _WizardTextButton extends StatelessWidget {
  const _WizardTextButton({
    required this.label,
    required this.onTap,
    required this.cs,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: onTap != null
                    ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                    : cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardFilledButton extends StatelessWidget {
  const _WizardFilledButton({
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────

class _WizardStepDots extends StatelessWidget {
  const _WizardStepDots({
    required this.currentStep,
    required this.totalSteps,
    required this.cs,
  });

  final int currentStep;
  final int totalSteps;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final active = i == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: active ? 16 : 5,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drum time picker
// ─────────────────────────────────────────────────────────────────────────────

Future<TimeOfDay?> showDrumTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _DrumTimePicker(initialTime: initialTime),
          ),
        ),
      ),
    ),
  );
}

class _DrumTimePicker extends StatefulWidget {
  const _DrumTimePicker({required this.initialTime});
  final TimeOfDay initialTime;
  @override
  State<_DrumTimePicker> createState() => _DrumTimePickerState();
}

class _DrumTimePickerState extends State<_DrumTimePicker> {
  late int _hour; // 1–12
  late int _minute; // 0–59
  late bool _isPm;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialTime.hour;
    _isPm = h24 >= 12;
    _hour = h24 % 12 == 0 ? 12 : h24 % 12;
    _minute = widget.initialTime.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _toTimeOfDay() {
    final h = _hour % 12 + (_isPm ? 12 : 0);
    return TimeOfDay(hour: h, minute: _minute);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Start Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppTheme.borderColor(isDark, cs),
        ),
        // Drums
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour drum
              SizedBox(
                width: 72,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center highlight
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: _hourCtrl,
                      itemExtent: 40,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) =>
                          setState(() => _hour = i + 1),
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(12, (i) {
                          final n = i + 1;
                          final selected = n == _hour;
                          return Center(
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              // Colon separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // Minute drum
              SizedBox(
                width: 72,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: _minuteCtrl,
                      itemExtent: 40,
                      diameterRatio: 1.5,
                      perspective: 0.003,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) => setState(() => _minute = i),
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: List.generate(60, (m) {
                          final selected = m == _minute;
                          return Center(
                            child: Text(
                              m.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // AM/PM toggle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AmPmChip(
                    label: 'AM',
                    selected: !_isPm,
                    onTap: () => setState(() => _isPm = false),
                    cs: cs,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 4),
                  _AmPmChip(
                    label: 'PM',
                    selected: _isPm,
                    onTap: () => setState(() => _isPm = true),
                    cs: cs,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppTheme.borderColor(isDark, cs),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _WizardTextButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
                cs: cs,
              ),
              const SizedBox(width: 8),
              _WizardFilledButton(
                label: 'Confirm',
                onTap: () => Navigator.of(context).pop(_toTimeOfDay()),
                cs: cs,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmPmChip extends StatelessWidget {
  const _AmPmChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 32,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : AppTheme.nestedBg(isDark, cs),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 1.0)
                : AppTheme.borderColor(isDark, cs),
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 0 — Day & Slot Setup
// ─────────────────────────────────────────────────────────────────────────────

const _kWizDayShort = <int, String>{
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

class _Stage0DaysSlots extends StatefulWidget {
  const _Stage0DaysSlots({
    required this.rules,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage0DaysSlots> createState() => _Stage0DaysSlotsState();
}

class _Stage0DaysSlotsState extends State<_Stage0DaysSlots> {
  late List<int> _activeDays;
  late List<TimetableSlot> _slots;
  late TimeOfDay _dayStart;

  @override
  void initState() {
    super.initState();
    _activeDays = List<int>.from(widget.rules.activeDays);
    _slots = List<TimetableSlot>.from(widget.rules.slots);
    _dayStart = widget.rules.dayStartTime;
  }

  void _toggleDay(int d) {
    setState(() {
      if (_activeDays.contains(d)) {
        if (_activeDays.length > 1) {
          _activeDays = List.from(_activeDays)..remove(d);
        }
      } else {
        _activeDays = List.from(_activeDays)
          ..add(d)
          ..sort();
      }
    });
    _notify();
  }

  void _removeSlot(int index) {
    setState(() => _slots = List<TimetableSlot>.from(_slots)..removeAt(index));
    _notify();
  }

  void _notify() {
    widget.onChanged(
      widget.rules.copyWith(
        activeDays: List<int>.from(_activeDays),
        dayStartTime: _dayStart,
        slots: List<TimetableSlot>.from(_slots),
      ),
    );
  }

  Future<void> _pickDayStart() async {
    final picked = await showDrumTimePicker(
      context: context,
      initialTime: _dayStart,
    );
    if (picked != null)
      setState(() {
        _dayStart = picked;
        _notify();
      });
  }

  Future<void> _promptAdd(SlotType type, BuildContext ctx) async {
    final label = type == SlotType.lesson ? 'Lesson' : 'Break';
    final defaultMins = type == SlotType.lesson ? 40 : 10;
    final result = await showDialog<int>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) =>
          _DurationPickerDialog(slotLabel: label, initialMinutes: defaultMins),
    );
    if (result == null || result < 5 || result > 240) return;
    setState(
      () => _slots = [
        ..._slots,
        TimetableSlot(type: type, durationMinutes: result),
      ],
    );
    _notify();
  }

  List<({int i, String range, int dur, SlotType type})> _rows() {
    final result = <({int i, String range, int dur, SlotType type})>[];
    int cursor = _dayStart.hour * 3600 + _dayStart.minute * 60;
    for (int i = 0; i < _slots.length; i++) {
      final s = _slots[i];
      final end = cursor + s.durationMinutes * 60;
      result.add((
        i: i,
        range: '${fmtTimeSec(cursor)}\u2013${fmtTimeSec(end)}',
        dur: s.durationMinutes,
        type: s.type,
      ));
      cursor = end;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final rows = _rows();
    final lessonCount = _slots.where((s) => s.type == SlotType.lesson).length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            // ── Section A: Day selector ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                const _SectionLabel('School Days'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ToggleButtons(
                    isSelected: [
                      _activeDays.contains(1),
                      _activeDays.contains(2),
                      _activeDays.contains(3),
                      _activeDays.contains(4),
                      _activeDays.contains(5),
                      _activeDays.contains(6),
                      _activeDays.contains(7),
                    ],
                    onPressed: (i) => _toggleDay(i + 1),
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    borderColor: AppTheme.borderColor(isDark, cs),
                    selectedBorderColor: cs.primary.withValues(alpha: 0.55),
                    selectedColor: cs.primary,
                    fillColor: cs.primary.withValues(
                      alpha: isDark ? 0.15 : 0.10,
                    ),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 36,
                    ),
                    children: const [
                      Text('Mon'),
                      Text('Tue'),
                      Text('Wed'),
                      Text('Thu'),
                      Text('Fri'),
                      Text('Sat'),
                      Text('Sun'),
                    ],
                  ),
                ),
              ],
            ),

            // ── Section B: Day-start time ────────────────────────────────────
            InkWell(
              onTap: _pickDayStart,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              splashFactory: NoSplash.splashFactory,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.nestedBg(isDark, cs),
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(color: AppTheme.borderColor(isDark, cs)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Starts at',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        _dayStart.format(context),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // ── Section C: Slot list ─────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 0,
              children: [
                _SectionLabel(
                  'Slot Sequence',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                    ),
                    child: Text(
                      '$lessonCount lesson${lessonCount == 1 ? "" : "s"}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.nestedBg(isDark, cs),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: AppTheme.borderColor(isDark, cs),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.view_timeline_outlined,
                          size: 28,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No slots yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add lesson and break slots below.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.modalBg(isDark, cs),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      border: Border.all(
                        color: AppTheme.borderColor(isDark, cs),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          AppTheme.tableRowDivider(isDark, cs),
                      itemBuilder: (_, idx) {
                        final r = rows[idx];
                        return _SlotRowTile(
                          index: r.i,
                          timeRange: r.range,
                          duration: r.dur,
                          isBreak: r.type == SlotType.breakSlot,
                          cs: cs,
                          isDark: isDark,
                          onDelete: () => _removeSlot(r.i),
                        );
                      },
                    ),
                  ),
              ],
            ),

            // ── Section D: Add-slot actions ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _AddSlotButton(
                    label: '+ Add Lesson',
                    color: AppTheme.brandGreen,
                    onTap: () => _promptAdd(SlotType.lesson, context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AddSlotButton(
                    label: '+ Add Break',
                    color: const Color(0xFFFFA726),
                    onTap: () => _promptAdd(SlotType.breakSlot, context),
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

// ─────────────────────────────────────────────────────────────────────────────
// Stage 0 helpers — slot tile, add-slot button, duration dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SlotRowTile extends StatefulWidget {
  const _SlotRowTile({
    required this.index,
    required this.timeRange,
    required this.duration,
    required this.isBreak,
    required this.cs,
    required this.isDark,
    required this.onDelete,
  });

  final int index;
  final String timeRange;
  final int duration;
  final bool isBreak;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  State<_SlotRowTile> createState() => _SlotRowTileState();
}

class _SlotRowTileState extends State<_SlotRowTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color _bg() {
    final cs = widget.cs;
    final isDark = widget.isDark;
    if (_isPressed) return cs.primary.withValues(alpha: 0.13);
    if (_isHovered) return cs.primary.withValues(alpha: 0.08);
    return AppTheme.nestedBg(isDark, cs);
  }

  Color _borderColor() {
    final cs = widget.cs;
    if (_isHovered || _isPressed) return cs.primary.withValues(alpha: 0.3);
    return AppTheme.borderColor(widget.isDark, cs);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    const breakColor = Color(0xFFFFA726);
    final accentColor = widget.isBreak
        ? breakColor.withValues(alpha: 0.7)
        : AppTheme.brandGreen.withValues(alpha: 0.7);
    final accentWidth = (_isHovered || _isPressed) ? 4.0 : 3.0;

    return ScaleTransition(
      scale: _scaleAnim,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _pressCtrl.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _pressCtrl.reverse();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _pressCtrl.reverse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _bg(),
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(color: _borderColor(), width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: accentWidth,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppTheme.kCardRadius),
                          bottomLeft: Radius.circular(AppTheme.kCardRadius),
                        ),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            // Number badge
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Text(
                                '${widget.index + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Type chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isBreak
                                    ? breakColor.withValues(alpha: 0.12)
                                    : AppTheme.brandGreen.withValues(
                                        alpha: 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kChipRadius,
                                ),
                              ),
                              child: Text(
                                widget.isBreak ? 'Break' : 'Lesson',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isBreak
                                      ? breakColor
                                      : AppTheme.brandGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Time range
                            Expanded(
                              child: Text(
                                widget.timeRange,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            // Duration
                            Text(
                              '${widget.duration} min',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Delete button
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: Center(
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
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
        ),
      ),
    );
  }
}

class _AddSlotButton extends StatelessWidget {
  const _AddSlotButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DurationPickerDialog extends StatefulWidget {
  const _DurationPickerDialog({
    required this.slotLabel,
    required this.initialMinutes,
  });

  final String slotLabel;
  final int initialMinutes;

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _minutes;
  late TextEditingController _ctrl;

  List<int> get _presets =>
      widget.slotLabel == 'Lesson' ? [30, 40, 45, 60] : [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _ctrl = TextEditingController(text: '$_minutes');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor(isDark, cs)),
            boxShadow: AppTheme.modalShadow(isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add ${widget.slotLabel} Slot',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderColor(isDark, cs),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    // Preset chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _presets.map((p) {
                        final sel = _minutes == p;
                        return InkWell(
                          onTap: () => setState(() {
                            _minutes = p;
                            _ctrl.text = '$p';
                          }),
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          splashFactory: NoSplash.splashFactory,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? cs.primary.withValues(
                                      alpha: isDark ? 0.15 : 0.08,
                                    )
                                  : AppTheme.nestedBg(isDark, cs),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kCardRadius,
                              ),
                              border: Border.all(
                                color: sel
                                    ? cs.primary.withValues(alpha: 0.55)
                                    : AppTheme.borderColor(isDark, cs),
                              ),
                            ),
                            child: Text(
                              '$p min',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: sel
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Custom text field
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Custom (minutes)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) setState(() => _minutes = n);
                      },
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderColor(isDark, cs),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_minutes),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 1 — Teacher Constraints
// ─────────────────────────────────────────────────────────────────────────────

class _Stage1TeacherConstraints extends StatefulWidget {
  const _Stage1TeacherConstraints({
    required this.rules,
    required this.teachers,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final List<WizardTeacher> teachers;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage1TeacherConstraints> createState() =>
      _Stage1TeacherConstraintsState();
}

class _Stage1TeacherConstraintsState extends State<_Stage1TeacherConstraints> {
  String _search = '';
  String? _expandedId;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<WizardTeacher> get _filtered {
    if (_search.isEmpty) return widget.teachers;
    final q = _search.toLowerCase();
    return widget.teachers
        .where((t) => t.name.toLowerCase().contains(q))
        .toList();
  }

  List<TeacherConstraintEntry> _constraintsFor(String id) =>
      widget.rules.teacherConstraints.where((c) => c.teacherId == id).toList();

  void _remove(TeacherConstraintEntry entry) {
    final updated = List<TeacherConstraintEntry>.from(
      widget.rules.teacherConstraints,
    )..remove(entry);
    widget.onChanged(widget.rules.copyWith(teacherConstraints: updated));
  }

  void _add(
    String teacherId,
    List<int> days,
    List<int> slotIndices,
    bool isBlock,
  ) {
    final entry = TeacherConstraintEntry(
      teacherId: teacherId,
      days: days,
      slotIndices: slotIndices,
      isBlock: isBlock,
    );
    final updated = [...widget.rules.teacherConstraints, entry];
    widget.onChanged(widget.rules.copyWith(teacherConstraints: updated));
  }

  Future<void> _showConstraintEntry(String entityId, String entityName) async {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final result = await showDialog<_ConstraintResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _ConstraintEntryForm(
                entityName: entityName,
                rules: widget.rules,
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    _add(entityId, result.days, result.slotIndices, result.isBlock);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final filtered = _filtered;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 38,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v.trim()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search teachers\u2026',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          child: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.2 : 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    widget.teachers.isEmpty
                        ? 'No teachers found for this term.'
                        : 'No results for "$_search".',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final teacher = filtered[i];
                  final constraints = _constraintsFor(teacher.id);
                  final expanded = _expandedId == teacher.id;
                  final blocks = constraints.where((c) => c.isBlock).length;
                  final requires = constraints.where((c) => !c.isBlock).length;
                  Widget? subtitleTrailing;
                  if (blocks > 0 || requires > 0) {
                    subtitleTrailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (blocks > 0)
                          _DiffBadge(label: '+$blocks', color: cs.error),
                        if (blocks > 0 && requires > 0)
                          const SizedBox(width: 4),
                        if (requires > 0)
                          _DiffBadge(
                            label: '+$requires',
                            color: AppTheme.brandGreen,
                          ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WizardEntityRow(
                      name: teacher.name,
                      subtitle: constraints.isEmpty ? 'No constraints' : '',
                      subtitleTrailing: subtitleTrailing,
                      icon: Icons.person_outline_rounded,
                      isExpanded: expanded,
                      cs: cs,
                      isDark: isDark,
                      onTap: () => setState(
                        () => _expandedId = expanded ? null : teacher.id,
                      ),
                      expandedContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (constraints.isNotEmpty) ...[
                            ...constraints.expand(
                              (c) => [
                                _ConstraintChipRow(
                                  days: c.days,
                                  slotIndices: c.slotIndices,
                                  isBlock: c.isBlock,
                                  rules: widget.rules,
                                  cs: cs,
                                  isDark: isDark,
                                  onDelete: () => _remove(c),
                                ),
                                AppTheme.tableRowDivider(isDark, cs),
                              ],
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: OutlinedButton.icon(
                              onPressed: () => _showConstraintEntry(
                                teacher.id,
                                teacher.name,
                              ),
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Add Constraint'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.primary,
                                side: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.kCardRadius,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 2 — Subject Constraints
// ─────────────────────────────────────────────────────────────────────────────

class _Stage2SubjectConstraints extends StatefulWidget {
  const _Stage2SubjectConstraints({
    required this.rules,
    required this.subjects,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final List<WizardSubject> subjects;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage2SubjectConstraints> createState() =>
      _Stage2SubjectConstraintsState();
}

class _Stage2SubjectConstraintsState extends State<_Stage2SubjectConstraints> {
  String _search = '';
  int? _expandedId;

  List<WizardSubject> get _filtered {
    if (_search.isEmpty) return widget.subjects;
    final q = _search.toLowerCase();
    return widget.subjects
        .where((s) => s.name.toLowerCase().contains(q))
        .toList();
  }

  List<SubjectConstraintEntry> _constraintsFor(int id) =>
      widget.rules.subjectConstraints.where((c) => c.subjectId == id).toList();

  void _remove(SubjectConstraintEntry entry) {
    final updated = List<SubjectConstraintEntry>.from(
      widget.rules.subjectConstraints,
    )..remove(entry);
    widget.onChanged(widget.rules.copyWith(subjectConstraints: updated));
  }

  void _add(
    int subjectId,
    List<int> days,
    List<int> slotIndices,
    bool isBlock,
  ) {
    final entry = SubjectConstraintEntry(
      subjectId: subjectId,
      days: days,
      slotIndices: slotIndices,
      isBlock: isBlock,
    );
    final updated = [...widget.rules.subjectConstraints, entry];
    widget.onChanged(widget.rules.copyWith(subjectConstraints: updated));
  }

  Future<void> _showConstraintEntry(String entityId, String entityName) async {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final result = await showDialog<_ConstraintResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.modalBg(isDark, cs),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(isDark, cs)),
              boxShadow: AppTheme.modalShadow(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _ConstraintEntryForm(
                entityName: entityName,
                rules: widget.rules,
                cs: cs,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    _add(int.parse(entityId), result.days, result.slotIndices, result.isBlock);
  }

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final filtered = _filtered;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: 38,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v.trim()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search subjects\u2026',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 6),
                          child: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.2 : 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kCardRadius,
                          ),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    widget.subjects.isEmpty
                        ? 'No subjects found for this term.'
                        : 'No results for "$_search".',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final subj = filtered[i];
                  final constraints = _constraintsFor(subj.id);
                  final expanded = _expandedId == subj.id;
                  final blocks = constraints.where((c) => c.isBlock).length;
                  final requires = constraints.where((c) => !c.isBlock).length;
                  Widget? subtitleTrailing;
                  if (blocks > 0 || requires > 0) {
                    subtitleTrailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (blocks > 0)
                          _DiffBadge(label: '+$blocks', color: cs.error),
                        if (blocks > 0 && requires > 0)
                          const SizedBox(width: 4),
                        if (requires > 0)
                          _DiffBadge(
                            label: '+$requires',
                            color: AppTheme.brandGreen,
                          ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WizardEntityRow(
                      name: subj.name,
                      subtitle: constraints.isEmpty ? 'No constraints' : '',
                      subtitleTrailing: subtitleTrailing,
                      icon: Icons.book_outlined,
                      isExpanded: expanded,
                      cs: cs,
                      isDark: isDark,
                      onTap: () => setState(
                        () => _expandedId = expanded ? null : subj.id,
                      ),
                      expandedContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (constraints.isNotEmpty) ...[
                            ...constraints.expand(
                              (c) => [
                                _ConstraintChipRow(
                                  days: c.days,
                                  slotIndices: c.slotIndices,
                                  isBlock: c.isBlock,
                                  rules: widget.rules,
                                  cs: cs,
                                  isDark: isDark,
                                  onDelete: () => _remove(c),
                                ),
                                AppTheme.tableRowDivider(isDark, cs),
                              ],
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showConstraintEntry('${subj.id}', subj.name),
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Add Constraint'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.primary,
                                side: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.kCardRadius,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — entity row with hover/press animations and inline expansion
// ─────────────────────────────────────────────────────────────────────────────

class _WizardEntityRow extends StatefulWidget {
  const _WizardEntityRow({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.cs,
    required this.isDark,
    required this.onTap,
    required this.expandedContent,
    this.subtitleTrailing,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;
  final Widget expandedContent;
  final Widget? subtitleTrailing;

  @override
  State<_WizardEntityRow> createState() => _WizardEntityRowState();
}

class _WizardEntityRowState extends State<_WizardEntityRow>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? cs.primary.withValues(alpha: 0.12)
        : cs.primary.withValues(alpha: 0.08);
    final pressBg = isDark
        ? cs.primary.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.13);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ─────────────────────────────────────────────
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _isPressed = true);
                _pressCtrl.forward();
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _pressCtrl.reverse();
                widget.onTap();
              },
              onTapCancel: () {
                setState(() => _isPressed = false);
                _pressCtrl.reverse();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? pressBg
                      : _isHovered
                      ? hoverBg
                      : idleBg,
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  border: Border.all(
                    color: _isHovered || _isPressed
                        ? cs.primary.withValues(alpha: 0.25)
                        : cs.outline.withValues(alpha: isDark ? 0.08 : 0.08),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Accent bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isHovered || _isPressed ? 4 : 3,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(
                              alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(AppTheme.kCardRadius),
                              bottomLeft: Radius.circular(AppTheme.kCardRadius),
                            ),
                          ),
                        ),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Row(
                              children: [
                                // Leading icon container
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isHovered || _isPressed
                                        ? cs.primary.withValues(alpha: 0.12)
                                        : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.kChipRadius,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: 14,
                                    color: _isHovered || _isPressed
                                        ? cs.primary
                                        : cs.onSurfaceVariant.withValues(
                                            alpha: 0.55,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Name + subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.subtitle,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w400,
                                                color: cs.onSurfaceVariant
                                                    .withValues(alpha: 0.55),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (widget.subtitleTrailing !=
                                              null) ...[
                                            const SizedBox(width: 6),
                                            widget.subtitleTrailing!,
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Chevron
                                AnimatedRotation(
                                  turns: widget.isExpanded ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
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
            ),
          ),
          // ── Expanded content ────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: AppTheme.nestedBg(isDark, cs),
                border: Border(
                  left: BorderSide(
                    color: cs.primary.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
              ),
              child: widget.expandedContent,
            ),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — compact constraint chip row
// ─────────────────────────────────────────────────────────────────────────────

class _ConstraintChipRow extends StatelessWidget {
  const _ConstraintChipRow({
    required this.days,
    required this.slotIndices,
    required this.isBlock,
    required this.rules,
    required this.cs,
    required this.isDark,
    required this.onDelete,
  });

  final List<int> days;
  final List<int> slotIndices;
  final bool isBlock;
  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeColor = isBlock ? cs.error : cs.primary;
    final allLessonSlots = rules.buildLessonSlots();

    final slotLabels = slotIndices.map((idx) {
      final match = allLessonSlots.where((s) => s.index == idx).firstOrNull;
      if (match == null) return 'Slot $idx';
      return '${fmtTimeSec(match.start)}\u2013${fmtTimeSec(match.end)}';
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isBlock
            ? cs.error.withValues(alpha: isDark ? 0.07 : 0.04)
            : cs.primary.withValues(alpha: isDark ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: typeColor, width: 3)),
      ),
      child: Row(
        children: [
          // Type label
          Text(
            isBlock ? 'Block' : 'Require',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 10),
          // Day + slot mini-chips
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...days.map(
                  (d) => _MiniChip(label: _kWizDayShort[d] ?? 'D$d', cs: cs),
                ),
                const _MiniSep(),
                ...slotLabels.map((l) => _MiniChip(label: l, cs: cs)),
              ],
            ),
          ),
          // Delete
          GestureDetector(
            onTap: onDelete,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _MiniSep extends StatelessWidget {
  const _MiniSep();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '\u00B7',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — type tab strip, diff badge
// ─────────────────────────────────────────────────────────────────────────────

class _TypeTabStrip extends StatelessWidget {
  const _TypeTabStrip({
    required this.isBlock,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });
  final bool isBlock;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      child: Row(
        children: [
          _TypeTab(
            label: 'Block',
            selected: isBlock,
            selectedColor: cs.error,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(true),
          ),
          _TypeTab(
            label: 'Require',
            selected: !isBlock,
            selectedColor: cs.primary,
            cs: cs,
            isDark: isDark,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.16 : 0.07,
                      ),
                      blurRadius: 5,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? selectedColor
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared — constraint entry dialog
// ─────────────────────────────────────────────────────────────────────────────

typedef _ConstraintResult = ({
  List<int> days,
  List<int> slotIndices,
  bool isBlock,
});

class _ConstraintEntryForm extends StatefulWidget {
  const _ConstraintEntryForm({
    required this.entityName,
    required this.rules,
    required this.cs,
    required this.isDark,
  });

  final String entityName;
  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_ConstraintEntryForm> createState() => _ConstraintEntryFormState();
}

class _ConstraintEntryFormState extends State<_ConstraintEntryForm> {
  final Set<int> _selectedDays = {};
  final Set<int> _selectedSlots = {};
  bool _isBlock = true;

  bool get _canSubmit => _selectedDays.isNotEmpty && _selectedSlots.isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop<_ConstraintResult>((
      days: _selectedDays.toList()..sort(),
      slotIndices: _selectedSlots.toList()..sort(),
      isBlock: _isBlock,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final lessonSlots = widget.rules.buildLessonSlots();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Constraint',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.entityName,
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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selector
                const _SectionLabel('Type'),
                const SizedBox(height: 8),
                _TypeTabStrip(
                  isBlock: _isBlock,
                  onChanged: (v) => setState(() => _isBlock = v),
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                // Days selector
                const _SectionLabel('Days'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Builder(
                    builder: (ctx) {
                      final daysToShow = widget.rules.activeDays.toList()
                        ..sort();
                      return ToggleButtons(
                        isSelected: daysToShow
                            .map((d) => _selectedDays.contains(d))
                            .toList(),
                        onPressed: (i) {
                          final d = daysToShow[i];
                          setState(() {
                            if (_selectedDays.contains(d)) {
                              _selectedDays.remove(d);
                            } else {
                              _selectedDays.add(d);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(
                          AppTheme.kCardRadius,
                        ),
                        borderColor: AppTheme.borderColor(isDark, cs),
                        selectedBorderColor: cs.primary.withValues(alpha: 0.55),
                        selectedColor: cs.primary,
                        fillColor: cs.primary.withValues(
                          alpha: isDark ? 0.15 : 0.10,
                        ),
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
                        children: daysToShow
                            .map((d) => Text(_kWizDayShort[d] ?? 'D$d'))
                            .toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Slots selector
                const _SectionLabel('Slots'),
                const SizedBox(height: 8),
                if (lessonSlots.isEmpty)
                  Text(
                    'No lesson slots configured.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ToggleButtons(
                      isSelected: lessonSlots
                          .map((s) => _selectedSlots.contains(s.index))
                          .toList(),
                      onPressed: (i) {
                        final idx = lessonSlots[i].index;
                        setState(() {
                          if (_selectedSlots.contains(idx)) {
                            _selectedSlots.remove(idx);
                          } else {
                            _selectedSlots.add(idx);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                      borderColor: AppTheme.borderColor(isDark, cs),
                      selectedBorderColor: cs.primary.withValues(alpha: 0.55),
                      selectedColor: cs.primary,
                      fillColor: cs.primary.withValues(
                        alpha: isDark ? 0.15 : 0.10,
                      ),
                      color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      constraints: const BoxConstraints(minHeight: 36),
                      children: lessonSlots
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '${fmtTimeSec(s.start)}\u2013${fmtTimeSec(s.end)}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderColor(isDark, cs),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _canSubmit ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _canSubmit
                          ? AppTheme.brandGreen
                          : AppTheme.brandGreen.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                    ),
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(
                          alpha: _canSubmit ? 1.0 : 0.6,
                        ),
                      ),
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
// Stage 3 — Remainder Slots
// ─────────────────────────────────────────────────────────────────────────────

/// Computes base + remainder lessons per week for a given (grade, stream) group.
({int base, int remainder, int totalPerWeek}) _computeRemainder({
  required TimetableRules rules,
  required int subjectCount,
}) {
  final slotsPerDay = rules.slots
      .where((s) => s.type == SlotType.lesson)
      .length;
  final total = slotsPerDay * rules.activeDays.length;
  if (subjectCount == 0) return (base: 0, remainder: 0, totalPerWeek: total);
  return (
    base: total ~/ subjectCount,
    remainder: total % subjectCount,
    totalPerWeek: total,
  );
}

class _Stage3RemainderSlots extends StatefulWidget {
  const _Stage3RemainderSlots({
    required this.rules,
    required this.assignments,
    required this.subjects,
    required this.config,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final TimetableRules rules;
  final List<SolverAssignment> assignments;
  final List<WizardSubject> subjects;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool isDark;
  final void Function(TimetableRules) onChanged;

  @override
  State<_Stage3RemainderSlots> createState() => _Stage3RemainderSlotsState();
}

class _Stage3RemainderSlotsState extends State<_Stage3RemainderSlots> {
  // Expanded state keyed by grade int as string for grade rows,
  // and "${grade}_${stream ?? 'null'}" for stream rows.
  final Map<String, bool> _expandedGrades = {};
  final Map<String, bool> _expandedStreams = {};

  String _subjectName(int sid) {
    try {
      return widget.subjects.firstWhere((s) => s.id == sid).name;
    } catch (_) {
      return 'Subject $sid';
    }
  }

  void _onReorder(String streamKey, List<int> newOrder) {
    final updated = Map<String, List<int>>.from(widget.rules.remainderPriority);
    updated[streamKey] = newOrder;
    widget.onChanged(widget.rules.copyWith(remainderPriority: updated));
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final rules = widget.rules;

    // Group assignments by grade, then by stream.
    final gradeGroups = <int, Map<int?, List<SolverAssignment>>>{};
    for (final a in widget.assignments) {
      gradeGroups
          .putIfAbsent(a.grade, () => {})
          .putIfAbsent(a.stream, () => [])
          .add(a);
    }

    if (gradeGroups.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('Remainder Slots'),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No subject assignments found for this term.',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedGrades = gradeGroups.keys.toList()..sort();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const _SectionLabel('Remainder Slots'),
            const SizedBox(height: 0),
            Text(
              'Subjects with remainder lessons appear first. Drag to reprioritise.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 8),
            for (final grade in sortedGrades)
              _buildGradeSection(grade, gradeGroups[grade]!, cs, isDark, rules),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSection(
    int grade,
    Map<int?, List<SolverAssignment>> streamGroups,
    ColorScheme cs,
    bool isDark,
    TimetableRules rules,
  ) {
    final gradeKey = '$grade';
    final isExpanded = _expandedGrades[gradeKey] ?? false;
    final streamCount = streamGroups.length;

    return _WizardEntityRow(
      name: gradeLabel(grade, config: widget.config),
      subtitle: '$streamCount stream${streamCount == 1 ? '' : 's'}',
      icon: Icons.school_outlined,
      isExpanded: isExpanded,
      cs: cs,
      isDark: isDark,
      onTap: () => setState(() => _expandedGrades[gradeKey] = !isExpanded),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stream
              in (streamGroups.keys.toList()
                ..sort((a, b) => (a ?? 0).compareTo(b ?? 0))))
            _buildStreamSection(
              grade,
              stream,
              streamGroups[stream]!,
              cs,
              isDark,
              rules,
            ),
        ],
      ),
    );
  }

  Widget _buildStreamSection(
    int grade,
    int? stream,
    List<SolverAssignment> streamAssignments,
    ColorScheme cs,
    bool isDark,
    TimetableRules rules,
  ) {
    final streamKey = '${grade}_${stream ?? 'null'}';
    final isExpanded = _expandedStreams[streamKey] ?? false;
    final subjects = streamAssignments.map((a) => a.subjectId).toSet().toList();
    final r = _computeRemainder(rules: rules, subjectCount: subjects.length);

    // Build priority order (from rules or default ascending).
    final savedOrder = rules.remainderPriority[streamKey];
    final orderedSubjects = savedOrder != null
        ? savedOrder.where((sid) => subjects.contains(sid)).toList()
        : (List<int>.from(subjects)..sort());
    // Append any subjects not yet in the ordered list (newly added).
    for (final sid in subjects) {
      if (!orderedSubjects.contains(sid)) orderedSubjects.add(sid);
    }

    String? resolvedName;
    if (stream != null) {
      for (final c in widget.config.curricula) {
        final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
        if (gc != null) {
          final s = gc.streams.where((s) => s.code == stream).firstOrNull;
          if (s != null) {
            resolvedName = s.name;
            break;
          }
        }
      }
    }
    final streamLabel = stream == null
        ? 'All'
        : (resolvedName ?? 'Stream $stream');

    return _WizardEntityRow(
      name: streamLabel,
      subtitle:
          '${r.totalPerWeek} lessons \u00B7 ${subjects.length} subjects'
          ' \u00B7 ${r.base} base + ${r.remainder} extra',
      icon: Icons.group_outlined,
      isExpanded: isExpanded,
      cs: cs,
      isDark: isDark,
      onTap: () => setState(() => _expandedStreams[streamKey] = !isExpanded),
      expandedContent: Container(
        decoration: BoxDecoration(
          color: AppTheme.nestedBg(isDark, cs),
          border: Border(
            left: BorderSide(
              color: cs.primary.withValues(alpha: 0.2),
              width: 3,
            ),
          ),
        ),
        child: orderedSubjects.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No subjects assigned.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              )
            : ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final newOrder = List<int>.from(orderedSubjects);
                  final item = newOrder.removeAt(oldIndex);
                  newOrder.insert(newIndex, item);
                  _onReorder(streamKey, newOrder);
                },
                itemCount: orderedSubjects.length,
                itemBuilder: (ctx, i) {
                  final sid = orderedSubjects[i];
                  final isExtra = i < r.remainder;
                  return _RemainderSubjectTile(
                    key: ValueKey(sid),
                    index: i,
                    name: _subjectName(sid),
                    isExtra: isExtra,
                    cs: cs,
                    isDark: isDark,
                  );
                },
              ),
      ),
    );
  }
}

class _RemainderSubjectTile extends StatelessWidget {
  const _RemainderSubjectTile({
    super.key,
    required this.index,
    required this.name,
    required this.isExtra,
    required this.cs,
    required this.isDark,
  });

  final int index;
  final String name;
  final bool isExtra;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.nestedBg(isDark, cs),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_handle_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isExtra) _DiffBadge(label: '+1', color: AppTheme.brandGreen),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 4 — Review & Generate
// ─────────────────────────────────────────────────────────────────────────────

class _Stage3Generate extends StatefulWidget {
  const _Stage3Generate({
    required this.rules,
    required this.conflicts,
    required this.teachers,
    required this.subjects,
    required this.generating,
    required this.result,
    required this.cs,
    required this.isDark,
    required this.onConflictResolved,
    required this.onGenerate,
    required this.onComplete,
  });

  final TimetableRules rules;
  final List<ConflictPair> conflicts;
  final List<WizardTeacher> teachers;
  final List<WizardSubject> subjects;
  final bool generating;
  final GeneratorResult? result;
  final ColorScheme cs;
  final bool isDark;
  final void Function(ConflictPair, bool teacherWins) onConflictResolved;
  final Future<void> Function() onGenerate;
  final VoidCallback onComplete;

  @override
  State<_Stage3Generate> createState() => _Stage3GenerateState();
}

class _Stage3GenerateState extends State<_Stage3Generate> {
  Timer? _statusTimer;
  int _statusIndex = 0;
  static const _statusMessages = [
    'Analysing subjects\u2026',
    'Building slot matrix\u2026',
    'Resolving constraints\u2026',
    'Optimising schedule\u2026',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_Stage3Generate old) {
    super.didUpdateWidget(old);
    if (widget.generating && !old.generating) {
      _statusIndex = 0;
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (mounted) {
          setState(
            () => _statusIndex = (_statusIndex + 1) % _statusMessages.length,
          );
        }
      });
    }
    if (!widget.generating && old.generating) {
      _statusTimer?.cancel();
      _statusTimer = null;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  String _teacherName(String id) =>
      widget.teachers.where((t) => t.id == id).map((t) => t.name).firstOrNull ??
      id;

  String _subjectName(int id) =>
      widget.subjects.where((s) => s.id == id).map((s) => s.name).firstOrNull ??
      'Subject $id';

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final hasConflicts = widget.conflicts.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (hasConflicts)
            _ConflictSection(
              conflicts: widget.conflicts,
              teacherNameOf: _teacherName,
              subjectNameOf: _subjectName,
              cs: cs,
              isDark: isDark,
              onConflictResolved: widget.onConflictResolved,
            )
          else
            _SummarySection(rules: widget.rules, cs: cs, isDark: isDark),
          _GenerateSection(
            generating: widget.generating,
            result: widget.result,
            statusMessage: _statusMessages[_statusIndex],
            cs: cs,
            isDark: isDark,
            onGenerate: widget.onGenerate,
            onComplete: widget.onComplete,
          ),
        ],
      ),
    );
  }
}

// ── Summary section ───────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.rules,
    required this.cs,
    required this.isDark,
  });

  final TimetableRules rules;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final slotCount = rules.buildLessonSlots().length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          label: 'Days',
          value: '${rules.activeDays.length}',
          cs: cs,
          isDark: isDark,
        ),
        _StatChip(
          label: 'Slots/Day',
          value: '$slotCount',
          cs: cs,
          isDark: isDark,
        ),
        _StatChip(
          label: 'Teacher rules',
          value: '${rules.teacherConstraints.length}',
          cs: cs,
          isDark: isDark,
        ),
        _StatChip(
          label: 'Subject rules',
          value: '${rules.subjectConstraints.length}',
          cs: cs,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.borderColor(isDark, cs)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Conflict section ──────────────────────────────────────────────────────────

class _ConflictSection extends StatelessWidget {
  const _ConflictSection({
    required this.conflicts,
    required this.teacherNameOf,
    required this.subjectNameOf,
    required this.cs,
    required this.isDark,
    required this.onConflictResolved,
  });

  final List<ConflictPair> conflicts;
  final String Function(String) teacherNameOf;
  final String Function(int) subjectNameOf;
  final ColorScheme cs;
  final bool isDark;
  final void Function(ConflictPair, bool teacherWins) onConflictResolved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          'Conflicts Detected',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
            ),
            child: Text(
              '${conflicts.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: conflicts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final cp = conflicts[i];
            return _ConflictCard(
              conflict: cp,
              teacherName: teacherNameOf(cp.teacherEntry.teacherId),
              subjectName: subjectNameOf(cp.subjectEntry.subjectId),
              cs: cs,
              isDark: isDark,
              onChanged: (v) => onConflictResolved(cp, v),
            );
          },
        ),
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.teacherName,
    required this.subjectName,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });

  final ConflictPair conflict;
  final String teacherName;
  final String subjectName;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<bool> onChanged; // true = teacher wins

  @override
  Widget build(BuildContext context) {
    final tc = conflict.teacherEntry;
    final sc = conflict.subjectEntry;
    final tcLabel = tc.isBlock ? 'Block' : 'Require';
    final scLabel = sc.isBlock ? 'Block' : 'Require';
    final muted = cs.onSurfaceVariant.withValues(alpha: 0.45);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher row
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Teacher: $teacherName',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _ConstraintTypeBadge(label: tcLabel, isBlock: tc.isBlock, cs: cs),
            ],
          ),
          const SizedBox(height: 4),
          // Subject row
          Row(
            children: [
              Icon(Icons.book_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Subject: $subjectName',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _ConstraintTypeBadge(label: scLabel, isBlock: sc.isBlock, cs: cs),
            ],
          ),
          const SizedBox(height: 10),
          // Priority picker
          const _SectionLabel('Which takes priority?'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PriorityChip(
                  label: teacherName,
                  selected: conflict.teacherWins,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PriorityChip(
                  label: subjectName,
                  selected: !conflict.teacherWins,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConstraintTypeBadge extends StatelessWidget {
  const _ConstraintTypeBadge({
    required this.label,
    required this.isBlock,
    required this.cs,
  });

  final String label;
  final bool isBlock;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isBlock
            ? cs.error.withValues(alpha: 0.10)
            : cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: isBlock ? cs.error : cs.primary,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.45)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Generate section ──────────────────────────────────────────────────────────

class _GenerateSection extends StatelessWidget {
  const _GenerateSection({
    required this.generating,
    required this.result,
    required this.statusMessage,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
    required this.onComplete,
  });

  final bool generating;
  final GeneratorResult? result;
  final String statusMessage;
  final ColorScheme cs;
  final bool isDark;
  final Future<void> Function() onGenerate;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (result == null && !generating)
          _GenerateButton(onGenerate: onGenerate)
        else if (generating)
          _GeneratingIndicator(statusMessage: statusMessage, cs: cs)
        else if (result is GeneratorSuccess)
          _SuccessPanel(
            result: result! as GeneratorSuccess,
            cs: cs,
            isDark: isDark,
            onGenerate: onGenerate,
            onComplete: onComplete,
          )
        else if (result is GeneratorFailure)
          _FailurePanel(
            result: result! as GeneratorFailure,
            cs: cs,
            isDark: isDark,
            onGenerate: onGenerate,
          ),
      ],
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onGenerate});

  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onGenerate,
      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: const Text('Generate Timetable'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.brandGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator({required this.statusMessage, required this.cs});

  final String statusMessage;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            statusMessage,
            key: ValueKey(statusMessage),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.result,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
    required this.onComplete,
  });

  final GeneratorSuccess result;
  final ColorScheme cs;
  final bool isDark;
  final Future<void> Function() onGenerate;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final dayCount = result.slots.map((s) => s.day).toSet().length;
    final ms = result.elapsed.inMilliseconds;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.brandGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: AppTheme.brandGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Timetable ready!',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.slots.length} slots across $dayCount days  \u00B7  ${ms}ms',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onGenerate,
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                child: const Text('Regenerate'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Apply Timetable \u2192'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({
    required this.result,
    required this.cs,
    required this.isDark,
    required this.onGenerate,
  });

  final GeneratorFailure result;
  final ColorScheme cs;
  final bool isDark;
  final Future<void> Function() onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Text(
                'Could not generate',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.reason,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onGenerate,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}
