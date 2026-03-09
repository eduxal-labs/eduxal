import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/daos/exams_grades_dao.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/curriculum_levels.dart';
import '../../../../models/membership.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paper Detail Page
//
// Reached from ExamDetailPage when a paper card is tapped. Shows a single
// paper with info card, status advance, grade entry (desktop spreadsheet or
// mobile list), and analytics when the paper is marked.
// ─────────────────────────────────────────────────────────────────────────────

class PaperDetailPage extends StatefulWidget {
  const PaperDetailPage({
    super.key,
    required this.paper,
    required this.exam,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.curriculumType,
    required this.schoolContext,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final String schoolId;
  final int year;
  final int term;
  final CurriculumType curriculumType;
  final SchoolContext schoolContext;

  @override
  State<PaperDetailPage> createState() => _PaperDetailPageState();
}

class _PaperDetailPageState extends State<PaperDetailPage> {
  late final ExamsGradesDao _dao;
  late Stream<List<GradeRow>> _gradesStream;
  List<StudentsData> _students = [];
  bool _loadingStudents = true;

  Paper get _paper => widget.paper;
  Exam get _exam => widget.exam.exam;

  bool get _canManage {
    final entry = widget.schoolContext.currentEntry.value;
    return entry is TeacherEntry || entry is OwnerEntry || entry is StaffEntry;
  }

  @override
  void initState() {
    super.initState();
    _dao = ExamsGradesDao(db);
    _gradesStream = _dao.watchGradesForPaper(
      schoolId: widget.schoolId,
      examId: _exam.id,
      subject: _paper.subject,
      paper: _paper.paper,
    );
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final list = await _dao.getEnrolledStudents(
      schoolId: widget.schoolId,
      year: widget.year,
      term: widget.term,
      grade: _exam.grade,
      stream: _exam.stream,
    );
    if (!mounted) return;
    setState(() {
      _students = list;
      _loadingStudents = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjLabel = subjectLabel(widget.curriculumType, _paper.subject);
    final paperNum = _paper.paper != null ? ' Paper ${_paper.paper}' : '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '$subjLabel$paperNum',
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
      body: StreamBuilder<List<GradeRow>>(
        stream: _gradesStream,
        builder: (context, snap) {
          if (_loadingStudents ||
              snap.connectionState == ConnectionState.waiting) {
            return _buildLoading(cs);
          }

          final gradeRows = snap.data ?? [];
          final gradeMap = {for (final r in gradeRows) r.student.adm: r.grade};

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= AppTheme.kMobileBreakpoint;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // ── Paper Info Card ──────────────────────────────────
                  _PaperInfoCard(
                    paper: _paper,
                    exam: widget.exam,
                    curriculumType: widget.curriculumType,
                    cs: cs,
                  ),

                  const SizedBox(height: 12),

                  // ── Status Advance ──────────────────────────────────
                  _PaperStatusRow(
                    paper: _paper,
                    schoolId: widget.schoolId,
                    exam: _exam,
                    dao: _dao,
                    canManage: _canManage,
                    cs: cs,
                  ),

                  const SizedBox(height: 16),

                  // ── Analytics (when marked) ─────────────────────────
                  if (_paper.status == PaperStatus.marked) ...[
                    _AnalyticsSection(
                      gradeRows: gradeRows,
                      totalStudents: _students.length,
                      cs: cs,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Grade Entry Section ─────────────────────────────
                  _SectionLabel(label: 'Grades', cs: cs),
                  const SizedBox(height: 8),

                  if (_students.isEmpty)
                    _buildEmpty(cs, 'No students enrolled')
                  else if (isDesktop)
                    _GradeSpreadsheet(
                      students: _students,
                      gradeMap: gradeMap,
                      paper: _paper,
                      exam: _exam,
                      schoolId: widget.schoolId,
                      dao: _dao,
                      canGrade: _canManage,
                      cs: cs,
                    )
                  else
                    _GradeList(
                      students: _students,
                      gradeMap: gradeMap,
                      paper: _paper,
                      exam: _exam,
                      schoolId: widget.schoolId,
                      dao: _dao,
                      canGrade: _canManage,
                      cs: cs,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Paper Info Card
// ═════════════════════════════════════════════════════════════════════════════

class _PaperInfoCard extends StatelessWidget {
  const _PaperInfoCard({
    required this.paper,
    required this.exam,
    required this.curriculumType,
    required this.cs,
  });

  final Paper paper;
  final ExamWithPapers exam;
  final CurriculumType curriculumType;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isDark = cs.brightness == Brightness.dark;
    final subjLabel = subjectLabel(curriculumType, paper.subject);
    final startDt = DateTime.fromMillisecondsSinceEpoch(
      paper.start.toInt() * 1000,
    );
    final endDt = DateTime.fromMillisecondsSinceEpoch(paper.end.toInt() * 1000);

    return Material(
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
            // ── Subject + paper number row ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    paper.paper != null
                        ? '$subjLabel — Paper ${paper.paper}'
                        : subjLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                _PaperStatusChip(status: paper.status, cs: cs),
              ],
            ),

            const SizedBox(height: 10),

            // ── Scheduled time ──
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_fmtDate(startDt)} · ${_fmtTime(startDt)} – ${_fmtTime(endDt)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Invigilator ──
            Row(
              children: [
                UserAvatar(userId: exam.teacher.id, radius: 10),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    exam.teacher.name,
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

            const SizedBox(height: 6),

            // ── Exam type badge ──
            Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
                Text(
                  _typeLabel(exam.exam.type),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _typeColor(exam.exam.type, cs),
                  ),
                ),
                if (exam.exam.personalized) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Personalized',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Paper Status Row + Advance Button
// ═════════════════════════════════════════════════════════════════════════════

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
        _PaperStatusChip(status: paper.status, cs: cs),
        const SizedBox(width: 8),
        Text(
          _statusDescription(paper.status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
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

  String _statusDescription(PaperStatus s) => switch (s) {
    PaperStatus.pending => 'Not yet started',
    PaperStatus.progress => 'Exam in progress',
    PaperStatus.done => 'Exam completed, awaiting grading',
    PaperStatus.marked => 'Fully graded',
  };
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

// ═════════════════════════════════════════════════════════════════════════════
// Analytics Section (visible when paper is Marked)
// ═════════════════════════════════════════════════════════════════════════════

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({
    required this.gradeRows,
    required this.totalStudents,
    required this.cs,
  });

  final List<GradeRow> gradeRows;
  final int totalStudents;
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

  final double gradedPct;
  final double avgPct;
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

// ═════════════════════════════════════════════════════════════════════════════
// Grade Spreadsheet — Desktop (≥ 600px)
// ═════════════════════════════════════════════════════════════════════════════

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
  final Map<int, String> _drafts = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Map<int, bool> _saving = {};

  int _maxScore = 100;

  @override
  void initState() {
    super.initState();
    _initFromMap();
  }

  @override
  void didUpdateWidget(_GradeSpreadsheet old) {
    super.didUpdateWidget(old);
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

// ═════════════════════════════════════════════════════════════════════════════
// Grade List — Mobile (< 600px)
// ═════════════════════════════════════════════════════════════════════════════

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

// ═════════════════════════════════════════════════════════════════════════════
// Mobile Grade Entry Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

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

// ═════════════════════════════════════════════════════════════════════════════
// Small shared widgets
// ═════════════════════════════════════════════════════════════════════════════

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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        letterSpacing: 0.2,
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
              Icons.people_outline_rounded,
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

InputDecoration _inputDeco(ColorScheme cs, {required String label}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    filled: true,
    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.error, width: 1.5),
    ),
  );
}
