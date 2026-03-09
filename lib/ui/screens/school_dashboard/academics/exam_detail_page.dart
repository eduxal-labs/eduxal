import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/curriculum_levels.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_tab_bar.dart';
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

  @override
  State<ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<ExamDetailPage>
    with SingleTickerProviderStateMixin {
  late final ExamsGradesDao _dao;
  late final TabController _tabController;
  late Stream<List<Paper>> _papersStream;

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
    _papersStream = _dao.watchPapersForExam(
      schoolId: widget.schoolId,
      examId: widget.exam.exam.id,
    );
  }

  @override
  void dispose() {
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Summary card ───────────────────────────────────────────
          _ExamSummaryCard(
            exam: _exam,
            teacher: _teacher,
            streamName: widget.streamName,
            curriculumType: widget.curriculumType,
            papersStream: _papersStream,
          ),

          // ── Tab bar ────────────────────────────────────────────────
          EduTabBar(controller: _tabController, tabs: _tabs),

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
                  curriculumType: widget.curriculumType,
                  papersStream: _papersStream,
                  dao: _dao,
                  schoolContext: widget.schoolContext,
                ),
                _GradesTab(
                  exam: widget.exam,
                  schoolId: widget.schoolId,
                  year: widget.year,
                  term: widget.term,
                  curriculumType: widget.curriculumType,
                  dao: _dao,
                ),
                _PerformanceTab(
                  exam: widget.exam,
                  schoolId: widget.schoolId,
                  year: widget.year,
                  term: widget.term,
                  curriculumType: widget.curriculumType,
                  dao: _dao,
                ),
              ],
            ),
          ),
        ],
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
  });

  final Exam exam;
  final UsersData teacher;
  final String? streamName;
  final CurriculumType curriculumType;
  final Stream<List<Paper>> papersStream;

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
                  if (exam.stream == null)
                    _TintedBadge(
                      label: 'Grade-wide',
                      color: cs.tertiary,
                      cs: cs,
                    )
                  else if (streamName != null)
                    _TintedBadge(
                      label: streamName!,
                      color: cs.secondary,
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
    required this.curriculumType,
    required this.papersStream,
    required this.dao,
    required this.schoolContext,
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final CurriculumType curriculumType;
  final Stream<List<Paper>> papersStream;
  final ExamsGradesDao dao;
  final SchoolContext schoolContext;

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

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: papers.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _buildHeader(cs, papers.length);
            }
            return _PaperCard(
              paper: papers[i - 1],
              curriculumType: curriculumType,
              cs: cs,
              onTap: () => _onPaperTap(context, papers[i - 1]),
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
          curriculumType: curriculumType,
          schoolContext: schoolContext,
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
    required this.curriculumType,
    required this.dao,
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final CurriculumType curriculumType;
  final ExamsGradesDao dao;

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
      grade: widget.exam.exam.grade,
      stream: widget.exam.exam.stream,
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
    final headerBg = cs.surfaceContainerHighest.withValues(alpha: 0.35);
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
                color: headerBg,
                border: Border(
                  bottom: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                ),
              ),
              child: Text('Student', style: headerStyle),
            ),
            // Student rows
            ...rows.map(
              (r) => Container(
                height: rowHeight,
                width: fixedWidth,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor),
                    right: BorderSide(color: borderColor),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.student.name,
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
                      'ADM ${r.student.adm}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
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
            Row(
              children: [
                ...subjects.map((s) {
                  final label = useAbbrev
                      ? _abbreviateSubject(
                          subjectLabel(widget.curriculumType, s),
                        )
                      : subjectLabel(widget.curriculumType, s);
                  return Container(
                    width: cellWidth,
                    height: headerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: headerBg,
                      border: Border(
                        bottom: BorderSide(color: borderColor),
                        right: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Tooltip(
                      message: subjectLabel(widget.curriculumType, s),
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
                // Total header
                Container(
                  width: totalCellWidth,
                  height: headerHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(
                      bottom: BorderSide(color: borderColor),
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
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Text('%', style: headerStyle),
                ),
              ],
            ),
            // ── Data rows ──
            ...rows.map((r) {
              return Row(
                children: [
                  ...subjects.map((s) {
                    final g = r.subjectGrades[s];
                    return Container(
                      width: cellWidth,
                      height: rowHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: borderColor),
                          right: BorderSide(color: borderColor),
                        ),
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
                  // Total cell
                  Container(
                    width: totalCellWidth,
                    height: rowHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: borderColor),
                        right: BorderSide(color: borderColor),
                      ),
                    ),
                    child: r.hasGrades
                        ? Text(
                            '${_fmtScore(r.totalScore)}/${r.totalPossible}',
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
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: r.hasGrades
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _pctColor(
                                r.percentage,
                                cs,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${r.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _pctColor(r.percentage, cs),
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
              );
            }),
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
          curriculumType: widget.curriculumType,
          cs: cs,
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
    required this.curriculumType,
    required this.cs,
  });

  final _StudentGradeRow row;
  final List<int> subjects;
  final CurriculumType curriculumType;
  final ColorScheme cs;

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
      padding: const EdgeInsets.only(bottom: 6),
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
                            fontWeight: FontWeight.w600,
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
                  ...widget.subjects.map((s) {
                    final g = row.subjectGrades[s];
                    final label = subjectLabel(widget.curriculumType, s);
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
                    final sp = g.total > 0 ? (g.score / g.total) * 100 : 0.0;
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
                                valueColor: AlwaysStoppedAnimation(barColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Total row
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: cs.outlineVariant.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
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
                            fontWeight: FontWeight.w600,
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
    required this.curriculumType,
    required this.dao,
  });

  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final CurriculumType curriculumType;
  final ExamsGradesDao dao;

  @override
  State<_PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<_PerformanceTab>
    with AutomaticKeepAliveClientMixin {
  Map<int, PaperAnalytics>? _analytics;
  List<_StudentRankRow>? _rankings;
  List<StudentsData>? _enrolled;
  bool _loading = true;

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
      grade: widget.exam.exam.grade,
      stream: widget.exam.exam.stream,
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

    final byStudent = <int, List<Grade>>{};
    for (final g in relevantGrades) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) return _buildLoading(cs);

    final analytics = _analytics;
    final rankings = _rankings;
    final enrolled = _enrolled;

    if (analytics == null || analytics.isEmpty) {
      return _buildEmpty(cs, 'No grades recorded for this exam yet');
    }

    // Overall class average
    double totalAvg = 0;
    for (final a in analytics.values) {
      totalAvg += a.averagePercent;
    }
    final overallAvg = totalAvg / analytics.length;
    final totalGraded = rankings?.length ?? 0;
    final totalEnrolled = enrolled?.length ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Summary card ──
        _buildSummaryCard(
          cs,
          overallAvg,
          totalGraded,
          totalEnrolled,
          analytics.length,
        ),
        const SizedBox(height: 20),

        // ── Grade distribution chart ──
        _buildDistributionChart(cs, analytics),
        const SizedBox(height: 20),

        // ── Subject performance bars ──
        _buildSectionLabel(cs, 'Subject Performance'),
        const SizedBox(height: 10),
        ...analytics.entries.map(
          (entry) => _buildSubjectBar(cs, entry.key, entry.value),
        ),

        if (rankings != null && rankings.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionLabel(cs, 'Student Ranking'),
          const SizedBox(height: 10),
          _buildRankingTable(cs, rankings),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(
    ColorScheme cs,
    double overallAvg,
    int totalGraded,
    int totalEnrolled,
    int subjectCount,
  ) {
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${overallAvg.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: _pctColor(overallAvg, cs),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Class Average',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: cs.outlineVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalGraded / $totalEnrolled',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Students Graded',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$subjectCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBar(ColorScheme cs, int subjectCode, PaperAnalytics pa) {
    final label = subjectLabel(widget.curriculumType, subjectCode);
    final avg = pa.averagePercent;
    final barColor = avg >= 75
        ? AppTheme.brandGreen
        : avg >= 50
        ? const Color(0xFFF59E0B)
        : cs.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${avg.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: (avg / 100).clamp(0.0, 1.0),
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aggregate distribution across all subjects and render a bar chart.
  Widget _buildDistributionChart(
    ColorScheme cs,
    Map<int, PaperAnalytics> analytics,
  ) {
    // Merge distributions from all subjects into one aggregate map.
    final aggregate = <String, int>{};
    for (final pa in analytics.values) {
      for (final entry in pa.distribution.entries) {
        aggregate[entry.key] = (aggregate[entry.key] ?? 0) + entry.value;
      }
    }
    if (aggregate.isEmpty) return const SizedBox.shrink();

    // Ensure consistent bucket order.
    const bucketOrder = ['0–39', '40–49', '50–59', '60–69', '70–79', '80–100'];
    final keys = <String>[];
    final values = <int>[];
    for (final b in bucketOrder) {
      if (aggregate.containsKey(b)) {
        keys.add(b);
        values.add(aggregate[b]!);
      }
    }
    // Append any extra keys not in predefined order (safety fallback).
    for (final k in aggregate.keys) {
      if (!bucketOrder.contains(k)) {
        keys.add(k);
        values.add(aggregate[k]!);
      }
    }

    final maxVal = values.fold(0, math.max).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(cs, 'Grade Distribution'),
        const SizedBox(height: 10),
        Material(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              border: Border.all(color: cs.outlineVariant, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: SizedBox(
              height: 90,
              child: BarChart(
                BarChartData(
                  maxY: maxVal <= 0 ? 5 : maxVal * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              keys[idx],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          );
                        },
                        reservedSize: 20,
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => cs.surfaceContainer,
                      tooltipRoundedRadius: 4,
                      getTooltipItem: (group, gIdx, rod, rIdx) {
                        final idx = group.x;
                        if (idx < 0 || idx >= keys.length) return null;
                        return BarTooltipItem(
                          '${keys[idx]}: ${values[idx]}',
                          TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(values.length, (i) {
                    final pct = values.length > 1
                        ? i / (values.length - 1)
                        : 0.5;
                    final barColor = Color.lerp(
                      const Color(0xFFE57373),
                      AppTheme.brandGreen,
                      pct,
                    )!;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].toDouble(),
                          color: barColor.withValues(
                            alpha: cs.brightness == Brightness.dark
                                ? 0.8
                                : 0.75,
                          ),
                          width: 14,
                          borderRadius: BorderRadius.circular(3),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxVal <= 0 ? 5 : maxVal * 1.2,
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingTable(ColorScheme cs, List<_StudentRankRow> rankings) {
    // Medal colors for top 3.
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    Color? _medalTint(int rank) {
      switch (rank) {
        case 1:
          return goldColor;
        case 2:
          return silverColor;
        case 3:
          return bronzeColor;
        default:
          return null;
      }
    }

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header row
            Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                    width: 60,
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
                    width: 50,
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
            ),
            // Data rows
            ...List.generate(rankings.length, (i) {
              final r = rankings[i];
              final isEven = i.isEven;
              final pctColor = _pctColor(r.percentage, cs);
              final medal = _medalTint(r.rank);
              final rowBg = medal != null
                  ? medal.withValues(
                      alpha: cs.brightness == Brightness.dark ? 0.08 : 0.06,
                    )
                  : isEven
                  ? Colors.transparent
                  : cs.surfaceContainerHighest.withValues(alpha: 0.15);
              return Container(
                decoration: BoxDecoration(
                  color: rowBg,
                  border: medal != null
                      ? Border(
                          left: BorderSide(
                            color: medal.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        )
                      : null,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${r.rank}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: medal != null
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: medal ?? cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${r.adm}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${_fmtScore(r.totalScore)}/${r.totalPossible}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r.percentage.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: pctColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              height: 3,
                              width: 50,
                              child: LinearProgressIndicator(
                                value: (r.percentage / 100).clamp(0.0, 1.0),
                                backgroundColor: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation(pctColor),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildSectionLabel(ColorScheme cs, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 0.3,
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

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.paper,
    required this.curriculumType,
    required this.cs,
    required this.onTap,
  });

  final Paper paper;
  final CurriculumType curriculumType;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = subjectLabel(curriculumType, paper.subject);
    final paperLabel = paper.paper != null ? ' · Paper ${paper.paper}' : '';
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label$paperLabel',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_fmtDate(startDt)} · ${_fmtTime(startDt)} – ${_fmtTime(endDt)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _PaperStatusChip(status: paper.status, cs: cs),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
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
