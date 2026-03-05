import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/daos/subjects_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/active_term_context.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_config.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/active_term_provider.dart';
import '../../../widgets/animated_save_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level entry point for the Exams & Grades section.
///
/// Mounted from the dashboard shell under the "Exams & Grades" nav label
/// (teacher view) and the "Academics" → Exams tab (owner/staff view).
class ExamsGradesScreen extends StatelessWidget {
  const ExamsGradesScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    final termCtx = ActiveTermProvider.of(context);
    if (termCtx.currentTerm == null) {
      return const _NoTermState();
    }
    return _ExamsShell(schoolContext: schoolContext, termContext: termCtx);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell — owns navigation state (exam list → exam detail → paper detail)
// ─────────────────────────────────────────────────────────────────────────────

enum _ExamsView { list, examDetail, paperDetail }

class _ExamsShell extends StatefulWidget {
  const _ExamsShell({required this.schoolContext, required this.termContext});
  final SchoolContext schoolContext;
  final ActiveTermContext termContext;

  @override
  State<_ExamsShell> createState() => _ExamsShellState();
}

class _ExamsShellState extends State<_ExamsShell> {
  _ExamsView _view = _ExamsView.list;
  ExamWithPapers? _selectedExam;
  Paper? _selectedPaper;
  SchoolConfig _config = SchoolConfig.defaults();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final schoolId = widget.schoolContext.membership.school.id;
    final row = await (db.select(
      db.settings,
    )..where((s) => s.school.equals(schoolId))).getSingleOrNull();
    if (row == null || !mounted) return;
    try {
      final decoded = Map<String, dynamic>.from(_jsonDecode(row.data) as Map);
      setState(() => _config = SchoolConfig.fromJson(decoded));
    } catch (_) {}
  }

  void _openExam(ExamWithPapers ep) {
    setState(() {
      _selectedExam = ep;
      _view = _ExamsView.examDetail;
    });
  }

  void _openPaper(Paper paper) {
    setState(() {
      _selectedPaper = paper;
      _view = _ExamsView.paperDetail;
    });
  }

  void _popToExam() {
    setState(() {
      _selectedPaper = null;
      _view = _ExamsView.examDetail;
    });
  }

