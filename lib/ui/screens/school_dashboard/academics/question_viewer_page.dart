import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../models/paper_generation.dart' show PaperQuestion;
import '../../../../models/result.dart';
import '../../../theme/app_theme.dart';

/// Displays the generated questions for a paper in a scrollable list.
///
/// Each question card shows the question number, body (rendered as plain text
/// or HTML), marks, difficulty, and rubric criteria.
class QuestionViewerPage extends StatefulWidget {
  const QuestionViewerPage({
    super.key,
    required this.paperId,
    required this.title,
    this.studentId,
  });

  final String paperId;
  final String title;
  final int? studentId;

  @override
  State<QuestionViewerPage> createState() => _QuestionViewerPageState();
}

class _QuestionViewerPageState extends State<QuestionViewerPage> {
  List<PaperQuestion>? _questions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final token = accessToken;
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    final result = await questionBankService.getPaperQuestions(
      paperId: widget.paperId,
      student: widget.studentId,
      accessToken: token,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        // Sort by order then by section if present.
        value.sort((a, b) {
          final secCmp = (a.section ?? '').compareTo(b.section ?? '');
          if (secCmp != 0) return secCmp;
          return a.order.compareTo(b.order);
        });
        setState(() {
          _questions = value;
          _loading = false;
        });
      case Err(:final error):
        setState(() {
          _error = error.message ?? 'Failed to load questions';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 24, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
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
      body: _buildBody(cs, isDark),
    );
  }

  Widget _buildBody(ColorScheme cs, bool isDark) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: cs.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadQuestions();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final questions = _questions!;
    if (questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 40, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No questions generated yet',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: questions.length,
      itemBuilder: (context, i) => _QuestionCard(
        question: questions[i],
        index: i,
        cs: cs,
        isDark: isDark,
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.cs,
    required this.isDark,
  });

  final PaperQuestion question;
  final int index;
  final ColorScheme cs;
  final bool isDark;

  String get _sectionPrefix =>
      question.section != null ? '${question.section}.' : '';

  @override
  Widget build(BuildContext context) {
    final hasStimulus = question.stimulus != null &&
        question.stimulus!['body'] is String &&
        (question.stimulus!['body'] as String).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
              : cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          border: Border.all(
            color: cs.outline.withValues(alpha: isDark ? 0.10 : 0.08),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.06),
              ),
              child: Row(
                children: [
                  // Question number
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Q$_sectionPrefix${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Marks chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(
                        alpha: isDark ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${question.marks} mark${question.marks == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Difficulty dots
                  ...List.generate(5, (i) {
                    final filled = i < question.difficulty;
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? cs.error.withValues(alpha: i < 3 ? 0.5 : 0.7)
                            : cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Stimulus (if any) ───────────────────────────────────────
            if (hasStimulus) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(
                        color: cs.secondary.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    question.stimulus!['body'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],

            // ── Question body ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Text(
                question.body.isNotEmpty ? question.body : question.text,
                style: TextStyle(
                  fontSize: 13.5,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),

            // ── Parts (if any) ──────────────────────────────────────────
            if (question.parts.isNotEmpty)
              ...question.parts.asMap().entries.map((e) {
                final part = e.value;
                final label = String.fromCharCode(97 + e.key); // a, b, c, ...
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          '($label)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              part.body,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: cs.onSurface.withValues(alpha: 0.85),
                                height: 1.5,
                              ),
                            ),
                            if (part.marks > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${part.marks} mark${part.marks == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.5),
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

            // ── Rubric (if any) ─────────────────────────────────────────
            if (question.rubric.isNotEmpty) ...[
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marking Rubric',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...question.rubric.map((criterion) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.secondary.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      if (criterion.criterion.isNotEmpty)
                                        TextSpan(
                                          text: '${criterion.criterion}: ',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      TextSpan(
                                        text: '${criterion.marks} mark${criterion.marks == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // ── Answer space indicator ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Icon(
                    _answerSpaceIcon(question.answerSpaceType),
                    size: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _answerSpaceLabel(question.answerSpaceType,
                        question.answerLines),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _answerSpaceIcon(String type) => switch (type) {
        'lines' => Icons.format_list_numbered_rounded,
        'plain_box' => Icons.check_box_outline_blank_rounded,
        'diagram_box' => Icons.grid_on_rounded,
        'construction_box' => Icons.square_foot_rounded,
        'grid_box' => Icons.grid_4x4_rounded,
        _ => Icons.edit_note_rounded,
      };

  String _answerSpaceLabel(String type, int lines) => switch (type) {
        'lines' => '$lines line${lines == 1 ? '' : 's'}',
        'plain_box' => 'Answer box',
        'diagram_box' => 'Diagram space',
        'construction_box' => 'Construction space',
        'grid_box' => 'Grid space',
        _ => 'Answer space',
      };
}
