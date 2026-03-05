import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/departments_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';

import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_tab_bar.dart' show EduTab, EduTabBarBottom;
import '../exams/exams_grades_screen.dart';
import 'grade_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class AcademicsScreen extends StatelessWidget {
  const AcademicsScreen({super.key, required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return _AcademicsGradeTree(schoolContext: schoolContext);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade/Stream Tree — the new Academics landing page
// ─────────────────────────────────────────────────────────────────────────────

class _AcademicsGradeTree extends StatefulWidget {
  const _AcademicsGradeTree({required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  State<_AcademicsGradeTree> createState() => _AcademicsGradeTreeState();
}

class _AcademicsGradeTreeState extends State<_AcademicsGradeTree> {
  SchoolConfig? _config;
  StreamSubscription<Setting?>? _settingsSub;
  bool _loading = true;

  String get _schoolId => widget.schoolContext.membership.school.id;

  @override
  void initState() {
    super.initState();
    _settingsSub = settingsDao.watchSettings(_schoolId).listen((setting) {
      if (!mounted) return;
      SchoolConfig config = SchoolConfig.defaults();
      if (setting != null) {
        try {
          final decoded = jsonDecode(setting.data);
          if (decoded is Map<String, dynamic>) {
            config = SchoolConfig.fromJson(decoded);
          }
        } catch (_) {}
      }
      setState(() {
        _config = config;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  Future<void> _saveConfig(SchoolConfig config) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await settingsDao.updateSchoolConfig(_schoolId, config, accountId: user.id);
  }

  // ── Add grade ──────────────────────────────────────────────────────────────

  void _showAddGradeSheet() {
    final config = _config;
    if (config == null) return;

    // Determine which curricula are enabled
    if (config.curricula.isEmpty) {
      // No curricula — show curriculum picker first
      _showAddCurriculumAndGradeSheet();
      return;
    }

    if (config.curricula.length == 1) {
      // Single curriculum — go directly to grade picker
      _showGradePickerForCurriculum(config.curricula.first);
    } else {
      // Multiple curricula — let user pick which one
      _showCurriculumChooser();
    }
  }

  void _showAddCurriculumAndGradeSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => _CurriculumSetupSheet(
        onCurriculumSelected: (type) {
          Navigator.pop(ctx);
          // Create a new curriculum config and show grade picker
          final newCurr = CurriculumConfig(type: type, grades: []);
          _showGradePickerForNewCurriculum(newCurr);
        },
      ),
    );
  }

  void _showCurriculumChooser() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add grade to…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              for (final curr in _config!.curricula)
                _SheetOption(
                  label: curr.type == CurriculumType.cbc ? 'CBC' : '8-4-4',
                  subtitle:
                      '${curr.grades.length} grade${curr.grades.length == 1 ? '' : 's'} configured',
                  icon: Icons.school_outlined,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showGradePickerForCurriculum(curr);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGradePickerForCurriculum(CurriculumConfig curriculum) {
    final labels = gradeLabelsFor(curriculum.type);
    final usedGrades = curriculum.grades.map((g) => g.grade).toSet();
    final available =
        labels.entries.where((e) => !usedGrades.contains(e.key)).toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All grades for ${curriculum.type == CurriculumType.cbc ? "CBC" : "8-4-4"} are already added.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => _GradePickerSheet(
        available: available,
        curriculumLabel: curriculum.type == CurriculumType.cbc
            ? 'CBC'
            : '8-4-4',
        onGradeSelected: (gradeNum) {
          Navigator.pop(ctx);
          _addGradeToCurriculum(curriculum.type, gradeNum);
        },
      ),
    );
  }

  void _showGradePickerForNewCurriculum(CurriculumConfig newCurr) {
    final labels = gradeLabelsFor(newCurr.type);
    final available = labels.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => _GradePickerSheet(
        available: available,
        curriculumLabel: newCurr.type == CurriculumType.cbc ? 'CBC' : '8-4-4',
        onGradeSelected: (gradeNum) {
          Navigator.pop(ctx);
          _addGradeToNewCurriculum(newCurr.type, gradeNum);
        },
      ),
    );
  }

  Future<void> _addGradeToCurriculum(CurriculumType type, int gradeNum) async {
    final config = _config;
    if (config == null) return;

    final updated = config.copyWith(
      curricula: config.curricula.map((c) {
        if (c.type != type) return c;
        final newGrades = [
          ...c.grades,
          GradeConfig(grade: gradeNum, streams: []),
        ]..sort((a, b) => a.grade.compareTo(b.grade));
        return c.copyWith(grades: newGrades);
      }).toList(),
    );
    await _saveConfig(updated);
  }

  Future<void> _addGradeToNewCurriculum(
    CurriculumType type,
    int gradeNum,
  ) async {
    final config = _config ?? SchoolConfig.defaults();
    final newCurr = CurriculumConfig(
      type: type,
      grades: [GradeConfig(grade: gradeNum, streams: [])],
    );
    final updated = config.copyWith(curricula: [...config.curricula, newCurr]);
    await _saveConfig(updated);
  }

  // ── Delete grade ───────────────────────────────────────────────────────────

  Future<void> _deleteGrade(CurriculumType type, int gradeNum) async {
    final config = _config;
    if (config == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final label = gradeLabelsFor(type)[gradeNum] ?? 'Grade $gradeNum';
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Remove $label?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          content: Text(
            'This will remove the grade and all its stream definitions from the school configuration. '
            'Existing enrollments and records are not affected.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Remove',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.error,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final updatedCurricula = config.curricula
        .map((c) {
          if (c.type != type) return c;
          return c.copyWith(
            grades: c.grades.where((g) => g.grade != gradeNum).toList(),
          );
        })
        .where((c) => c.grades.isNotEmpty)
        .toList();

    await _saveConfig(config.copyWith(curricula: updatedCurricula));
  }

  // ── Add stream ─────────────────────────────────────────────────────────────

  void _showAddStreamDialog(CurriculumType type, GradeConfig grade) {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Add stream to ${gradeLabelsFor(type)[grade.grade] ?? "Grade ${grade.grade}"}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Green, Blue, North, A',
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: cs.primary, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name required';
              if (grade.streams.any(
                (s) => s.name.toLowerCase() == v.trim().toLowerCase(),
              )) {
                return 'Stream already exists';
              }
              return null;
            },
            onFieldSubmitted: (_) =>
                _submitAddStream(ctx, formKey, nameCtrl, type, grade),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                _submitAddStream(ctx, formKey, nameCtrl, type, grade),
            child: Text(
              'Add',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAddStream(
    BuildContext ctx,
    GlobalKey<FormState> formKey,
    TextEditingController nameCtrl,
    CurriculumType type,
    GradeConfig grade,
  ) async {
    if (!formKey.currentState!.validate()) return;
    final name = nameCtrl.text.trim();

    // Auto-assign code: max existing code + 1, or 1 if none
    final nextCode = grade.streams.isEmpty
        ? 1
        : grade.streams.map((s) => s.code).reduce((a, b) => a > b ? a : b) + 1;

    final newStream = GradeStream(name: name, code: nextCode);
    final config = _config;
    if (config == null) return;

    final updated = config.copyWith(
      curricula: config.curricula.map((c) {
        if (c.type != type) return c;
        return c.copyWith(
          grades: c.grades.map((g) {
            if (g.grade != grade.grade) return g;
            return g.copyWith(streams: [...g.streams, newStream]);
          }).toList(),
        );
      }).toList(),
    );

    Navigator.pop(ctx);
    await _saveConfig(updated);
  }

  // ── Edit streams (batch rename) ────────────────────────────────────────────

  void _showEditStreamsSheet(CurriculumType type, GradeConfig grade) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => _EditStreamsSheet(
        type: type,
        grade: grade,
        gradeLabel: gradeLabelsFor(type)[grade.grade] ?? 'Grade ${grade.grade}',
        onSave: (updatedStreams) async {
          Navigator.pop(ctx);
          final config = _config;
          if (config == null) return;

          final updated = config.copyWith(
            curricula: config.curricula.map((c) {
              if (c.type != type) return c;
              return c.copyWith(
                grades: c.grades.map((g) {
                  if (g.grade != grade.grade) return g;
                  return g.copyWith(streams: updatedStreams);
                }).toList(),
              );
            }).toList(),
          );
          await _saveConfig(updated);
        },
      ),
    );
  }

  // ── Navigate to grade detail ───────────────────────────────────────────────

  void _navigateToGradeDetail(CurriculumType type, GradeConfig grade) {
    final label = gradeLabelsFor(type)[grade.grade] ?? 'Grade ${grade.grade}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTermProvider(
          termContext: ActiveTermProvider.read(context),
          child: GradeDetailPage(
            schoolContext: widget.schoolContext,
            curriculumType: type,
            grade: grade,
            gradeLabel: label,
          ),
        ),
      ),
    );
  }

  // ── Departments overlay ────────────────────────────────────────────────────

  void _openDepartments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DepartmentsFullScreen(schoolId: _schoolId),
      ),
    );
  }

  // ── Exams & Grades overlay ─────────────────────────────────────────────────

  void _openExamsGrades() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTermProvider(
          termContext: ActiveTermProvider.read(context),
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Exams & Grades',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            body: ExamsGradesScreen(schoolContext: widget.schoolContext),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
    }

    final config = _config ?? SchoolConfig.defaults();

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ── Header bar with action links ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Academics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    _HeaderAction(
                      icon: Icons.domain_outlined,
                      label: 'Departments',
                      onTap: _openDepartments,
                    ),
                    const SizedBox(width: 4),
                    _HeaderAction(
                      icon: Icons.assignment_outlined,
                      label: 'Exams',
                      onTap: _openExamsGrades,
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            if (config.isEmpty)
              SliverFillRemaining(
                child: _EmptyConfigState(onAdd: _showAddGradeSheet),
              )
            else
              ..._buildCurriculaSlivers(config, cs, isDark),

            // Bottom padding for FAB
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),

        // ── FAB ──────────────────────────────────────────────────────────
        if (!config.isEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: _AddGradeFab(onTap: _showAddGradeSheet),
          ),
      ],
    );
  }

  List<Widget> _buildCurriculaSlivers(
    SchoolConfig config,
    ColorScheme cs,
    bool isDark,
  ) {
    final showHeaders = config.curricula.length > 1;
    final List<Widget> slivers = [];

    for (final curriculum in config.curricula) {
      if (showHeaders) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      curriculum.type == CurriculumType.cbc ? 'CBC' : '8-4-4',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${curriculum.grades.length} grade${curriculum.grades.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, showHeaders ? 4 : 12, 16, 0),
          sliver: SliverList.builder(
            itemCount: curriculum.grades.length,
            itemBuilder: (context, index) {
              final grade = curriculum.grades[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GradeCard(
                  curriculumType: curriculum.type,
                  grade: grade,
                  gradeLabel:
                      gradeLabelsFor(curriculum.type)[grade.grade] ??
                      'Grade ${grade.grade}',
                  onTap: () => _navigateToGradeDetail(curriculum.type, grade),
                  onAddStream: () =>
                      _showAddStreamDialog(curriculum.type, grade),
                  onEditStreams: grade.streams.isNotEmpty
                      ? () => _showEditStreamsSheet(curriculum.type, grade)
                      : null,
                  onDelete: () => _deleteGrade(curriculum.type, grade.grade),
                ),
              );
            },
          ),
        ),
      );
    }

    return slivers;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade Card
