import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../models/paper_generation.dart';
import '../../../../models/question.dart' show QuestionPart, RubricCriterion;
import '../../../../models/result.dart';

import '../../../../client.dart';
import '../../../widgets/tiptap_renderer.dart';
import '../../../widgets/stimulus_block.dart';
import '../../../widgets/answer_space.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paper Reveal Page
//
// Time-gated, read-only teacher copy of a generated exam paper.
// The paper is locked until 30 minutes before the exam start time.
// Once revealed, the full question paper is shown with the marking scheme
// always visible (teacher copy).
// ─────────────────────────────────────────────────────────────────────────────

class PaperRevealPage extends StatefulWidget {
  const PaperRevealPage({
    super.key,
    required this.paperId,
    required this.examStartTime,
    required this.examName,
    required this.subjectName,
  });

  final String paperId;
  final DateTime examStartTime;
  final String examName;
  final String subjectName;

  @override
  State<PaperRevealPage> createState() => _PaperRevealPageState();
}

class _PaperRevealPageState extends State<PaperRevealPage> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  List<PaperQuestion> _questions = [];
  bool _isLoading = false;
  String? _error;

  DateTime get _revealTime =>
      widget.examStartTime.subtract(const Duration(minutes: 30));

  bool get _isRevealed => DateTime.now().isAfter(_revealTime);

  @override
  void initState() {
    super.initState();
    _remaining = _revealTime.difference(DateTime.now());
    if (!_isRevealed) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), _tick);
    } else {
      _loadQuestions();
    }
  }

  void _tick(Timer t) {
    final remaining = _revealTime.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      t.cancel();
      _loadQuestions();
    }
    if (mounted) setState(() => _remaining = remaining);
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    final result = await questionBankService.getPaperQuestions(
      paperId: widget.paperId,
      accessToken: accessToken,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        setState(() {
          _questions = value;
          _isLoading = false;
        });
      case Err(:final error):
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isRevealed) {
      return _buildLockedState(context);
    }
    return _buildRevealedState(context);
  }

  // ---------------------------------------------------------------------------
  // Locked state — countdown
  // ---------------------------------------------------------------------------

  Widget _buildLockedState(BuildContext context) {
    final minutesLeft = _remaining.isNegative ? 0 : _remaining.inMinutes;
    final secondsLeft = _remaining.isNegative ? 0 : _remaining.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.subjectName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Paper available at ${_formatTime(_revealTime)}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Available in ${minutesLeft}m ${secondsLeft}s',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This paper is confidential until 30 minutes before the exam.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Revealed state — full paper with marking scheme
  // ---------------------------------------------------------------------------

  Widget _buildRevealedState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.subjectName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(
            widget.examName,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Failed to load: $_error'),
                  TextButton(
                    onPressed: _loadQuestions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  ..._buildQuestions(),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header box
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            widget.examName,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            widget.subjectName,
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 16),
          const Text(
            'CONFIDENTIAL — TEACHER COPY',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 16),
          Text(
            'ANSWER ALL QUESTIONS IN THE SPACES PROVIDED',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Questions list
  // ---------------------------------------------------------------------------

  List<Widget> _buildQuestions() {
    final List<Widget> widgets = [];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${i + 1}.  ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (q.stimulus != null) StimulusBlock(stimulus: q.stimulus!),
                  renderBody(q.body, q.bodyFormat),
                  if (q.images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...q.images.map((img) {
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
                  if (q.parts.isNotEmpty) _buildParts(q.parts),
                  // Question-level marking scheme — shown when no parts,
                  // or in addition for any top-level rubric when parts exist.
                  _buildMarkingScheme(q),
                ],
              ),
            ),
            Text(
              '${q.marks} mk',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
      if (i < _questions.length - 1) widgets.add(const Divider(height: 24));
    }
    return widgets;
  }

  // ---------------------------------------------------------------------------
  // Parts
  // ---------------------------------------------------------------------------

  Widget _buildParts(List<QuestionPart> parts) {
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
              // Show answer space even in teacher copy for layout reference
              AnswerSpaceWidget(
                answerSpaceType: p.answerSpaceType,
                answerLines: p.answerLines,
                answerBoxHeightMm: p.answerBoxHeightMm,
              ),
              // Per-part marking scheme
              _buildRubricBlock(p.rubric, p.exampleAnswer),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Marking scheme — question level
  // ---------------------------------------------------------------------------

  Widget _buildMarkingScheme(PaperQuestion q) {
    // Only render if there is something to show at the question level.
    // (Parts have their own per-part scheme rendered inside _buildParts.)
    if (q.rubric.isEmpty) return const SizedBox.shrink();
    return _buildRubricBlock(q.rubric, null);
  }

  // ---------------------------------------------------------------------------
  // Shared rubric block (question-level and part-level)
  // ---------------------------------------------------------------------------

  Widget _buildRubricBlock(
    List<RubricCriterion> rubric,
    dynamic exampleAnswer,
  ) {
    final cs = Theme.of(context).colorScheme;

    if (rubric.isEmpty && exampleAnswer == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
