import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../database/database.dart';
import '../../../../../database/daos/exams_grades_dao.dart';
import '../../../../../database/tables/curriculum_subjects.dart';
import '../../../../../database/tables/enums.dart';
import '../../../../../models/curriculum_levels.dart';

/// Exams tab for the Student Grade Page — shows all exams the student has
/// participated in with per-subject grades, paper breakdowns, and totals.
///
/// Cards are ordered by exam start date descending (most recent first).
/// Each card shows an exam type badge, date range, subject grades with
/// thin progress bars, and an exam total at the bottom.
class StudentExamsTab extends StatefulWidget {
  const StudentExamsTab({
    super.key,
    required this.schoolId,
    required this.year,
    required this.term,
    required this.grade,
    required this.streamCode,
    required this.studentAdm,
    required this.curriculumType,
  });

  final String schoolId;
  final int year;
  final int term;
  final int grade;
  final int streamCode;
  final int studentAdm;
  final CurriculumType curriculumType;

  @override
  State<StudentExamsTab> createState() => _StudentExamsTabState();
}

class _StudentExamsTabState extends State<StudentExamsTab>
    with AutomaticKeepAliveClientMixin {
  late final ExamsGradesDao _examsGradesDao;
  late Stream<List<Grade>> _gradesStream;

  /// Cached exam lookups — avoids repeated DB calls for the same exam id.
  final Map<String, Exam?> _examCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _examsGradesDao = ExamsGradesDao(db);
    _buildStream();
  }

  @override
  void didUpdateWidget(covariant StudentExamsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.studentAdm != widget.studentAdm) {
      _examCache.clear();
      _buildStream();
      setState(() {});
    }
  }

  void _buildStream() {
    _gradesStream = _examsGradesDao.watchStudentGrades(
      widget.schoolId,
      widget.studentAdm,
    );
  }

  Future<Exam?> _getExam(String examId) async {
    if (_examCache.containsKey(examId)) return _examCache[examId];
    final exam = await _examsGradesDao.getExam(examId);
    _examCache[examId] = exam;
    return exam;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return StreamBuilder<List<Grade>>(
      stream: _gradesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          );
        }

        final grades = snapshot.data ?? [];
        if (grades.isEmpty) {
          return _buildEmptyState(cs);
        }

        // Group grades by exam id.
        final byExam = <String, List<Grade>>{};
        for (final g in grades) {
          byExam.putIfAbsent(g.exam, () => []).add(g);
        }

        // Sort exams by most recent grade created date (descending).
        final examIds = byExam.keys.toList()
          ..sort((a, b) {
            final aMax = byExam[a]!
                .map((g) => g.created.toInt())
                .reduce((v, e) => v > e ? v : e);
            final bMax = byExam[b]!
                .map((g) => g.created.toInt())
                .reduce((v, e) => v > e ? v : e);
            return bMax.compareTo(aMax);
          });

        return FutureBuilder<Map<String, Exam?>>(
          future: _resolveExams(examIds),
          builder: (context, examSnap) {
            final examMap = examSnap.data ?? {};

            // Build dot plot data — chronological order (oldest first).
            // examIds is sorted most-recent-first, so reverse for the chart.
            final dotData = <_DotDatum>[];
            for (final eid in examIds.reversed) {
              final eg = byExam[eid]!;
              final ex = examMap[eid];

              // Compute subject-level totals or fall back to all grades.
              final subjectTotals = <int, Grade>{};
              for (final g in eg) {
                if (g.paper == null) subjectTotals[g.subject] = g;
              }
              double score = 0;
              int possible = 0;
              if (subjectTotals.isNotEmpty) {
                for (final g in subjectTotals.values) {
                  score += g.score;
                  possible += g.total;
                }
              } else {
                for (final g in eg) {
                  score += g.score;
                  possible += g.total;
                }
              }
              final pct = possible > 0 ? (score / possible) * 100 : 0.0;

              // Abbreviated label: type initial + index.
              final typeInit = switch (ex?.type) {
                ExamType.exam => 'E',
                ExamType.assignment => 'A',
                ExamType.assessment => 'T',
                null => '?',
              };
              dotData.add(
                _DotDatum(
                  label: '$typeInit${dotData.length + 1}',
                  percent: pct,
                ),
              );
            }

            final showDotPlot = dotData.length >= 2;

            return Column(
              children: [
                if (showDotPlot)
                  _ExamDotPlot(cs: cs, isDark: isDark, data: dotData),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      showDotPlot ? 6 : 12,
                      16,
                      32,
                    ),
                    itemCount: examIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final examId = examIds[index];
                      final examGrades = byExam[examId]!;
                      final exam = examMap[examId];

                      return _ExamCard(
                        cs: cs,
                        isDark: isDark,
                        examId: examId,
                        exam: exam,
                        grades: examGrades,
                        curriculumType: widget.curriculumType,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Resolves all exam metadata in one pass, using the cache.
  Future<Map<String, Exam?>> _resolveExams(List<String> examIds) async {
    final result = <String, Exam?>{};
    for (final id in examIds) {
      result[id] = await _getExam(id);
    }
    return result;
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No exam results yet',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Results will appear here once exams are graded',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exam Card ───────────────────────────────────────────────────────────────

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.cs,
    required this.isDark,
    required this.examId,
    required this.exam,
    required this.grades,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final String examId;
  final Exam? exam;
  final List<Grade> grades;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    // Separate subject-level totals (paper == null) and paper-level grades.
    final subjectTotals = <int, Grade>{};
    final paperGrades = <int, List<Grade>>{};

    for (final g in grades) {
      if (g.paper == null) {
        subjectTotals[g.subject] = g;
      } else {
        paperGrades.putIfAbsent(g.subject, () => []).add(g);
      }
    }

    // Build ordered subject list — subjects that have a subject-level total,
    // plus any subjects that only have paper-level grades.
    final allSubjects = <int>{...subjectTotals.keys, ...paperGrades.keys};
    final sortedSubjects = allSubjects.toList()..sort();

    // Compute exam total from subject-level totals (preferred) or all grades.
    double totalScore = 0;
    int totalPossible = 0;
    if (subjectTotals.isNotEmpty) {
      for (final g in subjectTotals.values) {
        totalScore += g.score;
        totalPossible += g.total;
      }
    } else {
      for (final g in grades) {
        totalScore += g.score;
        totalPossible += g.total;
      }
    }
    final totalPercent = totalPossible > 0
        ? (totalScore / totalPossible) * 100
        : 0.0;
    final totalColor = _percentColor(totalPercent);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          _buildHeader(),

          // ── Divider ──────────────────────────────────────────────────
          Container(
            height: 0.5,
            color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          ),

          // ── Subject grades ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              children: [
                for (int i = 0; i < sortedSubjects.length; i++) ...[
                  _SubjectGradeRow(
                    cs: cs,
                    isDark: isDark,
                    subjectIndex: sortedSubjects[i],
                    subjectTotal: subjectTotals[sortedSubjects[i]],
                    papers: paperGrades[sortedSubjects[i]],
                    curriculumType: curriculumType,
                  ),
                  if (i < sortedSubjects.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // ── Total bar ────────────────────────────────────────────────
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(top: 6),
            color: cs.outline.withValues(alpha: isDark ? 0.06 : 0.04),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${totalScore.toStringAsFixed(0)}/$totalPossible',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: totalColor.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${totalPercent.round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: totalColor,
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

  Widget _buildHeader() {
    final examType = exam?.type;
    final typeLabel = switch (examType) {
      ExamType.exam => 'Exam',
      ExamType.assignment => 'Assignment',
      ExamType.assessment => 'Assessment',
      null => 'Exam',
    };
    final typeColor = switch (examType) {
      ExamType.exam => const Color(0xFF5C6BC0),
      ExamType.assignment => const Color(0xFF26A69A),
      ExamType.assessment => const Color(0xFFAB47BC),
      null => cs.onSurfaceVariant.withValues(alpha: 0.5),
    };

    // Date range from exam — days since epoch → readable date.
    final dateRange = exam != null
        ? '${_formatDaysDate(exam!.start)} – ${_formatDaysDate(exam!.end)}'
        : '';

    // Stream scope label.
    final scopeLabel = exam?.stream == null ? 'Grade-wide' : 'Stream';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Scope chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              scopeLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),

          const Spacer(),

          // Date range
          if (dateRange.isNotEmpty)
            Text(
              dateRange,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Subject Grade Row ───────────────────────────────────────────────────────

class _SubjectGradeRow extends StatelessWidget {
  const _SubjectGradeRow({
    required this.cs,
    required this.isDark,
    required this.subjectIndex,
    required this.subjectTotal,
    required this.papers,
    required this.curriculumType,
  });

  final ColorScheme cs;
  final bool isDark;
  final int subjectIndex;
  final Grade? subjectTotal;
  final List<Grade>? papers;
  final CurriculumType curriculumType;

  @override
  Widget build(BuildContext context) {
    final label = subjectLabel(curriculumType, subjectIndex);
    final hasPapers = papers != null && papers!.isNotEmpty;

    // Use subject-level total if available, otherwise sum papers.
    final double score;
    final int total;
    if (subjectTotal != null) {
      score = subjectTotal!.score;
      total = subjectTotal!.total;
    } else if (hasPapers) {
      score = papers!.fold(0.0, (sum, g) => sum + g.score);
      total = papers!.fold(0, (sum, g) => sum + g.total);
    } else {
      score = 0;
      total = 0;
    }

    final percent = total > 0 ? (score / total) * 100 : 0.0;
    final color = _percentColor(percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject row
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${score.toStringAsFixed(score.truncateToDouble() == score ? 0 : 1)}/$total',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '${percent.round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _ThinProgressBar(
          percent: percent / 100,
          color: color,
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          height: 2.5,
        ),

        // Paper-level breakdown (if multiple papers exist)
        if (hasPapers && papers!.length > 1) ...[
          const SizedBox(height: 6),
          ...papers!.map((p) => _buildPaperRow(p)),
        ],
      ],
    );
  }

  Widget _buildPaperRow(Grade paperGrade) {
    final paperNum = paperGrade.paper;
    final pLabel = paperNum != null ? 'Paper $paperNum' : 'Paper';
    final pPercent = paperGrade.total > 0
        ? (paperGrade.score / paperGrade.total) * 100
        : 0.0;
    final pColor = _percentColor(pPercent);

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            '${paperGrade.score.toStringAsFixed(paperGrade.score.truncateToDouble() == paperGrade.score ? 0 : 1)}/${paperGrade.total}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${pPercent.round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: pColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dot Plot Data ───────────────────────────────────────────────────────────

class _DotDatum {
  const _DotDatum({required this.label, required this.percent});
  final String label;
  final double percent;
}

// ─── Exam Dot Plot ───────────────────────────────────────────────────────────

class _ExamDotPlot extends StatelessWidget {
  const _ExamDotPlot({
    required this.cs,
    required this.isDark,
    required this.data,
  });

  final ColorScheme cs;
  final bool isDark;
  final List<_DotDatum> data;

  @override
  Widget build(BuildContext context) {
    const chartHeight = 80.0;
    const dotSpacing = 50.0;
    final plotWidth = math.max(data.length * dotSpacing, dotSpacing);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Y-axis labels
            SizedBox(
              height: chartHeight,
              width: 28,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '100',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      '0%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Scrollable chart area
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: plotWidth,
                  height: chartHeight,
                  child: CustomPaint(
                    painter: _DotPlotPainter(
                      data: data,
                      dotSpacing: dotSpacing,
                      lineColor: cs.onSurfaceVariant.withValues(
                        alpha: isDark ? 0.12 : 0.1,
                      ),
                      labelColor: cs.onSurfaceVariant.withValues(alpha: 0.45),
                      isDark: isDark,
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

// ─── Dot Plot Painter ────────────────────────────────────────────────────────

class _DotPlotPainter extends CustomPainter {
  _DotPlotPainter({
    required this.data,
    required this.dotSpacing,
    required this.lineColor,
    required this.labelColor,
    required this.isDark,
  });

  final List<_DotDatum> data;
  final double dotSpacing;
  final Color lineColor;
  final Color labelColor;
  final bool isDark;

  static const _dotRadius = 4.0;
  static const _labelHeight = 14.0; // space reserved for labels at bottom

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartTop = 4.0;
    final chartBottom = size.height - _labelHeight;
    final chartRange = chartBottom - chartTop;

    // Compute dot positions.
    final points = <Offset>[];
    final colors = <Color>[];
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = (i + 0.5) * dotSpacing;
      final pct = d.percent.clamp(0.0, 100.0);
      final y = chartBottom - (pct / 100.0) * chartRange;
      points.add(Offset(x, y));
      colors.add(_dotColor(d.percent));
    }

    // Draw connecting line.
    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw dots and labels.
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final color = colors[i];

      // Dot outer ring (subtle).
      final ringPaint = Paint()
        ..color = color.withValues(alpha: isDark ? 0.25 : 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, _dotRadius + 2, ringPaint);

      // Dot fill.
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, _dotRadius, dotPaint);

      // Label below.
      final labelSpan = TextSpan(
        text: data[i].label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w400,
          color: labelColor,
        ),
      );
      final tp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, chartBottom + 2));
    }
  }

  Color _dotColor(double p) {
    if (p >= 70) return const Color(0xFF4CAF50);
    if (p >= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  @override
  bool shouldRepaint(covariant _DotPlotPainter old) {
    return old.data != data ||
        old.dotSpacing != dotSpacing ||
        old.lineColor != lineColor;
  }
}

// ─── Thin Progress Bar ───────────────────────────────────────────────────────

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.percent,
    required this.color,
    required this.backgroundColor,
    this.height = 3,
  });

  /// 0.0 – 1.0
  final double percent;
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: backgroundColor),
            FractionallySizedBox(
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _percentColor(double p) {
  if (p >= 70) return const Color(0xFF4CAF50);
  if (p >= 40) return const Color(0xFFFFA726);
  return const Color(0xFFF44336);
}

/// Converts days since epoch to a short date string (e.g. "12 Jan").
String _formatDaysDate(int daysSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    daysSinceEpoch * 86400000,
    isUtc: true,
  );
  return '${date.day} ${_months[date.month - 1]}';
}

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