// ─────────────────────────────────────────────────────────────────────────────

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.curriculumType,
    required this.grade,
    required this.gradeLabel,
    required this.onTap,
    required this.onAddStream,
    this.onEditStreams,
    required this.onDelete,
  });

  final CurriculumType curriculumType;
  final GradeConfig grade;
  final String gradeLabel;
  final VoidCallback onTap;
  final VoidCallback onAddStream;
  final VoidCallback? onEditStreams;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
          : cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Grade label + actions ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          gradeLabel,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                  ),
                  // Action icons
                  _CardIconBtn(
                    icon: Icons.add_rounded,
                    tooltip: 'Add stream',
                    onTap: onAddStream,
                  ),
                  if (onEditStreams != null)
                    _CardIconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit streams',
                      onTap: onEditStreams!,
                    ),
                  _CardIconBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Remove grade',
                    onTap: onDelete,
                    isDestructive: true,
                  ),
                ],
              ),

              // ── Stream chips ──────────────────────────────────────────
              const SizedBox(height: 8),
              if (grade.streams.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(
                    'No streams',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: grade.streams.map((stream) {
                    return _StreamChip(name: stream.name);
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
// Stream Chip — solid, embedded element on a grade card
// ─────────────────────────────────────────────────────────────────────────────

class _StreamChip extends StatelessWidget {
  const _StreamChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withValues(alpha: 0.7) : cs.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurface.withValues(alpha: 0.85),
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card icon button — compact action icon on grade cards
// ─────────────────────────────────────────────────────────────────────────────

class _CardIconBtn extends StatelessWidget {
  const _CardIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive
        ? cs.error.withValues(alpha: 0.6)
        : cs.onSurfaceVariant.withValues(alpha: 0.45);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header action link (Departments, Exams)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: cs.primary.withValues(alpha: 0.8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.primary.withValues(alpha: 0.8),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB — Add grade
// ─────────────────────────────────────────────────────────────────────────────

class _AddGradeFab extends StatelessWidget {
  const _AddGradeFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: cs.primary,
        borderRadius: BorderRadius.circular(6),
        elevation: 3,
        shadowColor: cs.primary.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Icon(Icons.add_rounded, size: 22, color: cs.onPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty config state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyConfigState extends StatelessWidget {
  const _EmptyConfigState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // ignore: unused_local_variable
    final isDark = cs.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_tree_outlined,
                size: 24,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Configure your grade structure',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add grades and streams to organise\nyour school\'s academic hierarchy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Material(
              color: cs.primary,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    'Add First Grade',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Curriculum setup sheet — first-time picking CBC / 8-4-4
// ─────────────────────────────────────────────────────────────────────────────

class _CurriculumSetupSheet extends StatelessWidget {
  const _CurriculumSetupSheet({required this.onCurriculumSelected});
  final ValueChanged<CurriculumType> onCurriculumSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3.5,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select curriculum',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the curriculum system your school follows. You can add the other one later.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _SheetOption(
              label: 'CBC — Competency Based Curriculum',
              subtitle: 'PP1, PP2, Grade 1–12',
              icon: Icons.school_outlined,
              onTap: () => onCurriculumSelected(CurriculumType.cbc),
            ),
            const SizedBox(height: 6),
            _SheetOption(
              label: '8-4-4 System',
              subtitle: 'Standard 1–8, Form 1–4',
              icon: Icons.school_outlined,
              onTap: () => onCurriculumSelected(CurriculumType.eightFourFour),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet option row
// ─────────────────────────────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GradePickerSheet extends StatelessWidget {
  const _GradePickerSheet({
    required this.available,
    required this.curriculumLabel,
    required this.onGradeSelected,
  });

  final List<MapEntry<int, String>> available;
  final String curriculumLabel;
  final ValueChanged<int> onGradeSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add grade — $curriculumLabel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final entry = available[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                            : cs.surfaceContainerHighest.withValues(
                                alpha: 0.25,
                              ),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: () => onGradeSelected(entry.key),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: cs.primary.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit streams sheet — batch rename/delete streams within a grade
// ─────────────────────────────────────────────────────────────────────────────

class _EditStreamsSheet extends StatefulWidget {
  const _EditStreamsSheet({
    required this.type,
    required this.grade,
    required this.gradeLabel,
    required this.onSave,
  });

  final CurriculumType type;
  final GradeConfig grade;
  final String gradeLabel;
  final Future<void> Function(List<GradeStream> streams) onSave;

  @override
  State<_EditStreamsSheet> createState() => _EditStreamsSheetState();
}

class _EditStreamsSheetState extends State<_EditStreamsSheet> {
  late List<_EditableStream> _streams;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _streams = widget.grade.streams
        .map(
          (s) => _EditableStream(
            code: s.code,
            controller: TextEditingController(text: s.name),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final s in _streams) {
      s.controller.dispose();
    }
    super.dispose();
  }

  void _removeStream(int index) {
    setState(() {
      _streams[index].controller.dispose();
      _streams.removeAt(index);
    });
  }

  Future<void> _save() async {
    // Validate — no empty names, no duplicates
    final names = <String>{};
    for (final s in _streams) {
      final name = s.controller.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stream names cannot be empty.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!names.add(name.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicate stream name: "$name"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final result = _streams
        .map((s) => GradeStream(name: s.controller.text.trim(), code: s.code))
        .toList();
    await widget.onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3.5,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit streams — ${widget.gradeLabel}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (!_saving)
                  InkWell(
                    onTap: _save,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_streams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'All streams removed. Save to confirm.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...List.generate(_streams.length, (i) {
                final s = _streams[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: s.controller,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Stream name',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? cs.surfaceContainerHighest.withValues(
                                    alpha: 0.4,
                                  )
                                : cs.surfaceContainerHighest.withValues(
                                    alpha: 0.3,
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                            prefixText: '${s.code}  ',
                            prefixStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _removeStream(i),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: cs.error.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _EditableStream {
  _EditableStream({required this.code, required this.controller});
  final int code;
  final TextEditingController controller;
}

// ─────────────────────────────────────────────────────────────────────────────
// Departments — full-screen overlay (pushed route)
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentsFullScreen extends StatefulWidget {
  const _DepartmentsFullScreen({required this.schoolId});
  final String schoolId;

  @override
  State<_DepartmentsFullScreen> createState() => _DepartmentsFullScreenState();
}

class _DepartmentsFullScreenState extends State<_DepartmentsFullScreen> {
  late final DepartmentsDao _dao;

  @override
  void initState() {
    super.initState();
    _dao = DepartmentsDao(db);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Departments',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, size: 20, color: cs.primary),
            tooltip: 'Create department',
            onPressed: () => _showCreateSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Department>>(
        stream: _dao.watchDepartments(widget.schoolId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 1.5),
            );
          }
          final depts = snap.data!;
          if (depts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.domain_outlined,
                      size: 22,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No departments',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create one to organise teachers and staff.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: depts.length,
            itemBuilder: (context, index) {
              final dept = depts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: isDark
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _DepartmentDetailScreen(
                            dept: dept,
                            schoolId: widget.schoolId,
                            dao: _dao,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dept.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (dept.description != null &&
                                    dept.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      dept.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) =>
          _CreateDepartmentSheet(schoolId: widget.schoolId, dao: _dao),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Department Detail Screen — teachers + staff lists
// ─────────────────────────────────────────────────────────────────────────────

class _DepartmentDetailScreen extends StatefulWidget {
  const _DepartmentDetailScreen({
    required this.dept,
    required this.schoolId,
    required this.dao,
  });

  final Department dept;
  final String schoolId;
  final DepartmentsDao dao;

  @override
  State<_DepartmentDetailScreen> createState() =>
      _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<_DepartmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.dept.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: cs.error.withValues(alpha: 0.7),
            ),
            tooltip: 'Delete department',
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: EduTabBarBottom(
          controller: _tab,
          tabs: const [
            EduTab(label: 'Teachers'),
            EduTab(label: 'Staff'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _DeptMemberList<({TeachersData teacher, UsersData user})>(
            stream: widget.dao.watchTeachersInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            emptyLabel: 'No teachers assigned',
            nameOf: (item) => item.user.name,
            statusOf: (item) => item.teacher.status.name,
            onAssign: () => _showAssignTeacher(context),
            onRemove: (item) => _removeTeacher(item.teacher.user),
          ),
          _DeptMemberList<({StaffData staff, UsersData user})>(
            stream: widget.dao.watchStaffInDept(
              widget.schoolId,
              widget.dept.name,
            ),
            emptyLabel: 'No staff assigned',
            nameOf: (item) => item.user.name,
            statusOf: (item) => item.staff.status.name,
            onAssign: () => _showAssignStaff(context),
            onRemove: (item) => _removeStaff(item.staff.user),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Delete "${widget.dept.name}"?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        content: Text(
          'This department will be permanently removed.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = cache.currentUser?.user;
      if (user != null) {
        await widget.dao.deleteDepartment(
          widget.schoolId,
          widget.dept.name,
          accountId: user.id,
        );
      }
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showAssignTeacher(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) =>
          _AssignMemberSheet<({TeachersData teacher, UsersData user})>(
            title: 'Assign Teacher',
            stream: widget.dao.watchUnassignedTeachers(widget.schoolId),
            nameOf: (item) => item.user.name,
            onAssign: (item) async {
              final user = cache.currentUser?.user;
              if (user == null) return;
              await widget.dao.assignTeacherToDepartment(
                widget.schoolId,
                item.teacher.user,
                departmentName: widget.dept.name,
                accountId: user.id,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
    );
  }

  void _showAssignStaff(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (ctx) => _AssignMemberSheet<({StaffData staff, UsersData user})>(
        title: 'Assign Staff',
        stream: widget.dao.watchUnassignedStaff(widget.schoolId),
        nameOf: (item) => item.user.name,
        onAssign: (item) async {
          final user = cache.currentUser?.user;
          if (user == null) return;
          await widget.dao.assignStaffToDepartment(
            widget.schoolId,
            item.staff.user,
            departmentName: widget.dept.name,
            accountId: user.id,
          );
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _removeTeacher(String teacherUserId) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await widget.dao.assignTeacherToDepartment(
      widget.schoolId,
      teacherUserId,
      departmentName: null,
      accountId: user.id,
    );
  }

  Future<void> _removeStaff(String staffUserId) async {
    final user = cache.currentUser?.user;
    if (user == null) return;
    await widget.dao.assignStaffToDepartment(
      widget.schoolId,
      staffUserId,
      departmentName: null,
      accountId: user.id,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dept member list — reusable for teachers + staff
// ─────────────────────────────────────────────────────────────────────────────

class _DeptMemberList<T> extends StatelessWidget {
  const _DeptMemberList({
    required this.stream,
    required this.emptyLabel,
    required this.nameOf,
    required this.statusOf,
    required this.onAssign,
    required this.onRemove,
  });

  final Stream<List<T>> stream;
  final String emptyLabel;
  final String Function(T) nameOf;
  final String Function(T) statusOf;
  final VoidCallback onAssign;
  final void Function(T) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${items.length} member${items.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onAssign,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 15, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Assign',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    emptyLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _MemberRow(
                      name: nameOf(item),
                      statusLabel: statusOf(item),
                      onRemove: () => onRemove(item),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.statusLabel,
    required this.onRemove,
  });

  final String name;
  final String statusLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                    ),
                    if (statusLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: cs.error.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assign member sheet — picks from unassigned teachers/staff
// ─────────────────────────────────────────────────────────────────────────────

class _AssignMemberSheet<T> extends StatelessWidget {
  const _AssignMemberSheet({
    required this.title,
    required this.stream,
    required this.nameOf,
    required this.onAssign,
  });

  final String title;
  final Stream<List<T>> stream;
  final String Function(T) nameOf;
  final Future<void> Function(T) onAssign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: StreamBuilder<List<T>>(
                  stream: stream,
                  builder: (context, snap) {
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No unassigned members available.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final displayName = nameOf(item);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: isDark
                                ? cs.surfaceContainerHighest.withValues(
                                    alpha: 0.35,
                                  )
                                : cs.surfaceContainerHighest.withValues(
                                    alpha: 0.25,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              onTap: () => onAssign(item),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Department Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateDepartmentSheet extends StatefulWidget {
  const _CreateDepartmentSheet({required this.schoolId, required this.dao});
  final String schoolId;
  final DepartmentsDao dao;

  @override
  State<_CreateDepartmentSheet> createState() => _CreateDepartmentSheetState();
}

class _CreateDepartmentSheetState extends State<_CreateDepartmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = cache.currentUser?.user;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      final nowSec = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.createDepartment(
        DepartmentsCompanion(
          school: Value(widget.schoolId),
          name: Value(_nameCtrl.text.trim()),
          description: Value(
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          ),
          created: Value(nowSec),
          updated: Value(nowSec),
        ),
        accountId: user.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create department: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Department',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: _inputDeco(
                  cs: cs,
                  isDark: isDark,
                  hint: 'Department name',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                decoration: _inputDeco(
                  cs: cs,
                  isDark: isDark,
                  hint: 'Description (optional)',
                ),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: _saving ? null : _save,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Center(
                        child: _saving
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: cs.onPrimary,
                                ),
                              )
                            : Text(
                                'Create',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — input decoration
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDeco({
  required ColorScheme cs,
  required bool isDark,
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
    ),
    filled: true,
    fillColor: isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
        : cs.surfaceContainerHighest.withValues(alpha: 0.3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.primary, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.error.withValues(alpha: 0.5)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}
