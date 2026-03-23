import 'package:flutter/material.dart' hide Action;

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/curriculum_subjects.dart';

import '../../../../models/membership.dart';
import '../../../../models/permissions.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_form_field.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../widgets/edu_confirm_dialog.dart';

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
// Grade/Stream Tree — the Academics landing page
// ─────────────────────────────────────────────────────────────────────────────

class _AcademicsGradeTree extends StatefulWidget {
  const _AcademicsGradeTree({required this.schoolContext});
  final SchoolContext schoolContext;

  @override
  State<_AcademicsGradeTree> createState() => _AcademicsGradeTreeState();
}

class _AcademicsGradeTreeState extends State<_AcademicsGradeTree> {
  String get _schoolId => widget.schoolContext.membership.school.id;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Determines which curriculum a grade number belongs to based on the
  /// numbering convention:
  ///   CBC: 1–14  (PP1=1, PP2=2, Grade 1–9 = 3–11, Grade 10–12 = 12–14)
  ///   8-4-4: 1–8 (Standard 1–8) and 41–44 (Form 1–4)
  ///
  /// Grade numbers 1–8 are ambiguous — they exist in both systems. We resolve
  /// ambiguity by checking if any grade ≥ 41 exists (which means 8-4-4 is in
  /// use) or any grade ≥ 9 exists (which means CBC is in use). Grade numbers
  /// 41–44 are unambiguously 8-4-4. Grade numbers 9–14 are unambiguously CBC.
  ///
  /// For simplicity when the set of grades is unknown, we default ambiguous
  /// grades (1–8) to CBC. The curriculum chooser UI always creates at least
  /// one grade, so the grouping will self-correct as grades are added.
  CurriculumType _curriculumForGrade(int grade, Set<int> allGrades) {
    // Unambiguous: Form grades are always 8-4-4.
    if (grade >= 41) return CurriculumType.eightFourFour;
    // Unambiguous: CBC upper grades.
    if (grade >= 9) return CurriculumType.cbc;
    // Ambiguous range (1–8). Check if we have any 8-4-4-only grades.
    if (allGrades.any((g) => g >= 41)) return CurriculumType.eightFourFour;
    // Default to CBC.
    return CurriculumType.cbc;
  }

  /// Builds a [SchoolConfig]-like structure from raw [SchoolStream] rows,
  /// grouping by curriculum and grade.
  ({List<_CurriculumGroup> curricula, bool isEmpty}) _buildGradeTree(
    List<SchoolStream> allStreams,
  ) {
    if (allStreams.isEmpty) {
      return (curricula: <_CurriculumGroup>[], isEmpty: true);
    }

    // Collect all distinct grade numbers.
    final allGrades = allStreams.map((s) => s.grade).toSet();

    // Group streams by grade.
    final byGrade = <int, List<SchoolStream>>{};
    for (final s in allStreams) {
      byGrade.putIfAbsent(s.grade, () => []).add(s);
    }

    // Group grades by curriculum.
    final cbcGrades = <_GradeGroup>[];
    final eftGrades = <_GradeGroup>[];

    for (final entry in byGrade.entries) {
      final gradeNum = entry.key;
      final streams = entry.value..sort((a, b) => a.stream.compareTo(b.stream));
      final type = _curriculumForGrade(gradeNum, allGrades);
      final group = _GradeGroup(grade: gradeNum, streams: streams);

      if (type == CurriculumType.cbc) {
        cbcGrades.add(group);
      } else {
        eftGrades.add(group);
      }
    }

    cbcGrades.sort((a, b) => a.grade.compareTo(b.grade));
    eftGrades.sort((a, b) => a.grade.compareTo(b.grade));

    final curricula = <_CurriculumGroup>[];
    if (cbcGrades.isNotEmpty) {
      curricula.add(
        _CurriculumGroup(type: CurriculumType.cbc, grades: cbcGrades),
      );
    }
    if (eftGrades.isNotEmpty) {
      curricula.add(
        _CurriculumGroup(type: CurriculumType.eightFourFour, grades: eftGrades),
      );
    }

    return (curricula: curricula, isEmpty: false);
  }

  // ── Add grade ──────────────────────────────────────────────────────────────

