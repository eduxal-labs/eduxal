import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/academics_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../models/school_config.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/edu_empty_state.dart';
import '../academics/grade_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// My Classes Screen — teacher's assigned grades/streams
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the teacher's assigned classes — grades and streams where the current
/// user is either a class teacher or subject teacher for the active term.
///
/// Each card displays:
///  - Grade label (e.g. "Grade 4", "Form 2")
///  - Stream name
///  - A "Class Teacher" badge when the user is a class teacher for that stream
///  - The count of subjects the teacher is assigned in that stream
///  - The total student count for the stream
///
/// Tapping a card navigates to [GradeDetailPage] for that grade/stream.
class MyClassesScreen extends StatelessWidget {
  const MyClassesScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return _MyClassesBody(schoolContext: schoolContext);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal body — stateful to manage streams
// ─────────────────────────────────────────────────────────────────────────────

class _MyClassesBody extends StatefulWidget {
  const _MyClassesBody({required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  State<_MyClassesBody> createState() => _MyClassesBodyState();
}

class _MyClassesBodyState extends State<_MyClassesBody> {
  String get _schoolId => widget.schoolContext.membership.school.id;

  /// Determines curriculum type for a grade number, using the same heuristic as
  /// AcademicsScreen: grades ≥ 41 → 8-4-4, grades ≥ 9 → CBC, ambiguous 1–8
  /// resolved by checking for any 8-4-4-only grades in the set.
  CurriculumType _curriculumForGrade(int grade, Set<int> allGrades) {
    if (grade >= 41) return CurriculumType.eightFourFour;
    if (grade >= 9) return CurriculumType.cbc;
    if (allGrades.any((g) => g >= 41)) return CurriculumType.eightFourFour;
    return CurriculumType.cbc;
  }

  String _gradeLabel(int gradeNum, CurriculumType type) {
    final labels = gradeLabelsFor(type);
    return labels[gradeNum] ?? 'Grade $gradeNum';
  }

  void _navigateToGradeDetail(
    _ClassAssignment assignment,
    List<SchoolStream> allStreams,
  ) {
    final grade = assignment.grade;
    final streamCode = assignment.stream;
    final allGrades = allStreams.map((s) => s.grade).toSet();
    final curriculum = _curriculumForGrade(grade, allGrades);
    final label = _gradeLabel(grade, curriculum);

    // Build GradeConfig from all streams belonging to this grade.
    final gradeStreams =
        allStreams
            .where((s) => s.grade == grade)
            .map((s) => GradeStream(name: s.name, code: s.stream))
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));

    final gradeConfig = GradeConfig(grade: grade, streams: gradeStreams);

    // Find the stream tab index — 0 = All, 1+ = specific stream.
    final streamIndex =
        gradeStreams.indexWhere((s) => s.code == streamCode) + 1;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveTermProvider(
          termContext: ActiveTermProvider.read(context),
          child: GradeDetailPage(
            schoolContext: widget.schoolContext,
            curriculumType: curriculum,
            grade: gradeConfig,
            gradeLabel: label,
            initialStreamIndex: streamIndex > 0 ? streamIndex : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final termCtx = ActiveTermProvider.of(context);
    final term = termCtx.currentTerm;

    if (term == null) {
      return const EduEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No active term',
        subtitle: 'Classes will appear once a term is created.',
      );
    }

    final year = term.year;
    final termNum = term.term;

    return ValueListenableBuilder<MembershipEntry>(
      valueListenable: widget.schoolContext.currentEntry,
      builder: (context, entry, _) {
        final userId = entry is TeacherEntry ? entry.teacher.user : '';
        if (userId.isEmpty) {
          return const EduEmptyState(
            icon: Icons.school_outlined,
            title: 'Not a teacher',
            subtitle: 'This screen is only available for teacher accounts.',
          );
        }

        return StreamBuilder<List<SchoolStream>>(
          stream: catalogDao.watchAllStreamsForSchool(_schoolId),
          builder: (context, streamsSnap) {
            if (streamsSnap.hasError) {
              return Center(
                child: Text(
                  'Failed to load class streams',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              );
            }
            final allStreams = streamsSnap.data ?? [];

            return StreamBuilder<List<ClassTeacher>>(
              stream:
                  (db.select(db.classTeachers)..where(
                        (t) =>
                            t.school.equals(_schoolId) &
                            t.year.equals(year) &
                            t.term.equals(termNum) &
                            t.teacher.equals(userId),
                      ))
                      .watch(),
              builder: (context, ctSnap) {
                return StreamBuilder<List<SubjectTeacher>>(
                  stream:
                      (db.select(db.subjectTeachers)..where(
                            (t) =>
                                t.school.equals(_schoolId) &
                                t.year.equals(year) &
                                t.term.equals(termNum) &
                                t.teacher.equals(userId),
                          ))
                          .watch(),
                  builder: (context, stSnap) {
                    if (ctSnap.hasError || stSnap.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load class assignments',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    if (!ctSnap.hasData && !stSnap.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final classTeacherRows = ctSnap.data ?? [];
                    final subjectTeacherRows = stSnap.data ?? [];

                    // Build unique (grade, stream) assignments.
                    final assignments = _buildAssignments(
                      classTeacherRows,
                      subjectTeacherRows,
                      allStreams,
                    );

                    if (assignments.isEmpty) {
                      return const EduEmptyState(
                        icon: Icons.class_outlined,
                        title: 'No class assignments',
                        subtitle:
                            'You have no class teacher or subject assignments for this term.',
                      );
                    }

                    return _AssignmentsGrid(
                      assignments: assignments,
                      allStreams: allStreams,
                      schoolId: _schoolId,
                      year: year,
                      term: termNum,
                      isDark: isDark,
                      cs: cs,
                      onTap: (a) => _navigateToGradeDetail(a, allStreams),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Combines class_teachers and subject_teachers rows into unique
  /// (grade, stream) assignments with metadata.
  List<_ClassAssignment> _buildAssignments(
    List<ClassTeacher> classTeacherRows,
    List<SubjectTeacher> subjectTeacherRows,
    List<SchoolStream> allStreams,
  ) {
    final map = <String, _ClassAssignment>{};
    final allGrades = allStreams.map((s) => s.grade).toSet();

    // Stream name lookup: "grade|stream" → name
    final streamNames = <String, String>{};
    for (final s in allStreams) {
      streamNames['${s.grade}|${s.stream}'] = s.name;
    }

    // Process class teacher rows.
    for (final ct in classTeacherRows) {
      final key = '${ct.grade}|${ct.stream}';
      final existing = map[key];
      if (existing != null) {
        map[key] = existing.copyWith(isClassTeacher: true);
      } else {
        final curriculum = _curriculumForGrade(ct.grade, allGrades);
        map[key] = _ClassAssignment(
          grade: ct.grade,
          stream: ct.stream,
          streamName: streamNames[key] ?? 'Stream ${ct.stream}',
          gradeLabel: _gradeLabel(ct.grade, curriculum),
          curriculum: curriculum,
          isClassTeacher: true,
          subjectCount: 0,
        );
      }
    }

    // Process subject teacher rows — count distinct subjects per (grade, stream).
    final subjectCounts = <String, Set<int>>{};
    for (final st in subjectTeacherRows) {
      final key = '${st.grade}|${st.stream}';
      (subjectCounts[key] ??= {}).add(st.subject);
    }

    for (final entry in subjectCounts.entries) {
      final key = entry.key;
      final count = entry.value.length;
      final parts = key.split('|');
      final grade = int.parse(parts[0]);
      final stream = int.parse(parts[1]);

      final existing = map[key];
      if (existing != null) {
        map[key] = existing.copyWith(subjectCount: count);
      } else {
        final curriculum = _curriculumForGrade(grade, allGrades);
        map[key] = _ClassAssignment(
          grade: grade,
          stream: stream,
          streamName: streamNames[key] ?? 'Stream $stream',
          gradeLabel: _gradeLabel(grade, curriculum),
          curriculum: curriculum,
          isClassTeacher: false,
          subjectCount: count,
        );
      }
    }

    final result = map.values.toList()
      ..sort((a, b) {
        final g = a.grade.compareTo(b.grade);
        if (g != 0) return g;
        return a.stream.compareTo(b.stream);
      });

    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assignment model
// ─────────────────────────────────────────────────────────────────────────────

class _ClassAssignment {
  const _ClassAssignment({
    required this.grade,
    required this.stream,
    required this.streamName,
    required this.gradeLabel,
    required this.curriculum,
    required this.isClassTeacher,
    required this.subjectCount,
  });

  final int grade;
  final int stream;
  final String streamName;
  final String gradeLabel;
  final CurriculumType curriculum;
  final bool isClassTeacher;
  final int subjectCount;

  _ClassAssignment copyWith({bool? isClassTeacher, int? subjectCount}) {
    return _ClassAssignment(
      grade: grade,
      stream: stream,
      streamName: streamName,
      gradeLabel: gradeLabel,
      curriculum: curriculum,
      isClassTeacher: isClassTeacher ?? this.isClassTeacher,
      subjectCount: subjectCount ?? this.subjectCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive grid layout
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentsGrid extends StatelessWidget {
  const _AssignmentsGrid({
    required this.assignments,
    required this.allStreams,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final List<_ClassAssignment> assignments;
  final List<SchoolStream> allStreams;
  final String schoolId;
  final int year;
  final int term;
  final bool isDark;
  final ColorScheme cs;
  final void Function(_ClassAssignment) onTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My Classes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  ),
                  child: Text(
                    "${assignments.length} ${assignments.length == 1 ? 'class' : 'classes'}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── Grid / List ──────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final isDesktop = width >= AppTheme.kMobileBreakpoint;

              if (isDesktop) {
                // Desktop: responsive grid
                final columns = width >= AppTheme.kDesktopBreakpoint
                    ? 4
                    : width >= AppTheme.kTabletBreakpoint
                    ? 3
                    : 2;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ClassCard(
                      assignment: assignments[index],
                      schoolId: schoolId,
                      year: year,
                      term: term,
                      isDark: isDark,
                      cs: cs,
                      onTap: () => onTap(assignments[index]),
                    ),
                    childCount: assignments.length,
                  ),
                );
              }

              // Mobile: vertical list
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ClassCard(
                      assignment: assignments[index],
                      schoolId: schoolId,
                      year: year,
                      term: term,
                      isDark: isDark,
                      cs: cs,
                      onTap: () => onTap(assignments[index]),
                    ),
                  ),
                  childCount: assignments.length,
                ),
              );
            },
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual class card
// ─────────────────────────────────────────────────────────────────────────────

class _ClassCard extends StatefulWidget {
  const _ClassCard({
    required this.assignment,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final _ClassAssignment assignment;
  final String schoolId;
  final int year;
  final int term;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final cs = widget.cs;
    final isDark = widget.isDark;

    final bgColor = AppTheme.nestedBg(isDark, cs);
    final border = AppTheme.borderColor(isDark, cs);

    return ScaleTransition(
      scale: _scaleAnim,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Color.alphaBlend(
                      cs.primary.withValues(alpha: 0.04),
                      bgColor,
                    )
                  : bgColor,
              borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              border: Border.all(
                color: _isHovered ? cs.primary.withValues(alpha: 0.2) : border,
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top row: grade label + class teacher badge ────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.gradeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (a.isClassTeacher)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.actionAssign.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.kChipRadius,
                          ),
                        ),
                        child: Text(
                          'Class Teacher',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.actionAssign,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                // ── Stream name ──────────────────────────────────────────
                Text(
                  a.streamName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // ── Bottom row: subject count + student count ────────────
                Row(
                  children: [
                    if (a.subjectCount > 0) ...[
                      _InfoChip(
                        icon: Icons.menu_book_outlined,
                        label:
                            "${a.subjectCount} ${a.subjectCount == 1 ? 'subject' : 'subjects'}",
                        cs: cs,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _StudentCountChip(
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: a.grade,
                      stream: a.stream,
                      cs: cs,
                      isDark: isDark,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
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
// Info chip (static)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student count chip (reactive via StreamBuilder)
// ─────────────────────────────────────────────────────────────────────────────

class _StudentCountChip extends StatelessWidget {
  const _StudentCountChip({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.cs,
    required this.isDark,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int stream;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final academicsDao = AcademicsDao(db);

    return StreamBuilder<int>(
      stream: academicsDao.watchStudentCount(
        schoolId: schoolId,
        year: year,
        term: term,
        grade: grade,
        stream: stream,
      ),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              "$count ${count == 1 ? 'student' : 'students'}",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
