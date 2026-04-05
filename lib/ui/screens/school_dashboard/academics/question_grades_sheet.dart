import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../core/formatters.dart';
import '../../../../models/question_grade.dart';
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Question Grades Sheet
//
// A bottom sheet / desktop dialog showing per-question AI marking breakdown
// for a student's paper. Launched from grade spreadsheet/list rows.
// ─────────────────────────────────────────────────────────────────────────────

class QuestionGradesSheet extends StatefulWidget {
  const QuestionGradesSheet({
    super.key,
    required this.school,
    required this.exam,
    required this.student,
    required this.subject,
    this.paper,
    required this.studentName,
    required this.overallScore,
    required this.totalMarks,
  });

  final String school;
  final String exam;
  final int student;
  final int subject;
  final int? paper;
  final String studentName;
  final double overallScore;
  final int totalMarks;

  @override
  State<QuestionGradesSheet> createState() => _QuestionGradesSheetState();
}

class _QuestionGradesSheetState extends State<QuestionGradesSheet> {
  late Future<Result<List<QuestionGradeDetail>, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  void _fetchGrades() {
    _future = questionBankService.getQuestionGrades(
      school: widget.school,
      exam: widget.exam,
      student: widget.student,
      subject: widget.subject,
      paper: widget.paper,
      accessToken: accessToken,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Self-contained sheet — provides its own EduSheet wrapper (background,
    // handle, title, keyboard padding) per BUG-010 convention.
    return EduSheet(
      title: 'Marking Breakdown — ${widget.studentName}',
      child: Flexible(
        child: FutureBuilder<Result<List<QuestionGradeDetail>, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildLoading(cs);
            }

            final result = snapshot.data;
            if (result == null || result is Err) {
              final errMsg = result is Err
                  ? (result as Err).error.toString()
                  : 'Unknown error';
              return _buildError(cs, isDark, errMsg);
            }

            final grades =
                (result as Ok<List<QuestionGradeDetail>, dynamic>).value;
            if (grades.isEmpty) {
              return _buildEmpty(cs);
            }

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _OverallScoreBar(
                  score: widget.overallScore,
                  total: widget.totalMarks,
                  cs: cs,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < grades.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _QuestionCard(
                    index: i + 1,
                    detail: grades[i],
                    cs: cs,
                    isDark: isDark,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme cs, bool isDark, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: cs.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 32,
            child: TextButton.icon(
              onPressed: _fetchGrades,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.quiz_outlined,
                size: 22,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No marking breakdown available.',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall score bar
// ─────────────────────────────────────────────────────────────────────────────

class _OverallScoreBar extends StatelessWidget {
  const _OverallScoreBar({
    required this.score,
    required this.total,
    required this.cs,
    required this.isDark,
  });

  final double score;
  final int total;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (score / total * 100) : 0.0;
    final color = _pctColor(pct, cs);
    final fraction = total > 0 ? (score / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${fmtScore(score)} / $total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                ),
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.15),
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-question card
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.index,
    required this.detail,
    required this.cs,
    required this.isDark,
  });

  final int index;
  final QuestionGradeDetail detail;
  final ColorScheme cs;
  final bool isDark;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final cs = widget.cs;
    final isDark = widget.isDark;
    final pct = d.totalMarks > 0 ? (d.marksAwarded / d.totalMarks * 100) : 0.0;
    final markColor = _pctColor(pct, cs);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.nestedBg(isDark, cs),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  ),
                  child: Text(
                    'Q${widget.index}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: markColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                  ),
                  child: Text(
                    '${fmtScore(d.marksAwarded)}/${d.totalMarks}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: markColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (d.feedback.isNotEmpty)
                  Icon(
                    Icons.feedback_outlined,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),

          // ── Question text (expandable) ─────────────────────────────────
          if (d.questionText.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AnimatedCrossFade(
                  firstChild: Text(
                    d.questionText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  secondChild: Text(
                    d.questionText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ),
            ),

          // ── AI feedback ────────────────────────────────────────────────
          if (d.feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                d.feedback,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),

          // ── Rubric results (data-table style) ──────────────────────────
          if (d.rubricResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _RubricTable(
                results: d.rubricResults,
                cs: cs,
                isDark: isDark,
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rubric results table
// ─────────────────────────────────────────────────────────────────────────────

class _RubricTable extends StatelessWidget {
  const _RubricTable({
    required this.results,
    required this.cs,
    required this.isDark,
  });

  final List<RubricResult> results;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < results.length; i++) ...[
          if (i > 0) AppTheme.tableRowDivider(isDark, cs),
          _RubricRow(result: results[i], cs: cs),
        ],
      ],
    );
  }
}

class _RubricRow extends StatelessWidget {
  const _RubricRow({required this.result, required this.cs});

  final RubricResult result;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final satisfied = result.satisfied;
    final iconColor = satisfied ? AppTheme.brandGreen : cs.error;
    final icon = satisfied ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.criterion,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.8),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${fmtScore(result.marksAwarded)}/${result.marksAvailable}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _pctColor(double pct, ColorScheme cs) {
  if (pct >= 70) return AppTheme.brandGreen;
  if (pct >= 50) return const Color(0xFFF59E0B);
  return cs.error;
}
