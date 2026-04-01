import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';

import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_tab_bar.dart';
import '../../../widgets/student_avatar.dart';
import '../../../widgets/user_avatar.dart';
import 'paper_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exam Detail Page
//
// Reached from the ExamsTab inside the grade detail page. Shows a single exam
// with three tabs: Papers, Grades, and Performance.
// ─────────────────────────────────────────────────────────────────────────────

class ExamDetailPage extends StatefulWidget {
  const ExamDetailPage({
    super.key,
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.streamCode,
    this.streamName,
    required this.curriculumType,
    required this.schoolContext,
    this.subjectNames = const {},
    this.streamNames = const {},
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? streamCode;
  final String? streamName;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;
  final Map<int, String> subjectNames;

  /// Maps streamCode → stream name for the current grade.
  /// Used to show stream badges on papers when all streams are visible.
  final Map<int, String> streamNames;

  @override
  State<ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<ExamDetailPage>
    with TickerProviderStateMixin {
  late final ExamsGradesDao _dao;
  late final TabController _tabController;
  late Stream<List<Paper>> _papersStream;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  static const _tabs = [
    EduTab(label: 'Papers'),
    EduTab(label: 'Grades'),
    EduTab(label: 'Performance'),
  ];

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _tabController = TabController(length: _tabs.length, vsync: this);
    // When a specific stream is selected, filter papers to that grade+stream.
    // When streamCode is null (All tab), show all papers for the grade.
    if (widget.streamCode != null) {
      _papersStream = _dao.watchPapersForExamGradeStream(
        schoolId: widget.schoolId,
        examIds: [widget.exam.exam.id],
        grade: widget.grade,
        stream: widget.streamCode,
      );
    } else {
      _papersStream = _dao.watchPapersForExam(
        schoolId: widget.schoolId,
        examId: widget.exam.exam.id,
      );
    }
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Exam get _exam => widget.exam.exam;
  UsersData get _teacher => widget.exam.teacher;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _examTitle(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Summary card ───────────────────────────────────────────
              _ExamSummaryCard(
                exam: _exam,
                teacher: _teacher,
                streamName: widget.streamName,
                curriculumType: widget.curriculumType,
                papersStream: _papersStream,
                grade: widget.grade,
              ),

              // ── Tab bar ────────────────────────────────────────────────
              EduTabBar(
                controller: _tabController,
                tabs: _tabs,
                isScrollable: true,
              ),

              // ── Tab views ──────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PapersTab(
                      exam: widget.exam,
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: widget.grade,
                      streamCode: widget.streamCode,
                      curriculumType: widget.curriculumType,
                      papersStream: _papersStream,
                      dao: _dao,
                      schoolContext: widget.schoolContext,
                      subjectNames: widget.subjectNames,
                      streamNames: widget.streamNames,
                    ),
                    _GradesTab(
                      exam: widget.exam,
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: widget.grade,
                      streamCode: widget.streamCode,
                      curriculumType: widget.curriculumType,
                      dao: _dao,
                      subjectNames: widget.subjectNames,
                    ),
                    _PerformanceTab(
                      exam: widget.exam,
                      schoolId: widget.schoolId,
                      year: widget.year,
                      term: widget.term,
                      grade: widget.grade,
                      streamCode: widget.streamCode,
                      curriculumType: widget.curriculumType,
                      dao: _dao,
                      subjectNames: widget.subjectNames,
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

  String _examTitle() {
    final typeLabel = _typeLabel(_exam.type);
    final dt = DateTime.fromMillisecondsSinceEpoch(
      _exam.start * Duration.millisecondsPerDay,
      isUtc: true,
    );
    final dateStr =
        '${dt.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1]} ${dt.year}';
    return '$typeLabel · $dateStr';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Exam Summary Card
// ═════════════════════════════════════════════════════════════════════════════

class _ExamSummaryCard extends StatelessWidget {
  const _ExamSummaryCard({
    required this.exam,
    required this.teacher,
    required this.streamName,
    required this.curriculumType,
    required this.papersStream,
    required this.grade,
  });

  final Exam exam;
  final UsersData teacher;
  final String? streamName;
  final CurriculumType curriculumType;
  final Stream<List<Paper>> papersStream;
  final int grade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final startDate = DateTime.fromMillisecondsSinceEpoch(
      exam.start * 86400 * 1000,
    );
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      exam.end * 86400 * 1000,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Badges row ──
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TypeBadge(type: exam.type, cs: cs),
                  if (exam.personalized)
                    _OutlineBadge(label: 'Personalized', cs: cs),
                  if (streamName != null &&
                      streamName!.isNotEmpty &&
                      streamName != 'All')
                    _TintedBadge(
                      label: streamName!,
                      color: cs.tertiary,
                      cs: cs,
                    ),
                  // Status badge — reactive from papers stream
                  StreamBuilder<List<Paper>>(
                    stream: papersStream,
                    builder: (context, snap) {
                      final papers = snap.data;
                      final status = _computeGradingStatus(papers);
                      return _StatusBadge(status: status, cs: cs);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Date range ──
              Row(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_fmtDate(startDate)} – ${_fmtDate(endDate)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ── Teacher ──
              Row(
                children: [
                  UserAvatar(userId: teacher.id, radius: 10),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      teacher.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _GradingStatus _computeGradingStatus(List<Paper>? papers) {
    if (papers == null || papers.isEmpty) return _GradingStatus.notStarted;
    final allMarked = papers.every((p) => p.status == PaperStatus.marked);
    if (allMarked) return _GradingStatus.fullyGraded;
    final someMarked = papers.any((p) => p.status == PaperStatus.marked);
    if (someMarked) return _GradingStatus.partiallyGraded;
    return _GradingStatus.notStarted;
  }
}

enum _GradingStatus { notStarted, partiallyGraded, fullyGraded }

// ═════════════════════════════════════════════════════════════════════════════
// Papers Tab
// ═════════════════════════════════════════════════════════════════════════════

class _PapersTab extends StatelessWidget {
  const _PapersTab({
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.streamCode,
    required this.curriculumType,
    required this.papersStream,
    required this.dao,
    required this.schoolContext,
    required this.subjectNames,
    this.streamNames = const {},
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final int grade;

  /// null = All streams context; non-null = specific stream context.
  final int? streamCode;
  final CurriculumType curriculumType;
  final Stream<List<Paper>> papersStream;
  final ExamsGradesDao dao;
  final SchoolContext schoolContext;
  final Map<int, String> subjectNames;

  /// Maps streamCode → stream name. Used to label papers when all streams shown.
  final Map<int, String> streamNames;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Paper>>(
      stream: papersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoading(cs);
        }

        final papers = snap.data ?? [];
        if (papers.isEmpty) {
          return _buildEmpty(cs, 'No papers added to this exam yet');
        }

        return LayoutBuilder(
          builder: (ctx, constraints) {
            // ── Desktop (≥600px): unified cross-table matrix ──────────────
            if (constraints.maxWidth >= 600) {
              return _PapersCrossTable(
                papers: papers,
                subjectNames: subjectNames,
                streamNames: streamNames,
                onTap: (p) => _onPaperTap(context, p),
              );
            }

            // ── Mobile (<600px): existing date-grouped flat list ──────────
            final grouped = <String, List<Paper>>{};
            for (final p in papers) {
              final dt = DateTime.fromMillisecondsSinceEpoch(
                p.start.toInt() * 1000,
              );
              final key = _fmtDate(dt);
              grouped.putIfAbsent(key, () => []).add(p);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildHeader(cs, papers.length),
                const _PaperStatusLegend(),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  for (final p in entry.value)
                    _PaperTimetableCard(
                      paper: p,
                      subjectNames: subjectNames,
                      // Show stream badge only when viewing all streams
                      // (streamCode is null) and the paper itself has a stream.
                      streamName: streamCode == null && p.stream != null
                          ? streamNames[p.stream]
                          : null,
                      cs: cs,
                      onTap: () => _onPaperTap(context, p),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme cs, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$count paper${count == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  void _onPaperTap(BuildContext context, Paper paper) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaperDetailPage(
          paper: paper,
          exam: exam,
          schoolId: schoolId,
          year: year,
          term: term,
          grade: grade,
          curriculumType: curriculumType,
          schoolContext: schoolContext,
          subjectNames: subjectNames,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Grades Tab
// ═════════════════════════════════════════════════════════════════════════════

class _GradesTab extends StatefulWidget {
  const _GradesTab({
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.streamCode,
    required this.curriculumType,
    required this.dao,
    required this.subjectNames,
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? streamCode;
  final CurriculumType curriculumType;
  final ExamsGradesDao dao;
  final Map<int, String> subjectNames;

  @override
  State<_GradesTab> createState() => _GradesTabState();
}

/// Pre-computed row for the grades table — avoids recalculating totals in
/// multiple places (sorting, fixed column, scrollable columns).
class _StudentGradeRow {
  _StudentGradeRow({
    required this.student,
    required this.subjectGrades,
    required this.totalScore,
    required this.totalPossible,
  }) : percentage = totalPossible > 0
           ? (totalScore / totalPossible) * 100
           : 0.0;

  final StudentsData student;
  final Map<int, Grade> subjectGrades;
  final double totalScore;
  final int totalPossible;
  final double percentage;

  bool get hasGrades => totalPossible > 0;
}

enum _GradeSort { scoreDesc, nameAsc }

class _GradesTabState extends State<_GradesTab>
    with AutomaticKeepAliveClientMixin {
  late Stream<List<GradeRow>> _gradesStream;
  List<StudentsData>? _enrolled;
  bool _loadingStudents = true;
  _GradeSort _sort = _GradeSort.scoreDesc;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _gradesStream = widget.dao.watchGradesForExam(
      schoolId: widget.schoolId,
      examId: widget.exam.exam.id,
    );
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final enrolled = await widget.dao.getEnrolledStudents(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );
    if (!mounted) return;
    setState(() {
      _enrolled = enrolled;
      _loadingStudents = false;
    });
  }

  /// Build pre-computed rows from enrolled students + grade map, then sort.
  List<_StudentGradeRow> _buildRows(
    List<StudentsData> enrolled,
    List<int> subjects,
    Map<int, Map<int, Grade>> gradeMap,
  ) {
    final rows = enrolled.map((student) {
      final sg = gradeMap[student.adm] ?? {};
      double total = 0;
      int possible = 0;
      for (final s in subjects) {
        final g = sg[s];
        if (g != null) {
          total += g.score;
          possible += g.total;
        }
      }
      return _StudentGradeRow(
        student: student,
        subjectGrades: sg,
        totalScore: total,
        totalPossible: possible,
      );
    }).toList();

    switch (_sort) {
      case _GradeSort.scoreDesc:
        rows.sort((a, b) => b.percentage.compareTo(a.percentage));
      case _GradeSort.nameAsc:
        rows.sort(
          (a, b) => a.student.name.toLowerCase().compareTo(
            b.student.name.toLowerCase(),
          ),
        );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    if (_loadingStudents) return _buildLoading(cs);

    return StreamBuilder<List<GradeRow>>(
      stream: _gradesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoading(cs);
        }

        final gradeRows = snap.data ?? [];
        final enrolled = _enrolled ?? [];

        if (enrolled.isEmpty) {
          return _buildEmpty(cs, 'No students enrolled');
        }

        // Collect unique subjects from grade rows
        final subjectCodes = <int>{};
        for (final gr in gradeRows) {
          if (gr.grade.paper == null) {
            subjectCodes.add(gr.grade.subject);
          }
        }
        // If no subject-level totals, use all subjects
        if (subjectCodes.isEmpty) {
          for (final gr in gradeRows) {
            subjectCodes.add(gr.grade.subject);
          }
        }
        final sortedSubjects = subjectCodes.toList()..sort();

        // Build a lookup: student adm → subject → grade
        final gradeMap = <int, Map<int, Grade>>{};
        for (final gr in gradeRows) {
          // Prefer subject-level totals (paper == null)
          final existing = gradeMap.putIfAbsent(gr.grade.student, () => {});
          final key = gr.grade.subject;
          if (gr.grade.paper == null) {
            existing[key] = gr.grade;
          } else if (!existing.containsKey(key)) {
            existing[key] = gr.grade;
          }
        }

        final rows = _buildRows(enrolled, sortedSubjects, gradeMap);

        if (isDesktop) {
          return _buildDesktopTable(cs, rows, sortedSubjects);
        }
        return _buildMobileList(cs, rows, sortedSubjects);
      },
    );
  }

  // ── Desktop: fixed first column + horizontally scrollable grade columns ──

  Widget _buildDesktopTable(
    ColorScheme cs,
    List<_StudentGradeRow> rows,
    List<int> subjects,
  ) {
    final isDark = cs.brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.18 : 0.12,
    );
    final useAbbrev = subjects.length > 6;

    const double fixedWidth = 200; // Name + ADM column
    const double rowHeight = 52;
    const double headerHeight = 42;
    const double cellWidth = 90;
    const double totalCellWidth = 100;
    const double pctCellWidth = 72;

    // ── Header text style ──
    final headerStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      color: cs.onSurfaceVariant,
      letterSpacing: 0.3,
    );

    // ── Sort toggle ──
    Widget sortToggle() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${rows.length} student${rows.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => setState(() {
              _sort = _sort == _GradeSort.scoreDesc
                  ? _GradeSort.nameAsc
                  : _GradeSort.scoreDesc;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sort == _GradeSort.scoreDesc
                        ? Icons.leaderboard_outlined
                        : Icons.sort_by_alpha,
                    size: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sort == _GradeSort.scoreDesc ? 'By score' : 'By name',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── Fixed left column (Name + ADM) ──
    Widget fixedColumn() {
      return SizedBox(
        width: fixedWidth,
        child: Column(
          children: [
            // Header cell
            Container(
              height: headerHeight,
              width: fixedWidth,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.3 : 0.25,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  right: BorderSide(color: borderColor),
                ),
              ),
              child: Text('Student', style: headerStyle),
            ),
            // Student rows
            for (int index = 0; index < rows.length; index++)
              Container(
                height: rowHeight,
                width: fixedWidth,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: index.isOdd
                      ? cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.08 : 0.06,
                        )
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.08 : 0.1,
                      ),
                      width: 0.5,
                    ),
                    right: BorderSide(color: borderColor),
                  ),
                ),
                child: Row(
                  children: [
                    StudentAvatar(
                      schoolId: widget.schoolId,
                      adm: rows[index].student.adm,
                      name: rows[index].student.name,
                      radius: 13,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[index].student.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'ADM ${rows[index].student.adm}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
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
      );
    }

    // ── Scrollable subject columns + Total + % ──
    Widget scrollableColumns() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            // ── Header row ──
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.3 : 0.25,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  ...subjects.map((s) {
                    final fullLabel = widget.subjectNames[s] ?? 'Subject $s';
                    final label = useAbbrev
                        ? _abbreviateSubject(fullLabel)
                        : fullLabel;
                    return Container(
                      width: cellWidth,
                      height: headerHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: borderColor)),
                      ),
                      child: Tooltip(
                        message: fullLabel,
                        child: Text(
                          label,
                          style: headerStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                  // Total header — with left border separation
                  Container(
                    width: totalCellWidth,
                    height: headerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        right: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Text('Total', style: headerStyle),
                  ),
                  // % header
                  Container(
                    width: pctCellWidth,
                    height: headerHeight,
                    alignment: Alignment.center,
                    child: Text('%', style: headerStyle),
                  ),
                ],
              ),
            ),
            // ── Data rows ──
            for (int index = 0; index < rows.length; index++)
              Container(
                decoration: BoxDecoration(
                  color: index.isOdd
                      ? cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.08 : 0.06,
                        )
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.08 : 0.1,
                      ),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    ...subjects.map((s) {
                      final g = rows[index].subjectGrades[s];
                      return Container(
                        width: cellWidth,
                        height: rowHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: borderColor)),
                        ),
                        child: g == null
                            ? Text(
                                '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              )
                            : _GradeCell(grade: g, cs: cs),
                      );
                    }),
                    // Total cell — with left border separation
                    Container(
                      width: totalCellWidth,
                      height: rowHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          right: BorderSide(color: borderColor),
                        ),
                      ),
                      child: rows[index].hasGrades
                          ? Text(
                              '${_fmtScore(rows[index].totalScore)}/${rows[index].totalPossible}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            )
                          : Text(
                              '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                    ),
                    // % cell
                    Container(
                      width: pctCellWidth,
                      height: rowHeight,
                      alignment: Alignment.center,
                      child: rows[index].hasGrades
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _pctColor(
                                  rows[index].percentage,
                                  cs,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${rows[index].percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: _pctColor(rows[index].percentage, cs),
                                ),
                              ),
                            )
                          : Text(
                              '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.25,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort toggle row
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: sortToggle(),
          ),
          // Table with fixed first column
          Expanded(
            child: Material(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      fixedColumn(),
                      Expanded(child: scrollableColumns()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Abbreviate a subject label for compact column headers.
  /// Keeps first word + first letter of subsequent words (e.g. "Social Studies" → "Social S.").
  static String _abbreviateSubject(String label) {
    if (label.length <= 8) return label;
    final words = label.split(' ');
    if (words.length == 1) return '${label.substring(0, 7)}…';
    final buf = StringBuffer(words.first);
    for (var i = 1; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        buf.write(' ${words[i][0]}.');
      }
    }
    final result = buf.toString();
    return result.length > 12 ? '${result.substring(0, 11)}…' : result;
  }

  // ── Mobile: vertical list of student cards ──

  Widget _buildMobileList(
    ColorScheme cs,
    List<_StudentGradeRow> rows,
    List<int> subjects,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${rows.length} student${rows.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        final row = rows[i - 1];
        return _MobileStudentGradeCard(
          row: row,
          subjects: subjects,
          subjectNames: widget.subjectNames,
          cs: cs,
          schoolId: widget.schoolId,
        );
      },
    );
  }
}

// ─── Mobile student grade card (expandable) ──────────────────────────────────

/// A single grade cell for the desktop table: score/total on the first line,
/// percentage in muted text below — color-coded by performance.
class _GradeCell extends StatelessWidget {
  const _GradeCell({required this.grade, required this.cs});

  final Grade grade;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final pct = grade.total > 0 ? (grade.score / grade.total) * 100 : 0.0;
    final color = _pctColor(pct, cs);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_fmtScore(grade.score)}/${grade.total}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: color.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _MobileStudentGradeCard extends StatefulWidget {
  const _MobileStudentGradeCard({
    required this.row,
    required this.subjects,
    required this.subjectNames,
    required this.cs,
    required this.schoolId,
  });

  final _StudentGradeRow row;
  final List<int> subjects;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final String schoolId;

  @override
  State<_MobileStudentGradeCard> createState() =>
      _MobileStudentGradeCardState();
}

class _MobileStudentGradeCardState extends State<_MobileStudentGradeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final row = widget.row;
    final pct = row.percentage;
    final hasGrades = row.hasGrades;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    StudentAvatar(
                      schoolId: widget.schoolId,
                      adm: widget.row.student.adm,
                      name: widget.row.student.name,
                      radius: 14,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.student.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ADM: ${row.student.adm}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasGrades)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _pctColor(pct, cs).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _pctColor(pct, cs),
                          ),
                        ),
                      )
                    else
                      Text(
                        '—',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ],
                ),

                // ── Expanded: per-subject scores with thin progress bars ──
                if (_expanded && widget.subjects.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.15 : 0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < widget.subjects.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                      ),
                    Builder(
                      builder: (context) {
                        final s = widget.subjects[i];
                        final g = row.subjectGrades[s];
                        final label = widget.subjectNames[s] ?? 'Subject $s';
                        if (g == null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final sp = g.total > 0
                            ? (g.score / g.total) * 100
                            : 0.0;
                        final barColor = _pctColor(sp, cs);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_fmtScore(g.score)}/${g.total}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 42,
                                    child: Text(
                                      '${sp.toStringAsFixed(0)}%',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: barColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(1.5),
                                child: SizedBox(
                                  height: 3,
                                  child: LinearProgressIndicator(
                                    value: (sp / 100).clamp(0.0, 1.0),
                                    backgroundColor: cs.surfaceContainerHighest
                                        .withValues(alpha: isDark ? 0.6 : 0.5),
                                    valueColor: AlwaysStoppedAnimation(
                                      barColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  // Total row separator — thicker divider
                  const SizedBox(height: 2),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        hasGrades
                            ? '${_fmtScore(row.totalScore)}/${row.totalPossible}'
                            : '—',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          hasGrades ? '${pct.toStringAsFixed(0)}%' : '—',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _pctColor(pct, cs),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasGrades) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1.5),
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          backgroundColor: cs.surfaceContainerHighest
                              .withValues(alpha: isDark ? 0.6 : 0.5),
                          valueColor: AlwaysStoppedAnimation(
                            _pctColor(pct, cs),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Performance Tab
// ═════════════════════════════════════════════════════════════════════════════

class _PerformanceTab extends StatefulWidget {
  const _PerformanceTab({
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    this.streamCode,
    required this.curriculumType,
    required this.dao,
    required this.subjectNames,
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int? streamCode;
  final CurriculumType curriculumType;
  final ExamsGradesDao dao;
  final Map<int, String> subjectNames;

  @override
  State<_PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<_PerformanceTab>
    with AutomaticKeepAliveClientMixin {
  Map<int, PaperAnalytics>? _analytics;
  List<_StudentRankRow>? _rankings;
  List<StudentsData>? _enrolled;
  bool _loading = true;
  int _selectedInsight = 0; // 0 = Overview, 1 = Subjects, 2 = Rankings

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final analytics = await widget.dao.computeClassAnalytics(
      schoolId: widget.schoolId,
      examId: widget.exam.exam.id,
    );

    final enrolled = await widget.dao.getEnrolledStudents(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: widget.grade,
      stream: widget.streamCode,
    );

    // Fetch all grades for this exam
    final allGrades = await widget.dao
        .watchClassGrades(
          schoolId: widget.schoolId,
          examId: widget.exam.exam.id,
        )
        .first;

    // Build student rankings
    final hasSubjectTotals = allGrades.any((g) => g.paper == null);
    final relevantGrades = hasSubjectTotals
        ? allGrades.where((g) => g.paper == null).toList()
        : allGrades;

    // Filter grades to only students enrolled in this stream/grade.
    // watchClassGrades returns grades across all streams; restrict to
    // enrolled students so rankings and graded counts are per-stream.
    final enrolledAdms = {for (final s in enrolled) s.adm};
    final byStudent = <int, List<Grade>>{};
    for (final g in relevantGrades) {
      if (!enrolledAdms.contains(g.student)) continue;
      byStudent.putIfAbsent(g.student, () => []).add(g);
    }

    final studentMap = {for (final s in enrolled) s.adm: s};

    final rankings = <_StudentRankRow>[];
    for (final entry in byStudent.entries) {
      final adm = entry.key;
      final grades = entry.value;
      double totalScore = 0;
      int totalPossible = 0;
      for (final g in grades) {
        totalScore += g.score;
        totalPossible += g.total;
      }
      final pct = totalPossible > 0 ? (totalScore / totalPossible) * 100 : 0.0;
      final student = studentMap[adm];
      rankings.add(
        _StudentRankRow(
          name: student?.name ?? 'Student $adm',
          adm: adm,
          totalScore: totalScore,
          totalPossible: totalPossible,
          percentage: pct,
        ),
      );
    }

    // Sort by percentage descending
    rankings.sort((a, b) => b.percentage.compareTo(a.percentage));

    // Assign ranks (ties share the same rank)
    int currentRank = 1;
    for (int i = 0; i < rankings.length; i++) {
      if (i > 0 && rankings[i].percentage < rankings[i - 1].percentage) {
        currentRank = i + 1;
      }
      rankings[i] = rankings[i].copyWith(rank: currentRank);
    }

    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _rankings = rankings;
      _enrolled = enrolled;
      _loading = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    if (_loading) return _buildLoading(cs);

    final analytics = _analytics;
    final rankings = _rankings;
    final enrolled = _enrolled;

    if (analytics == null || analytics.isEmpty) {
      return _buildEmpty(cs, 'No grades recorded for this exam yet');
    }

    // Overall stats
    double totalAvg = 0;
    double highest = 0;
    double lowest = 100;
    for (final a in analytics.values) {
      totalAvg += a.averagePercent;
      if (a.averagePercent > highest) highest = a.averagePercent;
      if (a.averagePercent < lowest) lowest = a.averagePercent;
    }
    final overallAvg = totalAvg / analytics.length;
    final totalGraded = rankings?.length ?? 0;
    final totalEnrolled = enrolled?.length ?? 0;

    return Column(
      children: [
        // ── Insight selector ──
        _buildInsightSelector(cs, isDark),
        // ── Content ──
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedInsight == 0
                ? _buildOverviewInsight(
                    cs,
                    isDark,
                    overallAvg,
                    highest,
                    lowest,
                    totalGraded,
                    totalEnrolled,
                    analytics,
                  )
                : _selectedInsight == 1
                ? _buildSubjectsInsight(cs, isDark, analytics)
                : _buildRankingsInsight(cs, isDark, rankings ?? []),
          ),
        ),
      ],
    );
  }

  // ── Insight Selector ───────────────────────────────────────────────────────

  Widget _buildInsightSelector(ColorScheme cs, bool isDark) {
    const labels = ['Overview', 'Subjects', 'Rankings'];
    const icons = [
      Icons.insights_rounded,
      Icons.menu_book_rounded,
      Icons.emoji_events_rounded,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(3, (i) {
          final selected = _selectedInsight == i;
          return Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedInsight = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? cs.primary.withValues(alpha: 0.3)
                        : cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: 14,
                      color: selected
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Overview Insight ───────────────────────────────────────────────────────

  Widget _buildOverviewInsight(
    ColorScheme cs,
    bool isDark,
    double overallAvg,
    double highest,
    double lowest,
    int totalGraded,
    int totalEnrolled,
    Map<int, PaperAnalytics> analytics,
  ) {
    return ListView(
      key: const ValueKey('overview'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            if (constraints.maxWidth < 400) {
              return Column(
                children: [
                  _buildCompactMetrics(
                    cs,
                    isDark,
                    overallAvg,
                    highest,
                    lowest,
                    totalGraded,
                    totalEnrolled,
                  ),
                  const SizedBox(height: 12),
                  _buildDonutDistribution(cs, isDark, analytics),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactMetrics(
                  cs,
                  isDark,
                  overallAvg,
                  highest,
                  lowest,
                  totalGraded,
                  totalEnrolled,
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildDonutDistribution(cs, isDark, analytics)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildStrengthsWeaknesses(cs, isDark, analytics),
      ],
    );
  }

  Widget _buildCompactMetrics(
    ColorScheme cs,
    bool isDark,
    double avg,
    double highest,
    double lowest,
    int graded,
    int enrolled,
  ) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow(
            '${avg.toStringAsFixed(1)}%',
            'Class Average',
            _pctColor(avg, cs),
            cs,
          ),
          const SizedBox(height: 10),
          _metricRow('$graded / $enrolled', 'Graded', cs.onSurface, cs),
          const SizedBox(height: 10),
          _metricRow(
            '${(highest - lowest).toStringAsFixed(1)}%',
            'Spread',
            cs.onSurfaceVariant,
            cs,
          ),
        ],
      ),
    );
  }

  Widget _metricRow(
    String value,
    String label,
    Color valueColor,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: valueColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDonutDistribution(
    ColorScheme cs,
    bool isDark,
    Map<int, PaperAnalytics> analytics,
  ) {
    // Same aggregation logic as _buildDistribution
    final aggregate = <String, int>{};
    for (final pa in analytics.values) {
      for (final entry in pa.distribution.entries) {
        aggregate[entry.key] = (aggregate[entry.key] ?? 0) + entry.value;
      }
    }
    if (aggregate.isEmpty) return const SizedBox.shrink();

    const buckets = ['0–39', '40–49', '50–59', '60–69', '70–79', '80–100'];
    const bucketColors = [
      Color(0xFFEF4444),
      Color(0xFFF97316),
      Color(0xFFF59E0B),
      Color(0xFF84CC16),
      Color(0xFF22C55E),
      Color(0xFF10B981),
    ];

    final counts = <int>[];
    int total = 0;
    for (int i = 0; i < buckets.length; i++) {
      final c = aggregate[buckets[i]] ?? 0;
      counts.add(c);
      total += c;
    }
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Score Distribution',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DistributionDonutPainter(
                counts: counts,
                colors: bucketColors
                    .map((c) => c.withValues(alpha: isDark ? 0.8 : 0.9))
                    .toList(),
                trackColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'students',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: List.generate(buckets.length, (i) {
              if (counts[i] == 0) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: bucketColors[i].withValues(
                        alpha: isDark ? 0.8 : 0.9,
                      ),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${buckets[i]}% (${counts[i]})',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Distribution ───────────────────────────────────────────────────────────

  // ── Strengths & Weaknesses ─────────────────────────────────────────────────

  Widget _buildStrengthsWeaknesses(
    ColorScheme cs,
    bool isDark,
    Map<int, PaperAnalytics> analytics,
  ) {
    if (analytics.length < 2) return const SizedBox.shrink();

    final sorted = analytics.entries.toList()
      ..sort(
        (a, b) => b.value.averagePercent.compareTo(a.value.averagePercent),
      );

    final best = sorted.first;
    final worst = sorted.last;
    final bestName = widget.subjectNames[best.key] ?? 'Subject ${best.key}';
    final worstName = widget.subjectNames[worst.key] ?? 'Subject ${worst.key}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Insights',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            cs,
            icon: Icons.trending_up_rounded,
            iconColor: AppTheme.brandGreen,
            title: 'Strongest Subject',
            subtitle: bestName,
            value: '${best.value.averagePercent.toStringAsFixed(1)}%',
            valueColor: AppTheme.brandGreen,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          _buildInsightRow(
            cs,
            icon: Icons.trending_down_rounded,
            iconColor: cs.error,
            title: 'Needs Attention',
            subtitle: worstName,
            value: '${worst.value.averagePercent.toStringAsFixed(1)}%',
            valueColor: cs.error,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    ColorScheme cs, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── Subjects Insight ───────────────────────────────────────────────────────

  Widget _buildSubjectsInsight(
    ColorScheme cs,
    bool isDark,
    Map<int, PaperAnalytics> analytics,
  ) {
    final sorted = analytics.entries.toList()
      ..sort(
        (a, b) => b.value.averagePercent.compareTo(a.value.averagePercent),
      );

    return SingleChildScrollView(
      key: const ValueKey('subjects'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: sorted.map((entry) {
          final name = widget.subjectNames[entry.key] ?? 'Subject ${entry.key}';
          final pa = entry.value;
          final avg = pa.averagePercent;
          final barColor = avg >= 75
              ? AppTheme.brandGreen
              : avg >= 50
              ? const Color(0xFFF59E0B)
              : cs.error;

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: barColor, width: 2.5),
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                  right: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${avg.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: barColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: (avg / 100).clamp(0.0, 1.0),
                        backgroundColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          barColor.withValues(alpha: isDark ? 0.7 : 0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${pa.gradedStudents}/${pa.totalStudents} graded',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Rankings Insight ────────────────────────────────────────────────────────

  Widget _buildRankingsInsight(
    ColorScheme cs,
    bool isDark,
    List<_StudentRankRow> rankings,
  ) {
    if (rankings.isEmpty) {
      return _buildEmpty(cs, 'No student rankings available');
    }

    return ListView(
      key: const ValueKey('rankings'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Podium for top 3
        if (rankings.length >= 3) ...[
          _buildPodium(cs, isDark, rankings),
          const SizedBox(height: 16),
        ],
        // Header
        _buildRankHeader(cs, isDark),
        // Rows
        for (int i = 0; i < rankings.length; i++)
          _buildRankRow(cs, isDark, rankings[i], i),
      ],
    );
  }

  Widget _buildPodium(
    ColorScheme cs,
    bool isDark,
    List<_StudentRankRow> rankings,
  ) {
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    final first = rankings[0];
    final second = rankings[1];
    final third = rankings[2];

    Widget podiumItem(
      _StudentRankRow r,
      Color medalColor,
      double barHeight,
      double iconSize,
    ) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: iconSize, color: medalColor),
            const SizedBox(height: 4),
            StudentAvatar(
              schoolId: widget.schoolId,
              adm: r.adm,
              name: r.name,
              radius: 18,
            ),
            const SizedBox(height: 4),
            Text(
              r.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              'ADM ${r.adm}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${r.percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: iconSize == 24 ? 16 : 13,
                fontWeight: FontWeight.w500,
                color: _pctColor(r.percentage, cs),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: medalColor.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                border: Border(
                  top: BorderSide(
                    color: medalColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.15)
            : cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          podiumItem(second, silverColor, 40, 20),
          podiumItem(first, goldColor, 56, 24),
          podiumItem(third, bronzeColor, 28, 18),
        ],
      ),
    );
  }

  Widget _buildRankHeader(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.2 : 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 28), // avatar placeholder
          Expanded(
            flex: 3,
            child: Text(
              'Student',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              'Score',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              '%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(
    ColorScheme cs,
    bool isDark,
    _StudentRankRow r,
    int index,
  ) {
    final pctColor = _pctColor(r.percentage, cs);

    // Medal colors for top 3
    Color? medal;
    if (r.rank == 1) medal = const Color(0xFFFFD700);
    if (r.rank == 2) medal = const Color(0xFFC0C0C0);
    if (r.rank == 3) medal = const Color(0xFFCD7F32);

    return Container(
      decoration: BoxDecoration(
        color: index.isOdd
            ? cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.06 : 0.05)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.15),
            width: 0.5,
          ),
          left: medal != null
              ? BorderSide(color: medal.withValues(alpha: 0.6), width: 2.5)
              : BorderSide.none,
        ),
      ),
      child: InkWell(
        onTap: () {},
        hoverColor: cs.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: medal != null
                    ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                    : Text(
                        '${r.rank}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
              ),
              StudentAvatar(
                schoolId: widget.schoolId,
                adm: r.adm,
                name: r.name,
                radius: 13,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ADM ${r.adm}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${_fmtScore(r.totalScore)}/${r.totalPossible}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${r.percentage.toStringAsFixed(1)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: pctColor,
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

/// Data class for a single row in the student ranking table.
class _StudentRankRow {
  const _StudentRankRow({
    this.rank = 0,
    required this.name,
    required this.adm,
    required this.totalScore,
    required this.totalPossible,
    required this.percentage,
  });

  final int rank;
  final String name;
  final int adm;
  final double totalScore;
  final int totalPossible;
  final double percentage;

  _StudentRankRow copyWith({int? rank}) => _StudentRankRow(
    rank: rank ?? this.rank,
    name: name,
    adm: adm,
    totalScore: totalScore,
    totalPossible: totalPossible,
    percentage: percentage,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Paper Card
// ═════════════════════════════════════════════════════════════════════════════

class _PaperTimetableCard extends StatelessWidget {
  const _PaperTimetableCard({
    required this.paper,
    required this.subjectNames,
    required this.cs,
    required this.onTap,
    this.streamName,
  });
  final Paper paper;
  final Map<int, String> subjectNames;
  final ColorScheme cs;
  final VoidCallback onTap;

  /// When non-null, a stream badge is shown on the card.
  final String? streamName;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final statusColor = _examPaperStatusColor(paper.status, cs);
    final label = subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
    final paperLabel = paper.paper != null ? ' · Paper ${paper.paper}' : '';
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              border: Border(
                left: BorderSide(color: statusColor, width: 2.5),
                top: BorderSide(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.15 : 0.2,
                  ),
                ),
                right: BorderSide(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.15 : 0.2,
                  ),
                ),
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(
                    alpha: isDark ? 0.15 : 0.2,
                  ),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$label$paperLabel',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (streamName != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiary.withValues(
                                  alpha: cs.brightness == Brightness.dark
                                      ? 0.18
                                      : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                streamName!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: cs.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_fmtDate(startDt)} · ${_fmtTime(startDt)} – ${_fmtTime(endDt)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
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

class _PaperStatusLegend extends StatelessWidget {
  const _PaperStatusLegend();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: PaperStatus.values.map((s) {
          final color = _examPaperStatusColor(s, cs);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _examPaperStatusLabel(s),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Desktop papers cross-table (≥600px)
// ═════════════════════════════════════════════════════════════════════════════

/// Unified cross-table displayed in [_PapersTab] on desktop (≥600px).
/// Rows = unique grade+stream combinations present in [papers].
/// Columns = unique exam dates.
/// Cells = one or more papers stacked vertically (if multiple times same day).
class _PapersCrossTable extends StatelessWidget {
  const _PapersCrossTable({
    required this.papers,
    required this.subjectNames,
    required this.streamNames,
    required this.onTap,
  });

  final List<Paper> papers;
  final Map<int, String> subjectNames;

  /// Maps stream code → stream name for row labels.
  final Map<int, String> streamNames;
  final void Function(Paper) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Build row keys
    final rowKeys = <({int grade, int? stream})>[];
    final papersByRow = <({int grade, int? stream}), List<Paper>>{};
    for (final p in papers) {
      final key = (grade: p.grade, stream: p.stream);
      if (!papersByRow.containsKey(key)) {
        rowKeys.add(key);
        papersByRow[key] = [];
      }
      papersByRow[key]!.add(p);
    }
    rowKeys.sort((a, b) {
      final g = a.grade.compareTo(b.grade);
      if (g != 0) return g;
      if (a.stream == null && b.stream == null) return 0;
      if (a.stream == null) return -1;
      if (b.stream == null) return 1;
      return a.stream!.compareTo(b.stream!);
    });

    // Build unique time-slot columns
    final timeCols = <({String start, String end, int startMins})>[];
    {
      final seen = <int>{};
      final sorted = List<Paper>.from(papers)
        ..sort((a, b) => a.start.compareTo(b.start));
      for (final p in sorted) {
        if (p.start.toInt() == 0) continue;
        final sdt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
        final mins = sdt.hour * 60 + sdt.minute;
        if (seen.add(mins)) {
          final edt = DateTime.fromMillisecondsSinceEpoch(p.end.toInt() * 1000);
          timeCols.add((
            start: _fmtTime(sdt),
            end: _fmtTime(edt),
            startMins: mins,
          ));
        }
      }
    }

    final grouped = _groupExamPapersByDate(papers);
    final dates = _sortedExamPaperDates(grouped);

    if (rowKeys.isEmpty || timeCols.isEmpty || dates.isEmpty) {
      return _buildEmpty(cs, 'No papers added to this exam yet');
    }

    const double streamLabelW = 100;
    const double timeColW = 110;
    const double colGap = 3;
    final totalW =
        streamLabelW +
        colGap +
        timeCols.length * timeColW +
        (timeCols.length > 1 ? (timeCols.length - 1) * colGap : 0);

    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.15 : 0.2,
    );

    // Helper: find paper for row+date+time
    Paper? paperAt(
      ({int grade, int? stream}) key,
      DateTime date,
      int startMins,
    ) {
      final rowPapers = papersByRow[key] ?? [];
      for (final p in rowPapers) {
        final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
        final day = DateTime(dt.year, dt.month, dt.day);
        if (day == date && (dt.hour * 60 + dt.minute) == startMins) return p;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _PaperStatusLegend(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Time header row ──
                  Row(
                    children: [
                      const SizedBox(width: streamLabelW),
                      const SizedBox(width: colGap),
                      for (int i = 0; i < timeCols.length; i++) ...[
                        if (i > 0) const SizedBox(width: colGap),
                        SizedBox(
                          width: timeColW,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.kChipRadius,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${timeCols[i].start} – ${timeCols[i].end}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                                letterSpacing: 0.1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: colGap),

                  // ── Day groups ──
                  for (int di = 0; di < dates.length; di++) ...[
                    if (di > 0) const SizedBox(height: 10),
                    // Day header strip
                    Container(
                      width: totalW,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.25 : 0.20,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.kChipRadius,
                        ),
                      ),
                      child: Text(
                        _fmtDayHeader(dates[di]),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.75),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    // Stream rows for this day
                    for (final key in rowKeys) ...[
                      const SizedBox(height: colGap),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Stream label
                            SizedBox(
                              width: streamLabelW,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    key.stream != null
                                        ? (streamNames[key.stream] ?? '')
                                        : 'All Streams',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.55,
                                      ),
                                      letterSpacing: 0.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: colGap),

                            // Time slot cells
                            for (int ci = 0; ci < timeCols.length; ci++) ...[
                              if (ci > 0) const SizedBox(width: colGap),
                              SizedBox(
                                width: timeColW,
                                child: Builder(
                                  builder: (_) {
                                    final paper = paperAt(
                                      key,
                                      dates[di],
                                      timeCols[ci].startMins,
                                    );
                                    if (paper == null) {
                                      return Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 52,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.kChipRadius,
                                          ),
                                          border: Border.all(
                                            color: cs.outline.withValues(
                                              alpha: isDark ? 0.06 : 0.08,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                      );
                                    }
                                    return _buildCell(
                                      paper,
                                      cs,
                                      isDark,
                                      borderColor,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(
    Paper paper,
    ColorScheme cs,
    bool isDark,
    Color borderColor,
  ) {
    final statusColor = _examPaperStatusColor(paper.status, cs);
    final subjectName =
        subjectNames[paper.subject] ?? 'Subject ${paper.subject}';
    final paperLabel = paper.paper != null && paper.paper! > 1
        ? ' · P${paper.paper}'
        : '';

    return InkWell(
      onTap: () => onTap(paper),
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
          border: Border(
            left: BorderSide(
              color: statusColor.withValues(alpha: 0.6),
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          '$subjectName$paperLabel',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Badge Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.cs});
  final ExamType type;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final color = _typeColor(type, cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _OutlineBadge extends StatelessWidget {
  const _OutlineBadge({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.15 : 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TintedBadge extends StatelessWidget {
  const _TintedBadge({
    required this.label,
    required this.color,
    required this.cs,
  });
  final String label;
  final Color color;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.cs});
  final _GradingStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final (String label, Color color) = switch (status) {
      _GradingStatus.fullyGraded => ('Fully Graded', AppTheme.brandGreen),
      _GradingStatus.partiallyGraded => (
        'Partially Graded',
        const Color(0xFFF59E0B),
      ),
      _GradingStatus.notStarted => (
        'Not Started',
        cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PaperStatusChip extends StatelessWidget {
  const _PaperStatusChip({required this.status, required this.cs});
  final PaperStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final (String label, Color color) = switch (status) {
      PaperStatus.pending => (
        'Pending',
        cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      PaperStatus.progress => ('In Progress', const Color(0xFFF59E0B)),
      PaperStatus.done => ('Done', cs.primary),
      PaperStatus.marked => ('Marked', AppTheme.brandGreen),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═════════════════════════════════════════════════════════════════════════════

Widget _buildLoading(ColorScheme cs) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      ),
    ),
  );
}

Widget _buildEmpty(ColorScheme cs, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.quiz_outlined,
              size: 24,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ),
  );
}

String _typeLabel(ExamType type) => switch (type) {
  ExamType.exam => 'Exam',
  ExamType.assignment => 'Assignment',
  ExamType.assessment => 'Assessment',
};

Color _typeColor(ExamType type, ColorScheme cs) => switch (type) {
  ExamType.exam => cs.primary,
  ExamType.assignment => const Color(0xFFF59E0B),
  ExamType.assessment => AppTheme.brandGreen,
};

Color _pctColor(double pct, ColorScheme cs) {
  if (pct >= 70) return AppTheme.brandGreen;
  if (pct >= 50) return const Color(0xFFF59E0B);
  return cs.error;
}

Color _examPaperStatusColor(PaperStatus status, ColorScheme cs) =>
    switch (status) {
      PaperStatus.pending => cs.onSurfaceVariant.withValues(alpha: 0.3),
      PaperStatus.progress => const Color(0xFF42A5F5),
      PaperStatus.done => const Color(0xFFFFA726),
      PaperStatus.marked => const Color(0xFF66BB6A),
    };

String _examPaperStatusLabel(PaperStatus status) => switch (status) {
  PaperStatus.pending => 'Pending',
  PaperStatus.progress => 'In Progress',
  PaperStatus.done => 'Done',
  PaperStatus.marked => 'Marked',
};

class _DistributionDonutPainter extends CustomPainter {
  _DistributionDonutPainter({
    required this.counts,
    required this.colors,
    required this.trackColor,
  });
  final List<int> counts;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 20.0;
    final radius = size.width / 2 - strokeWidth / 2;

    // Draw track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    final total = counts.fold(0, (a, b) => a + b);
    if (total == 0) return;

    var startAngle = -math.pi / 2;
    const gapAngle = 0.03; // small gap between segments

    for (int i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final sweep = (counts[i] / total) * 2 * math.pi - gapAngle;
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = colors[i],
      );
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionDonutPainter old) => true;
}

String _fmtDayHeader(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[d.weekday - 1];
  return '$wd, ${d.day} ${_months[d.month - 1]}';
}

Map<DateTime, List<Paper>> _groupExamPapersByDate(List<Paper> papers) {
  final map = <DateTime, List<Paper>>{};
  for (final p in papers) {
    final dt = DateTime.fromMillisecondsSinceEpoch(p.start.toInt() * 1000);
    final day = DateTime(dt.year, dt.month, dt.day);
    map.putIfAbsent(day, () => []).add(p);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return map;
}

List<DateTime> _sortedExamPaperDates(Map<DateTime, List<Paper>> grouped) {
  final dates = grouped.keys.toList()..sort();
  return dates;
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

String _fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _fmtScore(double score) => score == score.truncateToDouble()
    ? score.toInt().toString()
    : score.toStringAsFixed(1);

const _months = [
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