  void _popToList() {
    setState(() {
      _selectedExam = null;
      _selectedPaper = null;
      _view = _ExamsView.list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = widget.schoolContext.membership.school.id;
    final term = widget.termContext.currentTerm!;
    final entry = widget.schoolContext.currentEntry.value;

    return switch (_view) {
      _ExamsView.list => _ExamsListView(
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        schoolContext: widget.schoolContext,
        config: _config,
        entry: entry,
        onExamTap: _openExam,
      ),
      _ExamsView.examDetail => _ExamDetailView(
        exam: _selectedExam!,
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        config: _config,
        entry: entry,
        onBack: _popToList,
        onPaperTap: _openPaper,
      ),
      _ExamsView.paperDetail => _PaperDetailView(
        exam: _selectedExam!,
        paper: _selectedPaper!,
        schoolId: schoolId,
        year: term.year,
        term: term.term,
        config: _config,
        entry: entry,
        onBack: _popToExam,
      ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exams list view
// ─────────────────────────────────────────────────────────────────────────────

class _ExamsListView extends StatefulWidget {
  const _ExamsListView({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.schoolContext,
    required this.config,
    required this.entry,
    required this.onExamTap,
  });
  final String schoolId;
  final int year;
  final int term;
  final SchoolContext schoolContext;
  final SchoolConfig config;
  final MembershipEntry entry;
  final ValueChanged<ExamWithPapers> onExamTap;

  @override
  State<_ExamsListView> createState() => _ExamsListViewState();
}

class _ExamsListViewState extends State<_ExamsListView> {
  late final ExamsGradesDao _dao;

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
  }

  Stream<List<ExamWithPapers>> _buildStream() {
    final entry = widget.entry;
    // Teacher view — filter to their own classes.
    if (entry is TeacherEntry) {
      return _dao.watchExamsForTerm(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
      );
    }
    return _dao.watchExamsForTerm(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Exams & Assessments',
          subtitle: '${widget.year} · Term ${widget.term}',
          action: _canManage
              ? _HeaderAction(
                  icon: Icons.add,
                  label: 'New Exam',
                  onTap: () => _showCreateExam(context),
                )
              : null,
        ),
        Expanded(
          child: StreamBuilder<List<ExamWithPapers>>(
            stream: _buildStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                );
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return _EmptyExamsState(
                  canCreate: _canManage,
                  onCreate: () => _showCreateExam(context),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ExamCard(
                  ep: items[i],
                  config: widget.config,
                  cs: cs,
                  canManage: _canManage,
                  onTap: () => widget.onExamTap(items[i]),
                  onDelete: _canManage
                      ? () => _confirmDelete(context, items[i].exam)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool get _canManage {
    final entry = widget.entry;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
  }

  Future<void> _showCreateExam(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateExamSheet(
        schoolId: widget.schoolId,
        year: widget.year,
        term: widget.term,
        config: widget.config,
        entry: widget.entry,
        dao: _dao,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        title: 'Delete Exam',
        message:
            'This will permanently delete the exam and all its papers and grades. '
            'This action cannot be undone.',
        confirmLabel: 'Delete Exam',
      ),
    );
    if (confirmed != true || !mounted) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    await _dao.deleteExam(examId: exam.id, accountId: accountId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exam card
// ─────────────────────────────────────────────────────────────────────────────

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.ep,
    required this.config,
    required this.cs,
    required this.canManage,
    required this.onTap,
    required this.onDelete,
  });
  final ExamWithPapers ep;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final exam = ep.exam;
    final gradeLabel = _gradeLabel(exam.grade, config);
    final streamLabel = exam.stream != null
        ? _streamLabel(exam.grade, exam.stream!, config)
        : 'All Streams';
    final typeColor = _typeColor(exam.type, cs);
    final typeLabel = _typeLabel(exam.type);
    final startDate = DateTime.fromMillisecondsSinceEpoch(
      exam.start * 86400 * 1000,
    );
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      exam.end * 86400 * 1000,
    );

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ClassChip(label: '$gradeLabel · $streamLabel', cs: cs),
                  const Spacer(),
                  if (canManage && onDelete != null)
                    _IconActionButton(
                      icon: Icons.delete_outline,
                      color: cs.error,
                      onTap: onDelete!,
                      tooltip: 'Delete',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${ep.teacher.name}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fmtDate(startDate)} – ${_fmtDate(endDate)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetaBadge(
                    icon: Icons.description_outlined,
                    label:
                        '${ep.papers.length} paper${ep.papers.length == 1 ? '' : 's'}',
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  if (exam.personalized)
                    _MetaBadge(
                      icon: Icons.person_outline,
                      label: 'Personalized',
                      cs: cs,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exam detail view — papers list + summary stats
// ─────────────────────────────────────────────────────────────────────────────

class _ExamDetailView extends StatefulWidget {
  const _ExamDetailView({
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.entry,
    required this.onBack,
    required this.onPaperTap,
  });
  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final MembershipEntry entry;
  final VoidCallback onBack;
  final ValueChanged<Paper> onPaperTap;

  @override
  State<_ExamDetailView> createState() => _ExamDetailViewState();
}

class _ExamDetailViewState extends State<_ExamDetailView> {
  late final ExamsGradesDao _dao;
  late final SubjectsDao _subjectsDao;

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _subjectsDao = SubjectsDao(db);
  }

  bool get _canManage {
    final entry = widget.entry;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final exam = widget.exam.exam;
    final gradeLabel = _gradeLabel(exam.grade, widget.config);
    final streamLabel = exam.stream != null
        ? _streamLabel(exam.grade, exam.stream!, widget.config)
        : 'All Streams';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: _typeLabel(exam.type),
          subtitle:
              '$gradeLabel · $streamLabel · ${widget.year} T${widget.term}',
          leadingAction: _HeaderAction(
            icon: Icons.arrow_back,
            label: 'Back',
            onTap: widget.onBack,
          ),
          action: _canManage
              ? _HeaderAction(
                  icon: Icons.add,
                  label: 'Add Paper',
                  onTap: () => _showAddPaper(context),
                )
              : null,
        ),
        Expanded(
          child: StreamBuilder<List<Paper>>(
            stream: _dao.watchPapersForExam(
              schoolId: widget.schoolId,
              examId: exam.id,
            ),
            builder: (context, snap) {
              final papers = snap.data ?? [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Exam summary card
                  _ExamSummaryCard(
                    exam: exam,
                    teacher: widget.exam.teacher,
                    config: widget.config,
                    cs: cs,
                  ),
                  const SizedBox(height: 20),
                  if (papers.isNotEmpty) ...[
                    _SubLabel(label: 'Papers', cs: cs),
                    const SizedBox(height: 10),
                    ...papers.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PaperCard(
                          paper: p,
                          config: widget.config,
                          cs: cs,
                          canManage: _canManage,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          onTap: () => widget.onPaperTap(p),
                          onDelete: _canManage
                              ? () => _confirmDeletePaper(context, p)
                              : null,
                        ),
                      ),
                    ),
                  ] else ...[
                    _EmptyPapersState(
                      canCreate: _canManage,
                      onCreate: () => _showAddPaper(context),
                      cs: cs,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddPaper(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePaperSheet(
        schoolId: widget.schoolId,
        examId: widget.exam.exam.id,
        year: widget.year,
        term: widget.term,
        grade: widget.exam.exam.grade,
        stream: widget.exam.exam.stream,
        config: widget.config,
        dao: _dao,
        subjectsDao: _subjectsDao,
      ),
    );
  }

  Future<void> _confirmDeletePaper(BuildContext context, Paper paper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        title: 'Delete Paper',
        message: 'All grades for this paper will be permanently deleted.',
        confirmLabel: 'Delete Paper',
      ),
    );
    if (confirmed != true || !mounted) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    await _dao.deletePaper(
      schoolId: widget.schoolId,
      examId: widget.exam.exam.id,
      subject: paper.subject,
      paperNum: paper.paper,
      accountId: accountId,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper detail view — analytics header + grading spreadsheet/list
// ─────────────────────────────────────────────────────────────────────────────

class _PaperDetailView extends StatefulWidget {
  const _PaperDetailView({
    required this.exam,
    required this.paper,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.entry,
    required this.onBack,
  });
  final ExamWithPapers exam;
  final Paper paper;
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final MembershipEntry entry;
  final VoidCallback onBack;

  @override
  State<_PaperDetailView> createState() => _PaperDetailViewState();
}

class _PaperDetailViewState extends State<_PaperDetailView> {
  late final ExamsGradesDao _dao;
  List<StudentsData> _students = [];
  bool _loadingStudents = true;

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final exam = widget.exam.exam;
    final list = await _dao.getEnrolledStudents(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: exam.grade,
      stream: exam.stream,
    );
    if (!mounted) return;
    setState(() {
      _students = list;
      _loadingStudents = false;
    });
  }

  bool get _canGrade {
    final entry = widget.entry;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paper = widget.paper;
    final exam = widget.exam.exam;
    final subjectLabel = _subjectLabel(paper.subject, widget.config);
    final paperLabel = paper.paper != null ? ' Paper ${paper.paper}' : '';
    final gradeLabel = _gradeLabel(exam.grade, widget.config);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: '$subjectLabel$paperLabel',
          subtitle: '$gradeLabel · ${widget.year} T${widget.term}',
          leadingAction: _HeaderAction(
            icon: Icons.arrow_back,
            label: 'Back',
            onTap: widget.onBack,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<GradeRow>>(
            stream: _dao.watchGradesForPaper(
              schoolId: widget.schoolId,
              examId: exam.id,
              subject: paper.subject,
              paper: paper.paper,
            ),
            builder: (context, snap) {
              if (_loadingStudents ||
                  snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                );
              }
              final gradeRows = snap.data ?? [];
              final gradeMap = {
                for (final r in gradeRows) r.student.adm: r.grade,
              };

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop =
                      constraints.maxWidth >= AppTheme.kMobileBreakpoint;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      // ── Analytics header ───────────────────────────────
                      _AnalyticsHeader(
                        schoolId: widget.schoolId,
                        examId: exam.id,
                        subject: paper.subject,
                        paper: paper.paper,
                        gradeRows: gradeRows,
                        totalStudents: _students.length,
                        dao: _dao,
                        cs: cs,
                      ),
                      const SizedBox(height: 20),
                      // ── Paper status chip ───────────────────────────────
                      _PaperStatusRow(
                        paper: paper,
                        schoolId: widget.schoolId,
                        exam: exam,
                        dao: _dao,
                        canManage: _canGrade,
                        cs: cs,
                      ),
                      const SizedBox(height: 20),
                      // ── Grading view ───────────────────────────────────
                      if (_students.isEmpty)
                        _NoStudentsState(cs: cs)
                      else if (isDesktop)
                        _GradeSpreadsheet(
                          students: _students,
                          gradeMap: gradeMap,
                          paper: paper,
                          exam: exam,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          canGrade: _canGrade,
                          cs: cs,
                        )
                      else
                        _GradeList(
                          students: _students,
                          gradeMap: gradeMap,
                          paper: paper,
                          exam: exam,
                          schoolId: widget.schoolId,
                          dao: _dao,
                          canGrade: _canGrade,
                          cs: cs,
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics header — donut + bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.schoolId,
    required this.examId,
    required this.subject,
    required this.paper,
    required this.gradeRows,
    required this.totalStudents,
    required this.dao,
    required this.cs,
  });
  final String schoolId;
  final String examId;
  final int subject;
  final int? paper;
  final List<GradeRow> gradeRows;
  final int totalStudents;
  final ExamsGradesDao dao;
  final ColorScheme cs;

  PaperAnalytics _compute() {
    if (gradeRows.isEmpty) {
      return PaperAnalytics(
        totalStudents: totalStudents,
        gradedStudents: 0,
        averageScore: 0,
        averagePercent: 0,
        distribution: {
          '0–39': 0,
          '40–49': 0,
          '50–59': 0,
          '60–69': 0,
          '70–79': 0,
          '80–100': 0,
        },
      );
    }

    double totalScore = 0;
    double totalPercent = 0;
    final dist = <String, int>{
      '0–39': 0,
      '40–49': 0,
      '50–59': 0,
      '60–69': 0,
      '70–79': 0,
      '80–100': 0,
    };

    for (final row in gradeRows) {
      final pct = row.grade.total > 0
          ? (row.grade.score / row.grade.total) * 100
          : 0.0;
      totalScore += row.grade.score;
      totalPercent += pct;
      if (pct < 40) {
        dist['0–39'] = dist['0–39']! + 1;
      } else if (pct < 50) {
        dist['40–49'] = dist['40–49']! + 1;
      } else if (pct < 60) {
        dist['50–59'] = dist['50–59']! + 1;
      } else if (pct < 70) {
        dist['60–69'] = dist['60–69']! + 1;
      } else if (pct < 80) {
        dist['70–79'] = dist['70–79']! + 1;
      } else {
        dist['80–100'] = dist['80–100']! + 1;
      }
    }

    return PaperAnalytics(
      totalStudents: totalStudents,
      gradedStudents: gradeRows.length,
      averageScore: totalScore / gradeRows.length,
      averagePercent: totalPercent / gradeRows.length,
      distribution: dist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _compute();
    final gradedPct = totalStudents > 0
        ? analytics.gradedStudents / totalStudents
        : 0.0;
    final avgPct = analytics.averagePercent;

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 560;
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DonutChart(
                        gradedPct: gradedPct,
                        avgPct: avgPct / 100,
                        analytics: analytics,
                        cs: cs,
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: _DistributionChart(
                          distribution: analytics.distribution,
                          cs: cs,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _DonutChart(
                        gradedPct: gradedPct,
                        avgPct: avgPct / 100,
                        analytics: analytics,
                        cs: cs,
                      ),
                      const SizedBox(height: 20),
                      _DistributionChart(
                        distribution: analytics.distribution,
                        cs: cs,
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut chart — completion and average
// ─────────────────────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.gradedPct,
    required this.avgPct,
    required this.analytics,
    required this.cs,
  });
  final double gradedPct; // 0–1
  final double avgPct; // 0–1 (average / 100)
  final PaperAnalytics analytics;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final primary = cs.primary;
    final trackColor = isDark
        ? const Color(0xFF1A2435)
        : const Color(0xFFF1F3F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 0,
                      centerSpaceRadius: 28,
                      sections: [
                        PieChartSectionData(
                          value: gradedPct,
                          color: primary,
                          radius: 12,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: 1 - gradedPct,
                          color: trackColor,
                          radius: 12,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(gradedPct * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${analytics.gradedStudents}/${analytics.totalStudents}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'graded',
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
        const SizedBox(height: 14),
        _StatRow(
          label: 'Class average',
          value: '${analytics.averagePercent.toStringAsFixed(1)}%',
          cs: cs,
        ),
        const SizedBox(height: 4),
        _StatRow(
          label: 'Mean score',
          value: analytics.averageScore.toStringAsFixed(1),
          cs: cs,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.cs});
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Distribution bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _DistributionChart extends StatelessWidget {
  const _DistributionChart({required this.distribution, required this.cs});
  final Map<String, int> distribution;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final keys = distribution.keys.toList();
    final values = distribution.values.toList();
    final maxVal = values.fold(0, math.max).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grade Distribution',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
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
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      );
                    },
                    reservedSize: 20,
                  ),
                ),
              ),
              barGroups: List.generate(values.length, (i) {
                final pct = i / (values.length - 1);
                // Gradient: low = muted red, high = brand green
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
                        alpha: cs.brightness == Brightness.dark ? 0.8 : 0.75,
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper status chip row
// ─────────────────────────────────────────────────────────────────────────────

class _PaperStatusRow extends StatelessWidget {
  const _PaperStatusRow({
    required this.paper,
    required this.schoolId,
    required this.exam,
    required this.dao,
    required this.canManage,
    required this.cs,
  });
  final Paper paper;
  final String schoolId;
  final Exam exam;
  final ExamsGradesDao dao;
  final bool canManage;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusChip(status: paper.status, cs: cs),
        const Spacer(),
        if (canManage)
          _StatusAdvanceButton(
            paper: paper,
            schoolId: schoolId,
            exam: exam,
            dao: dao,
            cs: cs,
          ),
      ],
    );
  }
}

class _StatusAdvanceButton extends StatefulWidget {
  const _StatusAdvanceButton({
    required this.paper,
    required this.schoolId,
    required this.exam,
    required this.dao,
    required this.cs,
  });
  final Paper paper;
  final String schoolId;
  final Exam exam;
  final ExamsGradesDao dao;
  final ColorScheme cs;

  @override
  State<_StatusAdvanceButton> createState() => _StatusAdvanceButtonState();
}

class _StatusAdvanceButtonState extends State<_StatusAdvanceButton> {
  bool _busy = false;

  Future<void> _advance() async {
    final next = _nextStatus(widget.paper.status);
    if (next == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;
    setState(() => _busy = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.updatePaper(
        schoolId: widget.schoolId,
        examId: widget.exam.id,
        subject: widget.paper.subject,
        paperNum: widget.paper.paper,
        changes: PapersCompanion(status: Value(next), updated: Value(now)),
        accountId: accountId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PaperStatus? _nextStatus(PaperStatus s) => switch (s) {
    PaperStatus.pending => PaperStatus.progress,
    PaperStatus.progress => PaperStatus.done,
    PaperStatus.done => PaperStatus.marked,
    PaperStatus.marked => null,
  };

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus(widget.paper.status);
    if (next == null) return const SizedBox.shrink();

    return AnimatedSaveButton(isDirty: true, isSaving: _busy, onSave: _advance);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grading spreadsheet — desktop, keyboard-navigable
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSpreadsheet extends StatefulWidget {
  const _GradeSpreadsheet({
    required this.students,
    required this.gradeMap,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    required this.canGrade,
    required this.cs,
  });
  final List<StudentsData> students;
  final Map<int, Grade> gradeMap;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final bool canGrade;
  final ColorScheme cs;

  @override
  State<_GradeSpreadsheet> createState() => _GradeSpreadsheetState();
}

class _GradeSpreadsheetState extends State<_GradeSpreadsheet> {
  // Local draft state: adm → raw score string being edited
  final Map<int, String> _drafts = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, bool> _saving = {};

  // Default max score from any existing grade, fallback 100
  int _maxScore = 100;

  @override
  void initState() {
    super.initState();
    _initFromMap();
  }

  @override
  void didUpdateWidget(_GradeSpreadsheet old) {
    super.didUpdateWidget(old);
    // Refresh controllers that aren't being actively edited
    for (final student in widget.students) {
      final adm = student.adm;
      final grade = widget.gradeMap[adm];
      final ctrl = _controllers[adm];
      if (ctrl != null && !(_focusNodes[adm]?.hasFocus ?? false)) {
        final newVal = grade != null ? _fmtScore(grade.score) : '';
        if (ctrl.text != newVal) ctrl.text = newVal;
        if (grade != null) _maxScore = grade.total;
      }
    }
  }

  void _initFromMap() {
    for (final student in widget.students) {
      final adm = student.adm;
      final grade = widget.gradeMap[adm];
      final initial = grade != null ? _fmtScore(grade.score) : '';
      _controllers[adm] = TextEditingController(text: initial);
      _focusNodes[adm] = FocusNode();
      if (grade != null) _maxScore = grade.total;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _saveRow(int adm, String rawInput) async {
    if (!widget.canGrade) return;
    final score = double.tryParse(rawInput);
    if (score == null || score < 0 || score > _maxScore) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() => _saving[adm] = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.upsertGrade(
        grade: GradesCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.exam.id),
          student: Value(adm),
          subject: Value(widget.paper.subject),
          paper: Value(widget.paper.paper),
          score: Value(score),
          total: Value(_maxScore),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
    } finally {
      if (mounted) setState(() => _saving[adm] = false);
    }
  }

  void _focusNext(int currentIndex) {
    final next = currentIndex + 1;
    if (next < widget.students.length) {
      _focusNodes[widget.students[next].adm]?.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = cs.brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1A2435) : const Color(0xFFF1F3F5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kRadius),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                flex: 3,
                child: Text(
                  'Student',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  'Score / $_maxScore',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppTheme.kRadius),
          ),
          elevation: 2,
          shadowColor: cs.shadow.withValues(alpha: 0.08),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.students.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (context, i) {
              final student = widget.students[i];
              final adm = student.adm;
              final existingGrade = widget.gradeMap[adm];
              final isDirty =
                  _drafts.containsKey(adm) &&
                  _drafts[adm] !=
                      (existingGrade != null
                          ? _fmtScore(existingGrade.score)
                          : '');
              final isSaving = _saving[adm] ?? false;

              return _SpreadsheetRow(
                student: student,
                controller: _controllers[adm]!,
                focusNode: _focusNodes[adm]!,
                existingGrade: existingGrade,
                maxScore: _maxScore,
                isDirty: isDirty,
                isSaving: isSaving,
                canGrade: widget.canGrade,
                cs: cs,
                onChanged: (v) {
                  setState(() => _drafts[adm] = v);
                },
                onSave: () => _saveRow(adm, _controllers[adm]!.text),
                onSubmitted: (_) {
                  _saveRow(adm, _controllers[adm]!.text);
                  _focusNext(i);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SpreadsheetRow extends StatelessWidget {
  const _SpreadsheetRow({
    required this.student,
    required this.controller,
    required this.focusNode,
    required this.existingGrade,
    required this.maxScore,
    required this.isDirty,
    required this.isSaving,
    required this.canGrade,
    required this.cs,
    required this.onChanged,
    required this.onSave,
    required this.onSubmitted,
  });
  final StudentsData student;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Grade? existingGrade;
  final int maxScore;
  final bool isDirty;
  final bool isSaving;
  final bool canGrade;
  final ColorScheme cs;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final ValueChanged<String> onSubmitted;

  double? get _pct {
    if (existingGrade == null) return null;
    if (existingGrade!.total <= 0) return null;
    return (existingGrade!.score / existingGrade!.total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final pct = _pct;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Adm number badge
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '${student.adm}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            flex: 3,
            child: Text(
              student.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score input
          SizedBox(
            width: 80,
            child: canGrade
                ? TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                    onChanged: onChanged,
                    onFieldSubmitted: onSubmitted,
                  )
                : Text(
                    existingGrade != null
                        ? _fmtScore(existingGrade!.score)
                        : '–',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Percentage badge
          SizedBox(
            width: 44,
            child: pct != null
                ? Text(
                    '${pct.toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _pctColor(pct, cs),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Save button
          if (canGrade)
            AnimatedSaveButton(
              isDirty: isDirty,
              isSaving: isSaving,
              onSave: isDirty ? onSave : null,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grade list — mobile, one row per student with large tap area
// ─────────────────────────────────────────────────────────────────────────────

class _GradeList extends StatefulWidget {
  const _GradeList({
    required this.students,
    required this.gradeMap,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
    required this.canGrade,
    required this.cs,
  });
  final List<StudentsData> students;
  final Map<int, Grade> gradeMap;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;
  final bool canGrade;
  final ColorScheme cs;

  @override
  State<_GradeList> createState() => _GradeListState();
}

class _GradeListState extends State<_GradeList> {
  int _maxScore = 100;

  @override
  void initState() {
    super.initState();
    final first = widget.gradeMap.values.firstOrNull;
    if (first != null) _maxScore = first.total;
  }

  void _openGradeEntry(BuildContext context, StudentsData student) {
    if (!widget.canGrade) return;
    final existing = widget.gradeMap[student.adm];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MobileGradeEntrySheet(
        student: student,
        existingGrade: existing,
        maxScore: _maxScore,
        paper: widget.paper,
        exam: widget.exam,
        schoolId: widget.schoolId,
        dao: widget.dao,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.students.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: cs.outlineVariant.withValues(alpha: 0.25),
        ),
        itemBuilder: (context, i) {
          final student = widget.students[i];
          final grade = widget.gradeMap[student.adm];
          final pct = grade != null && grade.total > 0
              ? (grade.score / grade.total) * 100
              : null;

          return InkWell(
            onTap: widget.canGrade
                ? () => _openGradeEntry(context, student)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Adm: ${student.adm}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (grade != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_fmtScore(grade.score)} / ${grade.total}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        if (pct != null)
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: _pctColor(pct, cs),
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      widget.canGrade ? 'Tap to grade' : 'Not graded',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                  if (widget.canGrade)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile grade entry sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MobileGradeEntrySheet extends StatefulWidget {
  const _MobileGradeEntrySheet({
    required this.student,
    required this.existingGrade,
    required this.maxScore,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.dao,
  });
  final StudentsData student;
  final Grade? existingGrade;
  final int maxScore;
  final Paper paper;
  final Exam exam;
  final String schoolId;
  final ExamsGradesDao dao;

  @override
  State<_MobileGradeEntrySheet> createState() => _MobileGradeEntrySheetState();
}

class _MobileGradeEntrySheetState extends State<_MobileGradeEntrySheet> {
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _totalCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = TextEditingController(
      text: widget.existingGrade != null
          ? _fmtScore(widget.existingGrade!.score)
          : '',
    );
    _totalCtrl = TextEditingController(
      text: '${widget.existingGrade?.total ?? widget.maxScore}',
    );
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final score = double.parse(_scoreCtrl.text);
    final total = int.parse(_totalCtrl.text);

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await widget.dao.upsertGrade(
        grade: GradesCompanion(
          school: Value(widget.schoolId),
          exam: Value(widget.exam.id),
          student: Value(widget.student.adm),
          subject: Value(widget.paper.subject),
          paper: Value(widget.paper.paper),
          score: Value(score),
          total: Value(total),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.student.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Adm: ${widget.student.adm}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _scoreCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      decoration: _inputDeco(cs, label: 'Score'),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null) return 'Enter a valid number';
                        final total = int.tryParse(_totalCtrl.text) ?? 100;
                        if (n < 0 || n > total) return '0 – $total';
                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '/',
                      style: TextStyle(
                        fontSize: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _totalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDeco(cs, label: 'Out of'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text(
                        'Save Grade',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
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
// Create exam sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateExamSheet extends StatefulWidget {
  const _CreateExamSheet({
    required this.schoolId,
    required this.year,
    required this.term,
    required this.config,
    required this.entry,
    required this.dao,
  });
  final String schoolId;
  final int year;
  final int term;
  final SchoolConfig config;
  final MembershipEntry entry;
  final ExamsGradesDao dao;

  @override
  State<_CreateExamSheet> createState() => _CreateExamSheetState();
}

class _CreateExamSheetState extends State<_CreateExamSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  ExamType _type = ExamType.exam;
  int? _selectedGrade;
  int? _selectedStream; // null = all streams
  bool _allStreams = true;
  bool _personalized = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  List<GradeConfig> get _grades {
    if (widget.config.isEmpty) return [];
    final all = <GradeConfig>[];
    for (final c in widget.config.curricula) {
      all.addAll(c.grades);
    }
    return all..sort((a, b) => a.grade.compareTo(b.grade));
  }

  List<GradeStream> get _streams {
    if (_selectedGrade == null) return [];
    for (final c in widget.config.curricula) {
      final gc = c.grades.where((g) => g.grade == _selectedGrade).firstOrNull;
      if (gc != null) return gc.streams;
    }
    return [];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final teacherId = widget.entry is TeacherEntry
        ? (widget.entry as TeacherEntry).teacher.user
        : accountId;

    setState(() => _saving = true);
    try {
      final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final examId = _generateId();
      final startDays = _startDate.millisecondsSinceEpoch ~/ (86400 * 1000);
      final endDays = _endDate.millisecondsSinceEpoch ~/ (86400 * 1000);

      await widget.dao.createExam(
        exam: ExamsCompanion(
          id: Value(examId),
          school: Value(widget.schoolId),
          year: Value(widget.year),
          term: Value(widget.term),
          grade: Value(_selectedGrade!),
          stream: Value(_allStreams ? null : _selectedStream),
          personalized: Value(_personalized),
          type: Value(_type),
          start: Value(startDays),
          end: Value(endDays),
          teacher: Value(teacherId),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Exam / Assessment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                // Type selector
                _FieldLabel(label: 'Type', cs: cs),
                const SizedBox(height: 6),
                _SegmentedRow<ExamType>(
                  options: ExamType.values,
                  selected: _type,
                  labelOf: (t) => switch (t) {
                    ExamType.exam => 'Exam',
                    ExamType.assignment => 'Assignment',
                    ExamType.assessment => 'Assessment',
                  },
                  onSelected: (t) => setState(() => _type = t),
                  cs: cs,
                ),
                const SizedBox(height: 16),
                // Grade selector
                _FieldLabel(label: 'Grade', cs: cs),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _selectedGrade,
                  decoration: _inputDeco(cs, label: 'Select grade'),
                  items: _grades.map((g) {
                    final label = _gradeLabel(g.grade, widget.config);
                    return DropdownMenuItem(value: g.grade, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedGrade = v;
                    _selectedStream = null;
                    _allStreams = true;
                  }),
                  validator: (v) => v == null ? 'Select a grade' : null,
                ),
                const SizedBox(height: 16),
                // Stream
                if (_streams.isNotEmpty) ...[
                  _FieldLabel(label: 'Stream', cs: cs),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Checkbox(
                        value: _allStreams,
                        onChanged: (v) =>
                            setState(() => _allStreams = v ?? true),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'All streams',
                        style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                      ),
                    ],
                  ),
                  if (!_allStreams) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedStream,
                      decoration: _inputDeco(cs, label: 'Select stream'),
                      items: _streams.map((s) {
                        return DropdownMenuItem(
                          value: s.code,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedStream = v),
                      validator: (v) =>
                          !_allStreams && v == null ? 'Select a stream' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                // Personalized
                Row(
                  children: [
                    Checkbox(
                      value: _personalized,
                      onChanged: (v) =>
                          setState(() => _personalized = v ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalized exam',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'Different questions per student',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date range
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start date',
                        date: _startDate,
                        cs: cs,
                        onPicked: (d) => setState(() => _startDate = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End date',
                        date: _endDate,
                        cs: cs,
                        onPicked: (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text(
                          'Create Exam',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
// Create paper sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePaperSheet extends StatefulWidget {
  const _CreatePaperSheet({
    required this.schoolId,
    required this.examId,
    required this.year,
    required this.term,
    required this.grade,
    required this.stream,
    required this.config,
    required this.dao,
    required this.subjectsDao,
  });
  final String schoolId;
  final String examId;
  final int year;
  final int term;
  final int grade;
  final int? stream;
  final SchoolConfig config;
  final ExamsGradesDao dao;
  final SubjectsDao subjectsDao;

  @override
  State<_CreatePaperSheet> createState() => _CreatePaperSheetState();
}

class _CreatePaperSheetState extends State<_CreatePaperSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  int? _selectedSubject;
  int? _paperNumber; // null = single paper
  bool _multiPaper = false;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  // Subjects assigned for this class in this term, keyed by subject code.
  // We store just the Subject row; teacher name resolved separately.
  List<Subject> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    // getSubjectsForTerm returns ALL subjects for the term; filter to this
    // grade (and stream when set) in Dart.
    final allSubs = await widget.subjectsDao.getSubjectsForTerm(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
    );
    final filtered = allSubs
        .where(
          (s) =>
              s.grade == widget.grade &&
              (widget.stream == null || s.stream == widget.stream),
        )
        .toList();
    if (mounted) setState(() => _subjects = filtered);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubject == null) return;
    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Find the invigilator — use the subject's assigned teacher or fall back.
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
          start: Value(BigInt.from(_startTime.millisecondsSinceEpoch ~/ 1000)),
          end: Value(BigInt.from(_endTime.millisecondsSinceEpoch ~/ 1000)),
          status: const Value(PaperStatus.pending),
          created: Value(now),
          updated: Value(now),
        ),
        accountId: accountId,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Paper',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                _FieldLabel(label: 'Subject', cs: cs),
                const SizedBox(height: 6),
                _subjects.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.kRadius),
                        ),
                        child: Text(
                          'No subjects assigned to this class yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : DropdownButtonFormField<int>(
                        value: _selectedSubject,
                        decoration: _inputDeco(cs, label: 'Select subject'),
                        items: _subjects.map((s) {
                          final label = _subjectLabel(s.subject, widget.config);
                          return DropdownMenuItem(
                            value: s.subject,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedSubject = v),
                        validator: (v) => v == null ? 'Select a subject' : null,
                      ),
                const SizedBox(height: 16),
                // Multi-paper toggle
                Row(
                  children: [
                    Checkbox(
                      value: _multiPaper,
                      onChanged: (v) => setState(() {
                        _multiPaper = v ?? false;
                        _paperNumber = _multiPaper ? 1 : null;
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Multiple papers (e.g. Paper 1, 2, 3)',
                      style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                    ),
                  ],
                ),
                if (_multiPaper) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: '${_paperNumber ?? 1}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDeco(cs, label: 'Paper number'),
                    onChanged: (v) =>
                        setState(() => _paperNumber = int.tryParse(v)),
                    validator: (v) {
                      if (!_multiPaper) return null;
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Enter paper number ≥ 1';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Date/time range
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start',
                        date: _startTime,
                        cs: cs,
                        onPicked: (d) => setState(() => _startTime = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End',
                        date: _endTime,
                        cs: cs,
                        onPicked: (d) => setState(() => _endTime = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_saving || _subjects.isEmpty) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text(
                          'Add Paper',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.leadingAction,
    this.action,
  });
  final String title;
  final String subtitle;
  final _HeaderAction? leadingAction;
  final _HeaderAction? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          if (leadingAction != null) ...[
            IconButton(
              onPressed: leadingAction!.onTap,
              icon: Icon(leadingAction!.icon, size: 20),
              tooltip: leadingAction!.label,
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurface,
                minimumSize: const Size(36, 36),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            TextButton.icon(
              onPressed: action!.onTap,
              icon: Icon(action!.icon, size: 16),
              label: Text(action!.label),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderAction {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label, required this.cs});
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs});
  final PaperStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaperStatus.pending => ('Pending', cs.onSurfaceVariant),
      PaperStatus.progress => ('In Progress', const Color(0xFFF59E0B)),
      PaperStatus.done => ('Done', cs.primary),
      PaperStatus.marked => ('Marked', AppTheme.brandGreen),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    required this.cs,
  });
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: opt == options.last ? 0 : 4),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
              ),
              child: Text(
                labelOf(opt),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.cs,
    required this.onPicked,
  });
  final String label;
  final DateTime date;
  final ColorScheme cs;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2050),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtDate(date),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });
  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary cards
// ─────────────────────────────────────────────────────────────────────────────

class _ExamSummaryCard extends StatelessWidget {
  const _ExamSummaryCard({
    required this.exam,
    required this.teacher,
    required this.config,
    required this.cs,
  });
  final Exam exam;
  final UsersData teacher;
  final SchoolConfig config;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.fromMillisecondsSinceEpoch(
      exam.start * 86400 * 1000,
    );
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      exam.end * 86400 * 1000,
    );
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor(exam.type, cs).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeLabel(exam.type),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _typeColor(exam.type, cs),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Spacer(),
                if (exam.personalized)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Personalized',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.person_outline, label: teacher.name, cs: cs),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.date_range_outlined,
              label: '${_fmtDate(startDate)} – ${_fmtDate(endDate)}',
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.cs});
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.paper,
    required this.config,
    required this.cs,
    required this.canManage,
    required this.schoolId,
    required this.dao,
    required this.onTap,
    required this.onDelete,
  });
  final Paper paper;
  final SchoolConfig config;
  final ColorScheme cs;
  final bool canManage;
  final String schoolId;
  final ExamsGradesDao dao;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final subjectLabel = _subjectLabel(paper.subject, config);
    final paperLabel = paper.paper != null ? ' · Paper ${paper.paper}' : '';
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.kRadius),
      elevation: 2,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$subjectLabel$paperLabel',
                      style: TextStyle(
                        fontSize: 14,
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
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(status: paper.status, cs: cs),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              if (canManage && onDelete != null)
                _IconActionButton(
                  icon: Icons.delete_outline,
                  color: cs.error,
                  onTap: onDelete!,
                  tooltip: 'Delete paper',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / no-data states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyExamsState extends StatelessWidget {
  const _EmptyExamsState({required this.canCreate, required this.onCreate});
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 26,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No exams this term',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              canCreate
                  ? 'Create an exam or assessment to get started.'
                  : 'Exams created by teachers will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (canCreate) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Exam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPapersState extends StatelessWidget {
  const _EmptyPapersState({
    required this.canCreate,
    required this.onCreate,
    required this.cs,
  });
  final bool canCreate;
  final VoidCallback onCreate;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 28,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Text(
            canCreate
                ? 'No papers yet — add a paper to start grading.'
                : 'No papers have been added.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          if (canCreate) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Paper'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoStudentsState extends StatelessWidget {
  const _NoStudentsState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
      ),
      child: Center(
        child: Text(
          'No students enrolled in this class.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _NoTermState extends StatelessWidget {
  const _NoTermState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Select a term to view exams and grades.',
        style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

String _gradeLabel(int grade, SchoolConfig config) {
  for (final c in config.curricula) {
    final labels = gradeLabelsFor(c.type);
    if (labels.containsKey(grade)) return labels[grade]!;
  }
  return 'Grade $grade';
}

String _streamLabel(int grade, int streamCode, SchoolConfig config) {
  for (final c in config.curricula) {
    final gc = c.grades.where((g) => g.grade == grade).firstOrNull;
    if (gc != null) {
      final s = gc.streams.where((s) => s.code == streamCode).firstOrNull;
      if (s != null) return s.name;
    }
  }
  return 'Stream $streamCode';
}

String _subjectLabel(int subjectCode, SchoolConfig config) {
  // Try CBC first, then 8-4-4
  try {
    final cbcSubject = CbcSubject.values.firstWhere(
      (s) => s.index_ == subjectCode,
    );
    return cbcSubject.label;
  } catch (_) {}
  try {
    final subject844 = EightFourFourSubject.values.firstWhere(
      (s) => s.index_ == subjectCode,
    );
    return subject844.label;
  } catch (_) {}
  return 'Subject $subjectCode';
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

InputDecoration _inputDeco(ColorScheme cs, {String? label}) => InputDecoration(
  labelText: label,
  labelStyle: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: cs.onSurfaceVariant,
  ),
  filled: true,
  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
  isDense: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.kRadius),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.kRadius),
    borderSide: BorderSide(color: cs.primary, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.kRadius),
    borderSide: BorderSide(color: cs.error, width: 1.5),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTheme.kRadius),
    borderSide: BorderSide(color: cs.error, width: 1.5),
  ),
);

/// Generates a simple time-based unique id.
String _generateId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final rand = (math.Random().nextInt(0x7FFFFFFF));
  return '${ms.toRadixString(16)}-${rand.toRadixString(16)}';
}

/// Thin wrapper so call sites read cleanly.
dynamic _jsonDecode(String source) => jsonDecode(source);
