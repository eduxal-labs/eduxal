import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../models/paper_generation.dart';
import '../../../../models/question.dart';
import '../../../../models/result.dart';

import '../../../../client.dart';
import '../../../widgets/tiptap_renderer.dart';
import '../../../widgets/stimulus_block.dart';
import '../../../widgets/answer_space.dart';
import 'paper_pdf_viewer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paper Preview Page
//
// Read-only preview of a generated exam paper. Supports toggling between
// the student-facing question paper view and the marking scheme view.
//
// Reached from PaperDetailPage or EventDetailPage by tapping a "Preview" action.
// ─────────────────────────────────────────────────────────────────────────────

class PaperPreviewPage extends StatefulWidget {
  const PaperPreviewPage({super.key, required this.paperId, this.studentId});

  /// The composite paper ID string used by the question bank service.
  final String paperId;

  /// If non-null, fetches the student-specific paper variant and shows
  /// student name/adm fields in the header.
  final String? studentId;

  @override
  State<PaperPreviewPage> createState() => _PaperPreviewPageState();
}

class _PaperPreviewPageState extends State<PaperPreviewPage> {
  bool _showMarkingScheme = false;
  List<PaperQuestion> _questions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await questionBankService.getPaperQuestions(
      paperId: widget.paperId,
      student: widget.studentId != null
          ? int.tryParse(widget.studentId!)
          : null,
      accessToken: accessToken,
    );

    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        setState(() {
          _questions = value;
          _loading = false;
        });
      case Err(:final error):
        setState(() {
          _error = error.message ?? 'Failed to load paper questions.';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paper Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Download MS Word (.docx)',
            onPressed: () => downloadAndOpenDocx(
              school: '',
              exam: '',
              subject: 0,
              grade: 0,
              accessToken: accessToken,
              context: context,
              title: 'Paper Preview',
              serverPaperId: widget.paperId,
            ),
          ),
          IconButton(
            icon: Icon(
              _showMarkingScheme
                  ? Icons.article_outlined
                  : Icons.fact_check_outlined,
            ),
            tooltip: _showMarkingScheme
                ? 'Show question paper'
                : 'Show marking scheme',
            onPressed: () =>
                setState(() => _showMarkingScheme = !_showMarkingScheme),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          'No questions found for this paper.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          ..._buildQuestions(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header box
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paper Preview',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Divider(height: 16),
          Text(
            'ANSWER ALL QUESTIONS IN THE SPACES PROVIDED',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Questions list
  // ---------------------------------------------------------------------------

  List<Widget> _buildQuestions(BuildContext context) {
    final result = <Widget>[];
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      result.add(_buildQuestionRow(context, i, question));
      if (i < _questions.length - 1) {
        result.add(const Divider(height: 24));
      }
    }
    return result;
  }

  Widget _buildQuestionRow(
    BuildContext context,
    int index,
    PaperQuestion question,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question number
        Text(
          'Q${index + 1}.  ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        // Question content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stimulus (passage / table / image) above the question body
              if (question.stimulus != null)
                StimulusBlock(stimulus: question.stimulus!),
              // Question body
              renderBody(question.body, question.bodyFormat),
              // Question images
              if (question.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...question.images.map((img) {
                  if (img.getUrl == null || img.getUrl!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final isSvg = img.filename.toLowerCase().endsWith('.svg') ||
                      (img.getUrl != null && img.getUrl!.toLowerCase().contains('.svg'));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: isSvg
                            ? SvgPicture.network(
                                img.getUrl!,
                                fit: BoxFit.contain,
                                placeholderBuilder: (context) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                              )
                            : Image.network(
                                img.getUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.broken_image_outlined, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Failed to load image (${img.filename})',
                                          style: const TextStyle(color: Colors.red, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  );
                }),
              ],
              // Parts
              if (question.parts.isNotEmpty) _renderParts(question.parts),
              // Answer space (question-level — only when no parts, or parts list
              // is empty; if there are parts the space appears under each part)
              if (question.parts.isEmpty && !_showMarkingScheme)
                AnswerSpaceWidget(
                  answerSpaceType: question.answerSpaceType,
                  answerLines: question.answerLines,
                ),
              // Marking scheme (question-level — only when no parts)
              if (question.parts.isEmpty && _showMarkingScheme)
                _renderMarkingScheme(question.rubric, null),
            ],
          ),
        ),
        // Marks badge
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            '${question.marks} mk',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Parts
  // ---------------------------------------------------------------------------

  Widget _renderParts(List<QuestionPart> parts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((p) {
        return Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '(${p.label})  ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(child: renderBody(p.body, p.bodyFormat)),
                ],
              ),
              if (!_showMarkingScheme)
                AnswerSpaceWidget(
                  answerSpaceType: p.answerSpaceType,
                  answerLines: p.answerLines,
                  answerBoxHeightMm: p.answerBoxHeightMm,
                ),
              if (_showMarkingScheme)
                _renderMarkingScheme(p.rubric, p.exampleAnswer),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Marking scheme block
  // ---------------------------------------------------------------------------

  Widget _renderMarkingScheme(
    List<RubricCriterion> rubric,
    dynamic exampleAnswer,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rubric.isNotEmpty) ...[
            const Text(
              'Marking Guide:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
            ...rubric.map(
              (r) => Text(
                '• ${r.criterion} [${r.marks} mark(s)]',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          if (exampleAnswer != null) ...[
            const SizedBox(height: 4),
            const Text(
              'Example Answer:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
            _renderExampleAnswer(exampleAnswer),
          ],
        ],
      ),
    );
  }

  Widget _renderExampleAnswer(dynamic ea) {
    if (ea is String && ea.isNotEmpty) {
      return Text(ea, style: const TextStyle(fontSize: 12));
    }
    if (ea is Map) {
      final format = ea['format'] as String? ?? 'plain';
      final content = ea['content'] as String? ?? '';
      if (format == 'svg') {
        try {
          return SvgPicture.string(content, height: 120);
        } catch (_) {
          // fall through to renderBody
        }
      }
      return renderBody(content, format, style: const TextStyle(fontSize: 12));
    }
    return const SizedBox.shrink();
  }
}