  void _showAddGradeSheet(List<SchoolStream> allStreams) {
    final allGrades = allStreams.map((s) => s.grade).toSet();

    if (allGrades.isEmpty) {
      // No grades yet — show curriculum picker first.
      _showAddCurriculumAndGradeSheet();
      return;
    }

    // Always show the chooser so the user can pick either curriculum,
    // even if only one is currently in use. A school may have both.
    _showCurriculumChooser(allGrades);
  }

  void _showAddCurriculumAndGradeSheet() {
    showEduSheet(
      context: context,
      builder: (ctx) => _CurriculumSetupSheet(
        onCurriculumSelected: (type) {
          Navigator.pop(ctx);
          _showGradePickerForCurriculum(type, <int>{});
        },
      ),
    );
  }

  void _showCurriculumChooser(Set<int> usedGrades) {
    final cbcCount = usedGrades.where((g) => g <= 14).length;
    final eftCount = usedGrades.where((g) => g >= 41).length;

    showEduSheet(
      context: context,
      title: 'Add grade to…',
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetOption(
                label: 'CBC',
                subtitle:
                    '$cbcCount grade${cbcCount == 1 ? '' : 's'} configured',
                icon: Icons.school_outlined,
                onTap: () {
                  Navigator.pop(ctx);
                  _showGradePickerForCurriculum(CurriculumType.cbc, usedGrades);
                },
              ),
              const SizedBox(height: 6),
              _SheetOption(
                label: '8-4-4',
                subtitle:
                    '$eftCount grade${eftCount == 1 ? '' : 's'} configured',
                icon: Icons.school_outlined,
                onTap: () {
                  Navigator.pop(ctx);
                  _showGradePickerForCurriculum(
                    CurriculumType.eightFourFour,
                    usedGrades,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGradePickerForCurriculum(CurriculumType type, Set<int> usedGrades) {
    final labels = gradeLabelsFor(type);
    final available =
        labels.entries.where((e) => !usedGrades.contains(e.key)).toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All grades for ${type == CurriculumType.cbc ? "CBC" : "8-4-4"} are already added.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showEduSheet(
      context: context,
      builder: (ctx) => _GradePickerSheet(
        available: available,
        curriculumLabel: type == CurriculumType.cbc ? 'CBC' : '8-4-4',
        onGradeSelected: (gradeNum) {
          Navigator.pop(ctx);
          _createGrade(gradeNum);
        },
      ),
    );
  }

  /// Creating a grade: prompt for the first stream name, then insert it.
  /// A grade with zero streams cannot exist in the DB, so we require at least
  /// one stream name up front instead of silently auto-creating "Main".
  void _createGrade(int gradeNum) {
    final gradeLabel =
        gradeLabelsFor(CurriculumType.cbc)[gradeNum] ??
        gradeLabelsFor(CurriculumType.eightFourFour)[gradeNum] ??
        'Grade $gradeNum';
    _showAddStreamDialog(gradeNum, gradeLabel, [], isFirstStream: true);
  }

  // ── Delete grade ───────────────────────────────────────────────────────────

  Future<void> _deleteGrade(int gradeNum, String gradeLabel) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Remove $gradeLabel?',
      message:
          'This will remove the grade and all its stream definitions. '
          'Existing enrollments and records are not affected.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (!confirmed) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    try {
      await catalogDao.deleteAllStreamsForGrade(
        schoolId: _schoolId,
        grade: gradeNum,
        gradeLabel: gradeLabel,
        accountId: accountId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove grade: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Add stream ─────────────────────────────────────────────────────────────

  void _showAddStreamDialog(
    int gradeNum,
    String gradeLabel,
    List<SchoolStream> existingStreams, {
    bool isFirstStream = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showEduSheet(
      context: context,
      title: isFirstStream
          ? 'Name the first stream for $gradeLabel'
          : 'Add stream to $gradeLabel',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Form(
              key: formKey,
              child: EduFormField(
                controller: nameCtrl,
                label: 'Stream name',
                hint: 'e.g. East, West',
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Enter a stream name';
                  if (existingStreams.any(
                    (s) => s.name.toLowerCase() == v.trim().toLowerCase(),
                  )) {
                    return 'Stream already exists';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitAddStream(
                  ctx,
                  formKey,
                  nameCtrl,
                  gradeNum,
                  existingStreams,
                  isFirstStream: isFirstStream,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                  onPressed: () => _submitAddStream(
                    ctx,
                    formKey,
                    nameCtrl,
                    gradeNum,
                    existingStreams,
                    isFirstStream: isFirstStream,
                  ),
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
          ],
        ),
      ),
    );
  }

  Future<void> _submitAddStream(
    BuildContext ctx,
    GlobalKey<FormState> formKey,
    TextEditingController nameCtrl,
    int gradeNum,
    List<SchoolStream> existingStreams, {
    bool isFirstStream = false,
  }) async {
    if (!formKey.currentState!.validate()) return;
    final name = nameCtrl.text.trim();

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Auto-assign code: max existing code + 1, or 1 if none.
    final nextCode = existingStreams.isEmpty
        ? 1
        : existingStreams.map((s) => s.stream).reduce((a, b) => a > b ? a : b) +
              1;

    Navigator.pop(ctx);

    try {
      await catalogDao.createSchoolStream(
        schoolId: _schoolId,
        grade: gradeNum,
        streamCode: nextCode,
        name: name,
        accountId: accountId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFirstStream
                ? 'Failed to add grade: $e'
                : 'Failed to add stream: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Edit streams (batch rename / delete) ───────────────────────────────────

  void _showEditStreamsSheet(
    int gradeNum,
    String gradeLabel,
    List<SchoolStream> streams,
  ) {
    showEduSheet(
      context: context,
      builder: (ctx) => _EditStreamsSheet(
        schoolId: _schoolId,
        gradeNum: gradeNum,
        gradeLabel: gradeLabel,
        streams: streams,
        onDone: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Navigate to grade detail ───────────────────────────────────────────────

  void _navigateToGradeDetail(
    CurriculumType type,
    int gradeNum,
    String gradeLabel,
    List<SchoolStream> streams,
  ) {
    // Build a GradeConfig from DB rows for the detail page.
    final gradeConfig = GradeConfig(
      grade: gradeNum,
      streams: streams
          .map((s) => GradeStream(name: s.name, code: s.stream))
          .toList(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTermProvider(
          termContext: ActiveTermProvider.read(context),
          child: GradeDetailPage(
            schoolContext: widget.schoolContext,
            curriculumType: type,
            grade: gradeConfig,
            gradeLabel: gradeLabel,
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

    // ── Permission checks ──────────────────────────────────────────────────
    final entry = widget.schoolContext.currentEntry.value;
    final perms = widget.schoolContext.permissions;
    final canCreate =
        entry is OwnerEntry || perms.can(Resource.classes, Action.create);
    final canEdit =
        entry is OwnerEntry || perms.can(Resource.classes, Action.update);
    final canDelete =
        entry is OwnerEntry || perms.can(Resource.classes, Action.delete);

    return StreamBuilder<List<SchoolStream>>(
      stream: catalogDao.watchAllStreamsForSchool(_schoolId),
      builder: (context, snapshot) {
        final allStreams = snapshot.data ?? [];
        final tree = _buildGradeTree(allStreams);

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── Header bar ──────────────────────────────────────────
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
                      ],
                    ),
                  ),
                ),

                // ── Content ─────────────────────────────────────────────
                if (tree.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyConfigState(
                      onAdd: canCreate
                          ? () => _showAddGradeSheet(allStreams)
                          : null,
                    ),
                  )
                else
                  ..._buildCurriculaSlivers(
                    tree.curricula,
                    cs,
                    isDark,
                    allStreams,
                    canCreate: canCreate,
                    canEdit: canEdit,
                    canDelete: canDelete,
                  ),

                // Bottom padding for FAB
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),

            // ── FAB — only visible when user can create ─────────────────
            if (canCreate)
              Positioned(
                right: 16,
                bottom: 16,
                child: _AddGradeFab(
                  onTap: () => _showAddGradeSheet(allStreams),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCurriculaSlivers(
    List<_CurriculumGroup> curricula,
    ColorScheme cs,
    bool isDark,
    List<SchoolStream> allStreams, {
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  }) {
    final showHeaders = curricula.length > 1;
    final List<Widget> slivers = [];

    for (final curriculum in curricula) {
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
              final gradeGroup = curriculum.grades[index];
              final gradeLabel =
                  gradeLabelsFor(curriculum.type)[gradeGroup.grade] ??
                  'Grade ${gradeGroup.grade}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GradeCard(
                  curriculumType: curriculum.type,
                  gradeNum: gradeGroup.grade,
                  gradeLabel: gradeLabel,
                  streams: gradeGroup.streams,
                  onTap: () => _navigateToGradeDetail(
                    curriculum.type,
                    gradeGroup.grade,
                    gradeLabel,
                    gradeGroup.streams,
                  ),
                  onAddStream: canCreate
                      ? () => _showAddStreamDialog(
                          gradeGroup.grade,
                          gradeLabel,
                          gradeGroup.streams,
                        )
                      : null,
                  onEditStreams: canEdit && gradeGroup.streams.isNotEmpty
                      ? () => _showEditStreamsSheet(
                          gradeGroup.grade,
                          gradeLabel,
                          gradeGroup.streams,
                        )
                      : null,
                  onDelete: canDelete
                      ? () => _deleteGrade(gradeGroup.grade, gradeLabel)
                      : null,
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
// Internal grouping models
// ─────────────────────────────────────────────────────────────────────────────

class _CurriculumGroup {
  const _CurriculumGroup({required this.type, required this.grades});
  final CurriculumType type;
  final List<_GradeGroup> grades;
}

class _GradeGroup {
  const _GradeGroup({required this.grade, required this.streams});
  final int grade;
  final List<SchoolStream> streams;
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade Card
// ─────────────────────────────────────────────────────────────────────────────

class _GradeCard extends StatefulWidget {
  const _GradeCard({
    required this.curriculumType,
    required this.gradeNum,
    required this.gradeLabel,
    required this.streams,
    required this.onTap,
    this.onAddStream,
    this.onEditStreams,
    this.onDelete,
  });

  final CurriculumType curriculumType;
  final int gradeNum;
  final String gradeLabel;
  final List<SchoolStream> streams;
  final VoidCallback onTap;
  final VoidCallback? onAddStream;
  final VoidCallback? onEditStreams;
  final VoidCallback? onDelete;

  @override
  State<_GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<_GradeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

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

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Curriculum-aware accent colour
    final accentColor = widget.curriculumType == CurriculumType.cbc
        ? cs.primary
        : const Color(0xFF26A69A); // teal for 8-4-4

    final idleBg = isDark
        ? cs.primary.withValues(alpha: 0.06)
        : cs.primary.withValues(alpha: 0.04);
    final hoverBg = isDark
        ? accentColor.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.08);
    final pressBg = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.12);

    return ScaleTransition(
      scale: _scaleAnim,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _isPressed
                  ? pressBg
                  : _isHovered
                  ? hoverBg
                  : idleBg,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered || _isPressed
                    ? accentColor.withValues(alpha: isDark ? 0.35 : 0.25)
                    : cs.outline.withValues(alpha: isDark ? 0.10 : 0.08),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Colored accent bar ─────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isHovered || _isPressed ? 4 : 3,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: _isHovered || _isPressed ? 1.0 : 0.7,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),

                    // ── Content ────────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Grade label + actions ──────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(
                                        widget.gradeLabel,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: cs.onSurface,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Stream count badge
                                      if (widget.streams.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(
                                              alpha: isDark ? 0.18 : 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.kChipRadius,
                                            ),
                                          ),
                                          child: Text(
                                            '${widget.streams.length} stream${widget.streams.length == 1 ? '' : 's'}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: accentColor,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      AnimatedSlide(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOut,
                                        offset: Offset(
                                          _isHovered ? 0.15 : 0.0,
                                          0,
                                        ),
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          opacity: _isHovered ? 0.8 : 0.35,
                                          child: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color: _isHovered
                                                ? accentColor
                                                : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Action icons (permission-gated)
                                if (widget.onAddStream != null)
                                  _CardIconBtn(
                                    icon: Icons.add_rounded,
                                    tooltip: 'Add stream',
                                    onTap: widget.onAddStream!,
                                  ),
                                if (widget.onEditStreams != null)
                                  _CardIconBtn(
                                    icon: Icons.edit_outlined,
                                    tooltip: 'Edit streams',
                                    onTap: widget.onEditStreams!,
                                  ),
                                if (widget.onDelete != null)
                                  _CardIconBtn(
                                    icon: Icons.delete_outline_rounded,
                                    tooltip: 'Remove grade',
                                    onTap: widget.onDelete!,
                                    isDestructive: true,
                                  ),
                              ],
                            ),

                            // ── Stream chips ──────────────────────────
                            const SizedBox(height: 8),
                            if (widget.streams.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 2,
                                ),
                                child: Text(
                                  'No streams',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                children: widget.streams.map((stream) {
                                  return _StreamChip(name: stream.name);
                                }).toList(),
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
// FAB — Add grade
// ─────────────────────────────────────────────────────────────────────────────

class _AddGradeFab extends StatelessWidget {
  const _AddGradeFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'fab_add_grade',
      onPressed: onTap,
      tooltip: 'Add grade',
      child: const Icon(Icons.add_rounded, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty config state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyConfigState extends StatelessWidget {
  const _EmptyConfigState({this.onAdd});
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            const SizedBox(height: 10),
            if (onAdd != null)
              Text(
                'Tap the + button to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                'You don\'t have permission to configure grades.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
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
              subtitle: 'Grade 1–12',
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
    required this.schoolId,
    required this.gradeNum,
    required this.gradeLabel,
    required this.streams,
    required this.onDone,
  });

  final String schoolId;
  final int gradeNum;
  final String gradeLabel;
  final List<SchoolStream> streams;
  final VoidCallback onDone;

  @override
  State<_EditStreamsSheet> createState() => _EditStreamsSheetState();
}

class _EditStreamsSheetState extends State<_EditStreamsSheet> {
  late List<_EditableStream> _streams;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _streams = widget.streams
        .map(
          (s) => _EditableStream(
            code: s.stream,
            originalName: s.name,
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
    final activeCount = _streams.where((s) => !s.removed).length;
    if (activeCount == 1) {
      // Last stream — confirm that removing it will delete the whole grade.
      showEduConfirmDialog(
        context: context,
        title: 'Remove grade?',
        message:
            'This is the last stream for ${widget.gradeLabel}. '
            'Removing it will also remove the grade. '
            'Existing enrollments and records are not affected.',
        confirmLabel: 'Remove',
        isDestructive: true,
      ).then((confirmed) {
        if (!confirmed) return;
        setState(() {
          _streams[index].controller.dispose();
          _streams[index] = _EditableStream(
            code: _streams[index].code,
            originalName: _streams[index].originalName,
            controller: TextEditingController(),
            removed: true,
          );
        });
      });
      return;
    }

    setState(() {
      _streams[index].controller.dispose();
      _streams[index] = _EditableStream(
        code: _streams[index].code,
        originalName: _streams[index].originalName,
        controller: TextEditingController(), // disposed above
        removed: true,
      );
    });
  }

  Future<void> _save() async {
    // Validate — no empty names, no duplicates among non-removed streams.
    final active = _streams.where((s) => !s.removed).toList();
    final names = <String>{};
    for (final s in active) {
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

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving = true);

    try {
      // Process deletions.
      for (final s in _streams.where((s) => s.removed)) {
        await catalogDao.deleteStream(
          schoolId: widget.schoolId,
          grade: widget.gradeNum,
          streamCode: s.code,
          streamName: s.originalName,
          accountId: accountId,
        );
      }

      // Process renames (only for non-removed streams whose name changed).
      for (final s in active) {
        final newName = s.controller.text.trim();
        if (newName != s.originalName) {
          await catalogDao.updateStream(
            schoolId: widget.schoolId,
            grade: widget.gradeNum,
            streamCode: s.code,
            name: newName,
            accountId: accountId,
          );
        }
      }

      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
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
    final activeStreams = _streams.where((s) => !s.removed).toList();

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
            if (activeStreams.isEmpty)
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
              ...List.generate(activeStreams.length, (i) {
                final s = activeStreams[i];
                final realIndex = _streams.indexOf(s);
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
                        onTap: () => _removeStream(realIndex),
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
  _EditableStream({
    required this.code,
    required this.originalName,
    required this.controller,
    this.removed = false,
  });
  final int code;
  final String originalName;
  final TextEditingController controller;
  final bool removed;
}
